#import "../style.typ": *

= Lesson 13 — A single-cycle RV32I processor

#goals(
  concept: [Fetch, decode, execute, memory and writeback in one clock — the simplest thing that is genuinely a CPU.],
  build: [A core that runs real RISC-V assembly, verified by the program's own output.],
  needs: [Lesson 12. A board, and it is worth it.],
)[
  - See a CPU as a state machine whose state is a program counter.
  - Explain why a single-cycle core needs separate instruction and data memories.
  - Handle byte and halfword access, and sign versus zero extension.
  - Test a processor through its architectural interface.
  - Explain why the whole core runs at half the ALU's clock.
]

== Nothing here is new

The ALU is lesson 10. The register file is lesson 11. The decoder and immediate
generator are lesson 12. The only new logic is a branch comparator, the
load/store aligners, and the next-PC multiplexer.

#why[
  #strong[A CPU is not a new kind of thing.] It is a state machine (lesson 05)
  whose state is a program counter, wired to parts you have already built and
  tested separately. That is the most demystifying idea in the course, and it
  is why those four lessons came first.
]

#fig("/figures/datapath.svg",
     [The datapath. Everything shown happens within one clock period.])

== Why single-cycle first

There are no pipeline registers between the stages, so every wire goes where
the diagram says it goes. Read the source top to bottom and it is the picture,
in order. Lesson 16 pipelines this exact core, and the comparison is the point
of doing it this way round.

=== Harvard, and not as a preference

There are #strong[two] memories, instruction and data, both read
combinationally. That is not a style choice: a single-cycle CPU must fetch an
instruction #emph[and] access data in the same cycle, and one memory with one
port cannot do both.

Real machines present one address space and manage with a single memory by
pipelining — fetch in one stage, memory access in a later one — or by putting
separate caches over shared memory. Here the simplest thing that works is two
memories, and saying so is better than pretending it was taste.

== The new parts

=== A separate branch comparator

Branches need six comparisons. The ALU could do them, but in a single-cycle CPU
#strong[the ALU is busy computing the branch target in the same cycle]. So a
separate comparator, which is cheap and keeps the ALU's output free.

Note what RV32I omits: there is no `BGT` or `BLE`. `bgt a, b, L` assembles as
`blt b, a, L` — the #emph[assembler] swaps the operands and the hardware needs
no extra cases. Six conditions, not ten.

=== Byte and halfword access

Memory is 32 bits wide; the ISA has `LB`, `LH`, `LW`, `LBU`, `LHU`, `SB`, `SH`,
`SW`. So a byte store must change #emph[one] byte and leave the other three
alone — which is why the memory has per-byte write enables — and a byte load
must select and extend. `LB` sign-extends and `LBU` zero-extends; both exist
because C's `char` may be either and a compiler must be able to ask for exactly
one.

== The bug only running software could find

The CPU ran on the first attempt — 109 cycles, reaching `halt` — and got most
answers right. Every failure was an #strong[X], and all of them traced to `LUI`.

#found[
  Lesson 12's decoder carried a comment saying #emph["rs1 is x0 by convention
  for LUI"], and the datapath relied on it. #strong[That is false.] `LUI` has
  no `rs1` field at all: `inst[19:15]` is part of its 20-bit immediate. So the
  ALU was adding the immediate to whatever register those five bits happened to
  name — an undefined register — and the X propagated into every value built
  with a large constant.

  Lesson 12's own testbench checked that `LUI` asks the ALU for ADD, and it
  does. #strong[It never checked where the operands came from.] 161 passing
  decoder checks and a mutation-tested testbench did not find this; eighty-eight
  instructions of real software found it in one go.
]

#why[
  #strong[Unit tests verify the parts. Integration finds the assumptions
  between the parts.] Both are necessary and neither substitutes for the other.
  The decoder now has an explicit "operand A is zero" output, and its testbench
  asserts it for `LUI` and asserts it is #emph[not] set for `add` or `auipc`.
]

== Testing through the architectural interface

The test program stores every result to a known memory address, and the
testbench reads data memory rather than peeking at the register file.

#why[
  That tests the CPU through the interface #emph[software actually uses], so a
  core that computes correctly but #emph[stores] wrongly still fails — which is
  also all that software could tell you. The program ends by setting a flag,
  and writes a marker if any branch goes the wrong way; the test requires the
  flag and forbids the marker.
]

== What it cost, and what it cost in time

#measured("thirty-two flip-flops in an entire CPU")[
  #ttable(
    columns: (auto, auto),
    [`LUT4`],      [1,765],
    [muxes],       [773],
    [`CCU2C`],     [80],
    [flip-flops],  [#strong[32] — the program counter, and nothing else],
    [`DPR16X4`],   [32 — the register file, as distributed RAM],
  )
  All the state a single-cycle machine has is its PC. The register file lives in
  distributed RAM and everything else is combinational. Lesson 16 will add
  hundreds of flip-flops, and that is precisely what pipelining #emph[is].
]

#measured("the number this lesson exists to produce")[
  #ttable(
    columns: (auto, auto),
    [32-bit ALU alone (lesson 10)], [115.94 MHz],
    [*the whole single-cycle core*], [*61.24 MHz*],
  )
]

Adding fetch, register read, memory access and writeback to the ALU's path
#strong[roughly halves the clock]. Every instruction — even `nop` — pays the
full critical path, because every instruction takes exactly one cycle and that
cycle must be long enough for the slowest one.

#why[
  That is the entire argument for pipelining, now with a number attached.
  Lesson 16 splits this path into five stages so each is short, and pays for it
  in hazard logic.
]

== On the board

Set the switches to 2 and you are reading the result of `addi t2, t0, -1`,
which must be #strong[9]. Had lesson 12's trap gone unfixed it would read 11.

This is a RISC-V processor you built, running a program you wrote, on a chip
you configured. Worth a moment.
