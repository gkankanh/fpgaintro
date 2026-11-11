`timescale 1ns/1ps
// Lesson 09 — the UART receiver, which is the harder half.
//
// The transmitter only has to count. The receiver has to work out WHEN to
// look, with no clock from the other end and no guarantee its own clock is
// exactly the same speed.
//
// WHY NOT 16x OVERSAMPLING? Every UART textbook says to build a clock at 16
// times the baud rate and sample on the 8th tick of each bit. That is how a
// 16550 does it, because it is given a 16x baud clock. Here it does not work:
//
//     115200 x 16 = 1,843,200 Hz
//     25,000,000 / 1,843,200 = 13.5634      <- not an integer
//
//     DIV=13 -> 120,192 baud (+4.3%)  -> 41% of a bit adrift by the stop bit
//     DIV=14 -> 111,607 baud (-3.1%)  -> 30% of a bit adrift by the stop bit
//
// Either way the stop bit gets sampled somewhere in the middle of bit 7, and
// the frame is lost. The 16x clock is a good idea given a crystal chosen for
// it; it is a bad idea given a 25 MHz crystal.
//
// WHAT TO DO INSTEAD. Count the bit period directly, which divides cleanly
// (DIV = 217, 0.0064% error), and sample at the HALF-WAY POINT:
//
//              |<--------- one bit, DIV clocks --------->|
//   rx    -----|========================================|-----
//                                 ^
//                            sample here (DIV/2)
//
// Same idea as oversampling -- sample as far as possible from both edges, so
// that clock error and edge uncertainty have the most room to be wrong in --
// implemented to fit the clock you actually have.
module uart_rx #(
    parameter CLK_HZ = 25_000_000,
    parameter BAUD   = 115200
)(
    input  wire       clk,
    input  wire       rx,              // straight from a pin: ASYNCHRONOUS
    output reg  [7:0] data  = 0,
    output reg        valid = 0,       // one-clock pulse: `data` is good
    output reg        frame_error = 0  // one-clock pulse: stop bit was wrong
);
    localparam integer DIV = CLK_HZ / BAUD;
    localparam integer CW  = $clog2(DIV);

    // Sized explicitly: see uart_tx.v. HALF_BIT is where the mid-bit sample
    // happens, and it is the single most important constant in this file.
    localparam [31:0]   FULL_W   = DIV - 1;
    localparam [31:0]   HALF_W   = DIV / 2;
    localparam [CW-1:0] FULL_BIT = FULL_W[CW-1:0];
    localparam [CW-1:0] HALF_BIT = HALF_W[CW-1:0];

    // The incoming line is asynchronous to this clock -- it comes from another
    // chip's oscillator. Sampling it directly risks metastability, so it goes
    // through a two-flop synchroniser first. Lesson 04 exists for this moment.
    reg [1:0] sync = 2'b11;
    always @(posedge clk)
        sync <= {sync[0], rx};
    wire rx_s = sync[1];

    localparam S_IDLE  = 2'd0,
               S_START = 2'd1,   // confirming the start bit at mid-bit
               S_DATA  = 2'd2,
               S_STOP  = 2'd3;

    reg [1:0]    state = S_IDLE;
    reg [CW-1:0] cnt   = 0;
    reg [2:0]    bitn  = 0;
    reg [7:0]    sh    = 0;

    always @(posedge clk) begin
        valid       <= 0;        // both outputs are one-clock pulses
        frame_error <= 0;

        case (state)
            // Watch for the line going low. No edge detector needed: the line
            // idles high, so "low" is already the event.
            S_IDLE:
                if (!rx_s) begin
                    cnt   <= 0;
                    state <= S_START;
                end

            // Wait half a bit, landing in the MIDDLE of the start bit, and
            // check it is still low. If it is not, that was a glitch rather
            // than a frame -- a line disturbance, or the tail of a previous
            // frame -- and the right response is to go back to waiting rather
            // than to read eight bits of noise.
            S_START:
                if (cnt == HALF_BIT) begin
                    cnt <= 0;
                    if (rx_s) state <= S_IDLE;     // false start, abandon it
                    else begin
                        bitn  <= 0;
                        state <= S_DATA;
                    end
                end else
                    cnt <= cnt + 1'b1;

            // From the middle of the start bit, every full bit period lands in
            // the middle of the next bit. LSB arrives first, so shift in from
            // the top.
            S_DATA:
                if (cnt == FULL_BIT) begin
                    cnt <= 0;
                    sh  <= {rx_s, sh[7:1]};
                    if (bitn == 3'd7) state <= S_STOP;
                    else              bitn  <= bitn + 1'b1;
                end else
                    cnt <= cnt + 1'b1;

            // One more bit period reaches the middle of the stop bit, which
            // must be HIGH. If it is not, the frame is malformed: the baud
            // rates disagree, or a byte was lost, or the line glitched. Report
            // it rather than pass up a byte that is probably wrong.
            S_STOP:
                if (cnt == FULL_BIT) begin
                    cnt   <= 0;
                    state <= S_IDLE;
                    if (rx_s) begin
                        data  <= sh;
                        valid <= 1;
                    end else
                        frame_error <= 1;
                end else
                    cnt <= cnt + 1'b1;

            default: state <= S_IDLE;
        endcase
    end
endmodule
