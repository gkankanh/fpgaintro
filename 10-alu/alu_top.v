`timescale 1ns/1ps
// Lesson 10 — board demo: drive the ALU by hand.
//
//   sw[3:0]   the operation's low 4 bits... but there are 10 ops needing a
//             4-bit code whose values are not contiguous, so instead:
//   sw[2:0]   funct3
//   sw[3]     instr[30]  -- distinguishes ADD/SUB and SRL/SRA
//   btn[4:1]  a 4-bit operand `a`, placed in the low bits
//   led[7:0]  the low byte of the result
//
// A 32-bit ALU driven by four buttons is not a thrilling demo -- that is
// honest, and it is why this lesson's real deliverable is the testbench. What
// the board gives you is a check that the thing synthesises, places, routes
// and closes timing, which simulation cannot tell you.
module alu_top (
    input  wire       clk_25mhz,
    input  wire [3:0] sw,
    input  wire [4:1] btn,
    output wire [7:0] led
);
    wire [3:0] op = {sw[3], sw[2:0]};
    wire [31:0] a = {28'd0, btn[4], btn[3], btn[2], btn[1]};
    wire [31:0] b = 32'h0000_0003;         // a fixed second operand

    wire [31:0] y;
    wire        zero;

    alu #(.W(32)) u_alu (.op(op), .a(a), .b(b), .y(y), .zero(zero));

    // Register the result so there is a real flop-to-flop path for nextpnr to
    // time -- a purely combinational design from pins to pins tells you
    // nothing about the ALU's critical path.
    reg [7:0] shown = 0;
    always @(posedge clk_25mhz)
        shown <= y[7:0];

    assign led = shown;

    wire _unused = &{y[31:8], zero, 1'b0};
endmodule
