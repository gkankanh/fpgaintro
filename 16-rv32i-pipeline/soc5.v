`timescale 1ns/1ps
// ===========================================================================
//  Lesson 16 — lesson 15's computer, with the pipelined core in it.
//
//  Everything outside the core is REUSED, not rewritten: the address decoder
//  and the peripherals are lesson 15's files, included from ../15-soc. The
//  program is lesson 15's firmware.hex, compiled from the same C. So when
//  this machine prints the same forty-six characters, the only thing that
//  changed is how the instructions were executed.
//
//  THREE THINGS ARE DIFFERENT, AND ALL THREE COME FROM THE PIPELINE:
//
//  1. THE MEMORY IS A BLOCK RAM. memory_sync.v replaces memory.v, and the
//     2,756 LUT4 that lesson 15 spent on 2 KB of asynchronous array become
//     two DP16KD out of the 85F's 208.
//
//  2. THE DECODER CAN FAULT ON LOADS. Lesson 15 could only report a bad
//     STORE, because its core never said which cycles were loads. This core
//     has a MEM stage -- being in the memory stage is a place, not a moment
//     -- so `dmem_re` exists, and feeding `we | re` into the decoder's
//     access strobe makes a load from nowhere reportable too.
//
//  3. THE I/O READ PATH NEEDS A REGISTER. A block RAM answers one cycle
//     after it is asked. The peripherals answer immediately, combinationally,
//     as they always did. Those are now DIFFERENT TIMES, and the bus has to
//     line them up -- see the read mux below. That is not a wart; it is what
//     every real bus does, and it is why real buses have a data-valid signal.
// ===========================================================================
module soc5 #(
    parameter MEM_WORDS = 512,
    parameter FIRMWARE  = "../15-soc/firmware.hex",
    parameter CLK_HZ    = 25_000_000,
    parameter BAUD      = 115_200
)(
    input  wire        clk,
    input  wire        rst,

    output wire [7:0]  gpo,
    input  wire [15:0] gpi,
    output wire        uart_tx_pin,
    input  wire        uart_rx_pin,

    output wire [31:0] pc_out,
    output wire        illegal_out,
    output wire        fault_out,
    output wire        halt_out,
    output wire [7:0]  halt_code,
    output wire        retire_out
);
    localparam AW = $clog2(MEM_WORDS);

    wire [31:0] imem_addr, imem_data;
    wire        imem_en;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0]  dmem_be;
    wire        dmem_we, dmem_re;

    cpu5 u_cpu (
        .clk(clk), .rst(rst),
        .imem_addr(imem_addr), .imem_en(imem_en), .imem_data(imem_data),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata), .dmem_be(dmem_be),
        .dmem_we(dmem_we), .dmem_re(dmem_re), .dmem_rdata(dmem_rdata),
        .pc_out(pc_out), .illegal_out(illegal_out), .retire_out(retire_out));

    // ---- the decode: lesson 15's file, told the whole truth ---------------
    wire sel_mem, sel_io, fault;

    busdec #(.MEM_BYTES(MEM_WORDS * 4)) u_dec (
        .addr(dmem_addr), .access(dmem_we || dmem_re),
        .sel_mem(sel_mem), .sel_io(sel_io), .fault(fault));

    // ---- the memory: one array, two ports, and now a block RAM ------------
    wire [31:0] mem_rdata;

    memory_sync #(.WORDS(MEM_WORDS), .FILE(FIRMWARE)) u_mem (
        .clk(clk),
        .a_en(imem_en), .a_addr(imem_addr[AW+1:2]), .a_data(imem_data),
        .b_en(dmem_re && sel_mem), .b_addr(dmem_addr[AW+1:2]),
        .b_data(mem_rdata),
        .b_we(dmem_we && sel_mem), .b_be(dmem_be), .b_wdata(dmem_wdata));

    // ---- the peripherals: lesson 15's file, unchanged ---------------------
    wire [31:0] io_rdata;

    mmio #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_io (
        .clk(clk), .rst(rst),
        .addr(dmem_addr[7:0]), .we(dmem_we && sel_io), .wdata(dmem_wdata),
        .rdata(io_rdata),
        .gpo(gpo), .gpi(gpi),
        .uart_tx_pin(uart_tx_pin), .uart_rx_pin(uart_rx_pin),
        .halt(halt_out), .halt_code(halt_code));

    // ---- the read mux, one cycle late -------------------------------------
    //
    // The core asks in MEM and uses the answer in WB, so everything on this
    // bus must deliver its data in the cycle AFTER the address. The block RAM
    // does that by itself: its output register is the delay. The peripherals
    // do not -- `io_rdata` is a combinational mux on the register file inside
    // mmio.v, valid in the same cycle as the address.
    //
    // So the I/O data gets a register of its own, and the SELECT gets one too:
    // deciding "was that an I/O read?" has to be remembered alongside the data
    // it decided about, because by the time the answer is used, the address
    // bus has moved on to the next instruction.
    //
    // Getting this wrong is a classic bug with an unmistakable signature: the
    // program reads a peripheral and gets the value belonging to the PREVIOUS
    // access.
    reg [31:0] io_rdata_q = 0;
    reg        io_sel_q   = 0;

    always @(posedge clk) begin
        io_rdata_q <= io_rdata;
        io_sel_q   <= dmem_re && sel_io;
    end

    assign dmem_rdata = io_sel_q ? io_rdata_q : mem_rdata;

    // ---- the fault latch ---------------------------------------------------
    // Sticky, as in lesson 15. A store OR a load to an address that belongs to
    // nothing now lands here.
    reg fault_seen = 0;
    always @(posedge clk)
        if (rst)        fault_seen <= 0;
        else if (fault) fault_seen <= 1;

    assign fault_out = fault_seen;

    wire _unused = &{imem_addr[31:AW+2], imem_addr[1:0], dmem_addr[1:0], 1'b0};
endmodule
