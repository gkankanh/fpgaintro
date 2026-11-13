`timescale 1ns/1ps
// ===========================================================================
//  Lesson 15 — board demo: a computer on the ULX3S.
//
//      btn[1]    reset, and restart the program from its first instruction
//      sw[3]     down: the LEDs are whatever the PROGRAM last wrote
//                up:   the LEDs are the MACHINE's own state (see below)
//      sw[2:0]   readable by the program at BUTTONS
//      the USB serial port, at 115200 baud, is the program's console:
//
//          screen /dev/tty.usbserial-*  115200      (macOS; ctrl-a k to quit)
//          picocom -b 115200 /dev/ttyUSB0           (Linux)
//
//  Press reset and the program greets you, prints its own cycle count, waits
//  for one keystroke and echoes it. Everything after the greeting is C.
//
//  WITH sw[3] UP THE LEDS SHOW THE MACHINE, NOT THE PROGRAM:
//
//      led[7]   halted     main() returned and crt0 wrote HALT
//      led[6]   fault      a store went to an address mapped to nothing --
//                          this program does that once, on purpose
//      led[5]   illegal    an undefined instruction was fetched
//      led[4:0] pc[6:2]    the program counter, in instructions
//
//  Those are the machine's health, and they are behind a switch rather than
//  on their own pins because eight LEDs is all there is. That is a real
//  constraint and also the beginning of a real idea: a debug interface is
//  just more memory-mapped registers, and once there is a serial port you can
//  print them instead of wiring them to anything.
// ===========================================================================
module soc_top #(
    // Parameterised so the memory can be resized from the command line, which
    // is how the size/speed table in the README was measured:
    //     make synth M=soc_top P="MEM_WORDS 512"
    parameter MEM_WORDS = 512
)(
    input  wire       clk_25mhz,
    input  wire [3:0] sw,
    input  wire [6:1] btn,
    output wire       ftdi_rxd,        // FPGA -> host   (see lesson 09)
    input  wire       ftdi_txd,        // host -> FPGA
    output wire       ftdi_txden,
    output wire [7:0] led
);
    assign ftdi_txden = 1'b1;          // enable the FPGA's side of the link

    wire [7:0]  gpo;
    wire [31:0] pc;
    wire        illegal, fault, halted;
    wire [7:0]  halt_code;

    // 115,200 baud here, against the 2.5 Mbaud the testbench uses. The same
    // hardware, one parameter, and the only reason for the difference is that
    // a simulation has no patience and a terminal program has no choice.
    soc #(.MEM_WORDS(MEM_WORDS), .FIRMWARE("firmware.hex"),
          .CLK_HZ(25_000_000), .BAUD(115_200)) u_soc (
        .clk(clk_25mhz),
        .rst(btn[1]),
        .gpo(gpo),
        .gpi({10'd0, sw[2:0], btn[5:3]}),
        .uart_tx_pin(ftdi_rxd),
        .uart_rx_pin(ftdi_txd),
        .pc_out(pc), .illegal_out(illegal), .fault_out(fault),
        .halt_out(halted), .halt_code(halt_code));

    // Registered, because driving a pin from a deep combinational cone is how
    // you get a design that meets timing everywhere except at its edges.
    reg [7:0] shown = 0;
    always @(posedge clk_25mhz)
        shown <= sw[3] ? {halted, fault, illegal, pc[6:2]} : gpo;

    assign led = shown;

    wire _unused = &{pc[31:7], pc[1:0], halt_code, btn[6], btn[2], 1'b0};
endmodule
