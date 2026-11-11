#import "../style.typ": *

= Lesson 02 — Combinational logic

#goals(
  concept: [Muxes, decoders and adders — the three structures everything else is made of.],
  build: [A 7-segment hex decoder and a parameterised adder, both verified exhaustively.],
  needs: [Lesson 01.],
)[
  - Recognise the mux and the decoder as mirror images, and find them in a CPU.
  - Explain why addition has a critical path at all.
  - Avoid the two silent width traps: shift results and discarded carries.
  - Measure why writing `+` beats building an adder from gates by 12×.
]

== The idea

Real designs are not built from gates any more than prose is built from
letters. Three structures account for most of a processor.

#strong[The multiplexer] selects: one of several inputs reaches the output.
Every point in a datapath where a value "comes from here, or from there" is a
mux, and lesson 13's CPU is mostly muxes with arithmetic between them.

#strong[The decoder] is the mux's mirror image: one input number, and exactly
one of 2#super[n] outputs goes high. Wherever a number must become a
#emph[choice] — instruction decode, address decode, one-hot state — there is a
decoder.

#strong[The adder] is the first structure with an interesting internal shape,
because each bit's result depends on a carry from the bit below.

== Theory

=== Carry propagation is why addition takes time

One bit of addition is two gates' worth of logic:

```verilog
assign s    = a ^ b ^ cin;                 // odd number of ones
assign cout = (a & b) | (cin & (a ^ b));   // at least two ones
```

Chain #emph[W] of them and the top bit of the sum cannot settle until the carry
has propagated through every stage below it. At 4 bits nobody cares. At 32 bits
it is the slowest thing in the CPU — and lesson 10 measures exactly that.

=== Two width traps

Both are silent, and both come from the same root: #strong[in Verilog, width is
part of the meaning.]

#watch[
  #strong[Shifts.] The result of `a << b` is as wide as `a`. So
  `assign y = 1'b1 << sel;` shifts a *one-bit* value, everything falls off the
  end, and `y` is always zero. The literal must be widened before it is
  shifted.

  #strong[Carries.] `a + b + cin` assigned to a W-bit destination throws the
  carry away. Widening the intermediate to W+1 bits is what keeps it. At 4
  bits this is wrong in exactly half of the 512 possible cases — and the sum
  bits are never corrupted, only the carry, which is what makes it hard to
  spot.
]

=== Latches

A combinational `always` block that fails to assign its output on some path
infers a #strong[latch] — a storage element with no clock, which is almost
never what you meant. The habit is to assign a default first and then override:

```verilog
always @(*) begin
    y = 1'b0;            // default FIRST, so no path is uncovered
    case (sel) ... endcase
end
```

== What it cost

#measured("a case statement and a ROM array are the same thing")[
  #ttable(
    columns: (auto, auto),
    [`seg7` — a 16-way `case` statement], [7 LUT4],
    [`seg7_rom` — the same table as an array of constants], [7 LUT4],
  )
  The synthesiser cannot tell the difference, because there is none. A `case`
  is not "logic" and an array is not "memory"; both describe one function of
  four inputs, and only the function survives.
]

#measured("hand-built addition versus the + operator")[
  #ttable(
    columns: (auto, auto, auto),
    [], [*at 4 bits*], [*at 32 bits — CPU width*],
    [built from full adders], [24 LUT4 + 17 muxes], [138 LUT4 + 74 muxes],
    [`a + b + cin`],          [#strong[3 CCU2C]],   [#strong[17 CCU2C]],
  )
  At CPU width that is #strong[212 cells against 17] — a factor of twelve.
]

The reason is what is #emph[absent] from the hand-built rows: there are no
`CCU2C` cells at all. The carry chain is dedicated hardware, one cell per two
bits, and when you write `a + b` the synthesiser recognises addition and maps
straight onto it. Write the same function as explicit gates and it sees gate
soup — it cannot prove that pile of XORs and ANDs is an adder, so the hard
carry logic goes unused.

#why[
  Lessons 01 and 02 point in opposite directions and both are true. In lesson
  01 the synthesiser #emph[discarded] your structure and kept only the
  function. Here it #emph[kept] your structure, because your structure
  prevented it from recognising the function.

  The rule underneath both: #strong[write what you mean, at the highest level
  you can, and let the tool match it to the hardware.] Build the ripple adder
  once to understand what a carry is. Then write `+` forever.
]

== Learning outcomes

Why a mux and a decoder are mirror images; why `1'b1 << sel` is always zero;
why a `case` statement and a lookup table cost the same; and why the
hand-built adder loses by twelve times in terms of what the synthesiser can
and cannot recognise.
