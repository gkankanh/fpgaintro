#import "../style.typ": *

= The toolchain, and the people who built it

None of this course would exist without a long chain of mostly volunteer work,
much of it given away. The tools are named throughout the lessons; this chapter
is where the people are.

== The chain from Verilog to bitstream

#ttable(
  columns: (auto, 1fr),
  [*Icarus Verilog*], [
    Simulation. The `make sim` in every lesson. Written and maintained by
    #strong[Stephen Williams] since 1998 — one of the oldest free Verilog
    implementations, and still the most forgiving one to learn in.
  ],
  [*Verilator*], [
    The strict linter, and a very fast simulator. Created by
    #strong[Wilson Snyder]. Every `make lint` in this course is Verilator, and
    it caught several real bugs during the writing — including a register
    driven from two `always` blocks and a width truncation that a passing test
    had hidden.
  ],
  [*Yosys*], [
    Synthesis: Verilog in, a netlist of ECP5 primitives out. Created by
    #strong[Claire Wolf], now developed at YosysHQ. Every resource measurement
    in this book is `yosys … stat`, and every schematic is `yosys show`.
  ],
  [*nextpnr*], [
    Place and route, and timing analysis. Created by #strong[gatecat]
    (formerly David Shah) with contributions from many others. Every "maximum
    frequency" figure in this book comes from nextpnr.
  ],
  [*Project Trellis*], [
    The ECP5 bitstream documentation — the work that makes all of the above
    possible on this chip. Also #strong[gatecat]'s, with contributors. `ecppack`
    and the PLL calculator `ecppll` are from this project.
  ],
  [*GTKWave*], [
    Waveform viewing, by #strong[Tony Bybell]. The `make wave` of every lesson.
  ],
  [*openFPGALoader*], [
    Getting the bitstream onto the board, across a remarkable range of cables
    and boards. By #strong[Gwenhael Goavec-Merou].
  ],
  [*SymbiYosys*], [
    Formal verification, used in lesson 14. From YosysHQ.
  ],
  [*OSS CAD Suite*], [
    All of the above, built nightly for every platform as one archive, by
    YosysHQ. `tools/install.sh` downloads exactly this, which is why setting up
    this course takes one command instead of an afternoon.
  ],
)

#why[
  Project IceStorm — Claire Wolf's documentation of the Lattice iCE40
  bitstream, published in 2015 — is the root of this whole tree. It
  demonstrated that a modern FPGA's bitstream could be understood well enough
  to target with free tools, and Project Trellis then did the same for the much
  larger ECP5. Everything in this course descends from that demonstration.
]

== The board

#ttable(
  columns: (auto, 1fr),
  [*ULX3S*], [
    Open hardware from #strong[Radiona.org], the Zagreb makerspace, developed
    with #strong[Goran Mahovlić] and #strong[Davor Jadrijević] ("emard"), who
    also maintains an extensive collection of example designs — SDRAM
    controllers, video output, emulators of older machines — that is worth
    reading once this course is finished.
  ],
  [*Pin constraints*], [
    `common/ulx3s_v20.lpf` in this repository comes from the ULX3S project
    itself. It is the one file here that is not original work, and it is the
    file that makes everything else possible: it is the map from names like
    `led[0]` to balls like `B2`.
  ],
)

== The instruction set

#ttable(
  columns: (auto, 1fr),
  [*RISC-V*], [
    Designed at the University of California, Berkeley, by
    #strong[Krste Asanović], #strong[Andrew Waterman], #strong[Yunsup Lee] and
    #strong[David Patterson], and released as an open standard. The
    specification is free to read and free to implement, which is why a course
    can end with "and now build the processor" rather than "and now read about
    one".
  ],
  [*riscv-formal*], [
    A formal specification of RV32I that an implementation can be checked
    against, by #strong[Claire Wolf]. Lesson 14 uses it to prove the lesson 13
    core correct — not merely tested.
  ],
)

The quality of the RISC-V specification is itself a teaching aid. Lesson 12
spends several pages on *why* the immediate fields are scattered the way they
are, and the answer — that the layout minimises multiplexer inputs in the
decoder, with 24 of 32 immediate bits needing no multiplexer at all — is a
designed property you can measure, not a historical accident.

== The visual path

#ttable(
  columns: (auto, 1fr),
  [*Icestudio*], [
    The block-diagram editor used as this course's alternative path, by
    #strong[Jesús Arroyo Torrens] and the #strong[FPGAwars] community.
  ],
  [*apio*], [
    The build system underneath Icestudio, also from FPGAwars, which wraps the
    same yosys and nextpnr that the command line uses. The two paths in this
    course are two front ends onto one toolchain, not two different worlds.
  ],
)

== On standing on shoulders

It is worth being explicit about the scale of what is being given away here. A
commercial FPGA toolchain is a multi-hundred-megabyte, licence-managed
install from a vendor with a commercial interest in the chips it targets. The
equivalent used in this course was largely written by individuals, is readable
end to end, and asks nothing.

If this course is useful to you, the projects above are where the gratitude
should go — and several of them take contributions, bug reports and
documentation from people whose first FPGA design was a blinking LED not long
before.

== This course's own licence

In the same spirit, and chosen so that reuse is easy rather than merely
permitted:

#ttable(
  columns: (auto, 1fr),
  [*Code*], [
    MIT. The Verilog, the tools, the Makefiles and the assembly programs. Use
    them in anything, commercial or not; keep the copyright notice.
  ],
  [*Prose*], [
    Creative Commons Attribution 4.0. The lessons, this book and its diagrams.
    Share them, adapt them, translate them, teach from them — commercially if
    you like — giving credit and indicating changes.
  ],
)

One file is not this project's to license: `common/ulx3s_v20.lpf`, the board's
pin constraints, which come from the ULX3S project and are included because
the course cannot work without them. Everything else — every diagram, every
line of Verilog, and the whole of this book — is original to the course.
