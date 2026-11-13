#import "../style.typ": *

= Lesson 15 — A system on chip

#goals(
  concept: [A memory map: making peripherals look like addresses, so software can reach them.],
  build: [Your CPU running C compiled by `riscv-gcc`, printing over the UART and reporting its own cycle count.],
  needs: [Lessons 13 and 09, a board, and the GNU RISC-V toolchain.],
)[
  - Decode an address space into memory and peripherals.
  - Explain what `volatile` in C corresponds to in hardware.
  - Build the toolchain path from C source to a hex file in memory.
  - Explain what must happen before `main`, when there is no operating system.
  - Say what a bus without a `ready` signal can never be connected to.
]

== Where a CPU becomes a computer

Lesson 13's memories ignored the high address bits entirely, so `0x0000_0100`
and `0xDEAD_0100` hit the same word. The memory #emph[aliased] across the whole
32-bit space — which means every address was valid, which means no mistake
could ever be reported.

A real system #strong[decodes] the high bits to decide which device an address
belongs to. That decoding is the memory map, and it is the difference between a
CPU and a computer.

#ttable(
  columns: (auto, auto, 1fr),
  [*address*], [*device*], [],
  [`0x0000_0000`–`0x0000_07FF`], [memory], [2 KB: program, data and stack],
  [`0x8000_0000`–`0x8000_00FF`], [I/O], [the peripheral registers],
  [everything else], [#emph[nothing]], [and an access there is reported],
)

The I/O window sits at the top bit on purpose. `addr[31]` alone separates I/O
from memory, so a select line costs #strong[one LUT input] rather than a 32-bit
comparator. Real memory maps are laid out with exactly this in mind: the reason
a peripheral block sits at `0x4000_0000` or `0xE000_0000` and never at
`0x1234_5678` is that the decoder is in series with every memory access the
machine will ever make.

A peripheral is then just an address that does something when written. There is
no I/O instruction in RV32I — no `IN`, no `OUT` — so the UART of lesson 09
becomes two addresses, reached with the same `LW` and `SW` as everything else.

#why[
  This is the lesson where the hardware/software boundary stops being something
  you read about and becomes something #emph[you chose]. The address decoder and
  the C header are the same decision written twice, once for each side, and
  nothing but your own care makes them agree.
]

== One memory, two ports

Lesson 13 had two memories because a single-cycle CPU fetches an instruction
#emph[and] accesses data in the same cycle, and one memory with one port cannot
do both. The fix is not a second memory. It is #strong[a second port].

One array, one address space, two read ports — fetch, and data. Software now
sees a flat memory in which a string constant can be read by the instruction
executing a few words away from it, which is what C expects and what makes
`.rodata` work at all.

#watch[
  One address space means a store can change an instruction. On this machine
  self-modifying code even works, because the fetch is asynchronous and there is
  no cache and no pipeline holding a stale copy. On any real machine it does
  not, and the instruction-cache flush that makes it work is one of the reasons
  a JIT compiler is harder than it looks.
]

== The bus has no `ready`, and that absence is the design

A real bus — AXI, Wishbone, even the simplest handshake — lets the #emph[target]
say "not yet". That is what makes a slow peripheral, a cache miss or an
off-chip memory possible.

This bus cannot. The lesson 13 core has no way to wait, because a single-cycle
CPU finishes the instruction in the cycle it started. #strong[Every target here
must answer combinationally], which is why the memory is built from LUTs
instead of block RAM, and why nothing slower than a register can ever be
attached.

So the missing `ready` is not a simplification for teaching. It is the
single-cycle decision of lesson 13, arriving two lessons later as a constraint
on what can be plugged in.

=== A read may not have a side effect

On almost every real UART, reading the data register consumes the byte. That
design is impossible here, and the reason is worth more than the convenience it
costs.

A register with a side effect on #strong[read] has to know that a read really
happened. The lesson 13 core reads its data memory #emph[unconditionally] —
every instruction puts its ALU result on the address bus whether or not it is a
load, and the writeback multiplexer decides whether the returned word is used.
So if reading the receive register consumed a byte, any instruction whose
arithmetic happened to produce `0x8000_0008` would eat a character — and
`li t0, -2147483640` is exactly that number.

Consuming the byte is therefore a #strong[write], to a separate acknowledge
register, because a write strobe is only ever asserted by a real store.

#watch[
  A bus whose master cannot say #emph["this is a real read"] may not have read
  side effects anywhere in its address map.
]

The same asymmetry decides what can be reported. A store to an unmapped address
is unambiguously a mistake, and the decoder raises a fault. A #emph[load] from
one cannot be, so it quietly reads whatever the aliased word holds. Lesson 16's
core brings its memory-read signal out — a pipeline has to know which stage is
accessing memory anyway — and lesson 17 gives the fault somewhere to be
reported #emph[to].

== The toolchain path

```
riscv64-elf-gcc  →  objcopy  →  .hex  →  $readmemh  →  the memory array
```

Lesson 08 established that `$readmemh` runs at elaboration time, so the compiled
program is baked into the bitstream. Changing the C means recompiling
#emph[and] resynthesising.

#why[
  `volatile` tells the compiler two things it otherwise assumes are false: that
  this location can change without the program changing it, and that writing to
  it has an effect beyond storing a value. Drop it from a status-register poll
  and gcc is entirely within its rights to emit one load and an infinite loop —
  because nothing in the program changes that variable, so why read it twice?
  That is not a compiler bug. It is the C abstract machine being told the truth
  and acting on it, and `volatile` is how you say #emph[this address is
  hardware].
]

=== Before `main`

With no operating system, something must set up the stack pointer and zero the
`.bss` section before `main` runs. That is `crt0`, it is about twenty
instructions here, and you can read all of them.

What is #emph[missing] from it is the interesting part. On a microcontroller
booting from flash, `.data` has two addresses — it lives in flash and runs in
RAM — and `crt0` must copy it across. That copy loop is in every embedded
`crt0` you will ever read, and it is absent here, because `$readmemh` placed the
initialised data into the memory array from the bitstream before the clock
ticked once. Load address and run address are the same address.

That is a real property of a soft core rather than a shortcut, and it says
exactly what would change to boot this machine from the board's SPI flash: the
copy loop comes back, and so does a linker script with `AT>` in it.

== What it cost

#cost([`soc_top` — the whole computer],
      (LUT4: 4821, TRELLIS_FF: 146, CCU2C: 114, PFUMX: 1460, L6MUX21: 593,
       TRELLIS_DPR16X4: 544),
      share: true)[
  #strong[Not one block RAM.] The 85F has 208 of them, each holding 18,432 bits;
  this design needs 16,384 bits of memory — which would fit in a single one —
  and uses none, because a single-cycle core needs its memory to answer in the
  same cycle and lesson 08 proved that rules a `DP16KD` out.
]

#cost([`memory` — 2 KB, two asynchronous read ports],
      (LUT4: 2756, PFUMX: 800, L6MUX21: 465, TRELLIS_DPR16X4: 512),
      cmd: "make synth M=memory")[
  More than half the computer, to hold 2 KB. Lesson 08's table predicted it: a
  256-entry asynchronous memory measured 919 LUT4 against a single `DP16KD` for
  the synchronous version, and this is the same arithmetic at twice the size
  with two read ports.
]

#cost([`busdec` — the entire memory map],
      (LUT4: 20, CCU2C: 10, PFUMX: 7, L6MUX21: 4),
      cmd: "make synth M=busdec")[
  #strong[Twenty LUT4.] The thing that turns a CPU into a computer is the
  cheapest module in the design by two orders of magnitude — which is what
  putting the I/O window at `addr[31]` buys.
]

#cost([`mmio` — UART, LEDs, buttons, stopwatch],
      (LUT4: 200, TRELLIS_FF: 113, CCU2C: 24, PFUMX: 66, L6MUX21: 33),
      cmd: "make synth M=mmio")[
  113 flip-flops, against 32 in the entire CPU. A peripheral is almost all
  state; a single-cycle datapath is almost all combinational logic.
]

== What it cost in time, and the size this lesson had to ship

This is where the lesson stopped being a write-up and became a measurement,
because the first version of it #strong[did not work on the board].

The memory is read asynchronously, so every fetch and every load drags a
multiplexer tree the full depth of the array, in series with the whole
single-cycle datapath. The deeper the memory, the slower the machine.

#measured("memory size is now a timing parameter")[
  #ttable(
    columns: (auto, auto, auto, auto),
    [*memory*], [*`LUT4`*], [*max clock, three placer seeds*], [*at 25 MHz*],
    [4 KB — 1024 words], [7,263], [25.14 / 24.44 / 24.40 MHz], [#strong[fails 2 runs in 3]],
    [*2 KB — 512 words*], [*4,821*], [*27.28 / 28.21 / 28.00 MHz*], [*passes*],
    [1 KB — 256 words], [4,007], [31.73 / 30.63 / 30.49 MHz], [passes],
  )
  ```
  make synth M=soc_top P="MEM_WORDS 1024"
  ```
]

#strong[4 KB of memory does not fit in 25 MHz on this machine.] Not "is tight" —
does not fit. The board's oscillator is 25 MHz and `nextpnr` reports `FAIL`,
which means the design may do anything at all on hardware, including working
until it warms up.

Three things in that table matter more than the numbers.

#strong[Three seeds, not one.] `nextpnr`'s placer is randomised, and the 4 KB
build passes on seed 1 and fails on seeds 2 and 3. A design that meets timing by
0.5% has not met timing; it has got away with it once. Quoting a single
placement as #emph[the] frequency is the most common way to publish a number
nobody else can reproduce.

#strong[Doubling the memory cost 10% of the clock.] Memory size has not been a
timing parameter in any earlier lesson. Lesson 08's warning was about area; this
is the same decision returning as speed.

#strong[The linker script is where this lands on the programmer.] `link.ld` says
`LENGTH = 2K` because of the row above, and a program that outgrows it does not
get a slower machine, it gets a link error. That is the hardware telling the
software what it may be.

#measured("the cost of becoming a computer")[
  #ttable(
    columns: (auto, auto),
    [32-bit ALU alone (lesson 10)], [115.94 MHz],
    [single-cycle core, small Harvard memories (lesson 13)], [61.24 MHz],
    [*the same core, as a computer*], [*28 MHz*],
  )
]

Building a computer around the core halved its clock again. Lesson 13 paid for
putting the whole datapath into one cycle; this lesson pays for putting a real
memory and an address decoder on both ends of it. Nothing was done badly — this
is what the single-cycle decision costs once the machine is big enough to run C.

#why[
  That is the argument for pipelining, stated in megahertz and in LUT4. Lesson
  16 takes the same core, cuts it into five stages, and gets both numbers back:
  the memory becomes two block RAMs, and the clock nearly doubles.
]

== On the board

#measured("what the hardware actually sent")[
  ```
  RV32I SoC
  deadbeef
  bss ok
  K
  CYC 0000025e
  DONE
  ```
  Seven consecutive runs, every one byte-identical to the string the testbench
  expected at the time — and `CYC 0000025e` is the same 606 cycles the
  simulation produced. The delay loop takes exactly as long on real silicon as
  it does in Icarus.

  The program has since gained a longer greeting, the `x+y` and opcode lines,
  and a carriage return on every line; the capture above is left as it was
  taken, because a measurement is a record of what happened and not a thing
  to edit afterwards. The cycle count is the part that was being measured, and
  it has not moved.
]

The capture also contained two greetings cut off after a character or two,
which is worth more than it looks. At 115,200 baud a character takes 87
microseconds, so a greeting that managed one `R` before restarting means two
resets about that far apart — from one press of the button.

#why[
  That is contact bounce, and it is the thing lesson 03 built a debouncer for.
  The board demo wires the reset button straight to `rst` with nothing in
  between, because a repeated reset is harmless — which is exactly the
  judgement lesson 03 asks you to make rather than debouncing everything by
  reflex. The evidence that it was the right call, and the evidence that the
  bouncing is real, are the same six lines of serial output.
]

== What this machine does not do

#ttable(
  columns: (auto, 1fr),
  [*faults*], [
    a store, and only a store, to an unmapped address is latched and shown. A
    load from one reads an aliased word and nobody is told
  ],
  [*traps*], [
    none. An illegal instruction halts the core, as in lesson 13, because
    trapping needs CSRs that lesson 17 adds
  ],
  [*the bus*], [
    one master, no arbitration, no `ready`, no burst. Everything answers in one
    cycle or it cannot be attached
  ],
  [*the UART*], [
    no FIFO. The receiver holds exactly one byte and reports an overrun if a
    second arrives before software takes the first
  ],
)
