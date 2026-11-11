#import "../style.typ": *

= About this course

This is a hands-on refresher in digital design, worked from a single logic gate
to a 32-bit RISC-V processor running compiled C, with a toolchain that is open
source from the Verilog parser to the bitstream.

The lessons are built and measured on a #strong[Radiona ULX3S], carrying a
Lattice ECP5 `LFE5U-85F`, and every number in this book was measured on that
part. But roughly half the course is board-independent: gates, multiplexers,
state machines, the ALU, the register file and instruction decode would be
identical on any FPGA. Where a result depends on this particular fabric — and
several of the most interesting ones do — the book says so.

It is written for someone who studied this once — perhaps a long time ago, as
an electrical engineer — and wants the ideas back *in their hands* rather than
back in their head. So concepts are stated briefly and then built: simulated,
inspected in a waveform viewer, synthesised, measured, and run on real silicon.

It assumes you know what a gate, a register and a clock are. It does not assume
you remember what a blocking assignment does to a shift register, or why your
counter synthesised into a latch.

== What you will build

Eighteen lessons, each self-contained, each ending in something you can see
working. The sequence is not arbitrary — every lesson exists because a later
one needs it.

#fig("/figures/course-map.svg",
     [The course. Solid arrows are prerequisites; the right-hand column is the
      processor, assembled from parts built in the left-hand ones.],
     width: 100%)

By lesson 13 you have a RISC-V CPU running programs. By lesson 15 it runs C
compiled by a standard GNU toolchain, printing to your terminal. Lesson 16
pipelines it.

== The method

Three habits run through every lesson, and they matter more than any particular
circuit.

=== Simulate first, and make the testbench say PASS or FAIL

Nothing goes near synthesis until a self-checking testbench passes. Every
testbench in this course prints an explicit verdict — never a waveform to
squint at — because a test you have to interpret is a test you will
misinterpret at one in the morning.

=== Measure; do not inherit opinions

This is the one that makes the course worth doing rather than reading. The
synthesiser's output is two seconds away, and it repeatedly contradicts what
everyone *knows*:

#measured("four received rules that did not survive contact with the fabric")[
  - "One-hot encoding suits FPGAs, since flip-flops are free." On this
    four-state machine it cost #strong[41 LUT4 against 12] — nearly four times
    worse (lesson 05).
  - "Mealy machines need fewer states, so they are cheaper." Fewer states, yes
    — 3 against 4 — and #strong[more logic]: 5 LUT4 against 2 (lesson 05).
  - "The synthesiser will reduce a constant multiply to shifts." It spent
    #strong[two hardware multiplier blocks] instead (lesson 08).
  - "Build it from gates to understand it, then it is the same thing." The
    hand-built 32-bit adder cost #strong[212 cells to `+`'s 17] (lesson 02).
]

None of those are in this book because they were read somewhere. They are here
because `make synth` said so, and the numbers are reproducible on your machine
in the time it takes to read this paragraph.

=== Account for every flip-flop

When `make synth` reports more state than you can explain, you have inferred
something you did not intend. Lesson 05's design reports 113 flip-flops, and
they decompose exactly: 25 for the tick divider, 5 for the traffic light, 76
for four debouncers, 4 for edge detectors, 3 for the lock's state. That habit
finds bugs no test was written for.

== Two ways to do it

Every lesson up to 09 can be done by typing Verilog in an editor, or by wiring
blocks together visually in Icestudio. Both are first class, and you can switch
at any lesson.

The two cannot drift apart, because the Icestudio project is #emph[generated]
from the lesson's real Verilog: a short specification names the source file and
binds each port to a board pin, and a tool lifts the module body into a visual
code block. The diagram you wire up and the file you would type are the same
design, laid out differently.

Going the other way, `make graph` runs your Verilog through the synthesiser and
hands you back a schematic. Doing that once per lesson is the fastest way to
find the gap between what you meant and what you said.

#why[
  Beyond lesson 09 the lessons are editor-only, and that is itself a lesson.
  Schematic entry stops scaling at roughly the complexity of a 32-bit datapath:
  a 32-bit ALU drawn as blocks is a wall of identical slices nobody can read,
  while as text it is a dozen lines with `[31:0]` on them. The industry made the
  same transition in the late 1980s for the same reason.
]

== What this course is not

It is not a Verilog language reference, and it is not a complete treatment of
computer architecture. Both exist and are better at being themselves; several
are listed at the end of this book.

It is also not a tour of IP cores. Nothing here is instantiated from a vendor
library. Every component — the adder, the register file, the UART, the CPU — is
built and tested in a lesson, because the point is to have built it.
