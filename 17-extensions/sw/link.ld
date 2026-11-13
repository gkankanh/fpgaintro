/* ==========================================================================
 *  link.ld — where everything goes.
 *
 *  The linker script is the other half of the memory map: busdec.v decides
 *  which device an address belongs to, and this decides which address each
 *  piece of the program gets. They have to agree, and nothing checks that
 *  they do -- except the machine, immediately, by not working.
 *
 *  MEMORY says there are 16 KB starting at zero, which is exactly
 *  soc17.v's MEM_WORDS * 4. Lesson 15 had to ship 2 KB because an
 *  asynchronous memory that size would not meet timing; lesson 16 moved the
 *  memory into block RAM, where 16 KB costs four of the chip's 208 and does
 *  not touch the clock. This line is what that bought. The CPU resets with pc = 0 (lesson 13), so
 *  whatever is placed first is what runs first: hence .text.start, the one
 *  section crt0.S puts itself in, placed ahead of everything else.
 * ========================================================================== */
OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    ram (rwx) : ORIGIN = 0x00000000, LENGTH = 16K
}

SECTIONS
{
    /* Reset lands here. _start must be the first byte of the image. */
    .text : {
        *(.text.start)
        *(.text .text.*)
    } > ram

    /* String literals and const data. On this machine they are read by the
     * data port of the same memory array the instructions are fetched from,
     * which is what the unified address space bought us. */
    . = ALIGN(4);
    .rodata : {
        *(.rodata .rodata.* .srodata .srodata.*)
    } > ram

    /* Initialised statics. Present in the image, therefore present in the
     * bitstream, therefore already correct at reset -- see crt0.S. */
    . = ALIGN(4);
    .data : {
        *(.data .data.* .sdata .sdata.*)
    } > ram

    /* Zeroed statics. NOT in the image: .bss occupies no space in the
     * binary, which is why a program with a 1 KB zero array is not 1 KB
     * bigger. crt0 zeroes it at run time, and these two symbols are how it
     * knows where. Both ends aligned to 4 so the loop can store words. */
    . = ALIGN(4);
    .bss (NOLOAD) : {
        _bss_start = .;
        *(.bss .bss.* .sbss .sbss.* COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > ram

    /* The stack starts at the top of memory and grows down. 16-byte aligned
     * because the RISC-V calling convention says so. */
    _stack_top = ORIGIN(ram) + LENGTH(ram);

    /* Anything the toolchain emits that this machine has no use for. Keeping
     * them OUT of the image is deliberate: a .comment section silently
     * linked into .text would be executed. */
    /DISCARD/ : {
        *(.comment)
        *(.note .note.*)
        *(.eh_frame .eh_frame_hdr)
        *(.riscv.attributes)
    }
}
