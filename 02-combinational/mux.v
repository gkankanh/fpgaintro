`timescale 1ns/1ps
// Lesson 02 — multiplexers.
//
// A mux is a selector: one of several inputs reaches the output, chosen by
// `sel`. It is the single most common structure in a processor — every place
// where a value "comes from here, or from there" is a mux, and a CPU datapath
// is mostly muxes with some arithmetic between them.
//
// Both modules are parameterised by width, because a mux does not care what it
// is selecting between. Writing it once at `W` bits and instantiating it at 7
// is the whole point of parameters.

// 2-to-1. The conditional operator is the clearest way to say this.
module mux2 #(
    parameter W = 1
)(
    input  wire [W-1:0] d0,      // chosen when sel = 0
    input  wire [W-1:0] d1,      // chosen when sel = 1
    input  wire         sel,
    output wire [W-1:0] y
);
    assign y = sel ? d1 : d0;
endmodule


// 4-to-1, as a chain of conditionals.
//
// A 4-to-1 mux is really a tree of three 2-to-1 muxes, and you could write it
// that way by instantiating mux2 three times. Expressed as nested conditionals
// it reads better and synthesises to the same thing — on this FPGA, for W=1,
// to a single LUT4, because a 4-to-1 mux of 1-bit data is a function of exactly
// 4 inputs... except it is 6 (d0..d3 plus 2 select bits), so it is not. Check
// with `make synth` and see what the ECP5 actually does with it.
module mux4 #(
    parameter W = 1
)(
    input  wire [W-1:0] d0,
    input  wire [W-1:0] d1,
    input  wire [W-1:0] d2,
    input  wire [W-1:0] d3,
    input  wire [1:0]   sel,
    output wire [W-1:0] y
);
    assign y = (sel == 2'd0) ? d0 :
               (sel == 2'd1) ? d1 :
               (sel == 2'd2) ? d2 :
                               d3;
endmodule


// An N-to-2^N decoder: exactly one output is high, the one `sel` names.
//
// Decoders are the mux's mirror image. A mux has many inputs and picks one; a
// decoder has one input and picks which of many outputs to activate. They turn
// up wherever a number has to become a selection: instruction decode (lesson
// 12), address decode (lesson 15), chip selects, one-hot FSM state.
module dec #(
    parameter N = 2                        // selector width
)(
    input  wire [N-1:0]       sel,
    output wire [(1<<N)-1:0]  y
);
    localparam M = 1 << N;                 // number of outputs

    // "A 1, shifted left by sel" — but the width matters enormously here.
    //
    // WATCH OUT: in Verilog the result of `a << b` is as wide as `a`. Writing
    // `assign y = 1'b1 << sel;` would shift a ONE-BIT value, so everything
    // shifts off the end and y is always 0. The literal has to be M bits wide
    // before it is shifted, which is what this concatenation does.
    assign y = { {(M-1){1'b0}}, 1'b1 } << sel;
endmodule
