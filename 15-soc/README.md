# Lesson 15 — a system on chip

**Concept:** a memory map — making peripherals look like addresses, so software
can reach them.

**You will build:** your CPU running C compiled by `riscv-gcc`, printing over
the UART and reporting its own cycle count.

**Needs the board:** yes, and this is the one to show people

**Prerequisites:** lesson 13 (the core) and lesson 09 (the UART). Lesson 14 is
not needed for this lesson, only for the ordering of the course.

**Paths:** editor only

**By the end you can:**

- Decode an address space into memory and peripherals.
- Explain what `volatile` in C corresponds to in hardware.
- Build the toolchain path from C source to a hex file in memory.
- Explain what must happen before `main`, when there is no operating system.
- Say what a bus without a `ready` signal can never be connected to.

---

## The idea

Lesson 13's memories ignored the high address bits entirely, so `0x0000_0100`
and `0xDEAD_0100` hit the same word. The memory **aliased** across the whole
32-bit space, which means every address was valid, which means no mistake could
ever be reported.

A real system **decodes** the high bits to decide which device an address
belongs to. That decoding is the memory map, and it is the difference between a
CPU and a computer.

A peripheral is then just an address that does something when written. There is
no I/O instruction in RV32I — no `IN`, no `OUT` — so the UART of lesson 09
becomes two addresses, and software reaches it with the same `lw` and `sw` it
uses for everything else.

> **Why this matters** — this is the lesson where the hardware/software
> boundary stops being something you read about and becomes something *you
> chose*. `busdec.v` and `sw/soc.h` are the same decision written twice, once
> for each side, and nothing but your own care makes them agree.

## The map

| address | device | |
|---|---|---|
| `0x0000_0000`–`0x0000_07FF` | memory | 2 KB: program, data and stack |
| `0x8000_0000`–`0x8000_00FF` | I/O | the peripheral registers |
| everything else | *nothing* | and a store there is reported |

The I/O window is at the top bit on purpose. `addr[31]` alone separates I/O
from memory, so a select line costs **one LUT input** rather than a 32-bit
comparator. Real memory maps are laid out with exactly this in mind: the reason
a peripheral block sits at `0x4000_0000` or `0xE000_0000` and never at
`0x1234_5678` is that the decoder is in series with every memory access the
machine will ever make.

The peripheral registers, from [`mmio.v`](./mmio.v):

| offset | name | |
|---|---|---|
| `0x00` | `UART_TX` | W: transmit this byte (dropped if the line is busy) |
| `0x04` | `UART_STAT` | R: `tx_busy`, `rx_valid`, `rx_over` |
| `0x08` | `UART_RX` | R: the received byte — reading does **not** consume it |
| `0x0C` | `UART_ACK` | W: consume it |
| `0x10` | `LEDS` | RW: the eight LEDs |
| `0x14` | `BUTTONS` | R: `{sw[2:0], btn[5:3]}` |
| `0x18` | `CYCLES` | R: clocks since reset |
| `0x1C` | `HALT` | W: stop, with an exit code |

## The design

### One memory, two ports — the end of the Harvard split

Lesson 13 had two separate memories because a single-cycle CPU fetches an
instruction *and* accesses data in the same cycle, and one memory with one port
cannot do both. [`memory.v`](./memory.v) fixes that, and the fix is not a second
memory: it is **a second port**.

One array, one address space, two read ports — fetch (read-only) and data (read
and write). Software now sees a flat memory in which a string constant can be
read by the instruction executing a few words away from it, which is what C
expects and what makes `.rodata` work at all.

Two things that shape costs:

- **Both reads are asynchronous**, because the single-cycle core needs the
  instruction and the loaded word *inside* the cycle that asked for them.
  Lesson 08 proved an asynchronous read can never be a block RAM. So this array
  becomes distributed RAM and multiplexer trees, and the 85F's 208 block RAMs
  sit idle. The measurement below is brutal about what that costs.
- **A second read port means a second copy of the storage**, because a
  distributed RAM cell has one read address. The write goes to both copies.

> **Watch out** — one address space means a store can change an instruction.
> On this machine self-modifying code even works, because the fetch is
> asynchronous and there is no cache and no pipeline holding a stale copy. On
> any real machine it does not, and the instruction-cache flush that makes it
> work is one of the reasons a JIT compiler is harder than it looks.

### The bus has no `ready`, and that absence is the design

A real bus — AXI, Wishbone, even the simplest handshake — lets the *target* say
"not yet". That is what makes a slow peripheral, a cache miss or an off-chip
memory possible.

This bus cannot. The lesson 13 core has no way to wait, because a single-cycle
CPU finishes the instruction in the cycle it started. **Every target here must
answer combinationally**, which is why the memory is built from LUTs instead of
block RAM and why nothing slower than a register can ever be attached.

So the missing `ready` is not a simplification for teaching. It is the
single-cycle decision of lesson 13 arriving two lessons later as a constraint on
what can be plugged in. Lesson 16's pipeline is the first design in this course
that can wait — and it is no coincidence that it is also the first that can use
the chip's real memories.

### Why reading `UART_RX` does not consume the byte

On almost every real UART it does: read the data register and the byte is gone.
That design is impossible here, and the reason is worth more than the
convenience it costs.

A register with a side effect on **read** has to know that a read really
happened. The lesson 13 core reads its data memory *unconditionally* — every
instruction puts its ALU result on the address bus whether or not it is a load,
and the writeback multiplexer decides whether the returned word is used. Its
`mem_read` signal exists but is never brought out of the module; it is sitting
in that file's list of deliberately unused signals.

So if reading `UART_RX` consumed the byte, any instruction whose arithmetic
happened to produce `0x8000_0008` would eat a character. That is not
hypothetical: `li t0, -2147483640` is exactly that number.

Consuming the byte is therefore a **write**, to `UART_ACK`, because `we` is only
ever asserted by a real store. The general rule is worth keeping:

> **Watch out** — a bus whose master cannot say *"this is a real read"* may not
> have read side effects anywhere in its address map.

The same asymmetry is why `fault` is qualified by `we` in
[`busdec.v`](./busdec.v). A store to an unmapped address is unambiguously a
mistake and is reported. A *load* from one cannot be, so it quietly reads
whatever the aliased word holds. Lesson 16's core brings `mem_read` out — a
pipeline has to know which stage is accessing memory anyway — and lesson 17
gives the fault somewhere to be reported *to*.

## The software

```
riscv64-elf-gcc   sw/crt0.S sw/main.c  ->  firmware.elf
riscv64-elf-objcopy          .elf      ->  .bin       strip the ELF wrapper
tools/bin2hex.py             .bin      ->  .hex       $readmemh's format
$readmemh                    .hex      ->  the memory array, at elaboration
```

```bash
make firmware      # recompile; needs brew install riscv64-elf-gcc
make dis           # the program as your decoder sees it
make size          # where the 2 KB went
```

`firmware.hex` is **checked in**, because `$readmemh` runs at elaboration
(lesson 08) and the hardware therefore treats it as a source file. A reader with
no RISC-V compiler can still run `make sim`, `make synth` and `make bit`; they
just cannot change the program.

### `volatile`, and what it means in gates

```c
#define UART_STAT (*(volatile uint32_t *)0x80000004)
while (UART_STAT & TX_BUSY) ;
```

`volatile` tells the compiler two things it otherwise assumes are false: that
this location can change without the program changing it, and that writing to it
has an effect beyond storing a value.

Drop the keyword and gcc is entirely within its rights to turn that loop into
one load and an infinite loop — because nothing in the program changes
`UART_STAT`, so why read it twice? That is not a compiler bug. It is the C
abstract machine being told the truth and acting on it, and `volatile` is how
you say *this address is hardware*.

### Before `main`

[`sw/crt0.S`](./sw/crt0.S) is twenty instructions, and every C program you have
ever run started with its equivalent. C's rules say that by the time `main` runs
there is a stack, `.bss` is zero, and `.data` holds its initialisers. crt0 does
the first two.

**The third is already true, and the reason is specific to an FPGA.** On a
microcontroller booting from flash, `.data` has two addresses — it *lives* in
flash and *runs* in RAM — and crt0 must copy it across before `main` can touch
it. That copy loop is in every embedded crt0 you will ever read, and it is
absent here, because `$readmemh` placed the initialised data into the memory
array from the bitstream before the clock ticked once. Load address and run
address are the same address.

That is a real property of a soft core, not a shortcut — and it tells you
exactly what would have to change to boot this machine from the ULX3S's SPI
flash: the copy loop comes back, and so does a linker script with `AT>` in it.

> **Watch out** — in [`sw/main.c`](./sw/main.c) the two globals are *not*
> `static`, and that is load-bearing. Declared static, gcc can see every access
> to them, prove nothing ever writes them, fold both checks to their answers and
> emit neither variable — leaving `.data` and `.bss` empty and the
> demonstration proving nothing. Try it, then run `make size`.

## Simulate it

```bash
make sim
```

```
RV32I SoC
deadbeef
bss ok
K
CYC 0000025e
DONE

PASS: 46 characters over the wire, both LED writes seen, one wild store caught, halt code 0
```

That output is not printed by the testbench. It is printed by the *program*,
and the testbench is reading it off a wire.

[`tb_soc.v`](./tb_soc.v) behaves like the host at the other end of the cable: it
instantiates lesson 09's **receiver**, points it at the SoC's transmit pin, and
decodes bytes at the agreed baud rate; and it instantiates lesson 09's
**transmitter** pointed the other way to send the single keystroke that the
program echoes. Everything in between — gcc's output, crt0, the address
decoder, the write path, the shift register, the bit timing — has to be right
for one character to arrive.

The obvious shortcut would be to reach into the design and watch writes to the
transmit register. That tests everything except the UART, the bus decode and the
pin: the parts most likely to be wrong.

Three details worth knowing:

- **The baud rate is wrong on purpose.** 2.5 Mbaud against a 25 MHz clock is ten
  clocks per bit, where the board's 115,200 is 217. Identical logic, one
  parameter, and the simulation finishes in ten thousand cycles instead of two
  hundred thousand.
- **`CYC 0000025e` is a measurement, so the testbench does not check it.** The
  expected string has `?` where the eight hex digits go. The test checks that
  the machine timed itself, not that it got a particular answer — 606 cycles for
  a 100-iteration `volatile` loop, or about six cycles an iteration, which is
  one load, one add, one store and one branch.
- **The program ends with a deliberate mistake.** The last thing `main` does is
  store to `0x0DD00000`, which belongs to nothing. On lesson 13's machine that
  store landed silently on an innocent word. Here it is reported, and the
  testbench fails if it is *not*.

```bash
make wave
```

Three signals are worth more than the other forty: `dut.dmem_addr`,
`dut.u_dec.sel_io` and `dut.uart_tx_pin`. Watch `sel_io` go high for exactly the
cycles in which the program is talking to a peripheral, and watch the address
bus carry garbage the rest of the time — that garbage is the reason this
machine's loads cannot fault.

## What it cost

```bash
make synth
```

| resource | count |
|---|---:|
| `LUT4` | 4,821 |
| `TRELLIS_FF` | 146 |
| `CCU2C` | 114 |
| `PFUMX` | 1,460 |
| `L6MUX21` | 593 |
| `TRELLIS_DPR16X4` | 544 |
| `DP16KD` | **0** |

4,821 of the 85F's 83,640 LUT4 — 5.8% of the part, for a computer that is
mostly 2 KB of memory.

That last row is the lesson. **Not one block RAM.** The 85F has 208 of them,
each holding 18,432 bits; this design needs 16,384 bits of memory — which would
fit in a single one — and uses none, because lesson 13 chose a single-cycle
core and a single-cycle core needs its memory to answer in the same cycle.

Where it all went:

```bash
make synth M=memory   # the array alone
make synth M=mmio
make synth M=busdec
make synth M=cpu
```

| module | `LUT4` | `TRELLIS_FF` | `TRELLIS_DPR16X4` | what it is |
|---|---:|---:|---:|---|
| `memory` | 2,756 | 0 | 512 | 2 KB, two asynchronous read ports |
| `cpu` | 1,765 | 32 | 32 | lesson 13's core, unchanged |
| `mmio` | 200 | 113 | 0 | UART, LEDs, buttons, stopwatch |
| `busdec` | 20 | 0 | 0 | **the entire memory map** |

- **The memory is more than half the design.** 2,756 LUT4 and 512 distributed
  RAM cells to hold 2 KB that one block RAM would have swallowed whole. Lesson
  08's table predicted this: it measured a 256-entry asynchronous memory at 919
  LUT4 against a single `DP16KD` for the synchronous version, and this is the
  same arithmetic at twice the size with two read ports.
- **The memory map costs 20 LUT4.** The thing that turns a CPU into a computer
  is the cheapest module in the design by two orders of magnitude. That is what
  putting I/O at `addr[31]` buys.
- **113 flip-flops in `mmio`** against 32 in the entire CPU. A peripheral is
  almost all state; a single-cycle datapath is almost all combinational logic.
- `cpu` reports 1,765 LUT4, the same number lesson 13 measured, because not one
  line of it changed. Re-measuring a module you reused is how you find out
  whether you really reused it.

## What it cost in time — and the size this lesson had to ship

```bash
make bit
```

This is where the lesson stopped being a write-up and started being a
measurement, because the first version of it **did not work on the board.**

The memory is read asynchronously, so every fetch and every load drags a
multiplexer tree the full depth of the array, and that tree is in series with
the whole single-cycle datapath. The deeper the memory, the slower the machine:

| memory | `LUT4` | max clock, three placer seeds | at 25 MHz |
|---|---:|---|---|
| 4 KB — 1024 words | 7,263 | 25.14 / 24.44 / 24.40 MHz | **fails 2 runs in 3** |
| **2 KB — 512 words** | **4,821** | **27.28 / 28.21 / 28.00 MHz** | **passes** |
| 1 KB — 256 words | 4,007 | 31.73 / 30.63 / 30.49 MHz | passes |

```bash
make bit                                   # as shipped, 2 KB
make synth M=soc_top P="MEM_WORDS 1024"    # any row of the table
```

**4 KB of memory does not fit in 25 MHz on this machine.** Not "is tight" —
does not fit. The ULX3S's oscillator is 25 MHz and `nextpnr` reports `FAIL`,
which means the design may do anything at all on the board, including working
until it warms up.

Three things in that table are worth more than the numbers:

- **Three seeds, not one.** `nextpnr`'s placer is randomised, and the 4 KB build
  passes on seed 1 and fails on seeds 2 and 3. A design that meets timing by
  0.5% has not met timing; it has got away with it once. Quoting a single
  placement as *the* frequency is the most common way to publish a number that
  nobody else can reproduce — so these were measured three times, and the spread
  is part of the result.
- **Doubling the memory cost 10% of the clock.** Memory size is a *timing*
  parameter here, which it has not been in any earlier lesson. Lesson 08's
  warning was about area; this is the same decision coming back as speed.
- **The linker script is where this lands on the programmer.** `sw/link.ld`
  says `LENGTH = 2K` because of the row above, and a program that outgrows it
  does not get a slower machine, it gets a link error. That is the hardware
  telling the software what it may be.

And compared with the core it contains:

| design | max clock |
|---|---|
| 32-bit ALU alone (lesson 10) | 115.94 MHz |
| single-cycle core, small Harvard memories (lesson 13) | 61.24 MHz |
| **the same core, as a computer** | **28 MHz** |

**Building a computer around the core halved its clock again.** Lesson 13 paid
for putting the whole datapath in one cycle; lesson 15 pays for putting a real
memory and an address decoder on both ends of it. Nothing was done badly here —
this is what the single-cycle decision costs once the machine is big enough to
run C, and it is the argument for lesson 16 stated in megahertz.

## On the board

```bash
make firmware     # only if you changed the C
make bit
make prog
make console      # tells you which serial device to open
```

Then, in a terminal at **115200 baud**:

```
screen /dev/tty.usbserial-*  115200      # macOS, ctrl-a k to quit
picocom -b 115200 /dev/ttyUSB0           # Linux
```

Press **btn[1]** to reset. The program prints its greeting, `deadbeef`, `bss
ok`, then stops and waits — it is in `getchar()`, polling `rx_valid`. Type one
character; it comes back, followed by the cycle count and `DONE`. The LEDs show
`0x5A` at the end (`01011010`), and the whole thing takes a few milliseconds,
so it is over before you release the button.

**It will probably run more than once per press**, and that is worth watching
for. `soc_top.v` wires `btn[1]` straight to `rst` with nothing in between, so
every bounce of the contact is another reset. Captured from the board, one
press gave seven complete runs and two greetings cut off after a character or
two:

```
...DONE
RRV32I SoC          <- a reset landed 87 microseconds into the previous greeting
deadbeef
```

At 115200 baud a character takes 87 µs, so a greeting that managed one `R`
before restarting is two resets about that far apart. **That is contact bounce,
and it is the thing lesson 03 built a debouncer for** — left out here because a
repeated reset is harmless, which is exactly the judgement lesson 03 asks you to
make. Put `debounce.v` in front of `btn[1]` and the fragments disappear.

> **Measured on the board.** The six lines above are what the hardware actually
> sent: seven runs, every one byte-identical to the string `tb_soc.v` expects,
> `CYC 0000025e` included. The cycle count on real silicon is the same 606 the
> simulation produced.

With **sw[3] up** the LEDs show the machine instead of the program:

| LED | |
|---|---|
| `led[7]` | halted — `main` returned and crt0 wrote `HALT` |
| `led[6]` | fault — the deliberate wild store was caught |
| `led[5]` | illegal instruction |
| `led[4:0]` | `pc[6:2]`, the program counter in instructions |

After a run, `led[7]` and `led[6]` are both lit. `led[6]` is the address decoder
telling you about a bug that lesson 13's machine could not have noticed.

**If nothing appears:** the serial port is the same one `make prog` used, so
close the terminal program before programming and reopen it after. A screen full
of garbage is a baud mismatch; a screen full of nothing with `led[5]` lit is an
illegal instruction, which means `firmware.hex` and the memory disagree about
size or contents.

## Exercises

1. **Delete the `volatile` from the status-poll in `soc.h`** — change
   `UART_STAT`'s definition to a plain `uint32_t *`. Predict what the program
   does before you run it. (`make firmware && make sim`. Look at `make dis`
   afterwards and find the loop that no longer reloads.)

2. **Make the globals `static`** in `main.c`, then `make size`. Both `.data` and
   `.bss` go to zero and the program still prints `bss ok` — explain how it can
   possibly still be right, and what that says about what the test was testing.

3. **Comment out the `.bss` loop in `crt0.S`.** The program will probably still
   print `bss ok`, because the memory image happens to have zeros there. Now
   make it fail: add an initialised global *after* `zeroed[]` in `main.c` so the
   image has non-zero bytes nearby, and watch the loop's absence become visible.
   This is what makes crt0 bugs so unpleasant.

4. **Give the framing error a status bit.** `mmio.v` receives `frame_error` from
   the UART and drops it on the floor — the comment admits as much. Add it as
   bit 3 of `UART_STAT`, make it sticky, and clear it with `UART_ACK`. Predict
   the cost first: how many flip-flops, how many LUT4? Then `make synth M=mmio`.

5. **Shrink the memory to 256 words** (`soc.v`, `sw/link.ld` and `MEM_WORDS` in
   the `Makefile` all have to agree — the memory map written three times, and
   you find out immediately if you miss one). Predict the LUT4 saving before
   you measure it. Halving the memory saved 2,442 LUT4 going from 4 KB to
   2 KB; does halving it again save another 2,442? Explain the answer, which
   is in the table above and is not what you expect.

6. **Add a second UART** at `0x8000_0020`, and make `putchar` write to both.
   Nothing about the decoder has to change, which is the point of a memory map.

## What you should now be able to explain

- Why a peripheral needs no instruction of its own, and what `volatile` is for.
- Why this bus has no `ready` signal, and what that rules out.
- Why reading a register may not have a side effect on *this* machine.
- Why `.bss` costs nothing in the image and everything in RAM.
- Why 2 KB of memory cost 2,756 LUT4 and zero block RAMs, and what would have to
  change to get a `DP16KD`.
- Why this machine ships with 2 KB rather than 4 KB, and why that is a timing
  result rather than a preference.

**Next:** [lesson 16 — pipelining](../16-rv32i-pipeline/), which is where the
memory finally gets to be a block RAM, because a pipelined core can wait.
