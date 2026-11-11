`timescale 1ns/1ps
// Lesson 13 — byte and halfword access, which is most of what makes loads and
// stores fiddly.
//
// Memory here is 32 bits wide, because the CPU is. But RV32I has LB, LH, LW,
// LBU, LHU, SB, SH and SW -- so a byte store must change one byte of a word
// and leave the other three alone, and a byte load must pick one byte out and
// sign- or zero-extend it.
//
// The low two bits of the address select which byte. They are NOT part of the
// word address, which is why the memory is indexed by addr[n:2] throughout.
//
// This module is pure combinational plumbing: no state, no decisions beyond
// "which bytes" and "extend how". It is separated out because mixing it into
// the CPU's datapath makes both harder to read.

// What to write: produce the 32-bit word and the per-byte write enables.
module store_align (
    input  wire [1:0]  addr_lo,     // addr[1:0]
    input  wire [2:0]  funct3,      // 000=SB, 001=SH, 010=SW
    input  wire [31:0] wdata,       // the register value, right-aligned
    output reg  [31:0] mem_wdata,   // shifted into position
    output reg  [3:0]  mem_be       // which bytes to actually write
);
    always @(*)
        case (funct3)
            3'b000: begin                               // SB
                mem_wdata = {4{wdata[7:0]}};            // replicate; be picks
                mem_be    = 4'b0001 << addr_lo;
            end
            3'b001: begin                               // SH
                mem_wdata = {2{wdata[15:0]}};
                mem_be    = addr_lo[1] ? 4'b1100 : 4'b0011;
            end
            3'b010: begin                               // SW
                mem_wdata = wdata;
                mem_be    = 4'b1111;
            end
            default: begin
                mem_wdata = wdata;
                mem_be    = 4'b0000;                    // write nothing
            end
        endcase
endmodule


// What was read: select the byte or halfword and extend it.
//
// The extension is the interesting part. LB sign-extends and LBU zero-extends,
// which is why RV32I needs both: C's `char` may be either, and a compiler must
// be able to ask for exactly one.
module load_align (
    input  wire [1:0]  addr_lo,
    input  wire [2:0]  funct3,      // 000=LB 001=LH 010=LW 100=LBU 101=LHU
    input  wire [31:0] mem_rdata,
    output reg  [31:0] rdata
);
    reg [7:0]  byte_sel;
    reg [15:0] half_sel;

    always @(*) begin
        case (addr_lo)
            2'd0: byte_sel = mem_rdata[7:0];
            2'd1: byte_sel = mem_rdata[15:8];
            2'd2: byte_sel = mem_rdata[23:16];
            2'd3: byte_sel = mem_rdata[31:24];
        endcase
        half_sel = addr_lo[1] ? mem_rdata[31:16] : mem_rdata[15:0];

        case (funct3)
            3'b000: rdata = {{24{byte_sel[7]}},  byte_sel};   // LB  signed
            3'b001: rdata = {{16{half_sel[15]}}, half_sel};   // LH  signed
            3'b010: rdata = mem_rdata;                        // LW
            3'b100: rdata = {24'd0, byte_sel};                // LBU zero
            3'b101: rdata = {16'd0, half_sel};                // LHU zero
            default: rdata = mem_rdata;
        endcase
    end
endmodule
