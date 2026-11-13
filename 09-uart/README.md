# Lesson 09 — UART

**Concept:** agreeing about time with a device you share no clock with.

**You will build:** a transmitter, a receiver, and an echo server you can type
into from a terminal.

**Needs the board:** yes — this is the lesson where the FPGA talks to your
computer

**Prerequisites:** lesson 05 (FSMs), and lesson 04 for the synchroniser

**Paths:** editor + visual

**By the end you can:**

- Explain why a start bit exists when there is no clock on the wire.
- Compute a baud divisor and judge whether its error matters.
- Decide where in a bit to sample, and why.
- Explain why a framing error is not a reliable corruption detector.

---

## The idea

There is **no clock on the wire**. Two chips, two crystals, one signal line in
each direction. Everything depends on both ends agreeing in advance how long a
bit lasts, and on one edge to say when to start counting.

That is the whole of 8N1: a **start bit** (the line falls from idle-high), eight
**data bits least significant first**, and a **stop bit** (back high). Ten bit
periods, no handshake, no acknowledgement.

![An 8N1 frame with the receiver sampling at the midpoint of each bit](../docs/diagrams/uart-sampling.svg)

### Baud rate is a counter modulus

```
25,000,000 / 115,200 = 217.0139
```

So `DIV = 217`, giving 115,207 baud — **0.0064% fast**. Over the 9.5 bit
periods to the middle of the stop bit that accumulates to 0.06% of a bit, which
is nothing. Even `DIV = 216` or `218` would be fine, at 4.5% of a bit.

> **Why this matters** — this is lesson 00's counter again, and lesson 03's
> clock enable. A UART is a shift register and a modulus. The whole difficulty
> is deciding *when* to look, which is the receiver's problem.

## The transmitter — [`uart_tx.v`](./uart_tx.v)

The easy half: it only has to count.

```verilog
assign tx = shift[0];
...
shift <= {1'b1, data, 1'b0};        // stop, 8 data (LSB first), start
...
shift <= {1'b1, shift[9:1]};        // shift right, ones trailing in
```

The whole frame lives in one 10-bit shift register and the output is simply its
low bit. Loading `{stop, data, start}` puts the start bit on the line
immediately, and because ones trail in from the top, the register is all-ones
again when the frame finishes — so the line returns to idle with **no special
case for idle at all**. That is the kind of small structural choice worth
noticing; the alternative is a fifth state and an output mux.

`busy` is the interface, exactly as in lesson 06's SPI engine: the rest of the
design only has to not touch `data` or raise `start` while `busy` is high.

## The receiver — [`uart_rx.v`](./uart_rx.v)

The hard half, and it starts with a correction to the conventional advice.

### Why not 16× oversampling?

Every UART reference says: build a clock at 16× the baud rate, sample on the
8th tick of each bit. That is how a 16550 works, because a 16550 is *given* a
16× baud clock. Here it does not work:

```
115,200 × 16 = 1,843,200 Hz
25,000,000 / 1,843,200 = 13.5634        ← not an integer
```

| divisor | resulting baud | error | drift by the stop bit |
|---|---|---|---|
| 13 | 120,192 | +4.33% | **+41% of a bit** |
| 14 | 111,607 | −3.12% | **−30% of a bit** |

Either way the stop bit gets sampled somewhere inside bit 7 and the frame is
lost. The 16× clock is a good idea given a crystal chosen for it, and a bad
idea given a 25 MHz crystal.

### What to do instead

Count the bit period directly — which *does* divide cleanly — and sample at the
**half-way point**:

```verilog
localparam [CW-1:0] FULL_BIT = ...;     // 217
localparam [CW-1:0] HALF_BIT = ...;     // 108
```

Same underlying idea as oversampling: put the sample as far as possible from
both edges, so clock error and edge uncertainty have the most room to be wrong
in. Implemented to fit the clock you actually have.

The FSM is four states:

| state | what it does |
|---|---|
| `S_IDLE` | wait for the line to go low. No edge detector needed — the line idles high, so "low" *is* the event |
| `S_START` | wait `HALF_BIT`, landing mid-start-bit, and **check it is still low** |
| `S_DATA` | every `FULL_BIT` lands mid-bit; shift in from the top, LSB first |
| `S_STOP` | one more period reaches the stop bit, which must be high |

`S_START`'s re-check is what makes a glitch harmless. A brief disturbance on
the line looks like a start bit for a few clocks; confirming it at the midpoint
rejects it instead of reading eight bits of noise.

> **Watch out** — `rx` comes straight from a pin, driven by *another chip's
> oscillator*. It is asynchronous, so it goes through a two-flop synchroniser
> before anything looks at it. Lesson 04 exists for this moment, and this is
> the first lesson that genuinely needs it.

## The honest limit: tolerance, measured

A receiver must absorb some rate error, because two crystals never agree. Here
is this receiver's actual behaviour at `DIV = 217`, driving frames at a range
of rates:

| sender error | result |
|---|---|
| +10.7%, +8.5% | **accepted, byte WRONG** |
| +6.4% … −4.8% | accepted, byte correct |
| −6.5%, −8.1%, −9.6% | **accepted, byte WRONG** |

So the usable window is roughly **−5% to +6%**, which comfortably covers real
crystals. But look at what happens *outside* it.

The frames are not rejected. They are **accepted, with a corrupted byte and no
framing error.** Far enough off, the stop-bit sample lands somewhere inside the
data, finds a 1 by chance, and the frame passes its only check.

> **A framing error is not a reliable corruption detector.** It catches many
> cases; it does not catch all of them. Detecting the rest is a *protocol*
> job — a parity bit, or a checksum over a packet.
>
> This is why the testbench deliberately does **not** assert that mistimed
> frames are always rejected. An earlier version did, and its `PASS` message
> claimed "mistimed frames never silently corrupted" — which the sweep above
> disproves. A test that asserts something false and passes anyway is worse
> than no test.

## Simulate it

```bash
cd 09-uart
make sim
```

```
PASS: tx bit period is exactly DIV clocks, 256/256 bytes round-tripped,
exact-rate frames correct, glitches ignored (note: out-of-tolerance frames CAN
corrupt undetected - see README)
```

Five tests, and the interesting thing is how they decompose:

**The bit period is measured off the wire**, not read from a counter. Sending
`0xFF` makes the start bit the only low period on the line, so its width is one
bit period; sending `0x00` makes start-plus-eight-zeros a nine-bit-wide low
run. Together they pin down both the width and the frame structure.

**Loopback runs all 256 byte values** through `tx → rx`. Note what that proves
and what it does not: both ends share a clock and a divisor, so it cannot find
a timing problem. It finds bit-order and framing mistakes, which is worth
having, but a passing loopback says almost nothing about talking to real
hardware. The tolerance sweep is the test that does.

**A two-clock glitch produces neither a byte nor an error.**

> **Watch out — the testbench bug worth knowing about.** The first version
> asserted `start` and *then* set up a wait for the line's falling edge. The
> edge had already happened, so it measured the next one — the five-zero run
> in the middle of `0x41` — and reported 40 clocks for an 8-clock bit. The
> transmitter was correct; the test was looking in the wrong place. The fix is
> `fork`/`join`, so the monitor is already waiting before the stimulus starts.
> Measuring edges in a testbench needs this care routinely.

## What it cost

`uart_top` — both halves, the echo and the LEDs:

```bash
make synth
```

| resource | count |
|---|---:|
| `LUT4` | 91 |
| `TRELLIS_FF` | 71 |
| `CCU2C` | 8 |
| `PFUMX` | 16 |
| `L6MUX21` | 7 |

91 of the 85F's 83,640 LUT4 — 0.11% of the part.

`uart_tx` — the transmitter:

```bash
make synth M=uart_tx
```

| resource | count |
|---|---:|
| `LUT4` | 23 |
| `TRELLIS_FF` | 22 |
| `CCU2C` | 4 |
| `PFUMX` | 1 |

`uart_rx` — the receiver:

```bash
make synth M=uart_rx
```

| resource | count |
|---|---:|
| `LUT4` | 48 |
| `TRELLIS_FF` | 33 |
| `CCU2C` | 4 |
| `PFUMX` | 9 |
| `L6MUX21` | 4 |

The receiver costs more than twice the transmitter, which is the resource
footprint of the asymmetry: the transmitter knows when every bit starts, and
the receiver has to work it out.

## On the board

```bash
make prog
```

Then open a terminal on your computer:

```bash
screen /dev/cu.usbserial-*  115200       # macOS — ctrl-a k to quit
picocom -b 115200 /dev/ttyUSB0           # Linux
```

> **If output ever arrives in a staircase**, drifting right instead of
> returning to the left margin, the device is sending LF without CR. A
> terminal takes those as two separate instructions: LF drops a row, CR
> returns to column one. The fix belongs in the firmware — lesson 15's
> `putchar` expands `'\n'` for exactly this reason — but `picocom --imap
> lfcrlf` will translate on the way in for a device you cannot change.
> `screen` has no equivalent option.

Type. Characters come back, and the LEDs show the byte you last sent — so
pressing `A` lights `0x41` = `01000001`. Hold `btn[1]` to see framing-error and
dropped-byte counts instead, which is how you tell a baud mismatch from a
wiring mistake.

> **Watch out — the classic afternoon-loser.** The pin names are from the
> **FTDI's** point of view:
>
> | pin | the FTDI… | so the FPGA… |
> |---|---|---|
> | `ftdi_rxd` | receives | **drives** it — our `tx` |
> | `ftdi_txd` | transmits | **reads** it — our `rx` |
>
> So `output ftdi_rxd` and `input ftdi_txd` are correct and look backwards.
> `ftdi_txden` must be driven high to enable the FPGA's side.

The echo connects `rx_valid` straight to `tx_start`, which is safe here: a byte
takes 87 µs to send and a host cannot deliver two inside that. It would **not**
be safe in general — a faster link, or a pasted kilobyte, would overrun it. The
fix is a FIFO, which lesson 15 needs anyway.

## Icestudio

```bash
open 09-uart/icestudio/uart_tx.ice
```

The transmitter as a block: data in, `start` in, a line out and a `busy` flag.
`CLK_HZ` and `BAUD` are constants you can edit — set `BAUD` to 9600 and
rebuild, then open your terminal at 9600 and watch it still work.

## Exercises

1. **Reproduce the tolerance sweep.** Drive `uart_rx` at `DIV=217` with sender
   periods from 196 to 240 and record which are accepted correctly. Find the
   exact boundary in each direction.
2. **Add a parity bit.** Odd parity, as a 9th data bit. This is the fix for the
   silent-corruption window above — how much of it does parity actually close?
3. **Break the mid-bit sample.** Change `HALF_BIT` to `0` so the receiver
   samples at the *start* of each bit instead of the middle. Loopback still
   passes. Now run the tolerance sweep and watch the window collapse.
4. **Drop the synchroniser.** Feed `rx` directly into the FSM. Everything still
   works in simulation and probably on the board, and it is still wrong —
   explain why, using lesson 04.
5. **Send a string.** Add a small ROM of characters and an FSM that transmits
   them in order on a button press, so the board greets you when you press it.

## Wrap-up

**What you built.** A UART transmitter and receiver that talk to a terminal over the same cable that programs the board — 23 LUT4 against the receiver's 48.

**What to keep.** The receiver pays, in logic, for not knowing when the bits start.

**What comes next.** Lesson 10 begins the processor. The UART comes back in lesson 15 as its console.
