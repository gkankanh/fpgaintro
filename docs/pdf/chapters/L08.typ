#import "../style.typ": *

= Lesson 08 — Memories

#goals(
  concept: [You do not instantiate a block RAM — you write a shape the synthesiser recognises, and the tidier-looking shapes cannot be recognised.],
  build: [The four memory configurations the fabric offers, a ROM loaded from a file, a dual-port framebuffer, and a memory self-test that runs on the board.],
  needs: [Lesson 07.],
)[
  - Write the coding pattern that infers block RAM, and spot the ones that cannot.
  - Explain why a combinational read rules out block RAM at any size.
  - Know roughly where the size threshold between logic and memory sits.
  - Present address, write-enable and write-data in the same cycle.
]

== The idea

The part has 208 `DP16KD` blocks — 18,432 bits each, about 3.7 Mbit in total,
true dual-port, with a #strong[registered output]. You cannot instantiate one
in this course's style; you write an array and the synthesiser infers it, under
three conditions:

- the array is a `reg [W-1:0] mem [0:DEPTH-1]`
- reads and writes happen inside `always @(posedge clk)`
- #strong[the read result goes into a register]

That last one is not a style preference. A block RAM's output is registered
#emph[inside the block], physically. A combinational read is something a
`DP16KD` cannot do, so asking for one takes block RAM off the table —
permanently, at any size.

== The measurement

#measured("the same array, two ways, at W = 32")[
  #ttable(
    columns: (auto, auto, auto),
    [*depth*], [*synchronous read*], [*combinational read*],
    [16],   [8 DPR16X4 + 32 FF], [#strong[8 DPR16X4]],
    [64],   [#strong[1 DP16KD]], [32 DPR16X4 + 132 LUT4 + 96 muxes],
    [256],  [#strong[1 DP16KD]], [128 DPR16X4 + #strong[919 LUT4] + 672 muxes],
    [1024], [#strong[2 DP16KD]], [—],
  )
]

Three readings, and the third is the one people miss.

#strong[At 256 entries, one line of difference costs 919 LUTs.] The
combinational version becomes #emph[distributed] RAM — 16 words of 4 bits built
from a logic cell's lookup tables — plus an enormous multiplexer tree.

#strong[At 1024 × 32 the synchronous version is two block RAMs and nothing
else.] 32,768 bits, and a `DP16KD` holds 18,432. Clean inference, zero LUTs.

#strong[And at 16 entries both give distributed RAM, with the combinational one
#emph[cheaper]] — it needs no output register. Small asynchronous arrays have a
legitimate home, and that is exactly how a 16-entry register file gets built.

#why[
  So the rule is not "always synchronous". It is #strong[synchronous once it is
  big enough to want a block, and know where that line is.] Lesson 11 depends
  on this: RV32I's 32-entry register file needs a combinational read for a
  single-cycle CPU, and that turns out to be the right choice rather than a
  compromise.
]

== Lesson 07's puzzle, answered

#measured("identical code, different sizes")[
  #ttable(
    columns: (auto, auto, auto),
    [`font_small`], [32 bytes — lesson 07's font], [9 LUT4],
    [`font_full`],  [1024 bytes],                   [#strong[1 DP16KD]],
  )
]

Lesson 07's font became logic because it was #emph[too small to be worth a
block]. The right conclusion is not "use logic for small memories" — it is:
#strong[write the memory in the shape that can become a block RAM and let the
synthesiser decide on size.] Writing a shape that cannot removes the decision
for good.

=== `$readmemh` runs at elaboration time

```verilog
initial $readmemh("font.hex", mem);
```

The synthesiser reads the file #emph[during synthesis] and bakes the contents
into the bitstream. The hex file is therefore a #strong[source file] — change it
and you must resynthesise. This is the path lesson 13 uses to load a program,
and lesson 15 uses for a program compiled by GCC.

#watch[
  A ROM whose contents are all zero is not a ROM — it is a constant, and the
  synthesiser folds it away entirely. The lesson's font file begins with ASCII
  0–31, which have no glyphs, so synthesising it at 256 entries emits
  #emph[no memory at all]. "My ROM disappeared" usually means the file was not
  found, was empty, or was genuinely all one value across the range used.
]

== Two traps found while building it

#found[
  #strong[Registered write data.] The memory self-test registered `din` inside
  the clocked block, so by the time the RAM performed the write on the
  following edge, `addr` had already advanced. #emph[Every location held its
  neighbour's value] and the read-back reported 128 errors out of 128.

  A memory's address, write-enable and write-data must be presented in the
  #strong[same cycle]. Register some and not others and they arrive skewed —
  and the memory faithfully stores the skew.
]

#found[
  #strong[A constant multiply that was not free.] The framebuffer's address is
  `y × 96 + x`. A comment in the first draft predicted the synthesiser would
  reduce a constant multiply to shifts. It did not — it allocated #strong[two
  `MULT18X18D` hardware multipliers]. Writing `(y << 6) + (y << 5)` explicitly,
  since 96 = 64 + 32, removes them entirely.

  #ttable(
    columns: (auto, auto),
    [`wy * 96 + wx`], [1 DP16KD + #strong[2 MULT18X18D] + 8 CCU2C],
    [`(wy<<6) + (wy<<5) + wx`], [1 DP16KD + 14 CCU2C + 24 LUT4],
  )

  Third time in this course that the synthesiser did not do what the received
  rule said. If you know the cheap form, write the cheap form — then check.
]

#watch[
  Uninitialised memory reads as #strong[X] in simulation. The ECP5 happens to
  zero its block RAM from the bitstream, but Verilog does not promise it, so a
  test that relies on initialisation is testing the simulator. The lesson's
  framebuffer test writes its zeros explicitly, after an earlier version failed
  for exactly this reason.
]

== Why a framebuffer wants two ports

A display memory is written one way and read another, simultaneously: written
by coordinate in whatever order the drawing code likes, and read in raster
order relentlessly, because the display never stops. One port cannot serve both
without one side waiting, which is largely why the `DP16KD` exists at all.
