# Lesson 01 — logic gates

**Concept:** AND, OR, NOT, NAND, NOR, XOR — and the fact that this FPGA
contains none of them.

**You will build:** every two-input gate, verified against its complete truth
table, plus NAND-only versions of four of them.

**Needs the board:** no (but there is a nice payoff if you have one)

**Prerequisites:** lesson 00

**Paths:** editor + visual

**By the end you can:**

- Write combinational logic as continuous assignment, not as statements.
- Test exhaustively while the input space still allows it.
- Explain NAND universality, and why it mattered more in 1975 than now.
- Measure why a 2-input AND and a 4-input XOR cost the same.

---

## The idea

A gate is a Boolean function of its inputs. These are the symbols, and they
are worth knowing by sight: every schematic in this course, and every diagram
`make graph` draws for you, is made of them.

![The seven basic logic gates: AND, OR, XOR, NOT, NAND, NOR and XNOR, each with its Verilog expression and truth table](../docs/diagrams/gate-symbols.svg)

In Verilog you write a gate as a permanent connection rather than as something
that happens:

```verilog
assign y_and = a & b;
```

`assign` is not a statement that runs. There is no "when". It is a wire: if `a`
or `b` changes, `y_and` follows, as fast as the silicon allows. Nothing is
clocked in this lesson — that starts in lesson 03.

Two things are worth re-establishing while the designs are this small.

**NAND is universal.** Every Boolean function can be built from NAND alone.
Four of them, one line each:

| function | from NAND | why |
|---|---|---|
| `NOT a` | `NAND(a, a)` | both inputs equal, so the AND is just `a` |
| `a AND b` | `NAND(NAND(a,b), NAND(a,b))` | the second NAND is a NOT |
| `a OR b` | `NAND(NOT a, NOT b)` | De Morgan: `a\|b == ~(~a & ~b)` |
| `a XOR b` | four NANDs, see the source | the classic construction |

That last one is worth drawing, because the lesson's measurement is about what
happens to it:

![Exclusive-OR built from four NAND gates: the first NANDs a and b, two more combine that result with each input, and the fourth NANDs those together](../docs/diagrams/nand-xor.svg)

Historically this mattered enormously: one gate type meant one mask, one part
number, one bin of 7400s. Which brings us to the second point.

**This FPGA has no gates.** The ECP5's logic is made of **4-input lookup
tables**: sixteen configuration bits holding the truth table of whatever
function you want, selected by the four inputs. Your `a & b` does not become an
AND gate. It becomes a LUT4 loaded with the AND truth table, two inputs unused.

The consequence is immediate and measurable: a 2-input AND and a 4-input XOR
cost *exactly the same*. One LUT4 each. So does any other function of up to
four inputs, however complicated.

> **Why this matters** — minimising gate count, which is half of what a classic
> digital design course teaches, is almost pointless on an FPGA. What costs is
> the number of LUTs, their *depth* (how many in series, which sets your clock
> speed — lesson 04), and how much routing they need. Rewriting an expression
> to use three gates instead of four usually changes nothing at all.

## The design

[`gates.v`](./gates.v) is the gates; [`gates_top.v`](./gates_top.v) wires them
to the board. Two files because one module per file is the right habit, and
because `make lint` complains otherwise.

The direct versions are the obvious seven lines. The NAND-only versions share
one subexpression:

```verilog
wire nab = ~(a & b);              // the shared NAND(a, b)

assign n_not = ~(a & a);
assign n_and = ~(nab & nab);

wire na = ~(a & a);
wire nb = ~(b & b);
assign n_or  = ~(na & nb);        // De Morgan

wire w1 = ~(a & nab);             // XOR, four NANDs
wire w2 = ~(b & nab);
assign n_xor = ~(w1 & w2);
```

> **Watch out** — `&` and `&&` are different operators and the difference is
> invisible until it bites. `&` is bitwise: it operates on each bit position.
> `&&` is logical: it reduces each side to true/false and returns one bit. On
> single-bit signals they agree, which is exactly why the habit of reaching for
> `&&` survives long enough to produce a bug on a 4-bit bus. Use `&` for
> hardware. Exercise 3 makes the failure visible.

In the board wrapper, `led[0]` is an equivalence check:

```verilog
wire agree = (n_not === y_not) && (n_and === y_and)
          && (n_or  === y_or ) && (n_xor === y_xor);
```

Press any combination of the two buttons and it stays lit. That is NAND
universality demonstrated on hardware rather than asserted in a textbook.

## Simulate it

```bash
cd 01-gates
make sim
```

```
PASS: 44 checks over all 4 input combinations
```

A two-input gate has four possible inputs, so the testbench does not choose
test cases — it checks all of them, against truth tables written out by hand
rather than computed with the same operator being tested. Then it checks each
NAND construction against its direct counterpart.

This is the last lesson where exhaustive testing is this trivial, and lesson 02
is the last where it is possible at all. Enjoy it.

Note the comparisons use `!==` rather than `!=`, so an undriven `x` counts as a
failure instead of comparing as "unknown, could be fine".

```bash
make wave
```

Four time steps, eleven outputs. The whole truth table, readable at a glance —
worth looking at once simply because a waveform this small is a waveform you
can fully understand.

## What it cost

`gates_top` — the whole design:

```bash
make synth
```

| resource | count |
|---|---:|
| `LUT4` | 7 |

7 of the 85F's 83,640 LUT4 — less than 0.01% of the part.

Eleven outputs, **seven** LUT4s — and no flip-flops at all, because nothing
here stores anything.

Fewer LUTs than outputs, because yosys does not implement what you wrote — it
works out what each output *is*, as a function of `a` and `b`, and then shares
whatever can be shared. There are only sixteen possible functions of two
variables, and eleven outputs drawn from that set leave plenty of overlap.

The NAND-only constructions are the clearest case. You wrote `n_xor` as four
NANDs; the synthesiser evaluated the function, found XOR, and programmed a LUT.
It never built the chain.

Which is the lesson, measured: **the structure you wrote was discarded and only
the function survived.** Verify it for yourself — `make graph` and look for the
NAND chains.

```bash
make graph      # -> gates_top.svg
```

## On the board

```bash
make prog
```

`btn[1]` (FIRE1) is `a`, `btn[2]` (FIRE2) is `b`. From `led[7]` down:
AND, OR, NOT a, NAND, NOR, XNOR, XOR, and then `led[0]`, the agreement check,
which should never go out.

The buttons are not debounced, and do not need to be — bounce on a
combinational input gives you a flickering LED, not a wrong answer. That
changes the moment something is clocked, in lesson 03.

## Icestudio

```bash
open 01-gates/icestudio/gates.ice
```

Here the visual path is at its best: the gates really do look like gates, and
the four-NAND XOR is visibly four NANDs. Compare that diagram with the
schematic `make graph` produced from the same source and you can see the
synthesiser throwing your structure away.

## Exercises

1. **XNOR from NAND.** Five NANDs will do it. Add `n_xnor` to `gates.v`, add a
   check to the testbench, and confirm `make synth` still reports 7 LUT4s.
2. **OR from NOR only.** NOR is also universal. Build OR, AND and NOT from it.
3. **`&` vs `&&`.** Change `y_and = a & b` to `a && b` — still passes, because
   the signals are one bit wide. Now widen `a` and `b` to `[3:0]`, make `y_and`
   `[3:0]`, and watch the two versions disagree. Predict the disagreement
   before you run it.
4. **Four inputs, one LUT.** Write `y = (a & b) | (c ^ d)` and check
   `make synth`. Then add a fifth input and check again. Where does the cost
   jump, and why exactly there?
5. **De Morgan, proved.** Write `~(a & b)` and `(~a | ~b)` as two outputs and
   have the testbench assert they are equal for all four inputs. This is a
   proof by exhaustion — and lesson 14 is about what to do when exhaustion
   stops being an option.

Worked answers to 1, 3 and 4 are in [`solutions/`](./solutions/).

## Wrap-up

**What you built.** Every two-input gate, tested against its complete truth table, and four of them rebuilt from NAND alone — eleven outputs that cost seven LUT4.

**What to keep.** The synthesiser keeps your function and discards your structure.

**What comes next.** Lesson 02 assembles those gates into the three structures a processor is actually made of, where structure starts to matter again.
