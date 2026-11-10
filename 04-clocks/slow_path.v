`timescale 1ns/1ps
// Lesson 04 — a design whose only purpose is to fail timing.
//
// A chain of DEPTH dependent additions, all between one pair of flip-flops.
// Stage i+1 cannot begin until stage i's carry has propagated the full width,
// so the combinational delay is roughly DEPTH x W carry stages, in series.
//
// That total delay is the CRITICAL PATH. The clock period must exceed it, or
// the destination flop samples a value that has not finished settling. So:
//
//     max clock frequency = 1 / (critical path delay)
//
// and a design is not "correct" or "incorrect" in isolation — it is correct
// *at a frequency*. nextpnr computes this and tells you, and `make bit` fails
// when it cannot meet what you asked for.
//
// The `^ (i+1)` is load-bearing. Without it the chain is a sum of constants
// and yosys folds the whole thing into a single addition — the fastest way to
// fail this experiment is to write something the synthesiser can see through.
module slow_path #(
    parameter W     = 32,
    parameter DEPTH = 8
)(
    input  wire         clk,
    input  wire [W-1:0] a,
    output reg  [W-1:0] y = 0
);
    wire [W-1:0] stage [0:DEPTH];
    assign stage[0] = a;

    genvar i;
    generate
        for (i = 0; i < DEPTH; i = i + 1) begin : chain
            assign stage[i+1] = stage[i] + (stage[i] ^ (i + 1));
        end
    endgenerate

    always @(posedge clk)
        y <= stage[DEPTH];
endmodule
