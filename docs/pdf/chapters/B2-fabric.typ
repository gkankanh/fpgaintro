#import "../style.typ": *

= The fabric, and what it costs

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
  design uses it or not. This is why one-hot state encoding is #emph[supposed]
  to be free on an FPGA — and lesson 05 measures a case where it is four times
  worse anyway.

+ #strong[Some things have dedicated hardware and some do not.] A carry chain
  runs up each column of cells, so addition is nearly free: a 32-bit adder
  costs 17 carry cells and no LUTs. There is no dedicated shift hardware, so a
  32-bit barrel shifter costs about 667 LUT4 — which is why lesson 10 finds
  that the shifter, not the adder, is 80% of the ALU.

Which operations are expensive is not intuition. It is a property of the fabric
in front of you, and on a chip without a carry chain the answer would invert.

== What "what it cost" means

Every lesson ends by asking what the design cost, and the phrase has one
meaning here: #strong[how much of the FPGA it used]. Not money, not runtime.
`make synth` prints a count of the chip's own primitives, and these are the
lines worth reading:

#ttable(
  columns: (auto, 1fr),
  [*in the report*], [*what it is*],
  [`LUT4`],         [four-input lookup tables — general-purpose logic, and
                     usually the headline number],
  [`TRELLIS_FF`],   [flip-flops: one bit of state each. Lesson 05's design
                     reports 113 of them, and the lesson accounts for all 113],
  [`CCU2C`],        [carry cells, two bits of arithmetic each — the dedicated
                     adder hardware, which is why `+` is so much cheaper than
                     logic you build yourself],
  [`PFUMX`, `L6MUX21`], [multiplexers that glue LUT4s together into wider
                     functions, so a 5- or 6-input function costs a little more
                     than one LUT4],
  [`TRELLIS_DPR16X4`], [distributed RAM: 16 words of 4 bits built out of a
                     logic cell's lookup tables, which is how a small array
                     gets stored when a block RAM would be wasteful],
  [`DP16KD`],       [block RAMs, 18 Kbit each — lesson 08's subject],
  [`MULT18X18D`],   [hardware 18×18 multipliers. Seeing one appear when you did
                     not ask for it is lesson 08's most useful surprise],
)

Area is what you spend. #strong[Time is a separate thing, and it is a
constraint rather than a price]: the longest path of logic between two
flip-flops has to settle inside one clock period. Adding logic to that path
does not make the design slower — the design has no choice about its clock, the
board's crystal does — it makes it #emph[stop working], and `nextpnr` says so
when `make bit` fails timing. That is lesson 04's subject.

Both quantities come back in a second or two, which is the whole reason this
course can measure rather than assert. And measurement repeatedly contradicts
what everyone knows:

#measured("four received rules that did not survive contact with the fabric")[
  - "One-hot encoding suits FPGAs, since flip-flops are free." On this
    four-state machine it cost #strong[41 LUT4 against 12] — nearly four times
    worse (lesson 05).
  - "Mealy machines need fewer states, so they are cheaper." Fewer states, yes
    — 3 against 4 — and #strong[more logic]: 5 LUT4 against 2 (lesson 05).
  - "The synthesiser will reduce a constant multiply to shifts." It spent
    #strong[two hardware multiplier blocks] instead (lesson 08).
  - "Build it from gates to understand it, then it is the same thing." The
    hand-built 32-bit adder cost #strong[212 cells to `+`'s 17] (lesson 02).
]

None of those are here because they were read somewhere. They are here because
`make synth` said so, and they are reproducible on your machine in the time it
takes to read the paragraph.

== The board

The ULX3S is an open-hardware board from #link("https://radiona.org")[Radiona],
the makerspace in Zagreb, designed for teaching — the peripherals are the ones
you want when learning, placed where you can reach them, with no mezzanine
cards to buy. Four of them matter for this course: a #strong[25 MHz] crystal
clock, #strong[8 LEDs] (active high), #strong[7 buttons] (undebounced, which
lesson 03 turns into a virtue) and #strong[4 slide switches], plus an
#strong[SSD1331 OLED] — 96×64, 16-bit colour, 4-wire SPI — for lessons 06 and
07, and an #strong[FT231X] that is both the JTAG programmer and the serial port
for lesson 09 onward. The SDRAM, SD card and video output are where you go
after the course ends; the full pinout is in #emph[Tools and Workflow].

== The chip

#ttable(
  columns: (auto, auto, 1fr),
  [*resource*], [*count*], [*what it is*],
  [LUT4],         [83,640],  [4-input lookup tables — the general-purpose logic],
  [Flip-flops],   [83,640],  [one per logic cell, whether you use it or not],
  [Block RAM],    [208 × 18 Kbit], [about 3.7 Mbit of dedicated memory],
  [Multipliers],  [156],     [18×18 hardware multipliers],
  [PLLs],         [4],       [frequency synthesis, lesson 04],
)

That is an `LFE5U-85F-6BG381C`: an ECP5 without SERDES, size grade 85 (about
84,000 logic cells), #strong[speed grade 6] of three — a faster part would
close timing at a higher clock with identical Verilog — in a 381-ball caBGA,
commercial temperature range.

For calibration: lesson 13's whole RISC-V CPU uses about 1,765 LUT4, a little
over #strong[2%] of the part. Logic capacity will not be your constraint in
this course, or in most projects.

== The shape of the course

Eighteen lessons, each self-contained, each ending in something you can see
working. The sequence is not arbitrary: every lesson exists because a later one
needs it. The register file in lesson 11 is the CPU's register file; the UART
in lesson 09 is how the CPU will say hello.

#fig("/figures/course-map.svg",
     [The course. Solid arrows are prerequisites; the right-hand column is the
      processor, assembled from parts built in the left-hand ones.],
     width: 100%)

The five parts of this book follow that structure, and Part IV — the processor
— depends on 00–05, 08 and 10–12. Lessons 06 and 07 are the display path and 09
is the serial path; the UART returns in lesson 15 as the processor's console,
but the CPU in lesson 13 does not depend on either. If your goal is the
processor and nothing else, you can read those three afterwards without being
stuck.
