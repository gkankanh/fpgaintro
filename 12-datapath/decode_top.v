`timescale 1ns/1ps
// Lesson 12 — board demo: decode an instruction and show what it wants.
//
//   sw[3:0]   selects one of 16 instructions from a small ROM
//   led[7]    illegal
//   led[6]    reg_we      (does it write a register?)
//   led[5]    mem_read    (is it a load?)
//   led[4]    mem_write   (is it a store?)
//   led[3]    branch
//   led[2]    jump
//   led[1:0]  wb_src      (0 = ALU, 1 = memory, 2 = pc+4)
//
// Step through the switches and watch the control signals change. Position 15
// is a deliberately malformed instruction, so led[7] lights.
module decode_top (
    input  wire       clk_25mhz,
    input  wire [3:0] sw,
    output wire [7:0] led
);
    reg [31:0] rom [0:15];
    initial begin
        rom[ 0] = 32'h003100B3;   // add  x1,x2,x3
        rom[ 1] = 32'h403100B3;   // sub  x1,x2,x3
        rom[ 2] = 32'h00510093;   // addi x1,x2,5
        rom[ 3] = 32'hFFF10093;   // addi x1,x2,-1
        rom[ 4] = 32'h0081A083;   // lw   x1,8(x3)
        rom[ 5] = 32'h00312623;   // sw   x3,12(x2)
        rom[ 6] = 32'h00208863;   // beq  x1,x2,+16
        rom[ 7] = 32'h00209863;   // bne  x1,x2,+16
        rom[ 8] = 32'h020000EF;   // jal  x1,+32
        rom[ 9] = 32'h010100E7;   // jalr x1,16(x2)
        rom[10] = 32'h123450B7;   // lui  x1,0x12345
        rom[11] = 32'h01000097;   // auipc x1,0x1000
        rom[12] = 32'h40715093;   // srai x1,x2,7
        rom[13] = 32'h00715093;   // srli x1,x2,7
        rom[14] = 32'h0020F0B3;   // and  x1,x1,x2
        rom[15] = 32'h203100B3;   // ILLEGAL: R-type, funct7 = 0010000
    end

    reg [31:0] inst = 0;
    always @(posedge clk_25mhz)
        inst <= rom[sw];

    wire [4:0] rs1, rs2, rd;
    wire       reg_we, alu_a_pc, alu_b_imm, mem_read, mem_write;
    wire [3:0] alu_op;
    wire [2:0] mem_op;
    wire       branch, jump, jalr, illegal;
    wire [1:0] wb_src;
    wire [31:0] imm;

    immgen u_imm (.inst(inst), .imm(imm));
    decode u_dec (
        .inst(inst), .rs1(rs1), .rs2(rs2), .rd(rd), .reg_we(reg_we),
        .alu_op(alu_op), .alu_a_pc(alu_a_pc), .alu_b_imm(alu_b_imm),
        .mem_read(mem_read), .mem_write(mem_write), .mem_op(mem_op),
        .branch(branch), .jump(jump), .jalr(jalr),
        .wb_src(wb_src), .illegal(illegal));

    assign led = {illegal, reg_we, mem_read, mem_write, branch, jump, wb_src};

    wire _unused = &{rs1, rs2, rd, alu_op, alu_a_pc, alu_b_imm,
                     mem_op, jalr, imm, 1'b0};
endmodule
