# Lesson 13 — single-cycle RV32I. See README.md.
#
# The ALU, register file, decoder and immediate generator come from
# common/rtl/ and the lessons that built them. This lesson adds the branch
# comparator, the load/store aligners, the PC logic and the memories.
#
# test.hex is assembled from test.s by tools/rvasm.py. It is read by
# $readmemh at elaboration time, so it is a source file: `make prog-asm`
# after editing test.s, then rebuild.
TOP  = cpu_top
SRCS = ../common/rtl/adder.v ../10-alu/alu.v ../11-regfile/regfile.v \
       ../12-datapath/immgen.v ../12-datapath/decode.v \
       branch_unit.v memaccess.v cpu.v cpu_sys.v cpu_top.v
TB   = tb_cpu
VCD  = cpu.vcd

include ../common/lesson.mk

# Reassemble the test program.
prog-asm:
	python3 ../tools/rvasm.py test.s -o test.hex
	python3 ../tools/rvasm.py test.s --list | head -30

# Cross-validate our assembler against GNU as, when it is installed.
check-asm:
	@../tools/check-asm.sh test.s

.PHONY: prog-asm check-asm
