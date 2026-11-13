/* ==========================================================================
 *  soc.h — the memory map, as C sees it.
 *
 *  This header is the software half of busdec.v and mmio.v. Every address in
 *  it is a register in the hardware you built, and the only thing making a
 *  peripheral different from a variable is the word `volatile`.
 *
 *  WHAT `volatile` MEANS HERE. It tells the compiler two things it otherwise
 *  assumes are false: that this location can change without the program
 *  changing it (so a value read once may not be reused), and that writing to
 *  it has an effect beyond storing a value (so a write may not be dropped,
 *  merged or reordered with other volatile accesses).
 *
 *  Drop the keyword and gcc is entirely within its rights to turn
 *
 *      while (UART->STAT & TX_BUSY) ;
 *
 *  into one load and an infinite loop -- because nothing in the program
 *  changes STAT, so why read it twice? That is not a compiler bug. It is the
 *  C abstract machine being told the truth and acting on it, and `volatile`
 *  is how you say that this particular address is hardware.
 * ========================================================================== */
#ifndef SOC_H
#define SOC_H

typedef unsigned int   uint32_t;
typedef unsigned char  uint8_t;

#define IO_BASE 0x80000000u

#define REG(off)  (*(volatile uint32_t *)(IO_BASE + (off)))

#define UART_TX   REG(0x00)   /* W: transmit a byte                       */
#define UART_STAT REG(0x04)   /* R: status bits below                     */
#define UART_RX   REG(0x08)   /* R: the received byte (does not consume)  */
#define UART_ACK  REG(0x0C)   /* W: consume it                            */
#define LEDS      REG(0x10)   /* RW: the eight LEDs                       */
#define BUTTONS   REG(0x14)   /* R: {sw[3:0], btn[6:1]}                   */
#define CYCLES    REG(0x18)   /* R: clocks since reset                    */
#define HALT      REG(0x1C)   /* W: stop, with an exit code               */

#define TX_BUSY   0x1u
#define RX_VALID  0x2u
#define RX_OVER   0x4u

/* ---- the whole I/O library, which is four functions ------------------- */

/* One byte, with no interpretation at all. */
static inline void uart_put(int c)
{
    while (UART_STAT & TX_BUSY)
        ;                      /* the byte would be dropped; wait for the line */
    UART_TX = (uint32_t)c;
}

/* A newline on a serial line is TWO control characters, and a terminal does
 * exactly what it is told: LF (0x0A) means "down one row", CR (0x0D) means
 * "back to column one". Send LF on its own and the cursor drops a row but
 * stays where it was, so every line starts where the last one ended and the
 * output walks off the right-hand edge in a staircase:
 *
 *     Hello world from RV32I SoC on ULX3S
 *                                        deadbeef
 *                                                bss ok
 *
 * Text files on Unix get away with a bare LF because the kernel's tty line
 * discipline expands it on the way out (ONLCR). There is no kernel here, and
 * no line discipline -- there is this function and a shift register. So this
 * is where the expansion has to happen. */
static inline void putchar(int c)
{
    if (c == '\n')
        uart_put('\r');
    uart_put(c);
}

static inline void puts(const char *s)
{
    while (*s)
        putchar(*s++);
}

/* Reading UART_RX does not consume the byte -- see mmio.v for why a read may
 * have no side effect on this bus. The acknowledge is a separate WRITE, and
 * forgetting it means reading the same character forever. */
static inline int getchar(void)
{
    while (!(UART_STAT & RX_VALID))
        ;
    int c = (int)(UART_RX & 0xFFu);
    UART_ACK = 0;
    return c;
}

/* Eight hex digits, most significant first. This is the entire "printf
 * subset" a machine without a C library needs to be debuggable, and it is
 * worth noticing how little it is: no format parsing, no varargs, no
 * division. The shift-by-four is free in hardware (lesson 10) and the lookup
 * is a string literal in .rodata -- which only works because this SoC's
 * memory is one address space, so the program can READ the bytes sitting a
 * few words away from the instructions reading them. */
static inline void puthex(uint32_t v)
{
    static const char digits[] = "0123456789abcdef";
    for (int i = 28; i >= 0; i -= 4)
        putchar(digits[(v >> i) & 0xF]);
}

#endif /* SOC_H */
