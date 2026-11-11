`timescale 1ns/1ps
// Lesson 12 — the immediate generator, and why RISC-V scatters its bits.
//
// Five of the six instruction formats carry an immediate, and each lays it out
// differently:
//
//   I  imm[11:0]  = inst[31:20]
//   S  imm[11:5]  = inst[31:25], imm[4:0]  = inst[11:7]
//   B  imm[12]    = inst[31],    imm[10:5] = inst[30:25],
//      imm[4:1]   = inst[11:8],  imm[11]   = inst[7]
//   U  imm[31:12] = inst[31:12]
//   J  imm[20]    = inst[31],    imm[10:1] = inst[30:21],
//      imm[11]    = inst[20],    imm[19:12]= inst[19:12]
//
// Read as a table that looks deranged: B and J shuffle their bits out of
// order, and B puts imm[11] in inst[7] while imm[12] is in inst[31].
//
// IT IS NOT DERANGED. It is optimised for the hardware you are about to build,
// at the cost of being awkward for humans, and there are two rules behind it:
//
//   1. THE SIGN BIT IS ALWAYS inst[31]. Every format. So sign extension needs
//      no multiplexer at all -- just replicate inst[31]. On a 32-bit machine
//      that saves up to 20 mux inputs on the most timing-critical path in the
//      decoder.
//
//   2. EACH IMMEDIATE BIT COMES FROM AS FEW DIFFERENT PLACES AS POSSIBLE.
//      imm[10:5] is inst[30:25] in I, S, B and J alike. imm[4:1] is
//      inst[24:21] in I and J, inst[11:8] in S and B. So most output bits need
//      a 2-input mux rather than a 5-input one.
//
// Rule 2 is why B and J look shuffled: bit positions were assigned to keep
// them aligned across formats, not to keep them in order within a format. The
// README counts the mux inputs, and the numbers are the argument.
//
// Note also that B and J immediates are implicitly multiplied by 2 -- bit 0 is
// always zero and is not stored, because instructions are 2-byte aligned. That
// buys one extra bit of branch range for free.
module immgen (
    input  wire [31:0] inst,
    output reg  [31:0] imm
);
    // The format is a function of the opcode alone, which is why the opcode
    // lives in a fixed place (see decode.v).
    localparam [6:0] OP_LOAD   = 7'b0000011,
                     OP_IMM    = 7'b0010011,
                     OP_AUIPC  = 7'b0010111,
                     OP_STORE  = 7'b0100011,
                     OP_LUI    = 7'b0110111,
                     OP_BRANCH = 7'b1100011,
                     OP_JALR   = 7'b1100111,
                     OP_JAL    = 7'b1101111;

    wire [6:0] opcode = inst[6:0];

    always @(*)
        case (opcode)
            // I-type: a plain 12-bit signed field, sign-extended.
            OP_LOAD, OP_IMM, OP_JALR:
                imm = {{20{inst[31]}}, inst[31:20]};

            // S-type: the same 12 bits, split so that rs1 and rs2 can stay in
            // the same place as in R-type. That is the trade -- the immediate
            // is split so the REGISTER fields never move.
            OP_STORE:
                imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};

            // B-type: 13 bits, bit 0 implicitly zero.
            OP_BRANCH:
                imm = {{19{inst[31]}}, inst[31], inst[7],
                       inst[30:25], inst[11:8], 1'b0};

            // U-type: the immediate IS the top 20 bits, already in position.
            // No shifting, no sign extension -- LUI's whole job is to put a
            // constant in the high half of a register.
            OP_LUI, OP_AUIPC:
                imm = {inst[31:12], 12'b0};

            // J-type: 21 bits, bit 0 implicitly zero.
            OP_JAL:
                imm = {{11{inst[31]}}, inst[31], inst[19:12],
                       inst[20], inst[30:21], 1'b0};

            // R-type has no immediate, and neither does anything
            // unrecognised, so both land here. (There is deliberately no
            // OP_REG constant above: listing an opcode whose only action is
            // to fall through to the default would be a line of code that
            // does nothing, and `make lint` says so.)
            default:
                imm = 32'd0;
        endcase
endmodule
