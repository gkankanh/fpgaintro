# ===========================================================================
#  common/lesson.mk — shared build rules for every lesson in this course.
#
#  A lesson's Makefile declares what is different and includes this file:
#
#      TOP = blink          # synthesisable top module, in $(TOP).v
#      TB  = tb_blink       # testbench module, in $(TB).v
#      include ../common/lesson.mk
#
#  Optional overrides: SRCS, TB_SRCS, VCD, DEVICE, PACKAGE, BOARD.
#
#  Verbs:
#    make sim     iverilog + vvp      — run the testbench, expect PASS
#    make wave    open the VCD in gtkwave
#    make lint    verilator --lint-only -Wall  (style/width/latch warnings)
#    make graph   yosys + graphviz — render the design as a schematic (SVG)
#    make synth   yosys synth_ecp5 + stat — resource usage, no bitstream
#    make bit     yosys -> nextpnr-ecp5 -> ecppack — a flashable bitstream
#    make prog    openFPGALoader — load the bitstream into SRAM (volatile)
#    make flash   openFPGALoader -f — write it to SPI flash (survives power)
#    make clean   remove build products
# ===========================================================================

ROOT    ?= ..
TOOLS   ?= $(ROOT)/toolchain/oss-cad-suite/bin
LPF     ?= $(ROOT)/common/ulx3s_v20.lpf

SRCS    ?= $(TOP).v
TB_SRCS ?= $(TB).v
VCD     ?= $(TOP).vcd

# ULX3S 85F: Lattice ECP5 LFE5U-85F in a 381-ball caBGA.
DEVICE  ?= --85k
PACKAGE ?= CABGA381
BOARD   ?= ulx3s

# Speed grade 6 part; ask nextpnr to prove we close timing at 25 MHz.
FREQ    ?= 25

.PHONY: sim wave lint graph synth bit prog flash clean help
.DEFAULT_GOAL := help

# ---------------------------------------------------------------- simulate --
# Rule of the road #1: nothing goes near synthesis until this prints PASS.
sim: $(TB).vvp
	$(TOOLS)/vvp $(TB).vvp
	@echo "---- waveform: make wave  (gtkwave $(VCD)) ----"

$(TB).vvp: $(SRCS) $(TB_SRCS)
	$(TOOLS)/iverilog -g2005 -Wall -o $@ $(SRCS) $(TB_SRCS)

wave: $(VCD)
	$(TOOLS)/gtkwave $(VCD) $(wildcard $(TOP).gtkw) &

$(VCD): sim

# -------------------------------------------------------------------- lint --
# Verilator is stricter than iverilog: it catches implicit widths, unintended
# latches and combinational loops that simulate fine but synthesise wrong.
# Two course-wide waivers, both deliberate. Every OTHER -Wall warning is
# treated as an error, which is the point — a linter you have trained to cry
# wolf is a linter you stop reading.
#
# DECLFILENAME enforces one module per file. Right for a large project, wrong
# for a lesson: three related ten-line modules (mux2, mux4, dec) read better
# grouped in mux.v than scattered across three files.
#
# PROCASSINIT objects to `reg q = 0;` on a signal that is also assigned
# procedurally. The course does this everywhere on purpose: the ECP5 loads
# flip-flop initial values straight from the bitstream, so a register really
# does start at a known value with no reset logic at all. Verilator warns
# because not every target honours that — which is true, and is exactly why
# the lessons say so in prose (see 00-blinky/README.md) rather than pretending
# it is portable.
LINT_WAIVE ?= -Wno-DECLFILENAME -Wno-PROCASSINIT

lint:
	$(TOOLS)/verilator --lint-only -Wall $(LINT_WAIVE) --top-module $(TOP) $(SRCS)

# --------------------------------------------------------------- schematic --
# The other half of the dual path: Icestudio users draw a diagram and get
# Verilog; this renders your Verilog back into a diagram. Worth doing once per
# lesson — seeing yosys' view of your code catches misunderstandings fast.
graph: $(TOP).svg
	@echo "schematic: $(TOP).svg"

$(TOP).svg: $(SRCS)
	$(TOOLS)/yosys -p "read_verilog $(SRCS); hierarchy -top $(TOP); proc; opt_clean; \
	                   show -format dot -prefix $(TOP) -notitle $(TOP)"
	$(TOOLS)/dot -Tsvg $(TOP).dot -o $@

# ------------------------------------------------------------- synthesise ---
# "How much fabric does this cost?" — read the stat block: LUT4s, DFFs, BRAM.
synth:
	$(TOOLS)/yosys -p "read_verilog $(SRCS); synth_ecp5 -top $(TOP); stat"

# ---------------------------------------------------------- place & route ---
$(TOP).json: $(SRCS)
	$(TOOLS)/yosys -p "read_verilog $(SRCS); synth_ecp5 -top $(TOP) -json $@"

$(TOP).config: $(TOP).json $(LPF)
	$(TOOLS)/nextpnr-ecp5 $(DEVICE) --package $(PACKAGE) --freq $(FREQ) \
	    --json $(TOP).json --lpf $(LPF) --textcfg $@

$(TOP).bit: $(TOP).config
	$(TOOLS)/ecppack $< $@

bit: $(TOP).bit

# --------------------------------------------------------------- program ----
# prog  = SRAM, gone at power-off. Use this while iterating.
# flash = SPI flash, boots on power-up. Use this when the lesson is done.
prog: $(TOP).bit
	$(TOOLS)/openFPGALoader -b $(BOARD) $(TOP).bit

flash: $(TOP).bit
	$(TOOLS)/openFPGALoader -b $(BOARD) -f $(TOP).bit

clean:
	rm -f *.vvp *.vcd *.json *.config *.bit *.fst *.dot *.svg

help:
	@echo "$(TOP): make [sim|wave|lint|graph|synth|bit|prog|flash|clean]"
	@echo "  start with 'make sim' — it must print PASS before anything else."
