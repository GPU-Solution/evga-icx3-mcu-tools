# EVGA iCX3 MCU tools (RTX 30 series)

Notes and tools for repairing the **iCX3 microcontroller** on EVGA GeForce RTX 30 cards (XC3, FTW3,
KINGPIN, Hybrid, Hydro Copper): the small MCU that drives the fans, the RGB and the extra iCX
temperature sensors, and that Precision X1 talks to.

Everything here comes from one real repair (an RTX 3090 FTW3 Ultra whose MCU had been burnt and was
replaced by a chip salvaged from an XC3), plus reverse engineering of Precision X1 and of the MCU
firmware images it ships. It is written so the next person does not have to repeat it.

> Not affiliated with EVGA, NVIDIA or NXP. Use at your own risk. This repository contains **no EVGA
> files**: no firmware images, no Precision X1 binaries, no decompiled source. The tools work on the
> files you already have installed.

## Symptoms this helps with

| Symptom | Likely cause | See |
|---|---|---|
| Precision X1 closes a few seconds after opening. Event Viewer, Application, `.NET Runtime`: `System.NullReferenceException at PX18.Monitors.RTX30.iCX3ExtTemp..ctor` | PX1 reads the MCU, gets invalid data, never wires its sensor callbacks and crashes on the first one | [docs/precision-x1-behaviour.md](docs/precision-x1-behaviour.md) |
| Precision X1 opens for a second and closes **without any error**, and a "Firmware Update" window appears | PX1 read the MCU fine and decided it carries the wrong firmware for this board; it launches `FirmwareUpdate.exe` and exits | [docs/ssid-firmware-map.md](docs/ssid-firmware-map.md) |
| `FirmwareUpdate.exe` / EVGA MCU Tool: "Firmware update failed. Click Start to try again." | The window hides the real error code (17 possible). Very often: the MCU does not answer correctly at the I2C speed PX1 uses | [docs/i2c-protocol.md](docs/i2c-protocol.md), `tools/icx3_speed.ps1` |
| The MCU answers `05 FF FF FF FF FF` to everything | The MCU only manages the reply at low I2C speed (clock stretching not reaching the GPU) | [Slow-I2C fix](#the-slow-i2c-problem-and-the-fix) |
| Replaced MCU: half of the RGB works, fans behave oddly | Donor MCU still runs the firmware of the card it came from (e.g. XC3 on an FTW3) | flash the right image, [docs/ssid-firmware-map.md](docs/ssid-firmware-map.md) |

## Quick facts

- MCU: **NXP LPC51U68JBD48** (LQFP48, Cortex-M0+, 256 KB flash) on the cards covered here. EVGA also
  shipped **LPC54113** and **STM32L431** variants (they have their own firmware images and ProductIDs).
- Bus: GPU I2C **port 1**, address **0x5A** (8-bit; 0x2D 7-bit). Precision X1 reaches it through NVAPI
  (`NvAPI_I2CReadEx` / `NvAPI_I2CWriteEx`) and only for cards with PCI subsystem vendor `0x3842`.
- Frame format: register byte, then `[length][payload...]`.
- Flash layout: EVGA bootloader in sector 0 (32 KB), application from `0x8000` (up to 192 KB),
  sectors of 32 KB, pages of 256 B. The update procedure never touches sector 0.
- The application identifies itself with a **ProductID** (2 = FTW3 E227/E228, 4 = FTW3 E230,
  1 = XC3 E221, ...) and the bootloader with **160** (`IAP`, LPC51U68). Full list in
  [docs/i2c-protocol.md](docs/i2c-protocol.md).
- **Which firmware a board needs is decided by its PCI subsystem ID**, not by the card family name.
  Precision X1 carries the official table: [docs/ssid-firmware-map.md](docs/ssid-firmware-map.md).
  Example: SSID `3842:3982` (RTX 3090 FTW3 Ultra) takes `FTW_3Fans_AP_R122.bin`, **not** the
  `FTW_E230_...376x` image (that one is for `3842:376x` boards).

## The slow-I2C problem and the fix

On the repaired card the MCU replied correctly only when the GPU read it at **33 kHz or slower**:

```
register 0xB1 (ReadInformation)
default speed / 100 kHz : 05 FF FF FF FF FF      <- only the first byte is real
33 / 10 / 3 kHz         : 05 FC 2D 02 01 16      <- valid: FTW3 (ProductID 2), firmware 1.22
```

At 100 kHz, selecting the register and reading it in two separate transactions with 0-5 ms in between
also works, so the MCU can transmit at 100 kHz; what fails is the combined write/repeated-start/read
that Precision X1 uses. The MCU needs a moment to prepare its reply and stretches SCL for it; on this
card the GPU does not see that stretch, so it samples a released SDA line (`FF`). The behaviour was the
same with three different firmware images (XC3 1.12, FTW3-E230 1.10, FTW3 1.22) and with NVIDIA drivers
610.88 and 621.40. Whether the cause is on the board (something on the SCL path between MCU and GPU) or
on the GPU/driver side was **not** determined; a healthy card in the same machine would settle it.

Fix used, two parts:

1. **Flash the MCU at 33 kHz** with [`tools/icx3_flash.ps1`](tools/icx3_flash.ps1) (same sequence as
   EVGA's updater, but with a selectable speed).
2. **Make Precision X1 use 33 kHz** with [`tools/patch_px1_i2c_speed.ps1`](tools/patch_px1_i2c_speed.ps1):
   it changes two IL constants in the installed `ManagedNvApi.dll` (the `i2cSpeedKhz` field of
   `NV_I2C_INFO_V3`, read and write paths) from "default" to 33 kHz, in both copies
   (`Precision X1\` and `Precision X1\Library\`), keeping `.orig` backups. Tested with PX1 1.3.6.0 and
   1.3.7.0. After it, PX1 opens normally, shows the iCX panel and the three fans.

The patch has to be applied on every PC where Precision X1 runs with that card, and again after
reinstalling or updating Precision X1.

## Tools

All PowerShell tools run on Windows PowerShell 5.1 with the NVIDIA driver installed. Close Precision X1
and FirmwareUpdate before using them, so only one program talks to the MCU.

| Tool | What it does |
|---|---|
| [`tools/icx3_speed.ps1`](tools/icx3_speed.ps1) | Reads the MCU identification at several I2C speeds. Read-only. First thing to run. |
| [`tools/icx3_split.ps1`](tools/icx3_split.ps1) | Same read, but register select and data read as two transactions with a delay. Read-only. |
| [`tools/icx3_flash.ps1`](tools/icx3_flash.ps1) | `-Mode info`: identification + flash configuration. `-Mode flash -File <ap.bin>`: full application update at 33 kHz, verified block by block with the MCU checksum. |
| [`tools/patch_px1_i2c_speed.ps1`](tools/patch_px1_i2c_speed.ps1) | Patches Precision X1 to use a fixed I2C speed; `-Restore` undoes it. |
| [`bootloader/`](bootloader/) | Experimental stand-in bootloader for a **blank** LPC51U68 (not tested on hardware). |
| [`re/`](re/) | Small scripts used to analyse the application images (vector table, cross references). |

Firmware images: take them from your own installation, `C:\Program Files\EVGA\Precision X1\Firmware\`.
Precision X1 1.3.7.0 (October 2022) is the last release; its MCU images are identical to 1.3.6.0's.

## Replacing the MCU: what we learned

- A **salvaged** MCU (from another EVGA RTX 30 card) keeps EVGA's bootloader, so it can be re-flashed
  over I2C with the right image. Read it first with `icx3_flash.ps1 -Mode info` to see what it runs.
- A **new** LPC51U68 from a distributor is blank. EVGA's updater cannot reach it: it needs EVGA's
  bootloader, which is not distributed. Options: copy the whole flash of a working MCU (SWD or the NXP
  ROM ISP, only if that MCU has no code-read protection) or use the experimental stand-in bootloader
  in [`bootloader/`](bootloader/), which boots EVGA's application but cannot receive updates from
  Precision X1. See [docs/firmware-layout.md](docs/firmware-layout.md) and
  [docs/lpc51u68-isp.md](docs/lpc51u68-isp.md).
- The LPC51U68 cannot really be bricked: its mask-ROM ISP (USART, I2C, SPI or USB mass storage)
  always works unless CRP3 is set.
- Before blaming the firmware, check what killed the old MCU. On this card the original MCU had a hole
  burnt in it; the fan-header area is a usual suspect.

## Documentation

- [docs/i2c-protocol.md](docs/i2c-protocol.md): registers, frame formats, update sequence, status codes, ProductIDs.
- [docs/precision-x1-behaviour.md](docs/precision-x1-behaviour.md): how PX1 detects, checks and updates the MCU, and why it crashes.
- [docs/ssid-firmware-map.md](docs/ssid-firmware-map.md): official subsystem ID → firmware table (PX1 1.3.7.0).
- [docs/firmware-layout.md](docs/firmware-layout.md): application image layout and bootloader contract.
- [docs/lpc51u68-isp.md](docs/lpc51u68-isp.md): LQFP48 pins, ROM ISP modes, CRP.

## Tested on

- EVGA GeForce RTX 3090 FTW3 Ultra (`10DE:2204`, SSID `3842:3982`), MCU LPC51U68JBD48 salvaged from an
  RTX 30 XC3 (it arrived with XC3 E221 firmware 1.12).
- Windows 11, NVIDIA drivers 610.88 and 621.40, Precision X1 1.3.6.0 and 1.3.7.0.

## License

MIT for the code and documentation in this repository. EVGA, Precision X1, iCX, NVIDIA and NXP names
belong to their owners.
