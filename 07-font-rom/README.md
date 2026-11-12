# Lesson 07 — font ROM and coordinate math

**Concept:** a lookup table plus arithmetic on coordinates, instead of stored
pixels.

**You will build:** "HELLO" in white, 2× scaled, centred over the lesson 06
gradient — still with no framebuffer.

**Needs the board:** yes, to see it

**Prerequisites:** lesson 06 (SPI and the OLED)

**Paths:** editor

**By the end you can:**

- Turn a raster coordinate into a ROM address and a bit select.
- Choose constants so that the arithmetic disappears.
- Recognise a hidden coupling between two distant constants.
- Explain why a 32-byte ROM becomes logic rather than memory.

---

## The idea

Lesson 06 established that you can drive a display without storing a frame, as
long as you can *compute* the pixel at any coordinate the moment it is needed.
Text is the first interesting thing to compute.

A bitmap font is a tiny ROM: each character is 8 bytes, each byte a row, each
bit a pixel. The letter H is

```
0x66  . # #  . . # #  .      bit 7 is the leftmost pixel
0x66  . # #  . . # #  .
0x66  . # #  . . # #  .
0x7E  . # # # # # #  .
0x66  . # #  . . # #  .
0x66  . # #  . . # #  .
0x66  . # #  . . # #  .
0x00  . . . . . . . .
```

So "is this pixel part of a letter?" becomes a chain of arithmetic on the
current raster coordinate: which character cell is x inside, which glyph is in
that cell, which row of that glyph does y select, which bit does x select.

That chain is the whole lesson. It is also exactly what a hardware text-mode
display controller does, and what a GPU's texture unit does in more
dimensions — a coordinate in, an address and a bit-select out.

## The design

[`text_top.v`](./text_top.v) is lesson 06 with a new pixel function. The SPI
engine, init ROM and raster counters are untouched; that is the payoff of the
`busy`/`start` handshake.

The text band is placed with constants:

```verilog
// "HELLO": 5 chars, 16px each = 80px wide at x 8..87, 16px tall at y 24..39
wire in_text = (x >= 7'd8) && (x < 7'd88) && (y >= 6'd24) && (y < 6'd40);
wire [6:0] tx = x - 7'd8;        // 0..79 inside the band
```

Then four lines of arithmetic turn a coordinate into a font bit:

```verilog
wire [2:0] ci    = tx[6:4];              // character cell 0..4
wire [1:0] glyph = (ci==0) ? 0 : (ci==1) ? 1 : (ci==4) ? 3 : 2;  // H E L L O
wire [2:0] frow  = y[3:1] - 3'd4;        // (y-24)/2, the glyph row
wire [2:0] fcol  = tx[3:1];              // (tx/2) & 7, the glyph column
wire font_bit = font[{glyph, frow}][3'd7 - fcol];
```

Every one of those is a *free* operation, and that is the point worth dwelling
on:

- `tx[6:4]` is a divide by 16 — a wire rename, no logic at all. Choosing a
  16-pixel cell width (a power of two) is what makes it free. 10 pixels would
  have cost a divider.
- `tx[3:1]` is the same trick for the 2× scale: dropping the low bit makes
  every source pixel cover two screen pixels.
- `font[{glyph, frow}]` concatenates a 2-bit glyph index and a 3-bit row into a
  5-bit ROM address. Address arithmetic by concatenation, not multiplication,
  because the glyph stride is 8 — again a power of two.
- `3'd7 - fcol` reverses the bit order, because bit 7 of the font byte is the
  *leftmost* pixel while x increases rightward.

> **Why this matters** — "choose your constants so the arithmetic disappears"
> is one of the highest-leverage habits in hardware design. The same design
> with a 10-pixel cell and a 3× scale is functionally identical and
> dramatically more expensive.

Finally, text wins over background:

```verilog
wire [15:0] bg    = { x[6:2], y[5:0], frame[7:3] };
wire [15:0] pixel = (in_text && font_bit) ? 16'hFFFF : bg;
```

> **Watch out** — `frow = y[3:1] - 3'd4` quietly relies on the band starting at
> y = 24. Change the band position and this constant has to change with it; the
> two facts are 40 lines apart and nothing connects them. Fixing that is
> exercise 3.

## Simulate it

```bash
cd 07-font-rom
make sim
```

```
PASS: 4863 bytes, init sequence + pixel stream OK
```

The testbench is lesson 06's, extended: it decodes the SPI stream, checks the
init sequence, and then counts data bytes through most of a frame.

Note what it does **not** check: that the letters are the right shape. It
verifies the stream is well-formed, not that it spells HELLO. Checking the
glyphs would mean reconstructing a 96×64 image in the testbench and comparing
it against a reference — worth doing, and exercise 5.

This gap is deliberate and worth sitting with. A passing test tells you only
what it was written to ask.

```bash
make wave
```

Find a `y` in the text band and watch `font_bit` and `in_text` toggle as `x`
sweeps — the letters appear as a pattern on a single trace.

## What it cost

`text_top` — the whole design:

```bash
make synth
```

| resource | count |
|---|---:|
| `LUT4` | 185 |
| `TRELLIS_FF` | 72 |
| `CCU2C` | 22 |
| `PFUMX` | 50 |
| `L6MUX21` | 25 |

185 of the 85F's 83,640 LUT4 — 0.22% of the part.

Set that beside lesson 06 — 108 LUT4, 72 `TRELLIS_FF`, 22 `CCU2C`, 29 `PFUMX`.
No new flip-flops at all — the text added no state, only combinational
arithmetic. The extra 77 LUT4s and 21 PFUMX muxes are the coordinate chain and
the font ROM.

And there it is: **a 32-byte ROM built out of 185 LUTs and multiplexers, not a
block RAM.** The ECP5 has 208 block RAMs sitting idle, and yosys used none of
them, because a 32×8 table is cheaper as logic than as a memory primitive with
a registered output and a cycle of latency.

That decision flips somewhere between 32 bytes and a few kilobytes, and knowing
roughly where is a useful instinct. Lesson 08 is about the other side of it —
and about a full 128-character font, which is 1,024 bytes and definitely
belongs in BRAM.

## On the board

```bash
make prog
```

White "HELLO" in 16×16 letters across the middle of the panel, with the gradient
drifting behind it.

## Icestudio

This lesson is editor-only. The coordinate chain is six wires of bit-slicing
arithmetic, which is about where a block diagram stops helping: `tx[6:4]` as a
picture is a box labelled `tx[6:4]`. See
[choosing your path](../docs/src/paths.md).

You can still see the structure:

```bash
make graph      # -> text_top.svg
```

## Exercises

1. **Change the message.** Add glyphs for `W`, `O`, `R`, `D` to the font ROM and
   spell something else. Note how `glyph` becomes a lookup table as the string
   gets longer — and that this is the point where you would want the string in a
   ROM too.
2. **Change the scale.** Make the text 1× instead of 2× (use `tx[2:0]` and
   `y[2:0]`). Then try 4×. Then try 3× and watch the cost appear in
   `make synth`.
3. **Remove the hidden coupling.** Replace the magic `3'd4` in `frow` with
   arithmetic derived from a single `TEXT_Y` parameter, so moving the band
   cannot silently break the row select.
4. **Make it move.** Add `frame` to the x origin so the text scrolls. You will
   need to handle wrap-around at the panel edge.
5. **Test the glyphs properly.** Extend the testbench to reconstruct the frame
   into a 96×64 array and assert that the pixel at a known position inside the
   H is white and one in the gap is not.

## Wrap-up

**What you built.** A font ROM and the coordinate chain that turns a pixel position into a glyph row — 77 more LUT4 than lesson 06 and **no new flip-flops**.

**What to keep.** Combinational work adds area, not state; and a 32-byte ROM becomes logic rather than memory.

**What comes next.** Lesson 08 explains where that line sits, and what it costs to be on the wrong side of it.
