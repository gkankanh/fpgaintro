// Board wrapper: two buttons in, eight LEDs out.
//
// btn[1] and btn[2] are FIRE1 and FIRE2, active high with pull-downs, so no
// inversion is needed. They are not debounced — and they do not need to be,
// because nothing here is clocked. Bounce on a combinational input produces a
// flickering LED, not a wrong answer. That changes in lesson 03.
// Only btn[2:1] is declared. The board has seven buttons, but declaring bits
// you never read is how you teach a linter to cry wolf — and `make lint` is
// only useful while it stays quiet.
module gates_top (
    input  wire [2:1] btn,
    output wire [7:0] led
);
    wire a = btn[1];
    wire b = btn[2];

    wire y_and, y_or, y_not, y_nand, y_nor, y_xor, y_xnor;
    wire n_not, n_and, n_or, n_xor;

    gates u_gates (
        .a(a), .b(b),
        .y_and(y_and), .y_or(y_or), .y_not(y_not), .y_nand(y_nand),
        .y_nor(y_nor), .y_xor(y_xor), .y_xnor(y_xnor),
        .n_not(n_not), .n_and(n_and), .n_or(n_or), .n_xor(n_xor)
    );

    // Seven LEDs show the gates directly. led[0] is an equivalence check: it
    // lights only while all four NAND-only constructions agree with their
    // direct counterparts. Press any combination of the two buttons and it
    // stays lit — NAND universality, demonstrated on hardware rather than
    // asserted in a textbook.
    wire agree = (n_not === y_not) && (n_and === y_and)
              && (n_or  === y_or ) && (n_xor === y_xor);

    assign led = { y_and, y_or, y_not, y_nand, y_nor, y_xnor, y_xor, agree };
endmodule
