`timescale 1ns/1ps
// Lesson 09 — board demo: an echo server.
//
// Type in a terminal, the character comes back, and the LEDs show its byte.
// That proves the whole path: your computer's UART -> FTDI -> FPGA pin ->
// synchroniser -> receiver -> transmitter -> FTDI -> your terminal.
//
//     screen /dev/tty.usbserial-*  115200          (macOS; ctrl-a k to quit)
//     picocom -b 115200 /dev/ttyUSB0               (Linux)
//
// PIN NAMES ARE FROM THE FTDI'S POINT OF VIEW, and this is the classic place
// to lose an afternoon:
//
//     ftdi_rxd   the FTDI RECEIVES here, so the FPGA DRIVES it   -> our tx
//     ftdi_txd   the FTDI TRANSMITS here, so the FPGA READS it   -> our rx
//
// So `output ftdi_rxd` and `input ftdi_txd` are correct and look backwards.
// ftdi_txden must be driven high to enable the FPGA's side of the link.
module uart_top (
    input  wire       clk_25mhz,
    input  wire [2:1] btn,
    output wire       ftdi_rxd,     // FPGA -> host
    input  wire       ftdi_txd,     // host -> FPGA
    output wire       ftdi_txden,
    output wire [7:0] led
);
    assign ftdi_txden = 1'b1;       // enable our transmitter

    // --- receive ----------------------------------------------------------
    wire [7:0] rx_data;
    wire       rx_valid, rx_frame_error;

    uart_rx #(.CLK_HZ(25_000_000), .BAUD(115200)) u_rx (
        .clk(clk_25mhz), .rx(ftdi_txd),
        .data(rx_data), .valid(rx_valid), .frame_error(rx_frame_error));

    // --- transmit ---------------------------------------------------------
    // Echo straight back. `rx_valid` is a one-clock pulse and `start` wants
    // exactly that, so they connect directly -- as long as the transmitter is
    // not already busy. At 115200 baud a byte takes 87 microseconds to send,
    // and the host cannot deliver two inside that, so this is safe here.
    //
    // It would NOT be safe in general: a faster link, or a host sending a
    // paste of several kilobytes, would overrun it. The fix is a FIFO, which
    // lesson 15 needs anyway.
    wire tx_busy;

    uart_tx #(.CLK_HZ(25_000_000), .BAUD(115200)) u_tx (
        .clk(clk_25mhz), .data(rx_data), .start(rx_valid && !tx_busy),
        .tx(ftdi_rxd), .busy(tx_busy));

    // --- what the LEDs show -----------------------------------------------
    // Latch the last byte received, so you can read the ASCII code of
    // whatever you typed. btn[1] shows a dropped-byte / framing-error count
    // instead, which is how you tell a baud mismatch from a wiring mistake.
    reg [7:0] last    = 0;
    reg [3:0] errs    = 0;
    reg [3:0] dropped = 0;

    always @(posedge clk_25mhz) begin
        if (rx_valid)                    last    <= rx_data;
        if (rx_frame_error)              errs    <= errs + 1'b1;
        if (rx_valid && tx_busy)         dropped <= dropped + 1'b1;
    end

    assign led = btn[1] ? {errs, dropped} : last;

    wire _unused = &{btn[2], 1'b0};
endmodule
