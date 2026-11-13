`timescale 1ns/1ps
// ===========================================================================
//  Lesson 17 — board demo: a computer that handles its own interrupts.
//
//      btn[1]    reset
//      sw[3]     down: the LEDs are what the PROGRAM wrote
//                up:   the machine's state (see below)
//      the USB serial port at 115200 baud is the console
//
//  With sw[3] up:
//
//      led[7]  halted      the program finished
//      led[6]  fault       an access to an address that is mapped to nothing
//      led[5]  trapped     at least one trap has been taken
//      led[4:0] pc[6:2]
//
//  Running at 35.7 MHz, from this lesson's own PLL. Lesson 16's machine runs
//  at 40; this one cannot, because the privileged architecture, the timer and
//  the M extension cost about six megahertz of critical path. pll36.v has the
//  measurements and the reasoning.
//
//  The timer counts CYCLES, so the firmware's idea of half a millisecond is
//  derived from the clock -- change the PLL and the tick rate changes with
//  it, which is the point of the comment in timer.v.
// ===========================================================================
module soc17_top #(
    parameter MEM_WORDS = 4096
)(
    input  wire       clk_25mhz,
    input  wire [3:0] sw,
    input  wire [6:1] btn,
    output wire       ftdi_rxd,
    input  wire       ftdi_txd,
    output wire       ftdi_txden,
    output wire [7:0] led
);
    assign ftdi_txden = 1'b1;

    wire clk, locked;
    pll36 u_pll (.clkin(clk_25mhz), .clkout0(clk), .locked(locked));

    wire rst = btn[1] || !locked;

    wire [7:0]  gpo;
    wire [31:0] pc, mcause;
    wire        fault, halted, retire, trap;
    wire [7:0]  halt_code;

    soc17 #(.MEM_WORDS(MEM_WORDS), .FIRMWARE("firmware.hex"),
            .CLK_HZ(35_714_286), .BAUD(115_200)) u_soc (
        .clk(clk), .rst(rst),
        .gpo(gpo),
        .gpi({10'd0, sw[2:0], btn[5:3]}),
        .uart_tx_pin(ftdi_rxd), .uart_rx_pin(ftdi_txd),
        .pc_out(pc), .fault_out(fault),
        .halt_out(halted), .halt_code(halt_code), .retire_out(retire),
        .trap_out(trap), .mcause_out(mcause));

    // A trap is a one-cycle event and a human needs it to stay put.
    reg trapped = 0;
    always @(posedge clk)
        if (rst)       trapped <= 0;
        else if (trap) trapped <= 1;

    reg [7:0] shown = 0;
    always @(posedge clk)
        shown <= sw[3] ? {halted, fault, trapped, pc[6:2]} : gpo;

    assign led = shown;

    wire _unused = &{pc[31:7], pc[1:0], halt_code, retire, mcause,
                     btn[6], btn[2], 1'b0};
endmodule
