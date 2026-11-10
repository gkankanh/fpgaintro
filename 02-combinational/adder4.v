`timescale 1ns/1ps
// Lesson 02 — addition, built up and then handed over.
//
// Three modules, which is the whole arc of the lesson:
//   full_adder     one bit of addition, from gates
//   adder4_ripple  four of them chained, the carry rippling along
//   adder4_behav   `a + b + cin`, and let the synthesiser decide
//
// The testbench proves the last two are identical over all 512 inputs. The
// point is not that `+` works. The point is seeing what `+` *is*, once, so that
// the critical path through lesson 10's 32-bit ALU is something you can
// picture rather than something you take on faith.

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


// Four full adders in a row. `c` carries the ripple: c[0] is the incoming
// carry, c[4] the outgoing one, and each stage waits for the stage below.
//
// THIS IS WHY ADDITION HAS A CRITICAL PATH. The top bit of the sum cannot
// settle until the carry has propagated through all four stages, one gate
// delay or so each. At 4 bits nobody cares. At 32 bits (lesson 10) it is the
// slowest thing in the CPU, and at that point you either accept a lower clock
// or you build a carry-lookahead adder — or, on this FPGA, you use the carry
// chain the fabric already has (lesson 00's CCU2C cells).
module adder4_ripple (
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire       cin,
    output wire [3:0] s,
    output wire       cout
);
    wire [4:0] c;
    assign c[0] = cin;

    // `generate` is a compile-time loop: it does not "run", it stamps out four
    // copies of the instance. The same pattern scales to 32 without edits.
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : stage
            full_adder fa (
                .a(a[i]), .b(b[i]), .cin(c[i]),
                .s(s[i]), .cout(c[i+1])
            );
        end
    endgenerate

    assign cout = c[4];
endmodule


// The same thing, written the way you actually would.
//
// Note the width discipline: `a + b + cin` on 4-bit operands would give a
// 4-bit result and silently throw the carry away. Widening the destination to
// 5 bits is what keeps it. Getting this wrong is one of the most common Verilog
// bugs, and it is invisible until a value happens to overflow.
module adder4_behav (
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire       cin,
    output wire [3:0] s,
    output wire       cout
);
    wire [4:0] sum = a + b + cin;
    assign s    = sum[3:0];
    assign cout = sum[4];
endmodule
