# Lesson 11 — the register file

**Concept:** two reads and one write per cycle from one array, and the one
register that is hardwired to zero.

**You will build:** RV32I's 32×32-bit register file, plus a block-RAM
alternative, measured against each other at two very different sizes.

**Needs the board:** optional — the demo makes x0's behaviour visible

**Prerequisites:** lesson 10

**Paths:** editor only

**By the end you can:**

- Explain why RISC instructions have at most two source registers.
- Explain what `x0` buys, and count the instructions it eliminates.
- Justify a combinational read here, having been warned against one in lesson 08.
- Explain why read-during-write must return the old value.
- Distinguish a mutation that survives from a test that is weak.

---

## The idea

```
add rd, rs1, rs2
```

One instruction, **two source operands read in the same cycle**, one result
written. So the register file needs two read ports and one write port — and
that is not a design choice made after the fact. If it had three read ports,
instructions could have three sources. If it had one, R-type instructions as we
know them could not exist.

> **Why this matters** — the instruction set and the register file are the same
> design decision seen from two sides. Register-file ports are expensive, and
> that cost is visible in the shape of every RISC instruction set. This is the
> clearest example in the course of hardware constraints writing software
> syntax.

![The register file as gates and flip-flops: a 5-to-32 decoder enabled by the write-enable raising one register's load line, two 32-to-1 multiplexers forming the read ports, and x0 wired to a constant zero](../docs/diagrams/regfile-gates.svg)

## x0

Reads of `x0` return zero. Writes to `x0` are discarded. Two lines of Verilog:

```verilog
if (we && rd != 0) regs[rd] <= wdata;              // absorbs writes
assign rd1 = (rs1 == 0) ? 32'd0 : regs[rs1];       // reads as zero
```

And they simplify the whole instruction set. None of the following are real
instructions — they are assembler conveniences that exist *because* one
register reads as zero and swallows writes:

| what you write | what it assembles to |
|---|---|
| `mv rd, rs` | `addi rd, rs, 0` |
| `li rd, imm` | `addi rd, x0, imm` |
| `nop` | `addi x0, x0, 0` |
| `not rd, rs` | `xori rd, rs, -1` |
| `neg rd, rs` | `sub rd, x0, rs` |
| `beqz rs, L` | `beq rs, x0, L` |
| `j L` | `jal x0, L` — throw the return address away |
| `ret` | `jalr x0, 0(x1)` |

One register sacrificed; eight instructions avoided. `jal x0, L` is the neatest
of them: a jump-and-link whose link register is the bit bucket *is* an
unconditional jump, so the ISA needs no separate `j` opcode at all.

## Reads are combinational, and lesson 08 says that is right

A single-cycle CPU must read its operands, compute, and write back inside one
clock period. So the read has to be combinational — the address goes in and the
data comes out in the same cycle, with no latency to absorb.

Lesson 08 established that a combinational read **cannot** become a block RAM.
That sounded like a warning. Here it is the correct answer, because lesson 08's
other finding applies: at a few tens of entries the ECP5 builds arrays from
LUTs as *distributed* RAM (`TRELLIS_DPR16X4`), cheaply and with no latency. 32
entries is firmly in that range.

This is the payoff of having measured rather than memorised. "Always use block
RAM for memories" would have been the wrong rule here.

## Read-during-write: the old value is correct

```verilog
// cycle N: an instruction reads rs1, computes, and its result is written
//          by the clock edge at the END of cycle N
```

So a read of the register being written returns the **old** value. That is not
a limitation — it is required. An instruction must see its operands as they
were before it ran.

> **Watch out** — this confuses people in both directions. Some expect a
> write-to-read bypass and are surprised by the old value; others add one and
> silently change what their CPU computes. The testbench asserts the old value
> explicitly, so that adding a bypass later is a visible, deliberate change.
>
> Bypass becomes *necessary* when a read and a write belong to different
> instructions in flight at once. That is lesson 16's pipeline — and the block
> RAM variant below, where latency forces the issue.

## The alternative, and what it costs

[`regfile_bram.v`](./regfile.v) builds the same interface from memory blocks.
Three things follow immediately:

**The array must be duplicated.** A DP16KD has two ports, and one is needed for
writing — so two read ports means two banks, written identically. That is why a
2-read/1-write register file costs *two* memories, not one.

**The read is registered**, one cycle late, which changes the CPU around it:
either an extra pipeline stage, or a slower clock.

**The bypass is no longer optional.** With latency, a read issued in the same
cycle as a write to the same address would present stale data, so the hit must
be remembered and the written value substituted on the way out. And because the
*address* is now registered too, even x0's zero-check has to be delayed to
match. Latency makes everything one step more awkward, which is the lesson.

## What it cost, at 32 registers

`regfile` — combinational read, as RV32I needs:

```bash
make synth M=regfile
```

| resource | count |
|---|---:|
| `LUT4` | 266 |
| `PFUMX` | 132 |
| `L6MUX21` | 66 |
| `TRELLIS_DPR16X4` | 32 |

266 of the 85F's 83,640 LUT4 — 0.32% of the part.

`regfile_bram` — the same file, asking for block RAM:

```bash
make synth M=regfile_bram
```

| resource | count |
|---|---:|
| `LUT4` | 214 |
| `TRELLIS_FF` | 108 |
| `PFUMX` | 6 |
| `L6MUX21` | 4 |
| `TRELLIS_DPR16X4` | 32 |

Look at what is **missing** from the second row: there is **no `DP16KD` at
all.** Thirty-two entries is too small for yosys to spend a block RAM on, so
the "block RAM version" got distributed RAM too — the same storage, plus 108
flip-flops of pipeline registers, plus a cycle of latency, for nothing.

**Asking for block RAM at this size does not even get you block RAM.** It gets
you a slower version of the same design.

## And at 1024 registers

Same two modules, same code, with `P="DEPTH 1024"` on each command:

| | cost |
|---|---|
| `regfile` — combinational read | **3,660 LUT4** + 454 muxes + 1,024 `TRELLIS_DPR16X4` |
| `regfile_bram` — registered read | **4 `DP16KD`** + 192 LUT4 + 131 `TRELLIS_FF` |

And there is the line. At 1024 entries the combinational version is roughly
5,100 cells and the memory version is four block RAMs and a handful of logic.
Same two modules, same code, opposite conclusion — decided entirely by size.

> **Why this matters** — a vector machine's register file, or a large
> scratchpad, lives on the right-hand side of that table. RV32I's lives firmly
> on the left. Neither module is "better"; the question is always *at what
> size*, and the answer takes two seconds to measure.

## Simulate it

```bash
cd 11-regfile
make sim
```

```
PASS: 1062 checks - all 31 registers from both ports, all 961 port pairs,
x0 reads zero and absorbs writes, read-during-write gives the old value,
BRAM variant agrees one cycle late
```

Notice that exhaustive testing is briefly **back**. A register file has 32
addresses, not 2³² values, so the thing that matters — *which register* — can be
swept completely. All 961 pairs of distinct registers are read simultaneously,
which is what catches a second port quietly sharing the first one's address
decoder.

### Mutation testing, and a mutation that should survive

| mutation | caught? |
|---|---|
| x0 not masked on the read path | ✅ `x0 did not read as zero on port 1` |
| port 2 reads port 1's address | ✅ `ports x1/x2: got f06a0855/f06a0855` |
| a write-to-read bypass added | ✅ `read-during-write returned the NEW value` |
| **writes to x0 allowed** | ❌ **survives** |

That last one is worth dwelling on, because an uncaught mutation is not
automatically a weak test.

Removing the write guard lets `regs[0]` hold garbage — but the read path masks
x0 *unconditionally*, so that garbage is never observable. The design is still
correct. The mutation survives because **x0's behaviour is enforced in two
independent places, and either one alone is sufficient.**

Remove *both* guards and the test fails immediately. So the correct reading is
not "the test is weak" but "the code is deliberately redundant" — and no
behavioural test can distinguish them, because there is no behavioural
difference. A test that reached inside to inspect `regs[0]` would be testing
the implementation rather than the contract.

> **Why this matters** — mutation testing tells you two different things, and
> distinguishing them is the skill. A surviving mutation means either your test
> missed something, or your code has belt-and-braces redundancy. Check which
> before "fixing" anything.

## On the board

```bash
make prog
```

- `sw[3:0]` — which register (x0 … x15)
- `btn[1]` — write a value derived from the register number
- `btn[2]` — read, showing the low byte

**Set the switches to 0, press write, then read: the LEDs stay dark.** However
many times you write to x0, it reads as zero. Set them to anything else and the
value appears. That is x0's entire behaviour, on eight LEDs.

The demo synthesises to almost nothing (4 LUT4) because only one byte is ever
observed and only sixteen registers are reachable, so yosys prunes the rest.
The standalone module measurements above are the real numbers.

## Icestudio

```bash
open 11-regfile/icestudio/regfile.ice
```

Eight registers of eight bits. Hold UP/DOWN/LEFT as the write address, press
FIRE2 to store `0xA5`, then set `sw2..sw0` to read it back on the LEDs.

Then write to register 0 and read it back. Nothing happens, and the reason is
the line worth remembering: `rd1 = (rs1 == 0) ? 0 : regs[rs1]` is a mux on the
*output*, not a zero stored in `regs[0]`. A stored zero works until something
writes there; a mux cannot be wrong.

`rs2` is tied off and `rd2` declared but unconnected, because eight LEDs is
one read port's worth. Both ports are exercised together in the testbench.

## Exercises

1. **Add a third read port.** How does the cost change — linearly, or worse?
   This is the measurement behind "register-file ports are expensive".
2. **Make x0 a real register.** Remove both guards and store zero into
   `regs[0]` at reset instead. It works until something writes to x0 — find
   the shortest instruction sequence that breaks it.
3. **Find the crossover.** Sweep `N` between 32 and 1024 for both modules and
   find the size at which `regfile_bram` starts producing `DP16KD` cells at
   all. Is it where you would have guessed?
4. **Add the bypass deliberately.** Put a write-to-read bypass in `regfile`,
   watch test 5 fail, and then work out what a single-cycle CPU would compute
   wrongly as a result.
5. **Count the flip-flops that are not there.** `regfile` at N=32 stores 1,024
   bits but reports zero `TRELLIS_FF`. Where are those bits? (`make graph`
   helps.)

## Wrap-up

**What you built.** A register file with two read ports, one write port and an `x0` that reads as zero — 266 LUT4, 32 distributed RAMs, and no block RAM at all.

**What to keep.** Size decides how storage gets built, and a combinational read is the right answer here for the reason lesson 08 warned against it elsewhere.

**What comes next.** Lesson 12 produces the control signals that tell the ALU and the register file what to do.
