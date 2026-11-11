`timescale 1ns/1ps
// Lesson 08 — initialised memory, and the answer to lesson 07's puzzle.
//
// Lesson 07 built a 32-byte font ROM and `make synth` reported 185 LUT4s and
// not a single block RAM. This file is where that gets resolved: a ROM is a
// memory like any other, and whether it lands in LUTs or in a DP16KD is a
// decision the synthesiser makes on SIZE.
//
// Two ROMs here, identical in every way except how many entries they have.

// ---------------------------------------------------------------------------
//  A ROM initialised from a hex file.
//
//  `$readmemh` runs at elaboration time, not at runtime — yosys reads the file
//  during synthesis and bakes the contents into the bitstream, exactly as it
//  does for an `initial` block of literals. The file is therefore a SOURCE
//  file: change it and you must resynthesise.
//
//  This is how lesson 13 loads a program into its instruction memory, and how
//  lesson 15 loads one compiled by riscv-gcc. The toolchain path is
//  riscv-gcc -> objcopy -> a .hex file -> $readmemh -> a block RAM.
// ---------------------------------------------------------------------------
module rom #(
    parameter W     = 8,
    parameter DEPTH = 256,
    parameter FILE  = "font.hex"
)(
    input  wire                     clk,
    input  wire [$clog2(DEPTH)-1:0] addr,
    output reg  [W-1:0]             dout
);
    reg [W-1:0] mem [0:DEPTH-1];

    initial $readmemh(FILE, mem);

    // A CURIOSITY WORTH KNOWING. font.hex starts with ASCII 0-31, which have
    // no glyphs, so its first 256 bytes are all zero. Synthesise this module
    // at DEPTH=256 and yosys emits NO memory at all — it folds the whole
    // thing to a constant zero, correctly, because that is what it is.
    // DEPTH=512 reaches real data and produces 1 DP16KD.
    //
    // So "my ROM disappeared" is usually not a tool bug. It means the
    // contents were constant, which means the file was not read, was empty,
    // or -- as here -- was genuinely all one value in the range used.

    // Synchronous read, for the same reason as ram_sp: a block RAM's output
    // is registered, so asking for a combinational read rules out BRAM.
    always @(posedge clk)
        dout <= mem[addr];
endmodule


// ---------------------------------------------------------------------------
//  Lesson 07's font, as it was: 4 glyphs x 8 rows = 32 bytes, inline literals.
//
//  Too small for a block RAM to be worth it, so it becomes logic — which is
//  the right call. One DP16KD holds 18,432 bits; spending a whole one on 256
//  bits would waste 98.6% of it, and the 85F only has 208.
// ---------------------------------------------------------------------------
module font_small (
    input  wire       clk,
    input  wire [4:0] addr,         // 32 entries
    output reg  [7:0] dout
);
    reg [7:0] mem [0:31];
    initial begin                   // glyph 0: H
        mem[ 0]=8'h66; mem[ 1]=8'h66; mem[ 2]=8'h66; mem[ 3]=8'h7E;
        mem[ 4]=8'h66; mem[ 5]=8'h66; mem[ 6]=8'h66; mem[ 7]=8'h00;
        mem[ 8]=8'h7E; mem[ 9]=8'h60; mem[10]=8'h60; mem[11]=8'h7C; // E
        mem[12]=8'h60; mem[13]=8'h60; mem[14]=8'h7E; mem[15]=8'h00;
        mem[16]=8'h60; mem[17]=8'h60; mem[18]=8'h60; mem[19]=8'h60; // L
        mem[20]=8'h60; mem[21]=8'h60; mem[22]=8'h7E; mem[23]=8'h00;
        mem[24]=8'h3C; mem[25]=8'h66; mem[26]=8'h66; mem[27]=8'h66; // O
        mem[28]=8'h66; mem[29]=8'h66; mem[30]=8'h3C; mem[31]=8'h00;
    end
    always @(posedge clk)
        dout <= mem[addr];
endmodule


// ---------------------------------------------------------------------------
//  The same idea at a useful size: a full 128-character font, 8 rows each.
//  1,024 bytes = 8,192 bits, which fits in one DP16KD with room to spare.
//
//  Identical code shape to font_small. Only DEPTH changed. The synthesiser
//  reaches a different conclusion, and that is the whole lesson:
//
//      font_small (32 bytes)    -> logic
//      font_full  (1024 bytes)  -> 1 DP16KD
//
//  So the question "should this be a ROM or logic?" is not one you answer.
//  You write the memory in the shape that CAN become a BRAM, and let the
//  synthesiser decide on size. Writing it in a shape that cannot — an
//  asynchronous read — takes the choice away permanently.
// ---------------------------------------------------------------------------
module font_full (
    input  wire       clk,
    input  wire [9:0] addr,         // 1024 entries: 128 chars x 8 rows
    output reg  [7:0] dout
);
    reg [7:0] mem [0:1023];
    initial $readmemh("font.hex", mem);
    always @(posedge clk)
        dout <= mem[addr];
endmodule
