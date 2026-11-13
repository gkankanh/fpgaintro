#import "../style.typ": *

= Lesson 04 — Clocks and timing

== The idea

Three lessons used `clk_25mhz` as if it were simply given. It is not.

=== Setup, hold, and the critical path

A flip-flop needs its data input stable #emph[before] the clock edge (setup)
and #emph[after] it (hold). Between any two flip-flops there is a budget: one
clock period, minus the first flop's output delay, minus the second's setup
time. Everything else is available for logic and routing.

The longest such path in the design sets the maximum frequency:

$ "max frequency" = 1 / "critical path delay" $

#fig("/figures/timing-budget.svg",
     [One clock period, as a budget. Everything the data must do between two
      flip-flops has to fit inside it, and what is left over is the slack
      nextpnr reports.])

#why[
  So #strong[a design is not correct or incorrect in isolation — it is correct
  at a frequency.] The same Verilog that works at 25 MHz may fail at 100, and
  nothing in the source says which. This is also the real argument for
  pipelining, twelve lessons early: lesson 16 splits the CPU into five stages
  not for elegance but because a shorter critical path permits a faster clock.
]

=== Enables, not gated clocks

Lesson 00 divided the clock with a counter and used the result as #emph[data].
Using it as a #emph[clock] is the mistake worth naming:

```verilog
wire tick = (div == LIMIT);                        // yes: an enable
always @(posedge clk_25mhz) if (tick) count <= count + 1'b1;

always @(posedge div[15]) count <= count + 1'b1;   // no: a derived clock
```

An FPGA has a small number of #strong[global clock networks] — dedicated
low-skew routing that reaches every flip-flop at very nearly the same instant.
A signal generated in logic travels on ordinary routing, arrives at different
flops at measurably different times, and the timing analyser can no longer give
a meaningful answer. You can watch the allocation happen in the build log:

```
Info:  promoting clock net clk_100mhz to global network
Info:  routing clock net $glbnet$clk_100mhz using global 1
```

== The PLL is a hard block

The ECP5's `EHXPLLL` is a real analogue phase-locked loop in the corner of the
die, not logic. Its parameters are computed by a calculator rather than chosen:

```
ecppll -i 25 -o 100 --clkout1 40
  -> VCO 600 MHz, divisors 6 and 15
```

The VCO must land in its legal range (roughly 400–800 MHz) and #strong[every
output is that one VCO frequency divided by an integer]. You cannot ask for an
arbitrary pair of frequencies.

Three consequences:

+ #strong[It cannot be simulated.] Icarus has no model and Verilator has no
  definition. This is the first lesson where what you simulate and what you
  synthesise differ — the lesson's Makefile names a simulatable subset, and the
  PLL is verified structurally and on hardware instead.
+ #strong[`locked` matters.] The loop takes tens of microseconds to settle.
  Logic in a PLL domain must be held in reset until then.
+ #strong[PLLs are finite.] Four on this part, not one per module.

== Crossing between domains

#fig("/figures/cdc-sync.svg",
     [Two domains, three cases: a two-flop synchroniser for one bit, a
      synchroniser per bit corrupting a bus, and the handshake that fixes it.])

Two clocks not derived from one another have #strong[no fixed phase
relationship]. Sooner or later a signal from domain A changes at exactly the
wrong moment relative to domain B's edge — inside the setup/hold window. The
receiving flip-flop then goes #strong[metastable]: its output sits between 0
and 1 for an unbounded time before resolving arbitrarily.

#watch[
  #strong[This cannot be simulated.] Verilog has no notion of setup time, so
  the simulator always gives a clean, defined, repeatable answer no matter how
  badly the crossing is built. Simulation cannot show you this bug and cannot
  prove you have fixed it.

  The defence is #emph[structural]: you follow the rule because the rule is
  correct, not because a test went green. It is also why "it worked on my
  bench for an hour" means nothing — a mean time between failures of three
  weeks looks exactly like a working design on a Tuesday afternoon.
]

For #strong[one bit], a two-flop synchroniser. The first flop may go
metastable; the second samples it a full period later, by which time it has
almost certainly resolved. "Almost certainly" is the honest phrasing.

For #strong[a bus], a synchroniser per bit is a #emph[bug]. Each bit resolves
independently, so some arrive one clock and some the next, and the destination
briefly sees a value that was never sent — `0x0F → 0x10` observed as `0x1F` or
`0x00`. Instead, synchronise #emph[one] bit and use it to say when the others
are safe to read; the data itself crosses with no synchroniser at all, because
by the time the request's toggle is noticed the data has been stable for two
destination clock periods.

== What it cost

#cost([`clocks_top` — the whole design],
      (LUT4: 19, TRELLIS_FF: 67, CCU2C: 26, EHXPLLL: 1), share: true)[
  The design is almost all flip-flops and carry: two counters, the
  synchronisers and the handshake registers. The row that matters is the last
  one — #strong[the PLL is one `EHXPLLL` and no logic at all], because it is a
  hard block sitting in the corner of the die rather than something built out
  of the fabric. You cannot have five of them; the part has four.
]

== What it cost in time

#measured("timing on the real build")[
  #ttable(
    columns: (auto, auto),
    [`clk_25mhz` domain],  [achieves 342.82 MHz — PASS at 25],
    [`clk_100mhz` domain], [achieves 278.09 MHz — PASS at 100],
    [cross-domain path],   [1.49 ns, #strong[found and reported separately]],
  )
  nextpnr finds the crossing unaided, because it cannot analyse it as a normal
  path. An unexpected `-> posedge <other clock>` line in your report is the
  tool handing you a bug report.
]

#measured("why 16× oversampling is not an option at 25 MHz")[
  Lesson 09's UART wants to sample at 16 times the baud rate. But
  115,200 × 16 = 1,843,200 Hz, and 25,000,000 / 1,843,200 = 13.5634 — not an
  integer. The nearest divisors give +4.33% and −3.12%, which is 41% and 30% of
  a bit adrift by the stop bit. The textbook technique is simply unavailable on
  this clock.
]

== The honest part about forcing a failure

Two attempts to build something deliberately slow were defeated by the
synthesiser. First a wrapper read only the low byte of the result, so the upper
24 bits were pruned and the measured frequency went #emph[up] with chain depth.
Then, with every bit live, a 16-deep chain still collapsed to 8 carry cells and
9 LUTs — the arithmetic was folded.

#why[
  #strong[You cannot read your critical path off your source code.] The thing
  that gets built is not the thing you wrote. Lessons 01 and 02 showed that for
  area; it is equally true for delay. Read the tool's report.
]

The reliable way to see a failure is to ask for more speed, not to build
something slower:

#measured("the same placed design, asked for different clocks")[
  #ttable(
    columns: (auto, auto, auto),
    [*asked for*], [*achieved*], [*verdict*],
    [100 MHz], [357.65 MHz], [PASS],
    [300 MHz], [357.65 MHz], [PASS],
    [400 MHz], [357.65 MHz], [#strong[FAIL]],
  )
  The achieved number never changes — it is a property of the placed and routed
  design. What changes is whether it is enough. That is what timing closure
  #emph[is].
]
