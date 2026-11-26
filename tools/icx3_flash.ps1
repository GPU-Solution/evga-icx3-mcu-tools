# icx3_flash.ps1 - EVGA iCX3 MCU (RTX 30 series) firmware update over NVAPI I2C at a selectable speed.
#
# Follows the same sequence Precision X1's FirmwareUpdate.exe uses (see docs/i2c-protocol.md), but
# drives NvAPI_I2CReadEx/WriteEx directly so i2cSpeedKhz can be lowered: some MCUs only answer the first
# byte at the default speed (05 FF FF ...) and answer fine at <= 33 kHz.
# Sector 0 (EVGA bootloader, 32 KB) is never touched; the application goes to sectors 1..N (0x8000+).
# If anything fails half-way the MCU stays in its bootloader (ProductID 160) and you can simply retry.
#
# Requirements: NVIDIA driver installed (nvapi64.dll), EVGA RTX 30 card with an iCX3 MCU that already has
# EVGA's bootloader, nothing else talking to the MCU (close Precision X1 and FirmwareUpdate).
# Take the application images from your own Precision X1 install: C:\Program Files\EVGA\Precision X1\Firmware
# and pick the one for YOUR board subsystem ID (docs/ssid-firmware-map.md).
#
# Usage:
#   icx3_flash.ps1 -Mode info                     # ReadInformation + ReadConfiguration (read-only)
#   icx3_flash.ps1 -Mode flash -File <ap.bin>     # full update
# Options: -Speed 3 (NV_I2C_SPEED: 1=3k 2=10k 3=33k 4=100k), -Gpu 0, -Port 1, -Addr 0x5A, -Log <file>
param([ValidateSet('info', 'flash')] [string]$Mode = 'info', [string]$File = '',
      [int]$Speed = 3, [int]$Gpu = 0, [int]$Port = 1, [int]$Addr = 0x5A,
      [string]$Log = (Join-Path $env:TEMP ("icx3_flash_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))))
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force (Split-Path $Log) | Out-Null
function Say($m) { $l = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss.fff'), $m; $l; Add-Content -Path $Log -Value $l }

$src = @'
using System;
using System.Runtime.InteropServices;
public static class NvI2c {
    [DllImport("nvapi64.dll", EntryPoint = "nvapi_QueryInterface", CallingConvention = CallingConvention.Cdecl)]
    static extern IntPtr QueryInterface(uint id);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int InitFn();
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int EnumFn([Out] IntPtr[] handles, out int count);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int I2cFn(IntPtr gpu, IntPtr info, IntPtr ex);
    static I2cFn readEx, writeEx;
    static IntPtr[] gpus = new IntPtr[64];
    public static int Count;
    public static int Gpu, Port; public static byte Addr; public static uint Speed;
    public static int Init() {
        var init = (InitFn)Marshal.GetDelegateForFunctionPointer(QueryInterface(0x0150E828), typeof(InitFn));
        int s = init(); if (s != 0) return s;
        var en = (EnumFn)Marshal.GetDelegateForFunctionPointer(QueryInterface(0xE5AC921F), typeof(EnumFn));
        s = en(gpus, out Count); if (s != 0) return s;
        readEx = (I2cFn)Marshal.GetDelegateForFunctionPointer(QueryInterface(0x4D7B0709), typeof(I2cFn));
        writeEx = (I2cFn)Marshal.GetDelegateForFunctionPointer(QueryInterface(0x283AC65A), typeof(I2cFn));
        return 0;
    }
    // NV_I2C_INFO_V3 (64 bytes) exactly as Precision X1's ManagedNvApi fills it, plus i2cSpeedKhz@48.
    static int Xfer(bool write, byte reg, byte[] data) {
        IntPtr info = Marshal.AllocHGlobal(64), ex = Marshal.AllocHGlobal(8);
        IntPtr pReg = Marshal.AllocHGlobal(1), pData = Marshal.AllocHGlobal(Math.Max(1, data.Length));
        try {
            for (int i = 0; i < 64; i++) Marshal.WriteByte(info, i, 0);
            Marshal.WriteInt64(ex, 0);
            Marshal.WriteByte(pReg, reg);
            if (write) Marshal.Copy(data, 0, pData, data.Length);
            Marshal.WriteInt32(info, 0, 64 | (3 << 16));
            Marshal.WriteByte(info, 9, Addr);
            Marshal.WriteInt64(info, 16, pReg.ToInt64());
            Marshal.WriteInt32(info, 24, 1);
            Marshal.WriteInt64(info, 32, pData.ToInt64());
            Marshal.WriteInt32(info, 40, data.Length);
            Marshal.WriteInt32(info, 44, 0xFFFF);
            Marshal.WriteInt32(info, 48, (int)Speed);
            if (Port != 0) { Marshal.WriteByte(info, 52, (byte)Port); Marshal.WriteInt32(info, 56, 1); }
            int s = write ? writeEx(gpus[Gpu], info, ex) : readEx(gpus[Gpu], info, ex);
            if (!write) Marshal.Copy(pData, data, 0, data.Length);
            return s;
        } finally {
            Marshal.FreeHGlobal(info); Marshal.FreeHGlobal(ex); Marshal.FreeHGlobal(pReg); Marshal.FreeHGlobal(pData);
        }
    }
    public static bool Read(byte reg, byte[] data) { return Xfer(false, reg, data) == 0; }
    public static bool Write(byte reg, byte[] data) { return Xfer(true, reg, data) == 0; }
}
'@
Add-Type -TypeDefinition $src
[NvI2c]::Gpu = $Gpu; [NvI2c]::Port = $Port; [NvI2c]::Addr = [byte]$Addr; [NvI2c]::Speed = [uint32]$Speed
$st = [NvI2c]::Init()
if ($st -ne 0) { Say "NvAPI init failed status=$st"; exit 1 }
Say "NvAPI ok, gpus=$([NvI2c]::Count), gpu=$Gpu port=$Port addr=0x$('{0:X2}' -f $Addr) speed=$Speed log=$Log"

function Hex([byte[]]$b) { ($b | ForEach-Object { '{0:X2}' -f $_ }) -join ' ' }
# Library retry semantics: reads up to 5 tries / 5 ms, writes up to 100 tries / 50 ms.
function McuRead([byte]$reg, [int]$len) {
    for ($i = 0; $i -lt 5; $i++) { $b = [byte[]]::new($len); if ([NvI2c]::Read($reg, $b)) { return ,$b }; Start-Sleep -Milliseconds 5 }
    return $null
}
function McuWrite([byte]$reg, [byte[]]$payload) {
    for ($i = 0; $i -lt 100; $i++) { if ([NvI2c]::Write($reg, $payload)) { return $true }; Start-Sleep -Milliseconds 50 }
    return $false
}
function ReadInfo {
    $b = McuRead 0xB1 6
    if ($null -eq $b) { return $null }
    $o = [pscustomobject]@{ Raw = (Hex $b); Valid = ($b[0] -eq 5 -and $b[1] -eq 0xFC); Slave = $b[2]; ID = $b[3]; Major = $b[4]; Minor = $b[5] }
    return $o
}
function EnableWrite {
    if (-not (McuWrite 0xB2 ([byte[]](4, 0xC6, 0xEB, 0xEA, 0x15)))) { return $false }
    $b = McuRead 0xB2 5
    return ($null -ne $b -and $b[0] -eq 4 -and $b[1] -eq 0xFC)
}

$info = ReadInfo
if ($null -eq $info -or -not $info.Valid) { Say "ReadInformation invalid: $($info.Raw)"; exit 2 }
Say ("Info: raw={0} slave=0x{1:X2} productID={2} version={3}.{4}" -f $info.Raw, $info.Slave, $info.ID, $info.Major, $info.Minor)
$cfg = McuRead 0xBA 10
if ($null -ne $cfg -and $cfg[1] -eq 0xBA) {
    Say ("Config: raw={0} IAP={1} AP={2} sector={3} page={4}" -f (Hex $cfg), [BitConverter]::ToUInt16($cfg, 2), [BitConverter]::ToUInt16($cfg, 4), [BitConverter]::ToUInt16($cfg, 6), [BitConverter]::ToUInt16($cfg, 8))
} else { Say "Config read failed: $(if ($cfg) { Hex $cfg })" }
if ($Mode -eq 'info') { exit 0 }

# ---------------- flash ----------------
if (-not (Test-Path $File)) { Say "file not found: $File"; exit 3 }
$img = [IO.File]::ReadAllBytes($File)
$sectors = [int][Math]::Ceiling($img.Length / 32768.0)
if ($sectors -gt 6) { Say "image too large: $($img.Length) bytes"; exit 3 }
Say "Image $File : $($img.Length) bytes, $sectors sector(s); SP=0x$('{0:X8}' -f [BitConverter]::ToUInt32($img,0)) Reset=0x$('{0:X8}' -f [BitConverter]::ToUInt32($img,4))"

$iapIds = 160, 161, 162, 164, 165
if ($iapIds -notcontains $info.ID) {
    $ok = $false; for ($i = 0; $i -lt 10 -and -not $ok; $i++) { $ok = EnableWrite }
    if (-not $ok) { Say "STATUS_ENABLE_WRITE_FAILED"; exit 4 }
    Say "EnableWrite ok"
    if (-not (McuWrite 0xA9 ([byte[]](4, 0xAA, 0xEB, 0x55, 0x66)))) { Say "STATUS_ENTER_IAP_MODE_FAILED (write)"; exit 4 }
    Start-Sleep -Milliseconds 500
    Say "EnterIAPMode sent"
}
$info2 = ReadInfo
Say ("Info after IAP entry: raw={0} productID={1} version={2}.{3}" -f $info2.Raw, $info2.ID, $info2.Major, $info2.Minor)
if ($iapIds -notcontains $info2.ID) {
    if ($info2.ID -eq 1) { Say "STATUS_ENTER_IAP_MODE_FAILED_STILL_IN_E221_XC3" } else { Say "STATUS_ENTER_IAP_MODE_FAILED_INVALID_ID" }
    exit 5
}
$ok = $false; for ($i = 0; $i -lt 10 -and -not $ok; $i++) { $ok = EnableWrite }
if (-not $ok) { Say "STATUS_ENABLE_WRITE_FAILED (bootloader)"; exit 6 }
Say "Bootloader: EnableWrite ok"

$t0 = Get-Date
for ($k = 0; $k -lt $sectors; $k++) {
    $sec = $k + 1
    if (-not (McuWrite 0xB4 ([byte[]](4, 0xBA, $sec, 0xEB, 0x55)))) { Say "STATUS_ERASE_SECTOR_FAILED (write) sector $sec"; exit 7 }
    Start-Sleep -Milliseconds 200
    $e = McuRead 0xB4 5
    if ($null -eq $e -or $e[0] -ne 4 -or $e[1] -ne 0xFC -or $e[2] -ne $sec) { Say "STATUS_ERASE_SECTOR_FAILED sector $sec reply=$(if ($e) { Hex $e })"; exit 7 }
    $addr = [uint32](32768 + $k * 32768)
    $set = $false
    for ($r = 0; $r -lt 10 -and -not $set; $r++) {
        $ab = [BitConverter]::GetBytes($addr)
        if (McuWrite 0xB6 ([byte[]](4, $ab[0], $ab[1], $ab[2], $ab[3]))) {
            $g = McuRead 0xB6 5
            if ($null -ne $g -and $g[0] -eq 4 -and [BitConverter]::ToUInt32($g, 1) -eq $addr) { $set = $true }
        }
    }
    if (-not $set) { Say "STATUS_SET_FLASH_ADDRESS_FAILED 0x$('{0:X}' -f $addr)"; exit 8 }
    if (-not (McuWrite 0xB5 ([byte[]](5, 0xBA, 0, 0, 0, 0)))) { Say "STATUS_RESET_CHECKSUM_FAILED"; exit 9 }
    Say ("Sector {0}: erased, address 0x{1:X5}, checksum reset" -f $sec, $addr)
    [uint32]$sum = 0
    for ($m = 0; $m -lt 1024; $m++) {
        $off = $k * 32768 + $m * 32
        $n = [Math]::Min(32, $img.Length - $off)
        if ($n -le 0) { break }
        $pkt = [byte[]]::new(33); $pkt[0] = 0x20
        for ($j = 0; $j -lt $n; $j++) { $pkt[1 + $j] = $img[$off + $j]; $sum = [uint32](($sum + $img[$off + $j]) -band 0xFFFFFFFF) }
        $done = $false
        for ($r = 0; $r -lt 100 -and -not $done; $r++) {
            if (McuWrite 0xB7 $pkt) {
                Start-Sleep -Milliseconds 5
                $c = McuRead 0xB5 6
                if ($null -eq $c -or $c[0] -ne 5 -or $c[1] -ne 0xFC) { Say "STATUS_READ_CHECKSUM_FAILED at 0x$('{0:X5}' -f ($addr + $m*32)) reply=$(if ($c) { Hex $c })"; exit 10 }
                $mcuSum = [BitConverter]::ToUInt32($c, 2)
                if ($mcuSum -ne $sum) { Say ("STATUS_CHECKSUM_ERROR at 0x{0:X5}: mcu={1} host={2}" -f ($addr + $m*32), $mcuSum, $sum); exit 11 }
                $done = $true
            }
        }
        if (-not $done) { Say "STATUS_SET_FLASH_DATA_FAILED at 0x$('{0:X5}' -f ($addr + $m*32))"; exit 12 }
        if ($m % 128 -eq 127) { Say ("  sector {0}: {1}/1024 blocks, {2:N0} s" -f $sec, ($m + 1), ((Get-Date) - $t0).TotalSeconds) }
    }
    $c = McuRead 0xB5 6
    if ($null -eq $c -or [BitConverter]::ToUInt32($c, 2) -ne $sum) { Say "STATUS_CHECKSUM_ERROR end of sector $sec"; exit 11 }
    Say ("Sector {0} done, checksum {1}" -f $sec, $sum)
}
if (-not (McuWrite 0xB9 ([byte[]](4, 0xAA, 0xEB, 0x55, 0x66)))) { Say "STATUS_FLASH_AP_COMPLETE_FAILED"; exit 13 }
Start-Sleep -Milliseconds 1500
$info3 = ReadInfo
Say ("STATUS_SUCCESS in {0:N0} s. Info now: raw={1} productID={2} version={3}.{4}" -f ((Get-Date) - $t0).TotalSeconds, $info3.Raw, $info3.ID, $info3.Major, $info3.Minor)
