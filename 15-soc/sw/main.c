/* ==========================================================================
 *  main.c — a C program running on a CPU you built, out of gates you built.
 *
 *  Nothing here is remarkable as C, and that is the entire point: it is
 *  ordinary code, compiled by an ordinary compiler, with no idea that the
 *  machine underneath it is a few thousand LUTs on an FPGA. Every line does
 *  something the hardware had to be able to do:
 *
 *    puts()        .rodata -- a string read through the data port of the
 *                  same array the instructions come from (unified memory)
 *    marker        .data   -- an initialised global, placed by the linker,
 *                  loaded by the bitstream, never copied by anyone
 *    zeroed[]      .bss    -- NOT in the image; crt0 zeroed it before main
 *    LEDS = 0xA5   a store that lights a pin, because an address decoder
 *                  said that address belongs to a peripheral
 *    getchar()     a poll of a status bit, and an explicit acknowledge
 *    CYCLES        the machine timing itself
 *
 *  If this prints, every one of those worked.
 * ========================================================================== */
#include "soc.h"

/* Initialised data. The linker places it, the bitstream loads it, and crt0
 * does nothing about it -- so if this prints as deadbeef, the .data section
 * made the whole journey from C through objcopy into the memory array.
 *
 * THESE ARE GLOBAL, NOT `static`, AND THAT IS NOT AN ACCIDENT. Declared
 * static, gcc can see every access to them in this file, prove that nothing
 * ever writes them, fold both checks below to their answers and emit neither
 * variable -- leaving .data and .bss empty and the demonstration proving
 * nothing. (Try it: make them static, then `make size`, and watch both
 * sections go to zero.) A global might be written by another translation
 * unit, so the compiler has to keep it in memory, which is exactly what we
 * want to look at here. */
uint32_t marker = 0xdeadbeef;

/* Uninitialised data: the C standard guarantees these are zero, and nothing
 * in the hardware guarantees anything of the sort. crt0's loop is the entire
 * reason this check passes. Comment that loop out and watch it fail. */
uint32_t zeroed[4];

/* Two integers to add, and a function to add them with.
 *
 * Both are global and the function is `noinline` for the same reason the
 * marker above is not `static`: with everything visible, gcc folds 17 + 25 to
 * 42 at compile time and emits no `add` instruction at all. There would be
 * nothing left to look at, which is the opposite of the point. */
int x = 17;
int y = 25;

__attribute__((noinline))
int add2(int a, int b)
{
    return a + b;
}

int main(void)
{
    puts("Hello world from RV32I SoC on ULX3S \n");

    /* .data arrived intact. */
    puthex(marker);
    putchar('\n');

    /* .bss really is zero. */
    uint32_t sum = 0;
    for (int i = 0; i < 4; i++)
        sum += zeroed[i];
    puts(sum == 0 ? "bss ok\n" : "bss BAD\n");

    /* x + y, and then the instructions that did it.
     *
     * A program on this machine can read its own code, because lesson 15's
     * SoC has ONE memory: `add2` is an address like any other, so casting it
     * to a uint32_t pointer and loading from it fetches the very words the
     * fetch unit fetches. On a machine with separate instruction and data
     * memories -- a Harvard machine, which lesson 16's two block RAM ports
     * nearly make this one -- the same four lines would read nothing at all.
     *
     * What comes back is the encoding lesson 12's decoder takes apart, so
     * the two lessons meet here: the low seven bits of the first word are
     * the opcode field, and 0x33 is RV32I's OP -- register-register
     * arithmetic. `make dis` shows the same bytes as mnemonics. */
    int s = add2(x, y);
    puts("x+y ");
    puthex((uint32_t)s);
    putchar('\n');

    const uint32_t *code = (const uint32_t *)(void *)add2;
    puts("add2 ");
    puthex(code[0]);
    putchar(' ');
    puthex(code[1]);
    putchar('\n');

    puts("op ");
    puthex(code[0] & 0x7Fu);
    putchar('\n');

    /* A store to 0x80000010. One instruction, and eight pins change. */
    LEDS = 0xA5;

    /* Wait for a character from the host and send it back. This is the full
     * round trip: the host's bit stream -> lesson 09's receiver -> a status
     * bit -> a load -> a store -> lesson 09's transmitter -> the host. */
    puts("Waiting for a character from host\n");
    int c = getchar();
    putchar(c);
    putchar('\n');

    /* The machine times itself. `volatile` on the loop counter is what stops
     * the optimiser deleting the loop entirely -- which it is allowed to do,
     * because an empty loop has no effect that C can observe. It would have
     * no effect this program could observe either, if the cycle counter were
     * not hardware. */
    uint32_t t0 = CYCLES;
    for (volatile int i = 0; i < 100; i++)
        ;
    uint32_t t1 = CYCLES;
    puts("CYC ");
    puthex(t1 - t0);
    putchar('\n');

    puts("DONE\n");

    /* A marker the hardware can see, one instruction before the mistake
     * below. The testbench watches the LEDs for it, because the serial line
     * is far slower than the CPU: "DONE" is still being shifted out a
     * character at a time while the program runs on past it, so the text is
     * no use at all as a statement about WHEN. A store is instant. */
    LEDS = 0x5A;

    /* The last thing this program does is a mistake, on purpose.
     *
     * 0x0DD00000 is in neither the memory array nor the I/O window, so the
     * address decoder matches nothing and raises a fault. On lesson 13's
     * machine this store would have silently landed on some innocent word,
     * because the high address bits went nowhere; here it is REPORTED, and
     * that is the difference an address map makes.
     *
     * Nothing stops the program -- there is no trap mechanism until lesson
     * 17 -- so the fault is latched and shown: on the LEDs with sw[3] up, and
     * as a check in the testbench. */
    *(volatile uint32_t *)0x0DD00000u = 1;

    return 0;                 /* crt0 turns this into a write to HALT */
}
