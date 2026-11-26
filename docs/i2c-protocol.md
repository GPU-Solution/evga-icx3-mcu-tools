# iCX3 MCU I2C protocol

Observed on an RTX 3090 FTW3 Ultra and derived from how Precision X1 1.3.6/1.3.7 talks to the MCU.

## Transport

- NVAPI `NvAPI_I2CReadEx` (interface ID `0x4D7B0709`) and `NvAPI_I2CWriteEx` (`0x283AC65A`), with an
  `NV_I2C_INFO_V3` structure (64 bytes, version `64 | 3 << 16`):

  | Offset | Field | Precision X1 value |
  |---|---|---|
  | 0 | version | `0x00030040` |
  | 8 | bIsDDCPort | 0 |
  | 9 | i2cDevAddress | `0x5A` (8-bit) |
  | 16 | pbI2cRegAddress | pointer to the 1-byte register |
  | 24 | regAddrSize | 1 |
  | 32 | pbData | pointer to the payload |
  | 40 | cbSize | payload length |
  | 44 | i2cSpeed (deprecated) | `0xFFFF` |
  | 48 | **i2cSpeedKhz** | **0 = default** (1 = 3 kHz, 2 = 10 kHz, 3 = 33 kHz, 4 = 100 kHz, 5 = 200 kHz, 6 = 400 kHz) |
  | 52 | portId | 1 |
  | 56 | bIsPortIdSet | 1 |

- A read is a combined transaction: write the register byte, repeated start, read `cbSize` bytes.
- Precision X1 only creates its MCU object when the card's PCI subsystem vendor is `0x3842` (EVGA).

## Frames

Every command is a register number followed by `[length][payload...]`; every reply starts with its
length. Reads that return status use `0xFC` as "OK".

## Identification and configuration

| Register | Name | Reply | Example |
|---|---|---|---|
| `0xB1` | ReadInformation | `05 FC <slave> <productID> <major> <minor>` | `05 FC 2D 02 01 16` = slave 0x2D, FTW3, v1.22 |
| `0xBA` | ReadConfiguration | `09 BA <IAP KB, u16> <AP KB, u16> <sector KB, u16> <page B, u16>` | `09 BA 20 00 C0 00 20 00 00 01` = 32 KB bootloader, 192 KB app, 32 KB sectors, 256 B pages |

Precision X1 only accepts ReadInformation when byte 0 is 5 and byte 1 is `0xFC`. Otherwise it treats
the reply as empty (ProductID 255), see [precision-x1-behaviour.md](precision-x1-behaviour.md).

## ProductIDs

| ID | Meaning | ID | Meaning |
|---|---|---|---|
| 1 | E221/E222 XC3 | 17 | E222 XC3 (LPC54113) |
| 2 | E227/E228 FTW3 | 18 | E227/E228 FTW3 (LPC54113) |
| 3 | E223 KINGPIN Hybrid | 19 | E251 KINGPIN Hybrid |
| 4 | E230 FTW3 | 20 | E230 FTW3 (LPC54113) |
| 5 | E229 XC3 | 21 | E229 XC3 (LPC54113) |
| 6 | E221/E222 XC3 Hybrid | 24 | E227/E228 FTW3 Hybrid (LPC54113) |
| 7 | E221/E222 XC3 Hydro Copper | 26 | E251 KINGPIN Hydro Copper |
| 8 | E227/E228 FTW3 Hybrid | 33 | E221 XC3 (STM32L431) |
| 9 | E227/E228 FTW3 Hydro Copper | 36 | E230/E238 FTW3 (STM32L431) |
| 10 | E223 KINGPIN Hydro Copper | 37 | E229/E237 XC3 (STM32L431) |
| 50 | E250 FTW3 | 56 | E250 FTW3 Hybrid |
| **160** | **bootloader (IAP), LPC51U68** | 161 | bootloader, KINGPIN |
| 162 | bootloader, LPC54113 | 163 | bootloader, STM32L431 |
| 164 | bootloader, LPC5516 | 165 | bootloader, KINGPIN E251 |

The LPC51U68 bootloader seen here answered `05 FC 2D A0 00 05` (ID 160, version 0.5).

## Firmware update sequence (application in sectors 1..N)

| Step | Register | Write | Check |
|---|---|---|---|
| Enable write | `0xB2` | `04 C6 EB EA 15` | read `0xB2`: `04 FC ..` |
| Enter bootloader | `0xA9` | `04 AA EB 55 66`, wait 500 ms | `0xB1` must now report a bootloader ID (160..165) |
| Enable write (again, in bootloader) | `0xB2` | `04 C6 EB EA 15` | `04 FC ..` |
| Erase sector k (1..6) | `0xB4` | `04 BA k EB 55`, wait 200 ms | read `0xB4`: `04 FC k ..` |
| Set address | `0xB6` | `04 <address, u32 LE>` (`0x8000 + (k-1) * 0x8000`) | read `0xB6` returns the same address |
| Reset checksum | `0xB5` | `05 BA 00 00 00 00` | |
| Write 32 bytes | `0xB7` | `20 <32 bytes>` (last block zero-padded), wait 5 ms | read `0xB5`: `05 FC <sum, u32 LE>` = running byte sum of the sector |
| Back to application | `0xB9` | `04 AA EB 55 66`, wait 500 ms | `0xB1` reports the application ID |

Other registers seen in Precision X1: `0xBB` ResetSystem (`04 BB EB 55 66`), `0xB0` LoopBack (32-byte
echo), `0xB3` EraseAP, `0x50` FanControl, `0x65`/`0x66` thermistor temperatures, `0x20`/`0x21` INA3221
power monitor, `0xC0`-`0xFA` LED effects.

On the application side the "enter bootloader" command erases the 256-byte page at `0x10000`, writes
`20 20 E0 E0` there (the boot flag) and resets; see [firmware-layout.md](firmware-layout.md).

## Updater status codes

`FirmwareUpdate.exe` retries the whole update up to 10 times and only shows "Firmware update failed".
The codes it discards are, in order: `SUCCESS`, `INITIALIZE_FAILED`, `FILE_NOT_FOUND`, `INVALID_FILE`
(more than 6 sectors), `ENABLE_WRITE_FAILED`, `READ_INFORMATION_FAILED`, `ERASE_SECTOR_FAILED`,
`SET_FLASH_ADDRESS_FAILED`, `SET_FLASH_DATA_FAILED`, `FLASH_AP_COMPLETE_FAILED`, `RESET_SYSTEM_FAILED`,
`ENTER_IAP_MODE_FAILED`, `ENTER_IAP_MODE_FAILED_STILL_IN_E221_XC3`, `ENTER_IAP_MODE_FAILED_INVALID_ID`,
`RESET_CHECKSUM_FAILED`, `READ_CHECKSUM_FAILED`, `CHECKSUM_ERROR`.
`tools/icx3_flash.ps1` prints the equivalent status at the step where it stops.

With an MCU that replies `05 FF FF ...` at the default speed, the updater ends in
`ENTER_IAP_MODE_FAILED_INVALID_ID` (it never reads a bootloader ID), before sending any firmware byte.
