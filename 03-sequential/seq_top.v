`timescale 1ns/1ps
// Lesson 03 — board demo: the same button counted two ways.
//
// One button, two counters:
//   led[7:4]  counts debounced presses  — goes up by exactly 1 per press
//   led[3:0]  counts raw edges          — goes up by however many bounces
//
// Press btn[1] five times. The top nibble reads 5. The bottom nibble reads
// something larger and unpredictable. That gap is contact bounce, and it is
// the entire argument for this lesson.
module seq_top (
    input  wire       clk_25mhz,
    input  wire [2:1] btn,
    output wire [7:0] led
);
    // --- the debounced path ------------------------------------------------
    wire clean, rise_clean, fall_clean;
    debounce #(.COUNT(250_000)) u_db (        // 10 ms at 25 MHz
        .clk(clk_25mhz), .noisy(btn[1]), .clean(clean));
    edge_detect u_ed_clean (
        .clk(clk_25mhz), .level(clean), .rise(rise_clean), .fall(fall_clean));

    // --- the raw path ------------------------------------------------------
    // Same edge detector, straight onto the pin. Note that this path is not
    // "wrong" in any way an inspection would reveal — it is a correct edge
    // detector fed a signal that is not what the programmer imagined.
    wire rise_raw, fall_raw;
    edge_detect u_ed_raw (
        .clk(clk_25mhz), .level(btn[1]), .rise(rise_raw), .fall(fall_raw));

    // --- two counters ------------------------------------------------------
    // btn[2] resets both, so the experiment can be repeated. Synchronous
    // reset: sampled on the clock edge like everything else in this course.
    //
    // ONE always block, not two. An earlier version of this file had the reset
    // in a second `always @(posedge clk_25mhz)` block driving the same
    // registers, and `make lint` rejected it (MULTIDRIVENPROC). Verilator was
    // right: two procedural blocks assigning one register have no defined
    // ordering in simulation, and synthesis has to guess which wins. A
    // register is driven from exactly one place, and priority between its
    // inputs is expressed with if/else — which also makes the priority
    // visible, rather than implied by the order the blocks happen to appear.
    reg [3:0] count_clean = 0;
    reg [3:0] count_raw   = 0;

    always @(posedge clk_25mhz) begin
        if (btn[2]) begin
            count_clean <= 0;
            count_raw   <= 0;
        end else begin
            if (rise_clean) count_clean <= count_clean + 1'b1;
            if (rise_raw)   count_raw   <= count_raw   + 1'b1;
        end
    end

    // fall_* are deliberately unused: edge_detect reports both edges, and this
    // demo only counts presses. Naming them rather than leaving the port
    // connection empty keeps the intent explicit.
    wire _unused = &{fall_clean, fall_raw, 1'b0};

    assign led = {count_clean, count_raw};
endmodule
