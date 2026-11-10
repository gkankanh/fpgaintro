# Lesson 15 — a system on chip

**Concept:** a memory map: making peripherals look like addresses so software can reach them.

**You will build:** your CPU running C compiled by riscv-gcc, printing over UART and drawing on the OLED.

**Needs the board:** yes

**Prerequisites:** lesson 14

**Paths:** editor

> **Status: planned.** Scope and ordering are settled; the code and the written
> lesson are not here yet. Lessons are built in order, so this one is written
> once lesson 14 is complete. See
> [`docs/LESSON_TEMPLATE.md`](../docs/LESSON_TEMPLATE.md) for the shape every
> lesson takes.

---

## Why this lesson exists

Where the FPGA stops being a logic exercise and becomes a computer you
programmed in C. Also where the hardware/software boundary becomes something
you personally defined, which is the clearest possible way to understand it.

## Planned outline

1. address decoding: RAM here, UART there, OLED over there, LEDs at this word
2. a bus, even a trivial one: address, write data, read data, valid, ready
3. memory-mapped I/O, and `volatile` in C as its software-side consequence
4. the toolchain: `riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32`, a linker script, `objcopy` to a hex file BRAM can `$readmemh`
5. crt0: what must happen before `main` when there is no operating system
6. `putchar` over UART, and therefore a usable subset of `printf`
7. a C program drawing on the OLED through lesson 08's framebuffer

## Deliverables

- `*.v` — the design, synthesisable and lint-clean
- `tb_*.v` — a self-checking testbench printing `PASS` or `FAIL`
- `README.md` — the written lesson, following the template
- `diagrams/*.wave.json` — timing diagrams where timing is the point
- editor path only: see [why the visual path stops](../docs/src/paths.md)

**Next:** [lesson 16 — rv32i pipeline](../16-rv32i-pipeline/)
