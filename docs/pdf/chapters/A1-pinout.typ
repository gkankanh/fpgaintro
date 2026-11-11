#import "../style.typ": *

= Appendix A — Board pinout

The authoritative constraint file is `common/ulx3s_v20.lpf`. The names below
are the port names to use in a top-level module; the constraint file binds them
to ECP5 balls. Icestudio uses the same friendly names on its canvas, so a block
bound to `btn_1` and a Verilog port `btn[1]` land on the same ball.

== Clock

#ttable(
  columns: (auto, auto, 1fr),
  [`clk`], [G2], [25 MHz, free-running],
)

Every lesson in this course is clocked by this and nothing else — one clock
domain, no gated clocks, except lesson 04 which is about the exceptions.

== LEDs

Active high: write 1 to light. `led_0` is the least significant bit of the
`led[7:0]` port used throughout.

#ttable(
  columns: (auto,auto,auto,auto,auto,auto,auto,auto),
  [`led_7`],[`led_6`],[`led_5`],[`led_4`],[`led_3`],[`led_2`],[`led_1`],[`led_0`],
  [H3],[E1],[E2],[D1],[D2],[C1],[C2],[B2],
)

== Buttons

`btn_0` is the power button and is #strong[inverted] — it reads 1 when
released. The rest are active high with pull-downs. All of them need
debouncing, which is lesson 03.

#ttable(
  columns: (auto, auto, 1fr),
  [`btn_0`], [D6],  [power — inverted],
  [`btn_1`], [R1],  [FIRE1],
  [`btn_2`], [T1],  [FIRE2],
  [`btn_3`], [R18], [UP],
  [`btn_4`], [V1],  [DOWN],
  [`btn_5`], [U1],  [LEFT],
  [`btn_6`], [H16], [RIGHT],
)

== Slide switches

Static configuration input; no debouncing needed in practice.

#ttable(
  columns: (auto,auto,auto,auto),
  [`sw_0`],[`sw_1`],[`sw_2`],[`sw_3`],
  [E8],[D8],[D7],[E7],
)

== OLED — SSD1331, 96 × 64, 16-bit colour

Four-wire SPI, write-only. `oled_dc` selects command (0) or data (1). Maximum
clock about 6.6 MHz, which is why lesson 06 divides the 25 MHz clock by four.

#ttable(
  columns: (auto, auto, 1fr),
  [`oled_clk`],  [P4], [SPI clock, driven by the FPGA],
  [`oled_mosi`], [P3], [data, most significant bit first],
  [`oled_dc`],   [P1], [command (0) or data (1) — a level, not a stream bit],
  [`oled_resn`], [P2], [reset, active low; needs a real delay after release],
  [`oled_csn`],  [N2], [chip select, active low],
)

== USB serial — FTDI FT231X

#watch[
  Named from the #strong[FTDI's] point of view. The FPGA #emph[drives]
  `ftdi_rxd` and #emph[reads] `ftdi_txd`, so `output ftdi_rxd` and
  `input ftdi_txd` are correct and look backwards. `ftdi_txden` must be driven
  high to enable the FPGA's driver. This is the classic place to lose an
  afternoon.
]

#ttable(
  columns: (auto, auto, 1fr),
  [`ftdi_rxd`],   [L4], [the FTDI receives — the FPGA #strong[transmits]],
  [`ftdi_txd`],   [M1], [the FTDI transmits — the FPGA #strong[receives]],
  [`ftdi_txden`], [L3], [drive high to enable],
  [`ftdi_nrts`],  [M3], [],
  [`ftdi_ndtr`],  [N1], [],
)

== Everything else

The board definition lists 184 pins in total: 32 MB of SDRAM (`sdram_*`, 16
bits wide), digital video out (`gpdi_*`), the audio resistor ladders
(`audio_*`), the SD card (`sd_*`), SPI flash (`flash_*`), an ADC (`adc_*`), the
ESP32 interface (`wifi_*`), and 28 differential GPIO pairs (`gp0`–`gp27` and
`gn0`–`gn27`). See `common/ulx3s_v20.lpf` for the complete set.

== Part facts worth remembering

#ttable(
  columns: (auto, 1fr),
  [FPGA],              [Lattice ECP5 `LFE5U-85F-6BG381C`],
  [Package],           [381-ball caBGA],
  [Speed grade],       [6],
  [LUT4s],             [83,640],
  [Flip-flops],        [83,640],
  [Block RAM],         [208 × 18 Kbit, about 3.7 Mbit],
  [18×18 multipliers], [156],
  [PLLs],              [4],
  [Clock],             [25 MHz],
  [Programmer],        [FTDI FT231X — `openFPGALoader -b ulx3s`],
)
