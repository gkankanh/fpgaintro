`timescale 1ns/1ps
// Testbench for exercise 4. See ex4_lut_boundary.v.
module tb_ex4;
    reg a, b, c, d, e;
    wire y4, y5, yugly;
    integer i;

    f4      u4    (.a(a), .b(b), .c(c), .d(d), .y(y4));
    f5      u5    (.a(a), .b(b), .c(c), .d(d), .e(e), .y(y5));
    f4_ugly uugly (.a(a), .b(b), .c(c), .d(d), .y(yugly));

    integer errors = 0;
    initial begin
        // Exhaustive over 5 inputs: 32 cases.
        for (i = 0; i < 32; i = i + 1) begin
            a = i[0]; b = i[1]; c = i[2]; d = i[3]; e = i[4]; #1;
            if (y4    !== ((a & b) | (c ^ d)))                  errors = errors + 1;
            if (y5    !== ((a & b) | (c ^ d) | (e & ~a)))       errors = errors + 1;
            if (yugly !== (((a ^ b) & (c | ~d)) | (~a & b & c & d) | (a & ~b & ~c)))
                errors = errors + 1;
        end
        if (errors == 0)
            $display("PASS: all 3 functions correct over 32 cases — now compare their LUT counts");
        else
            $display("FAIL: %0d mismatches", errors);
        $finish;
    end
endmodule
