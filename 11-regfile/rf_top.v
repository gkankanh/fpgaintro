`timescale 1ns/1ps
// Lesson 11 — board demo: write and read registers by hand.
//
//   sw[3:0]   register number's low 4 bits (so x0..x15 are reachable)
//   btn[1]    write: stores a value derived from the register number
//   btn[2]    read:  shows the low byte of that register on the LEDs
//
// Set the switches to 0 and press read: the LEDs stay dark, because x0 reads
// as zero however many times you write to it. Set them to anything else,
// press write, then read: the value appears. That is the whole of x0's
// behaviour, visible on eight LEDs.
module rf_top (
    input  wire       clk_25mhz,
    input  wire [3:0] sw,
    input  wire [2:1] btn,
    output wire [7:0] led
);
    wire [4:0] addr = {1'b0, sw};

    // A value that depends on the register number, so reading the wrong one
    // is visible rather than plausible.
    wire [31:0] wdata = {24'hA5A500, 3'b0, addr};

    wire [31:0] rd1, rd2;

    regfile #(.W(32), .N(32)) u_rf (
        .clk(clk_25mhz),
        .rs1(addr), .rs2(5'd0), .rd1(rd1), .rd2(rd2),
        .we(btn[1]), .rd(addr), .wdata(wdata));

    reg [7:0] shown = 0;
    always @(posedge clk_25mhz)
        if (btn[2]) shown <= rd1[7:0];

    assign led = shown;

    wire _unused = &{rd1[31:8], rd2, 1'b0};
endmodule
