# Lesson 04 — clocks and timing. See README.md.
#
# This is the first lesson where what you simulate and what you synthesise are
# not the same set of files.
#
# pll.v instantiates EHXPLLL, a hard analogue block. iverilog has no model for
# it and verilator has no definition, so neither tool can process it. The PLL
# is therefore verified structurally — it synthesises, and nextpnr reports the
# frequencies it closed timing at — and on hardware, via `locked` and the LEDs.
#
# FREQ is 100, not the usual 25: the top module runs logic in the PLL's 100 MHz
# domain, and asking nextpnr to close timing there is the whole point.
TOP       = clocks_top
SRCS      = pll.v cdc.v slow_path.v clocks_top.v
SIM_SRCS  = cdc.v slow_path.v
LINT_TOP  = cdc_bus
TB        = tb_clocks
VCD       = clocks.vcd
FREQ      = 100
include ../common/lesson.mk
