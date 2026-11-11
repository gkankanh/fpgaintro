`timescale 1ns/1ps
// Lesson 13 — board demo: a RISC-V CPU running on the ULX3S.
//
//   btn[1]   reset and restart the program
//   sw[3:0]  which result word to display (0x100 + 4*sw)
//   led[7:0] the low byte of that word
//
// Set the switches to 2 and you are looking at address 0x108 -- the result of
// `addi t2, t0, -1`, which should read 9. Set them to 0x12 (not reachable with
// four switches; see the exercises) for the loop sum.
//
// The program runs in a few hundred cycles, so it has finished before you can
// release the button.
module cpu_top (
    input  wire       clk_25mhz,
    input  wire [3:0] sw,
    input  wire [2:1] btn,
    output wire [7:0] led
);
    wire [31:0] pc, peek;
    wire        illegal;

    // 0x100, 0x104, 0x108 ... one word per switch position.
    wire [31:0] peek_addr = 32'h100 + {26'd0, sw, 2'b00};

    cpu_sys #(.IMEM_WORDS(256), .DMEM_WORDS(256), .PROGRAM("test.hex")) u_sys (
        .clk(clk_25mhz), .rst(btn[1]),
        .pc_out(pc), .illegal_out(illegal),
        .peek_addr(peek_addr), .peek_data(peek));

    reg [7:0] shown = 0;
    always @(posedge clk_25mhz)
        shown <= peek[7:0];

    assign led = shown;

    wire _unused = &{pc, illegal, peek[31:8], btn[2], 1'b0};
endmodule
