`timescale 1ns/1ps
// Lesson 02 — a 7-segment hex decoder, written two ways.
//
// Segment naming is the universal convention:
//
//        aaaa          seg[6] = a   top
//       f    b         seg[5] = b   top right
//       f    b         seg[4] = c   bottom right
//        gggg          seg[3] = d   bottom
//       e    c         seg[2] = e   bottom left
//       e    c         seg[1] = f   top left
//        dddd          seg[0] = g   middle
//
// Active high: a 1 lights the segment. (Real displays are often common-anode
// and want the inverse; that is one `~` at the pin, not a design change.)
//
// The ULX3S has no 7-segment display, so the board demo shows the seven
// segment bits on seven LEDs. Unsatisfying to look at, but the decoder is the
// canonical combinational exercise and it is exhaustively testable: 16 inputs,
// 16 outputs, no excuses.

// Version 1: a case statement. This is how you should write it.
module seg7 (
    input  wire [3:0] hex,
    output reg  [6:0] seg        // `reg` only because it is assigned in
);                               // always @(*) — it is not a register
    always @(*) begin
        case (hex)
            //                   abcdefg
            4'h0: seg = 7'b1111110;
            4'h1: seg = 7'b0110000;
            4'h2: seg = 7'b1101101;
            4'h3: seg = 7'b1111001;
            4'h4: seg = 7'b0110011;
            4'h5: seg = 7'b1011011;
            4'h6: seg = 7'b1011111;
            4'h7: seg = 7'b1110000;
            4'h8: seg = 7'b1111111;
            4'h9: seg = 7'b1111011;
            4'hA: seg = 7'b1110111;
            4'hB: seg = 7'b0011111;   // lowercase b: 8 and B would be identical
            4'hC: seg = 7'b1001110;
            4'hD: seg = 7'b0111101;   // lowercase d, for the same reason
            4'hE: seg = 7'b1001111;
            4'hF: seg = 7'b1000111;
            // Every one of the 16 cases is covered, so this `default` can
            // never fire. It is here anyway, because a combinational `always`
            // block that does not assign on every path infers a LATCH — a
            // storage element with no clock, which is almost never what you
            // meant. Make the default a reflex; `make lint` will tell you when
            // you forget.
            default: seg = 7'b0000000;
        endcase
    end
endmodule


// Version 2: the same truth table as a ROM, indexed instead of matched.
//
// Identical behaviour — the testbench checks both against the same expected
// values and against each other. The interesting question is whether they cost
// the same, which `make synth` answers. (They do: yosys builds a truth table
// either way. The `case` is not "logic" and the array is not "memory"; both are
// descriptions of a function, and only the function survives. Lesson 01's point
// again, one level up.)
module seg7_rom (
    input  wire [3:0] hex,
    output wire [6:0] seg
);
    reg [6:0] table_rom [0:15];
    initial begin
        table_rom[ 0] = 7'b1111110;  table_rom[ 1] = 7'b0110000;
        table_rom[ 2] = 7'b1101101;  table_rom[ 3] = 7'b1111001;
        table_rom[ 4] = 7'b0110011;  table_rom[ 5] = 7'b1011011;
        table_rom[ 6] = 7'b1011111;  table_rom[ 7] = 7'b1110000;
        table_rom[ 8] = 7'b1111111;  table_rom[ 9] = 7'b1111011;
        table_rom[10] = 7'b1110111;  table_rom[11] = 7'b0011111;
        table_rom[12] = 7'b1001110;  table_rom[13] = 7'b0111101;
        table_rom[14] = 7'b1001111;  table_rom[15] = 7'b1000111;
    end
    assign seg = table_rom[hex];
endmodule
