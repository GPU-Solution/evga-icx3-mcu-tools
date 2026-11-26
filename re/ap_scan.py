"""ap_scan.py - first-pass analysis of an EVGA iCX MCU application image (LPC51U68, Cortex-M0+).

Usage: python ap_scan.py <image.bin> [base=0x8000]
Prints the vector table, then every aligned 32-bit word that looks like an address outside the
application (bootloader flash < base, flash above the image, ROM 0x03000000, SYSCON/peripherals,
SCB registers), and every BL/B whose target falls below the base. Words in data/literal pools are
what the code loads with LDR, so this shows which external addresses the application touches.
"""
import struct
import sys
from collections import defaultdict

from capstone import CS_ARCH_ARM, CS_MODE_THUMB, Cs

path = sys.argv[1]
base = int(sys.argv[2], 16) if len(sys.argv) > 2 else 0x8000
img = open(path, "rb").read()
end = base + len(img)

names = ["SP", "Reset", "NMI", "HardFault", "r4", "r5", "r6", "r7", "r8", "r9", "r10",
         "SVCall", "r12", "r13", "PendSV", "SysTick"]
print(f"image {path}: {len(img)} bytes, assumed base 0x{base:x}..0x{end:x}")
vec = struct.unpack_from("<48I", img, 0)
for i, v in enumerate(vec[:16]):
    tag = ""
    if i and v:
        tag = "in image" if base <= (v & ~1) < end else "OUTSIDE image"
    print(f"  vec[{i:2}] {names[i]:9} 0x{v:08x} {tag}")
irqs = [(i - 16, v) for i, v in enumerate(vec[16:48], 16) if v]
print("  IRQ handlers used:", ", ".join(f"IRQ{n}=0x{v:x}" for n, v in irqs))

regions = [
    ("bootloader flash (<base)", lambda a: 0x100 <= a < base),
    ("flash above image", lambda a: end <= a < 0x40000),
    ("ROM / IAP (0x03000000)", lambda a: 0x03000000 <= a < 0x03100000),
    ("SRAM", lambda a: 0x20000000 <= a < 0x20030000),
    ("SYSCON 0x40000000", lambda a: 0x40000000 <= a < 0x40001000),
    ("other APB/AHB periph", lambda a: 0x40001000 <= a < 0x50000000),
    ("SCB / NVIC / SysTick", lambda a: 0xE000E000 <= a < 0xE000F000),
]
hits = defaultdict(set)
for off in range(0, len(img) - 3, 4):
    w = struct.unpack_from("<I", img, off)[0]
    for name, test in regions:
        if test(w):
            hits[name].add((w, base + off))
for name, _ in regions:
    if hits[name]:
        vals = sorted({w for w, _ in hits[name]})
        print(f"\n[{name}] {len(vals)} distinct words:")
        print("  " + " ".join(f"0x{w:08x}" for w in vals[:80]))

md = Cs(CS_ARCH_ARM, CS_MODE_THUMB)
low = []
for ins in md.disasm(img, base):
    if ins.mnemonic in ("bl", "b", "blx") and ins.op_str.startswith("#"):
        t = int(ins.op_str[1:], 16)
        if t < base:
            low.append((ins.address, ins.mnemonic, t))
print(f"\nBranches to below base: {len(low)}")
for a, m, t in low[:30]:
    print(f"  0x{a:05x} {m} 0x{t:x}")
