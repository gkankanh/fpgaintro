#import "../style.typ": *

= Lesson 03 — Sequential logic

== The idea

Everything so far had no memory. A D flip-flop changes that: on each rising
clock edge it samples its input and holds that value until the next edge.

#strong[Nothing else in this course stores a bit.] A register, a shift
register, a counter, a state machine and a 32-bit CPU are all arrangements of
flip-flops with combinational logic deciding what goes into them.

#fig("/figures/register-ff.svg",
     [A register, drawn out: one flip-flop per bit, and a multiplexer in front
      of each deciding whether to take new data or reload the old value.],
     width: 82%)

== Theory

=== `<=` versus `=`, as two circuits

The same three-stage shift register, written twice:

#grid(columns: (1fr, 1fr), gutter: 10pt,
  ```verilog
  always @(posedge clk) begin
      a <= d;
      b <= a;   // the OLD a
      c <= b;   // the OLD b
  end
  ```,
  ```verilog
  always @(posedge clk) begin
      a = d;
      b = a;    // the NEW a
      c = b;    // the NEW b
  end
  ```
)

#strong[Non-blocking] evaluates every right-hand side before updating any
left-hand side, so each stage samples what its neighbour held at the start of
the edge. A pulse walks along: stage `a` after one clock, `b` after two, `c`
after three.

#strong[Blocking] takes effect immediately, so each line sees the result of the
line above. All three registers load the same value on the same edge. The delay
line is gone.

#measured("the bug, as a number")[
  #ttable(
    columns: (auto, auto),
    [`shift_nonblocking`], [#strong[3] flip-flops],
    [`shift_blocking`],    [#strong[1] flip-flop],
  )
  One flip-flop. The synthesiser worked out that `b` and `c` always equal `a`,
  built one register and wired its output three ways.
]

#watch[
  Nothing warns. It compiles, it simulates, it synthesises, and `make lint` is
  quiet. The three-stage delay you asked for became a one-stage delay, and the
  only ways to notice are to know the rule or to count the flip-flops. This is
  the most common serious mistake in Verilog.
]

=== A switch is not a digital input

A button is two pieces of springy metal. When they meet they bounce apart and
meet again — several times, over roughly 1–10 ms.

At 25 MHz, 10 ms is #strong[250,000 clock cycles]. The bounce is not a blur or
a glitch to the FPGA: it is tens of thousands of clocks of perfectly clean,
fully sampled, entirely real transitions. #strong[One press genuinely is
several presses], as far as the hardware can tell.

#fig("/figures/debounce.svg",
     [One press. The raw path counts three times; the debounced path counts
      once.])

Lesson 02 did not care — combinational gates just flicker, and a flickering LED
is not a wrong answer. The moment an edge is used to #emph[count], every bounce
counts.

The defence is a saturating counter: the input must disagree with the current
output #emph[continuously] for `COUNT` clocks before the output follows. Any
shorter disagreement resets the timer, which rejects bounce of any pattern
rather than only bounce shorter than one sample period. The price is latency,
so you pick the smallest `COUNT` that comfortably exceeds the switch's bounce
time.

=== The apparent contradiction

```verilog
module reg_w #(parameter W = 32)(input clk, en, ...);
    always @(posedge clk)
        if (en) q <= d;      // no else
endmodule
```

In lesson 02 an `always @(*)` block without an assignment on every path
inferred a latch, and that was a bug. Here the identical-looking omission is
#strong[correct].

The difference is the clock. A flip-flop already holds its value between edges,
so "assign nothing" is a real, cheap, well-defined behaviour — it is just the
flop's enable input. In a combinational block there is no storage to fall back
on, so the tool has to invent some. Same syntax, opposite meaning, decided
entirely by whether the block is sensitive to a clock edge or to its inputs.

== What it cost

#cost([`seq_top` — the whole design],
      (LUT4: 24, TRELLIS_FF: 29, CCU2C: 9, PFUMX: 4, L6MUX21: 1),
      share: true)[
  The nine carry cells are the debounce counter's 18-bit increment — one per
  two bits, exactly as lesson 02 predicted.
]

#measured("every one of the 29 flip-flops accounted for")[
  #ttable(
    columns: (auto, auto),
    [debounce: an 18-bit counter plus `clean`], [19],
    [two edge detectors, one `prev` each],      [2],
    [two 4-bit counters],                        [8],
    [*total*],                                   [*29*],
  )
]
