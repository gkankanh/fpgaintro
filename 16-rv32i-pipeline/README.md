# Lesson 16 — pipelining

**Concept:** overlapping instructions, and the hazard logic that makes overlap
safe.

**You will build:** a 5-stage version of the same core, running the same
programs, at nearly twice the clock.

**Needs the board:** yes

**Prerequisites:** lesson 15 (and lesson 04, whose PLL this lesson finally has
a use for)

**Paths:** editor only

**By the end you can:**

- Explain why pipelining raises the clock without making any stage faster.
- Identify data, control and structural hazards.
- Explain which hazard forwarding can fix and which it cannot.
- Measure cycles-per-instruction and say where every extra cycle went.
- Say when pipelining makes a program *slower*, and prove it.

---

## The idea

The same work, cut into five pieces with registers between them, so five
instructions can be in the machine at once and the clock period only has to
cover the longest **piece** instead of the whole chain.

```
IF  ──>  ID  ──>  EX  ──>  MEM  ──>  WB
fetch   decode    ALU     memory   register
        + read    +       access    write
        regs    branch
```

Lesson 13's core did all of that between one clock edge and the next, and
measured 61.24 MHz; as a computer with real memory (lesson 15) it measured 28.
Nothing here makes any single step faster. The clock goes up because no step has
to finish inside the same period as all the others.

> **Why this matters** — a pipeline is not a different processor. It is the
> same parts in a different arrangement: the ALU is still lesson 10's, the
> register file lesson 11's, the decoder and immediate generator lesson 12's,
> the branch comparator and aligners lesson 13's. Not one of those files is
> touched by this lesson, which is why lesson 14's proof of the ALU still
> holds, unchanged and unre-run.

And it costs three things, which are the whole of [`cpu5.v`](./cpu5.v):

1. **Registers.** Lesson 13's entire core had 32 flip-flops — the program
   counter. This one has 414. That difference *is* pipelining.
2. **Hazards.** Instruction *N+1* may need a result instruction *N* has not
   written yet. Forwarding, stalling and flushing, in that order of preference.
3. **CPI above 1.** The single-cycle core retired exactly one instruction per
   cycle, by construction. This one manages it only when nothing goes wrong.

## The design

### The memory's output register is the IF/ID register

A block RAM's output is registered inside the block — lesson 08's rule, and the
reason lesson 15's asynchronous memory cost 2,756 LUT4 and no `DP16KD`. A
pipelined core asks in one stage and uses the answer in the next, which is
*exactly* the shape a block RAM offers.

So the pipeline does not merely tolerate the memory's latency. It is the reason
the latency is free. And the register holding the fetched instruction for the
whole of ID is the block RAM's own output register, which costs nothing because
the block RAM has it either way:

```verilog
assign imem_en = !halt_ill && (redirect || !stall);
```

That enable is also how the core stalls. Hold it low and ID keeps the
instruction it already has.

### Forwarding: do not wait for the register file

Two places already hold a value the ALU is about to need:

| source | what it has |
|---|---|
| `EX/MEM` | the instruction one ahead — its ALU result is computed |
| `MEM/WB` | the instruction two ahead — including a *loaded* word, which exists nowhere else yet |

`EX/MEM` wins when both match, because the nearer instruction is the more
recent one and the more recent one is right.

> **Watch out** — the MEM-stage value of a **load** is not its result, it is
> its *address*. Forwarding that would be a silent disaster: the program gets a
> pointer where it wanted a value and computes confident nonsense. The stall
> below is what prevents it, and `cpu5.v` carries a simulation-only assertion
> that fires if it ever doesn't.

### The bypass lesson 11 predicted

Lesson 11's register file has no write-to-read bypass, and its comment says
exactly why that was right then and wrong now:

> *"Bypass becomes necessary when a read and a write belong to **different**
> instructions in flight at once. That is lesson 16's pipeline."*

Here is that case. An instruction in WB writes its result at the *end* of a
cycle; an instruction in ID reads the register file *during* that cycle and gets
the old value. They are four instructions apart — too far for EX forwarding, too
close for the write to have landed. One mux on each read port, in ID, fixes it.

### The one hazard forwarding cannot fix

A load's result does not **exist** until WB: the memory is synchronous, so the
word asked for in MEM arrives in the cycle after. An instruction needing it one
instruction later would have to read it a cycle before it exists, and no amount
of wiring moves a value backwards in time.

So: stall one cycle, and forwarding handles the rest. That is the **load-use
hazard**, it costs exactly one bubble, and it is why compilers bother to
schedule an unrelated instruction into the slot after a load.

A bubble is not a special instruction, incidentally. It is `valid` going low,
with every control signal that could change state forced off.

### Control hazards, and a question lesson 12 was never asked

Branches resolve in EX, using the *forwarded* operands — which is why resolving
them in ID would need a second forwarding network. Resolving in EX costs **two**
wrong instructions on every taken branch, the two already fetched behind it.
Resolving in ID would cost one. Predicting would cost none, when right. This
core does the simplest correct thing, and the measurements below say what that
was worth.

The stall logic also needs something lesson 12's decoder does not produce:

```verilog
wire id_uses_rs1 = !(id_op == OP_LUI || id_op == OP_AUIPC || id_op == OP_JAL);
wire id_uses_rs2 = (id_op == OP_REG) || (id_op == OP_STORE) || (id_op == OP_BRANCH);
```

*"What does this instruction do"* was enough for a single-cycle core. A pipeline
also has to know *"what does it need"*, because stalling for a register an
instruction never reads is a bubble bought for nothing — and `LUI` has no `rs1`,
which lesson 13 learned the hard way. Those two lines belong in `decode.v`
honestly; they are here because that file is a finished, measured artifact of
lesson 12, and a lesson that quietly rewrites an earlier one invalidates its
numbers.

## The bug this lesson actually hit

The C program from lesson 15 halted on an illegal instruction at `0x258`, a few
instructions after printing `K`. The instruction was `0x20737362`, which is
ASCII `"bss "`.

The machine had decoded a **string constant**.

The last instruction of `main()` is a `jal`, and the word after it is the first
four bytes of `.rodata`. The pipeline fetches it — of course it does, it does
not know the jump is taken until EX — and that fetch is thrown away correctly:
`bubble` includes `redirect`, so the wrong-path instruction never reaches EX.

But an exception is not something an instruction *does*. It is something it
**is**, and the illegal-instruction latch was looking at it anyway:

```verilog
else if (id_valid && id_illegal && !redirect) ill <= 1;
```

> **A bug this course actually hit** — the `&& !redirect` is the entire fix,
> and the rule behind it is one every real processor obeys: **an instruction
> that is squashed raises nothing.** Real pipelines carry an exception down the
> stages with its instruction and raise it at commit, for precisely this
> reason — by then they know whether it was ever going to run.
>
> Lesson 13's core could not have had this bug: nothing is ever fetched
> speculatively, so every instruction it decodes is one it executes. The bug is
> not in the trap logic. It is a *control hazard*, wearing a disguise.

It also explains why the conformance program passed while the C did not. Lesson
13's `test.s` has a real instruction after every jump; a compiler does not, and
puts its string table there instead.

## Simulate it

```bash
make sim
```

```
  program finished in 148 cycles, 109 instructions retired, pc = 0000015c
  machine A: 24 checks, 0 errors
RV32I SoC
deadbeef
bss ok
K
CYC 000004b7
DONE
  machine B: 46 characters, 6089 cycles, 3243 instructions retired

PASS: lesson 13's program gives identical results (24 checks) and lesson 15's C runs unchanged
```

**Two machines run in one simulation, and both have to pass.**

- **Machine A** is [`cpu5_sys.v`](./cpu5_sys.v) running
  `../13-rv32i-single/test.hex` — lesson 13's conformance program, byte for
  byte, checked against the same thirty expected results. A pipelined core that
  gives different answers from the single-cycle one on the same image has a bug,
  and that is the strongest statement this lesson can make. It keeps lesson 13's
  two separate memories, because `test.s` writes its results to `0x100`, which
  on a unified machine is where its own instructions live. Harvard or unified is
  a property of what you wire to a core, not of the core.
- **Machine B** is [`soc5.v`](./soc5.v): lesson 15's computer with this core
  inside it, running lesson 15's `firmware.hex`, compiled from the same C. The
  address decoder and the peripherals are *the same files*, included from
  `../15-soc/`. Same forty-six characters, or it fails.

## What it cost

```bash
make synth
```

| module | `LUT4` | `TRELLIS_FF` | `DP16KD` | `TRELLIS_DPR16X4` |
|---|---:|---:|---:|---:|
| `cpu5` — the pipelined core | 2,110 | 414 | 0 | 32 |
| `cpu` — lesson 13's core, for comparison | 1,765 | 32 | 0 | 32 |
| `memory_sync` — 2 KB, two ports | 121 | 117 | **2** | 0 |
| `memory` — lesson 15's, same 2 KB | 2,756 | 0 | 0 | 512 |

And the whole computer, against lesson 15's:

| | lesson 15 | **lesson 16** |
|---|---:|---:|
| `LUT4` | 4,821 | **2,538** |
| `TRELLIS_FF` | 146 | **680** |
| `DP16KD` | 0 | **2** |
| `TRELLIS_DPR16X4` | 544 | 32 |
| `EHXPLLL` | 0 | 1 |

**The pipelined computer is smaller.** A more complex core, four sets of
pipeline registers, a forwarding network and hazard logic — and it costs 2,283
*fewer* LUT4, because the memory moved into two block RAMs out of 208. The
pipeline cost 345 LUT4 and 382 flip-flops; the memory it enabled paid that back
seven times over.

> **Why this matters** — that is what "use the hardware the chip has" means as a
> number. The 85F's block RAMs were there in lesson 15 too, sitting idle,
> unusable because of a decision made in lesson 13 about when a memory has to
> answer.

And now the memory scales, which it could not before:

```bash
make synth M=soc5_top P="MEM_WORDS 4096"
```

| memory | `LUT4` | `DP16KD` |
|---|---:|---:|
| 2 KB | 2,538 | 2 |
| **16 KB** | **2,521** | 16 |

Eight times the memory for seventeen LUT4 — the block RAMs are simply there,
and using eight more of the 208 costs nothing but the decode. In lesson 15,
merely doubling 2 KB to 4 KB cost 2,442 LUT4 and broke timing.

## What it cost in time — and what it bought

```bash
make bit
```

Both machines placed and routed three times with different placer seeds, at the
same 25 MHz constraint, so the numbers are comparable:

| design | max clock, three seeds |
|---|---|
| lesson 15 — single-cycle computer | 27.28 / 28.21 / 28.00 MHz |
| **lesson 16 — pipelined computer** | **49.48 / 47.52 / 45.74 MHz** |

**The clock nearly doubles.** Now the other half of the arithmetic.

### CPI, and where every cycle went

Machine A: **109 instructions, 148 cycles, CPI 1.358.** Lesson 13 ran the same
109 instructions in 109 cycles, CPI 1.000 by construction.

The C delay loop is the clearer case, because it is small enough to count by
hand. The program's own stopwatch reports it:

| | cycles |
|---|---:|
| lesson 15, single-cycle | 606 |
| lesson 16, pipelined | 1,207 |

Six instructions per iteration, a hundred iterations, 600 cycles single-cycle.
Pipelined, each iteration pays:

| | cycles |
|---|---:|
| six instructions | 6 |
| `lw` → `addi` load-use stall | 1 |
| `lw` → `bge` load-use stall | 1 |
| taken `bge`, two instructions flushed | 2 |
| taken `jal`, two instructions flushed | 2 |
| **per iteration** | **12** |

12 × 100 = 1,200, plus 7 cycles of loop entry and pipeline fill: **1,207.**
Every single cycle is accounted for, which is the same habit lesson 05 applied
to flip-flops.

### So is it faster? Not always, and that is the lesson

Time is cycles divided by clock, and both changed. Using the *slowest* seed for
each machine:

| program | lesson 15 | lesson 16 | |
|---|---|---|---|
| conformance (109 instructions) | 109 cyc ÷ 28.00 MHz = **3.89 µs** | 148 cyc ÷ 45.74 MHz = **3.24 µs** | **1.20× faster** |
| the `volatile` delay loop | 606 cyc ÷ 28.00 MHz = **21.6 µs** | 1,207 cyc ÷ 45.74 MHz = **26.4 µs** | **0.82× — slower** |

**Pipelining made one program 20% faster and the other 18% slower.** The clock
went up 1.63×; the delay loop's CPI went up 1.99×, and 1.99 > 1.63.

That loop is the worst case on purpose — every iteration is a load immediately
followed by its use, twice, and two taken branches. It is also exactly the shape
of code that a naive benchmark contains. The honest summary is that **pipelining
buys you permission to raise the clock, and whether that is a win depends on the
program**, which is not what the textbook diagram suggests.

The fixes are the obvious ones and each is a real design: resolve branches in ID
(one bubble instead of two), predict them (none, when right), or let the
compiler schedule an instruction into the load's shadow. `-O2` instead of `-Os`
does some of the third by itself — try it.

## On the board

**This is where pipelining finally pays, because here the clock is yours to
set.** Lesson 15's machine runs at the ULX3S's 25 MHz oscillator because it
cannot go faster. This one closes at 46 MHz, so the board top instantiates
lesson 04's PLL — unchanged, the same file — and runs the computer at **40
MHz**:

```verilog
pll u_pll (.clk_25mhz(clk_25mhz), .clk_100mhz(), .clk_40mhz(clk), .locked(locked));
wire rst = btn[1] || !locked;
```

40 and not 46: the slowest placer seed measured 45.74 MHz, and taking 46 because
one run said 46 is how you ship a machine that works on the bench and fails in
July. The shipped 40 MHz build closes at 48.55 MHz.

> **Why this matters** — a pipeline that runs at the same clock is a *slower
> machine*. It executes the same instructions in more cycles and each cycle is
> the same length, so it finishes later. Everything pipelining gives you arrives
> as permission to raise the clock, and if you do not raise it you have paid for
> the hazard logic and bought nothing.

```bash
make bit
make prog
make console
```

Controls are deliberately identical to lesson 15's, so the two bitstreams can be
loaded one after the other and compared by a human: **btn[1]** resets, **sw[3]**
switches the LEDs between what the program wrote and the machine's own state,
and the console is 115200 baud. The UART divisor comes from the `CLK_HZ`
parameter, so it follows the PLL to 40 MHz with nothing else changed — which is
why lesson 09 made it a parameter.

Load lesson 15's bitstream, reset, read the cycle count. Load this one, reset,
read it again: **it is larger**, on a machine that is faster. That is the whole
lesson in two numbers you can see on a screen.

## Exercises

1. **Delete `&& !redirect`** from the illegal-instruction latch in `cpu5.v` and
   run `make sim`. You will reproduce the bug above exactly, including the
   address. Then explain why machine A still passes.

2. **Break the load-use stall**: change `ex_mem_read` to `1'b0` in the `stall`
   expression. The assertion in `cpu5.v` fires and tells you the register and
   the PC. Predict *which* of lesson 13's thirty checks fail before you look.

3. **Remove the register-file bypass** in ID (`wb_hit_rs1`/`wb_hit_rs2`).
   Predict what breaks: an instruction reading a register written by one
   exactly four instructions earlier. Find it in `test.s`.

4. **Count the bubbles.** Add a counter for stall cycles and another for
   flushed instructions, print them through the `HALT` register, and check they
   add up: `cycles = instructions + stalls + flushes + 4`. Where does the 4 come
   from?

5. **Resolve branches in ID instead of EX.** This is the real exercise of this
   lesson. It needs a second forwarding network into ID and it saves one bubble
   per taken branch — recompute the delay loop's 12 cycles per iteration first
   and predict the new figure, then measure.

6. **Compile the C with `-O2`** instead of `-Os` (`15-soc/Makefile`), and
   measure the delay loop again on both machines. The pipelined one should
   improve more. Why?

## What you should now be able to explain

- Why pipelining raises the clock without making any stage faster.
- Why a block RAM is usable here and was not in lesson 15.
- Which hazard forwarding fixes, which needs a stall, and why.
- Why a squashed instruction must not raise an exception.
- Why this machine is slower than lesson 15's on some programs, and what to
  measure before claiming otherwise.

**Next:** [lesson 17 — extensions](../17-extensions/): CSRs, traps and
interrupts, which is where an illegal instruction stops halting the machine and
starts being handled.
