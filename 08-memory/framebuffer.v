`timescale 1ns/1ps
// Lesson 08 — a framebuffer: the two-access-patterns problem.
//
// A display memory is written one way and read another, at the same time:
//
//   WRITE  by coordinate, in whatever order the drawing code feels like
//   READ   in raster order, relentlessly, because the display never stops
//
// One port cannot serve both without one side waiting for the other. A simple
// dual-port memory serves both at once, which is why the DP16KD exists.
//
// 96x64 is 6,144 pixels. At one bit per pixel that is 6,144 bits -- a third of
// one DP16KD. Colour is applied on the way out, so a mono framebuffer plus a
// palette costs a third of a block where 16-bit colour would cost six.
//
// Lesson 15 wires this to the OLED and lets compiled C draw into it. Here it
// is built and verified on its own.
module framebuffer #(
    parameter XW = 7,                      // x: 0..95  needs 7 bits
    parameter YW = 6,                      // y: 0..63   needs 6 bits
    parameter W  = 96,
    parameter H  = 64
)(
    // --- write port: by coordinate ---------------------------------------
    input  wire           wclk,
    input  wire           we,
    input  wire [XW-1:0]  wx,
    input  wire [YW-1:0]  wy,
    input  wire           wpix,

    // --- read port: by raster coordinate ---------------------------------
    input  wire           rclk,
    input  wire [XW-1:0]  rx,
    input  wire [YW-1:0]  ry,
    output reg            rpix
);
    localparam PIXELS = W * H;

    // Address = y * 96 + x.
    //
    // Written as `wy * W + wx` this synthesises to TWO MULT18X18D blocks --
    // the ECP5's hardware multipliers. Measured, not guessed: an earlier
    // version of this file claimed yosys would reduce a constant multiply to
    // shifts, and it did not. It reached for a DSP block instead, which works
    // but spends one of the 156 on the part to multiply by a constant.
    //
    // 96 = 64 + 32, so the multiply is two shifts and an add, and saying so
    // explicitly costs no multiplier at all:
    //
    //     y * 96 == (y << 6) + (y << 5)
    //
    // The general lesson, third time in this course: the synthesiser is very
    // good and still does not read your mind. If you know the cheap form,
    // write the cheap form, then check `make synth` to see whether it
    // mattered.
    wire [15:0] waddr = ({9'd0, wy} << 6) + ({9'd0, wy} << 5) + {8'd0, wx};
    wire [15:0] raddr = ({9'd0, ry} << 6) + ({9'd0, ry} << 5) + {8'd0, rx};

    reg mem [0:PIXELS-1];

    always @(posedge wclk)
        if (we) mem[waddr] <= wpix;

    always @(posedge rclk)
        rpix <= mem[raddr];
endmodule
