`timescale 1ns/1ps
// ===========================================================================
//  Lesson 17 — the instructions lesson 12 called illegal.
//
//  Lesson 12's decoder recognises the nine base RV32I opcodes and raises
//  `illegal` for everything else. Three groups of instruction that this lesson
//  needs are in that "everything else":
//
//    SYSTEM (opcode 1110011)   CSRRW/S/C and their immediate forms, ECALL,
//                              EBREAK, MRET -- the privileged architecture
//    OP with funct7 = 0000001  MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU
//                              -- the M extension
//
//  This module claims them. The core then computes
//
//      illegal = base_illegal && !ext_legal
//
//  which is the smallest honest change: lesson 12's decoder is a finished,
//  measured artifact and this lesson does not reach into it. A second decoder
//  beside the first is also how real designs grow -- an extension is a
//  decoder, and `misa` is a list of which ones are present.
//
//  WHY THE M EXTENSION HIDES UNDER AN EXISTING OPCODE. MUL is opcode 0110011,
//  the same as ADD, distinguished only by funct7 = 0000001. RISC-V does that
//  deliberately: opcodes are a scarce resource, 32 bits do not go far, and an
//  extension that needed its own opcode would be an extension that could not
//  coexist with another. Lesson 12's `bad_funct7` check is what makes MUL
//  illegal on a core without M -- which is exactly what the specification
//  says should happen, and why the check was worth writing.
// ===========================================================================
module decode_ext (
    input  wire [31:0] inst,

    // ---- SYSTEM ----------------------------------------------------------
    output wire        is_csr,       // a CSR read/modify/write
    output wire [1:0]  csr_op,       // 00 = write, 01 = set, 10 = clear
    output wire        csr_imm,      // the operand is zimm, not rs1
    output wire [11:0] csr_addr,
    output wire [4:0]  csr_zimm,
    output wire        is_ecall,
    output wire        is_ebreak,
    output wire        is_mret,

    // ---- M extension ------------------------------------------------------
    output wire        is_mul,       // MUL MULH MULHSU MULHU
    output wire        is_div,       // DIV DIVU REM REMU
    output wire [2:0]  md_op,        // funct3, which selects among the eight

    // ---- what the core needs to know -------------------------------------
    output wire        ext_legal,    // this IS one of the above
    output wire        ext_reg_we    // ...and it writes rd
);
    wire [6:0] opcode = inst[6:0];
    wire [2:0] funct3 = inst[14:12];
    wire [6:0] funct7 = inst[31:25];
    wire [4:0] rs2_f  = inst[24:20];
    wire [4:0] rs1_f  = inst[19:15];

    localparam [6:0] OP_SYSTEM = 7'b1110011, OP_REG = 7'b0110011;

    // ---- SYSTEM ------------------------------------------------------------
    // funct3 = 000 is the "no CSR" corner: ECALL, EBREAK and MRET live there,
    // told apart by the whole upper 12 bits, because they have no operands at
    // all. Everything else under this opcode is a CSR instruction.
    wire sys = (opcode == OP_SYSTEM);
    wire priv = sys && (funct3 == 3'b000) && (rs1_f == 5'd0) && (inst[11:7] == 5'd0);

    assign is_ecall  = priv && (inst[31:20] == 12'h000);
    assign is_ebreak = priv && (inst[31:20] == 12'h001);
    assign is_mret   = priv && (inst[31:20] == 12'h302);

    // CSRRW=001 CSRRS=010 CSRRC=011 CSRRWI=101 CSRRSI=110 CSRRCI=111.
    // Bit 2 of funct3 says "the operand is an immediate", and the low two bits
    // say which operation -- the encoding is regular enough to decode with a
    // shift and a mask, which is not an accident.
    wire csr_shape = sys && (funct3 != 3'b000) && (funct3 != 3'b100);

    assign is_csr   = csr_shape;
    assign csr_op   = funct3[1:0] - 2'd1;     // 001->00 write, 010->01 set, 011->10 clear
    assign csr_imm  = funct3[2];
    assign csr_addr = inst[31:20];
    assign csr_zimm = rs1_f;

    // ---- M extension -------------------------------------------------------
    wire m_shape = (opcode == OP_REG) && (funct7 == 7'b0000001);

    assign is_mul = m_shape && !funct3[2];    // 0xx: the four multiplies
    assign is_div = m_shape &&  funct3[2];    // 1xx: the four divides
    assign md_op  = funct3;

    // ---- the verdict -------------------------------------------------------
    assign ext_legal  = is_csr | is_ecall | is_ebreak | is_mret | m_shape;

    // ECALL, EBREAK and MRET write no register. CSR instructions do, even
    // CSRRW with rd = x0 -- the register file discards that write by itself
    // (lesson 11), so there is no special case here.
    assign ext_reg_we = is_csr | m_shape;

    wire _unused = &{rs2_f, 1'b0};
endmodule
