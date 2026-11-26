# icx3_speed.ps1 - read the EVGA iCX3 MCU through NvAPI_I2CReadEx at several I2C speeds. Read-only.
#
# Same NV_I2C_INFO_V3 that Precision X1's ManagedNvApi.dll builds (port 1, 8-bit address 0x5A,
# 1-byte register), but with i2cSpeedKhz set explicitly. Use it to find out whether your MCU only
# answers at low speed. Healthy reply to register 0xB1 (ReadInformation):
#     05 FC <slave> <productID> <major> <minor>      e.g. 05 FC 2D 02 01 16 = FTW3, v1.22
# Broken-at-this-speed reply:
#     05 FF FF FF FF FF
#
# Usage: icx3_speed.ps1 [-Reg 0xB1] [-Len 6] [-Addr 0x5A] [-Port 1] [-Gpu 0] [-Speeds "0,4,3,2,1"]
# NV_I2C_SPEED: 0 default, 1 = 3 kHz, 2 = 10 kHz, 3 = 33 kHz, 4 = 100 kHz, 5 = 200 kHz, 6 = 400 kHz
# Close Precision X1 / FirmwareUpdate first.
param([int]$Reg = 0xB1, [int]$Len = 6, [int]$Addr = 0x5A, [int]$Port = 1, [int]$Gpu = 0,
      [string]$Speeds = '0,4,3,2,1')
$src = @'
using System;
using System.Runtime.InteropServices;
public static class NvI2cR {
    [DllImport("nvapi64.dll", EntryPoint = "nvapi_QueryInterface", CallingConvention = CallingConvention.Cdecl)]
    static extern IntPtr QueryInterface(uint id);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int InitFn();
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int EnumFn([Out] IntPtr[] handles, out int count);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int I2cFn(IntPtr gpu, IntPtr info, IntPtr ex);
    static I2cFn readEx;
    static IntPtr[] gpus = new IntPtr[64];
    public static int Count;
    public static int Init() {
        // NvAPI_Initialize, NvAPI_EnumPhysicalGPUs, NvAPI_I2CReadEx
        var init = (InitFn)Marshal.GetDelegateForFunctionPointer(QueryInterface(0x0150E828), typeof(InitFn));
        int s = init(); if (s != 0) return s;
        var en = (EnumFn)Marshal.GetDelegateForFunctionPointer(QueryInterface(0xE5AC921F), typeof(EnumFn));
        s = en(gpus, out Count); if (s != 0) return s;
        readEx = (I2cFn)Marshal.GetDelegateForFunctionPointer(QueryInterface(0x4D7B0709), typeof(I2cFn));
        return 0;
    }
    // NV_I2C_INFO_V3 (64 bytes): version@0 displayMask@4 bIsDDCPort@8 i2cDevAddress@9 pbI2cRegAddress@16
    // regAddrSize@24 pbData@32 cbSize@40 i2cSpeed@44 i2cSpeedKhz@48 portId@52 bIsPortIdSet@56
    public static int Read(int gpu, byte addr, byte reg, int port, uint speedKhz, byte[] data) {
        IntPtr info = Marshal.AllocHGlobal(64), ex = Marshal.AllocHGlobal(8);
        IntPtr pReg = Marshal.AllocHGlobal(1), pData = Marshal.AllocHGlobal(data.Length);
        try {
            for (int i = 0; i < 64; i++) Marshal.WriteByte(info, i, 0);
            Marshal.WriteInt64(ex, 0);
            Marshal.WriteByte(pReg, reg);
            for (int i = 0; i < data.Length; i++) Marshal.WriteByte(pData, i, 0xEE);
            Marshal.WriteInt32(info, 0, 64 | (3 << 16));
            Marshal.WriteByte(info, 9, addr);
            Marshal.WriteInt64(info, 16, pReg.ToInt64());
            Marshal.WriteInt32(info, 24, 1);
            Marshal.WriteInt64(info, 32, pData.ToInt64());
            Marshal.WriteInt32(info, 40, data.Length);
            Marshal.WriteInt32(info, 44, 0xFFFF);
            Marshal.WriteInt32(info, 48, (int)speedKhz);
            if (port != 0) { Marshal.WriteByte(info, 52, (byte)port); Marshal.WriteInt32(info, 56, 1); }
            int s = readEx(gpus[gpu], info, ex);
            Marshal.Copy(pData, data, 0, data.Length);
            return s;
        } finally {
            Marshal.FreeHGlobal(info); Marshal.FreeHGlobal(ex); Marshal.FreeHGlobal(pReg); Marshal.FreeHGlobal(pData);
        }
    }
}
'@
Add-Type -TypeDefinition $src
$s = [NvI2cR]::Init()
"NvAPI init status=$s gpus=$([NvI2cR]::Count)"
$names = @{0 = 'default'; 1 = '3 kHz'; 2 = '10 kHz'; 3 = '33 kHz'; 4 = '100 kHz'; 5 = '200 kHz'; 6 = '400 kHz'}
foreach ($sp in ($Speeds -split '[,; ]+' | Where-Object { $_ -ne '' } | ForEach-Object { [int]$_ })) {
    for ($k = 0; $k -lt 2; $k++) {
        $buf = [byte[]]::new($Len)
        $st = [NvI2cR]::Read($Gpu, [byte]$Addr, [byte]$Reg, $Port, [uint32]$sp, $buf)
        "{0,-8} status={1,-5} data={2}" -f $names[$sp], $st, (($buf | ForEach-Object { '{0:X2}' -f $_ }) -join ' ')
        Start-Sleep -Milliseconds 100
    }
}
