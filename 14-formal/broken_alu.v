`timescale 1ns/1ps
// ===========================================================================
//  Lesson 14 — a deliberately wrong ALU, so the solver can be seen working.
//
//  This is lesson 10's ALU with ONE change: signed less-than uses the
//  shortcut that nearly works.
//
//      lt = sum[W-1] ^ overflow;     // correct
//      lt = sum[W-1];                // this file
//
//  The reasoning behind the shortcut is appealing: a negative number is less
//  than a positive one, so surely the sign of the difference settles it. It
//  is right for the overwhelming majority of inputs, and lesson 10's 20,000
//  randomised vectors would very likely miss it -- the failing region is a
//  vanishing fraction of the 2**64 input pairs.
//
//  The solver does not sample. Run `make formal-broken` and it produces the
//  failing operands in under a second.
// ===========================================================================
module broken_alu #(
    parameter W = 32
)(
    input  wire [3:0]   op,
    input  wire [W-1:0] a,
    input  wire [W-1:0] b,
    output wire [W-1:0] y,
    output wire         zero
);
    localparam [3:0] OP_ADD  = 4'b0000, OP_SUB  = 4'b1000,
                     OP_SLL  = 4'b0001, OP_SLT  = 4'b0010,
                     OP_SLTU = 4'b0011, OP_XOR  = 4'b0100,
                     OP_SRL  = 4'b0101, OP_SRA  = 4'b1101,
                     OP_OR   = 4'b0110, OP_AND  = 4'b0111;

    wire         subtract = (op == OP_SUB) || (op == OP_SLT) || (op == OP_SLTU);
    wire [W-1:0] addend   = subtract ? ~b : b;
    wire [W-1:0] sum;
    wire         carry;

    adder #(.W(W)) u_add (
        .a(a), .b(addend), .cin(subtract), .s(sum), .cout(carry));

    wire ltu = ~carry;

    // THE BUG: no overflow term.
    wire lt = sum[W-1];

    localparam SHW = $clog2(W);
    wire [SHW-1:0] sh = b[SHW-1:0];

    reg [W-1:0] r;
    always @(*)
        case (op)
            OP_ADD, OP_SUB: r = sum;
            OP_SLL:         r = a << sh;
            OP_SRL:         r = a >> sh;
            OP_SRA:         r = $signed(a) >>> sh;
            OP_SLT:         r = {{(W-1){1'b0}}, lt};
            OP_SLTU:        r = {{(W-1){1'b0}}, ltu};
            OP_XOR:         r = a ^ b;
            OP_OR:          r = a | b;
            OP_AND:         r = a & b;
            default:        r = {W{1'b0}};
        endcase

    assign y    = r;
    assign zero = (r == {W{1'b0}});
endmodule
