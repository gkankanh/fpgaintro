`timescale 1ns/1ps
// Lesson 05 — Moore versus Mealy, as two machines that detect the same thing.
//
// Both watch a one-bit input and assert their output when they have just seen
// the sequence 1, 0, 1. They differ in where the output comes from:
//
//   MOORE: output is a function of STATE alone.
//          Registered, glitch-free, and one clock LATE.
//
//   MEALY: output is a function of STATE and INPUT.
//          Immediate, fewer states, but combinational — it inherits any glitch
//          on the input, and it is live during the same cycle as the input.
//
// Neither is correct in general. The question is always whether the consumer
// needs the answer now or needs it clean.

// ---------------------------------------------------------------------------
//  Moore: four states. The fourth exists purely to produce the output.
// ---------------------------------------------------------------------------
module seq_moore (
    input  wire clk,
    input  wire rst,
    input  wire d,
    output wire found
);
    localparam [1:0] S_IDLE = 2'd0,   // nothing useful seen
                     S_1    = 2'd1,   // seen "1"
                     S_10   = 2'd2,   // seen "10"
                     S_101  = 2'd3;   // seen "101" -> assert

    reg [1:0] state = S_IDLE;
    reg [1:0] next;

    always @(*) begin
        next = state;
        case (state)
            // On a 0 we are back to nothing; on a 1 we have a prefix.
            S_IDLE: next = d ? S_1  : S_IDLE;
            S_1:    next = d ? S_1  : S_10;
            // From "10", a 1 completes the sequence.
            S_10:   next = d ? S_101 : S_IDLE;
            // Having reported, the trailing 1 is itself a fresh prefix — so
            // overlapping matches are found. "10101" contains two.
            S_101:  next = d ? S_1  : S_10;
            default: next = S_IDLE;
        endcase
    end

    always @(posedge clk)
        if (rst) state <= S_IDLE;
        else     state <= next;

    assign found = (state == S_101);     // from state alone
endmodule


// ---------------------------------------------------------------------------
//  Mealy: three states. The output is produced on the transition, so the
//  fourth state is not needed — one of the classic Mealy savings.
// ---------------------------------------------------------------------------
module seq_mealy (
    input  wire clk,
    input  wire rst,
    input  wire d,
    output wire found
);
    localparam [1:0] S_IDLE = 2'd0,
                     S_1    = 2'd1,
                     S_10   = 2'd2;

    reg [1:0] state = S_IDLE;
    reg [1:0] next;

    always @(*) begin
        next = state;
        case (state)
            S_IDLE: next = d ? S_1 : S_IDLE;
            S_1:    next = d ? S_1 : S_10;
            S_10:   next = d ? S_1 : S_IDLE;   // the 1 that completes it is
            default: next = S_IDLE;            // also the next prefix
        endcase
    end

    always @(posedge clk)
        if (rst) state <= S_IDLE;
        else     state <= next;

    // From state AND input: asserted during the cycle the final 1 is present,
    // a full clock earlier than the Moore version.
    assign found = (state == S_10) && d;
endmodule


// ---------------------------------------------------------------------------
//  The deliverable: a lock that opens on a sequence of button presses.
//
//  This is the same idea as the detectors above, scaled up to a 4-symbol
//  sequence over a 2-bit alphabet, and it shows the one thing a sequence
//  detector must get right: WHAT HAPPENS ON A WRONG SYMBOL.
//
//  The naive answer — go back to the start — is wrong, and subtly so. If the
//  code is 1,2,1,3 and you press 1,2,1,2, the second "1,2" is a valid prefix
//  and must be kept. Resetting to the start throws it away and the lock
//  refuses a correct code. Getting this right by hand is fiddly; it is
//  exactly what the KMP string-matching algorithm automates, and exactly the
//  kind of thing lesson 14's formal tools find for you.
//
//  Here the sequence is short enough to reason about directly, and the
//  testbench checks the awkward cases.
// ---------------------------------------------------------------------------
module lock (
    input  wire       clk,
    input  wire       rst,
    input  wire       press,       // one-clock pulse: a button went down
    input  wire [1:0] code,        // which button (0..3)
    output wire       unlocked
);
    // The secret: 1, 2, 1, 3
    localparam [1:0] C0 = 2'd1, C1 = 2'd2, C2 = 2'd1, C3 = 2'd3;

    localparam [2:0] S_0    = 3'd0,   // nothing matched
                     S_1    = 3'd1,   // matched C0
                     S_2    = 3'd2,   // matched C0,C1
                     S_3    = 3'd3,   // matched C0,C1,C2
                     S_OPEN = 3'd4;   // matched all four

    reg [2:0] state = S_0;
    reg [2:0] next;

    always @(*) begin
        next = state;
        if (press)
            case (state)
                S_0: next = (code == C0) ? S_1 : S_0;

                S_1: next = (code == C1) ? S_2 :
                            // A wrong symbol here could still be the start of
                            // a new attempt — C0 itself is the obvious case.
                            (code == C0) ? S_1 : S_0;

                S_2: next = (code == C2) ? S_3 :
                            (code == C0) ? S_1 : S_0;

                // The interesting one. Expecting C3; if we get C1 instead, the
                // last two symbols were C2,C1 = 1,2, which is the prefix
                // C0,C1 — so we are two symbols in, not zero.
                S_3: next = (code == C3) ? S_OPEN :
                            (code == C1) ? S_2 :
                            (code == C0) ? S_1 : S_0;

                // Stay open until reset.
                S_OPEN:  next = S_OPEN;
                default: next = S_0;
            endcase
    end

    always @(posedge clk)
        if (rst) state <= S_0;
        else     state <= next;

    assign unlocked = (state == S_OPEN);     // Moore: safe, and one clock late
endmodule
