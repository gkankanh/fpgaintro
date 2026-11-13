# Lesson 08 — memories

**Concept:** you do not instantiate a block RAM. You write Verilog in a
particular shape and the synthesiser recognises it — and the shapes that *look*
tidier are the ones that cannot.

**You will build:** the four memory configurations the fabric offers, a ROM
loaded from a hex file, a dual-port framebuffer, and a memory self-test that
runs on the board.

**Needs the board:** yes, for the self-test

**Prerequisites:** lesson 07

**Paths:** editor only

**By the end you can:**

- Write the coding pattern that infers block RAM, and spot the ones that cannot.
- Explain why a combinational read rules out block RAM at any size.
- Know roughly where the size threshold between logic and memory sits.
- Present address, write-enable and write-data in the same cycle.

---

## The idea

Lesson 07 ended with a puzzle. A 32-byte font ROM synthesised into **185 LUT4s
and no block RAM at all**, on a chip with 208 block RAMs sitting idle. This
lesson resolves it, and the resolution matters because every remaining lesson
needs memory: the CPU's instruction store, its data store, its register file,
the framebuffer its C code will draw into.

The ECP5 has **208 × DP16KD** blocks — 18,432 bits each, about 3.7 Mbit in
total, true dual-port, with a registered output. You cannot instantiate one
directly in this course's style. Instead you write an array and the synthesiser
infers it, and the inference has conditions:

- the array is a `reg [W-1:0] mem [0:DEPTH-1]`
- reads and writes happen inside `always @(posedge clk)`
- **the read result goes into a register**

That last one is not a style preference. A block RAM's output is registered
*inside the block*, physically. So a combinational read is not something a
DP16KD can do, and asking for one quietly takes block RAM off the table —
permanently, at any size.

> **Why this matters** — this is the first lesson where getting the shape wrong
> does not merely cost you some LUTs. At realistic sizes it produces a design
> that does not fit in the part at all, and the error message will not mention
> the line that caused it.

## Four memories — [`ram.v`](./ram.v)

Four modules that differ only in small ways, so the small ways are the lesson.
All default to `W = 32`, the CPU's width.

**`ram_sp`** — single port, synchronous read. The canonical shape.

```verilog
always @(posedge clk) begin
    if (we) mem[addr] <= din;
    dout <= mem[addr];        // registered: available NEXT clock
end
```

**`ram_async`** — identical, except the read is combinational:

```verilog
assign dout = mem[addr];      // NOT something a BRAM can do
```

**`ram_sdp`** — simple dual port: one write port, one read port, independent
addresses, optionally **independent clocks**. What a framebuffer wants, and
what a CPU's instruction memory wants.

**`ram_tdp`** — true dual port: both ports read and write.

> **Watch out** — in `ram_tdp`, if both ports address the same word in the same
> cycle and at least one is writing, the result is **undefined**. Real silicon
> gives you something that depends on the block's configuration; simulation
> gives you whichever assignment ran last. The testbench deliberately does not
> assert on this case, because asserting any particular answer would be
> recording a simulator artefact as a fact. Arbitrate outside the memory, or
> guarantee by construction it cannot happen.

## The measurement

The whole lesson, in one table. `W = 32`, measured with `make synth`:

| DEPTH | `ram_sp` — synchronous read | `ram_async` — combinational read |
|---|---|---|
| 16 | 8 `TRELLIS_DPR16X4` + 32 `TRELLIS_FF` | **8 `TRELLIS_DPR16X4`** |
| 64 | **1 `DP16KD`** | 32 `TRELLIS_DPR16X4` + 132 LUT4 + 96 muxes |
| 256 | **1 `DP16KD`** | 128 `TRELLIS_DPR16X4` + **919 LUT4** + 672 muxes |
| 1024 | **2 `DP16KD`** | *(don't)* |

Three readings.

**At 256 entries, the asynchronous version costs 919 LUT4s where the
synchronous one costs one block RAM.** Same data, same functionality, one line
different. `TRELLIS_DPR16X4` is *distributed* RAM — 16 words of 4 bits built
out of a logic cell's LUTs — so the array becomes a pile of those plus an
enormous mux tree to select among them.

**At 1024 × 32 the synchronous version is 2 `DP16KD` and nothing else.** 32,768
bits, and a DP16KD holds 18,432, so two blocks. Clean inference, zero LUTs.

**And look at the top row.** At 16 entries *both* produce distributed RAM, and
the asynchronous one is **cheaper** — it needs no output register. Small
asynchronous arrays have a legitimate home, and that is exactly how a 16-entry
register file gets built. The threshold is tens of entries, not thousands. The
rule is not "always synchronous"; it is "synchronous once it is big enough to
want a block, and know where that line is".

## Lesson 07's puzzle, answered — [`rom.v`](./rom.v)

Two ROMs, identical in shape, differing only in size:

`font_small` — 32 bytes, lesson 07's font:

```bash
make synth M=font_small
```

| resource | count |
|---|---:|
| `LUT4` | 9 |
| `TRELLIS_FF` | 5 |
| `PFUMX` | 4 |

`font_full` — 1,024 bytes, 128 characters × 8 rows:

```bash
make synth M=font_full
```

| resource | count |
|---|---:|
| `DP16KD` | 1 |

So lesson 07's font became logic because it was *too small to be worth a
block*. One DP16KD holds 18,432 bits; spending a whole one on 256 bits wastes
98.6% of it, and there are only 208.

The right conclusion is not "use logic for small memories". It is: **write the
memory in the shape that CAN become a block RAM, and let the synthesiser decide
on size.** Writing it in a shape that cannot — an asynchronous read — takes the
decision away for good.

### `$readmemh`

```verilog
initial $readmemh("font.hex", mem);
```

This runs at **elaboration time**, not at runtime. yosys reads the file during
synthesis and bakes the contents into the bitstream, exactly as it would an
`initial` block of literals. [`font.hex`](./font.hex) is therefore a **source
file** — change it and you must resynthesise.

This is the path lesson 13 uses to load a program into instruction memory, and
lesson 15 uses for a program compiled by `riscv-gcc`:

```
riscv-gcc → objcopy → .hex → $readmemh → block RAM
```

> **A curiosity worth knowing** — `font.hex` begins with ASCII 0–31, which have
> no glyphs, so its first 256 bytes are all zero. Synthesise `rom` at
> `DEPTH=256` and yosys emits **no memory at all**: it folds the whole thing to
> a constant zero, correctly, because that is what it is. `DEPTH=512` reaches
> real data and produces 1 DP16KD.
>
> So "my ROM disappeared" is usually not a tool bug. It means the contents were
> constant — the file was not found, or was empty, or was genuinely all one
> value across the range you used.

## The framebuffer — [`framebuffer.v`](./framebuffer.v)

A display memory is written one way and read another, simultaneously:

- **written** by coordinate, in whatever order the drawing code likes
- **read** in raster order, relentlessly, because the display never stops

One port cannot serve both without one side waiting. A simple dual-port memory
serves both at once, which is largely why the DP16KD exists.

96 × 64 is 6,144 pixels. At one bit per pixel that is 6,144 bits — a third of
one block. Colour is applied on the way out, so a mono framebuffer plus a
palette costs a third of a block where 16-bit colour would cost six.

And then the address arithmetic taught me something:

```verilog
wire [15:0] waddr = wy * W + wx;     // W = 96
```

I wrote a comment confidently predicting yosys would reduce a constant multiply
to shifts. It did not — it allocated **2 `MULT18X18D`**, the ECP5's hardware
multipliers, to multiply by a constant. Writing the cheap form explicitly:

```verilog
wire [15:0] waddr = (wy << 6) + (wy << 5) + wx;   // 96 = 64 + 32
```

| | cost |
|---|---|
| `wy * 96 + wx` | 1 `DP16KD` + **2 `MULT18X18D`** + 8 `CCU2C` |
| `(wy<<6) + (wy<<5) + wx` | 1 `DP16KD` + 14 `CCU2C` + 24 `LUT4` |

> **Third time in this course** — the synthesiser is very good and still does
> not read your mind. Lesson 01: it discarded your structure. Lesson 02: it
> kept your structure and missed the carry chain. Lesson 04: you cannot read
> your critical path off your source. Here: it spent a DSP block on a constant.
> **If you know the cheap form, write the cheap form, then check `make synth`
> to see whether it mattered.**

## Simulate it

```bash
cd 08-memory
make sim
```

```
PASS: sync read has 1-cycle latency, dual-port reads and writes are
independent, font ROM matches font.hex, framebuffer round-trips coordinates,
self-test clean
```

The recurring theme is **latency**. Every synchronous memory here returns data
one clock after the address, and the testbench proves it rather than assuming
it:

```verilog
@(negedge clk); sp_addr = 8'd200;
#1;
if (sp_dout !== 32'hDEAD_BEEF)      // still the OLD location
    fail("ram_sp read is not registered - that shape cannot be a BRAM");
@(posedge clk); #1;
if (sp_dout !== 32'h0123_4567) fail("ram_sp second location wrong");
```

Change the address, look *before* the next edge: the output must still show the
previous location. A combinational read would have followed instantly. That
single check is what distinguishes a BRAM-shaped memory from a LUT-shaped one.

> **Watch out** — uninitialised memory reads as **X** in simulation. The ECP5
> happens to zero its block RAM from the bitstream, but Verilog does not
> promise it. An earlier version of this testbench checked that an unwritten
> framebuffer pixel read as 0 and failed; it now writes the zeros explicitly.
> A test that relies on initialisation is testing the simulator.

## The self-test — [`mem_test.v`](./mem_test.v)

Simulation proves the Verilog. It does not prove that the bits yosys placed in
a DP16KD store and return correctly on real silicon. So: an FSM (lesson 05)
that walks every address writing a pattern, walks every address reading it back,
and reports.

Two design points carry the lesson.

**The pattern is derived from the address**, not constant:

```verilog
expected = {{(W-AW){1'b0}}, a} ^ SALT;
```

With a constant pattern every location holds the same value, so reading the
*wrong* address looks correct and an addressing fault passes the test.

**Reading takes two states, not one:**

```verilog
S_READ_ISSUE: begin check_addr <= addr; state <= S_READ_CHECK; end
S_READ_CHECK: if (dout !== expected(check_addr)) errors <= errors + 1'b1;
```

Because the read is registered, the data for `addr` arrives the cycle *after*
`addr` is presented. Every design that reads a block RAM pays this. Forgetting
it is the most common BRAM bug there is.

> **Watch out — the bug this lesson actually hit.** The first version of
> `mem_test` registered the write data: `din <= expected(addr)` inside the
> clocked block. Every single location then held its *neighbour's* value,
> because by the time the RAM performed the write on the following edge, `addr`
> had already advanced. 128 errors out of 128.
>
> A memory's address, write-enable and write-data must be presented in the
> **same cycle**. Register some and not others and they arrive skewed, and the
> memory faithfully stores the skew.

## What it cost

`mem_top` — the whole design:

```bash
make synth
```

| resource | count |
|---|---:|
| `LUT4` | 80 |
| `TRELLIS_FF` | 61 |
| `CCU2C` | 27 |
| `PFUMX` | 6 |
| `DP16KD` | 2 |

80 of the 85F's 83,640 LUT4 — 0.10% of the part.

Two block RAMs: 1024 × 32 bits is 32,768 bits, and a DP16KD holds 18,432. Out
of 208 blocks on the part, so this design uses **1%** of the memory and would
have used 0% of it had the read been written combinationally — while consuming
far more logic than the whole rest of the course.

## On the board

```bash
make prog
```

- `btn[1]` — start the test
- `led[7]` — **pass** (finished with zero errors)
- `led[6]` — done, `led[5]` — busy
- `led[4:0]` — progress while running, error count when finished

1024 words of 32 bits is about 3,000 clocks to write and read, so at 25 MHz the
whole test is over in roughly **120 µs**. Press the button and `led[7]` and
`led[6]` are already lit — you will not see the busy phase.

If `led[6]` lights and `led[7]` does not, the error count on `led[4:0]` tells
you how many locations failed. On working hardware that should never happen,
which is rather the point of running it.

## Icestudio

```bash
open 08-memory/icestudio/font.ice
```

`font_small` with its address on your fingers. `sw2..sw0` picks the row, FIRE2
and `sw3` pick the glyph, and the eight LEDs are the byte that comes back — so
you can read H, E, L and O out of the lights one row at a time.

The info panel carries the numbers this lesson is about: 32 x 8 = 256 bits
synthesises to 9 LUT4, 4 PFUMX and 5 flip-flops with **no** block RAM, while
lesson 07's 8 Kbit `font_full` becomes exactly 1 DP16KD from the same five
lines of Verilog. The registered-read shape gives yosys the choice; the size
decides which way it jumps.

## Exercises

1. **Watch the shape matter.** Synthesise `ram_sp` and `ram_async` at
   `DEPTH=256` and reproduce the table above:
   `yosys -p "read_verilog ram.v; chparam -set DEPTH 256 ram_async; synth_ecp5 -top ram_async; stat"`
2. **Find the threshold.** Sweep `ram_sp`'s DEPTH between 16 and 64 and find
   exactly where yosys switches from distributed RAM to a DP16KD. Is it a round
   number? Why might it not be?
3. **Break the self-test deliberately.** Change `expected` to return a constant
   and then make `mem_test` read `addr ^ 1` instead of `addr`. The test should
   pass, wrongly — which is the argument for address-derived data.
4. **Widen the framebuffer.** Make it 16-bit colour instead of 1-bit. How many
   DP16KDs? Does the design still fit comfortably?
5. **Put the multiplier back.** Revert the framebuffer address to `wy * W + wx`
   and confirm the two `MULT18X18D` return. Then try a width of 128 instead of
   96 and see what happens to both forms — and why.

## Wrap-up

**What you built.** Block RAM, distributed RAM and a dual-port framebuffer, with the synchronous and combinational forms measured against each other from 16 entries to 1024.

**What to keep.** Write the shape that *can* become a block RAM and let size decide.

**What comes next.** Lesson 09 is the last peripheral before the processor — and lesson 11's register file is this lesson's threshold question asked again.
