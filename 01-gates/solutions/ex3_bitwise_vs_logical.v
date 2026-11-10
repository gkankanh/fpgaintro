// Exercise 3 — why `&` and `&&` are not interchangeable.
//
// On one-bit signals they agree, which is why the mistake survives. On a bus
// they do not:
//
//   `&`  is BITWISE: it ANDs bit 0 with bit 0, bit 1 with bit 1, and so on,
//        producing a result as wide as its operands.
//   `&&` is LOGICAL: it asks "is the left side non-zero?" and "is the right
//        side non-zero?", and produces ONE bit.
//
// So for a = 4'b0011, b = 4'b1100:
//        a & b  = 4'b0000     (no bit position is 1 in both)
//        a && b = 1'b1        (both operands are non-zero)
//
// Assigning that single bit to a 4-bit output zero-extends it to 4'b0001,
// which is neither the right answer nor an obviously wrong one — the kind of
// bug that survives a casual look at a waveform.
module ex3 (
    input  wire [3:0] a,
    input  wire [3:0] b,
    output wire [3:0] y_bitwise,
    output wire [3:0] y_logical
);
    assign y_bitwise = a & b;      // correct for hardware
    assign y_logical = a && b;     // 1 bit, zero-extended to 4
endmodule

module tb_ex3;
    reg  [3:0] a, b;
    wire [3:0] yb, yl;
    integer differ = 0, i, j;

    ex3 dut (.a(a), .b(b), .y_bitwise(yb), .y_logical(yl));

    initial begin
        // The headline case from the comment above.
        a = 4'b0011; b = 4'b1100; #1;
        $display("a=%b b=%b   a&b=%b   a&&b=%b", a, b, yb, yl);

        // How often do they disagree across all 256 input pairs?
        for (i = 0; i < 16; i = i + 1)
          for (j = 0; j < 16; j = j + 1) begin
            a = i[3:0]; b = j[3:0]; #1;
            if (yb !== yl) differ = differ + 1;
          end

        // 256 pairs; they agree only where the bitwise AND happens to equal
        // the zero-extended logical result, which is rare.
        if (differ > 0)
            $display("PASS: the two operators disagree on %0d of 256 input pairs", differ);
        else
            $display("FAIL: expected disagreements, found none");
        $finish;
    end
endmodule
