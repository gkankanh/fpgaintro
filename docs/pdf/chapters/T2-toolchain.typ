#import "../style.typ": *

= The tools, and the people who built them

== The chain, in order

#fig("/figures/fpga-flow.svg",
     [From a Verilog file to a configured chip. Four programs, each solving a
      different problem, and each failing in its own characteristic way.],
     width: 100%)

#ttable(
  columns: (auto, 1fr),
  [*stage*], [*what it turns into what*],
  [`yosys`], [
    Verilog into a netlist of this chip's primitives. Goes wrong by inferring a
    latch you did not intend, or a hardware multiplier where you expected
    shifts
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
`verilator` for linting.

== Who wrote them

None of this course would exist without a long chain of mostly volunteer work,
much of it given away.

#ttable(
  breakable: true,
  columns: (auto, 1fr),
  [*Icarus Verilog*], [
    Simulation — the `make sim` in every lesson. #strong[Stephen Williams],
    since 1998: one of the oldest free Verilog implementations, and still the
    most forgiving one to learn in.
  ],
  [*Verilator*], [
    The strict linter, and a very fast simulator. #strong[Wilson Snyder].
    Every `make lint` here is Verilator, and it caught real bugs while this
    course was written — a register driven from two `always` blocks, and a
    width truncation a passing test had hidden.
  ],
  [*Yosys*], [
    Synthesis: Verilog in, a netlist of ECP5 primitives out. #strong[Claire
    Wolf], now YosysHQ. Every resource measurement in the course book is
    `yosys … stat`; every schematic is `yosys show`.
  ],
  [*nextpnr*], [
    Place and route, and timing analysis. #strong[gatecat] (formerly David
    Shah) with many others. Every maximum-frequency figure comes from here.
  ],
  [*Project Trellis*], [
    The ECP5 bitstream documentation — the work that makes all of the above
    possible on this chip. Also #strong[gatecat]'s, with contributors.
    `ecppack` and the PLL calculator `ecppll` are from this project.
  ],
  [*GTKWave*], [
    Waveform viewing, by #strong[Tony Bybell]. The `make wave` of every lesson.
  ],
  [*openFPGALoader*], [
    Getting the bitstream onto the board, across a remarkable range of cables
    and boards. #strong[Gwenhael Goavec-Merou].
  ],
  [*SymbiYosys*], [Formal verification, used in lesson 14. YosysHQ.],
  [*OSS CAD Suite*], [
    All of the above, built nightly for every platform as one archive, by
    YosysHQ. `tools/install.sh` downloads exactly this, which is why setup is
    one command instead of an afternoon.
  ],
  [*Icestudio, apio*], [
    The visual path: a block-diagram editor and the build system under it, by
    #strong[Jesús Arroyo Torrens] and the #strong[FPGAwars] community. apio
    wraps the same yosys and nextpnr, so the two paths are two front ends onto
    one toolchain.
  ],
  [*ULX3S*], [
    Open hardware from #strong[Radiona.org], the Zagreb makerspace, with
    #strong[Goran Mahovlić] and #strong[Davor Jadrijević] ("emard"), whose
    collection of example designs — SDRAM controllers, video, emulators of
    older machines — is worth reading once the course is finished.
  ],
  [*RISC-V*], [
    Designed at UC Berkeley by #strong[Krste Asanović],
    #strong[Andrew Waterman], #strong[Yunsup Lee] and
    #strong[David Patterson], and released as an open standard — which is why
    a course can end with "now build the processor" rather than "now read about
    one".
  ],
  [*riscv-formal*], [
    A formal specification of RV32I an implementation can be checked against,
    by #strong[Claire Wolf]. Lesson 14 uses it to prove the lesson 13 core
    correct rather than merely tested.
  ],
)

Project IceStorm — Claire Wolf's documentation of the Lattice iCE40 bitstream,
published in 2015 — is the root of this tree. It demonstrated that a modern
FPGA's bitstream could be understood well enough to target with free tools, and
Project Trellis then did the same for the much larger ECP5. A commercial
toolchain is a licence-managed install from a vendor with a commercial interest
in the chips it targets; the equivalent used here was largely written by
individuals, is readable end to end, and asks nothing. If this course is useful
to you, those projects are where the gratitude should go — and most of them
take contributions from people whose first design was a blinking LED not long
before.

== Why an open toolchain matters here

- #strong[Nothing expires and nothing phones home.] No licence server, no
  registration, no node-locked key that stops working when you change laptop.
- #strong[You can read the tools.] When yosys does something surprising — and
  the course documents several cases — the source is there. The schematic
  `make graph` produces is the tool showing you its own intermediate
  representation.
- #strong[It runs anywhere.] One download of about a gigabyte, no
  administrator rights, removed by deleting a directory.

== Licences

#ttable(
  columns: (auto, 1fr),
  [*Code*], [
    MIT. The Verilog, the tools, the Makefiles and the assembly programs. Use
    them in anything, commercial or not; keep the copyright notice.
  ],
  [*Prose*], [
    Creative Commons Attribution 4.0. The lessons, both books and the diagrams.
    Share, adapt, translate, teach from them — commercially if you like —
    giving credit and indicating changes.
  ],
)

One file is not this project's to license: `common/ulx3s_v20.lpf`, the board's
pin constraints, which come from the ULX3S project and are included because the
course cannot work without them. Everything else is original to the course.
