`timescale 1ns/1ps
// Lesson 13 — the branch comparator.
//
// Branches need six comparisons that the ALU does not directly provide:
// equal, not-equal, and signed/unsigned less-than and greater-or-equal. The
// ALU could be made to do them -- SUB gives equality from its zero flag, and
// SLT/SLTU give the orderings -- but in a single-cycle CPU the ALU is busy:
// it is computing the branch TARGET at the same time.
//
// Hence a separate comparator. It is cheap (one subtract's worth of logic) and
// it keeps the ALU's result free for the address, which matters because every
// extra mux on the ALU's output lands on the critical path.
//
// Note what RV32I deliberately omits: there is no BGT or BLE. `bgt a, b, L` is
// assembled as `blt b, a, L` -- the operands are swapped by the assembler, and
// the hardware needs no extra cases. Six conditions, not ten.
module branch_unit (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  funct3,
    output reg         taken
);
    wire eq  = (a == b);
    wire ltu = (a < b);
    wire lt  = ($signed(a) < $signed(b));   // $signed, for the same reason
                                            // lesson 10's SRA needed it

    always @(*)
        case (funct3)
            3'b000: taken =  eq;    // BEQ
            3'b001: taken = !eq;    // BNE
            3'b100: taken =  lt;    // BLT
            3'b101: taken = !lt;    // BGE
            3'b110: taken =  ltu;   // BLTU
            3'b111: taken = !ltu;   // BGEU
            // funct3 010 and 011 are not branches; lesson 12's decoder
            // flags them illegal. A default is still required, or this
            // combinational block infers a latch.
            default: taken = 1'b0;
        endcase
endmodule
