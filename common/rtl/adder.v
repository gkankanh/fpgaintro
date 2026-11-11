`timescale 1ns/1ps
// Lesson 02 — addition, built up and then handed over.
//
// Three modules, which is the whole arc of the lesson:
//   full_adder    one bit of addition, from gates
//   adder_ripple  W of them chained, the carry rippling along
//   adder         `a + b + cin`, and let the synthesiser decide
//
// WIDTH: both multi-bit adders default to W = 32, because `adder` is a real
// CPU building block — lesson 10's ALU uses exactly this module, and lesson 13's
// CPU uses that ALU. The testbench instantiates them at W = 4 instead, so that
// all 512 input combinations can be swept exhaustively. Default to the width
// you mean; narrow it to the width you can prove.
//
// The point is not that `+` works. The point is seeing what `+` *is*, once, so
// that the critical path through a 32-bit ALU is something you can picture
// rather than something you take on faith.

// One bit. Two outputs: the sum bit, and the carry into the next column.
//
//   s    = a XOR b XOR cin      odd number of ones
//   cout = majority(a, b, cin)  at least two ones
//
// The `cout` expression below is the majority function written to share the
// XOR that `s` already needs:  (a & b) | (cin & (a ^ b)).
module full_adder (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire s,
    output wire cout
);
    assign s    = a ^ b ^ cin;
    assign cout = (a & b) | (cin & (a ^ b));
endmodule


// W full adders in a row. `c` carries the ripple: c[0] is the incoming carry,
// c[W] the outgoing one, and each stage waits for the stage below.
//
// THIS IS WHY ADDITION HAS A CRITICAL PATH. The top bit of the sum cannot
// settle until the carry has propagated through every stage below it, one gate
// delay or so each. At 4 bits nobody cares. At 32 bits it is the slowest thing
// in the CPU, and at that point you either accept a lower clock or you build a
// carry-lookahead adder — or, on this FPGA, you use the carry chain the fabric
// already has (lesson 00's CCU2C cells).
module adder_ripple #(
    parameter W = 32
)(
    input  wire [W-1:0] a,
    input  wire [W-1:0] b,
    input  wire         cin,
    output wire [W-1:0] s,
    output wire         cout
);
    wire [W:0] c;
    assign c[0] = cin;

    // `generate` is a compile-time loop: it does not "run", it stamps out W
    // copies of the instance. This is why the module scales from 4 to 32 with
    // no edit at all — which is also the thing a block diagram cannot do.
    genvar i;
    generate
        for (i = 0; i < W; i = i + 1) begin : stage
            full_adder fa (
                .a(a[i]), .b(b[i]), .cin(c[i]),
                .s(s[i]), .cout(c[i+1])
            );
        end
    endgenerate

    assign cout = c[W];
endmodule


// The same thing, written the way you actually would — and the module that
// gets promoted to common/rtl/ at lesson 10 and used by the CPU.
//
// Note the width discipline: `a + b + cin` on W-bit operands gives a W-bit
// result and silently throws the carry away. Widening the intermediate to
// W+1 bits is what keeps it. Getting this wrong is one of the most common
// Verilog bugs, and it is invisible until a value happens to overflow.
module adder #(
    parameter W = 32
)(
    input  wire [W-1:0] a,
    input  wire [W-1:0] b,
    input  wire         cin,
    output wire [W-1:0] s,
    output wire         cout
);
    wire [W:0] sum = a + b + cin;
    assign s    = sum[W-1:0];
    assign cout = sum[W];
endmodule
