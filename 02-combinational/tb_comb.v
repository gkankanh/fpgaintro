`timescale 1ns/1ps
// Lesson 02 testbench — the last time in this course that "test everything"
// is a strategy rather than a wish.
//
// Four exhaustive sweeps:
//   dec       all 4 selector values, checking exactly one output is high
//   seg7      all 16 digits, both implementations, against expected patterns
//   adder4    all 512 (a, b, cin) combinations, ripple vs behavioural vs a
//             computed reference
//   mux2      all 512 (sel, d0, d1) combinations at 4 bits
//
// Note what "exhaustive" costs as the design grows: 4 cases, then 16, then
// 512. A 32-bit adder would be 2^65 cases. That cliff is why lesson 10 tests
// by randomised comparison against a model, and why lesson 14 exists at all.
module tb_comb;

    integer errors = 0;
    integer checks = 0;

    task fail(input [8*24-1:0] what);
    begin
        errors = errors + 1;
        $display("  FAIL %0s", what);
    end
    endtask

    // ---------------------------------------------------------------- dec ---
    reg  [1:0] dsel;
    wire [3:0] dout;
    dec #(.N(2)) u_dec (.sel(dsel), .y(dout));

    // --------------------------------------------------------------- seg7 ---
    reg  [3:0] hex;
    wire [6:0] seg_case, seg_rom;
    seg7     u_seg  (.hex(hex), .seg(seg_case));
    seg7_rom u_segr (.hex(hex), .seg(seg_rom));

    reg [6:0] expect_seg [0:15];

    // -------------------------------------------------------------- adder ---
    reg  [3:0] a, b;
    reg        cin;
    wire [3:0] s_rip, s_beh;
    wire       c_rip, c_beh;
    adder4_ripple u_rip (.a(a), .b(b), .cin(cin), .s(s_rip), .cout(c_rip));
    adder4_behav  u_beh (.a(a), .b(b), .cin(cin), .s(s_beh), .cout(c_beh));

    // ---------------------------------------------------------------- mux ---
    reg  [3:0] d0, d1;
    reg        msel;
    wire [3:0] my;
    mux2 #(.W(4)) u_mux (.d0(d0), .d1(d1), .sel(msel), .y(my));

    integer i, j, k;
    reg [4:0] want;

    initial begin
        $dumpfile("comb.vcd");
        $dumpvars(0, tb_comb);

        expect_seg[ 0] = 7'b1111110; expect_seg[ 1] = 7'b0110000;
        expect_seg[ 2] = 7'b1101101; expect_seg[ 3] = 7'b1111001;
        expect_seg[ 4] = 7'b0110011; expect_seg[ 5] = 7'b1011011;
        expect_seg[ 6] = 7'b1011111; expect_seg[ 7] = 7'b1110000;
        expect_seg[ 8] = 7'b1111111; expect_seg[ 9] = 7'b1111011;
        expect_seg[10] = 7'b1110111; expect_seg[11] = 7'b0011111;
        expect_seg[12] = 7'b1001110; expect_seg[13] = 7'b0111101;
        expect_seg[14] = 7'b1001111; expect_seg[15] = 7'b1000111;

        // ---- decoder: one-hot, and the right bit ---------------------------
        for (i = 0; i < 4; i = i + 1) begin
            dsel = i[1:0]; #1;
            checks = checks + 1;
            if (dout !== (4'b0001 << i)) fail("dec wrong bit");
        end

        // ---- seg7: both versions, all 16 digits ---------------------------
        for (i = 0; i < 16; i = i + 1) begin
            hex = i[3:0]; #1;
            checks = checks + 2;
            if (seg_case !== expect_seg[i]) begin
                $display("  FAIL seg7     hex=%h got=%b want=%b",
                         hex, seg_case, expect_seg[i]);
                errors = errors + 1;
            end
            // The ROM version must agree with the case version exactly. Two
            // descriptions of one truth table; if they differ, one is a typo.
            if (seg_rom !== seg_case) begin
                $display("  FAIL seg7_rom hex=%h case=%b rom=%b",
                         hex, seg_case, seg_rom);
                errors = errors + 1;
            end
        end

        // ---- adder: all 512 combinations ----------------------------------
        for (i = 0; i < 16; i = i + 1)
          for (j = 0; j < 16; j = j + 1)
            for (k = 0; k < 2; k = k + 1) begin
                a = i[3:0]; b = j[3:0]; cin = k[0]; #1;
                // The reference is computed in 5 bits so the carry survives.
                want = {1'b0, a} + {1'b0, b} + {4'b0, cin};
                checks = checks + 2;
                if ({c_rip, s_rip} !== want) begin
                    $display("  FAIL ripple a=%h b=%h cin=%b got=%b want=%b",
                             a, b, cin, {c_rip, s_rip}, want);
                    errors = errors + 1;
                end
                // Gates built by hand must match the operator exactly.
                if ({c_beh, s_beh} !== {c_rip, s_rip}) begin
                    $display("  FAIL ripple vs behavioural a=%h b=%h cin=%b",
                             a, b, cin);
                    errors = errors + 1;
                end
            end

        // ---- mux: all 512 combinations ------------------------------------
        for (i = 0; i < 16; i = i + 1)
          for (j = 0; j < 16; j = j + 1)
            for (k = 0; k < 2; k = k + 1) begin
                d0 = i[3:0]; d1 = j[3:0]; msel = k[0]; #1;
                checks = checks + 1;
                if (my !== (msel ? d1 : d0)) fail("mux2 selected wrong input");
            end

        if (errors == 0) $display("PASS: %0d checks, all exhaustive", checks);
        else             $display("FAIL: %0d of %0d checks wrong", errors, checks);
        $finish;
    end
endmodule
