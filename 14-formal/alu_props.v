`timescale 1ns/1ps
// ===========================================================================
//  Lesson 14 — proving the ALU, rather than testing it.
//
//  Lesson 10 put a number on why this lesson exists. A 32-bit ALU has
//  2**32 x 2**32 x 10 input combinations -- about 4.6e19. At a billion a
//  second, checking them all takes 1,460 years, so lesson 10 settled for
//  1,440 directed vectors and 20,000 random ones.
//
//  This module makes the same claim as those tests, but as a PROOF over every
//  input. It takes seconds, because a solver does not enumerate: it reasons.
//
//  The ALU is purely combinational, which makes this especially clean. A
//  bounded model check to depth 1 examines every possible input in one step,
//  so for combinational logic "bounded" is not a limitation at all -- depth 1
//  IS a complete proof.
//
//  WHAT A PROPERTY MUST NOT BE. A property that restates the implementation
//  proves nothing. The ALU's shifts ARE Verilog's shift operators, so
//  asserting `sll == a << sh` would be asserting `x == x`. The shift
//  properties below are therefore written as independent facts about what a
//  shift must DO -- vacated bits are zero, an arithmetic shift replicates the
//  sign -- rather than as a restatement of how it is done. Lesson 10 made the
//  same argument and answered it with a second implementation; formal lets
//  you answer it with a specification instead.
// ===========================================================================
module alu_props (
    input  wire [3:0]  op,
    input  wire [31:0] a,
    input  wire [31:0] b
);
    localparam [3:0] OP_ADD  = 4'b0000, OP_SUB  = 4'b1000,
                     OP_SLL  = 4'b0001, OP_SLT  = 4'b0010,
                     OP_SLTU = 4'b0011, OP_XOR  = 4'b0100,
                     OP_SRL  = 4'b0101, OP_SRA  = 4'b1101,
                     OP_OR   = 4'b0110, OP_AND  = 4'b0111;

    wire [31:0] y;
    wire        zero;

    alu #(.W(32)) dut (.op(op), .a(a), .b(b), .y(y), .zero(zero));

    wire [4:0] sh = b[4:0];

    // ---- the one assumption, and why it is safe -------------------------
    //
    // Only ten of the sixteen op encodings mean anything. Lesson 12's decoder
    // never emits the other six -- it raises an illegal-instruction exception
    // instead -- so constraining the proof to legal operations is honest.
    //
    // ASSUMPTIONS ARE WHERE PROOFS GO TO DIE. Assume too much and you prove
    // something true of a machine nobody will build. See vacuous.v for what
    // that looks like when it goes wrong. This one is narrow and checkable:
    // it excludes exactly the encodings the decoder refuses to produce.
    always @(*)
        assume (op == OP_ADD || op == OP_SUB  || op == OP_SLL || op == OP_SLT ||
                op == OP_SLTU|| op == OP_XOR  || op == OP_SRL || op == OP_SRA ||
                op == OP_OR  || op == OP_AND);

    always @(*) begin
        // ---- arithmetic: proved against Verilog's own operators ----------
        //
        // This comparison IS independent: the ALU builds these from a single
        // adder with an inverted operand and explicit overflow logic, while
        // the right-hand side is the language's arithmetic. Two different
        // routes to one answer, now checked for all 2**64 operand pairs.
        if (op == OP_ADD)  assert (y == a + b);
        if (op == OP_SUB)  assert (y == a - b);

        // ---- the comparisons lesson 10 warned about ----------------------
        //
        // Signed less-than is where hand-written ALUs fail, and they fail
        // only at the extremes where the difference overflows. A proof does
        // not have to think of those cases.
        if (op == OP_SLT)  assert (y == {31'd0, ($signed(a) < $signed(b))});
        if (op == OP_SLTU) assert (y == {31'd0, (a < b)});

        // ---- bitwise -----------------------------------------------------
        if (op == OP_XOR)  assert (y == (a ^ b));
        if (op == OP_OR)   assert (y == (a | b));
        if (op == OP_AND)  assert (y == (a & b));

        // ---- shifts, as PROPERTIES rather than restatements --------------
        //
        // Each of these is a fact a correct shift must satisfy, written
        // without using the shift operator being checked.

        // Shifting by zero changes nothing. Catches an off-by-one in the
        // shift amount, which an `a << sh` restatement never could.
        if (sh == 5'd0) begin
            if (op == OP_SLL) assert (y == a);
            if (op == OP_SRL) assert (y == a);
            if (op == OP_SRA) assert (y == a);
        end

        // A mask with ones in the bits a shift VACATES. Writing the
        // properties through a mask keeps them legal Verilog and keeps them
        // independent of the shift operator being checked -- `y[sh-1:0]` is
        // not a legal part-select, and the first run of this proof failed on
        // exactly that. See the README: the first thing a formal tool finds
        // is usually a bug in your property.
        if (op == OP_SLL) begin
            // The low `sh` bits are vacated and must be zero...
            assert ((y & ~(32'hFFFF_FFFF << sh)) == 32'd0);
            // ...and the bits that survived are the original low bits.
            assert ((y >> sh) == (a & (32'hFFFF_FFFF >> sh)));
        end

        if (op == OP_SRL) begin
            // A logical right shift vacates the HIGH bits with zeros.
            assert ((y & ~(32'hFFFF_FFFF >> sh)) == 32'd0);
            assert ((y << sh) == (a & (32'hFFFF_FFFF << sh)));
        end

        if (op == OP_SRA) begin
            // An arithmetic right shift fills the vacated high bits with
            // COPIES OF THE SIGN BIT -- all ones if negative, all zeros if
            // not. This is the property `a >>> sh` on an unsigned operand
            // silently violates, and the bug lesson 10 called the most common
            // in any ALU.
            if (a[31]) assert ((y & ~(32'hFFFF_FFFF >> sh)) == ~(32'hFFFF_FFFF >> sh));
            else       assert ((y & ~(32'hFFFF_FFFF >> sh)) == 32'd0);
            // The surviving bits are the same either way.
            assert ((y << sh) == (a & (32'hFFFF_FFFF << sh)));
        end

        // ---- the zero flag, for every operation --------------------------
        assert (zero == (y == 32'd0));
    end

    // ---- covers: proof that the proof is not vacuous ---------------------
    //
    // An assertion holds trivially if the state it describes is unreachable.
    // A `cover` asks the solver to PRODUCE a trace reaching some state; if it
    // cannot, the assumptions have excluded reality and the proof above is
    // worth nothing. These are the antidote, and they are not optional.
    always @(*) begin
        cover (op == OP_SLT && y == 32'd1);                 // SLT can be true
        cover (op == OP_SLT && y == 32'd0);                 // and false
        cover (op == OP_SLT && a == 32'h8000_0000);         // at INT_MIN
        cover (op == OP_SLTU && y != {31'd0, ($signed(a) < $signed(b))});
                                                            // signed and
                                                            // unsigned really
                                                            // do disagree
        cover (op == OP_SRA && a[31] && y != (a >> sh));     // SRA differs from SRL
        cover (op == OP_ADD && y == 32'd0 && a != 32'd0);    // wraparound happens
        cover (zero);
    end
endmodule
