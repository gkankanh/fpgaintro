# Digital Design on the ULX3S

A hands-on refresher in digital design, worked all the way from a single
flip-flop to a **32-bit RISC-V CPU running compiled C**, on a Radiona
**ULX3S 85F** (Lattice ECP5 LFE5U-85F) using a fully open toolchain.

It is written for someone who studied this once and wants the ideas back in
their hands — concepts stated briefly, then built, simulated, and run on real
silicon. Every lesson is self-contained and every lesson ends with something
you can see working.

**Two ways to do every lesson.** Type Verilog in an editor, or wire blocks
together visually in [Icestudio](https://icestudio.io). The two paths describe
the same design and are checked against the same testbench — see
[Choosing your path](#choosing-your-path).

---

## Quick start

```bash
git clone <this repo> && cd ULX3S
tools/install.sh          # downloads the toolchain into ./toolchain (gitignored)
make check                # verifies every tool, then simulates lesson 00
cd 00-blinky && make sim  # must print PASS
```

Then open `00-blinky/README.md` and start reading, and keep
[`CHEATSHEET.md`](CHEATSHEET.md) to hand for the commands. With the board
plugged in, from the project root:

```bash
make deploy L=0   # build lesson 00, load it, LEDs count up as a binary odometer
make list         # which lesson is which number
```

`L` is the lesson number, so there is no need to change directory. Every verb
works this way: `make sim L=5`, `make wave L=3`, `make synth L=2`.

Nothing is installed system-wide and nothing needs `sudo`. Deleting
`toolchain/` undoes the entire install.

## Curriculum

| # | Lesson | Concept | Deliverable | Paths |
|---|--------|---------|-------------|-------|
| 00 | [blinky](00-blinky/) | clock division, counters, the whole toolchain | LEDs as a binary odometer · **board** | editor + visual |
| 01 | [gates](01-gates/) | AND/OR/NOT/NAND/NOR/XOR — and why an FPGA has none of them | every gate, exhaustively verified, plus NAND-only equivalents | editor + visual |
| 02 | [combinational](02-combinational/) | muxes, decoders, adders; truth tables as tests | 7-segment hex decoder + 4-bit adder | editor + visual |
| 03 | [sequential](03-sequential/) | D-flip-flops, registers, shift registers, debounce | a button that reliably counts once · **board** | editor + visual |
| 04 | [clocks](04-clocks/) | setup/hold, critical paths, PLLs, clock domains, metastability | a PLL, a deliberate timing failure, a safe domain crossing · **board** | editor |
| 05 | [fsm](05-fsm/) | Moore vs Mealy, state encoding, one-hot | traffic light + button-sequence lock · **board** | editor + visual |
| 06 | [spi-oled](06-spi-oled/) | an FSM that talks to a real chip on its terms | SSD1331 brought up, gradient drawn · **board** | editor + visual |
| 07 | [font-rom](07-font-rom/) | ROM lookup and coordinate math, with no framebuffer | "HELLO" on the OLED · **board** | editor |
| 08 | [memory](08-memory/) | BRAM inference, `$readmemh`, dual-port, framebuffers | the memory the CPU will use · **board** | editor |
| 09 | [uart](09-uart/) | serial framing, oversampling, baud generation | TX, RX, loopback, echo to your terminal · **board** | editor + visual |
| 10 | [alu](10-alu/) | 32-bit arithmetic, overflow, signed compare, shifts | the RV32I ALU, randomised against a model | editor |
| 11 | [regfile](11-regfile/) | 2-read/1-write arrays, x0, write-read bypass | 32×32 register file | editor |
| 12 | [datapath](12-datapath/) | instruction formats, immediate generation, control | a decoder for all of RV32I | editor |
| 13 | [rv32i-single](13-rv32i-single/) | fetch-decode-execute in one cycle | a CPU running hand-written assembly · **board** | editor |
| 14 | [formal](14-formal/) | bounded model checking, `riscv-formal` | a *proof* the core implements RV32I | editor |
| 15 | [soc](15-soc/) | memory maps, peripherals, linker scripts, crt0 | your CPU running compiled C · **board** | editor |
| 16 | [rv32i-pipeline](16-rv32i-pipeline/) | pipelining, hazards, forwarding, stalls | 5-stage core, same programs, faster clock · **board** | editor |
| 17 | [extensions](17-extensions/) | CSRs, traps, timer interrupts, the M extension | interrupts and hardware multiply · **board** | editor |

Lessons marked **board** want hardware to be satisfying; everything is still
verified in simulation first. Lessons 00–14 can be completed with no board at
all. Lesson 17 is optional — the course's goal is met at lesson 16.

Eleven lessons are written and working today — 00 through 10 — each with a
self-checking testbench and real, measured synthesis numbers. The rest have
settled scope and a planned outline in their README, and are being built in
order.

## Choosing your path

Both paths are first-class, and you can switch at any lesson.

**Editor path — VS Code (or any editor) + `make`.** You write Verilog. This is
the path that scales: by lesson 10 a design is thousands of gates and text is
the only sane way to express it.

```bash
cd 02-combinational
make sim      # iverilog: run the testbench, expect PASS
make wave     # gtkwave: look at the waveform
make graph    # yosys + graphviz: see your code as a schematic (SVG)
make lint     # verilator -Wall: catch latches and width mistakes
make synth    # how many LUTs and flip-flops did that cost?
make bit      # place & route into a real bitstream
make prog     # load it onto the board
```

Run `tools/code.sh` to launch VS Code with the toolchain on `PATH` — the
Verilog extension needs that to lint, and launching from the Dock does not
provide it. Recommended extensions are in `.vscode/extensions.json` and
`Cmd+Shift+B` runs the current lesson's simulation.

**Visual path — Icestudio.** You drag blocks onto a canvas and wire them up.
This is the better way to *see* structure — a mux really does look like a mux —
and it is excellent through lesson 09. Each dual-path lesson ships a project:

```bash
open 00-blinky/icestudio/blink.ice      # or File > Open in Icestudio
```

Icestudio is already configured for the ULX3S-85F here, so Build and Upload
work with no further setup.

**The two paths are kept honest about each other.** An Icestudio `.ice` project
is generated from the lesson's real Verilog by `tools/mkice.py`, which lifts
the module body into a code block and binds the ports to actual ECP5 balls. So
the diagram you wire up and the file you'd type are the same design, not two
drifting copies. Going the other way, `make graph` renders your Verilog as a
schematic — the picture and the text are two views of one thing, which is the
single most useful idea in this whole course.

Beyond lesson 09 the lessons are editor-only, and that is itself a lesson:
schematic entry stops scaling somewhere around a 32-bit datapath. Icestudio
stays useful at the top level, for wiring a finished core to pins.

## Repository layout

```
00-blinky/ … 17-extensions/   one directory per lesson, in order
  README.md                   the lesson: concept, build, what to look for
  *.v                         synthesisable source
  tb_*.v                      testbench — always prints PASS or FAIL
  Makefile                    4 lines; the rules live in common/lesson.mk
  solutions/                  worked answers, where an exercise needs one
  icestudio/                  .json spec + generated .ice (dual-path lessons)
  diagrams/                   *.wave.json timing diagram sources

common/
  lesson.mk                   every build rule, documented, shared by all
  ulx3s_v20.lpf               ECP5 pin constraints for the ULX3S v2.0 board
  rtl/                        modules promoted from lessons once the CPU needs
                              them (empty until lesson 10 — see its README)
docs/
  book.toml, src/             mdBook site built from the lesson READMEs
  diagrams/                   hand-authored SVG (block diagrams, datapaths)
tools/
  install.sh                  one-command setup on a fresh machine
  check.sh                    verify the toolchain, smoke-test lesson 00
  code.sh                     launch VS Code with the toolchain on PATH
  mkice.py                    generate Icestudio projects from Verilog
  mkwave.sh                   render WaveDrom timing diagrams to SVG
  mkdocs.sh                   build the lesson book
toolchain/                    oss-cad-suite (downloaded, gitignored, ~1 GB)
```

## Course-wide commands

```bash
make check       # is the toolchain healthy?
make sim-all     # every lesson's testbench — the regression suite
make lint-all    # verilator across every lesson
make graph-all   # render every lesson as a schematic
make ice         # regenerate Icestudio projects from their specs
make docs        # build the book into docs/book/
make docs-serve  # read it at http://localhost:3000
```

## Rules of the road

These are the conventions every lesson follows, and they are most of what
makes the difference between a design that works and one that nearly works.

1. **Simulate first.** Nothing goes near synthesis until the testbench passes.
   The waveform is the truth; read it in gtkwave.
2. **Every testbench prints `PASS` or `FAIL`.** No eyeballing-only tests. A
   test you have to interpret is a test you will misinterpret at 1 a.m.
3. **One concept per lesson.** Finish it, verify it, commit it, move on.
4. **`make sim-all` stays green.** A later lesson must never break an earlier
   one; the whole course is a regression suite.
5. **Synchronous design, one clock.** Everything is clocked by `clk_25mhz`.
   No gated clocks, no latches, no asynchronous resets unless a lesson is
   explicitly about them.
6. **Reusable blocks are parameterised and default to 32 bits.** The end goal
   is a 32-bit CPU, so a mux, an adder or a register defaults to the width the
   CPU needs, and a teaching testbench narrows it to 4 bits where sweeping
   every input is worth more than realism. Default to the width you mean;
   narrow to the width you can prove.
7. **Read the resource report.** `make synth` tells you what your abstraction
   actually cost in LUTs and flip-flops. Look at it every time.

## Toolchain

Everything is open source, and `tools/install.sh` fetches it all:

| Tool | Job |
|---|---|
| [Icarus Verilog](https://steveicarus.github.io/iverilog/) | simulation (`make sim`) |
| [Verilator](https://verilator.org) | strict linting (`make lint`) |
| [GTKWave](https://gtkwave.sourceforge.net) | waveform viewing (`make wave`) |
| [Yosys](https://yosyshq.net/yosys/) | synthesis and schematics |
| [nextpnr](https://github.com/YosysHQ/nextpnr) + [prjtrellis](https://github.com/YosysHQ/prjtrellis) | ECP5 place & route, bitstream |
| [openFPGALoader](https://github.com/trabucayre/openFPGALoader) | programming the board |
| [SymbiYosys](https://github.com/YosysHQ/sby) | formal verification (lesson 14) |
| [Icestudio](https://icestudio.io) | the visual path |

## Hardware

A **ULX3S 85F** — Lattice ECP5 `LFE5U-85F-6BG381C`, 25 MHz clock, 8 LEDs,
7 buttons, 4 slide switches, an SSD1331 colour OLED, FTDI USB-serial, SDRAM and
an SD slot. Lessons 00–14 need no board at all; lessons 03, 06, 07, 09, 13 and 15
are much more satisfying with one. Pin names come from `common/ulx3s_v20.lpf`.

## Contributing a lesson

`docs/LESSON_TEMPLATE.md` is the shape every lesson follows, and
`docs/src/reference-style.md` covers the Verilog and diagram conventions. The short version:
a lesson is not done until `make sim` prints PASS, `make lint` is quiet,
`make sim-all` is still green, and the README explains *why* the design is
shaped the way it is — not just what the code says.

## Licence

Course text and code: see `LICENSE`. The ULX3S pin constraint file comes from
the [ULX3S project](https://github.com/emard/ulx3s).
