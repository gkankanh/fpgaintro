# Lesson 16 — pipelining. See README.md.
#
# The ALU, register file, decoder, immediate generator, branch comparator and
# load/store aligners all come from earlier lessons, unchanged. This lesson
# adds the pipeline registers, the forwarding network, the hazard logic and a
# memory that can finally be a block RAM.
#
# THIS LESSON SIMULATES AND SYNTHESISES DIFFERENT FILE SETS, for the reason
# lesson 04 met first: soc5_top instantiates the PLL, and EHXPLLL is a hard
# analogue block that iverilog cannot model and verilator cannot parse. So the
# board top is verified structurally -- it synthesises, and nextpnr closes
# timing on it at 40 MHz -- while everything with behaviour in it is simulated.
#
# FREQ is 40, not the usual 25, because that is the clock the pipeline exists
# to make possible and asking nextpnr to prove it is the whole point.
TOP  = soc5_top
SRCS = ../04-clocks/pll.v ../common/rtl/adder.v ../10-alu/alu.v ../11-regfile/regfile.v \
       ../12-datapath/immgen.v ../12-datapath/decode.v \
       ../13-rv32i-single/branch_unit.v ../13-rv32i-single/memaccess.v \
       ../09-uart/uart_tx.v ../09-uart/uart_rx.v \
       ../15-soc/busdec.v ../15-soc/mmio.v \
       cpu5.v memory_sync.v cpu5_sys.v soc5.v soc5_top.v

# Everything with behaviour: the board top and the PLL are left out.
SIM_SRCS = ../common/rtl/adder.v ../10-alu/alu.v ../11-regfile/regfile.v \
       ../12-datapath/immgen.v ../12-datapath/decode.v \
       ../13-rv32i-single/branch_unit.v ../13-rv32i-single/memaccess.v \
       ../09-uart/uart_tx.v ../09-uart/uart_rx.v \
       ../15-soc/busdec.v ../15-soc/mmio.v \
       cpu5.v memory_sync.v cpu5_sys.v soc5.v
LINT_TOP = soc5
TB   = tb_pipe
VCD  = pipe.vcd
FREQ = 40

include ../common/lesson.mk
