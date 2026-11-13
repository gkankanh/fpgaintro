#import "../style.typ": *

= The big picture

This is a hands-on refresher in digital design, worked from a single logic gate
to a 32-bit RISC-V processor running real programs on real silicon. It is
written for someone who studied this once — perhaps a long time ago — and wants
the ideas back #emph[in their hands] rather than back in their head. So
concepts are stated briefly and then built: simulated, inspected in a waveform
viewer, synthesised, measured, and run on a board.

It assumes you know what a gate, a register and a clock are. It does not assume
you remember what a blocking assignment does to a shift register, or why your
counter synthesised into a latch.

Everything was built and measured on a #strong[Radiona ULX3S] carrying a
Lattice ECP5 `LFE5U-85F`, and every number in this book came out of the tools
on that part. Roughly half the course is board-independent — gates,
multiplexers, state machines, the ALU, the register file, instruction decode
would be identical on any FPGA. Where a result depends on this particular
fabric, and several of the most interesting ones do, the book says so.

Installing the toolchain, the `make` verbs, programming the board and the exact
commands behind every number are in the companion volume,
#emph[Tools and Workflow]. This book is the concepts.

== A chip that becomes your circuit

A microcontroller arrives with its hardware already decided. Somebody chose how
many adders it has, how wide its registers are, which peripherals sit on which
pins, and in what order it will do things. You get flexibility by changing the
#emph[sequence of instructions] it fetches; the silicon is fixed, and one
instruction happens at a time.

An FPGA arrives with almost nothing decided. It is a field of uncommitted
logic, flip-flops and wires, plus a very large number of switches deciding
which wire connects to which. Configuring it does not give the chip a program
to follow — it #strong[builds a circuit out of the fabric]. That is the whole
of the acronym: a #emph[field-programmable gate array].

The consequence never stops mattering. If your design needs thirty-two adders
working at the same time, it has thirty-two adders, all adding on every clock
edge. Nothing is shared unless you write the sharing, and nothing waits its
turn unless you build the queue.

== Programming it means loading configuration bits

There is no compiler emitting instructions here, because there is nothing to
execute them. The toolchain produces a #strong[bitstream]: a file of
configuration bits that fills in every lookup table's contents and sets every
routing switch in the part.

A bitstream therefore describes the whole chip, not your design. Lesson 00's
blinky — a counter and eight LEDs — produces a 274 KB bitstream on this part.
Lesson 13's complete RISC-V CPU, something like a hundred times the logic,
produces 295 KB. Both configure the same fabric; most of either one says
"unused".

On the ECP5 that configuration lives in on-chip SRAM, so it is volatile:
`make prog` loads it for this power cycle, `make flash` writes the SPI flash the
FPGA reloads itself from. An FPGA that has not been configured does nothing
whatsoever. It is not running an idle loop; there is no loop.

== Verilog is a description, not a program

This is the one real mental shift, and it is worth being blunt about.

There are no lines that "run". `assign y = a & b;` is not a statement executed
when control reaches it — it is a piece of wiring that holds continuously, for
as long as the chip is powered. `always @(posedge clk)` is not a loop; it is a
register that updates on every rising edge, forever, whether or not anything
else is paying attention. Two `always` blocks are not two threads taking turns.
They are two pieces of hardware, both of them live, always.

A `for` loop in synthesisable code does not iterate in time either. It stamps
out copies in space: thirty-two iterations become thirty-two copies of the
body, all working at once. Loop count is area, not duration.

Two tools read the same file with very different strictness. The simulator
accepts a great deal that no hardware can be — delays, `$display`, unbounded
integers — because its job is to model behaviour. The synthesiser accepts a
subset, and within that subset it quietly builds what you #emph[described]
rather than what you meant: an incompletely specified `if` becomes a latch, a
missing `else` becomes a memory you did not ask for. Nothing warns you, because
from the tool's point of view you asked for it.

Hence the order of work in every lesson: simulate first, then synthesise, then
look at the schematic the synthesiser produced and check it is the circuit you
had in mind.

== Two ways to do it

Every lesson up to 09 can be done by typing Verilog, or by wiring blocks
together visually in Icestudio, and you can switch at any lesson. The two
cannot drift apart, because the Icestudio project is #emph[generated] from the
lesson's real Verilog — the diagram you wire up and the file you would type are
the same design, laid out differently. Going the other way, `make graph` runs
your Verilog through the synthesiser and hands you back a schematic.

Beyond lesson 09 the lessons are editor-only, and that is itself a lesson.
Schematic entry stops scaling at roughly the complexity of a 32-bit datapath: a
32-bit ALU drawn as blocks is a wall of identical slices nobody can read, while
as text it is a dozen lines with `[31:0]` on them. The industry made the same
transition in the late 1980s for the same reason.

== What this course is not

It is not a Verilog language reference, and it is not a complete treatment of
computer architecture. Both exist and are better at being themselves; several
are listed at the end of this book.

It is also not a tour of IP cores. Nothing here is instantiated from a vendor
library. Every component — the adder, the register file, the UART, the CPU — is
built and tested in a lesson, because the point is to have built it.
