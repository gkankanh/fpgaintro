# ===========================================================================
#  crt0.S — what must happen before main(), on a machine with no operating
#  system and no C library.
#
#  Every C program you have ever run started like this. On Linux the file is
#  called crt1.o, it is linked in silently, and it is about four hundred lines
#  because it has an operating system to talk to. Here it is twenty
#  instructions and you can read all of them, which is the point of showing
#  it.
#
#  C's rules say that by the time main() runs:
#
#    1. there is a stack, and `sp` points at it
#    2. every object with static storage duration and no initialiser is zero
#       -- that is the .bss section, and the standard REQUIRES it
#    3. every initialised static object holds its initialiser -- that is .data
#
#  This file does 1 and 2. Point 3 is already true before the first
#  instruction executes, and the reason is worth a paragraph.
#
#  WHY THERE IS NO .data COPY LOOP HERE
#
#  On a microcontroller that boots from flash, .data has two addresses: it
#  LIVES in flash (its load address) and it RUNS in RAM (its virtual address),
#  and crt0 must copy it from the first to the second before main can touch
#  it. That copy loop is in every embedded crt0 you will ever read.
#
#  This machine's memory is loaded by $readmemh at ELABORATION time, from the
#  same image the linker produced -- the initialised data is placed into the
#  RAM array by the bitstream itself, before the clock has ticked once. Load
#  address and run address are the same address, so there is nothing to copy.
#
#  That is a genuine property of an FPGA soft core and not a shortcut: the
#  bitstream initialises the memory. It also tells you exactly what would have
#  to change to boot this machine from the ULX3S's SPI flash instead -- the
#  copy loop comes back, and so does a linker script with AT> in it.
# ===========================================================================
    .section .text.start, "ax"
    .globl _start
_start:
    # ---- 1. the stack ----------------------------------------------------
    # The linker put _stack_top at the top of memory. The stack grows DOWN
    # from there, toward .bss; nothing checks that they do not meet, which is
    # what a stack overflow is on a machine this size. The RISC-V ABI wants
    # sp 16-byte aligned, and the linker script aligns it.
    la      sp, _stack_top

    # ---- 2. zero .bss ----------------------------------------------------
    # A word at a time, because the linker aligned both ends to 4. If this
    # loop is wrong, every uninitialised global starts as whatever the image
    # left there -- a bug that reproduces perfectly and looks like anything
    # except what it is.
    la      t0, _bss_start
    la      t1, _bss_end
1:  bgeu    t0, t1, 2f
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       1b

    # ---- 3. into C -------------------------------------------------------
    # main's return value lands in a0, which the RISC-V ABI defines as the
    # first argument and the return value register.
2:  call    main

    # ---- 4. there is nowhere to return TO ---------------------------------
    # main() returning on a hosted system means exit(). Here it means the
    # program is over and the machine should stop, so write the exit code to
    # the HALT register -- which ends the simulation, and on the board simply
    # stops the program. The infinite loop after it is not optional: without
    # it the PC would run on into whatever follows, and "whatever follows" is
    # zeros, which decode as an illegal instruction.
    li      t0, 0x8000001C
    sw      a0, 0(t0)
3:  j       3b
