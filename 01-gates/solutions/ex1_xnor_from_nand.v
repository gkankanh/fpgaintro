// Exercise 1 — XNOR from NAND alone.
//
// XOR takes four NANDs; XNOR is XOR followed by a NOT, and a NOT is one more
// NAND, so five. There is no four-NAND XNOR.
//
//   nab = NAND(a, b)
//   w1  = NAND(a, nab)
//   w2  = NAND(b, nab)
//   xor = NAND(w1, w2)
//   xnor = NAND(xor, xor)      <- the fifth
module ex1 (
    input  wire a,
    input  wire b,
    output wire y_xnor,         // direct, for comparison
    output wire n_xnor          // five NANDs
);
    assign y_xnor = ~(a ^ b);

    wire nab = ~(a & b);
    wire w1  = ~(a & nab);
    wire w2  = ~(b & nab);
    wire xo  = ~(w1 & w2);      // this is XOR
    assign n_xnor = ~(xo & xo); // NOT of it

endmodule

module tb_ex1;
    reg a, b;
    wire y, n;
    ex1 dut (.a(a), .b(b), .y_xnor(y), .n_xnor(n));

    integer i, errors = 0;
    initial begin
        for (i = 0; i < 4; i = i + 1) begin
            a = i[0]; b = i[1]; #1;
            if (n !== y) begin
                errors = errors + 1;
                $display("  FAIL a=%b b=%b  nand-built=%b direct=%b", a, b, n, y);
            end
        end
        if (errors == 0) $display("PASS: 5-NAND XNOR matches ~(a^b) for all 4 inputs");
        else             $display("FAIL: %0d of 4 wrong", errors);
        $finish;
    end
endmodule
