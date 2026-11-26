# Stand-in bootloader for a blank LPC51U68 (experimental, not tested on hardware)

100-byte loader placed at `0x0000` that starts an EVGA iCX3 application image linked at `0x8000`.
Background: [../docs/firmware-layout.md](../docs/firmware-layout.md).

- Boots the application when the boot flag at `0x10000` is `0xFFFFFFFF` and its SP/reset vector look
  sane; otherwise parks in `WFI`.
- Contains the LPC51U68 ROM checksum (word `0x1C`), patched by `build_image.py`.
- Leaves the CRP word (`0x2FC`) erased.
- Does **not** speak EVGA's I2C update protocol: Precision X1 cannot update an MCU running it.

Build (GNU Arm Embedded toolchain):

```
arm-none-eabi-gcc -mcpu=cortex-m0plus -mthumb -nostdlib -nostartfiles -T boot.ld -o boot.elf boot.S
arm-none-eabi-objcopy -O binary boot.elf boot.bin
python build_image.py boot.bin "C:\Program Files\EVGA\Precision X1\Firmware\<image>.bin" flash_image.bin
```

`flash_image.bin` is a flash image starting at `0x0000`, ready for SWD or ROM ISP
([../docs/lpc51u68-isp.md](../docs/lpc51u68-isp.md)). If you can read the full flash of a working MCU
(no CRP), that copy is a better choice than this loader.
