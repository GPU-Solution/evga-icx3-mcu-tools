"""build_image.py - patch the LPC51U68 ROM checksum into the stand-in bootloader and merge it
with an EVGA application image into one flash image for SWD programming.

Usage: python build_image.py <boot.bin> <app.bin> <out.bin>
Layout: 0x0000 bootloader | 0xFF padding | 0x8000 application. The boot flag at 0x10000 is
whatever the application image holds there (0xFFFFFFFF in the EVGA images = run application).
Refuses to write anything at the CRP word (0x2FC) other than 0xFFFFFFFF.
"""
import struct
import sys

APP_BASE = 0x8000
CRP_ADDR = 0x2FC
BOOT_FLAG = 0x10000

boot = bytearray(open(sys.argv[1], "rb").read())
app = open(sys.argv[2], "rb").read()

words = struct.unpack_from("<7I", boot, 0)
checksum = (-sum(words)) & 0xFFFFFFFF
struct.pack_into("<I", boot, 0x1C, checksum)
assert sum(struct.unpack_from("<8I", boot, 0)) & 0xFFFFFFFF == 0

if len(boot) > CRP_ADDR:
    raise SystemExit("bootloader reaches the CRP word at 0x2FC")

image = bytearray(b"\xff" * (APP_BASE + len(app)))
image[:len(boot)] = boot
image[APP_BASE:] = app

flag = struct.unpack_from("<I", image, BOOT_FLAG)[0] if len(image) > BOOT_FLAG + 3 else None
crp = struct.unpack_from("<I", image, CRP_ADDR)[0]
open(sys.argv[3], "wb").write(image)
print(f"boot {len(boot)} B, checksum 0x{checksum:08x}; app {len(app)} B at 0x{APP_BASE:x}")
print(f"image {len(image)} B; CRP word 0x{crp:08x}; boot flag @0x10000 = "
      + (f"0x{flag:08x}" if flag is not None else "beyond image (erased)"))
