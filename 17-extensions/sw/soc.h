/* ==========================================================================
 *  soc.h — lesson 15's memory map, plus the timer and the CSRs.
 *
 *  Everything from 0x00 to 0x1C is lesson 15's, unchanged, because the
 *  peripheral is the same file. The timer is new, and so is the second half
 *  of this header: the CSRs, which are not memory at all.
 * ========================================================================== */
#ifndef SOC_H
#define SOC_H

typedef unsigned int       uint32_t;
typedef signed   int       int32_t;
typedef unsigned long long uint64_t;
typedef unsigned char      uint8_t;

#define IO_BASE 0x80000000u
#define REG(off)  (*(volatile uint32_t *)(IO_BASE + (off)))

#define UART_TX   REG(0x00)
#define UART_STAT REG(0x04)
#define UART_RX   REG(0x08)
#define UART_ACK  REG(0x0C)
#define LEDS      REG(0x10)
#define BUTTONS   REG(0x14)
#define CYCLES    REG(0x18)
#define HALT      REG(0x1C)

/* The machine timer. Memory-mapped, not a CSR, because mtime belongs to the
 * platform rather than to the hart -- see timer.v. */
#define MTIME     REG(0x40)
#define MTIMEH    REG(0x44)
#define MTIMECMP  REG(0x48)
#define MTIMECMPH REG(0x4C)

#define TX_BUSY   0x1u
#define RX_VALID  0x2u

/* ---- the CSRs ----------------------------------------------------------
 *
 * There is no C syntax for a control and status register, and there is no
 * reason there should be: they are not memory, they have no addresses C can
 * form, and the only instructions that reach them take the CSR number as an
 * IMMEDIATE -- so it must be a compile-time constant, which is why these are
 * macros with `#csr` string-pasted into the assembly rather than functions
 * taking a number.
 *
 * This is the floor of the C abstraction, and every operating system has a
 * header that looks like this.
 */
#define csr_read(csr) ({                                   \
    uint32_t v__;                                          \
    __asm__ volatile ("csrr %0, " #csr : "=r"(v__));       \
    v__; })

#define csr_write(csr, val)                                \
    __asm__ volatile ("csrw " #csr ", %0" :: "r"(val))

#define csr_set(csr, bits)                                 \
    __asm__ volatile ("csrs " #csr ", %0" :: "r"(bits))

#define csr_clear(csr, bits)                               \
    __asm__ volatile ("csrc " #csr ", %0" :: "r"(bits))

#define MSTATUS_MIE  (1u << 3)    /* interrupts enabled, globally */
#define MIE_MTIE     (1u << 7)    /* ...and the timer in particular */

#define CAUSE_ILLEGAL   2u
#define CAUSE_BREAK     3u
#define CAUSE_ECALL_M  11u

/* ---- the same four I/O functions as lesson 15 -------------------------- */

static inline void putchar(int c)
{
    while (UART_STAT & TX_BUSY)
        ;
    UART_TX = (uint32_t)c;
}

static inline void puts(const char *s)
{
    while (*s)
        putchar(*s++);
}

static inline void puthex(uint32_t v)
{
    static const char digits[] = "0123456789abcdef";
    for (int i = 28; i >= 0; i -= 4)
        putchar(digits[(v >> i) & 0xF]);
}

/* mtime is 64 bits across two 32-bit registers, and reading it needs care:
 * between reading the low half and the high half, the low half can wrap and
 * carry into the high one, and the pair you took is then a time that never
 * happened. Re-reading the high half and retrying if it moved is the
 * standard fix, and it is in the RISC-V specification itself. */
static inline uint64_t mtime_read(void)
{
    uint32_t hi, lo;
    do {
        hi = MTIMEH;
        lo = MTIME;
    } while (hi != MTIMEH);
    return ((uint64_t)hi << 32) | lo;
}

/* Arming it needs the same care in reverse: set the comparison out of reach
 * before changing the halves, or a half-written deadline fires immediately. */
static inline void mtimecmp_write(uint64_t v)
{
    MTIMECMPH = 0xFFFFFFFFu;
    MTIMECMP  = (uint32_t)v;
    MTIMECMPH = (uint32_t)(v >> 32);
}

#endif /* SOC_H */
