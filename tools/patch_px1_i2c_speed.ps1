<#
.SYNOPSIS
  Make EVGA Precision X1 talk to the iCX3 MCU at a fixed, slower I2C speed.

.DESCRIPTION
  Precision X1 (and its Library\FirmwareUpdate.exe) reach the iCX3 MCU through ManagedNvApi.dll, which
  fills NV_I2C_INFO_V3 with i2cSpeedKhz = 0 (NVI2C_SPEED_DEFAULT) in getNormalRead and setNormalWrite.
  On boards where the MCU only answers correctly at <= 33 kHz (it replies "05 FF FF FF ..." at the
  default speed), Precision X1 crashes on start and FirmwareUpdate reports "Firmware update failed".

  This script patches the two IL instructions that load that 0 so they load the chosen speed instead.
  It does not ship any EVGA file: it patches the ManagedNvApi.dll already installed on this PC, after
  locating the exact IL sequence, and keeps a .orig backup next to each patched file.

  IL sequence (inside the NV_I2C_INFO_V3 setup):
      ldc.i4.s 44 ; add ; ldc.i4 0xFFFF ; stind.i4      -> i2cSpeed  = 0xFFFF
      ldloca.s N ; ldc.i4.s 48 ; add ; ldc.i4.<v> ; stind.i4   -> i2cSpeedKhz = <v>
  Exactly two occurrences are expected (read and write); anything else aborts without writing.

  NV_I2C_SPEED values: 0 default, 1 = 3 kHz, 2 = 10 kHz, 3 = 33 kHz, 4 = 100 kHz, 5 = 200 kHz, 6 = 400 kHz.

.PARAMETER Speed
  NV_I2C_SPEED value to write (default 3 = 33 kHz). 0 puts back the stock behaviour.

.PARAMETER Restore
  Copy the .orig backups back over the patched files.

.PARAMETER Px1Dir
  Precision X1 install folder (default "C:\Program Files\EVGA\Precision X1").

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File patch_px1_i2c_speed.ps1            # patch to 33 kHz
  powershell -ExecutionPolicy Bypass -File patch_px1_i2c_speed.ps1 -Restore   # undo

.NOTES
  Tested with Precision X1 1.3.6.0 and 1.3.7.0. Run from an elevated PowerShell (writes to Program Files).
  Re-run after reinstalling or updating Precision X1.
#>
param(
    [ValidateRange(0, 6)] [int]$Speed = 3,
    [switch]$Restore,
    [string]$Px1Dir = (Join-Path $env:ProgramFiles 'EVGA\Precision X1')
)
$ErrorActionPreference = 'Stop'

$running = Get-Process PrecisionX_x64, FirmwareUpdate -ErrorAction SilentlyContinue
if ($running) { throw "Close Precision X1 / FirmwareUpdate first (running: $($running.Name -join ', '))." }

$targets = @('ManagedNvApi.dll', 'Library\ManagedNvApi.dll') |
    ForEach-Object { Join-Path $Px1Dir $_ } | Where-Object { Test-Path $_ }
if (-not $targets) { throw "No ManagedNvApi.dll found under '$Px1Dir'." }

if ($Restore) {
    foreach ($t in $targets) {
        $orig = "$t.orig"
        if (Test-Path $orig) { Copy-Item -Force $orig $t; "restored $t" } else { "no backup for $t (left as is)" }
    }
    return
}

$prefix = [byte[]](0x1F, 0x2C, 0x58, 0x20, 0xFF, 0xFF, 0x00, 0x00, 0x54, 0x12)
$suffix = [byte[]](0x1F, 0x30, 0x58)
foreach ($t in $targets) {
    $b = [IO.File]::ReadAllBytes($t)
    $hits = New-Object System.Collections.Generic.List[int]
    for ($i = 0; $i -le $b.Length - 16; $i++) {
        $ok = $true
        for ($j = 0; $j -lt $prefix.Length; $j++) { if ($b[$i + $j] -ne $prefix[$j]) { $ok = $false; break } }
        if (-not $ok) { continue }
        # $b[$i+10] is the ldloca.s operand (any local index)
        for ($j = 0; $j -lt $suffix.Length; $j++) { if ($b[$i + 11 + $j] -ne $suffix[$j]) { $ok = $false; break } }
        if (-not $ok) { continue }
        $v = $b[$i + 14]
        if ($v -ge 0x16 -and $v -le 0x1C -and $b[$i + 15] -eq 0x54) { $hits.Add($i + 14) }
    }
    if ($hits.Count -ne 2) { throw "$t : expected 2 i2cSpeedKhz stores, found $($hits.Count). Unknown build - not patched." }
    $old = ($hits | ForEach-Object { $b[$_] - 0x16 }) -join ','
    $new = [byte](0x16 + $Speed)
    if (-not (Test-Path "$t.orig")) { Copy-Item $t "$t.orig" }
    foreach ($h in $hits) { $b[$h] = $new }
    [IO.File]::WriteAllBytes($t, $b)
    "{0}: i2cSpeedKhz {1} -> {2} at offsets {3}" -f $t, $old, $Speed, (($hits | ForEach-Object { '0x{0:X}' -f $_ }) -join ', ')
}
