`timescale 1ns/1ps
// ===========================================================================
//  Lesson 17 — the M extension: multiply and divide.
//
//  Two units with completely different shapes, which is the lesson.
//
//  MULTIPLY IS A BLOCK THE CHIP ALREADY HAS. The ECP5 contains hard
//  18x18 multipliers (MULT18X18D), and a 32x32 product is four of them plus
//  the adds that combine the partial products. Write `a * b` and yosys infers
//  them.
//
//  IT IS STILL NOT A ONE-CYCLE OPERATION, and this lesson measured three
//  versions of it before settling. Three placer seeds each, maximum clock:
//
//    combinational                34.5 / 34.9 / 35.5 MHz
//    product registered  <-- ship  41.1 / 40.1 / 39.6 MHz
//    operands registered too      38.5 / 39.8 / 41.5 MHz
//
//  Built combinationally the multiplier WAS the critical path of the machine:
//  nextpnr reported 29 ns from the block RAM's output, through the forwarding
//  network, the four DSPs and the carry chain summing their partial products,
//  into the EX/MEM register -- against lesson 16's 46 MHz for the same core
//  without it. So the product is REGISTERED, the multiply takes two cycles,
//  and the clock comes back to 40.
//
//  THE THIRD VERSION IS THE INTERESTING ONE. Registering the operands as
//  well -- a three-cycle multiply, with the long path split in two -- is the
//  textbook next step, and it bought NOTHING: the same clock within the
//  placer's own spread, for an extra cycle on every multiply. The multiplier
//  had stopped being the critical path after the first register, and a second
//  one optimises something that is no longer the problem.
//
//  That is the whole method of this course in one decision. The obvious
//  improvement was measured, did not help, and was removed -- and the only
//  reason anyone knows is that it was measured three times rather than once,
//  because a single run of this design lands anywhere between 38.5 and 41.5
//  MHz depending on a random seed.
//
//  DIVIDE IS NOT. There is no divider on the chip, there is no divider on
//  most CPUs, and the reason is that division does not parallelise the way
//  multiplication does: each step of a long division depends on the result of
//  the step before. So it is a state machine, one bit per cycle, 32 cycles --
//  and it is the first thing in this course that makes the pipeline WAIT.
//
//  THAT ASYMMETRY IS WHY `a / b` IS EXPENSIVE IN C AND `a * b` IS NOT, and
//  why compilers turn division by a constant into a multiply by a magic
//  number. It is not folklore. It is this file.
// ===========================================================================

// ---------------------------------------------------------------------------
//  MUL, MULH, MULHSU, MULHU — one cycle, combinational.
//
//  Four instructions because a 32x32 product is 64 bits and only 32 fit in a
//  register. MUL gives the low half; the three MULH variants give the high
//  half for each combination of signedness. A compiler emits MULH alongside
//  MUL when it wants the whole product -- and the pair is the reason RISC-V
//  has no "multiply with carry out" flag: there are no flags anywhere in this
//  instruction set, by design, and this is how the hole is filled.
//
//  The widening trick: sign-extend both operands to 33 bits according to
//  their signedness, multiply once, and slice. One multiplier serves all four
//  instructions instead of three different ones.
// ---------------------------------------------------------------------------
module mul_unit (
    input  wire        clk,
    input  wire        rst,

    // The same request/done handshake as the divider below, so the pipeline
    // needs only one kind of "EX is not finished" and does not care which
    // unit is holding it up.
    input  wire        req,
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  op,        // 000 MUL, 001 MULH, 010 MULHSU, 011 MULHU
    output wire        done,
    output wire [31:0] y
);
    wire a_signed = (op != 3'b011);                 // only MULHU has unsigned a
    wire b_signed = (op == 3'b001);                 // only MULH has signed b

    wire signed [32:0] ae = {a_signed & a[31], a};
    wire signed [32:0] be = {b_signed & b[31], b};

    wire signed [65:0] p = ae * be;

    reg        busy = 0;
    reg [65:0] p_q  = 0;
    reg [2:0]  op_q = 0;

    // The same request/done handshake as the divider, so the pipeline needs
    // only one notion of "EX is not finished" and does not care which unit is
    // holding it up -- one for a cycle, the other for thirty-two.
    assign done = busy;

    always @(posedge clk)
        if (rst)
            busy <= 0;
        else if (!busy) begin
            if (req) begin
                p_q  <= p;        // this one register is the whole fix
                op_q <= op;
                busy <= 1;
            end
        end else if (!req)
            busy <= 0;

    assign y = (op_q == 3'b000) ? p_q[31:0] : p_q[63:32];

    // A 33x33 product is 66 bits and RV32IM defines 64 of them. The top two
    // can only be sign extension: two 33-bit values each fit in 32 bits plus
    // a sign, so their product fits in 64 plus a sign.
    wire _unused = &{p_q[65:64], 1'b0};
endmodule


// ---------------------------------------------------------------------------
//  DIV, DIVU, REM, REMU — restoring division, one quotient bit per cycle.
//
//  THE SPECIFICATION'S CORNER CASES ARE NOT OPTIONAL, and they are the reason
//  this module is longer than the algorithm:
//
//    x / 0   = -1 (all ones)        x % 0   = x
//    x /u 0  = 2**32 - 1            x %u 0  = x
//    -2**31 / -1 = -2**31           -2**31 % -1 = 0
//
//  RISC-V defines division by zero to RETURN A VALUE rather than trap, which
//  is unusual and deliberate: a trap would need the divide to be precise in a
//  pipeline, and every program that wants the check can write one `beqz`. The
//  overflow case exists because 2**31 has no positive representation in 32
//  bits -- the one value whose negation is itself.
//
//  Get these wrong and nothing fails for months, until something divides by a
//  variable that is zero this once.
// ---------------------------------------------------------------------------
module div_unit (
    input  wire        clk,
    input  wire        rst,

    input  wire        req,       // a divide is sitting in EX, waiting
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  op,        // 100 DIV, 101 DIVU, 110 REM, 111 REMU
    output wire        done,      // the answer is on `y` now
    output reg  [31:0] y
);
    localparam [1:0] IDLE = 2'd0, RUN = 2'd1, FIN = 2'd2;

    reg [1:0]  state = IDLE;
    reg [32:0] rem   = 0;         // 33 bits: the shift can carry out of 32
    reg [31:0] quo   = 0;
    reg [31:0] ua    = 0, ub = 0;
    reg [4:0]  cnt   = 0;
    reg        q_neg = 0, r_neg = 0;
    reg        want_rem = 0;

    assign done = (state == FIN);

    wire is_signed = !op[0];
    wire rem_wanted =  op[1];

    // Magnitudes. Note that negating 0x8000_0000 gives 0x8000_0000 back, which
    // is exactly right: its magnitude does not fit, and the overflow case
    // below is what catches it.
    wire [31:0] mag_a = (is_signed && a[31]) ? (~a + 32'd1) : a;
    wire [31:0] mag_b = (is_signed && b[31]) ? (~b + 32'd1) : b;

    wire div_zero = (b == 32'd0);
    wire overflow = is_signed && (a == 32'h8000_0000) && (b == 32'hFFFF_FFFF);

    // One restoring step: shift the next dividend bit in, subtract if it fits.
    wire [32:0] shifted = {rem[31:0], ua[cnt]};
    wire [32:0] diff    = shifted - {1'b0, ub};
    wire        fits    = !diff[32];

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            y     <= 32'd0;
        end else case (state)
            IDLE:
                if (req) begin
                    if (div_zero) begin
                        // The specification's values, not a convenient zero.
                        // DIV and DIVU both give all-ones; REM and REMU
                        // both give the dividend untouched.
                        y     <= rem_wanted ? a : 32'hFFFF_FFFF;
                        state <= FIN;
                    end else if (overflow) begin
                        y     <= rem_wanted ? 32'd0 : 32'h8000_0000;
                        state <= FIN;
                    end else begin
                        ua       <= mag_a;
                        ub       <= mag_b;
                        rem      <= 33'd0;
                        quo      <= 32'd0;
                        cnt      <= 5'd31;
                        q_neg    <= is_signed && (a[31] ^ b[31]);
                        r_neg    <= is_signed && a[31];
                        want_rem <= rem_wanted;
                        state    <= RUN;
                    end
                end

            RUN: begin
                rem      <= fits ? diff : shifted;
                quo[cnt] <= fits;
                if (cnt == 5'd0) state <= FIN;
                else             cnt   <= cnt - 5'd1;
            end

            // The answer is held here until the pipeline takes the
            // instruction out of EX, which is what drops `req`.
            FIN: if (!req) state <= IDLE;

            default: state <= IDLE;
        endcase

        // The sign is applied the cycle the last quotient bit lands, so that
        // `y` is correct from the first cycle `done` is high.
        if (state == RUN && cnt == 5'd0) begin
            if (want_rem) begin
                // The remainder currently in `rem` does not include this
                // cycle's step, so take it from the same wires the step uses.
                y <= r_neg ? (~(fits ? diff[31:0] : shifted[31:0]) + 32'd1)
                           :  (fits ? diff[31:0] : shifted[31:0]);
            end else begin
                y <= q_neg ? (~{quo[31:1], fits} + 32'd1) : {quo[31:1], fits};
            end
        end
    end
    // op[2] is 1 for every instruction that reaches this unit -- it is what
    // told decode_ext this was a divide rather than a multiply. rem[32] is
    // the bit the subtraction can borrow into and never a result bit, and
    // quo[0] is written on the last step but read from `fits` instead,
    // because the step and the answer happen in the same cycle.
    wire _unused = &{op[2], rem[32], quo[0], 1'b0};

endmodule
