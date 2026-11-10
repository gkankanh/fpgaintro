`timescale 1ns/1ps
// Lesson 03 — making a mechanical switch into a digital input.
//
// A button is two pieces of springy metal. When they meet they bounce apart
// and meet again, several times, over something like 1-10 ms. To the FPGA,
// sampling at 25 MHz, one press looks like a burst of dozens of clean
// transitions — because at that timescale they ARE clean transitions.
//
// Combinational logic does not care: lesson 02's gates just flicker. But the
// moment an edge is used to *count*, every bounce counts, and one press
// becomes seventeen.

// A saturating-counter debouncer.
//
// The rule: the input must disagree with the current output continuously for
// COUNT clocks before the output is allowed to follow it. Any disagreement
// shorter than that is noise and resets the timer.
//
// This is better than a simple delay because it rejects bounce of any pattern,
// not just bounce shorter than one sample period. The cost is latency: the
// output lags the input by COUNT clocks, which is why you pick COUNT as the
// smallest value that comfortably exceeds the switch's bounce time.
module debounce #(
    parameter COUNT = 250_000      // 10 ms at 25 MHz
)(
    input  wire clk,
    input  wire noisy,
    output reg  clean = 0
);
    // $clog2 sizes the counter to exactly fit COUNT — one of the few places a
    // system function is allowed in synthesisable code.
    localparam CW = $clog2(COUNT + 1);
    reg [CW-1:0] cnt = 0;

    always @(posedge clk) begin
        if (noisy == clean) begin
            // They agree: nothing is happening. Hold the timer at zero so a
            // later disagreement has to wait the full COUNT.
            cnt <= 0;
        end else if (cnt == COUNT[CW-1:0]) begin
            // Disagreed for long enough: accept the new level.
            clean <= noisy;
            cnt   <= 0;
        end else begin
            cnt <= cnt + 1'b1;
        end
    end
endmodule


// An edge detector: turn a level into a one-clock pulse.
//
// Remember the input's previous value, and report a rise when the input is
// high and its previous value was not. The output is high for exactly one
// clock per rising edge, however long the input stays high.
//
// This tiny module is needed everywhere. "Do something once when X happens"
// is a different requirement from "do something while X is true", and a level
// cannot express the first one. Lesson 05's FSMs, lesson 09's UART and lesson
// 13's CPU all use this pattern.
module edge_detect (
    input  wire clk,
    input  wire level,
    output wire rise,
    output wire fall
);
    reg prev = 0;

    always @(posedge clk)
        prev <= level;

    assign rise =  level & ~prev;
    assign fall = ~level &  prev;
endmodule
