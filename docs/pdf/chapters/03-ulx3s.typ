#import "../style.typ": *

= The ULX3S, and what is inside it

== The board

The ULX3S is an open-hardware FPGA development board from
#link("https://radiona.org")[Radiona], the makerspace in Zagreb. Schematics,
PCB layout and a large body of example gateware are published openly by the
project itself.

It was designed for teaching, and it shows: the peripherals are the ones you
actually want when learning, placed where you can reach them, with no
mezzanine cards to buy.

#ttable(
  columns: (auto, 1fr),
  [*Clock*],      [25 MHz, free-running, straight from a crystal],
  [*LEDs*],       [8, active high],
  [*Buttons*],    [7, undebounced — which lesson 03 turns into a virtue],
  [*Switches*],   [4 slide switches, static],
  [*Display*],    [SSD1331 colour OLED, 96×64, 16-bit colour, 4-wire SPI],
  [*Serial*],     [FTDI FT231X — also the JTAG programmer, over one USB cable],
  [*Memory*],     [32 MB SDRAM, 16 bits wide; SPI flash for the bitstream],
  [*Storage*],    [micro-SD slot],
  [*Video*],      [digital video output],
  [*Expansion*],  [28 differential GPIO pairs on two headers],
  [*Wireless*],   [an ESP32 module],
)

Four of those matter for this course: the clock, the LEDs, the buttons and the
OLED. Lessons 00–13 need no more. The SDRAM, the SD card and video output are
where you go after the course ends.

== The chip

The board in this course carries a Lattice `LFE5U-85F-6BG381C`. Unpacking that
part number is worth a paragraph, because every field of it turns up later:

#ttable(
  columns: (auto, 1fr),
  [`LFE5U`],  [Lattice ECP5, the "U" being the version without SERDES],
  [`85`],     [the size grade — about 84,000 logic cells],
  [`F`],      [the package family],
  [`6`],      [speed grade 6, the middle of three. A faster part would close
               timing at a higher clock with identical Verilog],
  [`BG381`],  [a 381-ball caBGA],
  [`C`],      [commercial temperature range],
)

What you get:

#ttable(
  columns: (auto, auto, 1fr),
  [*resource*], [*count*], [*what it is*],
  [LUT4],         [83,640],  [4-input lookup tables — the general-purpose logic],
  [Flip-flops],   [83,640],  [one per logic cell, whether you use it or not],
  [Block RAM],    [208 × 18 Kbit], [about 3.7 Mbit of dedicated memory],
  [Multipliers],  [156],     [18×18 hardware multipliers],
  [PLLs],         [4],       [frequency synthesis, lesson 04],
)

For calibration: lesson 13's whole RISC-V CPU uses about 1,765 LUT4 — a little
over #strong[2%] of the part. Logic capacity will not be your constraint in
this course, or in most projects.

== What is actually inside

This is the single most useful piece of theory in the book, because almost
every cost surprise in the course follows from it.

#fig("/figures/logic-cell.svg",
     [An ECP5 logic cell. The LUT's sixteen configuration bits come from the
      bitstream, which is what "programming" an FPGA means.])

An FPGA contains no gates. It contains #strong[lookup tables]: sixteen
configuration bits holding the truth table of whatever four-input function you
asked for, selected by the four inputs. Your `a & b` does not become an AND
gate; it becomes a LUT4 loaded with the AND truth table and two inputs unused.

Three consequences run through the whole course:

+ #strong[Any function of up to four inputs costs exactly one LUT4], however
  complicated. A 2-input AND and a 4-input XOR are the same price (lesson 01).
  Minimising gate count — half of a classic logic design course — mostly does
  not apply here.

+ #strong[Flip-flops are not scarce.] Every logic cell has one whether the
  design uses it or not. This is why one-hot state encoding is *supposed* to
  be free on an FPGA — and lesson 05 measures a case where it is four times
  worse anyway.

+ #strong[Some things have dedicated hardware and some do not.] There is a
  carry chain running up each column of cells, so addition is nearly free: a
  32-bit adder costs 17 carry cells and no LUTs. There is no dedicated shift
  hardware, so a 32-bit barrel shifter costs about 667 LUT4 — which is why
  lesson 10 finds that the shifter, not the adder, is 80% of the ALU.

#why[
  "Which operations are expensive" is not intuition. It is a property of the
  fabric in front of you, and on a chip without a carry chain the answer would
  invert. This is why the course measures everything rather than citing rules.
]

== Why an open toolchain matters here

The ECP5 can be programmed by entirely open-source software, from Verilog
source to a bitstream the chip accepts. That is unusual, and it is not an
accident of licensing — it is the result of years of work reverse-engineering
and documenting the bitstream format, described in the next chapter.

It matters for a course for three reasons:

- #strong[Nothing expires and nothing phones home.] No licence server, no
  registration, no node-locked key that stops working when you change laptop.
- #strong[You can read the tools.] When yosys does something surprising — and
  this course documents several cases — the source is there. The schematic
  `make graph` produces is the tool showing you its own intermediate
  representation.
- #strong[It runs anywhere.] The entire toolchain for this course is one
  download of about a gigabyte, needs no administrator rights, and is removed
  by deleting a directory.
