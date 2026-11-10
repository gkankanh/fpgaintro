# ULX3S — FPGA Learning Project

Pure gateware. Target: Radiona ULX3S (Lattice ECP5, open toolchain).
Every stage is self-contained: sources, a testbench, and a Makefile with
three verbs — `make sim` (iverilog + gtkwave), `make synth` (yosys sanity
check), `make bit` (nextpnr-ecp5 place & route → bitstream), plus
`make prog` where hardware applies.

Toolchain: `toolchain/oss-cad-suite/` (yosys, nextpnr-ecp5, prjtrellis,
iverilog, openFPGALoader). Activate per shell:

    source toolchain/oss-cad-suite/environment

## Rules of the road

1. **Simulate first.** Nothing goes near synthesis until the testbench
   passes. The waveform is the truth; read it in gtkwave.
2. **One concept per stage.** Finish, verify, commit, move on.
3. Every testbench ends with an explicit `PASS` / `FAIL` print —
   no eyeballing-only tests.

## Curriculum

| stage | topic | deliverable |
|---|---|---|
| 00 | Toolchain smoke test | blinky: sim waveform + synth report |
| 01 | Combinational logic | gates → mux → 7-segment decoder |
| 02 | Sequential logic | D-FF, clock dividers, counters |
| 03 | Registers & buses | tristate-style shared bus + register file (the '245 world, in HDL) |
| 04 | FSMs | UART TX, then RX, loopback tested |
| 05 | Memories | BRAM inference, ROM init files |
| 06 | SAP-1 CPU | the Ben Eater CPU in Verilog, reusing BCE's architecture as spec |
| 07 | Real hardware | buttons/LEDs, then DVI out on the ULX3S |

Stages 00–06 run entirely in simulation; no board required until 07.

## Layout

    stage00-blinky/     blink.v  tb_blink.v  Makefile
    stage01-comb/       ...
    common/             ulx3s_v20.lpf (pin constraints), makefile fragments
    toolchain/          oss-cad-suite (gitignored)
