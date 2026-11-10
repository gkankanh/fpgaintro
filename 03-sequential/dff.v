`timescale 1ns/1ps
// Lesson 03 — the flip-flop, and the assignment operator that makes it work.
//
// Three modules. The first is the primitive everything else is built from; the
// other two are the SAME shift register written with the two different
// assignment operators, and they are not the same circuit. That difference is
// the whole point of this file, and `make graph` shows it as two pictures.

// A D flip-flop: on each rising clock edge, q takes the value d had at that
// instant. Between edges, nothing happens — q holds.
//
// This is the only way to store a bit in this course, and `always @(posedge
// clk)` is the only way to ask for one. There is no other mechanism; a
// register, a counter, a state machine and a CPU are all just arrangements of
// these.
module dff (
    input  wire clk,
    input  wire d,
    output reg  q = 0      // the ECP5 loads initial values from the bitstream
);
    always @(posedge clk)
        q <= d;
endmodule


// A 3-stage shift register, written correctly.
//
// All three assignments use `<=`, so all three right-hand sides are evaluated
// BEFORE any left-hand side is updated. Every stage therefore samples the
// value its neighbour had at the start of the clock edge — which is exactly
// what three real flip-flops in a row do.
//
// Result: `d` appears at `a` after one clock, `b` after two, `c` after three.
module shift_nonblocking (
    input  wire       clk,
    input  wire       d,
    output wire [2:0] q
);
    reg a = 0, b = 0, c = 0;

    always @(posedge clk) begin
        a <= d;
        b <= a;        // the OLD a
        c <= b;        // the OLD b
    end

    assign q = {c, b, a};
endmodule


// The same three lines with `=` instead. This is a different circuit.
//
// Blocking assignment takes effect immediately, so each line sees the result
// of the one above it. `a = d` makes a equal d; then `b = a` makes b equal d
// as well; then `c = b` makes c equal d too. All three registers get the same
// value on the same edge.
//
// Result: `d` appears at a, b AND c after one clock. The delay line is gone —
// collapsed into a single stage, replicated three times.
//
// Nothing warns you. It simulates, it synthesises, and it is wrong. This is
// the most common serious mistake in Verilog, which is why the course rule is
// absolute: `<=` inside `always @(posedge clk)`, always.
module shift_blocking (
    input  wire       clk,
    input  wire       d,
    output wire [2:0] q
);
    reg a = 0, b = 0, c = 0;

    always @(posedge clk) begin
        a = d;
        b = a;         // the NEW a, which is d
        c = b;         // the NEW b, which is also d
    end

    assign q = {c, b, a};
endmodule


// A W-bit register with a clock enable — the workhorse.
//
// This is the module that gets promoted to common/rtl/ at lesson 10 and then
// turns up everywhere: the program counter, the instruction register, every
// pipeline register in lesson 16. W defaults to 32, the CPU's width.
//
// Note the missing `else`:
//
//     if (en) q <= d;        // and nothing happens when en is low
//
// In lesson 02 an `always @(*)` block without an assignment on every path
// inferred a LATCH, and that was a bug. Here the identical-looking omission is
// correct and intended. The difference is that this block is clocked: a
// flip-flop already holds its value between edges, so "do nothing" is a real,
// cheap, well-defined behaviour — it is just the enable input on the flop.
//
// Same syntax, opposite meaning, decided entirely by whether the block is
// sensitive to a clock edge or to its inputs. Worth getting straight now,
// because it is the one place where the two rules appear to contradict.
module reg_w #(
    parameter W = 32
)(
    input  wire         clk,
    input  wire         en,     // load `d` when high, hold otherwise
    input  wire [W-1:0] d,
    output reg  [W-1:0] q = 0
);
    always @(posedge clk)
        if (en) q <= d;
endmodule
