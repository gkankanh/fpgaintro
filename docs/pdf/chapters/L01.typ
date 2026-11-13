#import "../style.typ": *

= Lesson 01 — Logic gates

== The idea

Worth knowing by sight: every schematic in this course, and every diagram
`make graph` draws, is made of these.

#fig("/figures/gate-symbols.svg",
     [The seven gates every digital circuit is described with. The bubble means
      "and then invert".],
     width: 100%)

A gate is a Boolean function of its inputs. In Verilog you write it as a
permanent connection rather than as something that happens:

```verilog
assign y_and = a & b;
```

`assign` is not a statement that runs. There is no "when". It is a wire: if `a`
or `b` changes, `y_and` follows as fast as the silicon allows.

== Theory

=== NAND is universal

Every Boolean function can be built from NAND alone:

#ttable(
  columns: (auto, auto, 1fr),
  [*function*], [*from NAND*], [*why*],
  [`NOT a`],   [`NAND(a, a)`], [both inputs equal, so the AND is just `a`],
  [`a AND b`], [`NAND(NAND(a,b), NAND(a,b))`], [the second NAND is a NOT],
  [`a OR b`],  [`NAND(NOT a, NOT b)`], [De Morgan: `a|b == ~(~a & ~b)`],
  [`a XOR b`], [four NANDs], [the classic construction],
)

#fig("/figures/nand-xor.svg",
     [The classic one, drawn out: exclusive-OR from four NANDs. Hold on to
      this picture — the measurement below is about what became of it.],
     width: 76%)

Historically this mattered enormously: one gate type meant one mask, one part
number, one bin of 7400s on the shelf.

=== Exhaustive testing

A two-input gate has four possible inputs. There is no need to *choose* test
cases — check all of them, against truth tables written out by hand rather
than computed with the same operator being tested.

This is the last lesson where exhaustive testing is this trivial, and lesson 02
the last where it is possible at all: the counts go 4, then 512, then — by
lesson 10 — 4.6 × 10#super[19]. Build the habit while it is cheap.

== What it cost, and why it is the point

#cost([`gates_top` — eleven outputs, no state at all], (LUT4: 7), share: true)[
  No flip-flops at all: this design has no memory.
]

#measured("eleven outputs from seven LUT4s")[
  Fewer LUTs than outputs, because the synthesiser does not implement what you
  *wrote*: it works out what each output #emph[is] as a function of `a` and
  `b`, and shares whatever can be shared.

  The NAND-only constructions are the clearest case. `n_xor` was written as a
  chain of four NANDs; the synthesiser evaluated the function, found XOR, and
  programmed one lookup table. #strong[It never built the chain.]
]

The fabric has no gates, only 4-input lookup tables, so a 2-input AND and a
4-input XOR cost exactly the same — one LUT4 each, as does any other function
of up to four inputs however complicated. Minimising gate count, half of a
classic digital design course, is therefore almost pointless here. What costs
is the number of LUTs, their #emph[depth] — how many in series, which sets your
clock speed — and the routing between them.

=== The boundary that does matter

A LUT4 holds any function of four inputs. Five inputs needs at least two LUTs,
no matter how simple the function:

#ttable(
  columns: (auto, auto),
  [*function*], [*cost*],
  [`(a & b) | (c ^ d)`], [1 LUT4],
  [`((a^b) & (c|~d)) | (~a&b&c&d) | (a&~b&~c)` — far uglier, same 4 inputs], [1 LUT4],
  [`(a & b) | (c ^ d) | (e & ~a)` — one more input], [2 LUT4 + 1 mux],
)

#strong[Count inputs, not operators.] "Simplifying" a four-input expression
from five operators to three saves nothing.
