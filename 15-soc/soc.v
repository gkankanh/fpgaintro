`timescale 1ns/1ps
// ===========================================================================
//  Lesson 15 — the system on chip.
//
//  A CPU, a memory and some peripherals, joined by a bus and an address map.
//  That is a computer, and this file is where lesson 13's core stops being a
//  piece of logic that executes instructions and becomes a machine that can
//  run a program somebody compiled.
//
//      cpu ──fetch addr──────────────────> memory port A ──> instruction
//          │
//          └─data addr/wdata/be/we──┬──> busdec ──> sel_mem, sel_io, fault
//                                   ├──> memory port B  ──┐
//                                   └──> mmio            ─┴─> read mux ─> cpu
//
//  THE BUS HAS NO `ready` SIGNAL, and that absence is the design.
//
//  A real bus -- AXI, Wishbone, even the simplest handshake -- lets the
//  TARGET say "not yet". That is what makes a slow peripheral, a cache miss or
//  an off-chip memory possible. This bus cannot: the lesson 13 core has no way
//  to wait, because a single-cycle CPU finishes the instruction in the cycle
//  it started. Every target here must answer COMBINATIONALLY, within the same
//  cycle, which is why the memory is built from LUTs instead of block RAM and
//  why nothing slower than a register can ever be attached.
//
//  So the missing `ready` is not a simplification for teaching. It is the
//  single-cycle decision of lesson 13, arriving two lessons later as a
//  constraint on what can be plugged in. Lesson 16's pipeline is the first
//  design in this course that can wait, and it is no coincidence that it is
//  also the first that can use the chip's real memories.
// ===========================================================================
module soc #(
    parameter MEM_WORDS = 512,                   // 512 words = 2 KB
    parameter FIRMWARE  = "firmware.hex",
    parameter CLK_HZ    = 25_000_000,
    parameter BAUD      = 115_200
)(
    input  wire        clk,
    input  wire        rst,

    // the board
    output wire [7:0]  gpo,                      // LEDs
    input  wire [15:0] gpi,                      // {sw[3:0], btn[6:1]}
    output wire        uart_tx_pin,
    input  wire        uart_rx_pin,

    // visible state, for the testbench and the board
    output wire [31:0] pc_out,
    output wire        illegal_out,              // an undefined instruction
    output wire        fault_out,                // a store to an unmapped address
    output wire        halt_out,
    output wire [7:0]  halt_code
);
    localparam AW = $clog2(MEM_WORDS);

    // ---- the core (lesson 13, not one line changed) -----------------------
    wire [31:0] imem_addr, imem_data;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0]  dmem_be;
    wire        dmem_we;

    cpu u_cpu (
        .clk(clk), .rst(rst),
        .imem_addr(imem_addr), .imem_data(imem_data),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata),
        .dmem_be(dmem_be), .dmem_we(dmem_we), .dmem_rdata(dmem_rdata),
        .pc_out(pc_out), .illegal_out(illegal_out));

    // ---- the decode -------------------------------------------------------
    wire sel_mem, sel_io, fault;

    busdec #(.MEM_BYTES(MEM_WORDS * 4)) u_dec (
        .addr(dmem_addr), .access(dmem_we),
        .sel_mem(sel_mem), .sel_io(sel_io), .fault(fault));

    // ---- the memory -------------------------------------------------------
    // addr[1:0] is the byte within the word; the word index is addr[AW+1:2].
    // A data address beyond the array still indexes it (the high bits are
    // dropped here, as in lesson 13) -- but now `sel_mem` is false for such an
    // address, so the write is suppressed and only the stale read remains.
    wire [AW-1:0] a_word = imem_addr[AW+1:2];
    wire [AW-1:0] b_word = dmem_addr[AW+1:2];
    wire [31:0]   mem_rdata;

    memory #(.WORDS(MEM_WORDS), .FILE(FIRMWARE)) u_mem (
        .clk(clk),
        .a_addr(a_word), .a_data(imem_data),
        .b_addr(b_word), .b_data(mem_rdata),
        .b_we(dmem_we && sel_mem), .b_be(dmem_be), .b_wdata(dmem_wdata));

    // ---- the peripherals --------------------------------------------------
    wire [31:0] io_rdata;

    mmio #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_io (
        .clk(clk), .rst(rst),
        .addr(dmem_addr[7:0]), .we(dmem_we && sel_io), .wdata(dmem_wdata),
        .rdata(io_rdata),
        .gpo(gpo), .gpi(gpi),
        .uart_tx_pin(uart_tx_pin), .uart_rx_pin(uart_rx_pin),
        .halt(halt_out), .halt_code(halt_code));

    // ---- the read mux: the bus's other half -------------------------------
    // One mux, one cycle, no arbitration -- there is a single master. Note
    // that a load from an unmapped address lands here as `mem_rdata` of some
    // aliased word rather than a fault, for the reason busdec.v gives.
    assign dmem_rdata = sel_io ? io_rdata : mem_rdata;

    // ---- the fault latch --------------------------------------------------
    // Sticky, because a one-cycle pulse is no use to anybody: a human reading
    // LEDs and a testbench checking at the end both need it to still be there.
    // This is the same reasoning that gave the UART its rx_valid bit.
    reg fault_seen = 0;
    always @(posedge clk)
        if (rst)        fault_seen <= 0;
        else if (fault) fault_seen <= 1;

    assign fault_out = fault_seen;

    // The byte-within-word bits, and the address bits above this memory.
    // The fetch port's high bits: the decoder never sees them, because the
    // fetch does not pass through it (busdec.v says why). The data address is
    // used in full -- by the decoder -- which is the difference between an
    // address that is checked and one that merely indexes.
    wire _unused = &{imem_addr[31:AW+2], imem_addr[1:0], dmem_addr[1:0], 1'b0};
endmodule
