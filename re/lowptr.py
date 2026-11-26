"""lowptr.py - find literals below the app base that the code dereferences (reads/writes memory at them).

Usage: python lowptr.py <objdump.dis> <image.bin> [base=0x8000]
For every `ldr rX, [pc, #..] @ (0xPOOL)` whose pool word is in 0x0..base, looks at the next 6
instructions for a memory access through rX ([rX] / [rX, #imm]). Those are reads/writes into the
bootloader flash region; plain arithmetic constants are ignored.
"""
import re
import struct
import sys

dis, image = sys.argv[1], sys.argv[2]
base = int(sys.argv[3], 16) if len(sys.argv) > 3 else 0x8000
img = open(image, "rb").read()
lines = [l.rstrip("\n") for l in open(dis, encoding="latin-1")]
pat = re.compile(r"^\s+([0-9a-f]+):\s+(?:[0-9a-f]{4}\s?){1,2}\s+(\S+)\s+(.*)$")
parsed = []
for l in lines:
    m = pat.match(l)
    if m:
        parsed.append((int(m.group(1), 16), m.group(2), m.group(3)))

for i, (addr, mn, ops) in enumerate(parsed):
    m = re.match(r"(r\d+), \[pc, #\d+\]\s+@ \((0x[0-9a-f]+)\)", ops)
    if mn != "ldr" or not m:
        continue
    reg, pool = m.group(1), int(m.group(2), 16)
    off = pool - base
    if not 0 <= off <= len(img) - 4:
        continue
    val = struct.unpack_from("<I", img, off)[0]
    if not 0 < val < base:
        continue
    for a2, mn2, ops2 in parsed[i + 1:i + 7]:
        if re.search(rf"\[{reg}(,|\])", ops2) and mn2.startswith(("ldr", "str")):
            print(f"0x{addr:x}: {reg}=0x{val:x} -> 0x{a2:x} {mn2} {ops2}")
            break
        if re.match(rf"{reg},", ops2):  # register overwritten
            break
