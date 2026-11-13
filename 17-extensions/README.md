# Lesson 17 — CSRs, traps and the M extension

**Concept:** privileged state, traps, and the extensions that make a core
usable rather than merely correct.

**You will build:** CSRs, a machine-timer interrupt, and hardware multiply and
divide — with the interrupt handler written in C.

**Needs the board:** yes

**Prerequisites:** lesson 16

**Paths:** editor only

**By the end you can:**

- Explain what a trap is and what hardware must save before taking one.
- Distinguish an exception from an interrupt.
- Write an interrupt handler in C and know what the hardware did first.
- Decide when to spend a hardware multiplier and when to iterate.
- Explain why a CSR write has to serialise a pipeline.

---

## The idea

Lesson 13's core, and lesson 16's, do the same thing with an instruction they
do not understand: **they stop.** The program counter freezes, a light comes
on, and that is the end of the machine.

Real processors do not stop. They **trap**: save where they were, record why,
and jump to an address the software chose. The difference between a core that
halts and a core that can run an operating system is almost entirely this
lesson, and it is smaller than you would think.

> **Why this matters** — a trap is the only mechanism by which software gets
> control of a machine it is not currently running on. System calls, page
> faults, debuggers, timer-driven scheduling, and every "something went wrong"
> message you have ever seen are the same four registers and one jump.

This lesson is genuinely optional: the course's goal is met at lesson 16. It is
here because *a correct RV32I core* and *a core that could run an RTOS* are
separated by exactly these pieces, and it is worth seeing how few they are.

## The design

The core is lesson 16's. The honest way to read it is:

```bash
diff cpu5t.v ../16-rv32i-pipeline/cpu5.v
```

Four things are added.

### 1. A second decoder

Lesson 12's decoder recognises the nine base RV32I opcodes and calls everything
else illegal — which includes every instruction this lesson needs.
[`decode_ext.v`](./decode_ext.v) claims them, and the core computes:

```verilog
wire id_illegal = id_illegal_base && !id_ext_legal;
```

That is the smallest honest change: lesson 12's decoder is a finished, measured
artifact and this lesson does not reach into it. A second decoder beside the
first is also how real designs grow — **an extension is a decoder**, and `misa`
is a register listing which ones are present.

> **Why this matters** — `MUL` is opcode `0110011`, the same as `ADD`,
> distinguished only by `funct7 = 0000001`. RISC-V does that deliberately:
> opcodes are scarce, and an extension needing its own opcode is an extension
> that cannot coexist with another. Lesson 12's `bad_funct7` check is exactly
> what makes `MUL` illegal on a core without M — which is what the
> specification says should happen, and why that check was worth writing.

### 2. Traps

[`csr.v`](./csr.v) holds nine registers and the trap state. Taking a trap is a
redirect with bookkeeping: save the PC in `mepc`, say why in `mcause`, copy
`MIE` into `MPIE` and clear `MIE` so the handler is not immediately
interrupted, and jump to `mtvec`. **Four registers and a jump** — that is all
the hardware does. Everything else is the handler.

Traps are decided in **ID**, before the instruction has done anything:

- everything ahead of it in the pipeline (EX, MEM, WB) completes, because those
  instructions are *earlier* in program order;
- the trapping instruction is squashed, having changed nothing;
- everything behind it is flushed by the redirect.

The machine stops between two instructions, exactly, with `mepc` naming the
boundary. That property is called **precision**, and it is not optional: a
handler that cannot tell what has happened cannot return from it.

> **Watch out** — `trap_ok` requires `!redirect`, which is lesson 16's rule
> about squashed instructions. There it stopped the machine halting on a string
> constant; here it keeps traps precise, because an instruction on the wrong
> path of a branch must not trap — it is not going to run.

### 3. Interrupts

Everything above is caused by an *instruction*. [`timer.v`](./timer.v) is not:
`mtip` goes high because **time passed**, and that is the entire difference
between an exception and an interrupt. It arrives as one input wire.

```
0x8000_0040  MTIME      0x8000_0048  MTIMECMP     mtip = (mtime >= mtimecmp)
```

> **Watch out** — `mtip` is a **level**, not an event. It stays asserted while
> `mtime >= mtimecmp`, so a handler that returns without moving `mtimecmp`
> forward is re-entered the instant `MRET` re-enables interrupts, forever. This
> is the classic first bug with a timer, and exercise 2 makes you write it.

Adding the timer to the system cost one line in [`soc17.v`](./soc17.v):

```verilog
wire sel_timer = sel_io &&  dmem_addr[6];
```

Lesson 15's address decoder is unchanged, the compiler is unchanged, the linker
script is unchanged. **A new device is a select line and an entry in the read
mux.** That is what a memory map buys.

### 4. An EX stage that can take longer than a cycle

Multiply and divide do not finish in a cycle, so for the first time in this
course EX can say *"not yet"* — which needs a stall that holds the instruction
**in** EX rather than ahead of it:

| stall | who waits | what EX gets |
|---|---|---|
| load-use (lesson 16) | the instruction in **ID** | a bubble |
| multiply/divide | the instruction in **EX** | nothing — it holds |

Both are one signal to the rest of the pipeline. Adding the divider beside the
multiplier changed nothing anywhere else, because "EX is not finished" does not
care which unit is unfinished.

## The bug this lesson actually hit

The program printed its greeting **twice**.

```
RV32IM
RV32IM
E
I
...
```

Here is the whole of it:

```asm
csrw  mtvec, a5     # in EX, writing mtvec at the end of this cycle
ecall               # in ID, reading mtvec to find out where to go
```

Both in the machine at once, one stage apart. The `ecall` read the **old**
`mtvec` — zero, because nothing had set it yet — and jumped to address zero,
which is the first instruction of the program. The machine restarted itself,
printed its greeting again, set `mtvec` again, and the second `ecall` worked.
On the board that would look like a glitch.

> **A bug this course actually hit** — lesson 16's forwarding network cannot
> help here, and the reason is worth more than the fix. Forwarding moves
> **values** between instructions. This is not a value: it is a change to how
> the machine *behaves* — where traps go, whether interrupts are allowed, what
> the timer is compared against. **There is no wire to forward "the rules are
> different now" along.**
>
> So the pipeline serialises instead: while a CSR instruction is in EX, nothing
> is decoded behind it. One bubble per CSR instruction, which is the right
> price for an instruction a program executes a few dozen times — and it is why
> real instruction sets describe CSR writes as *serialising* rather than as
> ordinary register writes.

```verilog
wire csr_serialise = ex_valid && ex_is_csr;
assign stall_id = load_use || csr_serialise;
```

The same run also fired the load-use assertion falsely, on `x16`. That one was
the *assertion's* fault: the `rs1` field of `CSRRWI` is not a register number
at all, it is a 5-bit immediate, and comparing it against a destination
register raises an alarm about a register nobody is reading. The assertion now
checks what the instruction actually reads.

## The software

```bash
make firmware      # needs riscv64-elf-gcc
make dis           # the handler's prologue is the thing to look at
```

### A handler in C

```c
__attribute__((interrupt("machine")))
void trap_entry(void)
```

That attribute asks gcc for a function that can be jumped to by **hardware**
rather than called by software. Two things change: it saves and restores every
register it touches, because the interrupted code was not expecting to lose
any of them — a normal function may clobber `t0`-`t6` freely, this one may not
clobber anything — and it returns with `MRET` instead of `RET`, which restores
the interrupt enable and jumps to `mepc`.

Run `make dis` and count the stores in its prologue. **That stack traffic is
the cost of an interrupt**, before any of your code runs.

### Stepping over the instruction that trapped

```c
csr_write(mepc, csr_read(mepc) + 4);
```

`mepc` points **at** the faulting instruction, not after it — which is right
for a page fault, where you fix the problem and re-run it, and wrong for
`ECALL`, where re-running it would trap again immediately. The handler decides,
which is the point of the design.

### Reaching a CSR from C

There is no C syntax for a control and status register, and no reason there
should be: they are not memory, they have no addresses C can form, and the
instructions take the CSR number as an **immediate** — so it must be a
compile-time constant. Hence macros with the name pasted into inline assembly:

```c
#define csr_read(csr) ({ uint32_t v; __asm__ volatile ("csrr %0, " #csr : "=r"(v)); v; })
```

This is the floor of the C abstraction, and every operating system has a header
that looks like this.

### One flag, two extensions

```make
RVCFLAGS = -march=rv32im_zicsr ...
```

`m` makes `a * b` one instruction instead of a call into libgcc. `zicsr` makes
`csrr` assemble *at all* — the CSR instructions were part of the base integer
ISA until 2019, when they were split into their own extension, because a core
needing no privileged state should not have to implement six instructions to be
called RV32I. The hardware does not care: `decode_ext.v` would have decoded
them under any name.

## Simulate it

```bash
make sim
```

```
RV32IM
E
I
T
T
T
MUL be991a08
DIV 0001e240
REM 00000315
SDV fffe1dc0
CYC 00010845 INS 0000712e
DONE
  RV32I conformance: 23 checks, 0 errors, 148 cycles, 109 instructions

PASS: 100 characters, 5 traps taken (3 of them timer interrupts), every one returned from, and lesson 13's program still gives all 23 answers
```

Every line of that output is a trap that was taken and returned from. `E` is an
`ECALL`. `I` is an **illegal instruction** — the word `0x00000000`, which on
lesson 13's core halted the machine dead and here is reported to a handler that
steps over it. Each `T` is a timer interrupt, caused by nothing in the
instruction stream at all.

`CYC` and `INS` are the machine reading its own `mcycle` and `minstret`. Lesson
16 had to count cycles in a simulator; a processor with CSRs counts them
itself, and **any program can ask** — 67,653 cycles for 28,974 instructions, a
CPI of 2.33, which is what a program that spends its life polling a UART status
bit and a volatile counter deserves.

As in lesson 16, **two machines run here**. The second is the same core with
two plain memories, running lesson 13's conformance program and checked against
the same results — in the same 148 cycles lesson 16 took, so privileged state
cost ordinary code nothing. That check is not a formality: `decode_ext.v` claims
encodings lesson 12's decoder used to reject, and one `funct3` compared too
loosely would quietly redefine an ordinary instruction.

## What it cost

```bash
make synth
```

| resource | count |
|---|---:|
| `LUT4` | 3,866 |
| `TRELLIS_FF` | 1,285 |
| `CCU2C` | 366 |
| `PFUMX` | 896 |
| `L6MUX21` | 340 |
| `TRELLIS_DPR16X4` | 32 |
| `DP16KD` | 16 |
| `MULT18X18D` | **4** |
| `EHXPLLL` | 1 |

Four hard multipliers, sixteen block RAMs, and 4.6% of the part — for a
computer with 16 KB of memory that takes interrupts.

Where the additions went, each synthesised on its own:

```bash
make synth M=cpu5t
make synth M=csr
make synth M=div_unit
make synth M=mul_unit
make synth M=timer
make synth M=decode_ext
```

| module | `LUT4` | `TRELLIS_FF` | `MULT18X18D` | |
|---|---:|---:|---:|---|
| `cpu5t` | 3,270 | 887 | 4 | this lesson's core |
| `cpu5` | 2,110 | 414 | 0 | lesson 16's, for comparison |
| `csr` | 1,402 | 225 | 0 | nine registers and the trap state |
| `div_unit` | 528 | 169 | 0 | 32 cycles of restoring division |
| `mul_unit` | 36 | 68 | **4** | the DSPs do the work |
| `timer` | 164 | 128 | 0 | two 64-bit registers and a comparator |
| `decode_ext` | 56 | 0 | 0 | every instruction this lesson added |

- **The whole privileged architecture is a decoder of 56 LUT4** and a register
  file of about 1,400. Traps are cheap. What they *enable* is not, but the
  mechanism itself is smaller than the ALU.
- **Multiply costs 36 LUT4 and four DSP blocks**; divide costs 528 LUT4 and no
  DSP at all. That asymmetry is the whole of the M extension in one row:
  multiplication is a block the chip already has, and division is a state
  machine you have to build. It is why `a / b` is expensive in C and `a * b` is
  not, and why compilers turn division by a constant into a multiply.
- `cpu5t` is 1,160 LUT4 and 473 flip-flops more than `cpu5`. The modules above
  sum to more than that, because a module synthesised alone must build every
  output it exposes — the same effect lesson 13 measured when `cpu` came out
  larger than the `cpu_top` containing it.


## What it cost in time

```bash
make bit
```

**This core does not close timing at lesson 16's 40 MHz**, and finding out why
took three builds and nine place-and-route runs.

| build | constraint | three placer seeds | verdict |
|---|---|---|---|
| combinational multiplier | 40 MHz | 34.5 / 34.9 / 35.5 MHz | fails all three |
| product registered | 40 MHz | 41.1 / 40.1 / **39.6** MHz | fails one in three |
| …and operands registered too | 40 MHz | 38.5 / 39.8 / 41.5 MHz | fails two in three |
| **shipped: product registered, at 35.7 MHz** | 35.71 MHz | **39.7 / 39.8 / 39.5 MHz** | **passes** |

Built combinationally, the 32×32 multiplier *was* the critical path of the
machine. nextpnr named it exactly: 29 ns from the block RAM's output, through
the forwarding network, the four DSPs and the carry chain that sums their
partial products, into the `EX/MEM` register. Lesson 16's core without it
closed at 46 MHz.

Registering the product fixed most of that, and the multiply became a two-cycle
instruction — which is what real cores do, and why every instruction-timing
table lists multiply latency separately from throughput.

> **Why this matters** — the third row is the one worth having. Registering the
> *operands* as well is the textbook next step: split the long path in two,
> get a faster clock. It **bought nothing** — the same clock within the
> placer's own spread — and cost an extra cycle on every multiply. The
> multiplier had stopped being the critical path after the first register, and
> a second one optimises something that is no longer the problem.
>
> The only reason anyone knows that is that it was measured three times rather
> than once. A single run of this design lands anywhere between 38.5 and 41.5
> MHz depending on a random seed, and either of those numbers alone tells a
> confident, wrong story.

So the board runs at **35.7 MHz**, from this lesson's own PLL
([`pll36.v`](./pll36.v), generated by `ecppll`), about 10% below the slowest
measured placement — the same kind of margin lesson 16 leaves at 40.

| | clock | why |
|---|---|---|
| lesson 15 — single-cycle computer | 25 MHz | it closes at 28; the oscillator is 25 |
| lesson 16 — pipelined | 40 MHz | closes at 45.7 worst-seed |
| **lesson 17 — with traps and M** | **35.7 MHz** | closes at 39.5 worst-seed |

**Privileged state and hardware multiply cost about six megahertz.** That is
the price of the lesson, stated the way this course states prices.


## On the board

```bash
make bit
make prog
make console
```

Press **btn[1]** and the program runs: an `ECALL`, an illegal instruction, three
timer interrupts 0.56 ms apart, the multiply and divide results, and
its own cycle and instruction counts. With **sw[3]** up, `led[5]` shows that at
least one trap has been taken.

The illegal instruction is the one to appreciate. On lesson 13's machine the
same word stopped the processor; here the machine reports it, the handler steps
over it, and the program carries on and finishes normally.

## Icestudio

```bash
open 17-extensions/icestudio/timer.ice
```

The machine timer, and `mtip` as the single comparison it actually is. With
`sw0` down the LEDs show `mtime` climbing — bit 25 flips every 1.34 s at
25 MHz. Put `sw0` up and press FIRE2 to write `0x40000000` into `mtimecmp`,
then put it back down and wait. `0x40000000` at 25 MHz is 43 seconds; when
`mtime` passes it, led0 lights and stays lit. UP resets both.

**Stays** lit, because `mtip` is `mtime >= mtimecmp` and not `==`. An equality
would be true for exactly one clock in 2^64, so a core that happened to have
interrupts disabled that cycle would miss the interrupt forever. Level-
triggered means ignoring it is a choice and missing it is not possible — and
it is why `rst` restores `mtimecmp` to all ones rather than zero.

`csr` and the multiplier stay on the editor path, since `cpu5t` wires them
together.

## Exercises

1. **Comment out `csr_write(mtvec, ...)`** in `main.c`. Predict where the
   `ecall` goes, then run it. You will reproduce the double-greeting bug above
   from the other direction.

2. **Delete the re-arm** — the `mtimecmp_write` at the end of the interrupt
   branch of `trap_entry`. Predict what happens before you run it. The machine
   does not crash and does not stop; it just never makes progress again, and
   understanding *why* is the exercise.

3. **Remove `csr_serialise`** from the stall logic and run `make sim`. You will
   get the double greeting exactly as described above, which is a surprisingly
   satisfying thing to reproduce on purpose.

4. **Make the illegal-instruction handler emulate instead of skip.** `mtval`
   holds the faulting instruction; decode it in C and do what it meant to do.
   This is how a processor without a floating-point unit runs floating-point
   code, and it is slow for reasons you will feel.

5. **Count how many cycles a trap costs.** Read `mcycle` before the `ecall` and
   first thing in the handler. Compare with the number of instructions in the
   handler's prologue from `make dis`. Where does the difference go?

6. **Build with `-march=rv32i_zicsr`** instead of `rv32im`. The program still
   works — libgcc provides `__mulsi3` and `__divsi3` — and `make size` and the
   cycle count both change. Is the hardware multiplier worth its four DSP
   blocks for *this* program? Measure before answering.

## What you should now be able to explain

- What the hardware saves before a handler's first instruction, and what it
  does not.
- Why an exception and an interrupt use the same mechanism, and what the one
  difference is.
- Why a trap must be precise, and what makes this core's traps precise.
- Why a CSR write cannot be forwarded and must serialise.
- Why a multiply needs pipeline stages of its own, with the measurement to
  back it.

This is the last lesson. The core now takes traps, handles interrupts,
multiplies in hardware and counts its own cycles — which is to say it is a
computer, built from a single logic gate in seventeen steps.
