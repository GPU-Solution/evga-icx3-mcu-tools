"""xref.py - find which instructions load a given 32-bit constant (Thumb LDR literal) in a raw image.

Usage: python xref.py <image.bin> <base_hex> <const_hex> [<const_hex> ...]
For each constant: lists the literal-pool addresses holding it and every `ldr rX, [pc, #imm]` that
loads that pool word, with the address of the enclosing push{..lr} (approximate function start).
"""
import struct
import sys

from capstone import CS_ARCH_ARM, CS_MODE_THUMB, Cs

img = open(sys.argv[1], "rb").read()
base = int(sys.argv[2], 16)
consts = [int(c, 16) for c in sys.argv[3:]]

md = Cs(CS_ARCH_ARM, CS_MODE_THUMB)
insns = list(md.disasm(img, base))
func_start = None
loads = {}  # pool address -> list of (insn addr, func start)
for ins in insns:
    if ins.mnemonic.startswith("push") and "lr" in ins.op_str:
        func_start = ins.address
    if ins.mnemonic == "ldr" and "[pc," in ins.op_str:
        imm = int(ins.op_str.split("#")[1].rstrip("]"), 0)
        pool = ((ins.address + 4) & ~3) + imm
        loads.setdefault(pool, []).append((ins.address, func_start))

for c in consts:
    pools = [base + o for o in range(0, len(img) - 3, 4) if struct.unpack_from("<I", img, o)[0] == c]
    print(f"0x{c:08x}: pools {[hex(p) for p in pools]}")
    for p in pools:
        for a, f in loads.get(p, []):
            print(f"   ldr at 0x{a:x} (func ~0x{f:x})" if f else f"   ldr at 0x{a:x}")
