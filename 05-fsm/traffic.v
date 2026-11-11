`timescale 1ns/1ps
// Lesson 05 — a traffic light, as the canonical state machine.
//
// THE CANONICAL FORM. Every FSM in this course and in lessons 09 and 13 is
// written this way, and it is worth internalising as a shape:
//
//   1. a STATE REGISTER            — one clocked block, nothing else in it
//   2. NEXT-STATE LOGIC            — one combinational block, pure function
//   3. OUTPUT LOGIC                — combinational, from state (Moore)
//
// Splitting 1 from 2 is not stylistic. It keeps the only sequential element
// trivially obvious, which means you can read the next-state block as a plain
// truth table and never wonder what is registered.
//
// This is a MOORE machine: the outputs depend only on which state it is in,
// never on the inputs. See lock.v for the contrast.
module traffic #(
    parameter TICKS_RED   = 4,
    parameter TICKS_GREEN = 4
)(
    input  wire clk,
    input  wire rst,
    input  wire tick,          // one-clock pulse: advance time by one unit
    output wire red,
    output wire amber,
    output wire green
);
    // State encoding. Written as named constants, never as bare numbers in
    // the case statement — `2'd2` tells a reader nothing and `S_GREEN` tells
    // them everything.
    localparam [1:0] S_RED       = 2'd0,
                     S_RED_AMBER = 2'd1,
                     S_GREEN     = 2'd2,
                     S_AMBER     = 2'd3;

    // ENCODING. yosys's `fsm` pass detects this register as a state variable
    // and re-encodes it as it sees fit — so the constants above are a
    // suggestion, not an instruction. To take control, put an attribute on the
    // state register itself (NOT on the module; it has no effect there):
    //
    //     (* fsm_encoding = "one-hot" *) reg [1:0] state = S_RED;
    //     (* fsm_encoding = "binary"  *) reg [1:0] state = S_RED;
    //     (* fsm_encoding = "none"    *) reg [1:0] state = S_RED;   // keep mine
    //
    // Binary uses ceil(log2(N)) flops and needs a decoder to answer "which
    // state am I in". One-hot uses N flops, exactly one high, so that question
    // becomes a single wire with no decoding at all.
    //
    // The textbook trade is "one-hot costs flops, saves logic", and on an FPGA
    // the flops are nearly free because every logic cell has one whether you
    // use it or not. So one-hot is supposed to win here.
    //
    // For THIS machine it loses badly — 41 LUT4 against 12. Four states is
    // small, so one-hot's saving on decode never materialises, while every
    // comparison against the state has to be built from four bits instead of
    // two. One-hot earns its keep on wide state machines, not narrow ones.
    //
    // Which is the actual lesson: measure, do not inherit an opinion. The
    // README has the full table.
    reg [1:0] state = S_RED;
    reg [1:0] next;
    reg [2:0] timer = 0;

    // How long each state lasts, in ticks. A function of state alone, so it
    // belongs with the next-state logic rather than inside the clocked block.
    reg [2:0] duration;
    always @(*)
        case (state)
            S_RED:       duration = TICKS_RED[2:0];
            S_RED_AMBER: duration = 3'd1;
            S_GREEN:     duration = TICKS_GREEN[2:0];
            S_AMBER:     duration = 3'd1;
            default:     duration = 3'd1;
        endcase

    wire expired = tick && (timer + 1'b1 >= duration);

    // ---- 2. next-state logic: combinational, a pure function --------------
    always @(*) begin
        next = state;                 // default: stay put. Assign FIRST, so
                                      // every path is covered and no latch
                                      // can be inferred (lesson 02).
        if (expired)
            case (state)
                S_RED:       next = S_RED_AMBER;
                S_RED_AMBER: next = S_GREEN;
                S_GREEN:     next = S_AMBER;
                S_AMBER:     next = S_RED;
                default:     next = S_RED;
            endcase
    end

    // ---- 1. the state register: one clocked block, and nothing else -------
    always @(posedge clk)
        if (rst) begin
            state <= S_RED;
            timer <= 0;
        end else begin
            state <= next;
            if (tick) timer <= expired ? 3'd0 : timer + 1'b1;
        end

    // ---- 3. output logic: Moore — from state alone ------------------------
    // Written as continuous assignments because each lamp is a simple
    // predicate on the state. A `case` assigning three regs would do equally
    // well; this reads better for three independent one-bit outputs.
    assign red   = (state == S_RED) || (state == S_RED_AMBER);
    assign amber = (state == S_RED_AMBER) || (state == S_AMBER);
    assign green = (state == S_GREEN);
endmodule
