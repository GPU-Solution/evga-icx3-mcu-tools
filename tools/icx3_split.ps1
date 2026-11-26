# icx3_split.ps1 - EVGA iCX3 MCU: register-select and data-read as two separate I2C transactions with
# a delay in between, at a given speed. Tells whether the MCU only needs time to prepare its reply
# (works with a delay) or cannot transmit at that speed at all (still 05 FF FF ...).
# Transaction 1: WriteEx, no register, data = [reg]       (START addr+W reg STOP)
# Transaction 2: ReadEx,  no register, cbSize = Len       (START addr+R data... STOP)
# Read-only from the MCU's point of view (0xB1 ReadInformation takes no payload).
param([int]$Reg = 0xB1, [int]$Len = 6, [int]$Addr = 0x5A, [int]$Port = 1, [int]$Gpu = 0, [int]$Speed = 4)
$src = @'
using System;
using System.Runtime.InteropServices;
public static class NvI2cS {
    [DllImport("nvapi64.dll", EntryPoint = "nvapi_QueryInterface", CallingConvention = CallingConvention.Cdecl)]
    static extern IntPtr QueryInterface(uint id);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int InitFn();
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int EnumFn([Out] IntPtr[] handles, out int count);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int I2cFn(IntPtr gpu, IntPtr info, IntPtr ex);
    static I2cFn readEx, writeEx;
    static IntPtr[] gpus = new IntPtr[64];
    public static int Count;
    public static int Init() {
        var init = (InitFn)Marshal.GetDelegateForFunctionPointer(QueryInterface(0x0150E828), typeof(InitFn));
        int s = init(); if (s != 0) return s;
        var en = (EnumFn)Marshal.GetDelegateForFunctionPointer(QueryInterface(0xE5AC921F), typeof(EnumFn));
        s = en(gpus, out Count); if (s != 0) return s;
        readEx = (I2cFn)Marshal.GetDelegateForFunctionPointer(QueryInterface(0x4D7B0709), typeof(I2cFn));
        writeEx = (I2cFn)Marshal.GetDelegateForFunctionPointer(QueryInterface(0x283AC65A), typeof(I2cFn));
        return 0;
    }
    // NV_I2C_INFO_V3 with regAddrSize = 0 (raw transfer)
    public static int Raw(bool write, int gpu, byte addr, int port, uint speed, byte[] data) {
        IntPtr info = Marshal.AllocHGlobal(64), ex = Marshal.AllocHGlobal(8), pData = Marshal.AllocHGlobal(data.Length);
        try {
            for (int i = 0; i < 64; i++) Marshal.WriteByte(info, i, 0);
            Marshal.WriteInt64(ex, 0);
            if (write) Marshal.Copy(data, 0, pData, data.Length);
            else for (int i = 0; i < data.Length; i++) Marshal.WriteByte(pData, i, 0xEE);
            Marshal.WriteInt32(info, 0, 64 | (3 << 16));
            Marshal.WriteByte(info, 9, addr);
            Marshal.WriteInt32(info, 24, 0);
            Marshal.WriteInt64(info, 32, pData.ToInt64());
            Marshal.WriteInt32(info, 40, data.Length);
            Marshal.WriteInt32(info, 44, 0xFFFF);
            Marshal.WriteInt32(info, 48, (int)speed);
            if (port != 0) { Marshal.WriteByte(info, 52, (byte)port); Marshal.WriteInt32(info, 56, 1); }
            int s = write ? writeEx(gpus[gpu], info, ex) : readEx(gpus[gpu], info, ex);
            if (!write) Marshal.Copy(pData, data, 0, data.Length);
            return s;
        } finally { Marshal.FreeHGlobal(info); Marshal.FreeHGlobal(ex); Marshal.FreeHGlobal(pData); }
    }
}
'@
Add-Type -TypeDefinition $src
"init=$([NvI2cS]::Init()) gpus=$([NvI2cS]::Count) speed=$Speed reg=0x$('{0:X2}' -f $Reg)"
foreach ($d in 0, 1, 5, 20, 100) {
    $w = [NvI2cS]::Raw($true, $Gpu, [byte]$Addr, $Port, [uint32]$Speed, [byte[]]@([byte]$Reg))
    Start-Sleep -Milliseconds $d
    $b = [byte[]]::new($Len)
    $r = [NvI2cS]::Raw($false, $Gpu, [byte]$Addr, $Port, [uint32]$Speed, $b)
    "delay {0,3} ms: write={1} read={2} data={3}" -f $d, $w, $r, (($b | ForEach-Object { '{0:X2}' -f $_ }) -join ' ')
}
