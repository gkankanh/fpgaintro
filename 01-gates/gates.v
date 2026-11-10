// Lesson 01 — logic gates.
//
// Every two-input gate, plus NAND-only equivalents of four of them. Pure
// combinational logic — there is no clock anywhere in this file.
//
// The board wrapper lives in gates_top.v.
//
// The point of the NAND-only versions is not that you would ever write them.
// It is that `make synth` reports the same cost for both, because this FPGA
// has no gates — only 4-input lookup tables.

module gates (
    input  wire a,
    input  wire b,
    // the gates, written directly
    output wire y_and,
    output wire y_or,
    output wire y_not,      // of `a` only
    output wire y_nand,
    output wire y_nor,
    output wire y_xor,
    output wire y_xnor,
    // the same functions, built from NAND alone
    output wire n_not,
    output wire n_and,
    output wire n_or,
    output wire n_xor
);
    // ---------------------------------------------------------------- direct
    // `assign` is not a statement that runs. It is a permanent connection:
    // whenever `a` or `b` changes, the output follows. There is no "when".
    assign y_and  =   a & b;
    assign y_or   =   a | b;
    assign y_not  =  ~a;
    assign y_nand = ~(a & b);
    assign y_nor  = ~(a | b);
    assign y_xor  =   a ^ b;
    assign y_xnor = ~(a ^ b);

    // ------------------------------------------------------- NAND-only forms
    // NAND is a universal gate: every Boolean function can be built from it
    // alone. Four constructions, each one line, each verified by the
    // testbench against the direct version above.

    wire nab = ~(a & b);                 // the shared NAND(a, b)

    // NOT a = NAND(a, a): both inputs the same, so the AND is just `a`.
    assign n_not = ~(a & a);

    // AND = NOT(NAND) = NAND(NAND(a,b), NAND(a,b)).
    assign n_and = ~(nab & nab);

    // OR = NAND(NOT a, NOT b). This is De Morgan:  a | b  ==  ~(~a & ~b).
    wire na = ~(a & a);
    wire nb = ~(b & b);
    assign n_or = ~(na & nb);

    // XOR from four NANDs — the classic construction.
    //   w1 = NAND(a, NAND(a,b))   is 1 unless a=1 and b=0
    //   w2 = NAND(b, NAND(a,b))   is 1 unless b=1 and a=0
    //   XOR = NAND(w1, w2)
    wire w1 = ~(a & nab);
    wire w2 = ~(b & nab);
    assign n_xor = ~(w1 & w2);
endmodule
