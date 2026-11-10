`timescale 1ns/1ps
// Lesson 04 — a pin-connected wrapper around slow_path, so nextpnr can be
// asked to close timing on it and will tell you what it managed.
//
// DEPTH is the experiment. Sweep it and watch the achievable frequency fall:
//
//   for d in 1 2 4 8 16 32; do
//     yosys -p "read_verilog slow_path.v slow_top.v; \
//               chparam -set DEPTH $d slow_top; \
//               synth_ecp5 -top slow_top -json slow.json"
//     nextpnr-ecp5 --85k --package CABGA381 --freq 100 \
//                  --json slow.json --lpf ../common/ulx3s_v20.lpf \
//                  --textcfg slow.config 2>&1 | grep "Max frequency"
//   done
module slow_top #(
    parameter DEPTH = 8
)(
    input  wire       clk_25mhz,
    input  wire [2:1] btn,
    output wire [7:0] led
);
    // A register feeding the chain, so there is a real flop-to-flop path to
    // measure rather than a path from a pin.
    reg [31:0] a = 32'h1234_5678;
    always @(posedge clk_25mhz)
        if (btn[1]) a <= a + 1'b1;

    wire [31:0] y;
    slow_path #(.W(32), .DEPTH(DEPTH)) u_slow (
        .clk(clk_25mhz), .a(a), .y(y));

    // Every bit of `y` must reach a pin, or yosys prunes the ones that do not
    // and the chain you thought you built is not there. An earlier version of
    // this file assigned `led = y[7:0]`, and the measured frequency went UP
    // with DEPTH — because only the low byte was live, and carries propagate
    // upward, so the surviving logic was shallow. Folding all four bytes
    // together keeps the whole datapath alive.
    assign led = y[7:0] ^ y[15:8] ^ y[23:16] ^ y[31:24];
    wire _unused = &{btn[2], 1'b0};
endmodule
