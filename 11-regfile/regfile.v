`timescale 1ns/1ps
// Lesson 11 — RV32I's register file.
//
// Thirty-two registers of 32 bits, with TWO read ports and ONE write port.
// That shape is not a choice; it is dictated by the instruction set, and the
// instruction set was shaped by it:
//
//     add rd, rs1, rs2
//
// One instruction, two source operands read in the same cycle, one result
// written. So: two read ports, one write port. If the register file had three
// read ports, instructions could have three sources; if it had one, R-type
// instructions as we know them could not exist. The ISA and the register file
// are the same design decision seen from two sides.
//
// x0 IS HARDWIRED TO ZERO. Reads of x0 return 0; writes to x0 are discarded.
// Two lines of Verilog, and they simplify the whole instruction set:
//
//     mv rd, rs      ->  addi rd, rs, 0
//     li rd, imm     ->  addi rd, x0, imm
//     nop            ->  addi x0, x0, 0
//     not rd, rs     ->  xori rd, rs, -1
//     neg rd, rs     ->  sub  rd, x0, rs
//     beqz rs, L     ->  beq  rs, x0, L
//     j L            ->  jal  x0, L        (throw the return address away)
//     ret            ->  jalr x0, 0(x1)
//
// None of those are real instructions. They are assembler conveniences that
// exist *because* a register reads as zero and absorbs writes. One register
// sacrificed, eight instruction formats avoided.
//
// READS ARE COMBINATIONAL, and that is deliberate. Lesson 08 established that
// a combinational read cannot become a block RAM -- and that at a few tens of
// entries that is the RIGHT answer, because the ECP5 builds small arrays from
// LUTs as distributed RAM, cheaply, with no read latency. 32 entries is firmly
// in that range. See regfile_bram.v for the alternative and what it costs.
module regfile #(
    parameter W = 32,          // register width
    parameter N = 32           // number of registers
)(
    input  wire                   clk,

    // two read ports, combinational: addresses in, data out, same cycle
    input  wire [$clog2(N)-1:0]   rs1,
    input  wire [$clog2(N)-1:0]   rs2,
    output wire [W-1:0]           rd1,
    output wire [W-1:0]           rd2,

    // one write port, synchronous
    input  wire                   we,
    input  wire [$clog2(N)-1:0]   rd,
    input  wire [W-1:0]           wdata
);
    reg [W-1:0] regs [0:N-1];

    // x0 absorbs writes. `rd != 0` is the entire mechanism -- and note it
    // costs one comparator, not a special case in the read path.
    always @(posedge clk)
        if (we && rd != {$clog2(N){1'b0}})
            regs[rd] <= wdata;

    // x0 reads as zero. Note this is a MUX on the output, not a value stored
    // in regs[0]: storing zero there would work until something wrote to it.
    assign rd1 = (rs1 == {$clog2(N){1'b0}}) ? {W{1'b0}} : regs[rs1];
    assign rd2 = (rs2 == {$clog2(N){1'b0}}) ? {W{1'b0}} : regs[rs2];

    // In a SINGLE-CYCLE CPU this needs no write-to-read bypass, and it is
    // worth being clear why, because it is a common source of confusion.
    //
    // During cycle N an instruction reads rs1 and rs2, computes, and its
    // result is written at the END of cycle N by the clock edge. So a read of
    // the register being written returns the OLD value -- which is correct:
    // the instruction must see its operands as they were before it ran.
    //
    // Bypass becomes necessary when a read and a write belong to DIFFERENT
    // instructions in flight at once. That is lesson 16's pipeline, and
    // regfile_bram.v below shows the shape of the fix.
endmodule


// ---------------------------------------------------------------------------
//  The alternative: block RAM, with everything that follows from it.
//
//  Two read ports means two memories, because a DP16KD gives you two ports and
//  one of them is needed for writing. So the array is DUPLICATED -- both
//  copies written identically, each serving one read port. That is the
//  standard trick, and it is why a 2-read-1-write register file costs two
//  block RAMs rather than one.
//
//  And the read is now REGISTERED, one cycle late, which changes the CPU
//  around it: the datapath needs an extra stage, or the clock halves. It also
//  introduces the read-during-write hazard for real, so the bypass below is
//  not optional.
//
//  Measured against regfile in the README. For 32 entries this loses; the
//  point is to see where the line is, because a 1024-entry register file --
//  a vector machine's, say -- would flip it.
// ---------------------------------------------------------------------------
module regfile_bram #(
    parameter W = 32,
    parameter N = 32
)(
    input  wire                 clk,
    input  wire [$clog2(N)-1:0] rs1,
    input  wire [$clog2(N)-1:0] rs2,
    output wire [W-1:0]         rd1,
    output wire [W-1:0]         rd2,
    input  wire                 we,
    input  wire [$clog2(N)-1:0] rd,
    input  wire [W-1:0]         wdata
);
    localparam AW = $clog2(N);

    reg [W-1:0] bank1 [0:N-1];
    reg [W-1:0] bank2 [0:N-1];

    reg [W-1:0] q1 = 0, q2 = 0;

    wire write = we && (rd != {AW{1'b0}});

    always @(posedge clk) begin
        if (write) begin
            bank1[rd] <= wdata;
            bank2[rd] <= wdata;        // both banks, identically
        end
        q1 <= bank1[rs1];
        q2 <= bank2[rs2];
    end

    // The read-during-write hazard, now real. If the address being read this
    // cycle is the one being written, the registered output would present
    // stale data. So remember that it happened and substitute the written
    // value on the way out -- "write-first" behaviour, built explicitly
    // because the block RAM does not promise it.
    reg            hit1 = 0, hit2 = 0;
    reg [W-1:0]    wr_hold = 0;

    always @(posedge clk) begin
        hit1    <= write && (rs1 == rd);
        hit2    <= write && (rs2 == rd);
        wr_hold <= wdata;
    end

    // x0 still reads as zero, and the check must happen on the REGISTERED
    // address... which is why the address is remembered too. Latency makes
    // everything one step more awkward, which is the lesson.
    reg [AW-1:0] rs1_q = 0, rs2_q = 0;
    always @(posedge clk) begin
        rs1_q <= rs1;
        rs2_q <= rs2;
    end

    assign rd1 = (rs1_q == {AW{1'b0}}) ? {W{1'b0}} : (hit1 ? wr_hold : q1);
    assign rd2 = (rs2_q == {AW{1'b0}}) ? {W{1'b0}} : (hit2 ? wr_hold : q2);
endmodule
