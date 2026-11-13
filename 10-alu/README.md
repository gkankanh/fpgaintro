# Lesson 10 — the ALU

**Concept:** 32-bit arithmetic and logic as one combinational block — and the
point where exhaustive testing becomes impossible.

**You will build:** the complete RV32I ALU, verified against a reference model
and against an independent second implementation.

**Needs the board:** no (it synthesises, but four buttons is a poor demo)

**Prerequisites:** lesson 08

**Paths:** editor only

**By the end you can:**

- Explain why RV32I has exactly ten integer operations.
- Derive subtraction, signed and unsigned comparison from one adder.
- Get signed less-than right, including where the difference overflows.
- Replace exhaustive testing with directed cases, randomisation and an independent model.
- Verify that a testbench has teeth, by mutating the design.

---

## The idea

From here the modules are not illustrations. They are the CPU's parts. This
ALU is the one lesson 13 executes instructions with, and lesson 16 pipelines.

RV32I's integer ALU has **ten operations and not one more**:

```
ADD  SUB  SLL  SRL  SRA  SLT  SLTU  XOR  OR  AND
```

A CISC machine might have hundreds. Everything else here is built by the
compiler out of these — negation is `sub` from `x0`, bitwise NOT is `xor` with
−1, branch-if-greater is branch-if-less with the operands swapped. That
austerity is the "reduced" in RISC, and it is a claim about what hardware
should cost rather than about what programmers should write.

![One bit of an ALU in gates: AND, OR and XOR gates and a full adder all computing at once on the same pair of operand bits, with a multiplexer choosing which result leaves](../docs/diagrams/alu-slice.svg)

### The encoding is a gift

RISC-V packs the selector into `{instruction[30], funct3}` — four bits:

| op | name | funct3 | bit 30 |
|---|---|---|---|
| `0000` | ADD | 000 | 0 |
| `1000` | SUB | 000 | **1** |
| `0001` | SLL | 001 | 0 |
| `0010` | SLT | 010 | 0 |
| `0011` | SLTU | 011 | 0 |
| `0100` | XOR | 100 | 0 |
| `0101` | SRL | 101 | 0 |
| `1101` | SRA | 101 | **1** |
| `0110` | OR | 110 | 0 |
| `0111` | AND | 111 | 0 |

Only **two** operations need bit 30 — and they are exactly the two pairs where
one is the signed/arithmetic variant of the other. So lesson 12's decoder can
pull this field straight out of the instruction word with no translation table
at all. That is deliberate, and it is the kind of thing you only notice when
you build the hardware.

## One adder does four jobs — [`alu.v`](./alu.v)

```verilog
wire subtract = (op == OP_SUB) || (op == OP_SLT) || (op == OP_SLTU);
wire [W-1:0] addend = subtract ? ~b : b;

adder #(.W(W)) u_add (.a(a), .b(addend), .cin(subtract), .s(sum), .cout(carry));
```

`a - b == a + (~b) + 1` in two's complement, so subtraction is the *same* adder
with `b` inverted and the carry-in set. One instance, not two — and it is
lesson 02's `adder`, now promoted to [`common/rtl/`](../common/rtl/) because
this is its second user.

And both comparisons fall out of that same subtraction for free.

### SLTU is the borrow

For an unsigned subtract, carry-out is 1 when there was **no** borrow, i.e.
when `a >= b`. So:

```verilog
wire ltu = ~carry;        // no comparator needed at all
```

### SLT is where ALUs go wrong

Signed less-than is **not** a comparison of the raw bits, and it is not simply
the sign of the difference either — because the difference can overflow.

```verilog
wire overflow = (a[W-1] ^ b[W-1]) & (sum[W-1] ^ a[W-1]);
wire lt       = sum[W-1] ^ overflow;
```

> **Watch out — the shortcut that nearly works.** "If the signs differ, the
> answer is just `a`'s sign; a negative number is always less than a positive
> one." That is true, and implementing it that way passes almost every test
> you would write by hand. It fails exactly where the subtraction overflows —
> `INT_MIN` against `INT_MAX`, and `0` against `INT_MIN`. This lesson's
> testbench checks those pairs by name, and the mutation test below confirms
> it catches the shortcut.

### The shift trap

```verilog
wire [W-1:0] sra = $signed(a) >>> sh;
```

> **Watch out** — `>>>` is an arithmetic shift **only if its left operand is
> signed**. Writing `a >>> sh` on an unsigned wire silently performs a
> *logical* shift. It compiles, it simulates, it lints clean, and it is wrong
> for every negative input. This is the single most common ALU bug, and
> `$signed(a)` is the whole fix.

Also note RV32I's rule: only the low 5 bits of `b` are the shift amount, and
**the rest are ignored, not an error**. A shift by 32 is a shift by 0 — which
C calls undefined behaviour and the hardware simply defines.

## Exhaustive testing is now impossible

A 32-bit ALU has 2³² × 2³² × 10 input combinations. That is **4.6 × 10¹⁹**
vectors; at a billion a second, 1,460 years. Lesson 02's strategy is gone, and
this is the pattern that replaces it everywhere from here on:

**1. Directed edge cases.** Twelve interesting operands — zero, one, −1,
`INT_MAX`, `INT_MIN`, `INT_MIN+1`, −2, the alternating patterns, shift amounts
31 and 32 — crossed against each other for all ten ops. 1,440 vectors that
cover every extreme against every other extreme.

**2. Randomised comparison against a reference model.** 20,000 vectors. The
model uses Verilog's own operators and `$signed`, while the DUT builds the same
results from an adder and explicit overflow logic — two different routes to one
answer.

**3. An independent second implementation, where a model would prove nothing.**
This is the subtle one. The DUT's shifts *are* Verilog's shift operators, so
checking them against the same operators tests nothing whatsoever. They are
cross-checked instead against [`shift_iterative`](./shifter.v), which shifts
one place per clock — a genuinely different implementation that can disagree.

```bash
cd 10-alu
make sim
```

```
PASS: 21499 checks - 1440 directed + SLT/SLTU extremes + shifts cross-checked
against an independent implementation + 20000 randomised
```

### Does the test actually work?

A test that has never caught a bug is unproven. So: break the design
deliberately and check the test notices. All three mutations were caught, with
the exact operands named:

| mutation | caught? |
|---|---|
| `sra = a >> sh` (drop `$signed`) | ✅ `SRA a=ffffffff b=00000001 -> 7fffffff, model says ffffffff` |
| `lt = sum[W-1]` (drop the overflow term) | ✅ `SLT a=00000000 b=80000000 -> 00000001, model says 00000000` |
| `ltu = carry` (wrong polarity) | ✅ `SLTU a=00000000 b=00000001 -> 00000000, model says 00000001` |

> **Why this matters** — mutation testing is the only way to know a testbench
> has teeth. Lesson 09 found a testbench asserting something false and passing;
> this is the systematic version of that check. Every testbench from here on
> is worth mutating once.

## What it cost

The surprise is in the proportions, so each piece is reported on its own.

`alu` — the whole thing:

```bash
make synth M=alu
```

| resource | count |
|---|---:|
| `LUT4` | 885 |
| `CCU2C` | 17 |
| `PFUMX` | 281 |
| `L6MUX21` | 127 |

885 of the 85F's 83,640 LUT4 — 1.06% of the part.

`adder` — 32-bit addition:

```bash
make synth M=adder
```

| resource | count |
|---|---:|
| `CCU2C` | 17 |

`shift_barrel` — single-cycle shifting:

```bash
make synth M=shift_barrel
```

| resource | count |
|---|---:|
| `LUT4` | 667 |
| `PFUMX` | 262 |
| `L6MUX21` | 139 |

`shift_iterative` — the same shifts in up to 31 cycles:

```bash
make synth M=shift_iterative
```

| resource | count |
|---|---:|
| `LUT4` | 76 |
| `TRELLIS_FF` | 40 |
| `CCU2C` | 3 |
| `PFUMX` | 32 |
| `L6MUX21` | 1 |

**The shifter is about 80% of the ALU.** The adder — the thing you would assume
an ALU is mostly about — is seventeen carry cells and essentially free, because
lesson 02's CCU2C chain does it in dedicated hardware. Shifting has no
dedicated hardware, so a barrel shifter is a tree of multiplexers log₂(32) = 5
layers deep and 32 wide, three times over for SLL, SRL and SRA.

And the iterative shifter is **seven times smaller**, at the cost of up to 31
cycles. On an 8-bit microcontroller that is the usual choice. In a single-cycle
CPU it is not available at all — every instruction must finish in one cycle —
so lesson 13 pays for the barrel shifter whether it likes it or not.

> **Why this matters** — "which operations are expensive" is not intuition, it
> is a property of the fabric. Addition is free here and shifting is not. On a
> chip with no carry chain the answer would invert.

## Timing — lesson 04 arrives with consequences

A registered 32-bit ALU, placed and routed:

```
Info: Max frequency for clock 'clk': 115.94 MHz (PASS at 25.00 MHz)
```

**That is the ceiling.** Lesson 13's single-cycle CPU must do instruction
fetch, decode, register read, *this ALU*, memory access and writeback all
within one clock period — so its clock will be well under 116 MHz, and the ALU
is only one of the things on that path.

nextpnr names the path, and the net name alone is readable:

```
y_o_..._CCU2C_COUT_CIN_CCU2C_COUT_CIN_CCU2C_COUT_..._LUT4_Z_C_PFUMX_Z_...
```

A chain of carry cells, then a stack of LUT4s and a wide mux: the adder's carry
propagating all the way up, *then* the result multiplexer selecting between ten
candidates. Both are on the critical path, which is exactly the argument lesson
16 makes for splitting them across pipeline stages.

## Icestudio

```bash
open 10-alu/icestudio/shifter.ice
```

`shift_barrel` at `W` = 8 — SLL, SRL and SRA in one expression, with no clock
anywhere in it. `a` is a constant on the canvas, `sw2..sw0` set the shift
amount, `sw3` picks the direction and FIRE2 makes a right shift arithmetic.

Load `10110010`, shift right, then hold FIRE2: the sign bit fills in instead
of zeros, and keeps filling until the whole byte is ones. That one bit of
difference is what RV32I spends `inst[30]` on, and why the expression needs
`$signed()`.

The 32-bit ALU itself stays on the editor path. 32 bits in and 32 out is 64
pins; the board has 19 usable. A testbench can drive all of them at once.

## Exercises

1. **Mutate it yourself.** Change `ltu = ~carry` to `ltu = carry` and run
   `make sim`. Then try `overflow = 1'b0`. Which directed vectors catch each?
2. **Remove `$signed`.** Change `sra` to `a >>> sh` and watch which test fails
   — note that the *model* comparison cannot catch it, only the cross-check
   against `shift_iterative`.
3. **Count the shifter.** Synthesise `shift_barrel` at `W` = 8, 16, 32, 64.
   Does the cost grow linearly, or as *W* log *W*? Does the measurement match
   the theory?
4. **Drop a shift.** Remove SRA from the result mux and re-measure the ALU.
   How much of the 885 LUT4 was that one operation?
5. **Make SLT expensive.** Replace the overflow logic with a separate 32-bit
   signed comparator (`$signed(a) < $signed(b)`). Does yosys build a second
   subtractor, and what does it cost?

## Wrap-up

**What you built.** The complete RV32I ALU, verified against a reference model and an independent second implementation — 885 LUT4, of which the shifter is about 80%.

**What to keep.** Which operations are expensive is a property of the fabric, not of arithmetic.

**What comes next.** Lesson 11 builds the thing that feeds it: the register file.
