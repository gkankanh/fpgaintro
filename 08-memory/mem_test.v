`timescale 1ns/1ps
// Lesson 08 — a memory self-test, on hardware.
//
// Simulation proves the Verilog. It does not prove that the bits yosys placed
// in a DP16KD actually store and return what you wrote on real silicon. This
// is the hardware equivalent of a power-on memory test: walk every address
// writing a pattern, walk every address reading it back, and report.
//
// It is also an FSM from lesson 05 driving a memory from lesson 08, which is
// the shape of every memory controller you will ever meet.
module mem_test #(
    parameter DEPTH = 1024,
    parameter W     = 32
)(
    input  wire                     clk,
    input  wire                     start,
    output reg                      busy   = 0,
    output reg                      done   = 0,
    output reg                      pass   = 0,
    output reg  [15:0]              errors = 0,
    output wire [$clog2(DEPTH)-1:0] progress
);
    localparam AW = $clog2(DEPTH);

    localparam S_IDLE       = 3'd0,
               S_WRITE      = 3'd1,
               S_READ_ISSUE = 3'd2,
               S_READ_CHECK = 3'd3,
               S_DONE       = 3'd4;

    reg [2:0]    state      = S_IDLE;
    reg [AW-1:0] addr       = 0;
    reg [AW-1:0] check_addr = 0;

    // The value every address should hold. Derived from the address rather
    // than constant, so a swapped or stuck ADDRESS line fails too: with a
    // constant pattern every location holds the same value, and reading the
    // wrong one looks correct.
    // The value every address should hold: the address itself, XORed with a
    // fixed pattern so that an all-zero or all-ones location is never
    // "correct" by accident. Width-exact for any W that is a multiple of 4.
    //
    // Deriving the data from the ADDRESS is the important part. With a
    // constant pattern every location holds the same value, so reading the
    // wrong address looks correct and an addressing fault passes the test.
    //
    // (This started as `{a, ~a, a, ~a}`, which at AW=10 is 40 bits assigned to
    // a 32-bit result -- a silent truncation. The test still passed, because
    // the pattern was at least deterministic. `make lint` caught it, which is
    // the argument for keeping lint quiet enough to be worth reading.)
    localparam [W-1:0]  SALT = {(W/4){4'hA}};

    // The last address, sized to the address width. Comparing against a bare
    // `DEPTH-1` works, but it is a 32-bit integer against a 10-bit signal and
    // the linter rightly objects. The SystemVerilog cast `AW'(DEPTH-1)` is
    // rejected by iverilog -g2005, which is what this course targets. A sized
    // localparam is the Verilog-2005 answer and reads better anyway.
    //
    // (Side note worth knowing: a comment line that BEGINS with the word
    // "verilator" is treated as a lint pragma, and an unrecognised one is a
    // hard error. Mentioning the tool mid-sentence, as above, is fine.)
    // Truncated EXPLICITLY. `localparam [AW-1:0] LAST = DEPTH - 1;` is a
    // 32-bit value assigned to AW bits, and the linter is right to flag it
    // even though the intent is obvious -- that is the same class of silent
    // narrowing that lesson 02 warned about. Widening then slicing says what
    // is meant.
    localparam [31:0]   LAST32 = DEPTH - 1;
    localparam [AW-1:0] LAST   = LAST32[AW-1:0];

    function [W-1:0] expected(input [AW-1:0] a);
        expected = {{(W-AW){1'b0}}, a} ^ SALT;
    endfunction

    // --- the memory under test ---------------------------------------------
    //
    // `we` and `din` are COMBINATIONAL from state and addr, deliberately.
    //
    // An earlier version registered the write data -- `din <= expected(addr)`
    // inside the clocked block -- and every single location then held its
    // NEIGHBOUR's value, because by the time the RAM performed the write on
    // the following edge, `addr` had already advanced. The read-back reported
    // 128 errors out of 128.
    //
    // The rule: a memory's address, write-enable and write-data must be
    // presented in the SAME cycle. Register some and not others and they
    // arrive skewed, and the memory faithfully stores the skew.
    wire         we  = (state == S_WRITE);
    wire [W-1:0] din = expected(addr);
    wire [W-1:0] dout;

    ram_sp #(.W(W), .DEPTH(DEPTH)) u_ram (
        .clk(clk), .we(we), .addr(addr), .din(din), .dout(dout));

    assign progress = addr;

    always @(posedge clk) begin
        case (state)
            S_IDLE: if (start) begin
                state  <= S_WRITE;
                addr   <= 0;
                errors <= 0;
                busy   <= 1;
                done   <= 0;
                pass   <= 0;
            end

            // Fill: one write per clock, straight up the address space.
            S_WRITE:
                if (addr == LAST) begin
                    addr  <= 0;
                    state <= S_READ_ISSUE;
                end else
                    addr <= addr + 1'b1;

            // Read back. ram_sp's output is REGISTERED, so the data for
            // `addr` arrives the cycle AFTER addr is presented. That latency
            // is the whole reason this needs two states rather than one:
            // issue the address, then check what came back a clock later.
            // Every design that reads a block RAM pays this, and forgetting
            // it is the most common BRAM bug there is.
            S_READ_ISSUE: begin
                check_addr <= addr;
                state      <= S_READ_CHECK;
            end

            S_READ_CHECK: begin
                if (dout !== expected(check_addr))
                    errors <= errors + 1'b1;

                if (check_addr == LAST)
                    state <= S_DONE;
                else begin
                    addr  <= check_addr + 1'b1;
                    state <= S_READ_ISSUE;
                end
            end

            S_DONE: begin
                busy <= 0;
                done <= 1;
                pass <= (errors == 0);
                if (!start) state <= S_IDLE;
            end

            default: state <= S_IDLE;
        endcase
    end
endmodule
