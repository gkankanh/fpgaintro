`timescale 1ns/1ps
// ===========================================================================
//  Lesson 14 — a proof that passes and is worth nothing.
//
//  This is the failure mode that makes formal verification dangerous rather
//  than merely difficult. Everything here is correct Verilog, the design
//  under test is the real ALU, the assertions are true statements about it,
//  and the proof PASSES.
//
//  It proves almost nothing, because of one line:
//
//      assume (a == b);
//
//  With the operands forced equal, `a < b` is false for every input the
//  solver is allowed to consider. The SLT assertion becomes "0 == 0" and
//  holds trivially. The overflow logic that lesson 10 spent a page on is
//  never exercised at all. Replace the ALU with one that returns a constant
//  zero for SLT and this proof still passes.
//
//  Nobody writes `assume (a == b)` on purpose. They write an assumption to
//  exclude an input the design is not meant to handle, it is slightly too
//  strong, and the hole is invisible -- because a passing proof looks exactly
//  the same either way.
//
//  THE ANTIDOTE IS cover. An assertion says "this is always true"; a cover
//  says "this is reachable, please show me". If a cover you expect to be
//  reachable is not, your assumptions have excluded part of reality, and
//  every assertion resting on them is suspect.
//
//  Run `make formal-vacuous`: the prove task PASSES and the cover task FAILS.
//  The cover failure is the only thing standing between you and a false sense
//  of security.
// ===========================================================================
module vacuous (
    input  wire [3:0]  op,
    input  wire [31:0] a,
    input  wire [31:0] b
);
    localparam [3:0] OP_SLT = 4'b0010;

    wire [31:0] y;
    wire        zero;

    alu #(.W(32)) dut (.op(op), .a(a), .b(b), .y(y), .zero(zero));

    always @(*) begin
        assume (op == OP_SLT);

        // THE LINE THAT RUINS IT. Looks like a harmless narrowing of the
        // input space. It removes every input for which the property has
        // any content.
        assume (a == b);

        // A true statement about the design. Proved. Meaningless.
        assert (y == {31'd0, ($signed(a) < $signed(b))});
    end

    // The alarm. Both of these are plainly reachable in the real design --
    // signed less-than is sometimes true, and INT_MIN is a legal operand --
    // so a solver that cannot reach them is telling you the assumptions
    // above have thrown away the interesting half of the problem.
    always @(*) begin
        cover (y == 32'd1);                  // SLT is ever true
        cover (a == 32'h8000_0000 && b == 32'd0);   // INT_MIN vs zero
    end
endmodule
