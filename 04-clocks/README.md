# Lesson 04 — clocks and timing

**Concept:** what a clock actually is inside an FPGA, what the tools are
checking when they check timing, and why two clocks are much harder than one.

**You will build:** a PLL generating 100 MHz and 40 MHz from the 25 MHz
crystal, a safe crossing between two clock domains, and a design pushed until
it fails timing.

**Needs the board:** yes for the PLL — it cannot be simulated at all

**Prerequisites:** lesson 03

**Paths:** editor only (hard blocks and timing constraints have no block-diagram

**By the end you can:**

- Explain why a design is correct *at a frequency* rather than correct.
- Divide a clock to make an *enable*, never a clock, and say why.
- Explain why a PLL's output frequencies are not freely chosen.
- Cross a bus between clock domains without corrupting it.
- Explain why no simulation can validate a clock-domain crossing.
form)

---

## The idea

Three lessons have used `clk_25mhz` as if it were simply given. It is not. A
clock is a physical signal with properties, and three of them decide whether
your design works.

### Setup and hold

A flip-flop needs its data input **stable before** the clock edge (setup time)
and **stable after** it (hold time). Inside that window the flop is making its
decision, and a change there means it may not make one cleanly.

So between any two flip-flops there is a budget: one clock period, minus the
first flop's output delay, minus the second's setup time. Everything else is
available for logic and routing.

### The critical path

The longest flop-to-flop path in the design sets the maximum frequency:

```
max frequency = 1 / (critical path delay)
```

Which means **a design is not correct or incorrect in isolation — it is correct
at a frequency.** The same Verilog that works at 25 MHz may fail at 100 MHz,
and nothing in the source code says which.

This is also the real argument for pipelining, twelve lessons early. Lesson 16
splits the CPU into five stages not for elegance but because a shorter critical
path permits a faster clock.

### Clock enables, not clock gating

Lesson 00 divided the clock with a counter and used the counter's *top bit as
data*. The alternative — using it as a clock — is a mistake worth naming:

```verilog
// Yes: one clock domain, a slow enable.
wire tick = (div == LIMIT);
always @(posedge clk_25mhz) if (tick) count <= count + 1'b1;

// No: a derived clock.
always @(posedge div[15]) count <= count + 1'b1;
```

An FPGA has a small number of **global clock networks** — dedicated low-skew
routing that reaches every flip-flop at very nearly the same instant. A signal
you generate in logic travels on ordinary routing, arrives at different flops
at measurably different times, and the timing analyser can no longer give you a
meaningful answer. You can see nextpnr doing this allocation in this lesson's
build log:

```
Info:     promoting clock net clk_100mhz to global network
Info:     routing clock net $glbnet$clk_100mhz using global 1
```

Two nets, two of the chip's global networks. That resource is why the rule is
"divide to make an enable, never a clock".

## The PLL

[`pll.v`](./pll.v) is **generated**, not written:

```bash
ecppll -n pll -i 25 -o 100 --clkout1 40 \
       --clkin_name clk_25mhz --clkout0_name clk_100mhz \
       --clkout1_name clk_40mhz -f pll.v
```

which reported a VCO of 600 MHz, divisor 6 for 100 MHz and divisor 15 for
40 MHz. Those numbers are not free choices: the VCO must land in its legal
range (roughly 400–800 MHz) and **every output is that one VCO frequency
divided by an integer**. You cannot ask for an arbitrary pair of frequencies,
which is exactly why a calculator exists.

`EHXPLLL` is a **hard block** — a real analogue phase-locked loop in the corner
of the die, not logic. Three consequences:

1. **It cannot be simulated.** iverilog has no model and verilator has no
   definition. This lesson's Makefile is the first in the course where what you
   simulate and what you synthesise differ:

   ```make
   SRCS     = pll.v cdc.v slow_path.v clocks_top.v
   SIM_SRCS = cdc.v slow_path.v
   ```

   The PLL is verified *structurally* — it synthesises, and nextpnr reports the
   frequencies it closed timing at — and on hardware.

2. **`locked` matters.** The loop takes tens of microseconds to settle after
   power-up. Logic in a PLL domain must be held in reset until then, or it runs
   on a clock that is still wandering.

3. **It is a finite resource.** The 85F has a handful of PLLs, not one per
   module.

## Crossing between domains

Here is the part that bites people, and the reason this lesson is full depth
rather than a page of rules.

Two clocks that are not derived from one another have **no fixed phase
relationship**. Sooner or later, a signal from domain A changes at exactly the
wrong moment relative to domain B's clock edge — inside the setup/hold window.

The receiving flip-flop then goes **metastable**: its output sits between 0 and
1 for an unbounded time before resolving arbitrarily. Two gates reading it may
disagree about what they saw.

> **Watch out — this cannot be simulated.** Verilog has no notion of setup
> time. iverilog will always give you a clean, defined, repeatable answer, no
> matter how badly your crossing is built. **Simulation cannot show you this
> bug and cannot prove you have fixed it.** The defence is structural: you
> follow the rule because the rule is correct, not because a test went green.
>
> This is the single most important sentence in the lesson. It is also why
> "it worked on my bench for an hour" means nothing here — the failure rate is
> probabilistic, and a mean time between failures of three weeks looks exactly
> like a working design on a Tuesday afternoon.

### One bit: the two-flop synchroniser

```verilog
always @(posedge clk) s <= {s[0], d_async};
assign q = s[1];
```

The first flop may go metastable; the second samples it a full period later, by
which time it has almost certainly resolved. "Almost certainly" is the honest
phrasing — two flops push the mean time between failures out to years. Three
for a very fast clock or a very critical signal.

What you give up: two clocks of latency, and any guarantee about *which* edge
the change is seen on.

### A bus: a synchroniser per bit is a bug

Put `sync2` on each of 32 bits and each bit resolves independently. Some arrive
on one clock and some on the next, so the destination briefly sees a value that
was **never sent** — `0x0F → 0x10` can be observed as `0x1F` or `0x00`. For a
counter crossing domains this is not theoretical, it is routine.

[`cdc.v`](./cdc.v)'s `cdc_bus` synchronises **one** bit and uses it to say when
the others are safe:

```verilog
always @(posedge src_clk)
    if (src_valid) begin
        hold <= src_data;
        req  <= ~req;          // toggle, not pulse
    end

always @(posedge dst_clk) rs <= {rs[1:0], req};
wire req_changed = rs[2] ^ rs[1];
```

The data crosses with **no synchroniser at all**, and that is correct: by the
time the destination notices `req` has flipped, the data has been stable for at
least two destination clock periods. Nothing is ever sampled while it moves.

`req` *toggles* rather than pulsing, because a one-clock pulse in a fast domain
can be missed entirely by a slow one.

> **The constraint, which nothing enforces:** the source must not send again
> until the destination has seen the previous value — two or three destination
> clocks. For a stream rather than occasional values you want a proper
> asynchronous FIFO.

## Simulate it

```bash
cd 04-clocks
make sim
```

```
PASS: sync2 passes levels, cdc_bus delivered all 12 values in order
(metastability is NOT and cannot be tested here)
```

The testbench generates its two clocks with **mutually prime periods** (17 ns
and 7 ns half-periods), so their phase relationship drifts continuously through
every possible alignment — which is what two unrelated clocks really do, and
what a neat 1:4 ratio would hide.

The pass message says what it does not prove, on purpose.

## What it cost

`clocks_top` — the whole design:

```bash
make synth
```

| resource | count |
|---|---:|
| `LUT4` | 19 |
| `TRELLIS_FF` | 67 |
| `CCU2C` | 26 |
| `EHXPLLL` | 1 |

19 of the 85F's 83,640 LUT4 — 0.02% of the part.

Almost all flip-flops and carry: two counters, the synchronisers and the
handshake registers. The row that matters is the last one — **the PLL is one
`EHXPLLL` and no logic at all**, because it is a hard block sitting in the
corner of the die rather than something built out of the fabric. You cannot
have five of them; the part has four.

## What it cost in time

```bash
make bit
```

The report is the output that matters:

```
Info: Max frequency for clock 'clk_25mhz' : 342.82 MHz (PASS at 25.00 MHz)
Info: Max frequency for clock 'clk_100mhz': 278.09 MHz (PASS at 100.00 MHz)
Info: Max delay posedge clk_25mhz -> posedge clk_100mhz: 1.49 ns
```

Three things in there:

- **Both domains close with enormous margin.** 342 MHz achieved where 25 is
  required. At 25 MHz on this part you have 40 ns to play with, which is a
  great deal of logic.
- **nextpnr found the cross-domain path by itself** and reports it separately,
  because it cannot analyse it as a normal path — the two clocks have no defined
  relationship. Seeing a `-> posedge <other clock>` line in your report is the
  tool telling you a crossing exists. If you did not intend one, that line is a
  bug report.
- **The numbers are per clock.** Each domain gets its own budget.

## Making it fail — and why that is hard

[`slow_path.v`](./slow_path.v) chains `DEPTH` dependent 32-bit additions between
one pair of flip-flops, so the delay should grow with `DEPTH`.

It is instructive mostly for how hard it was to make work. Two attempts were
quietly defeated by the synthesiser:

1. **Dead bits.** The wrapper assigned `led = y[7:0]`, so yosys pruned the
   upper 24 bits. Carries propagate upward, so what survived was shallow — and
   the measured frequency went *up* with `DEPTH`. Fixed by folding all four
   bytes into the output so every bit is live.
2. **Algebraic folding.** Even then, `DEPTH = 16` synthesised to 8 CCU2C and
   9 LUT4 — a few dozen cells where hundreds were intended. yosys worked out
   what the chain computes and built that instead of what was written.

> **Why this matters more than the original exercise** — you cannot determine
> your critical path by reading your source code. The thing that gets built is
> not the thing you wrote; lesson 01 and lesson 02 showed that for area, and it
> is equally true for delay. **Read the tool's report.**

The reliable way to see a failure is not to build something slower but to **ask
for something faster.** With the LPF's 25 MHz constraint removed so `--freq`
takes effect:

| asked for | achieved | verdict |
|---|---|---|
| 100 MHz | 357.65 MHz | PASS |
| 300 MHz | 357.65 MHz | PASS |
| 400 MHz | 357.65 MHz | **FAIL** |
| 500 MHz | 357.65 MHz | **FAIL** |

The achieved number never changes — it is a property of the placed and routed
design. What changes is whether it is enough. That is what timing closure *is*.

## On the board

```bash
make prog
```

- `led[3:0]` — top bits of a 24-bit counter in the **25 MHz** domain
- `led[7:4]` — the same counter width in the **100 MHz** domain, so it advances
  **four times faster**. That visible difference is the PLL working.
- hold `btn[1]` — shows the crossed value next to the count of values that
  arrived, which should agree

If the top nibble never moves, the PLL did not lock.

## Exercises

1. **Watch the global clock networks.** Run `make bit` and find the
   `promoting clock net` lines. How many global networks did this design use,
   and what happens if you add a third PLL output and clock something with it?
2. **Break the crossing.** Replace `cdc_bus` with a `sync2` on each of the 8
   bits. `make sim` will still pass, and so will the hardware, probably, for a
   while. Explain precisely why the test cannot catch this — that explanation
   is the exercise.
3. **Violate the handshake constraint.** Make `tick_25` fire every clock
   instead of every 65,536. Values will be lost. Predict whether the testbench
   catches it, then check.
4. **Use the 40 MHz output.** It is generated and unused. Put a third counter
   in that domain and cross it into the 100 MHz domain too.
5. **Find your own ceiling.** Sweep `DEPTH` in `slow_top` and plot achieved
   frequency. Where does it cross 100 MHz? Then try to make the chain survive
   optimisation — `(* keep *)` on the intermediate wires is one way.

## Wrap-up

**What you built.** A PLL, a safe crossing between two clock domains, and a design pushed until it failed timing — 342 MHz achieved where 25 was required.

**What to keep.** A design is correct *at a frequency*, and the critical path is the tool's answer rather than yours.

**What comes next.** Lesson 05 builds the first designs complex enough for that budget to matter.
