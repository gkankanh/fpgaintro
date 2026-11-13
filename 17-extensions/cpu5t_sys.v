`timescale 1ns/1ps
// ===========================================================================
//  Lesson 17 — the trapping core with two plain memories, so that lesson
//  13's conformance program can run on it unchanged.
//
//  This is lesson 16's cpu5_sys with cpu5t in place of cpu5, and it exists
//  for one reason: to prove that adding privileged state did not change what
//  the base instruction set does.
//
//  That is not a formality. decode_ext.v now claims instruction encodings
//  that lesson 12's decoder used to reject, and a mistake in it -- one funct3
//  compared too loosely, one opcode matched too broadly -- would quietly
//  redefine an ordinary instruction. Running the same eighty-eight
//  instructions and demanding the same thirty answers is how you find out.
//
//  `mtip` is tied low here: there is no timer in this system, so this core
//  can take exceptions but never an interrupt.
// ===========================================================================
module cpu5t_sys #(
    parameter IMEM_WORDS = 256,
    parameter DMEM_WORDS = 256,
    parameter PROGRAM    = "../13-rv32i-single/test.hex"
)(
    input  wire        clk,
    input  wire        rst,
    output wire [31:0] pc_out,
    output wire        trap_out,
    output wire        retire_out
);
    localparam IAW = $clog2(IMEM_WORDS);
    localparam DAW = $clog2(DMEM_WORDS);

    wire [31:0] imem_addr, imem_data;
    wire        imem_en;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0]  dmem_be;
    wire        dmem_we, dmem_re;
    wire [31:0] mcause;
    wire [31:0] imem_b_unused, dmem_a_unused;

    cpu5t u_cpu (
        .clk(clk), .rst(rst),
        .imem_addr(imem_addr), .imem_en(imem_en), .imem_data(imem_data),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata), .dmem_be(dmem_be),
        .dmem_we(dmem_we), .dmem_re(dmem_re), .dmem_rdata(dmem_rdata),
        .mtip(1'b0),
        .pc_out(pc_out), .trap_out(trap_out), .mcause_out(mcause),
        .retire_out(retire_out));

    memory_sync #(.WORDS(IMEM_WORDS), .FILE(PROGRAM)) u_imem (
        .clk(clk),
        .a_en(imem_en), .a_addr(imem_addr[IAW+1:2]), .a_data(imem_data),
        .b_en(1'b0), .b_addr({IAW{1'b0}}), .b_data(imem_b_unused),
        .b_we(1'b0), .b_be(4'd0), .b_wdata(32'd0));

    memory_sync #(.WORDS(DMEM_WORDS), .FILE("")) u_dmem (
        .clk(clk),
        .a_en(1'b0), .a_addr({DAW{1'b0}}), .a_data(dmem_a_unused),
        .b_en(dmem_re), .b_addr(dmem_addr[DAW+1:2]), .b_data(dmem_rdata),
        .b_we(dmem_we), .b_be(dmem_be), .b_wdata(dmem_wdata));

    wire _unused = &{imem_addr[31:IAW+2], imem_addr[1:0],
                     dmem_addr[31:DAW+2], dmem_addr[1:0],
                     imem_b_unused, dmem_a_unused, mcause, 1'b0};
endmodule
