// Exercise 4 — where the LUT boundary is.
//
// A LUT4 can implement ANY function of up to four inputs, so:
//
//   f4 = (a & b) | (c ^ d)                   -> 1 LUT4
//   f5 = (a & b) | (c ^ d) | (e & ~a)        -> more than 1
//
// The jump is at five inputs, and it is not gradual: four inputs is one LUT
// regardless of how complicated the function is, and five inputs needs at
// least two LUTs no matter how simple it is. The ECP5 helps a little here —
// two LUT4s in a slice share a mux (the PFUMX) that can build a 5-input
// function from them — so the real cost of f5 is two LUT4s plus that mux.
//
// Check it yourself (the testbench is in a separate file precisely so that
// yosys can read this one without hitting its $finish):
//   yosys -p "read_verilog ex4_lut_boundary.v; synth_ecp5 -top f4; stat"
//   yosys -p "read_verilog ex4_lut_boundary.v; synth_ecp5 -top f5; stat"
//   yosys -p "read_verilog ex4_lut_boundary.v; synth_ecp5 -top f4_ugly; stat"
//
// The lesson: count INPUTS, not operators. "Simplifying" a 4-input expression
// from five operators to three saves nothing at all.
module f4 (
    input  wire a, b, c, d,
    output wire y
);
    assign y = (a & b) | (c ^ d);
endmodule

module f5 (
    input  wire a, b, c, d, e,
    output wire y
);
    assign y = (a & b) | (c ^ d) | (e & ~a);
endmodule

// A deliberately baroque 4-input function, to make the point that complexity
// within four inputs is free.
module f4_ugly (
    input  wire a, b, c, d,
    output wire y
);
    assign y = ((a ^ b) & (c | ~d)) | (~a & b & c & d) | (a & ~b & ~c);
endmodule
