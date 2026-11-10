`timescale 1ns/1ps
// Lesson 04 — crossing between clock domains without corrupting anything.
//
// Two clocks that are not derived from each other have no fixed phase
// relationship. So a signal from domain A, sampled by a flip-flop in domain B,
// will sometimes change at exactly the wrong moment — within the flop's setup
// or hold window.
//
// When that happens the flop does not pick a value. It goes METASTABLE: its
// output sits between 0 and 1 for an unbounded time before resolving
// arbitrarily. Downstream logic reading it may disagree about which it saw.
//
// Note carefully: THIS CANNOT BE SIMULATED. Verilog has no notion of setup
// time, so iverilog will always give you a clean, defined, repeatable answer.
// Simulation cannot show you this bug and cannot prove you have fixed it. The
// defence has to be structural — you follow the rule because the rule is
// correct, not because a test told you to.

// ---------------------------------------------------------------------------
//  A two-flop synchroniser: the standard defence, for ONE bit.
//
//  The first flop may go metastable. The second samples it a full clock period
//  later, by which time it has almost certainly resolved. "Almost certainly" is
//  the honest phrasing: the metastability window is probabilistic, and two
//  flops push the mean time between failures out to years or centuries. Three
//  flops for a very fast clock or a very critical signal.
//
//  What you give up is latency (two clocks) and any guarantee about *which*
//  edge the change is seen on. That is fine for a level. It is not fine for a
//  bus — see below.
// ---------------------------------------------------------------------------
module sync2 (
    input  wire clk,
    input  wire d_async,
    output wire q
);
    reg [1:0] s = 0;

    always @(posedge clk)
        s <= {s[0], d_async};

    assign q = s[1];
endmodule


// ---------------------------------------------------------------------------
//  Crossing a BUS. A synchroniser per bit is a bug, not a solution.
//
//  Put sync2 on each of 32 bits and each bit resolves independently. Some
//  arrive on one clock, some on the next, and the destination briefly sees a
//  value that was never sent — 0x0F -> 0x10 can be observed as 0x1F or 0x00.
//  For a counter crossing domains this is not theoretical; it is routine.
//
//  The fix is to synchronise ONE bit and use it to say when the others are
//  safe to read. Here that bit is a toggling request:
//
//    source:       latch the data, then flip `req`
//    destination:  synchronise `req`, and when it changes, read the data
//
//  The data itself crosses with no synchroniser at all, and that is correct:
//  by the time the destination notices `req` has flipped, the data has been
//  stable for at least two destination clock periods. Nothing is sampled
//  while it is moving.
//
//  THE CONSTRAINT: the source must not raise `src_valid` again until the
//  destination has seen the previous one — at least two or three destination
//  clocks. Going faster than the destination can look is how this design
//  fails, and nothing here enforces it. For a stream rather than occasional
//  values you want a proper asynchronous FIFO.
// ---------------------------------------------------------------------------
module cdc_bus #(
    parameter W = 32
)(
    // source domain
    input  wire         src_clk,
    input  wire         src_valid,    // one-clock pulse: src_data is ready
    input  wire [W-1:0] src_data,
    // destination domain
    input  wire         dst_clk,
    output reg  [W-1:0] dst_data  = 0,
    output reg          dst_valid = 0 // one-clock pulse in the dst domain
);
    // --- source side: hold the data still, then announce it ----------------
    reg [W-1:0] hold = 0;
    reg         req  = 0;

    always @(posedge src_clk)
        if (src_valid) begin
            hold <= src_data;
            req  <= ~req;        // toggle, not pulse: a pulse in a fast domain
        end                      // can be missed entirely by a slow one

    // --- destination side: synchronise the single bit, detect its change ---
    // rs[0] is the raw sample (may be metastable), rs[1] the synchronised
    // value, rs[2] its previous value — so rs[2]^rs[1] is "it just changed".
    reg [2:0] rs = 0;

    always @(posedge dst_clk)
        rs <= {rs[1:0], req};

    wire req_changed = rs[2] ^ rs[1];

    always @(posedge dst_clk) begin
        dst_valid <= req_changed;
        if (req_changed) dst_data <= hold;
    end
endmodule
