# Toolchain cheat sheet

Every lesson understands the same verbs. They come from `common/lesson.mk`,
which is worth reading once — it is the whole build system, 90 commented lines.

| Verb | Tool | What it does |
|---|---|---|
| `make sim` | iverilog + vvp | compile source + testbench, run it, print PASS/FAIL |
| `make wave` | gtkwave | open the VCD this lesson produced |
| `make lint` | verilator `-Wall` | width mismatches, inferred latches, combinational loops |
| `make graph` | yosys + graphviz | render the design as an SVG schematic |
| `make synth` | yosys `synth_ecp5` | resource report: LUT4s, flip-flops, BRAM |
| `make synth M=mod` | yosys `synth_ecp5 -top mod` | the same, for one module instead of the top |
| `make bit` | yosys → nextpnr-ecp5 → ecppack | a flashable bitstream, with timing closure |
| `make prog` | openFPGALoader | load into FPGA SRAM — volatile, use while iterating |
| `make flash` | openFPGALoader `-f` | write to SPI flash — survives power cycling |
| `make clean` | | delete build products |

## Raw commands

When you want to drive the tools directly:

```bash
# simulate
iverilog -g2005 -Wall -o tb.vvp design.v tb_design.v && vvp tb.vvp

# strict lint
verilator --lint-only -Wall --top-module design design.v

# resource usage
yosys -p "read_verilog design.v; synth_ecp5 -top design; stat"

# schematic
yosys -p "read_verilog design.v; proc; opt_clean; show -format dot -prefix d design"
dot -Tsvg d.dot -o d.svg

# place & route for the ULX3S 85F
nextpnr-ecp5 --85k --package CABGA381 --freq 25 \
  --json design.json --lpf common/ulx3s_v20.lpf --textcfg design.config
ecppack design.config design.bit

# program
openFPGALoader -b ulx3s design.bit        # SRAM
openFPGALoader -b ulx3s -f design.bit     # SPI flash
```

## Reading a yosys `stat` block

```
   Number of cells:   34
     LUT4              18     combinational logic, 4 inputs each
     TRELLIS_FF        26     flip-flops
     DP16KD             1     an 18 Kbit dual-port block RAM
     MULT18X18D         0     hardware multiplier
```

The 85F has 83,640 LUTs, 83,640 flip-flops and 208 block RAMs — so a lesson
using 34 cells is using about 0.04% of the part. Knowing roughly what things
cost is the point: a 32-bit adder is ~32 LUTs, a 32×32 register file built from
flip-flops is ~1,024 of them (which is why lesson 11 weighs distributed RAM
against block RAM instead).

## Reproducing the numbers in the lessons

Every resource count and frequency in this course came from the commands
printed beside it, on this setup. A different toolchain release can move a LUT4
count by a few percent; a different device or speed grade moves the
frequencies.

| | |
|---|---|
| board | Radiona ULX3S, `common/ulx3s_v20.lpf` (board revisions v2.x.x and v3.0.x) |
| device | Lattice ECP5 `LFE5U-85F-6BG381C` — 85F, **speed grade 6**, CABGA381, commercial |
| clock | 25 MHz from the board crystal, constrained in the `.lpf` |
| place & route | `nextpnr-ecp5 --85k --package CABGA381 --freq 25` |
| toolchain | OSS CAD Suite release `2026-11-10` |
| synthesis | Yosys 0.70+368 (`7cf88aca6`), `synth_ecp5` |
| p&r | nextpnr 0.11.1-89 (`445e2a65`) |
| bitstream | Project Trellis `ecppack` 1.4-88 |
| simulation | Icarus Verilog 14.0 (devel) |
| linting | Verilator 5.055 devel |

Resource counts come from `make synth` (`synth_ecp5` + `stat`), not from a
placed design. Frequencies come from `make bit`, where nextpnr reports the
routed design's maximum frequency per clock.

## Which simulator when

- **iverilog** — the default. Fast to start, forgiving, good `$display`.
- **verilator** — much faster for long runs, but compiles to C++ and is strict
  about things iverilog tolerates. Lessons 11+ use it where simulations get
  long.
- **sby** (SymbiYosys) — not a simulator at all. Proves properties over *all*
  inputs up to a bound, instead of the handful your testbench thought of.
  Lesson 14.
