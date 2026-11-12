# Lesson 06 — SPI and the OLED

**Concept:** an FSM that talks to a real chip, on that chip's terms.

**You will build:** the SSD1331 colour OLED brought up from cold and filled
with an animated gradient — with no framebuffer anywhere.

**Needs the board:** yes, to see it (the testbench proves it without one)

**Prerequisites:** lesson 05 (FSMs)

**Paths:** editor + visual

**By the end you can:**

- Read a datasheet's timing requirements and turn them into clock counts.
- Set up data before clocking it, and say why that ordering is universal.
- Use a `busy`/`start` handshake to separate timing from sequencing.
- Recognise when a design needs no frame buffer at all.

---

## The idea

Everything so far has been self-contained: your logic, your clock, your
decisions. This lesson is the first one where another piece of silicon has
opinions, written down in a datasheet, and your design has to satisfy them.

The SSD1331 is a 96×64 OLED controller speaking 4-wire SPI. The contract is:

- **SCLK** — you supply the clock. Maximum about 6.6 MHz.
- **MOSI** — one bit per SCLK, most significant first.
- **D/C** — a *level*, not a bit in the stream: low means "this byte is a
  command", high means "this byte is pixel data".
- **RES#** — hold it low on power-up, then release it and wait.

Three things have to be built, and they stack:

1. A **bit-level engine** that shifts 8 bits out at a legal clock rate.
2. An **initialisation sequence** — 31 bytes from the datasheet, in order.
3. A **pixel source** that keeps feeding bytes forever after that.

![One SPI byte: four system clocks per bit](diagrams/spi-byte.svg)

Four system clocks per bit gives 25 MHz / 4 = **6.25 MHz** SCLK, comfortably
under the 6.6 MHz limit. The phases do distinct jobs: drive MOSI on phase 0,
raise SCLK on phase 2 so the data has been stable for two clocks before the
chip samples it, and advance the shift register on phase 3.

> **Why this matters** — "set up the data, *then* clock it" is the whole of
> synchronous interface design. The same reasoning sets the sample point in
> lesson 07's UART receiver.

## The design

[`oled_top.v`](./oled_top.v) is three cooperating pieces.

**The SPI engine** is a shift register with a 2-bit phase counter and a `busy`
flag:

```verilog
always @(posedge clk_25mhz) begin
    if (!busy) begin
        if (start) begin shift <= data; busy <= 1; phase <= 0; bitn <= 0; end
    end else begin
        phase <= phase + 1'b1;
        case (phase)
            2'd0: begin oled_clk <= 0; oled_mosi <= shift[7]; end
            2'd2: oled_clk <= 1;
            2'd3: begin
                shift <= {shift[6:0], 1'b0};
                bitn  <= bitn + 1'b1;
                if (bitn == 3'd7) busy <= 0;
            end
        endcase
    end
end
```

`busy` is the entire interface. Everything above it only has to obey one rule:
do not touch `data` or raise `start` while `busy` is high. That is a
*handshake*, and it is why the sequencer above can be written without knowing
anything about SPI timing.

**The init ROM** is 31 bytes straight out of the datasheet's power-up sequence,
in a `reg [7:0] rom [0:30]` with an `initial` block. Each byte is commented with
what it does, because in six months nobody — including you — will remember what
`8'hAD, 8'h8E` means.

**The sequencer** is a four-state FSM: hold reset, wait for the chip to wake,
push the 31 init bytes, then stream pixels forever.

```verilog
S_PIXEL: if (!busy && !start) begin
    oled_dc <= 1;
    data    <= lohi ? pixel[7:0] : pixel[15:8];
    start   <= 1;
    lohi    <= ~lohi;
    if (lohi) begin ... advance x, then y, then frame ... end
end
```

And the pixel itself is not stored anywhere — it is *computed* from the current
coordinate:

```verilog
wire [15:0] pixel = { x[6:2], y[5:0], frame[7:3] };
```

**There is no framebuffer.** 96 × 64 × 16 bits is 98,304 bits, which would fit
in the ECP5's block RAM easily — but it is not needed, because the SSD1331's
internal address pointer auto-increments. Set the column and row window once
during init, then every data byte lands in the next pixel automatically. The
design just has to produce bytes in raster order, and `x`/`y` counters that
mirror the chip's own pointer are enough.

> **Watch out** — `start <= 0;` sits at the top of the sequencer's `always`
> block, before the `case`. That makes `start` a one-clock pulse by default,
> which any branch can override. Forget it and `start` stays high, the engine
> re-triggers immediately, and you will send one byte 25 million times a second.

## Simulate it

```bash
cd 06-spi-oled
make sim
```

```
PASS: 157 bytes, init sequence + pixel stream OK
```

The testbench shortens the reset and wake-up delays (they are milliseconds of
real time, which is minutes of simulation), then decodes the SPI stream the way
the OLED would: it samples MOSI on each rising SCLK edge, assembles bytes,
checks the first 31 against the expected init sequence with `oled_dc` low, and
then confirms data bytes keep arriving with `oled_dc` high.

That it reconstructs bytes from the wire rather than peeking at internal
signals is the point — it tests the contract the OLED cares about, so it would
catch a bit-order or clock-phase error that an internal check would miss.

```bash
make wave
```

Look at `oled_clk`, `oled_mosi` and `phase` together, zoomed in on a single
byte, and check it against the timing diagram above. Then zoom out to see the
init sequence as 31 bursts followed by an unbroken pixel stream.

## What it cost

`oled_top` — the whole display controller:

```bash
make synth
```

| resource | count |
|---|---:|
| `LUT4` | 108 |
| `TRELLIS_FF` | 72 |
| `CCU2C` | 22 |
| `PFUMX` | 29 |
| `L6MUX21` | 4 |

108 of the 85F's 83,640 LUT4 — 0.13% of the part.

Seventy-two flip-flops: the shift register, the phase and bit counters, the
state, the wait counter, and the x/y/frame counters. The 29 `PFUMX` cells are
multiplexers — mostly the 31-entry init ROM, which yosys built out of logic
rather than memory because it is far too small to be worth a block RAM. Lesson
08 is about when that decision goes the other way.

## On the board

```bash
make prog
```

A smooth colour gradient across the 96×64 panel, drifting slowly as `frame`
increments. If the panel stays black, the usual causes are reset timing (the
chip needs real milliseconds after `RES#` rises) and SCLK being too fast.

## Icestudio

```bash
open 06-spi-oled/icestudio/oled.ice
```

The block view earns its keep here: you can see the SPI engine, the sequencer
and the pixel generator as three boxes with the `busy`/`start` handshake drawn
between them, which is exactly the structure that is hardest to see in the text.

## Exercises

1. **Change the pixel function.** `{x[6:2], y[5:0], frame[7:3]}` is arbitrary.
   Make it a checkerboard: `(x[3] ^ y[3]) ? 16'hFFFF : 0`. Note that you are
   changing one `wire` and nothing else — the stream machinery does not care.
2. **Break the handshake.** Remove the `!start` from `if (!busy && !start)`.
   The simulation will still look plausible. Find the duplicated byte in the
   waveform.
3. **Speed up SCLK.** Make the engine 2 clocks per bit instead of 4 (12.5 MHz).
   The simulation will pass. The hardware probably will not. This is the
   lesson's real point: a passing testbench is necessary and not sufficient when
   another chip's datasheet is involved.
4. **Add a command.** Send `0xA7` (invert display) after init and watch the
   colours flip.
5. **Count the bytes.** How many SPI bytes per frame, and therefore what is the
   frame rate at 6.25 MHz SCLK? Check your arithmetic against the waveform.

## Wrap-up

**What you built.** An SPI controller driving a colour OLED, built from a datasheet's timing requirements — 108 LUT4 and 72 flip-flops.

**What to keep.** A datasheet becomes clock counts, and clock counts become states.

**What comes next.** Lesson 07 puts readable text on that display, which needs a ROM and some coordinate arithmetic.
