`timescale 1ns/1ps
// Lesson 12 — turning a 32-bit instruction word into control signals.
//
// No execution here. This module only answers "what does this instruction
// want done", and lesson 13 wires those answers to lesson 10's ALU and
// lesson 11's register file.
//
// WHY THE OPCODE IS SEVEN BITS AND ALWAYS IN inst[6:0]:
// every other field's MEANING depends on the opcode, so the opcode must be
// decodable before anything else. Putting it at a fixed position means the
// register fields, the funct3 field and the immediate can all be extracted
// IN PARALLEL with decoding the opcode, rather than after it. In a
// single-cycle CPU that parallelism is the difference between one mux delay
// and two on the critical path.
//
// The register fields never move either: rs1 is always inst[19:15], rs2 is
// always inst[24:20], rd is always inst[11:7]. So the register file can be
// addressed before the instruction has been understood at all -- which is
// exactly what lesson 13 does.
module decode (
    input  wire [31:0] inst,

    // --- register file -----------------------------------------------------
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [4:0]  rd,
    output wire        reg_we,

    // --- ALU ---------------------------------------------------------------
    output wire [3:0]  alu_op,      // {instr[30], funct3}, as lesson 10 expects
    output wire        alu_a_pc,    // operand A is the PC, not rs1 (AUIPC, JAL)
    output wire        alu_a_zero,  // operand A is zero, not rs1 (LUI)
    output wire        alu_b_imm,   // operand B is the immediate, not rs2

    // --- memory ------------------------------------------------------------
    output wire        mem_read,
    output wire        mem_write,
    output wire [2:0]  mem_op,      // funct3: width and signedness

    // --- control flow ------------------------------------------------------
    output wire        branch,      // conditional, on the ALU/compare result
    output wire        jump,        // unconditional (JAL, JALR)
    output wire        jalr,        // target is rs1+imm rather than pc+imm

    // --- writeback ---------------------------------------------------------
    output wire [1:0]  wb_src,      // 0 = ALU, 1 = memory, 2 = pc+4

    // --- and the one every real CPU needs ----------------------------------
    output wire        illegal
);
    localparam [6:0] OP_LOAD   = 7'b0000011,
                     OP_IMM    = 7'b0010011,
                     OP_AUIPC  = 7'b0010111,
                     OP_STORE  = 7'b0100011,
                     OP_REG    = 7'b0110011,
                     OP_LUI    = 7'b0110111,
                     OP_BRANCH = 7'b1100011,
                     OP_JALR   = 7'b1100111,
                     OP_JAL    = 7'b1101111;

    localparam [1:0] WB_ALU = 2'd0, WB_MEM = 2'd1, WB_PC4 = 2'd2;

    wire [6:0] opcode = inst[6:0];
    wire [2:0] funct3 = inst[14:12];
    wire [6:0] funct7 = inst[31:25];

    // Fields at fixed positions, extracted unconditionally.
    assign rs1 = inst[19:15];
    assign rs2 = inst[24:20];
    assign rd  = inst[11:7];

    assign mem_op = funct3;

    // ---- which instruction class is this? ---------------------------------
    wire is_reg    = (opcode == OP_REG);
    wire is_imm    = (opcode == OP_IMM);
    wire is_load   = (opcode == OP_LOAD);
    wire is_store  = (opcode == OP_STORE);
    wire is_branch = (opcode == OP_BRANCH);
    wire is_jal    = (opcode == OP_JAL);
    wire is_jalr   = (opcode == OP_JALR);
    wire is_lui    = (opcode == OP_LUI);
    wire is_auipc  = (opcode == OP_AUIPC);

    // ---- the ALU operation ------------------------------------------------
    //
    // Lesson 10's ALU takes {instr[30], funct3}, which falls straight out of
    // the instruction for R-type. For I-type it very nearly does, and the
    // exception is a REAL BUG that is easy to ship:
    //
    //   addi x1, x2, -1
    //
    // has imm = 0xFFF, so inst[31:20] is all ones and inst[30] is 1. Pass
    // {inst[30], funct3} = {1, 000} to the ALU and it performs SUB instead of
    // ADD -- so `addi` with any negative immediate silently subtracts.
    //
    // inst[30] is only meaningful for OP-IMM when funct3 == 101, i.e.
    // SRLI versus SRAI. Everywhere else in OP-IMM it is part of the
    // immediate and must be forced to zero.
    wire use_bit30 = is_reg || (is_imm && funct3 == 3'b101);
    wire alu_bit30 = use_bit30 ? inst[30] : 1'b0;

    // Loads, stores, jumps, AUIPC and LUI all need an ADDITION regardless of
    // what funct3 says -- for those instructions funct3 means something else
    // entirely (a width, or which comparison), so it must not reach the ALU.
    //
    // LUI reuses ADD with operand A forced to ZERO, which is why RV32I needs
    // no "pass-through" ALU operation.
    wire needs_add = is_load || is_store || is_jal || is_jalr
                             || is_auipc || is_lui;

    // ONE assignment to the output. An earlier version assigned alu_op from
    // {alu_bit30, funct3} and then computed a separate `alu_op_final` that
    // was never connected to anything -- so the needs_add override silently
    // did nothing and every load would have asked the ALU for whatever funct3
    // happened to mean. `make lint` caught the dangling wire; it is a good
    // argument for keeping exactly one assignment per output.
    assign alu_op = needs_add ? 4'b0000 : {alu_bit30, funct3};

    // ---- operand sources --------------------------------------------------
    //
    // LUI AND OPERAND A. An earlier version of this file carried a comment
    // claiming "rs1 is x0 by convention for LUI" and relied on it. That is
    // FALSE: LUI has no rs1 field at all -- inst[19:15] is part of its 20-bit
    // immediate. So the ALU was adding the immediate to whatever register
    // those five bits happened to name, and since the register file starts
    // undefined, lesson 13's CPU stored X and the X's propagated through
    // every value built with `li` of a large constant.
    //
    // Found by running real software, which is exactly what lesson 13 is for:
    // the decoder's own testbench checked that LUI asks the ALU for ADD, and
    // it does. It never checked where operand A came from.
    //
    // JAL and AUIPC have the same field overlap but are already safe, because
    // they take operand A from the PC.
    assign alu_a_pc   = is_auipc || is_jal;
    assign alu_a_zero = is_lui;
    assign alu_b_imm  = !is_reg && !is_branch;

    // ---- memory -----------------------------------------------------------
    assign mem_read  = is_load;
    assign mem_write = is_store;

    // ---- control flow -----------------------------------------------------
    assign branch = is_branch;
    assign jump   = is_jal || is_jalr;
    assign jalr   = is_jalr;

    // ---- writeback --------------------------------------------------------
    // Stores and branches write no register. x0 absorbs a write anyway
    // (lesson 11), so `jal x0, L` needs no special case here.
    assign reg_we = is_reg || is_imm || is_load || is_lui || is_auipc
                           || is_jal || is_jalr;

    assign wb_src = is_load            ? WB_MEM :
                    (is_jal || is_jalr) ? WB_PC4 :
                                          WB_ALU;

    // ---- illegal instruction ----------------------------------------------
    //
    // Everything not recognised above. A real CPU must trap rather than
    // execute something arbitrary, and lesson 17 wires this to the trap
    // mechanism. Having the signal from the start costs one wire and means
    // the CPU is never silently executing nonsense.
    //
    // The funct7 checks catch malformed R-type: only 0000000 and 0100000 are
    // legal, and 0100000 only for SUB and SRA.
    wire bad_funct7 = is_reg &&
                      !((funct7 == 7'b0000000) ||
                        (funct7 == 7'b0100000 &&
                         (funct3 == 3'b000 || funct3 == 3'b101)));

    // Branches have no funct3 == 010 or 011.
    wire bad_branch = is_branch && (funct3 == 3'b010 || funct3 == 3'b011);

    // Loads have no funct3 == 011, 110 or 111; stores only 000, 001, 010.
    wire bad_load   = is_load &&
                      (funct3 == 3'b011 || funct3 == 3'b110 || funct3 == 3'b111);
    wire bad_store  = is_store && (funct3 != 3'b000 && funct3 != 3'b001
                                                    && funct3 != 3'b010);
    // JALR's funct3 must be 000.
    wire bad_jalr   = is_jalr && (funct3 != 3'b000);

    wire known = is_reg | is_imm | is_load | is_store | is_branch
               | is_jal | is_jalr | is_lui | is_auipc;

    assign illegal = !known | bad_funct7 | bad_branch
                            | bad_load   | bad_store | bad_jalr;
endmodule
