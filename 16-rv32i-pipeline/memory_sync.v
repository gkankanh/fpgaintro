`timescale 1ns/1ps
// ===========================================================================
//  Lesson 16 — the memory the chip actually has.
//
//  This file is four lines different from lesson 15's memory.v, and the four
//  lines are worth 2,756 LUT4.
//
//      lesson 15:   assign a_data = mem[a_addr];           // combinational
//      lesson 16:   always @(posedge clk) a_data <= ...;   // registered
//
//  Lesson 08 established the rule: a block RAM's output is registered inside
//  the block, so a memory read ASYNCHRONOUSLY can never become a DP16KD, at
//  any size. Lesson 15 had to read asynchronously, because a single-cycle
//  core must have the instruction and the loaded word inside the cycle that
//  asked for them. A pipelined core does not: it asks in one stage and uses
//  the answer in the next, which is exactly the shape a block RAM offers.
//
//  So the pipeline does not merely tolerate the memory's latency. It is the
//  reason the latency is free.
//
//  THE OUTPUT REGISTER IS A PIPELINE REGISTER. `a_data` holds the instruction
//  for the whole of the ID stage -- it IS the IF/ID instruction register, and
//  it lives inside the block RAM where it costs nothing, because the block
//  RAM has it either way. `a_en` is that register's clock enable, which is
//  how the core stalls: hold the enable low and ID keeps the instruction it
//  already has.
// ===========================================================================
module memory_sync #(
    parameter WORDS = 512,
    // Empty means "start uninitialised", which is what a data memory should
    // do: lesson 08's point about X propagation is that a memory you did not
    // write and then read is a bug, and X is the only value that says so.
    parameter FILE  = ""
)(
    input  wire                     clk,

    // ---- port A: instruction fetch, read only ----------------------------
    input  wire                     a_en,        // clock enable on the output reg
    input  wire [$clog2(WORDS)-1:0] a_addr,
    output reg  [31:0]              a_data,

    // ---- port B: data, read or write (never both in one cycle) -----------
    input  wire                     b_en,        // a real load is happening
    input  wire [$clog2(WORDS)-1:0] b_addr,
    output reg  [31:0]              b_data,
    input  wire                     b_we,
    input  wire [3:0]               b_be,
    input  wire [31:0]              b_wdata
);
    reg [31:0] mem [0:WORDS-1];

    generate if (FILE != "") begin : g_init
        initial $readmemh(FILE, mem);
    end endgenerate

    // Port A. One line, and it is the whole reason this design gets block RAM.
    always @(posedge clk)
        if (a_en) a_data <= mem[a_addr];

    // Port B. The read and the write are mutually exclusive by construction
    // -- a load does not store and a store does not load -- which matters,
    // because a DP16KD port does one or the other in a cycle and writing
    // Verilog that asks for both is how you lose the block RAM again.
    //
    // `b_en` comes from the core's dmem_re: the signal lesson 15 wanted and
    // could not have, because a single-cycle core never knew which cycles
    // were loads. A pipeline knows, because the MEM stage is a place rather
    // than a moment.
    always @(posedge clk) begin
        if (b_we) begin
            if (b_be[0]) mem[b_addr][ 7: 0] <= b_wdata[ 7: 0];
            if (b_be[1]) mem[b_addr][15: 8] <= b_wdata[15: 8];
            if (b_be[2]) mem[b_addr][23:16] <= b_wdata[23:16];
            if (b_be[3]) mem[b_addr][31:24] <= b_wdata[31:24];
        end
        if (b_en) b_data <= mem[b_addr];
    end
endmodule
