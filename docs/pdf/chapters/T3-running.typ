#import "../style.typ": *

= Running a lesson

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
  icestudio/       the visual path: a spec and the project built from it
```

A lesson's Makefile declares only what is different about it and includes the
shared rules:

```make
TOP = blink          # synthesisable top module, in blink.v
TB  = tb_blink       # testbench module, in tb_blink.v
include ../common/lesson.mk
```

`common/lesson.mk` is the whole build system — about 90 commented lines, worth
reading once.

== The verbs

Every lesson understands the same ones. Run them from inside a lesson folder.

#ttable(
  columns: (auto, auto, 1fr),
  [*verb*], [*tool*], [*what it does*],
  [`make sim`],   [iverilog + vvp], [compile source and testbench, run it.
                                     #strong[Must print `PASS`]],
  [`make wave`],  [GTKWave], [open the VCD this lesson produced],
  [`make lint`],  [Verilator `-Wall`], [width mismatches, inferred latches,
                                        multiple drivers],
  [`make graph`], [yosys + graphviz], [render the design as an SVG schematic],
  [`make synth`], [yosys `synth_ecp5`], [resource report: LUT4s, flip-flops,
                                         block RAM, carry cells],
  [`make bit`],   [yosys → nextpnr → ecppack], [a bitstream, with timing
                                                closure],
  [`make prog`],  [openFPGALoader], [load into FPGA SRAM — volatile, for
                                     iterating],
  [`make flash`], [openFPGALoader `-f`], [write to SPI flash — survives
                                          power-off],
  [`make clean`], [], [delete build products],
)

=== Options the verbs take

`make synth` reports the design as built, which is flattened — so a submodule's
own cost is only visible by making it the top. `M` does that, and `P`
overrides one of its parameters. Every per-module number in the course book was
produced this way, and the lesson always says which command produced which:

```bash
make synth                        # the lesson's top, as built
make synth M=uart_rx              # just the receiver
make synth M=adder_ripple P="W 4" # that module at a different width
```

The rest are variables a lesson's own Makefile overrides, listed here because
reading an unfamiliar lesson's Makefile is easier when the knobs have names:

#ttable(
  columns: (auto, auto, 1fr),
  [*variable*], [*default*], [*what it is for*],
  [`SRCS`],      [`$(TOP).v`],   [the synthesisable sources],
  [`TB_SRCS`],   [`$(TB).v`],    [the testbench sources],
  [`SIM_SRCS`],  [`$(SRCS)`],    [what to #emph[simulate], when that differs.
    A lesson instantiating a hard block — the PLL, a block RAM primitive, an
    I/O buffer — cannot simulate it: there is no behavioural model in
    iverilog. Such a lesson names only the simulatable part here and verifies
    the rest structurally with `make bit`. Lesson 04 is the first to need it],
  [`DATA`],      [empty], [memory images read by `$readmemh`. These are read at
    #emph[elaboration] time, by iverilog and by yosys, so they are build
    inputs exactly like a `.v` file. A lesson that leaves them out quietly
    simulates and flashes a #strong[stale] program after you rebuild the
    software — which lesson 15 did, reporting nothing to be done while
    `firmware.hex` was newer than the bitstream],
  [`LINT_SRCS`, `LINT_TOP`], [from `SIM_SRCS`], [what Verilator sees],
  [`VCD`],       [`$(TOP).vcd`], [the waveform file `make wave` opens],
  [`DEVICE`, `PACKAGE`, `BOARD`], [`--85k`, `CABGA381`, `ulx3s`],
                 [the part and the programmer target],
  [`FREQ`],      [`25`], [the clock nextpnr must prove the design closes at],
)

Two Verilator warnings are waived course-wide and both are deliberate.
`DECLFILENAME` enforces one module per file — right for a large project, wrong
for a lesson where three related ten-line modules read better grouped in one
file. `PROCASSINIT` objects to `reg q = 0;` on a signal that is also assigned
procedurally, which the course does everywhere on purpose: the ECP5 loads
flip-flop initial values straight from the bitstream, so a register really does
start at a known value with no reset logic. Not every target honours that,
which is why the lessons say so in prose rather than pretending it is portable.
Every other `-Wall` warning is an error — a linter trained to cry wolf is a
linter you stop reading.

== From the project root, without changing directory

`L` is the lesson number. `5`, `05` and `05-fsm` all find the same lesson:

```bash
make list              # which lesson is which number
make deploy L=0        # build lesson 00 and load it onto the board
make sim    L=5        # simulate lesson 05
make wave   L=3        # open lesson 03's waveform
```

Every per-lesson verb works this way — `sim bit prog flash lint synth graph
wave clean deploy`. With no `L`, the Makefile says which lessons exist rather
than failing cryptically. This exists because remembering which editor tab is
focused, or which directory a terminal is in, is friction nobody needs.

== Across the whole course

#ttable(
  columns: (auto, 1fr),
  [`make check`],    [verify the toolchain and smoke-test lesson 00],
  [`make sim-all`],  [every lesson's testbench — the regression suite],
  [`make lint-all`], [Verilator across every lesson],
  [`make graph-all`],[render every lesson as a schematic],
  [`make ice`],      [regenerate the Icestudio projects from their specs],
  [`make icecheck`], [compile-check every Icestudio project, without the GUI],
  [`make tasks`],    [regenerate the editor's per-lesson task list],
  [`make docs`],     [build the HTML version of the lessons],
  [`make docs-serve`], [serve that at `http://localhost:3000`],
  [`make pdf`],      [build both books: the course and this document],
  [`make pdf-watch`],[rebuild them on every save],
  [`make clean-all`],[remove build products everywhere],
  [`make help`],     [list the above],
)

=== Keeping the whole course green

```bash
make sim-all
```

A later lesson must never break an earlier one, so the whole course is a
regression suite. When a module is promoted into `common/rtl/` — as the adder
and the debouncer are, once a second lesson needs them — this is what catches a
change that breaks a downstream lesson. Worth running before every commit; it
ends with `ALL LESSONS PASS` or names what failed.

== The editor's task list

Optional, and entirely equivalent to the `L=` commands above.
#strong[Terminal → Run Task…] lists every lesson by name, deploy entries
first; clicking one builds it and loads it onto the board, with nothing
selected beforehand and no regard for which file is open.

#ttable(
  columns: (auto, 1fr, auto),
  [*keys*], [*action*], [*which lesson*],
  [`⌘⇧B`], [`make sim` — run the testbench], [the open file's],
  [`⌘⌥R`], [the task picker — everything], [you choose],
  [`⌘⌥U`], [build #strong[and] deploy], [asks],
  [`⌘⌥B`], [build a bitstream only], [asks],
  [`⌘⌥P`], [deploy an existing bitstream], [asks],
  [`⌘⌥L`], [`make lint` — Verilator, strict], [the open file's],
  [`⌘⌥G`], [`make wave` — GTKWave], [the open file's],
  [`⌘⌥Y`], [is the board connected?], [—],
  [`⌘⌥T`], [stop the running task], [—],
)

"The open file's" means the task runs in the directory of whichever editor tab
is focused. With a root-level README focused there is no lesson, and the
Makefile says so.

== The order to do things in

+ #strong[Read the lesson's idea] before looking at any code. Most lessons are
  about one idea and the code is its consequence.

+ #strong[`make sim`.] It must print `PASS`. If it does not, nothing else is
  worth doing yet.

+ #strong[`make wave`], and look at the three signals the lesson tells you to
  look at. A waveform with forty signals in it is not useful until someone says
  which three matter.

+ #strong[`make synth`], and read the number. Then try to account for it. This
  is the habit that separates "it works" from "I know what I built".

+ #strong[`make graph`], at least once per lesson. Seeing what the synthesiser
  inferred from what you wrote is the fastest way to find the gap between the
  two — an `always` block you thought was a register that became a latch, a
  comparison you thought was 4 bits wide that became 32.

+ #strong[`make prog`], where the lesson has a board demo.

+ #strong[The exercises.] Most break something deliberately. Predict what will
  happen before you run it.

== On the exercises

They are not homework. Each is chosen because it teaches something by failing
in an instructive way, and each states what you should observe when it works.
Three kinds recur: #strong[break it and watch] ("change `<=` to `=` and run
`make sim`" — the failure is the lesson), #strong[predict then measure] ("how
many flip-flops will this use? now run `make synth`"), and #strong[extend it]
("add a parity bit"), which are the ones that take an evening and the ones
worth doing. Worked solutions ship only where an answer is genuinely hard to
self-check; lesson 01 has a set, most lessons do not need one.
