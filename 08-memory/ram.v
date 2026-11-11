`timescale 1ns/1ps
// Lesson 08 — memories, and the coding patterns that get you one.
//
// You do not instantiate a block RAM. You write Verilog in a particular shape
// and the synthesiser RECOGNISES it. Get the shape right and you get a
// DP16KD — a hard 18 Kbit dual-port memory block, of which the 85F has 208.
// Get it subtly wrong and you get flip-flops, which for anything above a few
// dozen bits is a disaster you will only notice in the resource report.
//
// So this file is four memories that differ only in small ways, and the
// lesson is what `make synth` says about each.
//
// All default to W=32 — the CPU's width. Lesson 13 stores its program in one
// of these and lesson 15 gives it a data memory.

// ---------------------------------------------------------------------------
//  1. SINGLE PORT, synchronous read. The canonical shape.
//
//  The rules the synthesiser is looking for:
//    * the array is a `reg [W-1:0] mem [0:DEPTH-1]`
//    * reads and writes both happen inside ONE `always @(posedge clk)`
//    * the read result goes into a register, so it appears a clock LATER
//
//  That last point is not a style choice — it is what the hardware does. A
//  block RAM's output is registered inside the block. You cannot have a
//  combinational read from a BRAM, and asking for one is how you accidentally
//  get flip-flops instead.
// ---------------------------------------------------------------------------
module ram_sp #(
    parameter W     = 32,
    parameter DEPTH = 1024
)(
    input  wire                     clk,
    input  wire                     we,
    input  wire [$clog2(DEPTH)-1:0] addr,
    input  wire [W-1:0]             din,
    output reg  [W-1:0]             dout
);
    reg [W-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (we) mem[addr] <= din;
        dout <= mem[addr];        // registered: available next clock
    end
endmodule


// ---------------------------------------------------------------------------
//  2. The same memory with an ASYNCHRONOUS read. Looks tidier. Is a trap.
//
//  `assign dout = mem[addr];` reads combinationally — the data is there in
//  the same cycle, no latency to think about. It is also something a block RAM
//  physically cannot do, so this memory can NEVER become a DP16KD, at any
//  size.
//
//  What you get instead is distributed RAM (TRELLIS_DPR16X4 — 16 words of 4
//  bits, built from a logic cell's LUTs) plus a mux tree to select among them.
//  Measured, at W=32:
//
//      DEPTH    ram_sp (sync read)       ram_async (comb read)
//         16    8 DPR16X4 + 32 FF        8 DPR16X4
//         64    1 DP16KD                 32 DPR16X4 + 132 LUT4 + 96 muxes
//        256    1 DP16KD                 128 DPR16X4 + 919 LUT4 + 672 muxes
//       1024    2 DP16KD                 (do not)
//
//  At 256 entries the asynchronous version costs 919 LUT4s where the
//  synchronous one costs a single block RAM — and the 85F has 208 blocks
//  sitting idle either way.
//
//  Note the top row, though: at 16 entries BOTH produce distributed RAM, and
//  the asynchronous one is actually CHEAPER because it needs no output
//  register. Small asynchronous arrays have a legitimate home, and that is
//  exactly how a 16-entry register file gets built. The threshold is tens of
//  entries, not thousands.
// ---------------------------------------------------------------------------
module ram_async #(
    parameter W     = 32,
    parameter DEPTH = 1024
)(
    input  wire                     clk,
    input  wire                     we,
    input  wire [$clog2(DEPTH)-1:0] addr,
    input  wire [W-1:0]             din,
    output wire [W-1:0]             dout
);
    reg [W-1:0] mem [0:DEPTH-1];

    always @(posedge clk)
        if (we) mem[addr] <= din;

    assign dout = mem[addr];      // combinational: NOT what a BRAM can do
endmodule


// ---------------------------------------------------------------------------
//  3. SIMPLE DUAL PORT: one write port, one read port, independent addresses.
//
//  This is what a framebuffer wants — something writes pixels by coordinate
//  while something else reads them in raster order — and what a CPU's
//  instruction memory wants. The DP16KD supports it natively, so it costs the
//  same as the single-port version: one block.
//
//  Note the two ports can even have different clocks, which is how a video
//  pipeline crosses domains without the lesson 04 handshake. That is the one
//  case where crossing a bus between clocks is safe without synchronisers,
//  because the memory block is built for it.
// ---------------------------------------------------------------------------
module ram_sdp #(
    parameter W     = 32,
    parameter DEPTH = 1024
)(
    input  wire                     wclk,
    input  wire                     we,
    input  wire [$clog2(DEPTH)-1:0] waddr,
    input  wire [W-1:0]             din,

    input  wire                     rclk,
    input  wire [$clog2(DEPTH)-1:0] raddr,
    output reg  [W-1:0]             dout
);
    reg [W-1:0] mem [0:DEPTH-1];

    always @(posedge wclk)
        if (we) mem[waddr] <= din;

    always @(posedge rclk)
        dout <= mem[raddr];
endmodule


// ---------------------------------------------------------------------------
//  4. TRUE DUAL PORT: both ports can read AND write.
//
//  Needed when two masters share one memory — a CPU and a DMA engine, or two
//  cores. Also the shape a register file would want if it needed two writes
//  per cycle (RV32I does not: one write, two reads — lesson 11).
//
//  THE HAZARD: if both ports address the same word in the same cycle and at
//  least one is writing, the result is undefined. Real silicon gives you
//  something; which something depends on the block's configuration, and
//  simulation will cheerfully give you a different answer. Arbitrate outside
//  the memory, or guarantee by construction that it cannot happen.
// ---------------------------------------------------------------------------
module ram_tdp #(
    parameter W     = 32,
    parameter DEPTH = 1024
)(
    input  wire                     clk,

    input  wire                     we_a,
    input  wire [$clog2(DEPTH)-1:0] addr_a,
    input  wire [W-1:0]             din_a,
    output reg  [W-1:0]             dout_a,

    input  wire                     we_b,
    input  wire [$clog2(DEPTH)-1:0] addr_b,
    input  wire [W-1:0]             din_b,
    output reg  [W-1:0]             dout_b
);
    reg [W-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (we_a) mem[addr_a] <= din_a;
        dout_a <= mem[addr_a];
    end

    always @(posedge clk) begin
        if (we_b) mem[addr_b] <= din_b;
        dout_b <= mem[addr_b];
    end
endmodule
