`timescale 1ns/1ps
// Lesson 09 — the UART transmitter.
//
// An 8N1 frame, least significant bit first:
//
//   idle   start   d0  d1  d2  d3  d4  d5  d6  d7   stop   idle
//   ----\______/---- ... each bit exactly DIV clocks wide ... ----/------
//    1      0                                          1      1
//
// Ten bit periods. The line idles HIGH, so the falling edge into the start bit
// is what the receiver watches for -- which is the whole reason a start bit
// exists. There is no clock on the wire; both ends simply agree on how long a
// bit lasts, and the start bit says when to begin counting.
//
// BAUD RATE IS A COUNTER MODULUS. 25,000,000 / 115,200 = 217.0139, so DIV is
// 217 and the actual rate is 115,207 baud -- 0.0064% fast. Over the 9.5 bit
// periods to the middle of the stop bit that accumulates to 0.06% of a bit,
// which is nothing. (DIV=216 or 218 would give 4.5%, still fine. UARTs
// tolerate a few percent; it is tens of percent that break them.)
module uart_tx #(
    parameter CLK_HZ = 25_000_000,
    parameter BAUD   = 115200
)(
    input  wire       clk,
    input  wire [7:0] data,    // sampled when `start` is high and busy is low
    input  wire       start,   // raise for one clock
    output wire       tx,      // to the other end's receiver
    output reg        busy = 0 // high from `start` until the stop bit ends
);
    localparam integer DIV = CLK_HZ / BAUD;
    localparam integer CW  = $clog2(DIV);

    // Sized explicitly, so the comparison below is not a 32-bit integer
    // against an 8-bit counter. Widen then slice, rather than relying on an
    // implicit narrowing -- lesson 08's lesson, and lesson 02's before it.
    localparam [31:0]   DIV_W    = DIV - 1;
    localparam [CW-1:0] DIV_LAST = DIV_W[CW-1:0];

    reg [CW-1:0] cnt   = 0;
    reg [3:0]    bitn  = 0;
    reg [9:0]    shift = 10'h3FF;   // all ones: the idle line

    // The whole frame lives in one shift register, and the output is simply
    // its low bit. Loading {stop, data, start} means shift[0] is the start bit
    // immediately, and once the frame has been shifted out the register is all
    // ones again -- so the line returns to idle with no special case.
    assign tx = shift[0];

    always @(posedge clk)
        if (!busy) begin
            if (start) begin
                shift <= {1'b1, data, 1'b0};   // stop, 8 data (LSB first), start
                cnt   <= 0;
                bitn  <= 0;
                busy  <= 1;
            end
        end else if (cnt == DIV_LAST) begin
            cnt   <= 0;
            shift <= {1'b1, shift[9:1]};       // shift right, ones trailing in
            bitn  <= bitn + 1'b1;
            if (bitn == 4'd9) busy <= 0;       // start + 8 data + stop = 10
        end else
            cnt <= cnt + 1'b1;
endmodule
