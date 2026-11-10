TOP      = text_top
TB       = tb_text
LPF      = ../common/ulx3s_v20.lpf
TOOLS    = ../toolchain/oss-cad-suite/bin

sim:
	$(TOOLS)/iverilog -o $(TB).vvp $(TOP).v $(TB).v
	$(TOOLS)/vvp $(TB).vvp
	@echo "waveform: gtkwave $(TOP).vcd"

synth:
	$(TOOLS)/yosys -p "read_verilog $(TOP).v; synth_ecp5 -top $(TOP); stat"

bit:
	$(TOOLS)/yosys -p "read_verilog $(TOP).v; synth_ecp5 -top $(TOP) -json $(TOP).json"
	$(TOOLS)/nextpnr-ecp5 --85k --package CABGA381 --json $(TOP).json \
	    --lpf $(LPF) --textcfg $(TOP).config
	$(TOOLS)/ecppack $(TOP).config $(TOP).bit

prog:
	$(TOOLS)/openFPGALoader -b ulx3s $(TOP).bit

clean:
	rm -f *.vvp *.vcd *.json *.config *.bit

.PHONY: sim synth bit prog clean
