`timescale 1ns/1ps
// Lesson 02 — board demo: a mux choosing between a decoder and an adder.
//
// Inputs
//   sw[3:0]   the hex digit / the adder's `a`. Slide switches hold their
//             position, so no debouncing is needed — and nothing here is
//             clocked anyway, so bounce could only make an LED flicker.
//   btn[4:1]  the adder's `b` (UP, DOWN, LEFT and FIRE2 — hold them)
//   btn[5]    carry in
//   btn[6]    display select: released = segments, pressed = sum
//
// Outputs
//   led[6:0]  whichever the mux selected
//   led[7]    which mode you are in
//
// All three of the lesson's structures appear here, which is the point: this is
// the first design in the course assembled out of separately-tested parts
// rather than written as one lump.
module comb_top (
    input  wire [3:0] sw,
    input  wire [6:1] btn,
    output wire [7:0] led
);
    wire [3:0] a = sw;
    wire [3:0] b = {btn[4], btn[3], btn[2], btn[1]};
    wire       cin  = btn[5];
    wire       show = btn[6];

    // --- the decoder -------------------------------------------------------
    wire [6:0] seg;
    seg7 u_seg (.hex(a), .seg(seg));

    // --- the adder ---------------------------------------------------------
    // `adder` defaults to 32 bits because it is a CPU part; here it is
    // narrowed to the 4 bits this demo has switches for.
    wire [3:0] sum;
    wire       cout;
    adder #(.W(4)) u_add (.a(a), .b(b), .cin(cin), .s(sum), .cout(cout));

    // --- the mux -----------------------------------------------------------
    // One instance, 7 bits wide, from a module written for 1. The sum is only
    // 5 bits, so it is zero-padded up to the mux's width.
    wire [6:0] shown;
    mux2 #(.W(7)) u_mux (
        .d0  (seg),                       // btn[6] released
        .d1  ({2'b00, cout, sum}),        // btn[6] pressed
        .sel (show),
        .y   (shown)
    );

    assign led = {show, shown};
endmodule
