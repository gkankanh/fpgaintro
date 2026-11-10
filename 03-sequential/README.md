# Lesson 03 — sequential logic

**Concept:** the flip-flop — the only component that makes *time* exist — and
the assignment operator that decides whether you get one or several.

**You will build:** a debounced button that increments a counter exactly once
per press, next to an undebounced one that does not.

**Needs the board:** no, but this is the lesson where hardware is the argument

**Prerequisites:** lesson 02

**Paths:** editor + visual

---

## The idea

Everything so far had no memory. Lesson 02's adder has no idea what it added a
moment ago; change the inputs and the outputs follow, and that is all there is.

A **D flip-flop** changes that. On each rising clock edge it samples its input
and holds that value until the next edge. Nothing else in this course stores a
bit. A register, a shift register, a counter, a state machine and a 32-bit CPU
are all arrangements of flip-flops with combinational logic deciding what goes
into them.

In Verilog there is exactly one way to ask for one:

```verilog
always @(posedge clk)
    q <= d;
```

> **Why this matters** — this is the dividing line in digital design.
> Combinational logic answers "what"; sequential logic answers "what, and
> when". Every remaining lesson is on this side of the line.

## `<=` versus `=`, as two circuits

The course rule has been stated since lesson 00: use `<=` inside
`always @(posedge clk)`. Here is why, as something you can measure rather than
a rule to memorise.

[`dff.v`](./dff.v) has the *same* three-stage shift register written twice:

```verilog
always @(posedge clk) begin      always @(posedge clk) begin
    a <= d;                          a = d;
    b <= a;                          b = a;
    c <= b;                          c = b;
end                              end
```

**Non-blocking (`<=`)** evaluates every right-hand side *before* updating any
left-hand side. So `b <= a` uses the value `a` had at the start of the edge —
which is what three real flip-flops in a row do. A pulse on `d` walks along:
stage `a` after one clock, `b` after two, `c` after three.

**Blocking (`=`)** takes effect immediately, so each line sees the result of
the line above. `a = d` makes `a` equal `d`; then `b = a` makes `b` equal `d`
too; then `c` as well. All three registers load the same value on the same
edge. The delay line is gone.

Now the measurement:

| module | flip-flops |
|---|---|
| `shift_nonblocking` | **3** |
| `shift_blocking` | **1** |

One flip-flop. The synthesiser worked out that `b` and `c` always equal `a`,
so it built one register and wired its output three ways. That is the bug, as a
number.

> **Watch out** — nothing warned. It compiled, it simulated, it synthesised,
> and `make lint` was quiet. The three-stage delay you asked for became a
> one-stage delay, and the only way to notice is to know the rule or to count
> the flip-flops. This is the most common serious mistake in Verilog.

Run `make graph` on each and look at the two schematics side by side. That
picture is the lesson.

## A mechanical switch is not a digital input

A button is two bits of springy metal. When they meet, they bounce apart and
meet again — several times, over roughly 1–10 ms.

At 25 MHz, 10 ms is **250,000 clock cycles**. So the bounce is not a blur or a
glitch to the FPGA: it is tens of thousands of clocks of perfectly clean,
fully-sampled, entirely real transitions. One press genuinely *is* several
presses, as far as the hardware can tell.

![A bouncing button produces several counts on the raw path and one on the debounced path](../docs/diagrams/debounce.svg)

Lesson 02 did not care — combinational gates just flicker, and a flickering LED
is not a wrong answer. The moment an edge is used to **count**, every bounce
counts.

### The debouncer

[`debounce.v`](./debounce.v) uses a saturating counter. The rule: the input must
disagree with the current output **continuously** for `COUNT` clocks before the
output follows. Any shorter disagreement resets the timer.

```verilog
if (noisy == clean)                 cnt <= 0;              // nothing happening
else if (cnt == COUNT[CW-1:0]) begin clean <= noisy; cnt <= 0; end
else                                cnt <= cnt + 1'b1;
```

This rejects bounce of *any* pattern, not just bounce shorter than one sample
period. The price is latency — the output lags by `COUNT` clocks — so you pick
the smallest `COUNT` that comfortably exceeds the switch's bounce time. 10 ms
is the usual safe answer for a tactile button.

`localparam CW = $clog2(COUNT + 1);` sizes the counter to exactly fit: 18 bits
for 250,000. One of the few places a system function belongs in synthesisable
code.

### The edge detector

```verilog
always @(posedge clk) prev <= level;
assign rise =  level & ~prev;
```

Two gates and a flip-flop, and you need it constantly. "Do something *once*
when X happens" is a different requirement from "do something *while* X is
true", and a level cannot express the first. Lesson 05's state machines,
lesson 09's UART and lesson 13's CPU all use this exact pattern.

### The register — [`reg_w`](./dff.v)

The workhorse, and the module that gets promoted to `common/rtl/` at lesson 10:

```verilog
module reg_w #(parameter W = 32) (
    input wire clk, en, input wire [W-1:0] d, output reg [W-1:0] q = 0);
    always @(posedge clk)
        if (en) q <= d;
endmodule
```

`W` defaults to 32 — the CPU's width. This becomes the program counter, the
instruction register, and every pipeline register in lesson 16.

> **Watch out — the apparent contradiction.** There is no `else`. In lesson 02,
> an `always @(*)` block that failed to assign on every path inferred a *latch*,
> and that was a bug. Here the identical-looking omission is correct.
>
> The difference is the clock. A flip-flop already holds its value between
> edges, so "assign nothing" is a real, cheap, well-defined behaviour — it is
> just the flop's enable input. In a combinational block there is no storage to
> fall back on, so the tool has to invent some.
>
> Same syntax, opposite meaning, decided entirely by whether the block is
> sensitive to a clock edge or to its inputs. This is the one place the two
> rules appear to conflict, so it is worth getting straight now.

## Simulate it

```bash
cd 03-sequential
make sim
```

```
PASS: shift registers differ as expected, debounce gives 1 transition per
press, edge detect gives 1 pulse per edge, reg_w loads and holds
```

Four experiments, and the second one is a milestone: **it is the first test in
this course that cannot be exhaustive.** There is no "all possible bounce
patterns". So instead a specific realistic pattern is injected — six makes and
breaks, then settling — and the output is checked for the *property* that
matters: exactly one transition.

That shift from "check every input" to "check the property that matters" is
permanent from here on. Lesson 10 formalises it with randomised comparison
against a model; lesson 14 formalises it properly with a proof.

Note also what the testbench does about time:

```verilog
localparam DB = 20;    // hardware uses 250_000
```

The debouncer is parameterised so the simulation runs in microseconds rather
than simulating 250,000 clocks. Lesson 00 did the same thing with `WIDTH`. Make
your time constants adjustable — it is what makes slow hardware testable.

```bash
make wave
```

Look at `noisy` and `clean` together during the injected bounce. Then look at
`cnt` climbing and being slammed back to zero each time the input wobbles —
that sawtooth is the debouncer doing its job.

## What it cost

```bash
make synth
```

```
29   TRELLIS_FF
24   LUT4
 9   CCU2C
```

Twenty-nine flip-flops, and every one is accountable:

| | flip-flops |
|---|---|
| debounce: 18-bit counter + `clean` | 19 |
| two edge detectors: one `prev` each | 2 |
| two 4-bit counters | 8 |
| **total** | **29** |

The 9 `CCU2C` are the debounce counter's 18-bit increment — one carry cell per
two bits, exactly as lesson 02 predicted.

Being able to account for every flip-flop in a design is a good habit and a
good diagnostic. When the number is larger than your explanation, you have
inferred something you did not intend.

## On the board

```bash
make prog
```

- `btn[1]` — the button, counted both ways
- `btn[2]` — reset both counters
- `led[7:4]` — debounced count
- `led[3:0]` — raw count

**Press `btn[1]` exactly five times.** The top nibble reads 5. The bottom
nibble reads something larger, and different every time you try it.

That gap is contact bounce, and it is the whole argument for this lesson. You
cannot get it from simulation, because simulation only bounces the way you told
it to.

## Icestudio

```bash
open 03-sequential/icestudio/debounce.ice
```

The debouncer as a block: a noisy input, a clean output, and the saturating
counter inside. Try changing `COUNT` on the constant block to something small
like 1000 and rebuild — on hardware you will see the raw and debounced counts
start to agree, because the window is now shorter than the bounce.

## Exercises

1. **Count the flip-flops.** Before running `make synth`, predict how many
   `shift_nonblocking` and `reg_w #(.W(8))` will each use. Then check.
2. **Break the shift register.** Swap `<=` for `=` in `shift_nonblocking` and
   run `make sim`. Which checks fail, and does the failure message tell you
   what actually happened?
3. **Shorten the debounce window.** Set `COUNT` to 100 (4 µs) and program the
   board. Does the debounced counter still count once per press? What does that
   tell you about your particular buttons?
4. **Add a fall counter.** `edge_detect` already outputs `fall`, and
   `seq_top` deliberately ignores it. Count releases as well as presses, and
   confirm that pressing and releasing gives you one of each.
5. **Debounce the wrong way.** Replace the saturating counter with a simple
   "sample the button every 10 ms" design — one flip-flop clocked by a slow
   enable. It mostly works. Construct the bounce pattern that defeats it.

## What you should now be able to explain

- Why `<=` gives three flip-flops and `=` gives one, and why nothing warns you.
- Why 10 ms of bounce is 250,000 clock cycles of real, clean transitions.
- Why a saturating counter beats a simple delay for debouncing.
- Why `if (en) q <= d;` with no `else` is correct in a clocked block and a bug
  in a combinational one.
- Why this lesson's debounce test cannot be exhaustive, and what replaces
  exhaustiveness.

**Next:** [lesson 04 — clocks and timing](../04-clocks/), where the clock stops
being something you are given and becomes something with properties you have to
respect.
