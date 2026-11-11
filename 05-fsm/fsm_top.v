`timescale 1ns/1ps
// Lesson 05 — board demo: a traffic light and a combination lock.
//
//   led[2:0]  the traffic light: red, amber, green, cycling once per second
//   led[7]    the lock, lit when the secret sequence has been entered
//   led[6:4]  the lock's current state, so you can watch it track and reset
//
// Enter the code with the direction buttons. The secret is 1, 2, 1, 3 —
// which in button terms is FIRE2, UP, FIRE2, DOWN. btn[5] (LEFT) resets.
//
// The buttons come through the debouncer promoted to common/rtl/ in lesson 03.
// This is the first lesson to reuse it, and the reason it moved there.
module fsm_top (
    input  wire       clk_25mhz,
    input  wire [5:1] btn,
    output wire [7:0] led
);
    // ---- one tick per second, for the traffic light ------------------------
    // A clock ENABLE, not a divided clock — lesson 04's rule.
    localparam TICK_DIV = 25_000_000;
    reg [24:0] div = 0;
    wire tick = (div == TICK_DIV - 1);
    always @(posedge clk_25mhz)
        div <= tick ? 25'd0 : div + 1'b1;

    wire red, amber, green;
    traffic #(.TICKS_RED(4), .TICKS_GREEN(4)) u_traffic (
        .clk(clk_25mhz), .rst(1'b0), .tick(tick),
        .red(red), .amber(amber), .green(green));

    // ---- the lock's input: debounce, then detect the press edge -----------
    // Four buttons, each debounced independently, then collapsed into a
    // "something was pressed, and it was this one" pair of signals.
    wire [4:1] clean;
    wire [4:1] pressed;
    wire [4:1] released;        // unused here; named rather than left empty

    genvar i;
    generate
        for (i = 1; i <= 4; i = i + 1) begin : btn_in
            debounce #(.COUNT(250_000)) u_db (
                .clk(clk_25mhz), .noisy(btn[i]), .clean(clean[i]));
            edge_detect u_ed (
                .clk(clk_25mhz), .level(clean[i]),
                .rise(pressed[i]), .fall(released[i]));
        end
    endgenerate

    // Encode which button, and announce that one was pressed. Simultaneous
    // presses resolve by priority, which is fine for a lock — and is itself a
    // mux and a decoder, from lesson 02.
    wire       press = |pressed;
    wire [1:0] code  = pressed[1] ? 2'd0 :
                       pressed[2] ? 2'd1 :
                       pressed[3] ? 2'd2 :
                                    2'd3;

    wire unlocked;
    lock u_lock (
        .clk(clk_25mhz), .rst(btn[5]),
        .press(press), .code(code), .unlocked(unlocked));

    // Expose the lock's internal state so the machine is visible while you
    // use it — watching it hold at 2 instead of dropping to 0 on a wrong
    // press is the whole point of the lesson.
    // Reaching into u_lock for its state is a HIERARCHICAL REFERENCE. yosys
    // accepts it and it is handy for exposing something on LEDs, but it is a
    // debug convenience, not a design technique: it couples this module to the
    // internals of another one. If a signal is genuinely wanted outside, make
    // it a port.
    assign led = {unlocked, u_lock.state, 1'b0, green, amber, red};

    wire _unused = &{released, 1'b0};
endmodule
