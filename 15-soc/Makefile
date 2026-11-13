# Lesson 15 — a system on chip. See README.md.
#
# The core is lesson 13's, not one line changed, and the UART is lesson 09's.
# This lesson adds the memory, the address decoder, the peripherals and the
# software: everything that turns a CPU into a computer.
#
# firmware.hex is compiled from sw/ by `make firmware` and READ AT
# ELABORATION by $readmemh, so it is a source file rather than a build
# product -- which is why it is checked in and why `clean` leaves it alone. A
# reader with no RISC-V compiler can still run sim, synth and bit; they just
# cannot change the program.
TOP  = soc_top
SRCS = ../common/rtl/adder.v ../10-alu/alu.v ../11-regfile/regfile.v \
       ../12-datapath/immgen.v ../12-datapath/decode.v \
       ../13-rv32i-single/branch_unit.v ../13-rv32i-single/memaccess.v \
       ../13-rv32i-single/cpu.v \
       ../09-uart/uart_tx.v ../09-uart/uart_rx.v \
       memory.v busdec.v mmio.v soc.v soc_top.v
TB   = tb_soc
VCD  = soc.vcd

DATA = firmware.hex

include ../common/lesson.mk

# ---------------------------------------------------------------- software --
# The toolchain path, one arrow per step:
#
#     riscv64-elf-gcc      sw/crt0.S sw/main.c  ->  firmware.elf
#     riscv64-elf-objcopy  firmware.elf         ->  firmware.bin
#     tools/bin2hex.py     firmware.bin         ->  firmware.hex
#
# WHY THE FLAGS ARE WHAT THEY ARE:
#   -march=rv32i   exactly the instruction set lessons 10-13 built. No M, so
#                  no hardware multiply: gcc calls libgcc's __mulsi3 instead,
#                  and lesson 17 is where that changes.
#   -mabi=ilp32    32-bit int, long and pointer; no hardware floating point.
#   -mno-relax     linker relaxation rewrites address calculations to be
#                  gp-relative. Nothing here sets up gp, so it must not.
#   -ffreestanding there is no hosted C library and no operating system, so
#   -fno-builtin   gcc may not assume that `puts` or `memcpy` mean what they
#                  mean on Linux, nor call a library that is not there.
#   -nostdlib      link nothing automatically, not even a crt0 -- ours is in sw/.
#   -lgcc          except libgcc, which holds what the hardware cannot do:
#                  the multiply and divide that RV32I does not have.
RVPREFIX ?= riscv64-elf-
RVCC      = $(RVPREFIX)gcc
RVCFLAGS  = -march=rv32i -mabi=ilp32 -mno-relax -Os -ffreestanding -fno-builtin \
            -Wall -Wextra
RVLDFLAGS = -nostdlib -nostartfiles -Wl,--no-warn-rwx-segments -T sw/link.ld
MEM_WORDS = 512

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

# Where the program went. .bss costs nothing in the image and everything in
# RAM, which is the whole reason the two sections are different.
size:
	@$(RVPREFIX)size sw/firmware.elf
	@echo "memory: $(MEM_WORDS) words"

# The program as the CPU sees it. Worth doing once: every instruction in here
# is one your decoder from lesson 12 has to recognise.
dis:
	@$(RVPREFIX)objdump -d -M numeric,no-aliases sw/firmware.elf

# Talk to the board after `make prog`.
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
