`timescale 1ns/1ps
// ===========================================================================
//  Lesson 17 — the machine timer: an interrupt that comes from nowhere.
//
//  Every exception so far has been caused by an instruction. This is not.
//  `mtip` goes high because TIME PASSED, and that is the entire difference
//  between an exception and an interrupt.
//
//  The RISC-V specification puts the timer in memory, not in CSRs, and the
//  reason is worth knowing: mtime belongs to the PLATFORM rather than to the
//  hart. One clock, several harts, each with its own mtimecmp -- so the
//  comparison values are per-hart registers at platform addresses, and the
//  time itself is one shared counter. A single-core machine does not need
//  that arrangement and follows it anyway, because software written for the
//  arrangement is software that runs here.
//
//      0x8000_0040  MTIME      low 32 bits, read/write
//      0x8000_0044  MTIMEH     high 32
//      0x8000_0048  MTIMECMP   low 32 bits, read/write
//      0x8000_004C  MTIMECMPH  high 32
//
//  mtip = (mtime >= mtimecmp), continuously. Note what that means: the
//  interrupt is a LEVEL, not an event. It stays asserted until software moves
//  mtimecmp forward, which is why a handler that forgets to re-arm the timer
//  is re-entered immediately and forever -- the classic first bug with this
//  peripheral, and one you will meet in the exercises.
//
//  WHY mtime IS 64 BITS. At 36 MHz a 32-bit counter wraps in two minutes. A
//  comparison against a wrapping counter is a bug waiting for an uptime; 64
//  bits at 36 MHz wraps in sixteen thousand years, and the specification
//  chose that rather than make every operating system think about it.
//
//  WHAT THIS MACHINE GETS WRONG, deliberately and in one respect: mtime here
//  counts CPU CYCLES. On a real platform it counts a fixed-frequency tick, so
//  that a second is a second no matter what the processor clock is doing. Here
//  the CPU clock is the only clock there is, so a program that wants
//  milliseconds has to know the clock frequency -- which is why soc.h has it
//  as a constant, and why that constant is a lie waiting to happen if the PLL
//  is ever changed.
// ===========================================================================
module timer (
    input  wire        clk,
    input  wire        rst,

    input  wire [7:0]  addr,          // byte offset within the I/O window
    input  wire        we,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,

    output wire        mtip
);
    reg [63:0] mtime    = 64'd0;
    // All ones, so that a machine that never arms the timer never takes a
    // timer interrupt. Zero would mean "the deadline passed before reset".
    reg [63:0] mtimecmp = {64{1'b1}};

    wire [1:0] reg_i = addr[3:2];

    localparam [1:0] R_TIME = 2'd0, R_TIMEH = 2'd1, R_CMP = 2'd2, R_CMPH = 2'd3;

    assign mtip = (mtime >= mtimecmp);

    always @(posedge clk)
        if (rst) begin
            mtime    <= 64'd0;
            mtimecmp <= {64{1'b1}};
        end else begin
            mtime <= mtime + 64'd1;

            if (we)
                case (reg_i)
                    // Writing mtime is allowed by the specification and is
                    // how a platform sets the clock. The increment above is
                    // overridden by this, which is the whole reason it is
                    // written as a separate statement first.
                    R_TIME:  mtime[31:0]     <= wdata;
                    R_TIMEH: mtime[63:32]    <= wdata;
                    R_CMP:   mtimecmp[31:0]  <= wdata;
                    R_CMPH:  mtimecmp[63:32] <= wdata;
                endcase
        end

    always @(*)
        case (reg_i)
            R_TIME:  rdata = mtime[31:0];
            R_TIMEH: rdata = mtime[63:32];
            R_CMP:   rdata = mtimecmp[31:0];
            R_CMPH:  rdata = mtimecmp[63:32];
        endcase

    wire _unused = &{addr[7:4], addr[1:0], 1'b0};
endmodule
