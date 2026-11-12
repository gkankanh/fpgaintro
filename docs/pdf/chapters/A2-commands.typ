#import "../style.typ": *

= Appendix B — Command reference

== Per-lesson verbs

From inside a lesson directory, or from the project root with `L=<number>`:

#ttable(
  columns: (auto, auto, 1fr),
  [*verb*], [*tool*], [*what it does*],
  [`sim`],   [iverilog + vvp], [compile source and testbench, run it, print PASS or FAIL],
  [`wave`],  [GTKWave], [open the VCD this lesson produced],
  [`lint`],  [Verilator `-Wall`], [width mismatches, inferred latches, multiple drivers],
  [`graph`], [yosys + graphviz], [render the design as an SVG schematic],
  [`synth`], [yosys `synth_ecp5`], [resource report: LUT4s, flip-flops, block RAM, carry],
  [`synth M=mod`], [yosys `synth_ecp5 -top mod`], [the same report for one module instead of the top],
  [`bit`],   [yosys → nextpnr → ecppack], [a bitstream, with timing closure],
  [`prog`],  [openFPGALoader], [load into FPGA SRAM — volatile, for iterating],
  [`flash`], [openFPGALoader `-f`], [write to SPI flash — survives power-off],
  [`clean`], [], [delete build products],
)

== From the project root

```bash
make list              # which lesson is which number
make deploy L=0        # build lesson 00 and load it onto the board
make sim    L=5        # simulate lesson 05
make wave   L=3        # open lesson 03's waveform
```

#ttable(
  columns: (auto, 1fr),
  [`make check`],    [verify the toolchain and smoke-test lesson 00],
  [`make sim-all`],  [every lesson's testbench — the regression suite],
  [`make lint-all`], [Verilator across every lesson],
  [`make graph-all`],[render every lesson as a schematic],
  [`make ice`],      [regenerate the Icestudio projects from their specs],
  [`make tasks`],    [regenerate the editor's per-lesson task list],
  [`make docs`],     [build the HTML version of the lessons],
  [`make pdf`],      [build this book],
  [`make clean-all`],[remove build products everywhere],
)

== Driving the tools directly

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
cost is the point: a 32-bit adder is 17 carry cells, a 32-bit barrel shifter is
about 667 LUTs, and a whole RISC-V CPU is about 1,765.

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
  [`tools/mkice.py`],      [generate Icestudio projects from lesson Verilog],
  [`tools/mktasks.py`],    [regenerate the editor's per-lesson tasks],
  [`tools/mkwave.sh`],     [render WaveDrom timing diagrams to SVG],
  [`tools/svg-flatten.py`],[resolve CSS variables so diagrams print],
  [`tools/mkdocs.sh`],     [build the HTML lessons],
  [`tools/mkpdf.sh`],      [build this book],
)
