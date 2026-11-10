`timescale 1ns/1ps
// Testbench for lesson 01.
//
// A two-input gate has exactly four possible inputs, so there is no need to
// choose test cases: check all of them. This is the last lesson where
// exhaustive testing is this easy, and lesson 02 is the last where it is
// possible at all.
//
// Two things are checked for every input combination:
//   1. each gate against its truth table, written out by hand
//   2. each NAND-only construction against the direct version
module tb_gates;
    reg a, b;

    wire y_and, y_or, y_not, y_nand, y_nor, y_xor, y_xnor;
    wire n_not, n_and, n_or, n_xor;

    gates dut (
        .a(a), .b(b),
        .y_and(y_and), .y_or(y_or), .y_not(y_not), .y_nand(y_nand),
        .y_nor(y_nor), .y_xor(y_xor), .y_xnor(y_xnor),
        .n_not(n_not), .n_and(n_and), .n_or(n_or), .n_xor(n_xor)
    );

    integer errors = 0;
    integer checks = 0;

    // Compare one output against its expected value and report precisely.
    // `!==` rather than `!=` so that x and z count as failures instead of
    // quietly comparing as unknown.
    task check(input [8*8-1:0] name, input got, input want);
    begin
        checks = checks + 1;
        if (got !== want) begin
            errors = errors + 1;
            $display("  FAIL a=%b b=%b  %0s = %b, expected %b",
                     a, b, name, got, want);
        end
    end
    endtask

    integer i;
    initial begin
        $dumpfile("gates.vcd");
        $dumpvars(0, tb_gates);

        for (i = 0; i < 4; i = i + 1) begin
            a = i[0];
            b = i[1];
            #1;                       // let the combinational logic settle

            // ---- truth tables, written out rather than computed -----------
            check("and",  y_and,  (a == 1 && b == 1) ? 1'b1 : 1'b0);
            check("or",   y_or,   (a == 1 || b == 1) ? 1'b1 : 1'b0);
            check("not",  y_not,  (a == 0)           ? 1'b1 : 1'b0);
            check("nand", y_nand, (a == 1 && b == 1) ? 1'b0 : 1'b1);
            check("nor",  y_nor,  (a == 0 && b == 0) ? 1'b1 : 1'b0);
            check("xor",  y_xor,  (a != b)           ? 1'b1 : 1'b0);
            check("xnor", y_xnor, (a == b)           ? 1'b1 : 1'b0);

            // ---- NAND-only constructions must match the direct versions ---
            check("n_not", n_not, y_not);
            check("n_and", n_and, y_and);
            check("n_or",  n_or,  y_or);
            check("n_xor", n_xor, y_xor);
        end

        if (errors == 0) $display("PASS: %0d checks over all 4 input combinations", checks);
        else             $display("FAIL: %0d of %0d checks wrong", errors, checks);
        $finish;
    end
endmodule
