`timescale 1ns/1ps
// ===========================================================================
//  Lesson 17 — the computer, with a timer and somewhere for traps to go.
//
//  Lesson 16's system, with three changes and no rewriting:
//
//    * the core is cpu5t, which traps instead of halting
//    * a new peripheral, the machine timer, whose `mtip` output is wired
//      straight into the core -- an interrupt line, literally a wire
//    * the memory is 16 KB rather than 2, because lesson 16 moved it into
//      block RAM and made that nearly free
//
//  ADDING A PERIPHERAL IS A SELECT LINE AND A MUX ENTRY. busdec.v is lesson
//  15's file, unchanged, and still only answers "memory, I/O, or nothing".
//  Splitting the I/O window between two devices happens here, with one bit:
//
//      0x8000_0000 .. 0x8000_003F   mmio   (lesson 15's peripherals)
//      0x8000_0040 .. 0x8000_007F   timer  (this lesson's)
//
//  That is what a memory map buys. Nothing about the core, the decoder, the
//  compiler or the linker script changes because a device was added -- only
//  a header file gains four addresses.
// ===========================================================================
module soc17 #(
    parameter MEM_WORDS = 4096,                  // 16 KB, in four block RAMs
    parameter FIRMWARE  = "firmware.hex",
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
    output wire        fault_out,
    output wire        halt_out,
    output wire [7:0]  halt_code,
    output wire        retire_out,
    output wire        trap_out,
    output wire [31:0] mcause_out
);
    localparam AW = $clog2(MEM_WORDS);

    wire [31:0] imem_addr, imem_data;
    wire        imem_en;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0]  dmem_be;
    wire        dmem_we, dmem_re;
    wire        mtip;

    cpu5t u_cpu (
        .clk(clk), .rst(rst),
        .imem_addr(imem_addr), .imem_en(imem_en), .imem_data(imem_data),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata), .dmem_be(dmem_be),
        .dmem_we(dmem_we), .dmem_re(dmem_re), .dmem_rdata(dmem_rdata),
        .mtip(mtip),
        .pc_out(pc_out), .trap_out(trap_out), .mcause_out(mcause_out),
        .retire_out(retire_out));

    // ---- the decode, lesson 15's file -------------------------------------
    wire sel_mem, sel_io, fault;

    busdec #(.MEM_BYTES(MEM_WORDS * 4)) u_dec (
        .addr(dmem_addr), .access(dmem_we || dmem_re),
        .sel_mem(sel_mem), .sel_io(sel_io), .fault(fault));

    // ---- the memory, lesson 16's file -------------------------------------
    wire [31:0] mem_rdata;

    memory_sync #(.WORDS(MEM_WORDS), .FILE(FIRMWARE)) u_mem (
        .clk(clk),
        .a_en(imem_en), .a_addr(imem_addr[AW+1:2]), .a_data(imem_data),
        .b_en(dmem_re && sel_mem), .b_addr(dmem_addr[AW+1:2]),
        .b_data(mem_rdata),
        .b_we(dmem_we && sel_mem), .b_be(dmem_be), .b_wdata(dmem_wdata));

    // ---- the peripherals ---------------------------------------------------
    // One bit of the address picks between them. This is the memory map
    // growing a branch, and it is six characters of Verilog.
    wire sel_timer = sel_io &&  dmem_addr[6];
    wire sel_mmio  = sel_io && !dmem_addr[6];

    wire [31:0] mmio_rdata, timer_rdata;

    mmio #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_io (
        .clk(clk), .rst(rst),
        .addr(dmem_addr[7:0]), .we(dmem_we && sel_mmio), .wdata(dmem_wdata),
        .rdata(mmio_rdata),
        .gpo(gpo), .gpi(gpi),
        .uart_tx_pin(uart_tx_pin), .uart_rx_pin(uart_rx_pin),
        .halt(halt_out), .halt_code(halt_code));

    timer u_timer (
        .clk(clk), .rst(rst),
        .addr(dmem_addr[7:0]), .we(dmem_we && sel_timer), .wdata(dmem_wdata),
        .rdata(timer_rdata), .mtip(mtip));

    // ---- the read mux, one cycle late (lesson 16's reasoning) -------------
    wire [31:0] io_rdata = dmem_addr[6] ? timer_rdata : mmio_rdata;

    reg [31:0] io_rdata_q = 0;
    reg        io_sel_q   = 0;

    always @(posedge clk) begin
        io_rdata_q <= io_rdata;
        io_sel_q   <= dmem_re && sel_io;
    end

    assign dmem_rdata = io_sel_q ? io_rdata_q : mem_rdata;

    // ---- the fault latch ---------------------------------------------------
    reg fault_seen = 0;
    always @(posedge clk)
        if (rst)        fault_seen <= 0;
        else if (fault) fault_seen <= 1;

    assign fault_out = fault_seen;

    wire _unused = &{imem_addr[31:AW+2], imem_addr[1:0], dmem_addr[1:0], 1'b0};
endmodule
