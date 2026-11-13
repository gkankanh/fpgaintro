`timescale 1ns/1ps
// ===========================================================================
//  Lesson 16 — board demo: the same computer, pipelined.
//
//  AND IT RUNS AT 40 MHz, which is the entire point.
//
//  Lesson 15's machine runs at the ULX3S's 25 MHz oscillator because it
//  cannot go faster: nextpnr closes it at about 28 MHz. This one closes at
//  about 46, so the clock is worth spending -- and spending it means a PLL,
//  which is lesson 04, instantiated here unchanged.
//
//  A PIPELINE THAT RUNS AT THE SAME CLOCK IS A SLOWER MACHINE. It executes
//  the same instructions in more cycles (bubbles) and each cycle is the same
//  length, so it finishes later. Everything pipelining gives you arrives as
//  permission to raise the clock, and if you do not raise it, you have paid
//  for the hazard logic and bought nothing. That is why this file has a PLL
//  in it and why the README's comparison is in microseconds, not cycles.
//
//  The controls are lesson 15's, deliberately, so that the two bitstreams can
//  be loaded one after the other and compared by a human:
//
//      btn[1]    reset
//      sw[3]     down: the LEDs are what the PROGRAM wrote
//                up:   the machine's state (halted, fault, illegal, pc)
//      the USB serial port at 115200 baud is the console
//
//  Load lesson 15's bitstream, press reset, read the cycle count it prints.
//  Load this one, press reset, read the cycle count again. Same program, same
//  C, same UART -- and the number is different, which is the entire subject
//  of this lesson.
// ===========================================================================
module soc5_top #(
    parameter MEM_WORDS = 512
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

    // ---- the clock ---------------------------------------------------------
    // Lesson 04's PLL, not one line changed. It offers 100 MHz and 40 MHz;
    // 40 is the one this design can keep, with the slowest of three placer
    // seeds measuring 45.74 MHz. Taking 46 because one run said 46 is how you
    // ship a machine that works on the bench and fails in July.
    wire clk, locked;

    pll u_pll (.clk_25mhz(clk_25mhz), .clk_100mhz(), .clk_40mhz(clk), .locked(locked));

    // A PLL takes tens of microseconds to lock, and its output is not a clock
    // until it does. Holding reset until `locked` is lesson 04's rule, and it
    // is the difference between a machine that starts and one that starts
    // most of the time.
    wire rst = btn[1] || !locked;

    wire [7:0]  gpo;
    wire [31:0] pc;
    wire        illegal, fault, halted, retire;
    wire [7:0]  halt_code;

    soc5 #(.MEM_WORDS(MEM_WORDS), .FIRMWARE("../15-soc/firmware.hex"),
           .CLK_HZ(40_000_000), .BAUD(115_200)) u_soc (
        .clk(clk),
        .rst(rst),
        .gpo(gpo),
        .gpi({10'd0, sw[2:0], btn[5:3]}),
        .uart_tx_pin(ftdi_rxd),
        .uart_rx_pin(ftdi_txd),
        .pc_out(pc), .illegal_out(illegal), .fault_out(fault),
        .halt_out(halted), .halt_code(halt_code), .retire_out(retire));

    reg [7:0] shown = 0;
    always @(posedge clk)
        shown <= sw[3] ? {halted, fault, illegal, pc[6:2]} : gpo;

    assign led = shown;

    wire _unused = &{pc[31:7], pc[1:0], halt_code, retire, btn[6], btn[2], 1'b0};
endmodule
