# Run all three solution testbenches.
TOOLS = ../../toolchain/oss-cad-suite/bin
SOLS  = ex1_xnor_from_nand ex3_bitwise_vs_logical ex4_lut_boundary

all: $(SOLS)

# ex4 keeps its testbench in a separate file so yosys can read the design
# without executing the testbench's $$finish; the others are self-contained.
$(SOLS):
	@echo "=== $@ ==="
	@$(TOOLS)/iverilog -g2005 -Wall -o $@.vvp $@.v $(wildcard tb_$@.v)
	@$(TOOLS)/vvp $@.vvp

clean:
	rm -f *.vvp *.vcd

.PHONY: all clean $(SOLS)
