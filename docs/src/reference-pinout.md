# ULX3S board pinout

The authoritative constraint file is `common/ulx3s_v20.lpf` (ULX3S v2.0). The
names below are the port names to use in your top-level module; the LPF binds
them to ECP5 balls. Icestudio uses the same friendly names on its canvas, so a
`basic.input` bound to `btn_1` and a Verilog port `btn[1]` land on the same ball.

Generated from the board definition, so it matches what the tools actually use.

## Clock

25 MHz, free-running. Every lesson in this course is clocked by this and
nothing else — one clock domain, no gated clocks.

| signal | ECP5 ball | pull |
|---|---|---|
| `clk` | G2 | — |

## LEDs

Active high: write 1 to light. They sit in a row along the board edge;
`led_0` is the least significant bit of the `led[7:0]` port used throughout.

| signal | ECP5 ball | pull |
|---|---|---|
| `led_7` | H3 | — |
| `led_6` | E1 | — |
| `led_5` | E2 | — |
| `led_4` | D1 | — |
| `led_3` | D2 | — |
| `led_2` | C1 | — |
| `led_1` | C2 | — |
| `led_0` | B2 | — |

## Buttons

`btn_0` is the power button and is **inverted** (reads 1 when released);
the rest are active high with pull-downs. All of them need debouncing —
that is lesson 02.

| signal | ECP5 ball | pull |
|---|---|---|
| `btn_0` | D6 | UP |
| `btn_1` | R1 | DOWN |
| `btn_2` | T1 | DOWN |
| `btn_3` | R18 | DOWN |
| `btn_4` | V1 | DOWN |
| `btn_5` | U1 | DOWN |
| `btn_6` | H16 | DOWN |

## Slide switches

Static configuration input; no debouncing needed in practice.

| signal | ECP5 ball | pull |
|---|---|---|
| `sw_0` | E8 | DOWN |
| `sw_1` | D8 | DOWN |
| `sw_2` | D7 | DOWN |
| `sw_3` | E7 | DOWN |

## OLED (SSD1331, 96x64, 16-bit colour)

4-wire SPI, write-only. `oled_dc` selects command (0) or data (1).
Max SCLK about 6.6 MHz, so lesson 04 divides the 25 MHz clock by 4.

| signal | ECP5 ball | pull |
|---|---|---|
| `oled_clk` | P4 | UP |
| `oled_mosi` | P3 | UP |
| `oled_dc` | P1 | UP |
| `oled_resn` | P2 | UP |
| `oled_csn` | N2 | UP |

## USB serial (FTDI FT231X)

Named from the FTDI's point of view: the FPGA **drives** `ftdi_rxd` and
**receives** `ftdi_txd`. Getting this backwards is the classic lesson-07
mistake. `ftdi_txden` must be driven high to enable the FPGA's driver.

| signal | ECP5 ball | pull |
|---|---|---|
| `ftdi_rxd` | L4 | UP |
| `ftdi_txd` | M1 | UP |
| `ftdi_nrts` | M3 | UP |
| `ftdi_ndtr` | N1 | UP |
| `ftdi_txden` | L3 | UP |

## SPI flash

Holds the bitstream after `make flash`. Also usable as storage.

| signal | ECP5 ball | pull |
|---|---|---|
| `flash_csn` | R2 | UP |
| `flash_clk` | U3 | DOWN |
| `flash_mosi` | W2 | UP |
| `flash_miso` | V2 | UP |
| `flash_wpn` | Y2 | UP |
| `flash_holdn` | W1 | UP |

## SD card

| signal | ECP5 ball | pull |
|---|---|---|
| `sd_clk` | H2 | UP |
| `sd_cmd` | J1 | UP |
| `sd_d0` | J3 | UP |
| `sd_d1` | H1 | UP |
| `sd_d2` | K1 | NONE |
| `sd_d3` | K2 | UP |
| `sd_wp` | P5 | UP |
| `sd_cdn` | N5 | UP |

## GPIO headers

28 differential pairs on the two side headers: `gp0`–`gp27` and
`gn0`–`gn27`. Used in this course only if you add your own peripherals.

| signal | ball | | signal | ball |
|---|---|---|---|---|
| `gp0` | B11 | | `gn0` | C11 |
| `gp1` | A10 | | `gn1` | A11 |
| `gp2` | A9 | | `gn2` | B10 |
| `gp3` | B9 | | `gn3` | C10 |
| `gp4` | A7 | | `gn4` | A8 |
| `gp5` | C8 | | `gn5` | B8 |
| `gp6` | C6 | | `gn6` | C7 |
| `gp7` | A6 | | `gn7` | B6 |
| `gp8` | A4 | | `gn8` | A5 |
| `gp9` | A2 | | `gn9` | B1 |
| `gp10` | C4 | | `gn10` | B4 |
| `gp11` | F4 | | `gn11` | E3 |
| `gp12` | G3 | | `gn12` | F3 |
| `gp13` | H4 | | `gn13` | G5 |
| `gp14` | U18 | | `gn14` | U17 |
| `gp15` | N17 | | `gn15` | P16 |
| `gp16` | N16 | | `gn16` | M17 |
| `gp17` | L16 | | `gn17` | L17 |
| `gp18` | H18 | | `gn18` | H17 |
| `gp19` | F17 | | `gn19` | G18 |
| `gp20` | D18 | | `gn20` | E17 |
| `gp21` | C18 | | `gn21` | D17 |
| `gp22` | B15 | | `gn22` | C15 |
| `gp23` | B17 | | `gn23` | C17 |
| `gp24` | C16 | | `gn24` | D16 |
| `gp25` | D14 | | `gn25` | E14 |
| `gp26` | B13 | | `gn26` | C13 |
| `gp27` | D13 | | `gn27` | E13 |

## Everything else

The board definition lists 184 pins in total, including SDRAM
(`sdram_*`), digital video out (`gpdi_*`), the audio DAC resistor ladders
(`audio_*`), the ADC (`adc_*`) and the ESP32 WiFi interface (`wifi_*`). See
`common/ulx3s_v20.lpf` for the complete set.

## Part facts worth remembering

| | |
|---|---|
| FPGA | Lattice ECP5 `LFE5U-85F-6BG381C` |
| Package | 381-ball caBGA |
| Speed grade | 6 |
| LUT4s | 83,640 |
| Flip-flops | 83,640 |
| Block RAM | 208 x 18 Kbit (about 3.7 Mbit) |
| 18x18 multipliers | 156 |
| Clock | 25 MHz |
| Programmer | FTDI FT231X, `openFPGALoader -b ulx3s` |

