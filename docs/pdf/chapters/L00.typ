#import "../style.typ": *

= Lesson 00 — Blinky

#goals(
  concept: [A counter is a frequency divider.],
  build: [The 8 LEDs counting up as a binary odometer.],
  needs: [Nothing. This is the start.],
)[
  - Explain why bit #emph[n] of a counter toggles every 2#super[n] clocks.
  - Use non-blocking assignment in a clocked block, and say why.
  - Make a design's time constant a parameter, so it can be simulated.
  - Read a resource report and account for what is in it.
]

== The idea

The board's crystal runs at 25 MHz. An LED toggling at that rate looks like an
LED that is simply on, so to see anything the clock must be divided by tens of
millions.

The cheapest divider in digital design is a binary counter. Add one to a
register every clock and bit #emph[n] toggles every 2#super[n] clocks: bit 0 at
12.5 MHz, bit 1 at 6.25 MHz, and so on. Nothing is *built* to divide — the
division is what counting already is, read one bit at a time.

#fig("/figures/blink-counter.svg",
     [Tapping the top eight bits of a 26-bit counter. At 25 MHz, bit 25
      toggles every 1.34 seconds.])

#fig("/figures/blink-divide.svg",
     [Each bit halves the frequency of the one below it — the whole of clock
      division, in one picture.])

== Theory

=== Non-blocking assignment

```verilog
always @(posedge clk)
    count <= count + 1'b1;
```

`<=` is non-blocking: every right-hand side in the block is evaluated before
any left-hand side updates. That is what a bank of real flip-flops does — all
of them sample their inputs at the same instant. Lesson 03 measures what
happens when you use `=` instead, and the answer is two flip-flops fewer than
you asked for.

=== Parameterised time constants

The testbench overrides `WIDTH` from 26 to 8, so the simulation finishes in
milliseconds rather than simulating 67 million clock cycles. #strong[Making a
design's time constant adjustable is what makes slow hardware testable], and
it is a habit every later lesson depends on — lesson 03's debouncer and lesson
09's baud generator both do it.

=== Part-select

```verilog
assign led = count[WIDTH-1 -: 8];
```

"Eight bits, counting downward from `WIDTH-1`." Writing `count[25:18]` means
the same thing until someone changes `WIDTH`, at which point it silently reads
out of range.

== What it cost

#measured("a 26-bit counter")[
  #ttable(
    columns: (auto, auto, 1fr),
    [`TRELLIS_FF`], [26], [one flip-flop per counter bit, as expected],
    [`CCU2C`],      [13], [the ECP5's carry cells — #strong[two bits each]],
    [`LUT4`],       [1],  [],
  )
  Thirteen carry cells do 26 bits of addition in dedicated hardware, which is
  why a wide counter is nearly free. The general-purpose logic contributes a
  single LUT.
]

#why[
  This is the first appearance of the course's central method. The number is
  not "about thirty cells"; it is 26 flip-flops and 13 carry cells, and both
  are explainable. When a resource report contains something you cannot
  explain, you have inferred something you did not intend.
]

== Learning outcomes

By the end you should be able to say, without looking anything up, why bit 25
of a counter clocked at 25 MHz toggles roughly every 1.3 seconds; why `<=`
belongs in a clocked block; and why a 26-bit counter costs one LUT rather than
twenty-six.
