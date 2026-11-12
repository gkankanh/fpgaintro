# Lesson 00 — blinky

**Concept:** a counter is a frequency divider, and the whole toolchain in one
go.

**You will build:** the 8 LEDs on the board counting up as a binary odometer.

**Needs the board:** no (but it is the payoff)

**Prerequisites:** none — start here.

**By the end you can:**

- Explain why bit *n* of a counter toggles every 2ⁿ clocks.
- Use non-blocking assignment in a clocked block, and say why.
- Make a design's time constant a parameter, so it can be simulated.
- Read a resource report and account for what is in it.

---

## The idea

The ULX3S has a 25 MHz crystal. That is 25 million clock edges per second, and
an LED toggling at that rate looks like an LED that is simply on. To see
anything you have to divide the clock down by a factor of tens of millions.

The cheapest divider in all of digital design is a binary counter. Add one to a
register every clock, and bit *n* of that register toggles every 2<sup>n</sup>
clocks: bit 0 at 12.5 MHz, bit 1 at 6.25 MHz, and so on. Nothing special is
built to divide — the division is just what counting *is*, read one bit at a
time.

![A 26-bit counter clocked at 25 MHz, with its top 8 bits tapped to drive the LEDs](../docs/diagrams/blink-counter.svg)

At 25 MHz, bit 25 toggles every 2<sup>25</sup> / 25,000,000 ≈ **1.34 seconds**.
So a 26-bit counter puts its top bits squarely in human territory, and tapping
the top eight gives an odometer: `led[0]` flickering, `led[7]` crawling.

![Each counter bit halves the frequency of the one below it](diagrams/blink-divide.svg)

> **Why this matters** — this is also how you will build every baud rate
> generator, every SPI clock and every refresh timer in this course. Lesson 07
> divides 25 MHz by 217 to get 115200 baud. Same idea, different modulus.

## The design

The whole thing is [`blink.v`](./blink.v), and it is 13 lines:

```verilog
module blink #(
    parameter WIDTH = 26          // 2^26 / 25MHz ~ 2.7s period
)(
    input  wire        clk_25mhz,
    output wire [7:0]  led
);
    reg [WIDTH-1:0] count = 0;
    always @(posedge clk_25mhz)
        count <= count + 1'b1;
    assign led = count[WIDTH-1 -: 8];   // top 8 bits: binary odometer
endmodule
```

Three decisions worth naming:

**`WIDTH` is a parameter, not a constant.** The testbench overrides it to 8 so
the simulation finishes in milliseconds instead of simulating 67 million clock
cycles. Making the time constant adjustable is what makes the design testable —
a habit worth forming now, because every later lesson depends on it.

**`<=`, not `=`.** Non-blocking assignment is what a bank of real flip-flops
does: every bit samples its input and they all update together at the end of
the clock edge. See [the style rules](../docs/src/reference-style.md) for what
goes wrong with `=`.

**`count[WIDTH-1 -: 8]`** is the part-select operator: "8 bits, counting
downward from `WIDTH-1`". It means the same as `count[25:18]` but keeps working
when you change `WIDTH`. Writing `count[25:18]` and then changing `WIDTH` to 20
gives you a silent out-of-range read.

**`reg [WIDTH-1:0] count = 0;`** The initial value is not a reset — there is no
reset in this design. The ECP5 loads flip-flop initial values straight from the
bitstream, so the counter genuinely starts at zero on power-up. Convenient, and
used throughout this course; not portable to an ASIC, where you would need an
explicit reset.

> **Watch out** — the counter wraps silently from all-ones to zero. That is
> exactly what you want here, and exactly what you do *not* want in lesson 07's
> baud counter, which must reset at a specific modulus. Overflow is a design
> decision, not an accident.

## Simulate it

```bash
cd 00-blinky
make sim
```

```
PASS: 8 toggles, period 256 clks
```

The testbench ([`tb_blink.v`](./tb_blink.v)) instantiates the design with
`WIDTH = 8`, watches `led[7]`, and checks two things: that it toggled 8 times,
and that consecutive rising edges are 256 clocks apart — because with
`WIDTH = 8` the top bit is `count[7]`, which toggles every 2<sup>7</sup> = 128
clocks and so has a 256-clock period.

That it checks the *period* and not merely that something moved is the point.
"The LED changed" passes for a design that is wrong by a factor of two.

```bash
make wave
```

In gtkwave, look at `count[7:0]` as an analogue trace: a perfect sawtooth. Then
look at the individual bits stacked up and you can see each one running at half
the rate of the one below — the picture above, in your own waveform.

## See the structure

```bash
make graph      # -> blink.svg
```

The schematic shows something the source does not: there is no "divider" in the
design. There is an adder, a register, and eight wires leaving the register's
high end. The frequency division is not a component; it is an interpretation of
where you tap.

## What it cost

`blink` — the whole design:

```bash
make synth
```

| resource | count |
|---|---:|
| `LUT4` | 1 |
| `TRELLIS_FF` | 26 |
| `CCU2C` | 13 |

1 of the 85F's 83,640 LUT4 — less than 0.01% of the part.

Twenty-six flip-flops — exactly one per counter bit, as you would expect.

The interesting number is `CCU2C`: thirteen of them. That is the ECP5's
dedicated carry-chain cell, and each one handles **two** bits of an adder. So
13 × 2 = 26 bits of ripple-carry addition, built from hard carry logic rather
than general-purpose LUTs. This is why a wide counter is nearly free on an
FPGA: the fabric has a purpose-built adder running up each column of logic
cells, and yosys used it instead of spending 26 LUTs.

For scale, the 85F has 83,640 flip-flops. This design uses 0.03% of them.

## On the board

```bash
make prog      # into SRAM; gone when you unplug it
make flash     # into SPI flash; boots on power-up
```

You should see the LED row counting in binary, `led[0]` toggling about twice a
second and `led[7]` taking about three minutes for a full cycle. Give it a few
seconds before concluding it is broken — the slow bits are *slow*.

If nothing lights up: check you are using the FPGA USB port rather than the
ESP32 one, and run `openFPGALoader --detect -b ulx3s` to confirm the board is
seen at all.

## Icestudio

```bash
open 00-blinky/icestudio/blink.ice
```

The same design as a diagram: a clock input bound to ball G2, a code block
holding the counter, and an 8-bit output bus bound to the eight LED balls. The
`WIDTH` constant is a block you can edit — change it to 24 and rebuild to make
the odometer run four times faster.

This project is generated from `blink.v` by `tools/mkice.py`, so it is the same
design rather than a second copy of it. Run `make ice` from the repository root
after editing the Verilog.

## Exercises

1. **Predict, then check.** Change `WIDTH` to 24 in the Icestudio constant
   block or in `blink.v`. How much faster does `led[7]` move? Work it out
   before you rebuild.
2. **Break the testbench's assumption.** Change `assign led = count[7:0]` to
   tap the *bottom* 8 bits. `make sim` should still pass — why? Fix the
   testbench so it catches this. (This is the useful bit: a test that passes a
   wrong design is worse than no test.)
3. **Use blocking assignment.** Change `<=` to `=` in the `always` block. Does
   the simulation still pass? Does `make graph` look different? This one
   happens to be harmless — a single register has no ordering to get wrong —
   which is exactly why the habit must come from discipline rather than from
   being bitten.
4. **Add a reset.** Wire `btn_1` to a synchronous reset that zeroes the
   counter. You will discover the button is not debounced, and that the LEDs do
   not care. Lesson 03 is about why they will start caring.
5. **Count down.** `count <= count - 1'b1`. Check `make synth` — does
   subtraction cost more than addition on this fabric?

## Wrap-up

**What you built.** A 26-bit counter dividing the board's 25 MHz down to something an eye can follow, simulated at a smaller width and accounted for down to the last flip-flop.

**What to keep.** A counter is a frequency divider, and a resource report is something you read rather than glance at.

**What comes next.** Lesson 01 goes underneath it, to what the fabric actually builds when you write a logic expression.
