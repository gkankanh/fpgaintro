`timescale 1ns/1ps
// ===========================================================================
//  Lesson 14 — proving the register file.
//
//  The ALU was combinational, so a single step covered everything. A register
//  file has STATE, so the proof is genuinely bounded: checking to depth k
//  proves the properties hold for every sequence of k operations, and says
//  nothing about step k+1.
//
//  That sounds like a weakness and mostly is not. Bugs that need a specific
//  twenty-step sequence exist, but bugs that need *any* sequence at all are
//  usually reachable in a handful of steps -- and a solver searching every
//  12-step sequence over every address and every data value is doing
//  something no testbench can approach.
//
//  THE TECHNIQUE WORTH LEARNING is the shadow register. Rather than
//  reimplementing the register file to compare against -- which would only
//  prove that two copies of the same mistake agree -- we pick ONE arbitrary
//  address, remember what was last written to it, and assert the file agrees.
//
//  `anyconst` is what makes that a proof rather than a spot check: the solver
//  chooses the address, and must make the property hold for EVERY choice. One
//  shadow register proves a property about all thirty-two.
// ===========================================================================
module regfile_props (
    input  wire        clk,
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    input  wire [4:0]  rd,
    input  wire        we,
    input  wire [31:0] wdata
);
    wire [31:0] rd1, rd2;

    regfile #(.W(32), .N(32)) dut (
        .clk(clk), .rs1(rs1), .rs2(rs2), .rd1(rd1), .rd2(rd2),
        .we(we), .rd(rd), .wdata(wdata));

    // The address the solver gets to choose. It is constant over the whole
    // trace, but the proof must hold whichever constant it picks -- so this
    // is a statement about all 32 registers at once.
    (* anyconst *) reg [4:0] watched;

    reg [31:0] shadow       = 32'd0;
    reg        shadow_valid = 1'b0;

    always @(posedge clk)
        if (we && rd == watched && watched != 5'd0) begin
            shadow       <= wdata;
            shadow_valid <= 1'b1;
        end

    always @(*) begin
        // ---- x0 is zero, always, under every possible write sequence -----
        //
        // A test can write to x0 a few times and check. This proves it for
        // every sequence of writes of every value, which is the difference
        // between evidence and a guarantee.
        if (rs1 == 5'd0) assert (rd1 == 32'd0);
        if (rs2 == 5'd0) assert (rd2 == 32'd0);

        // ---- the file remembers what was written -------------------------
        //
        // Once something has been written to the watched register, reading it
        // must return exactly that -- from EITHER port, and regardless of
        // what has happened to any other register in between.
        if (shadow_valid && watched != 5'd0) begin
            if (rs1 == watched) assert (rd1 == shadow);
            if (rs2 == watched) assert (rd2 == shadow);
        end

        // ---- the two ports never disagree --------------------------------
        // Reading the same address through both ports must give one answer.
        if (rs1 == rs2) assert (rd1 == rd2);
    end

    // ---- covers, so the proof is known not to be vacuous ----------------
    always @(*) begin
        cover (shadow_valid && rs1 == watched && rd1 != 32'd0);
        cover (shadow_valid && watched == 5'd31);
        cover (rs1 == 5'd0 && we && rd == 5'd0);   // a write to x0 happens
        cover (rs1 != rs2 && rd1 != rd2);          // the ports really differ
    end
endmodule
