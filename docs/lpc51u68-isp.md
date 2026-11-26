# LPC51U68 (LQFP48): pins for programming, ROM ISP, code protection

From the NXP LPC51U68 datasheet (rev 1.5) and user manual UM11071 (rev 1.1). Check the official
documents before wiring anything; pin numbers below are for the **48-pin** package used on the
EVGA cards seen here.

## Debug / power pins (LQFP48)

| Pin | Function |
|---|---|
| 39 | SWCLK / PIO0_16 |
| 40 | SWDIO / PIO0_17 |
| 41 | VSS |
| 42 | VDD |
| 48 | RESET (internal pull-up) |
| 18 / 19 | VDD / VSS |
| 16 / 17 | VSSA / VDDA |

Pins 39-42 are consecutive, convenient for an SWD probe.

## ROM ISP

The 32 KB mask ROM contains an ISP loader that cannot be erased. Mode selection at reset (UM11071,
table "ISP modes"):

| ISP0 = PIO0_31 (pin 9) | ISP1 = PIO0_4 (pin 27) | VBUS = PIO1_6 (pin 20) | Result |
|---|---|---|---|
| 1 | x | x | boot from flash if it holds valid user code |
| 0 | 0 | x | ISP over I2C (Flexcomm 1: SCL PIO0_23 pin 1, SDA PIO0_24 pin 2) or SPI (Flexcomm 3: pins 34-37) |
| 0 | 1 | 0 | ISP over USART (Flexcomm 0: **RXD PIO0_0 pin 23, TXD PIO0_1 pin 24**) |
| 0 | 1 | 1 | ISP over USB, mass-storage device (USB_DP pin 5, USB_DM pin 6) |

- If the flash holds no valid image (blank chip), ISP is entered according to ISP1/VBUS only.
  PIO0_4 and PIO1_6 have internal pull-ups, so a blank chip with nothing connected selects USB.
- The manual asks for a pull-down resistor (not a hard short) on ISP1, because it becomes an output
  (ISP1_IRQ) in I2C/SPI ISP mode.
- I2C ISP answers on addresses 0x18, 0x1C, 0x30 and 0x38.
- USART ISP: 8N1, send `?`, the chip answers `Synchronized\r\n`, echo it back, then send the clock in
  kHz. Data in Read Memory / Write commands are plain binary (not UU-encoded).
- A 3.3 V USB-UART adapter is enough for USART ISP. PIO0_0/PIO0_1 are 5 V tolerant only while VDD is
  present (datasheet pin type [2]); with the MCU unpowered they must not exceed 3.6 V, so a 3.3 V
  adapter is the safe choice.

On a populated graphics card these pins may be connected to other circuitry. Check where they go before
forcing levels on them.

## Code read protection (word at 0x2FC)

| Value | Level | Effect |
|---|---|---|
| `0x12345678` | CRP1 | SWD disabled; ISP Read Memory and Go disabled; sector 0 protected |
| `0x87654321` | CRP2 | SWD disabled; only full erase + write via ISP |
| `0x43218765` | CRP3 | SWD and ISP entry disabled |
| `0x4E697370` | NO_ISP | ISP pin not sampled; SWD still allowed |

With CRP1/CRP2 the flash cannot be read out by ISP or SWD, so a working MCU can only be cloned if it
has no CRP. Whether EVGA enables CRP was not checked.

## Valid user code

The boot ROM requires the first 8 words of the vector table to add up to 0 (word `0x1C` is the
checksum). See [firmware-layout.md](firmware-layout.md).
