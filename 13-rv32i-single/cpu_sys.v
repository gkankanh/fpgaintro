`timescale 1ns/1ps
// Lesson 13 — the CPU plus its memories.
//
// Instruction and data memory are SEPARATE and both read combinationally.
// That is a Harvard architecture, and it is not a stylistic choice: a
// single-cycle CPU must fetch an instruction and access data in the SAME
// cycle, so one memory with one port cannot serve both.
//
// Real machines present a single address space and get away with one memory
// by pipelining (fetch in one stage, memory access in a later one -- lesson
// 16) or by using separate caches over shared memory. Here the simplest thing
// that works is two memories, and being explicit about why is better than
// pretending it is a design preference.
//
// Lesson 15 unifies them behind a bus and a memory map.
module cpu_sys #(
    parameter IMEM_WORDS = 256,
    parameter DMEM_WORDS = 256,
    // The default must name a file that EXISTS. yosys elaborates this module
    // with its default parameters before cpu_top overrides them, and
    // $readmemh on a missing file is a hard error at that point -- so a
    // placeholder default breaks `make synth` even though nothing uses it.
    parameter PROGRAM    = "test.hex"
)(
    input  wire        clk,
    input  wire        rst,
    output wire [31:0] pc_out,
    output wire        illegal_out,
    // a window into the data memory, so the board and testbench can look
    input  wire [31:0] peek_addr,
    output wire [31:0] peek_data
);
    // ---- instruction memory: a ROM loaded at elaboration time -------------
    reg [31:0] imem [0:IMEM_WORDS-1];
    initial $readmemh(PROGRAM, imem);

    wire [31:0] imem_addr;
    // addr[1:0] are the byte within the word and are not part of the index,
    // and the high bits are beyond this memory entirely.
    localparam IAW = $clog2(IMEM_WORDS);
    wire [31:0] imem_data = imem[imem_addr[IAW+1:2]];

    // ---- data memory ------------------------------------------------------
    reg [31:0] dmem [0:DMEM_WORDS-1];

    wire [31:0] dmem_addr, dmem_wdata;
    wire [3:0]  dmem_be;
    wire        dmem_we;

    localparam DAW = $clog2(DMEM_WORDS);
    wire [DAW-1:0] dword = dmem_addr[DAW+1:2];

    wire [31:0] dmem_rdata = dmem[dword];

    // Byte-enabled write. Each enabled byte lane is replaced; the others keep
    // their value, which is what makes SB and SH possible on a 32-bit memory.
    always @(posedge clk)
        if (dmem_we) begin
            if (dmem_be[0]) dmem[dword][ 7: 0] <= dmem_wdata[ 7: 0];
            if (dmem_be[1]) dmem[dword][15: 8] <= dmem_wdata[15: 8];
            if (dmem_be[2]) dmem[dword][23:16] <= dmem_wdata[23:16];
            if (dmem_be[3]) dmem[dword][31:24] <= dmem_wdata[31:24];
        end

    assign peek_data = dmem[peek_addr[DAW+1:2]];

    // ---- the address bits nobody looks at ---------------------------------
    //
    // The CPU emits full 32-bit addresses; these memories are 1 KB each, so
    // only addr[9:2] indexes them. The high bits are silently ignored, which
    // means address 0x0000_0100 and address 0xDEAD_0100 hit the same word --
    // the memory ALIASES across the whole address space.
    //
    // That is fine here and wrong in general. A real system DECODES the high
    // bits to choose between RAM, ROM and peripherals, and raises a fault for
    // addresses that match nothing. That decoding is lesson 15's memory map,
    // and it is the difference between a CPU and a computer.
    wire _unused = &{imem_addr[31:IAW+2], imem_addr[1:0],
                     dmem_addr[31:DAW+2], dmem_addr[1:0],
                     peek_addr[31:DAW+2], peek_addr[1:0], 1'b0};

    // ---- the core ---------------------------------------------------------
    cpu u_cpu (
        .clk(clk), .rst(rst),
        .imem_addr(imem_addr), .imem_data(imem_data),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata),
        .dmem_be(dmem_be), .dmem_we(dmem_we), .dmem_rdata(dmem_rdata),
        .pc_out(pc_out), .illegal_out(illegal_out));
endmodule
