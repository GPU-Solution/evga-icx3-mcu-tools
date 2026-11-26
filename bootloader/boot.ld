/* boot.ld - places the stand-in bootloader at the start of LPC51U68 flash, below the
   EVGA application (0x8000). Keeps clear of the CRP word at 0x2FC. */
MEMORY
{
    FLASH (rx) : ORIGIN = 0x00000000, LENGTH = 0x2F0
}

SECTIONS
{
    .text :
    {
        KEEP(*(.vectors))
        *(.text*)
        *(.rodata*)
    } > FLASH
}
