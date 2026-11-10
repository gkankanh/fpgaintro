# Digital Design on the ULX3S

A hands-on refresher in digital design, worked from a single flip-flop to a
32-bit RISC-V CPU running compiled C, on a Radiona **ULX3S 85F** (Lattice ECP5
`LFE5U-85F-6BG381C`) with a fully open toolchain.

## Who this is for

Someone who studied logic design once — perhaps a long time ago — and wants the
ideas back in their hands rather than back in their head. So the concepts are
stated briefly and then *built*: simulated, inspected in a waveform viewer,
synthesised, and run on real silicon.

It assumes you know what a gate, a register and a clock are. It does not assume
you remember what a blocking assignment does to a shift register, or why your
counter synthesised into a latch.

## How a lesson works

Every lesson is a directory containing its own source, its own testbench, its
own Makefile and its own README. Each one follows the same arc:

1. **The idea** — a paragraph or two, and a picture.
2. **The design** — the Verilog, with the decisions explained.
3. **Simulate** — `make sim`, which prints `PASS` or `FAIL`, never a shrug.
4. **Look at it** — the waveform, and the schematic yosys inferred.
5. **What it cost** — LUTs and flip-flops from `make synth`.
6. **On the board** — where hardware applies.
7. **Exercises** — small changes that break it in instructive ways.

## Two paths

You can type Verilog, or you can wire blocks together in Icestudio. Both are
supported, both are checked against the same testbench, and you can switch
whenever you like. [Choosing your path](./paths.md) explains the trade-off and
where the visual path stops being the right tool.

## The end goal

A working RV32I core. Not a toy: a core that passes a formal proof of
instruction-set conformance, runs C compiled by a standard RISC-V GCC, prints
to your terminal over UART and draws on the OLED. Then the same core again,
pipelined, to see what pipelining really costs in hazard logic.

Everything in between exists because the CPU needs it. The register file in
lesson 11 is the CPU's register file. The UART in lesson 09 is how the CPU will
say hello. Nothing is busywork.
