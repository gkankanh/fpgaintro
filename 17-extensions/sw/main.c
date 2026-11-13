/* ==========================================================================
 *  main.c — a program that is interrupted, and handles it.
 *
 *  Five demonstrations, in order:
 *
 *    1. ECALL      -- a trap the program asks for. This is how a system call
 *                     works on every operating system you have used.
 *    2. an illegal instruction -- a trap the program did not ask for, and
 *                     survives, because the handler steps over it.
 *    3. the machine timer -- a trap that has nothing to do with the
 *                     instruction stream at all. That is an INTERRUPT.
 *    4. MUL and DIV -- the M extension, from C, with no library call.
 *    5. mcycle and minstret -- the machine measuring its own CPI, which
 *                     lesson 16 could only do in a simulator.
 * ========================================================================== */
#include "soc.h"

/* How often the timer fires, in CYCLES -- not milliseconds. mtime counts
 * cycles on this machine (timer.v says why), so a period in time would need
 * the clock frequency, and the clock frequency is 25 MHz in simulation and 40
 * on the board. 20,000 cycles is 0.56 ms at this machine's 35.7 MHz. */
#define TICK_PERIOD 20000

volatile int ticks = 0;

/* Operands the compiler cannot constant-fold. Declared non-static for the
 * reason lesson 15 gave: gcc would otherwise compute all of this at compile
 * time and emit no MUL or DIV at all, and the demonstration would be of the
 * compiler rather than of the hardware. */
uint32_t big   = 123456789;
uint32_t small = 1000;
int32_t  neg   = -123456789;

/* ==========================================================================
 *  The trap handler.
 *
 *  `__attribute__((interrupt("machine")))` is gcc being asked to generate a
 *  function that can be jumped to by HARDWARE rather than called by software.
 *  Two things change:
 *
 *    * it saves and restores every caller-saved register it touches, because
 *      the interrupted code was not expecting to lose any of them. A normal
 *      function may clobber t0-t6 and a0-a7 freely; this one may not clobber
 *      anything at all.
 *    * it returns with MRET instead of RET, which restores the interrupt
 *      enable from MPIE and jumps to mepc -- the two things RET does not do.
 *
 *  Look at the prologue with `make dis` and count the stores. That stack
 *  traffic is the cost of an interrupt, before any of your code runs.
 *
 *  WHAT THE HARDWARE ALREADY DID, before this function's first instruction:
 *  saved the PC into mepc, recorded why in mcause, copied MIE into MPIE and
 *  cleared MIE so that this handler is not immediately interrupted again, and
 *  jumped to mtvec. Four registers and a jump. Everything else is software,
 *  and this function is the software.
 * ========================================================================== */
__attribute__((interrupt("machine")))
void trap_entry(void)
{
    uint32_t cause = csr_read(mcause);

    /* The top bit distinguishes an interrupt from an exception, which is why
     * mcause is 32 bits wide to hold numbers below sixteen. */
    if ((int32_t)cause < 0) {
        putchar('T');
        putchar('\n');
        ticks++;

        /* RE-ARM, OR BE RE-ENTERED FOREVER. mtip is a LEVEL: it stays high
         * while mtime >= mtimecmp. Returning without moving the deadline
         * means the interrupt is still pending the instant MRET re-enables
         * interrupts, and the machine never makes progress again. This is the
         * classic first bug with a timer, and the exercises make you write
         * it on purpose. */
        mtimecmp_write(mtime_read() + TICK_PERIOD);
        return;
    }

    putchar(cause == CAUSE_ECALL_M ? 'E' : 'I');
    putchar('\n');

    /* STEP OVER THE INSTRUCTION THAT TRAPPED. mepc points AT it, not after
     * it -- which is right for a page fault, where you fix the problem and
     * re-run the instruction, and wrong for ECALL, where re-running it would
     * trap again immediately. Compressed instructions would make this `+2`
     * sometimes, which is one reason a real handler reads the instruction
     * before deciding. */
    csr_write(mepc, csr_read(mepc) + 4);
}

int main(void)
{
    puts("RV32IM\n");

    /* Where traps go. Until this line runs, mtvec is 0 and a trap would jump
     * to the first instruction of the program -- a reset in all but name. */
    csr_write(mtvec, (uint32_t)&trap_entry);

    /* 1. A trap the program asked for. */
    __asm__ volatile ("ecall");

    /* 2. One it did not. The word 0x00000000 decodes to nothing: lesson 12's
     * decoder raises `illegal`, and on lesson 13's core that halted the
     * machine dead. Here the handler prints a letter and steps over it. */
    __asm__ volatile (".word 0");

    /* 3. One that has nothing to do with the instruction stream. */
    mtimecmp_write(mtime_read() + TICK_PERIOD);
    csr_set(mie, MIE_MTIE);            /* let the timer interrupt         */
    csr_set(mstatus, MSTATUS_MIE);     /* let anything interrupt          */

    while (ticks < 3)
        ;                              /* `ticks` is volatile; see soc.h   */

    csr_clear(mstatus, MSTATUS_MIE);   /* quiet again, so the output below
                                        * is not interleaved with ticks    */

    /* 4. The M extension. Every one of these is a single instruction now;
     * without -march=rv32im each would be a call into libgcc, and
     * `make dis` shows the difference better than any paragraph. */
    puts("MUL ");  puthex(big * small);
    puts("\nDIV "); puthex(big / small);
    puts("\nREM "); puthex(big % small);
    puts("\nSDV "); puthex((uint32_t)(neg / (int32_t)small));
    putchar('\n');

    /* 5. The machine's own performance counters. Lesson 16 had to count
     * cycles and instructions in a simulator; a processor with CSRs counts
     * them itself, and any program can ask. */
    puts("CYC "); puthex(csr_read(mcycle));
    puts(" INS "); puthex(csr_read(minstret));
    putchar('\n');

    LEDS = 0x5A;
    puts("DONE\n");
    return 0;
}
