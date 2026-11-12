#import "../style.typ": *

= What an FPGA is

This chapter is the short version of what the rest of the book assumes. If you
have taped out a chip or written gateware for a living, skip it; if your mental
model of a programmable part is still a microcontroller, it is three pages well
spent, because almost every surprise in the course comes from the difference.

== A chip that becomes your circuit

A microcontroller arrives with its hardware already decided. Somebody chose how
many adders it has, how wide its registers are, which peripherals are on which
pins, and in which order it will do things. You get flexibility by changing the
#emph[sequence of instructions] it fetches; the silicon itself is fixed, and
one instruction happens at a time.

An FPGA arrives with almost nothing decided. It is a field of uncommitted
logic, flip-flops and wires, plus a very large number of switches that
determine which wire connects to which. Configuring it does not give the chip a
program to follow — it #strong[builds a circuit out of the fabric]. That is the
whole of the acronym: a #emph[field-programmable gate array], an array of logic
that is programmable after it has left the factory.

The consequence is immediate and it never stops mattering. If your design needs
thirty-two adders working at the same time, it has thirty-two adders, all
adding on every clock edge. Nothing is shared unless you write the sharing, and
nothing waits its turn unless you build the queue.

== "Programming" it means loading configuration bits

There is no compiler emitting instructions here, because there is nothing to
execute them. The toolchain instead produces a #strong[bitstream]: a file of
configuration bits that fills in every lookup table's contents and sets every
routing switch in the part.

A bitstream is therefore a description of the whole chip, not of your design.
Lesson 00's blinky — a counter and eight LEDs — produces a 274 KB bitstream on
this part. Lesson 13's complete RISC-V CPU, something like a hundred times the
logic, produces 295 KB. Both files configure the same fabric; most of either
one is saying "unused".

On the ECP5 that configuration lives in on-chip SRAM, which means it is
volatile, and that is why the course has two load commands:

#ttable(
  columns: (auto, 1fr),
  [`make prog`],  [straight into the FPGA's configuration SRAM. Takes about a
                   second, and is gone the moment the board loses power. This
                   is what you use while iterating],
  [`make flash`], [into the SPI flash chip beside the FPGA, from which the FPGA
                   reloads itself at every power-on. This is what you use when
                   the design is finished],
)

An FPGA that has not been configured does nothing whatsoever. It is not running
an idle loop; there is no loop.

== Verilog is a description, not a program

This is the one real mental shift, and it is worth being blunt about.

There are no lines that "run". `assign y = a & b;` is not a statement executed
when control reaches it — it is a piece of wiring that holds continuously, for
as long as the chip is powered. `always @(posedge clk)` is not a loop; it is a
register that updates on every rising edge, forever, whether or not anything
else in the design is paying attention. Two `always` blocks are not two threads
taking turns. They are two pieces of hardware, both of them live, always.

A `for` loop in synthesisable code does not iterate in time either. It stamps
out copies in space: a loop of thirty-two iterations becomes thirty-two copies
of its body, all working at once. Loop count is area, not duration.

#watch[
  Because nothing is executed, the editor's Run or Debug button has nothing to
  bind to, and pressing it produces "no extension found for verilog". Verilog
  is #emph[simulated] (`make sim`) or #emph[synthesised] (`make synth`) — never
  run. "How to run the exercises" lists that error alongside the other ones
  worth recognising on sight.
]

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

== What "what it cost" means

Every lesson ends by asking what the design cost, and in this course that
phrase has one meaning: #strong[how much of the FPGA it used]. Not money, not
runtime. `make synth` runs the design through yosys and prints a count of the
chip's own primitives, and these are the lines worth reading:

#ttable(
  columns: (auto, 1fr),
  [*in the report*], [*what it is*],
  [`LUT4`],         [four-input lookup tables — general-purpose logic, and
                     usually the headline number],
  [`TRELLIS_FF`],   [flip-flops: one bit of state each. Lesson 05's design
                     reports 113 of them, and the lesson accounts for all 113],
  [`CCU2C`],        [carry cells, two bits of arithmetic each — the dedicated
                     adder hardware, which is why `+` is so much cheaper than
                     logic you build yourself],
  [`PFUMX`, `L6MUX21`], [multiplexers that glue LUT4s together into wider
                     functions, so a 5- or 6-input function costs a little more
                     than one LUT4],
  [`TRELLIS_DPR16X4`], [distributed RAM: 16 words of 4 bits built out of a
                     logic cell's lookup tables, which is how a small array
                     gets stored when a block RAM would be wasteful],
  [`DP16KD`],       [block RAMs, 18 Kbit each — lesson 08's subject],
  [`MULT18X18D`],   [hardware 18×18 multipliers. Seeing one appear when you did
                     not ask for it is lesson 08's most useful surprise],
)

Area is what you spend. #strong[Time is a separate thing, and it is a
constraint rather than a price]: the longest path of logic between two
flip-flops has to settle inside one clock period. Adding logic to that path
does not make the design slower — the design has no choice about its clock, the
board's crystal does — it makes it #emph[stop working], and `nextpnr` says so
when `make bit` fails timing. That is lesson 04's subject.

Both quantities come back in a second or two, which is the whole reason this
course can measure rather than assert.

== The tools, in order

#fig("/figures/fpga-flow.svg",
     [From a Verilog file to a configured chip. Four programs, each solving a
      different problem, and each failing in its own characteristic way.],
     width: 100%)

#ttable(
  columns: (auto, 1fr),
  [*stage*], [*what it turns into what*],
  [`yosys`], [
    Verilog into a netlist of this chip's primitives — the table above. Goes
    wrong by inferring a latch you did not intend, or a hardware multiplier
    where you expected shifts
  ],
  [`nextpnr-ecp5`], [
    that netlist into a choice of which physical cell and which physical wire,
    then checks the clock against the result. Goes wrong by not fitting, or by
    not meeting 25 MHz
  ],
  [`ecppack`], [
    the placed design into a bitstream the chip will accept. Rarely goes wrong;
    by here the hard decisions have been made
  ],
  [`openFPGALoader`], [
    a bitstream into the board, over the same USB cable that carries the serial
    port. Goes wrong by finding no device — usually the wrong USB socket or a
    charge-only cable
  ],
)

Alongside that path, and ahead of it, sit `iverilog` for simulation and
`verilator` for linting. Who wrote all of these, and why it matters that you
can read their source, is the subject of "The toolchain, and the people who
built it".

== When an FPGA is the right answer

Not as often as a course about FPGAs might imply, and saying so makes the
course easier to place.

A microcontroller is cheaper, smaller, lower power and far easier to program
for anything that fits comfortably in software — which is most things. That is
not a concession; it is the reason lesson 15 puts a #emph[CPU inside the FPGA]
rather than building ever more logic by hand. An ASIC, at the other end, is
dramatically faster and cheaper per unit, once you can spread the cost of a
mask set over millions of parts.

An FPGA wins in the gap between them:

- #strong[Genuine parallelism with predictable timing.] Sixteen channels of
  signal processing, or a video pipeline, all running every cycle, with latency
  that does not vary because there is no operating system and no cache.
- #strong[Interfaces whose timing software cannot hold.] If a protocol needs a
  response within 40 ns, every cycle, no software will do it; a few hundred
  LUT4 will.
- #strong[Low volume, or still changing.] Instrumentation, telecoms equipment,
  medical devices, a protocol that is not finalised — anywhere an ASIC cannot
  pay for itself or cannot be committed to yet.
- #strong[Prototyping silicon] before it is manufactured, which is where a
  large share of the world's FPGAs actually sit.

#why[
  And for learning, there is nothing else like it. A wrong idea costs seconds
  rather than a fabrication run, the result is real hardware rather than a
  simulation of hardware, and the entire loop — write, simulate, synthesise,
  measure, run on silicon — fits on a laptop with no licence and no permission.
  That is what makes a refresher like this one possible at all.
]

== The words

Used throughout the book without further ceremony:

#ttable(
  columns: (auto, 1fr),
  [*fabric*],        [the uncommitted logic and routing in the part],
  [*logic cell*],    [one LUT4 plus its flip-flop plus its carry hardware — the
                      unit the fabric is made of, opened up in the next chapter],
  [*netlist*],       [a design expressed as primitives and the wires between
                      them: the output of synthesis],
  [*RTL*],           [register-transfer level — describing hardware as registers
                      and the logic between them, which is what you write],
  [*synthesis*],     [Verilog → netlist],
  [*place and route*], [netlist → specific cells and specific wires],
  [*timing closure*], [proving every path settles within one clock period],
  [*bitstream*],     [the configuration bits for the whole chip],
  [*inference*],     [the synthesiser deducing hardware from what you wrote —
                      a counter, a RAM, a latch you did not want],
  [*constraint file*], [`common/ulx3s_v20.lpf`: which signal goes to which
                      physical pin, and how fast the clock is],
  [*testbench*],     [non-synthesisable Verilog that drives a design and checks
                      it, which in this course always prints `PASS` or `FAIL`],
)
