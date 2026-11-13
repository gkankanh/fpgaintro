#import "../style.typ": *

= Driving the tools directly

The `make` verbs are thin wrappers. When you want the tools themselves:

```bash
# simulate
iverilog -g2005 -Wall -o tb.vvp design.v tb_design.v && vvp tb.vvp

# strict lint
verilator --lint-only -Wall --top-module design design.v

# resource usage
yosys -p "read_verilog design.v; synth_ecp5 -top design; stat"

# resource usage at a different parameter value
yosys -p "read_verilog design.v; chparam -set W 32 design; \
          synth_ecp5 -top design; stat"

# schematic
yosys -p "read_verilog design.v; proc; opt_clean; \
          show -format dot -prefix d design"
dot -Tsvg d.dot -o d.svg

# place and route for the ULX3S 85F
nextpnr-ecp5 --85k --package CABGA381 --freq 25 \
  --json design.json --lpf common/ulx3s_v20.lpf --textcfg design.config
ecppack design.config design.bit

# program
openFPGALoader -b ulx3s design.bit        # SRAM
openFPGALoader -b ulx3s -f design.bit     # SPI flash
openFPGALoader --detect -b ulx3s          # is the board there?

# PLL parameters
ecppll -i 25 -o 100 --clkout1 40 -f pll.v
```

== Reading a resource report

```
   LUT4              18     combinational logic, 4 inputs each
   TRELLIS_FF        26     flip-flops
   CCU2C             13     carry chain cells — TWO BITS EACH
   DP16KD             1     an 18 Kbit dual-port block RAM
   TRELLIS_DPR16X4    8     distributed RAM: 16 words x 4 bits, from LUTs
   PFUMX / L6MUX21    4     wide multiplexers, for functions over 4 inputs
   MULT18X18D         0     a hardware multiplier
```

The 85F has 83,640 LUTs, 83,640 flip-flops and 208 block RAMs, so a design
using 34 cells is using about 0.04% of the part. Knowing roughly what things
cost is the point: a 32-bit adder is 17 carry cells, a 32-bit barrel shifter
about 667 LUTs, and a whole RISC-V CPU about 1,765.

== Which simulator when

#ttable(
  columns: (auto, 1fr),
  [#strong[iverilog]], [the default. Fast to start, forgiving, good `$display`.],
  [#strong[Verilator]], [much faster for long runs, but compiles to C++ and is
    strict about things iverilog tolerates. Used here mainly as a linter.],
  [#strong[sby]], [not a simulator at all. Proves properties over #emph[all]
    inputs up to a bound, instead of the handful your testbench thought of.
    Lesson 14.],
)

== Tools written for this course

#ttable(
  columns: (auto, 1fr),
  [`tools/install.sh`],    [set up a machine; no sudo, nothing system-wide],
  [`tools/check.sh`],      [verify every tool runs, then smoke-test lesson 00],
  [`tools/code.sh`],       [launch VS Code with the toolchain on `PATH`],
  [`tools/rvasm.py`],      [an RV32I assembler — labels, pseudo-instructions, `--list`],
  [`tools/check-asm.sh`],  [cross-validate that assembler against GNU `as`],
  [`tools/bin2hex.py`],    [an ELF's `.bin` into the `$readmemh` image a lesson's memory loads],
  [`tools/mkice.py`],      [generate Icestudio projects from lesson Verilog],
  [`tools/icecheck.py`],   [rebuild and compile-check a generated .ice project],
  [`tools/mktasks.py`],    [regenerate the editor's per-lesson tasks],
  [`tools/mkwave.sh`],     [render WaveDrom timing diagrams to SVG],
  [`tools/svg-flatten.py`],[resolve CSS variables so diagrams print],
  [`tools/mkdocs.sh`],     [build the HTML lessons],
  [`tools/mkpdf.sh`],      [build both books],
)

== Reproducing the numbers in the course book

Every resource count and every frequency in the course book was produced by the
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

Resource numbers come from `make synth`, which runs `synth_ecp5` and `stat` —
not from a placed design, so they do not include board wiring unless the quoted
module is the lesson's top. Frequencies come from `make bit`, where nextpnr
reports the routed design's maximum frequency for each clock.

A measured number without its conditions is an anecdote. If your own
`make synth` disagrees with the book by a cell or two, the likely reason is a
newer OSS CAD Suite — which is the right thing to trust, since it is the one
that built your bitstream.
