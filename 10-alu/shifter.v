`timescale 1ns/1ps
// Lesson 10 — barrel shifter versus iterative shifter.
//
// `a << sh` gives you a BARREL SHIFTER: pure combinational logic that shifts
// by any amount in one cycle. It is a tree of multiplexers, log2(W) deep --
// shift by 16 or not, then by 8 or not, then 4, 2, 1 -- so for 32 bits that is
// five layers of 32 muxes.
//
// The alternative shifts one place per clock, costing one mux layer and a
// counter but up to 31 cycles. On an 8-bit microcontroller that is the usual
// choice. In a single-cycle CPU it is not available at all: every instruction
// must finish in one cycle, so the shifter must be combinational.
//
// Both are here so the trade can be measured rather than described. See the
// README for the numbers.

// The barrel shifter, written as the operator. Note the explicit mux tree is
// NOT written out: yosys builds it, and lesson 02 is the reason to trust that
// for something as standard as a shift.
module shift_barrel #(
    parameter W = 32
)(
    input  wire [W-1:0]            a,
    input  wire [$clog2(W)-1:0]    sh,
    input  wire                    right,
    input  wire                    arith,
    output wire [W-1:0]            y
);
    assign y = right ? (arith ? ($signed(a) >>> sh) : (a >> sh))
                     : (a << sh);
endmodule


// One place per clock. `busy` while it works, exactly the handshake lesson 06
// and lesson 09 used.
module shift_iterative #(
    parameter W = 32
)(
    input  wire                 clk,
    input  wire                 start,
    input  wire [W-1:0]         a,
    input  wire [$clog2(W)-1:0] sh,
    input  wire                 right,
    input  wire                 arith,
    output reg  [W-1:0]         y    = 0,
    output reg                  busy = 0
);
    localparam SHW = $clog2(W);

    reg [SHW-1:0] left = 0;
    reg           r_right = 0, r_arith = 0;

    always @(posedge clk)
        if (!busy) begin
            if (start) begin
                y       <= a;
                left    <= sh;
                r_right <= right;
                r_arith <= arith;
                busy    <= (sh != {SHW{1'b0}});   // shift by 0 is already done
            end
        end else begin
            // One place, and only one, per clock. The sign bit is replicated
            // on an arithmetic right shift -- doing it a bit at a time makes
            // visible what `>>>` does in one step.
            if (r_right) y <= r_arith ? {y[W-1], y[W-1:1]} : {1'b0, y[W-1:1]};
            else         y <= {y[W-2:0], 1'b0};

            left <= left - 1'b1;
            if (left == {{(SHW-1){1'b0}}, 1'b1}) busy <= 0;
        end
endmodule
