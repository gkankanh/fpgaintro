#import "../style.typ": *

= Lesson 15 — A system on chip

#planned

#goals(
  concept: [A memory map: making peripherals look like addresses, so software can reach them.],
  build: [Your CPU running C compiled by `riscv-gcc`, printing over the UART and drawing on the OLED.],
  needs: [Lesson 14, a board, and the GNU RISC-V toolchain.],
)[
  - Decode an address space into RAM, ROM and peripherals.
  - Explain what `volatile` in C corresponds to in hardware.
  - Build the toolchain path from C source to a hex file in block RAM.
  - Explain what must happen before `main`, when there is no operating system.
]

== Where a CPU becomes a computer

Lesson 13's memories ignore the high address bits entirely, so address
`0x0000_0100` and address `0xDEAD_0100` hit the same word — the memory
#emph[aliases] across the whole space. That is fine for one program and wrong
in general.

A real system #strong[decodes] the high bits to choose between RAM, ROM and
peripherals, and faults on addresses that match nothing. That decoding is the
memory map, and it is the difference between a CPU and a computer.

A peripheral is then just an address that does something when written. The UART
of lesson 09 becomes a transmit register at some address and a status register
at another, and the software-side consequence is one C keyword:

```c
volatile uint32_t *uart_tx = (uint32_t *)0x8000_0000;
```

#why[
  `volatile` tells the compiler that this location can change without the
  program changing it, and that writes to it have effects beyond storing a
  value — so it may not cache, reorder or elide them. It is the C type system
  acknowledging that some addresses are hardware, and it exists #emph[because]
  memory-mapped I/O does.
]

== The toolchain path

```
riscv-gcc  →  objcopy  →  .hex  →  $readmemh  →  block RAM
```

Lesson 08 established that `$readmemh` runs at elaboration time, so the
compiled program is baked into the bitstream. Changing the C means recompiling
#emph[and] resynthesising — which is the point at which a soft CPU's real
advantage appears: a design where behaviour lives in software is a design you
can change without re-running place and route, if you load the program at run
time instead.

=== Before `main`

With no operating system, something must set up the stack pointer, zero the
`.bss` section, copy initialised data into RAM, and only then call `main`.
That is `crt0`, and writing it is the clearest possible explanation of what a
C runtime actually does — because it is about fifteen instructions and you can
read all of them.

== The payoff

The point at which the FPGA stops being a logic exercise and becomes a computer
you programmed in C — and the point at which the hardware/software boundary
becomes something you personally defined, which is the clearest way there is to
understand it.
