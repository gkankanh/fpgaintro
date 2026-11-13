#import "../style.typ": *

= Appendix B — Verilog style rules

Conventions every lesson follows. Each exists because it corresponds to a
mistake that is easy to make and annoying to debug.

== Synchronous design, one clock

Everything is clocked by `clk_25mhz`. No gated clocks, no latches, no
asynchronous resets unless a lesson is explicitly about them.

If you need something slower, divide with a counter and use the result as an
#strong[enable], not as a clock:

```verilog
// Yes: one clock domain, a slow enable.
reg [15:0] div = 0;
wire tick = (div == 16'd49999);
always @(posedge clk) div   <= tick ? 16'd0 : div + 1'b1;
always @(posedge clk) if (tick) count <= count + 1'b1;

// No: a derived clock. Does not use the clock network, will not meet
// timing predictably, and makes the design unanalysable.
always @(posedge div[15]) count <= count + 1'b1;
```

== Blocking versus non-blocking

- `<=` inside `always @(posedge clk)` — always, without exception.
- `=` inside `always @(*)` combinational blocks.

Non-blocking assignments all take effect at the end of the time step, which is
what a bank of real flip-flops does. Blocking assignments take effect
immediately, which chains them.

```verilog
// Shift register: each stage sees the OLD value of the previous one.
always @(posedge clk) begin
    a <= in;  b <= a;  c <= b;      // three flip-flops
end

// With blocking assignments this collapses: a, b and c all become `in`.
always @(posedge clk) begin
    a = in;   b = a;   c = b;       // ONE flip-flop, replicated
end
```

Lesson 03 measures it: three flip-flops against one.

== Do not infer latches

A combinational `always` block must assign every output on every path, or
synthesis infers a latch — storage with no clock, which is almost never what
you wanted.

```verilog
// Latch: `y` keeps its old value when sel is 2'b11.
always @(*) case (sel)
    2'b00: y = a;  2'b01: y = b;  2'b10: y = c;
endcase

// Fixed: assign a default FIRST, then override.
always @(*) begin
    y = 1'b0;
    case (sel)
        2'b00: y = a;  2'b01: y = b;  2'b10: y = c;
        default: y = 1'b0;
    endcase
end
```

#watch[
  In a #emph[clocked] block the same omission is correct. `if (en) q <= d;`
  with no `else` is a flip-flop with an enable, not a latch, because a
  flip-flop already holds its value between edges. Same syntax, opposite
  meaning, decided by whether the block is sensitive to a clock edge or to its
  inputs.
]

== Widths

State widths explicitly and keep them consistent. Verilog will silently
zero-extend, truncate or sign-extend, and the result is a bug that appears only
at a boundary value.

```verilog
reg  [7:0] count;
count <= count + 1'b1;        // explicit 1-bit literal, not bare `1`
wire [7:0] sum   = a + b;     // drops the carry — deliberate? say so
wire [8:0] sum_c = a + b;     // keeps it
```

Two traps worth naming, both silent:

#ttable(
  columns: (auto, 1fr),
  [#strong[Shifts]], [`a << b` is as wide as `a`. So `1'b1 << sel` shifts a
    one-bit value and is always zero. Widen the literal before shifting.],
  [#strong[Carries]], [`a + b` into a W-bit destination throws the carry away.
    Widen the intermediate to W+1.],
)

And when a truncation is intended, say so — widen, then slice:

```verilog
localparam [31:0]   LAST32 = DEPTH - 1;
localparam [AW-1:0] LAST   = LAST32[AW-1:0];
```

== Reset and initialisation

The ECP5 initialises flip-flops from the bitstream, so `reg x = 0;` works and
is used throughout this course. That is a convenience of this family, not a
portable habit — on an ASIC you need an explicit reset. Where a lesson needs a
real reset, it is synchronous:

```verilog
always @(posedge clk)
    if (rst) count <= 0;
    else     count <= count + 1'b1;
```

== One driver per signal

A register is driven from exactly one `always` block, and priority between its
inputs is expressed with `if`/`else`. Two blocks assigning one register have no
defined ordering in simulation and force synthesis to guess — Verilator rejects
it, correctly.

== Naming

#ttable(
  columns: (auto, 1fr),
  [`clk_25mhz`], [the board clock, named for its frequency],
  [`*_n`, `*n`], [active low — `oled_resn`, `csn`],
  [`*_i`],       [an internal copy of an output you also need to read],
  [`S_*`],       [state constants, as `localparam`],
  [`tb_*`],      [the testbench for the module of the same name],
  [`*_next`],    [the combinational next-state value of a register],
)

Name states as constants, never bare numbers in a `case`. `2'd2` tells a reader
nothing; `S_GREEN` tells them everything.

== Testbenches

Every testbench ends with an explicit verdict:

```verilog
if (errors == 0) $display("PASS: %0d vectors checked", n);
else             $display("FAIL: %0d of %0d wrong", errors, n);
```

`make sim-all` greps for `PASS`, so this is the regression suite's interface
rather than decoration.

Three further rules, each learned the hard way in a lesson:

+ #strong[Compute the reference a different way from the design.] A model that
  shares the design's mistake proves nothing. Lesson 10's shifts are checked
  against an independent iterative implementation for exactly this reason.
+ #strong[Set up monitors before stimulus.] Lesson 09's bit-period measurement
  asserted `start` and then waited for an edge that had already passed. Use
  `fork`/`join`.
+ #strong[Do not assert what you have not established.] Lesson 09's testbench
  claimed mistimed frames were never silently corrupted, and passed. The claim
  was false. A test that asserts something false and passes is worse than no
  test.

== Mutation testing

A testbench that has never caught a bug is unproven. Break the design
deliberately and check the test notices. A surviving mutation means one of two
things, and distinguishing them is the skill:

#ttable(
  columns: (auto, 1fr),
  [the test is incomplete], [lesson 12: every store offset in the vectors
    happened to be even, so a bug in the immediate's low bit was invisible],
  [the code is redundant],  [lesson 11: `x0` is enforced on both the read and
    the write path, so removing either alone changes no behaviour],
)
