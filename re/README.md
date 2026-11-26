# Analysis helpers

Small Python scripts (capstone for `ap_scan.py` / `xref.py`) used to understand the application images.

| Script | Use |
|---|---|
| `ap_scan.py <image.bin> [base]` | Vector table, IRQ handlers, aligned words that point outside the image (bootloader flash, ROM, peripherals, SCB), branches below the base. |
| `xref.py <image.bin> <base> <const> ...` | Which `ldr rX, [pc, #..]` load a given constant. |
| `lowptr.py <objdump.dis> <image.bin> [base]` | Literals below the base that the code dereferences (reads/writes into the bootloader region). |

Disassembly used with them:

```
arm-none-eabi-objdump -D -b binary -marm -Mforce-thumb --adjust-vma=0x8000 image.bin > image.dis
```

Expect false positives where data (jump tables, literal pools) is disassembled as code.
