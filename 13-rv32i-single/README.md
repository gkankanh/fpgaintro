# Lesson 13 — single-cycle RV32I

**Concept:** fetch, decode, execute, memory and writeback in one clock — the
simplest thing that is genuinely a CPU.

**You will build:** a core that runs real RISC-V assembly, verified by the
program's own output.

**Needs the board:** yes, and it is worth it

**Prerequisites:** lesson 12

**Paths:** editor only

**By the end you can:**

- See a CPU as a state machine whose state is a program counter.
- Explain why a single-cycle core needs separate instruction and data memories.
- Handle byte and halfword access, and sign versus zero extension.
- Test a processor through its architectural interface.
- Explain why the whole core runs at half the ALU's clock.

---

## The idea

Nothing in this lesson is new.

The ALU is lesson 10. The register file is lesson 11. The decoder and immediate
generator are lesson 12. The only new logic is a branch comparator, the
load/store aligners, and the next-PC multiplexer.

> **Why this matters** — a CPU is not a new kind of thing. It is a state
> machine (lesson 05) whose state is a program counter, wired to parts you have
> already built and tested separately. That is the single most demystifying
> idea in the course, and it is why those four lessons came first.

![The single-cycle RV32I datapath](../docs/diagrams/datapath.svg)

## Single-cycle first, because the datapath stays visible

There are no pipeline registers between the stages, so every wire goes where
the diagram says it goes. Read [`cpu.v`](./cpu.v) top to bottom and it is the
picture above, in order.

The price is that **everything happens within one clock period**, so the
critical path is the whole chain in series. Lesson 16 pipelines this exact core
and the comparison is the point of doing it this way round.

### Harvard, and not as a preference

[`cpu_sys.v`](./cpu_sys.v) has **two** memories, instruction and data, both
read combinationally. That is not a style choice: a single-cycle CPU must fetch
an instruction *and* access data in the same cycle, and one memory with one
port cannot do both.

Real machines present one address space and get away with a single memory by
pipelining (fetch in one stage, memory access in a later one) or by putting
separate caches over shared memory. Here the simplest thing that works is two
memories, and saying so is better than pretending it was taste. Lesson 15
unifies them behind a bus.

## The parts that are new

### The branch comparator

Branches need six comparisons — equal, not-equal, and signed/unsigned
less-than and greater-or-equal. The ALU could do them, but in a single-cycle
CPU **the ALU is busy computing the branch target in the same cycle**. So a
separate comparator, which is cheap and keeps the ALU's output free.

Note what RV32I omits: there is no `BGT` or `BLE`. `bgt a, b, L` assembles as
`blt b, a, L` — the *assembler* swaps the operands and the hardware needs no
extra cases. Six conditions, not ten.

### Load and store alignment

Memory is 32 bits wide; RV32I has `LB`, `LH`, `LW`, `LBU`, `LHU`, `SB`, `SH`,
`SW`. So [`memaccess.v`](./memaccess.v) does two jobs:

- **a byte store must change one byte** and leave the other three alone, which
  is why the memory has per-byte write enables
- **a byte load must select and extend** — `LB` sign-extends, `LBU`
  zero-extends. Both exist because C's `char` may be either and a compiler must
  be able to ask for exactly one.

`addr[1:0]` picks the byte and is *not* part of the word index.

## The bug that running software found

The CPU ran on the first attempt — 109 cycles, reaching `halt` — and got most
answers right. The failures were all **X bits**, and they all traced to `LUI`.

My lesson 12 decoder carried a comment saying *"rs1 is x0 by convention for
LUI"*, and the datapath relied on it. **That is false.** LUI has no `rs1` field
at all: `inst[19:15]` is part of its 20-bit immediate. So the ALU was adding
the immediate to whatever register those five bits happened to name — an
undefined register — and the X propagated into every value built with `li` of a
large constant.

The fix is a third operand-A source:

```verilog
wire [31:0] alu_a = alu_a_zero ? 32'd0 :
                    alu_a_pc   ? pc    : rd1;
```

> **Why this matters** — lesson 12's own testbench checked that LUI asks the
> ALU for ADD, and it does. **It never checked where the operands came from.**
> 161 passing decoder checks and a mutation-tested testbench did not find this;
> running eighty-eight instructions of real software found it in one go.
>
> Unit tests verify the parts. Integration finds the assumptions *between* the
> parts. Both are necessary and neither substitutes.

The decoder now has an `alu_a_zero` output, and its testbench asserts it for
LUI and asserts it is *not* set for `add` or `auipc`.

## The program, and how it is checked

[`test.s`](./test.s) exercises arithmetic, logic, both shift kinds, signed and
unsigned comparison, byte/halfword memory access, a backward-branch loop,
`jal`/`ret`, `jalr` through a register, `lui`, and branches that must *not* be
taken. 88 instructions.

**Every result is stored to memory**, and the testbench reads data memory
rather than peeking at the register file:

```verilog
expect(32'h108, 32'd9,  "addi -1  (the trap)");
expect(32'h148, 32'd55, "loop sum 1..10");
expect(32'h140, 32'hFFFFFF80, "lb  sign-extended");
```

That matters: it tests the CPU through the interface software actually uses, so
a core that computes correctly but *stores* wrongly still fails — which is also
all that software could tell you.

The program ends by setting a flag at `0x1FC`, and has a `bad` label that
writes `0xBAD` if any branch goes the wrong way. The testbench requires the
flag and forbids the marker.

```bash
cd 13-rv32i-single
make sim
```

```
program finished in 109 cycles, pc = 0000015c
PASS: 24 checks - the CPU ran 88 instructions of RV32I and every result is
correct
```

### The assembler

[`tools/rvasm.py`](../tools/rvasm.py) is a 400-line RV32I assembler with no
dependencies: labels, the common pseudo-instructions, and `--list` to print
encodings beside the source.

```bash
make prog-asm        # reassemble test.s -> test.hex
```

**Why not GNU `as`?** We will use the GNU toolchain from lesson 15, where
compiling C makes it unavoidable. For *this* lesson, requiring a ~500 MB cross
toolchain to assemble twenty instructions would put a wall in front of the most
important lesson in the course — and `rvasm` agrees with lesson 12's
independently-derived encodings on every instruction they share, which is
cross-validation rather than duplication.

But "self-consistent" is weaker than "agrees with the reference", so:

```bash
make check-asm       # diffs rvasm against GNU as, when it is installed
```

With no toolchain it says so and exits cleanly. Once you install it for lesson
15, run this and the claim gets earned.

`test.hex` is read by `$readmemh` at **elaboration** time (lesson 08), so it is
a source file: change `test.s` and you must reassemble *and* resynthesise.

## What it cost

`cpu` — the processor itself, memories external:

```bash
make synth M=cpu
```

| resource | count |
|---|---:|
| `LUT4` | 1,765 |
| `TRELLIS_FF` | 32 |
| `CCU2C` | 80 |
| `PFUMX` | 547 |
| `L6MUX21` | 226 |
| `TRELLIS_DPR16X4` | 32 |

1,765 of the 85F's 83,640 LUT4 — 2.11% of the part.

`cpu_top` — the core plus its memories and board wiring:

```bash
make synth
```

| resource | count |
|---|---:|
| `LUT4` | 1,268 |
| `TRELLIS_FF` | 40 |
| `CCU2C` | 52 |
| `PFUMX` | 316 |
| `L6MUX21` | 153 |
| `TRELLIS_DPR16X4` | 42 |

Fewer LUT4 in the wrapper than in the core it contains, which is not a
misprint: synthesised on its own, `cpu` must build every output it exposes,
while inside `cpu_top` only the parts that drive something survive. **A
module's cost depends on what is asked of it** — so a per-module number means
nothing without the command that produced it, which is why every table in this
course carries one.

**Thirty-two flip-flops in an entire CPU.** All the state a single-cycle
machine has is its PC; the register file lives in distributed RAM and everything
else is combinational. Lesson 16 will add hundreds of flip-flops and that is
precisely what pipelining *is*.

Lesson 10 measured the ALU at 885 LUT4, so the ALU is roughly half the core.

## What it cost in time — the number this lesson exists to produce

```
Info: Max frequency for clock 'clk': 61.24 MHz (PASS at 25.00 MHz)
```

| design | max clock |
|---|---|
| 32-bit ALU alone (lesson 10) | 115.94 MHz |
| **whole single-cycle core** | **61.24 MHz** |

**Adding fetch, register read, memory access and writeback to the ALU's path
roughly halves the clock.** Every instruction — even `nop` — pays the full
critical path, because every instruction takes exactly one cycle and that cycle
must be long enough for the slowest one.

That is the entire argument for pipelining, now with a number attached. Lesson
16 splits this path into five stages so each one is short, and pays for it in
hazard logic.

(nextpnr reports max frequency twice: once after placement, once after routing.
The post-route figure — 61.24 MHz here — is the real one; the earlier 49.51 MHz
is an estimate made before routing is known.)

## Exactly what this core implements

The core executes the **RV32I base integer instruction set, less the privileged
and system parts**. Being precise matters here: "RISC-V" on its own claims
rather a lot, and lesson 14 is about not claiming what you have not shown.

| | |
|---|---|
| **implemented** | all nine base opcodes and every instruction under them: `LUI`, `AUIPC`, `JAL`, `JALR`, the six branches, the five loads, the three stores, the nine register-immediate and ten register-register operations — with byte and halfword access and sign or zero extension |
| **not implemented** | `FENCE`, `ECALL`, `EBREAK`, and the whole CSR and privileged architecture: no traps, no interrupts, no machine mode. That is the planned lesson 17 |
| **illegal instruction** | the decoder raises `illegal`, the register file and data memory are held off, and the PC stops advancing. The core **halts** rather than trapping, because trapping needs CSRs it does not have |
| **misaligned access** | **not detected.** A misaligned load or store does something well-defined by the aligner and wrong by the specification |
| **memory** | Harvard: separate instruction and data memory, both block RAM, no caches, no bus |

RV32I user-level integer code assembled by [`tools/rvasm.py`](../tools/rvasm.py)
runs correctly, and lesson 14 takes that claim seriously for the ALU. It is not
a compliance claim about the whole core: the official `riscv-arch-test` suite
has not been run against it.

## On the board

```bash
make prog
```

- `btn[1]` — reset and restart the program
- `sw[3:0]` — which result word to show: address `0x100 + 4×sw`
- `led[7:0]` — the low byte of that word

Set the switches to **2** and you are reading `0x108` — the result of
`addi t2, t0, -1`, which must be **9**. Had lesson 12's trap gone unfixed it
would read 11. Position **0** is `10 + 3 = 13`; position **1** is `10 - 3 = 7`.

The program runs in 109 cycles — about 4 µs — so it has finished long before
you release the button.

**This is a RISC-V processor you built, running a program you wrote, on a chip
you configured.** Worth a moment.

## Icestudio

```bash
open 13-rv32i-single/icestudio/branch.ice
```

`branch_unit` on its own, which is the corner of this core you can genuinely
test by hand. `b` is fixed at 7, the switches are `a` sign-extended to 32
bits, and the three buttons are `funct3`.

Set the switches to `1111`, which is -1. Hold LEFT for BLT and the LED lights,
because -1 is less than 7. Add DOWN for BLTU and it goes out, because the same
bit pattern read as unsigned is 4,294,967,295. The bits did not change; the
comparison did, and that is why RV32I spends separate opcodes on it.

Six conditions come out of three comparisons and some inversions. The core
itself stays on the editor path — `cpu.v` wires six modules together.

## Exercises

1. **Reach the loop result.** `sw` only addresses `0x100`–`0x13C`. Change
   `cpu_top` so the switches reach `0x148` and confirm the sum is 55.
2. **Write your own program.** Compute something in `test.s` — a factorial, a
   GCD, a bubble sort over memory — and add testbench checks for it.
   `make prog-asm` then `make sim`.
3. **Re-introduce the LUI bug.** Set `alu_a_zero` to `1'b0` always and run
   `make sim`. Which results go X, and can you explain the pattern from the
   program source?
4. **Find the critical path.** Run `make bit` and read nextpnr's critical path
   report. Which module names appear on it? Is the ALU there, the memory, or
   both?
5. **Make it slower and prove it.** Add a second data memory port so loads and
   stores can both happen, measure the clock, and explain the change.
6. **Count the cycles.** 88 instructions take 109 cycles. Where do the extra 21
   come from?

## Wrap-up

**What you built.** A single-cycle RV32I core running real assembled programs, tested through its architectural interface — 1,765 LUT4, 32 flip-flops, 61.24 MHz.

**What to keep.** One cycle for every instruction means every instruction pays for the slowest one.

**What comes next.** Lesson 14 proves components correct rather than testing them. Lessons 15 to 17, which are planned rather than built, take this core to a system that runs C, a pipeline, and traps.
