# iCX3 application image layout and bootloader contract (LPC51U68)

From disassembling EVGA's application images (`*_AP_R*.bin` shipped with Precision X1), e.g.
`FTW_3Fans_AP_R118.bin` / `R122.bin` (Keil-built, Cortex-M0+).

## Flash map

| Range | Content |
|---|---|
| `0x00000`-`0x07FFF` | Sector 0: EVGA bootloader (not distributed; never written by the updater) |
| `0x08000`-... | Application image (`*_AP_*.bin` is exactly this region, no header) |
| `0x10000` | **Boot flag** word inside the application image, `FF FF FF FF` in every image |
| `0x3FE00` | Application settings page (magic `0x0112` at the start; created by the application if missing) |

Sectors are 32 KB, pages 256 B, total 256 KB (matches ReadConfiguration: 32 KB bootloader, 192 KB app).

## What the application expects from the bootloader

Practically nothing:

- Vector table at `0x8000` (SP `0x20010000`, reset handler around `0x81CD`). `SystemInit` only does
  `SCB->VTOR = 0x8000`; clocks, peripherals and the settings page are set up by the application itself.
- No branches into, and no reads from, `0x0000`-`0x7FFF`.
- Flash is written through the NXP ROM IAP entry (`0x03000205`, commands 50/51/52/59).

So a minimal loader that sets MSP from `0x8000` and jumps to `[0x8004]` is enough to run it.

## Boot flag and update entry

- "Enter bootloader" (frame `04 AA EB 55 66` on register `0xA9`, after EnableWrite; see
  [i2c-protocol.md](i2c-protocol.md)): the application prepares sector 2, erases the page at `0x10000`,
  writes `20 20 E0 E0` there and resets. The bootloader then stays in update mode (ProductID 160).
- ResetSystem (`04 BB EB 55 66` on register `0xBB`) just resets.
- Because the flag page is erased, an interrupted update leaves the application unusable but the
  bootloader intact: re-run the update.

## Blank chips and the stand-in bootloader

A new LPC51U68 needs something at `0x0000`. The LPC51U68 boot ROM only starts user code when word
`0x1C` holds the two's complement of the sum of words `0x00`-`0x18` (the first 8 words add up to 0);
otherwise it enters ISP. [`../bootloader/`](../bootloader/) contains a 100-byte loader that:

- checks the boot flag at `0x10000` is `0xFFFFFFFF` and that the application's SP/reset vector look
  valid, then jumps to it; otherwise sleeps (`WFI`);
- carries the ROM checksum (`build_image.py` patches it) and leaves the CRP word (`0x2FC`) erased.

It does **not** implement EVGA's I2C update protocol, so Precision X1 cannot update an MCU running it:
if PX1 sends "enter bootloader", the application erases its flag page and the MCU stays parked until it
is reprogrammed over SWD or ISP. It was built and checked with `arm-none-eabi-gcc` but **never run on
hardware**. Prefer copying a full flash image from a working MCU when you can.
