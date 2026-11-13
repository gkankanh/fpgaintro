`timescale 1ns/1ps
// ===========================================================================
//  Lesson 16 — the pipelined core with two memories, so that lesson 13's
//  conformance program can run on it UNCHANGED.
//
//  This is lesson 13's cpu_sys, rebuilt around the pipelined core: an
//  instruction memory and a data memory, separate, Harvard. Not because the
//  pipeline needs that -- soc5.v gives it one unified memory and it does not
//  care -- but because lesson 13's test.s writes its results to 0x100, which
//  on a unified machine is where its own instructions live.
//
//  Keeping the memories separate here means the test program is the SAME
//  FILE, byte for byte: ../13-rv32i-single/test.hex. A pipelined core that
//  produces different answers from the single-cycle one on the same image has
//  a bug, and that is the strongest statement this lesson can make.
//
//  Harvard or unified is a property of what you wire to a core, not of the
//  core. That is worth seeing demonstrated rather than asserted.
// ===========================================================================
module cpu5_sys #(
    parameter IMEM_WORDS = 256,
    parameter DMEM_WORDS = 256,
    parameter PROGRAM    = "../13-rv32i-single/test.hex"
)(
    input  wire        clk,
    input  wire        rst,
    output wire [31:0] pc_out,
    output wire        illegal_out,
    output wire        retire_out
);
    localparam IAW = $clog2(IMEM_WORDS);
    localparam DAW = $clog2(DMEM_WORDS);

    wire [31:0] imem_addr, imem_data;
    wire        imem_en;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0]  dmem_be;
    wire        dmem_we, dmem_re;

    // Each memory has a port this system does not use: the instruction
    // memory is never written and the data memory is never fetched from.
    // Naming the dangling outputs rather than leaving the connection empty
    // keeps the linter quiet AND says which port is idle and why.
    wire [31:0] imem_b_unused, dmem_a_unused;

    cpu5 u_cpu (
        .clk(clk), .rst(rst),
        .imem_addr(imem_addr), .imem_en(imem_en), .imem_data(imem_data),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata), .dmem_be(dmem_be),
        .dmem_we(dmem_we), .dmem_re(dmem_re), .dmem_rdata(dmem_rdata),
        .pc_out(pc_out), .illegal_out(illegal_out), .retire_out(retire_out));

    memory_sync #(.WORDS(IMEM_WORDS), .FILE(PROGRAM)) u_imem (
        .clk(clk),
        .a_en(imem_en), .a_addr(imem_addr[IAW+1:2]), .a_data(imem_data),
        .b_en(1'b0), .b_addr({IAW{1'b0}}), .b_data(imem_b_unused),
        .b_we(1'b0), .b_be(4'd0), .b_wdata(32'd0));

    // Uninitialised on purpose: the program writes every word it later reads,
    // and anything it does not write stays X -- so a result that was never
    // computed shows up as X rather than as a plausible zero.
    memory_sync #(.WORDS(DMEM_WORDS), .FILE("")) u_dmem (
        .clk(clk),
        .a_en(1'b0), .a_addr({DAW{1'b0}}), .a_data(dmem_a_unused),
        .b_en(dmem_re), .b_addr(dmem_addr[DAW+1:2]), .b_data(dmem_rdata),
        .b_we(dmem_we), .b_be(dmem_be), .b_wdata(dmem_wdata));

    wire _unused = &{imem_addr[31:IAW+2], imem_addr[1:0],
                     dmem_addr[31:DAW+2], dmem_addr[1:0],
                     imem_b_unused, dmem_a_unused, 1'b0};
endmodule
