`timescale 1ns/1ps
// Lesson 10 — the RV32I ALU.
//
// Ten operations, and not one more. That is worth pausing on: a CISC machine
// might have hundreds, and RISC-V's integer base has add, subtract, three
// shifts, two comparisons and three bitwise ops. Everything else is built
// from these by the compiler -- negation is `sub` from x0, `not` is `xor` with
// -1, a branch-if-greater is a branch-if-less with the operands swapped.
//
// THE ENCODING IS NOT ARBITRARY. RISC-V packs the selector into
// {instruction[30], funct3}, four bits, and that layout is why:
//
//   op   name   funct3   bit30   note
//   ---- ------ -------- ------- ------------------------------------------
//   0000 ADD    000      0
//   1000 SUB    000      1       same funct3 as ADD, bit 30 distinguishes
//   0001 SLL    001      0
//   0010 SLT    010      0       signed
//   0011 SLTU   011      0       unsigned
//   0100 XOR    100      0
//   0101 SRL    101      0
//   1101 SRA    101      1       same funct3 as SRL, bit 30 distinguishes
//   0110 OR     110      0
//   0111 AND    111      0
//
// Only two operations need bit 30 — and they are exactly the two pairs where
// one is the "signed/arithmetic" variant of the other. Lesson 12 decodes this
// field straight out of the instruction word with no translation table at all,
// which is a deliberate gift from the ISA designers to anyone building a
// decoder.
module alu #(
    parameter W = 32
)(
    input  wire [3:0]   op,        // {instr[30], funct3}
    input  wire [W-1:0] a,
    input  wire [W-1:0] b,
    output wire [W-1:0] y,
    output wire         zero       // y == 0, which branches need
);
    localparam [3:0] OP_ADD  = 4'b0000,
                     OP_SUB  = 4'b1000,
                     OP_SLL  = 4'b0001,
                     OP_SLT  = 4'b0010,
                     OP_SLTU = 4'b0011,
                     OP_XOR  = 4'b0100,
                     OP_SRL  = 4'b0101,
                     OP_SRA  = 4'b1101,
                     OP_OR   = 4'b0110,
                     OP_AND  = 4'b0111;

    // ---- one adder for add, subtract AND both comparisons -----------------
    //
    // a - b == a + (~b) + 1 in two's complement, so subtraction is the same
    // adder with b inverted and the carry-in set. One `adder` instance, not
    // two, and it is lesson 02's module promoted to common/rtl.
    //
    // The comparisons come free from the same subtraction, which is why they
    // live here rather than as separate comparators.
    wire              subtract = (op == OP_SUB) || (op == OP_SLT) || (op == OP_SLTU);
    wire [W-1:0]      addend   = subtract ? ~b : b;
    wire [W-1:0]      sum;
    wire              carry;

    adder #(.W(W)) u_add (
        .a(a), .b(addend), .cin(subtract), .s(sum), .cout(carry));

    // ---- SLTU: unsigned less-than is the borrow out -----------------------
    //
    // For an unsigned subtract, carry-out is 1 when there was NO borrow, i.e.
    // when a >= b. So a < b is simply !carry. No comparator needed.
    wire ltu = ~carry;

    // ---- SLT: signed less-than is NOT a comparison of the raw bits --------
    //
    // The sign bit of the difference is right only when the subtraction did
    // not overflow. Overflow happens exactly when the operands have different
    // signs and the result takes the sign of b:
    //
    //     overflow = (a[W-1] != b[W-1]) && (sum[W-1] != a[W-1])
    //
    // and then a < b is sum's sign XOR overflow.
    //
    // The shortcut that nearly works, and is a real bug: when the signs
    // differ, the answer is just a's sign -- a negative number is always less
    // than a positive one. Many hand-written ALUs get this almost right and
    // fail only at the extremes, where the difference overflows.
    wire overflow = (a[W-1] ^ b[W-1]) & (sum[W-1] ^ a[W-1]);
    wire lt       = sum[W-1] ^ overflow;

    // ---- the shifts -------------------------------------------------------
    //
    // Only the low log2(W) bits of b are the shift amount; RV32I specifies
    // that the rest are IGNORED, not an error. So a shift by 32 is a shift by
    // 0, which a C programmer would call undefined behaviour and the hardware
    // simply defines.
    //
    // `>>>` is an arithmetic shift ONLY if its left operand is signed, which
    // is why $signed(a) is needed here. Writing `a >>> sh` on an unsigned
    // wire silently gives a logical shift -- it compiles, simulates, and is
    // wrong for every negative input. This is the single most common ALU bug.
    localparam SHW = $clog2(W);
    wire [SHW-1:0] sh = b[SHW-1:0];

    wire [W-1:0] sll = a << sh;
    wire [W-1:0] srl = a >> sh;
    wire [W-1:0] sra = $signed(a) >>> sh;

    // ---- the result mux ---------------------------------------------------
    reg [W-1:0] r;
    always @(*)
        case (op)
            OP_ADD, OP_SUB: r = sum;
            OP_SLL:         r = sll;
            OP_SRL:         r = srl;
            OP_SRA:         r = sra;
            OP_SLT:         r = {{(W-1){1'b0}}, lt};
            OP_SLTU:        r = {{(W-1){1'b0}}, ltu};
            OP_XOR:         r = a ^ b;
            OP_OR:          r = a | b;
            OP_AND:         r = a & b;
            // Unused op encodings. A CPU should never present one -- lesson
            // 12's decoder raises an illegal-instruction exception instead --
            // but a combinational block still needs every path assigned, or
            // it infers a latch. Lesson 02's rule, in the CPU's hot path.
            default:        r = {W{1'b0}};
        endcase

    assign y    = r;
    assign zero = (r == {W{1'b0}});
endmodule
