`timescale 1ns/1ps
// ===========================================================================
//  Lesson 15 — the peripherals: addresses that DO something.
//
//  This is the whole idea of memory-mapped I/O. There is no I/O instruction in
//  RV32I -- no IN, no OUT. A peripheral is a register that happens to answer
//  at an address, and software reaches it with the same LW and SW it uses for
//  everything else. The UART of lesson 09 becomes two addresses: one you write
//  a byte to, and one you read to find out whether it is ready for the next.
//
//  THE REGISTER MAP (offsets inside the 0x8000_0000 window)
//
//    0x00  UART_TX    W   transmit this byte. Dropped if the line is busy,
//                         so software must check STAT first.
//    0x04  UART_STAT  R   bit 0  tx_busy    transmitter still shifting
//                         bit 1  rx_valid   a received byte is waiting
//                         bit 2  rx_over    a byte arrived while one waited
//    0x08  UART_RX    R   the received byte (reading does NOT consume it)
//    0x0C  UART_ACK   W   any value: consume the byte, clear rx_valid/rx_over
//    0x10  LEDS       RW  the eight LEDs
//    0x14  BUTTONS    R   {sw[3:0], btn[6:1]}
//    0x18  CYCLES     R   clocks since reset: the machine's own stopwatch
//    0x1C  HALT       W   stop. The testbench ends the simulation here, and
//                         lesson 16 uses it to timestamp a benchmark.
//
//  ---------------------------------------------------------------------
//  WHY READING UART_RX DOES NOT CONSUME THE BYTE
//
//  On almost every real UART it does: read the data register and the byte is
//  gone. That design is impossible here, and the reason is worth more than the
//  convenience it costs.
//
//  A register with a side effect on READ needs to know that a read really
//  happened. The lesson 13 core reads its data memory unconditionally -- every
//  instruction puts its ALU result on the address bus whether or not it is a
//  load (see busdec.v). If reading UART_RX consumed the byte, then any
//  instruction whose arithmetic happened to produce 0x8000_0008 would eat a
//  character. That is not a hypothetical: `li t0, -2147483640` is exactly that
//  number.
//
//  So consuming the byte is a WRITE, to UART_ACK. A write is unambiguous,
//  because `we` is only ever asserted by a store. The rule this illustrates is
//  general and worth keeping: a bus whose master cannot say "this is a real
//  read" may not have read side effects anywhere in its address map.
// ===========================================================================
module mmio #(
    parameter CLK_HZ = 25_000_000,
    parameter BAUD   = 115_200
)(
    input  wire        clk,
    input  wire        rst,

    // the bus, already decoded: this is our window
    input  wire [7:0]  addr,          // byte offset within the I/O window
    input  wire        we,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,         // combinational: the core cannot wait

    // the outside world
    output reg  [7:0]  gpo,           // LEDs
    input  wire [15:0] gpi,           // buttons and switches
    output wire        uart_tx_pin,
    input  wire        uart_rx_pin,

    // "the program has finished": for the testbench, and for lesson 16's
    // benchmark harness. On the board it is simply never written.
    output reg         halt,
    output reg  [7:0]  halt_code
);
    localparam [5:0] R_TX   = 6'h0, R_STAT = 6'h1, R_RX  = 6'h2, R_ACK  = 6'h3,
                     R_LEDS = 6'h4, R_BTN  = 6'h5, R_CYC = 6'h6, R_HALT = 6'h7;

    // The register index. addr[1:0] are the byte within the word and are not
    // part of it: these are word registers.
    wire [5:0] reg_i = addr[7:2];
    wire       sel   = we;

    // ---- the transmitter (lesson 09, unchanged) ---------------------------
    // `start` is a one-clock pulse because a store IS one clock. The data is
    // whatever the CPU is driving this cycle, and uart_tx samples it on the
    // same edge -- so the byte never needs a register of its own here.
    wire tx_busy;
    wire tx_start = sel && (reg_i == R_TX) && !tx_busy;

    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_tx (
        .clk(clk), .data(wdata[7:0]), .start(tx_start),
        .tx(uart_tx_pin), .busy(tx_busy));

    // ---- the receiver -----------------------------------------------------
    // uart_rx raises `valid` for ONE clock. Software cannot poll fast enough
    // to catch a one-clock pulse, so the peripheral holds it: that is what
    // makes a status bit a status bit rather than an event.
    wire [7:0] rx_byte;
    wire       rx_strobe, rx_frame_err;

    uart_rx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_rx (
        .clk(clk), .rx(uart_rx_pin), .data(rx_byte),
        .valid(rx_strobe), .frame_error(rx_frame_err));

    reg [7:0] rx_data  = 0;
    reg       rx_valid = 0;
    reg       rx_over  = 0;

    always @(posedge clk)
        if (rst) begin
            rx_data <= 0; rx_valid <= 0; rx_over <= 0;
        end else begin
            // The acknowledge is checked FIRST and the arrival second, so a
            // byte landing in the same cycle as its predecessor's ACK is kept
            // rather than lost. Order matters in a procedural block, and this
            // is the one place in this file where it does.
            if (sel && (reg_i == R_ACK)) begin
                rx_valid <= 0;
                rx_over  <= 0;
            end
            if (rx_strobe) begin
                rx_data  <= rx_byte;
                rx_valid <= 1;
                // It was still holding the last one: software was too slow,
                // and a character has been lost. Say so rather than hide it.
                if (rx_valid) rx_over <= 1;
            end
        end

    // ---- the stopwatch ----------------------------------------------------
    // Free-running from reset. Software reads it twice and subtracts, which is
    // how lesson 16 measures cycles per instruction on the real machine rather
    // than in a simulator.
    reg [31:0] cycles = 0;
    always @(posedge clk)
        if (rst) cycles <= 0;
        else     cycles <= cycles + 32'd1;

    // ---- the output registers --------------------------------------------
    always @(posedge clk)
        if (rst) begin
            gpo <= 8'd0; halt <= 1'b0; halt_code <= 8'd0;
        end else if (sel) begin
            if (reg_i == R_LEDS) gpo <= wdata[7:0];
            if (reg_i == R_HALT) begin
                halt      <= 1'b1;
                halt_code <= wdata[7:0];
            end
        end

    // ---- the read mux -----------------------------------------------------
    // Unmapped registers inside the window read as zero. That is a choice, not
    // a law: some machines fault, and faulting needs lesson 17.
    always @(*)
        case (reg_i)
            R_STAT:  rdata = {29'd0, rx_over, rx_valid, tx_busy};
            R_RX:    rdata = {24'd0, rx_data};
            R_LEDS:  rdata = {24'd0, gpo};
            R_BTN:   rdata = {16'd0, gpi};
            R_CYC:   rdata = cycles;
            default: rdata = 32'd0;
        endcase

    // A framing error is detected and deliberately not reported: there is no
    // bit for it in STAT. Lesson 09 built that output and this peripheral
    // drops it, which is a small dishonesty worth naming -- the exercises make
    // it a status bit, and it costs one flip-flop.
    wire _unused = &{rx_frame_err, wdata[31:8], addr[1:0], 1'b0};
endmodule
