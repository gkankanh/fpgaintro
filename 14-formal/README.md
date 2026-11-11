# Lesson 14 — formal verification

**Concept:** proving a property for *all* inputs, instead of testing the cases
you thought of.

**You will build:** a proof that lesson 10's ALU is correct for every one of
its 2⁶⁴ input pairs, and that lesson 11's register file is correct for every
sequence of twelve operations.

**Needs the board:** no

**Prerequisites:** lesson 13

**Paths:** editor

---

## Why this lesson is here

Lesson 13 made the argument by accident. A bug in `LUI` got through **161
passing decoder checks on a mutation-tested testbench**, because the test asked
*"does LUI request an ADD?"* — it does — and never asked *"where do its operands
come from?"* The bug lived in an assumption nobody had written a test against.

And lesson 10 put a number on the other half. A 32-bit ALU has
2³² × 2³² × 10 ≈ **4.6 × 10¹⁹** input combinations. At a billion a second,
checking them all takes **1,460 years**, so lesson 10 settled for 1,440
directed vectors and 20,000 random ones.

```bash
cd 14-formal
make sim
```

```
  ALU correct for all 2**64 inputs   proved
```

**One second.** Not sampled — proved, over every input.

> **Why this matters** — a testbench *samples* the input space. A solver
> *searches* it. The difference is not that formal is more thorough; it is
> that thoroughness stops being a function of how much time you spend.

## What a bounded model checker does

It takes a property and either proves it holds in every reachable state within
*k* cycles of reset, or hands you a concrete trace where it fails.

**"Bounded" is doing real work**, and it is worth knowing when it costs you
something and when it does not:

| | |
|---|---|
| **Combinational logic** | depth 1 examines every possible input in one step. For the ALU, bounded is a **complete** proof — the bound costs nothing. |
| **Sequential logic** | depth *k* proves every *k*-step sequence and says nothing about step *k+1*. The register file is proved to depth 12. |

Bugs needing a specific twenty-step sequence do exist. But a solver searching
*every* twelve-step sequence over *every* address and *every* data value is
doing something no testbench approaches.

## Three kinds of statement

| | |
|---|---|
| `assert` | must always be true. The thing being proved. |
| `assume` | a constraint on the inputs. **The dangerous one.** |
| `cover` | "show me a trace reaching this state". The antidote to the above. |

### Writing properties that mean something

A property that restates the implementation proves nothing. The ALU's shifts
*are* Verilog's shift operators, so asserting `sll == a << sh` asserts `x == x`.

So the shift properties are written as independent facts about what a shift
must **do**:

```verilog
// A left shift vacates the low bits...
assert ((y & ~(32'hFFFF_FFFF << sh)) == 32'd0);
// ...and an arithmetic right shift fills the vacated high bits with
// copies of the sign bit.
if (a[31]) assert ((y & ~(32'hFFFF_FFFF >> sh)) == ~(32'hFFFF_FFFF >> sh));
```

Lesson 10 answered the same objection with a second *implementation*. Formal
lets you answer it with a *specification*.

The arithmetic properties need no such care: the ALU builds add, subtract and
both comparisons from one adder with explicit overflow logic, while the
property compares against the language's own arithmetic. Two genuinely
different routes to one answer — now checked for all 2⁶⁴ operand pairs.

> **Watch out — the first thing formal finds is usually a bug in your
> property.** The first run of this proof failed, and the design was fine. The
> property was `assert (y[sh-1:0] == ...)`, which is not a legal variable
> part-select, with a right-hand side that was nonsense. The counterexample
> showed `0x02000001 << 1 = 0x04000002` — exactly correct. Expect this. The
> tool is unforgiving about what you actually wrote.

## The register file: proving something tests cannot

Lesson 11 verified all 961 pairs of distinct registers. Here is the stronger
claim:

```verilog
(* anyconst *) reg [4:0] watched;      // the SOLVER picks the address
reg [31:0] shadow;

always @(posedge clk)
    if (we && rd == watched && watched != 0) shadow <= wdata;

always @(*)
    if (shadow_valid && rs1 == watched) assert (rd1 == shadow);
```

`anyconst` is what makes this a proof rather than a spot check. The solver
chooses `watched`, and must make the property hold for **every** choice — so
one shadow register proves a property about all thirty-two.

What it establishes: *after any sequence of writes to any registers, reading
any register returns exactly what was last written to it*, and `x0` reads zero
under every possible write sequence. A test can write to `x0` a few times and
check. This is the difference between evidence and a guarantee.

```bash
make formal        # includes the register file — about a minute
```

## Watching it catch a real bug

[`broken_alu.v`](./broken_alu.v) is lesson 10's ALU with one change — signed
less-than using the shortcut that nearly works:

```verilog
wire lt = sum[W-1] ^ overflow;   // correct
wire lt = sum[W-1];              // broken_alu.v
```

Lesson 10 warned that this fails only where the difference overflows. That
region is a vanishing fraction of 2⁶⁴ pairs, and 20,000 random vectors would
very likely miss it.

```bash
make formal-broken
```

The solver produces the operands in **under a second**:

```
a = 0x80008000   signed  -2147450880
b = 0x57FE8001   signed   1476296705

signed:  -2147450880 < 1476296705  ->  1
broken ALU answered:  0
```

Signs differ, the difference overflows, and the shortcut gives the wrong
answer — precisely the case lesson 10 described. Nobody told the solver to
look there.

```bash
make wave          # the counterexample, in gtkwave
```

## The failure mode that makes formal dangerous

This is the most important section in the lesson.

[`vacuous.v`](./vacuous.v) uses the **real** ALU, makes **true** assertions
about it, and **passes** — while proving almost nothing. One line is
responsible:

```verilog
assume (a == b);
```

With the operands forced equal, `a < b` is false for every input the solver
may consider. The assertion becomes `0 == 0`. The overflow logic is never
exercised. **Replace the ALU with one returning a constant zero and this proof
still passes.**

Nobody writes `assume (a == b)` deliberately. They write an assumption to
exclude an input the design is not meant to handle, it is slightly too strong,
and the hole is invisible — because a passing proof looks identical either way.

```bash
make formal-vacuous
```

```
--- the proof passes ---
SBY  DONE (PASS, rc=0)

--- and the cover shows it was worthless ---
SBY  Unreached cover statement at vacuous.v:63   cover (y == 32'd1);
SBY  Unreached cover statement at vacuous.v:64   cover (a == 32'h8000_0000 && b == 0);
```

> **Why this matters** — `cover` is not optional decoration. An assertion says
> "this is always true"; a cover says "this is reachable, show me". If a cover
> you expect to be reachable is not, your assumptions have excluded part of
> reality and every assertion resting on them is suspect.
>
> **A formal proof is only as good as its assumptions, and nothing in the
> output tells you whether they were right.** The covers are the only thing
> standing between you and a false sense of security.

The real ALU proof carries seven covers for exactly this reason — including
that signed and unsigned comparison genuinely disagree, that `SRA` differs
from `SRL`, and that addition wraps around. All seven are reached.

## What this lesson does not do

**`riscv-formal`.** Claire Wolf's instruction-level specification of RV32I can
check a whole core against the ISA, and applying it to lesson 13's CPU is the
natural next step. It needs the core to expose a trace interface reporting
what it retired each cycle, plus the riscv-formal repository itself. That is a
lesson's worth of work on its own and is not here yet.

What *is* here is the technique it rests on, applied to the two components the
CPU is mostly made of.

## Exercises

1. **Break something else.** Change `ltu = ~carry` to `ltu = carry` in lesson
   10's ALU and run `make sim`. How long does the solver take, and is the
   counterexample the one you would have written?
2. **Write a vacuous proof on purpose.** Add `assume (b == 0)` to
   `alu_props.v`. Which assertions become trivial? Which covers stop being
   reached?
3. **Find the depth that matters.** Lower the register file proof to depth 2
   and raise it to 20. Does the time grow linearly? At what depth does it stop
   being practical?
4. **Prove the branch comparator.** Lesson 13's `branch_unit` is combinational
   and has six conditions. Prove all six against independent expressions — it
   should take about twenty lines and one second.
5. **Prove something false.** Assert that the ALU's `SLL` never produces zero.
   Read the counterexample, and notice it is minimal rather than merely valid.

## What you should now be able to explain

- Why depth 1 is a complete proof for combinational logic and not for anything
  with state.
- Why a property restating the implementation proves nothing, and two
  different ways to avoid it.
- What `anyconst` buys, and why one shadow register proves a fact about
  thirty-two.
- Why `cover` is the only defence against a vacuous proof.
- Why a passing proof with a bad assumption is more dangerous than no proof.

**Next:** [lesson 15 — a system on chip](../15-soc/), where the CPU gets a
memory map and runs C.
