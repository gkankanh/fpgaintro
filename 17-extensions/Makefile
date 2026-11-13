# Lesson 17 — CSRs, traps, interrupts and the M extension. See README.md.
#
# The core is lesson 16's pipeline with privileged state added; the honest
# way to read it is `diff cpu5t.v ../16-rv32i-pipeline/cpu5.v`. Everything
# else is reused: the ALU, register file and decoders from lessons 10-12, the
# address decoder and peripherals from lesson 15, the block-RAM memory from
# lesson 16, and the PLL from lesson 04.
#
# As in lesson 16, what is simulated and what is synthesised differ: the board
# top instantiates a PLL, and EHXPLLL has no simulation model.
#
# FREQ is 36, not lesson 16's 40: this core does not close timing at 40, and
# pll36.v records the three-seed measurement that says so.
TOP  = soc17_top
SRCS = pll36.v \
       ../common/rtl/adder.v ../10-alu/alu.v ../11-regfile/regfile.v \
       ../12-datapath/immgen.v ../12-datapath/decode.v \
       ../13-rv32i-single/branch_unit.v ../13-rv32i-single/memaccess.v \
       ../09-uart/uart_tx.v ../09-uart/uart_rx.v \
       ../15-soc/busdec.v ../15-soc/mmio.v \
       ../16-rv32i-pipeline/memory_sync.v \
       decode_ext.v csr.v muldiv.v cpu5t.v cpu5t_sys.v timer.v soc17.v soc17_top.v

SIM_SRCS = ../common/rtl/adder.v ../10-alu/alu.v ../11-regfile/regfile.v \
       ../12-datapath/immgen.v ../12-datapath/decode.v \
       ../13-rv32i-single/branch_unit.v ../13-rv32i-single/memaccess.v \
       ../09-uart/uart_tx.v ../09-uart/uart_rx.v \
       ../15-soc/busdec.v ../15-soc/mmio.v \
       ../16-rv32i-pipeline/memory_sync.v \
       decode_ext.v csr.v muldiv.v cpu5t.v cpu5t_sys.v timer.v soc17.v

LINT_TOP = soc17
TB   = tb_traps
VCD  = traps.vcd
FREQ = 36

DATA = firmware.hex ../13-rv32i-single/test.hex

include ../common/lesson.mk

# ---------------------------------------------------------------- software --
# ONE FLAG IS DIFFERENT FROM LESSON 15, and it carries two extensions:
#
#     -march=rv32i          a * b  becomes  call __mulsi3  (a loop, in libgcc)
#     -march=rv32im         a * b  becomes  mul a0, a0, a1 (one instruction)
#     -march=rv32im_zicsr   ...and `csrr` assembles at all
#
# ZICSR IS WHY THE MARCH STRING LOOKS ODD. The CSR instructions were part of
# the RISC-V base integer ISA until 2019, when they were split out into their
# own extension named Zicsr -- because a core that needs no privileged state
# should not have to implement six instructions to be called RV32I. Ratifying
# that split made every existing -march=rv32i assembler reject `csrr`, which
# is exactly the error you get without it. The hardware in this lesson does
# not care: decode_ext.v would have decoded them under any name.
#
# Run `make dis` after changing the flag and look at what happened to main().
RVPREFIX ?= riscv64-elf-
RVCC      = $(RVPREFIX)gcc
RVCFLAGS  = -march=rv32im_zicsr -mabi=ilp32 -mno-relax -Os -ffreestanding -fno-builtin \
            -Wall -Wextra
RVLDFLAGS = -nostdlib -nostartfiles -Wl,--no-warn-rwx-segments -T sw/link.ld
MEM_WORDS = 4096

.PHONY: firmware size dis console

firmware:
	@command -v $(RVCC) >/dev/null || { \
	  echo "$(RVCC) not found. Install it:"; \
	  echo "    brew install riscv64-elf-gcc            # macOS"; \
	  echo "    apt install gcc-riscv64-unknown-elf     # Debian/Ubuntu"; \
	  echo "firmware.hex is checked in, so sim and synth still work."; \
	  exit 1; }
	$(RVCC) $(RVCFLAGS) $(RVLDFLAGS) -o sw/firmware.elf sw/crt0.S sw/main.c -lgcc
	$(RVPREFIX)objcopy -O binary sw/firmware.elf sw/firmware.bin
	python3 ../tools/bin2hex.py sw/firmware.bin -o firmware.hex --words $(MEM_WORDS)
	@$(MAKE) -s size

size:
	@$(RVPREFIX)size sw/firmware.elf
	@echo "memory: $(MEM_WORDS) words"

# Worth doing twice: once as shipped, once after changing rv32im to rv32i in
# RVCFLAGS above. The trap handler's prologue is the other thing to look at.
dis:
	@$(RVPREFIX)objdump -d -M numeric,no-aliases sw/firmware.elf

# Two things about this that cost an evening if you meet them the hard way.
#
# USE /dev/cu.*, NOT /dev/tty.*  On macOS the tty device blocks on open until
# carrier detect is asserted, which an FTDI cable never does.
#
# QUIT THE CONSOLE BEFORE `make prog`.  The ULX3S puts JTAG and this UART on
# one FT231X, so openFPGALoader cannot claim the chip while a terminal holds
# the port: it fails with "unable to claim usb device".
console:
	@echo "115200 baud, 8N1."
	@echo "  macOS:  screen /dev/cu.usbserial-* 115200    (quit: ctrl-a k y)"
	@echo "  Linux:  picocom -b 115200 /dev/ttyUSB0       (quit: ctrl-a ctrl-x)"
	@echo ""
	@echo "The program greets you once per reset and then blocks in getchar(),"
	@echo "so with the console open press FIRE1 (btn[1]) to run it again, and"
	@echo "type a character when it asks for one."
	@echo ""
	@echo "Serial ports present:"
	@found=; for p in /dev/cu.usbserial-* /dev/ttyUSB*; do \
	  [ -e "$$p" ] && { echo "  $$p"; found=1; }; \
	done; [ -n "$$found" ] || echo "  (none -- is the board plugged in?)"
