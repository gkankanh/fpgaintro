#import "../style.typ": *

= Lesson 07 — Font ROM and coordinate maths

#goals(
  concept: [A lookup table plus arithmetic on coordinates, instead of stored pixels.],
  build: ["HELLO" in white, scaled 2×, over the lesson 06 gradient — still with no framebuffer.],
  needs: [Lesson 06.],
)[
  - Turn a raster coordinate into a ROM address and a bit select.
  - Choose constants so that the arithmetic disappears.
  - Recognise a hidden coupling between two distant constants.
  - Explain why a 32-byte ROM becomes logic rather than memory.
]

== The idea

Lesson 06 established that you can drive a display without storing a frame, as
long as you can #emph[compute] the pixel at any coordinate the moment it is
needed. Text is the first interesting thing to compute.

A bitmap font is a tiny ROM: each character is eight bytes, each byte a row,
each bit a pixel. So "is this pixel part of a letter?" becomes a chain of
arithmetic on the current raster coordinate — which character cell is #emph[x]
inside, which glyph is in that cell, which row does #emph[y] select, which bit
does #emph[x] select.

#why[
  That chain is exactly what a hardware text-mode display controller does, and
  what a GPU's texture unit does in more dimensions: a coordinate in, an
  address and a bit-select out.
]

== Theory: make the arithmetic disappear

```verilog
wire [2:0] ci    = tx[6:4];        // which character cell: divide by 16
wire [2:0] frow  = y[3:1] - 3'd4;  // which glyph row: divide by 2
wire [2:0] fcol  = tx[3:1];        // which column: divide by 2
wire font_bit = font[{glyph, frow}][3'd7 - fcol];
```

Every one of those is #strong[free], and that is the point:

- `tx[6:4]` is a divide by 16 — a wire rename, no logic at all. Choosing a
  16-pixel cell width (a power of two) is what makes it free; 10 pixels would
  have cost a divider.
- `tx[3:1]` is the same trick for the 2× scale: dropping the low bit makes
  every source pixel cover two screen pixels.
- `font[{glyph, frow}]` concatenates a 2-bit glyph index and a 3-bit row into a
  5-bit address. Address arithmetic by #emph[concatenation] rather than
  multiplication, because the glyph stride is 8.
- `3'd7 - fcol` reverses the bit order, because bit 7 of the font byte is the
  #emph[leftmost] pixel while #emph[x] increases rightward.

#why[
  "Choose your constants so the arithmetic disappears" is one of the
  highest-leverage habits in hardware design. The same design with a 10-pixel
  cell and a 3× scale is functionally identical and dramatically more
  expensive. Lesson 08 meets the same idea with a price attached, when a
  framebuffer's `y × 96 + x` turns out to cost two hardware multipliers.
]

#watch[
  `frow = y[3:1] - 3'd4` quietly relies on the text band starting at #emph[y] =
  24. Change the band's position and this constant must change with it — and
  the two facts are forty lines apart with nothing connecting them. A constant
  derived from another constant should be #emph[derived], not duplicated.
]

== What it cost, and the question it raises

#measured("adding text to lesson 06")[
  #ttable(
    columns: (auto, auto, auto),
    [], [*lesson 06*], [*lesson 07*],
    [`LUT4`],       [108], [#strong[185]],
    [`TRELLIS_FF`], [72],  [72 — #strong[unchanged]],
    [`PFUMX`],      [29],  [50],
  )
  #strong[No new flip-flops at all.] The text added no state, only
  combinational arithmetic. The extra 77 LUTs are the coordinate chain and the
  font ROM.
]

And there is the puzzle this lesson ends on: #strong[a 32-byte ROM built out of
logic, not memory.] The part has 208 block RAMs sitting idle and the
synthesiser used none of them.

The reason is size. One block RAM holds 18,432 bits; spending a whole one on
256 bits would waste 98.6% of it. The decision flips somewhere between 32 bytes
and a few kilobytes — and knowing roughly where is a useful instinct, which is
what lesson 08 is for.

== On what the test does not check

The testbench verifies that the SPI stream is well-formed and that the
initialisation sequence is correct. It does #emph[not] check that the letters
are the right shape — that would mean reconstructing a 96 × 64 image and
comparing against a reference.

#why[
  This gap is deliberate and worth sitting with. #strong[A passing test tells
  you only what it was written to ask.] The course returns to this repeatedly:
  lesson 09 finds a testbench asserting something false, lesson 11 finds a
  mutation that survives for a good reason, lesson 12 finds a hole in its own
  vectors, and lesson 13 finds a bug that 161 passing checks had missed.
]
