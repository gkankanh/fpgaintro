#import "../style.typ": *

= How to run the exercises

== The shape of a lesson

Every lesson is a directory holding its own source, testbench, Makefile and
written lesson:

```
13-rv32i-single/
  README.md        the lesson
  cpu.v            synthesisable source
  tb_cpu.v         testbench — always prints PASS or FAIL
  test.s           an assembly program, where the lesson needs one
  Makefile         four lines; the rules live in common/lesson.mk
  diagrams/        timing diagram sources
  icestudio/       the visual path, where the lesson has one
```

Each one follows the same arc: the idea, the design, simulate it, look at the
waveform, see what it cost, run it on the board, exercises.

== The commands

Every lesson understands the same verbs. Run them from inside a lesson folder:

#ttable(
  columns: (auto, 1fr),
  [`make sim`],   [Icarus Verilog — run the testbench. #strong[Must print `PASS`.]],
  [`make wave`],  [GTKWave — look at the waveform],
  [`make lint`],  [Verilator `-Wall` — latches, widths, multiple drivers],
  [`make graph`], [yosys + graphviz — render the design as a schematic],
  [`make synth`], [the resource report: LUT4s, flip-flops, block RAM, carry cells],
  [`make synth M=mod`], [the same report for one module rather than the whole
                        design — how every per-module cost in this book was
                        produced],
  [`make bit`],   [yosys → nextpnr → ecppack — a bitstream, with timing closure],
  [`make prog`],  [load into FPGA SRAM — volatile, for iterating],
  [`make flash`], [write to SPI flash — survives power-off],
  [`make clean`], [delete build products],
)

Or from the project root, without changing directory — `L` is the lesson
number:

```bash
make list              # which lesson is which number
make sim    L=5        # simulate lesson 05
make deploy L=0        # build lesson 00 and load it onto the board
make wave   L=3        # open lesson 03's waveform
```

And across the whole course:

#ttable(
  columns: (auto, 1fr),
  [`make check`],    [is the toolchain healthy?],
  [`make sim-all`],  [every lesson's testbench — the regression suite],
  [`make lint-all`], [Verilator across every lesson],
  [`make ice`],      [regenerate the Icestudio projects from their specs],
  [`make docs`],     [build the HTML version of the lessons],
  [`make pdf`],      [build this book],
)

== The order to do things in

+ #strong[Read the lesson's "The idea" section] before looking at any code.
  Most lessons are about one idea and the code is its consequence.

+ #strong[`make sim`.] It must print `PASS`. If it does not, the lesson is not
  finished and nothing else is worth doing yet.

+ #strong[`make wave`], and look at the three signals the lesson tells you to
  look at. A waveform with forty signals in it is not useful until someone
  tells you which three matter, which is what the lessons do.

+ #strong[`make synth`], and read the number. Then try to account for it. This
  is the habit that separates "it works" from "I know what I built".

+ #strong[`make graph`], at least once per lesson. Seeing what the synthesiser
  inferred from what you wrote is the fastest way to find the gap between the
  two.

+ #strong[`make prog`], where the lesson has a board demo.

+ #strong[The exercises.] Most of them break something deliberately. Predict
  what will happen before you run it — a prediction you can check is worth ten
  instructions you can follow.

== On the exercises

They are not homework. Each is chosen because it teaches something by failing
in an instructive way, and each states what you should observe when it works.

Three kinds recur:

- #strong[Break it and watch.] "Change `<=` to `=` and run `make sim`." The
  failure is the lesson.
- #strong[Predict then measure.] "How many flip-flops will this use? Now run
  `make synth`."
- #strong[Extend it.] "Add a parity bit." These are the ones that take an
  evening, and the ones worth doing.

Worked solutions are shipped only where an answer is genuinely hard to
self-check — lesson 01 has a set; most lessons do not need one, because the
exercise states what you should see.

== When something goes wrong

#ttable(
  columns: (auto, 1fr),
  [`command not found`], [
    the toolchain is missing — run `tools/install.sh`
  ],
  [macOS: "cannot be opened"], [
    quarantine flags; `xattr -dr com.apple.quarantine toolchain/oss-cad-suite`
  ],
  [linting does nothing], [
    the editor was launched without the toolchain on `PATH` — use
    `tools/code.sh`
  ],
  [`No rule to make target 'bit'`], [
    `make` ran in the project root with no lesson named. Add `L=n`, or open a
    file inside a lesson first
  ],
  [`Nothing to be done for 'bit'`], [
    the bitstream is newer than the source. `make clean` to force a rebuild
  ],
  [`openFPGALoader` finds nothing], [
    wrong USB socket, or a charge-only cable
  ],
  ["no extension found for verilog"], [
    you pressed the editor's Run/Debug button. Verilog is not *executed* — it
    is simulated or synthesised. Use `make sim`
  ],
  [`nextpnr` fails timing], [
    the design is too slow for the requested clock. Read the critical path it
    reports; lesson 04 is about exactly this
  ],
)

== Reproducing the numbers in this book

Every resource count and every frequency in this book was produced by the
commands printed beside it, on the setup below. Synthesis results are not
universal constants: a different toolchain release can move a LUT4 count by a
few percent, and a different device or speed grade moves the frequencies.

#ttable(
  columns: (auto, 1fr),
  [*board*],        [Radiona ULX3S, `ulx3s_v20.lpf` — the constraint file for
                     board revisions v2.x.x and v3.0.x],
  [*device*],       [Lattice ECP5 `LFE5U-85F-6BG381C` — 85F size grade,
                     #strong[speed grade 6], 381-ball caBGA, commercial],
  [*clock*],        [25 MHz, from the board crystal, constrained in the `.lpf`
                     with `FREQUENCY PORT "clk_25mhz" 25 MHZ`],
  [*place & route*], [`nextpnr-ecp5 --85k --package CABGA381 --freq 25`],
  [*toolchain*],    [OSS CAD Suite release `2026-11-10`],
  [*synthesis*],    [Yosys 0.70+368 (`7cf88aca6`), `synth_ecp5`],
  [*p\&r*],         [nextpnr 0.11.1-89 (`445e2a65`)],
  [*bitstream*],    [Project Trellis `ecppack` 1.4-88],
  [*simulation*],   [Icarus Verilog 14.0 (devel)],
  [*linting*],      [Verilator 5.055 devel],
)

The resource numbers come from `make synth`, which runs `synth_ecp5` and
`stat` — not from a placed design, so they do not include the board wiring
unless the quoted module is the lesson's top. The frequencies come from
`make bit`, which is `nextpnr` reporting the routed design's maximum frequency
for each clock.

#why[
  A measured number without its conditions is an anecdote. If your own `make
  synth` disagrees with this book by a cell or two, the likely reason is a
  newer OSS CAD Suite — which is the right thing to trust, since it is the one
  that built your bitstream.
]

== Keeping the whole course green

```bash
make sim-all
```

A later lesson must never break an earlier one, so the whole course is a
regression suite. When a module is promoted into `common/rtl/` — as the adder
and the debouncer are, once a second lesson needs them — this is what catches a
change that breaks a downstream lesson. It is worth running before every
commit.
