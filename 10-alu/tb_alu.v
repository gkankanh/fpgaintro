`timescale 1ns/1ps
// Lesson 10 testbench — the lesson where exhaustive testing dies.
//
// A 32-bit ALU has 2**32 x 2**32 x 10 input combinations. That is 4.6e19
// vectors; at a billion per second it would take 1,460 years. Lesson 02's
// strategy is simply gone.
//
// What replaces it, and this is the pattern for everything from here on:
//
//   1. DIRECTED edge cases -- zero, one, minus one, INT_MIN, INT_MAX, and the
//      pairs where a naive implementation is known to break
//   2. RANDOMISED comparison against a REFERENCE MODEL, many iterations
//   3. an INDEPENDENT second implementation for the parts where a reference
//      written with the same operator would prove nothing
//
// Point 3 matters more than it looks. For ADD/SUB/SLT the reference below uses
// Verilog's own operators while the DUT builds them from an adder and explicit
// overflow logic, so the comparison is meaningful. But the DUT's shifts ARE
// Verilog's shift operators, so checking them against the same operators
// tests nothing at all. They are therefore cross-checked against
// shift_iterative, which shifts one place per clock -- a genuinely different
// implementation that can disagree.
module tb_alu;
    localparam W = 32;

    reg clk = 0;
    always #20 clk = ~clk;

    localparam [3:0] OP_ADD  = 4'b0000, OP_SUB  = 4'b1000,
                     OP_SLL  = 4'b0001, OP_SLT  = 4'b0010,
                     OP_SLTU = 4'b0011, OP_XOR  = 4'b0100,
                     OP_SRL  = 4'b0101, OP_SRA  = 4'b1101,
                     OP_OR   = 4'b0110, OP_AND  = 4'b0111;

    reg  [3:0]   op = 0;
    reg  [W-1:0] a = 0, b = 0;
    wire [W-1:0] y;
    wire         zero;
    alu #(.W(W)) dut (.op(op), .a(a), .b(b), .y(y), .zero(zero));

    // The independent shifter, used as a reference for SLL/SRL/SRA.
    reg          sh_start = 0, sh_right = 0, sh_arith = 0;
    wire [W-1:0] sh_y;
    wire         sh_busy;
    shift_iterative #(.W(W)) u_sh (
        .clk(clk), .start(sh_start), .a(a), .sh(b[4:0]),
        .right(sh_right), .arith(sh_arith), .y(sh_y), .busy(sh_busy));

    integer errors = 0, checks = 0;

    // The reference model. Deliberately written with Verilog's operators and
    // $signed, NOT by reimplementing the DUT's adder-and-overflow approach --
    // two different routes to the same answer is the point.
    function [W-1:0] model(input [3:0] o, input [W-1:0] x, input [W-1:0] z);
        case (o)
            OP_ADD:  model = x + z;
            OP_SUB:  model = x - z;
            OP_SLL:  model = x << z[4:0];
            OP_SRL:  model = x >> z[4:0];
            OP_SRA:  model = $signed(x) >>> z[4:0];
            OP_SLT:  model = ($signed(x) < $signed(z)) ? 32'd1 : 32'd0;
            OP_SLTU: model = (x < z)                   ? 32'd1 : 32'd0;
            OP_XOR:  model = x ^ z;
            OP_OR:   model = x | z;
            OP_AND:  model = x & z;
            default: model = 32'd0;
        endcase
    endfunction

    function [8*5-1:0] opname(input [3:0] o);
        case (o)
            OP_ADD:  opname = "ADD";   OP_SUB:  opname = "SUB";
            OP_SLL:  opname = "SLL";   OP_SRL:  opname = "SRL";
            OP_SRA:  opname = "SRA";   OP_SLT:  opname = "SLT";
            OP_SLTU: opname = "SLTU";  OP_XOR:  opname = "XOR";
            OP_OR:   opname = "OR";    OP_AND:  opname = "AND";
            default: opname = "?";
        endcase
    endfunction

    // Apply one (op, a, b) and compare against the model.
    task check(input [3:0] o, input [W-1:0] x, input [W-1:0] z);
        reg [W-1:0] want;
    begin
        op = o; a = x; b = z; #1;
        want   = model(o, x, z);
        checks = checks + 1;
        if (y !== want) begin
            errors = errors + 1;
            if (errors <= 12)
                $display("  FAIL %0s a=%h b=%h -> %h, model says %h",
                         opname(o), x, z, y, want);
        end
        // `zero` must track the result, every time.
        if (zero !== (want == {W{1'b0}})) begin
            errors = errors + 1;
            if (errors <= 12)
                $display("  FAIL %0s a=%h b=%h: zero=%b but result is %h",
                         opname(o), x, z, zero, want);
        end
    end
    endtask

    // Cross-check one shift against the bit-at-a-time implementation.
    task check_shift(input [3:0] o, input [W-1:0] x, input [W-1:0] z);
        reg [W-1:0] from_alu;
    begin
        op = o; a = x; b = z; #1;
        from_alu = y;

        sh_right = (o != OP_SLL);
        sh_arith = (o == OP_SRA);
        @(negedge clk); sh_start = 1;
        @(negedge clk); sh_start = 0;
        while (sh_busy) @(posedge clk);
        #1;

        checks = checks + 1;
        if (from_alu !== sh_y) begin
            errors = errors + 1;
            if (errors <= 12)
                $display("  FAIL %0s a=%h sh=%0d: barrel gave %h, iterative gave %h",
                         opname(o), x, z[4:0], from_alu, sh_y);
        end
    end
    endtask

    // Interesting operands: the extremes, and the values where sign handling
    // and overflow go wrong.
    localparam NV = 12;
    reg [W-1:0] v [0:NV-1];

    integer i, j, k, n;
    reg [3:0] ops [0:9];

    initial begin
        $dumpfile("alu.vcd");
        $dumpvars(0, tb_alu);

        v[0]  = 32'h0000_0000;   // zero
        v[1]  = 32'h0000_0001;   // one
        v[2]  = 32'hFFFF_FFFF;   // -1
        v[3]  = 32'h7FFF_FFFF;   // INT_MAX
        v[4]  = 32'h8000_0000;   // INT_MIN -- the one that breaks things
        v[5]  = 32'h8000_0001;   // INT_MIN + 1
        v[6]  = 32'hFFFF_FFFE;   // -2
        v[7]  = 32'h5555_5555;
        v[8]  = 32'hAAAA_AAAA;
        v[9]  = 32'h0000_001F;   // 31: the largest legal shift
        v[10] = 32'h0000_0020;   // 32: shift amount that must WRAP to 0
        v[11] = 32'h0000_0010;   // 16

        ops[0]=OP_ADD;  ops[1]=OP_SUB;  ops[2]=OP_SLL;  ops[3]=OP_SRL;
        ops[4]=OP_SRA;  ops[5]=OP_SLT;  ops[6]=OP_SLTU; ops[7]=OP_XOR;
        ops[8]=OP_OR;   ops[9]=OP_AND;

        // ===== 1. every op over every pair of interesting operands =========
        // 10 x 12 x 12 = 1,440 directed vectors. Not exhaustive, but it
        // covers every extreme against every other extreme.
        for (k = 0; k < 10; k = k + 1)
          for (i = 0; i < NV; i = i + 1)
            for (j = 0; j < NV; j = j + 1)
              check(ops[k], v[i], v[j]);

        // ===== 2. the specific SLT cases a naive version fails =============
        // "If the signs differ, the answer is a's sign" is the shortcut that
        // nearly works. These are where the difference overflows.
        check(OP_SLT,  32'h8000_0000, 32'h7FFF_FFFF);  // INT_MIN < INT_MAX: true
        check(OP_SLT,  32'h7FFF_FFFF, 32'h8000_0000);  // INT_MAX < INT_MIN: false
        check(OP_SLT,  32'hFFFF_FFFF, 32'h0000_0001);  // -1 < 1: true
        check(OP_SLT,  32'h0000_0001, 32'hFFFF_FFFF);  // 1 < -1: false
        check(OP_SLT,  32'h8000_0000, 32'hFFFF_FFFF);  // INT_MIN < -1: true

        // And the same pairs unsigned, where the answers invert.
        check(OP_SLTU, 32'h8000_0000, 32'h0000_0001);  // false: 2^31 > 1
        check(OP_SLTU, 32'h0000_0001, 32'h8000_0000);  // true
        check(OP_SLTU, 32'hFFFF_FFFF, 32'h0000_0000);  // false: max > 0

        // ===== 3. SRA against an independent implementation ================
        // The sign-extension trap: $signed() is what makes >>> arithmetic.
        // Checking it against the same operator would prove nothing, so these
        // go through shift_iterative instead.
        for (i = 0; i < NV; i = i + 1) begin
            check_shift(OP_SRA, v[i], 32'd1);
            check_shift(OP_SRA, v[i], 32'd31);
            check_shift(OP_SLL, v[i], 32'd1);
            check_shift(OP_SRL, v[i], 32'd17);
        end
        // Negative values shifted right must keep their sign.
        check_shift(OP_SRA, 32'hFFFF_FFFF, 32'd31);    // -1 >>> 31 == -1
        check_shift(OP_SRA, 32'h8000_0000, 32'd31);    // INT_MIN >>> 31 == -1
        check_shift(OP_SRA, 32'h8000_0000, 32'd4);

        // ===== 4. randomised, against the model ============================
        // 20,000 vectors. Not proof -- lesson 14 is about proof -- but it
        // reaches combinations nobody would think to write down.
        for (n = 0; n < 20000; n = n + 1)
          check(ops[n % 10], {$random, $random}, {$random, $random});

        if (errors == 0)
            $display("PASS: %0d checks - 1440 directed + SLT/SLTU extremes + shifts cross-checked against an independent implementation + 20000 randomised", checks);
        else
            $display("FAIL: %0d of %0d checks wrong", errors, checks);
        $finish;
    end
endmodule
