# Verilog style rules

Conventions every lesson follows. They exist because each one corresponds to a
mistake that is easy to make and annoying to debug.

## Synchronous design

One clock, `clk_25mhz`, for everything. No gated clocks, no latches, no
asynchronous resets unless a lesson is explicitly about them.

If you need something slower, divide with a counter and use the result as an
*enable*, not as a clock:

```verilog
// Yes: one clock domain, a slow enable.
reg [15:0] div = 0;
wire tick = (div == 16'd49999);
always @(posedge clk_25mhz) div <= tick ? 16'd0 : div + 1'b1;
always @(posedge clk_25mhz) if (tick) count <= count + 1'b1;

// No: a derived clock. Does not use the FPGA's clock network, will not meet
// timing predictably, and makes the design unanalysable.
always @(posedge div[15]) count <= count + 1'b1;
```

## Blocking vs non-blocking

- `<=` (non-blocking) in `always @(posedge clk)` — always, without exception.
- `=` (blocking) in `always @(*)` combinational blocks.

Mixing them is the single most common source of designs that simulate
correctly and synthesise wrong. The reason: non-blocking assignments all take
effect at the end of the time step, which is what a bank of real flip-flops
does. Blocking assignments take effect immediately, which chains them.

```verilog
// Shift register: each stage sees the OLD value of the previous one.
always @(posedge clk) begin
    a <= in;  b <= a;  c <= b;      // three flip-flops
end

// With blocking assignments this collapses: a, b and c all become `in`,
// because each assignment is visible to the next line immediately.
always @(posedge clk) begin
    a = in;   b = a;   c = b;       // one flip-flop, replicated
end
```

## Avoid inferring latches

A combinational `always` block must assign every output on every path, or
synthesis infers a latch — a storage element with no clock, which is almost
never what you wanted.

```verilog
// Latch: `y` keeps its old value when sel is 2'b11.
always @(*) case (sel)
    2'b00: y = a;  2'b01: y = b;  2'b10: y = c;
endcase

// Fixed: a default, or a full case with `default`.
always @(*) begin
    y = 1'b0;                        // default first
    case (sel)
        2'b00: y = a;  2'b01: y = b;  2'b10: y = c;
        default: y = 1'b0;
    endcase
end
```

`make lint` catches these. Run it.

## Widths

State widths explicitly and keep them consistent. Verilog will silently
zero-extend, truncate or sign-extend, and the result is a bug that only appears
at a boundary value.

```verilog
reg  [7:0] count;
count <= count + 1'b1;        // explicit 1-bit literal, not bare `1`
wire [7:0] sum = a + b;       // drops the carry — deliberate? say so
wire [8:0] sum_c = a + b;     // keeps it
```

Use `'0`-style sizing on literals for anything wider than a bit: `32'd0`,
`8'hFF`, `4'b1010`.

## Reset and initialisation

The ECP5 initialises flip-flops from the bitstream, so `reg x = 0;` works and
is used throughout this course for simplicity. That is a convenience of this
family, not a portable habit — on an ASIC you need an explicit reset.

Where a lesson needs a real reset, it is synchronous:

```verilog
always @(posedge clk)
    if (rst) count <= 0;
    else     count <= count + 1'b1;
```

## Naming

| Pattern | Meaning |
|---|---|
| `clk_25mhz` | the board clock, named for its frequency |
| `*_n` / `*n` | active low, e.g. `oled_resn`, `csn` |
| `*_i` | internal copy of an output you also need to read |
| `s_*` / `S_*` | state constants, as `localparam` |
| `tb_*` | testbench for the module of the same name |
| `*_next` | the combinational next-state value of a register |

## Module shape

Ports in ANSI style, one per line, with direction and width and a comment where
the name is not self-explanatory:

```verilog
module uart_tx #(
    parameter CLK_HZ = 25_000_000,
    parameter BAUD   = 115200
)(
    input  wire       clk,
    input  wire [7:0] data,      // latched when `start` is high
    input  wire       start,     // pulse for one clock
    output wire       tx,        // to ftdi_rxd
    output wire       busy       // high from `start` until the stop bit ends
);
```

## Testbenches

Every testbench ends with an explicit verdict:

```verilog
if (errors == 0) $display("PASS: %0d vectors checked", n);
else             $display("FAIL: %0d of %0d vectors wrong", errors, n);
```

`make sim-all` greps for `PASS`, so this is not decorative — it is the
regression suite's interface. A test you have to interpret by eye is a test you
will misinterpret.

Prefer self-checking loops over hand-written vectors where the correct answer
can be computed:

```verilog
for (i = 0; i < 256; i = i + 1) begin
    a = i[3:0]; b = i[7:4]; #1;
    if (sum !== a + b) errors = errors + 1;
end
```

## Diagrams

Timing diagrams are [WaveDrom](https://wavedrom.com) JSON in the lesson's
`diagrams/` directory, named `*.wave.json`, rendered by `tools/mkwave.sh`.
The JSON is committed; the SVG is generated.

Block diagrams are hand-authored SVG in `docs/diagrams/`. Keep them
theme-aware so they are readable on a dark background: use `currentColor` for
strokes and text where possible, and where explicit colours are needed, define
them once and override under `prefers-color-scheme: dark`.

```svg
<style>
  :root { --ink: #1f2328; --accent: #0969da; }
  @media (prefers-color-scheme: dark) {
    :root { --ink: #e6edf3; --accent: #58a6ff; }
  }
  .wire { stroke: var(--ink); fill: none; stroke-width: 1.5 }
  .lbl  { fill: var(--ink); font: 12px ui-sans-serif, sans-serif }
</style>
```

Never put text in a diagram that the prose does not also state — diagrams are
not accessible to everyone, and a reader skimming the text should not miss
anything load-bearing.
