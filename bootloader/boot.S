/*
 * boot.S - minimal stand-in for the EVGA iCX MCU bootloader (NXP LPC51U68, Cortex-M0+).
 *
 * Contract derived from the EVGA application images (e.g. FTW_3Fans_AP_R118.bin):
 *   - the application is linked at 0x8000 and sets SCB->VTOR = 0x8000 itself (SystemInit),
 *     configures its own clocks and its own config page at 0x3FE00;
 *   - the word at 0x10000 is a boot flag: 0xFFFFFFFF = run the application,
 *     0xE0E02020 = update requested (the application writes it on I2C command
 *     01 AA EB 55 66, erasing the 256-byte page at 0x10000, then resets).
 *
 * This loader only boots the application. It does NOT implement EVGA's I2C update protocol:
 * if an update is requested, or the application looks invalid, it parks in a WFI loop and the
 * MCU has to be reflashed over SWD.
 *
 * The LPC51U68 boot ROM only runs user code when vector[7] holds the two's complement of the
 * sum of vectors 0..6; fix_checksum.py patches that after linking.
 */
    .syntax unified
    .cpu cortex-m0plus
    .thumb

    .equ APP_BASE,   0x00008000
    .equ BOOT_FLAG,  0x00010000
    .equ RAM_START,  0x20000000
    .equ RAM_END,    0x20010000   /* initial SP used by the EVGA application */

    .section .vectors, "a"
    .word   RAM_END             /* 0x00 initial SP            */
    .word   reset_handler       /* 0x04 reset                 */
    .word   park                /* 0x08 NMI                   */
    .word   park                /* 0x0C HardFault             */
    .word   0, 0, 0             /* 0x10..0x18 reserved        */
    .word   0                   /* 0x1C ROM checksum (patched)*/

    .text
    .thumb_func
    .global reset_handler
reset_handler:
    /* Update requested (flag != 0xFFFFFFFF): we cannot serve it, stay parked. */
    ldr     r0, =BOOT_FLAG
    ldr     r1, [r0]
    adds    r1, r1, #1
    bne     park

    /* Application sanity: initial SP inside SRAM, reset vector inside the application. */
    ldr     r0, =APP_BASE
    ldr     r1, [r0]            /* app initial SP */
    ldr     r2, =RAM_START
    cmp     r1, r2
    bls     park
    ldr     r2, =RAM_END
    cmp     r1, r2
    bhi     park
    ldr     r2, [r0, #4]        /* app reset vector (Thumb bit set) */
    cmp     r2, r0
    bls     park
    ldr     r3, =0x00040000
    cmp     r2, r3
    bhs     park

    msr     msp, r1
    bx      r2

    .thumb_func
park:
    wfi
    b       park

    .ltorg
