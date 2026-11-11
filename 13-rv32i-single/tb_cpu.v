`timescale 1ns/1ps
// ===========================================================================
//  Lesson 13 testbench — run a program, check what it wrote.
//
//  The CPU is tested THROUGH ITS ARCHITECTURAL INTERFACE. The program stores
//  every result to a known address and the testbench reads data memory; it
//  never reaches into the register file. So a core that computes correctly but
//  stores wrongly fails, which is the right outcome -- software cannot tell
//  the difference between those two faults either.
//
//  The program is test.s, assembled by tools/rvasm.py into test.hex.
// ===========================================================================
module tb_cpu;
    reg clk = 0;
    always #20 clk = ~clk;

    reg         rst = 1;
    reg  [31:0] peek_addr = 0;
    wire [31:0] peek_data;
    wire [31:0] pc;
    wire        illegal;

    cpu_sys #(.IMEM_WORDS(256), .DMEM_WORDS(256), .PROGRAM("test.hex")) u_sys (
        .clk(clk), .rst(rst),
        .pc_out(pc), .illegal_out(illegal),
        .peek_addr(peek_addr), .peek_data(peek_data));

    integer errors = 0, checks = 0;

    // `illegal` must NEVER assert: every instruction in test.s is valid, and
    // the core halts rather than executing an unrecognised word, so a single
    // assertion would stop the program dead.
    integer illegal_seen = 0;
    always @(posedge clk)
        if (illegal && !rst) illegal_seen = illegal_seen + 1;

    task expect(input [31:0] addr, input [31:0] want, input [8*28-1:0] what);
    begin
        peek_addr = addr; #1;
        checks = checks + 1;
        if (peek_data !== want) begin
            errors = errors + 1;
            $display("  FAIL [%03h] %0s: got %h, expected %h",
                     addr, what, peek_data, want);
        end
    end
    endtask

    integer cycles;

    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(0, tb_cpu);

        repeat (3) @(posedge clk);
        @(negedge clk); rst = 0;

        // Run until the program sets its done flag, or give up. 88
        // instructions with a 10-iteration loop is a few hundred cycles; the
        // limit is generous so a real hang is distinguishable from slowness.
        cycles = 0;
        peek_addr = 32'h1FC;
        while (peek_data !== 32'd1 && cycles < 20000) begin
            @(posedge clk);
            cycles = cycles + 1;
            #1;
        end

        if (cycles >= 20000) begin
            $display("  FAIL program never set its done flag (pc = %h)", pc);
            errors = errors + 1;
        end else
            $display("  program finished in %0d cycles, pc = %h", cycles, pc);

        if (illegal_seen != 0) begin
            $display("  FAIL illegal asserted %0d times", illegal_seen);
            errors = errors + 1;
        end

        // The `bad` path writes 0xBAD. Memory starts as X, so check it is not
        // that value rather than checking it is zero -- lesson 08's point
        // about uninitialised memory.
        peek_addr = 32'h1F8; #1;
        checks = checks + 1;
        if (peek_data === 32'hBAD) begin
            $display("  FAIL program took a branch it should not have");
            errors = errors + 1;
        end

        // ---- arithmetic ----------------------------------------------------
        expect(32'h100, 32'd13,        "add 10+3");
        expect(32'h104, 32'd7,         "sub 10-3");
        expect(32'h108, 32'd9,         "addi -1  (the trap)");
        expect(32'h10c, 32'hFFFFF800,  "addi -2048");

        // ---- logic ---------------------------------------------------------
        expect(32'h110, 32'h000000F0,  "and");
        expect(32'h114, 32'h0000FFF0,  "or");
        expect(32'h118, 32'h0000FF00,  "xor");

        // ---- shifts --------------------------------------------------------
        expect(32'h11c, 32'hFFFFFFFC,  "srai -16>>2 = -4");
        expect(32'h120, 32'h0000000F,  "srli -16>>>28 logical");
        expect(32'h124, 32'h0000FF00,  "slli");

        // ---- comparison ----------------------------------------------------
        expect(32'h128, 32'd1,         "slt  -1 < 1 signed");
        expect(32'h12c, 32'd0,         "sltu -1 < 1 unsigned");

        // ---- byte and halfword memory --------------------------------------
        expect(32'h130, 32'h00000078,  "lb  low byte");
        expect(32'h134, 32'h00000012,  "lbu high byte");
        expect(32'h138, 32'h00001234,  "lh  upper half");
        expect(32'h13c, 32'h1234FF78,  "sb  patched one byte");
        expect(32'h140, 32'hFFFFFF80,  "lb  sign-extended");
        expect(32'h144, 32'h00000080,  "lbu zero-extended");

        // ---- control flow ---------------------------------------------------
        expect(32'h148, 32'd55,        "loop sum 1..10");
        expect(32'h14c, 32'd99,        "jal/ret return value");
        expect(32'h150, 32'd1,         "branches not taken");
        expect(32'h154, 32'hABCDE000,  "lui");
        expect(32'h158, 32'h00005A5A,  "jalr through a register");

        if (errors == 0)
            $display("PASS: %0d checks - the CPU ran %0d instructions of RV32I and every result is correct",
                     checks, 88);
        else
            $display("FAIL: %0d of %0d checks wrong", errors, checks);
        $finish;
    end
endmodule
