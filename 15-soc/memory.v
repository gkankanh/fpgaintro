`timescale 1ns/1ps
// ===========================================================================
//  Lesson 15 — the memory, and the end of the Harvard split.
//
//  Lesson 13 had TWO memories: an instruction memory and a data memory, with
//  separate address spaces that overlapped at every address. That is a
//  Harvard architecture, and lesson 13 was honest about why it was there --
//  a single-cycle CPU fetches an instruction and accesses data in the same
//  cycle, so one memory with one port cannot serve both.
//
//  The fix is not a second memory. It is a second PORT.
//
//  One array, one address space, two read ports: the fetch port (read-only)
//  and the data port (read and write). Software now sees one flat memory in
//  which a string constant can be read by the program that is executing a few
//  words away from it -- which is what C expects, and what makes `.rodata`
//  work at all.
//
//  TWO THINGS THIS SHAPE COSTS, both deliberate and both measured in the
//  README:
//
//    * Both reads are ASYNCHRONOUS, because the single-cycle core needs the
//      instruction and the loaded word inside the cycle that asked for them.
//      Lesson 08 proved that an asynchronous read can never be a block RAM.
//      So this array becomes distributed RAM and multiplexers -- hundreds of
//      LUT4 where one DP16KD would have done -- and the 85F's 208 block RAMs
//      sit idle. Lesson 16's pipeline is what earns them back.
//
//    * A second read port means a second copy of the storage, since a
//      distributed RAM cell has one read address. The write goes to both
//      copies, so they stay identical. That is not a trick: it is what the
//      synthesiser does for you when you write two reads of one array, and
//      writing it explicitly is the only way to see the price.
//
//  SELF-MODIFYING CODE IS NOW POSSIBLE, and that is not a feature anyone
//  wanted -- it is the consequence of one address space. A store to an
//  address the PC later reaches changes the program. On this machine it even
//  works, because the fetch is asynchronous and there is no cache and no
//  pipeline to hold a stale copy. On any real machine it does not, and the
//  instruction-cache flush that makes it work is one of the reasons a
//  JIT compiler is harder than it looks.
// ===========================================================================
module memory #(
    parameter WORDS = 512,                   // 32-bit words; 512 = 2 KB
    // The default must name a file that EXISTS: yosys elaborates this module
    // with its defaults before the parent overrides them, and $readmemh on a
    // missing file is a hard error at that point (lesson 13 learned this).
    parameter FILE  = "firmware.hex"
)(
    input  wire                     clk,

    // port A — instruction fetch: asynchronous read, never written
    input  wire [$clog2(WORDS)-1:0] a_addr,
    output wire [31:0]              a_data,

    // port B — data: asynchronous read, byte-enabled synchronous write
    input  wire [$clog2(WORDS)-1:0] b_addr,
    output wire [31:0]              b_data,
    input  wire                     b_we,
    input  wire [3:0]               b_be,
    input  wire [31:0]              b_wdata
);
    // One array. $readmemh runs at ELABORATION time (lesson 08), so the
    // compiled program is baked into the bitstream: changing the C means
    // recompiling AND resynthesising. The file is a source file.
    reg [31:0] mem [0:WORDS-1];
    initial $readmemh(FILE, mem);

    assign a_data = mem[a_addr];
    assign b_data = mem[b_addr];

    // Byte lanes, exactly as lesson 13 wrote them: each enabled lane is
    // replaced and the others keep their value, which is what makes SB and SH
    // possible in a memory that is physically 32 bits wide.
    //
    // A READ AND A WRITE OF THE SAME ADDRESS IN THE SAME CYCLE returns the OLD
    // value here, because the read is combinational on the array's current
    // contents and the write lands at the edge. For this CPU that is never
    // observable -- a store and the load that reads it back are different
    // instructions in different cycles -- but it is the sort of question a
    // memory's documentation must answer, and most of them do not.
    always @(posedge clk)
        if (b_we) begin
            if (b_be[0]) mem[b_addr][ 7: 0] <= b_wdata[ 7: 0];
            if (b_be[1]) mem[b_addr][15: 8] <= b_wdata[15: 8];
            if (b_be[2]) mem[b_addr][23:16] <= b_wdata[23:16];
            if (b_be[3]) mem[b_addr][31:24] <= b_wdata[31:24];
        end
endmodule
