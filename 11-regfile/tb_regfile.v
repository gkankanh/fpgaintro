`timescale 1ns/1ps
// Lesson 11 testbench.
//
// A register file is small enough that the input space is nearly tractable
// again -- 32 addresses, not 2**32 values -- so the tests can be close to
// exhaustive over the thing that matters: WHICH register, not which value.
//
//   1. every register stores and returns, read from BOTH ports
//   2. the two read ports are genuinely independent
//   3. x0 reads as zero no matter what is written to it
//   4. a write to x0 does not disturb any other register
//   5. in the same cycle, a read of the register being written returns the
//      OLD value -- correct for a single-cycle CPU, and worth pinning down
//   6. the BRAM variant agrees, allowing for its one cycle of latency
//
// Test 5 is the one people get wrong in both directions: some expect a bypass
// that should not be there, others do not notice when it is missing.
module tb_regfile;
    localparam W = 32, N = 32, AW = 5;

    reg clk = 0;
    always #20 clk = ~clk;

    integer errors = 0, checks = 0;

    task fail(input [8*52-1:0] what);
    begin
        errors = errors + 1;
        $display("  FAIL %0s", what);
    end
    endtask

    // ------------------------------------------------------- the real one ---
    reg  [AW-1:0] rs1 = 0, rs2 = 0, rd = 0;
    reg           we = 0;
    reg  [W-1:0]  wdata = 0;
    wire [W-1:0]  rd1, rd2;

    regfile #(.W(W), .N(N)) u_rf (
        .clk(clk), .rs1(rs1), .rs2(rs2), .rd1(rd1), .rd2(rd2),
        .we(we), .rd(rd), .wdata(wdata));

    // ----------------------------------------------------- the BRAM one -----
    wire [W-1:0] brd1, brd2;
    regfile_bram #(.W(W), .N(N)) u_bram (
        .clk(clk), .rs1(rs1), .rs2(rs2), .rd1(brd1), .rd2(brd2),
        .we(we), .rd(rd), .wdata(wdata));

    // Write one register.
    task write(input [AW-1:0] a, input [W-1:0] d);
    begin
        @(negedge clk); rd = a; wdata = d; we = 1;
        @(negedge clk); we = 0;
    end
    endtask

    // A distinctive value per register, so a cross-wired address shows up.
    function [W-1:0] val(input [AW-1:0] a);
        val = {~a, a, 6'b101010, a, a, 6'b010101};
    endfunction

    integer i, j;

    initial begin
        $dumpfile("regfile.vcd");
        $dumpvars(0, tb_regfile);

        // ===== 1. fill every register, then read every one from both ports ==
        for (i = 1; i < N; i = i + 1)
            write(i[AW-1:0], val(i[AW-1:0]));

        for (i = 1; i < N; i = i + 1) begin
            @(negedge clk); rs1 = i[AW-1:0]; rs2 = i[AW-1:0]; #1;
            checks = checks + 2;
            if (rd1 !== val(i[AW-1:0])) begin
                errors = errors + 1;
                $display("  FAIL port 1, x%0d: got %h want %h",
                         i, rd1, val(i[AW-1:0]));
            end
            if (rd2 !== val(i[AW-1:0])) begin
                errors = errors + 1;
                $display("  FAIL port 2, x%0d: got %h want %h",
                         i, rd2, val(i[AW-1:0]));
            end
        end

        // ===== 2. the two ports are independent =============================
        // Every pair of distinct registers, read simultaneously. 31 x 31 is
        // 961 combinations -- small enough to simply do all of them, which is
        // what catches a port that quietly shares an address decoder.
        for (i = 1; i < N; i = i + 1)
          for (j = 1; j < N; j = j + 1) begin
            @(negedge clk); rs1 = i[AW-1:0]; rs2 = j[AW-1:0]; #1;
            checks = checks + 1;
            if (rd1 !== val(i[AW-1:0]) || rd2 !== val(j[AW-1:0])) begin
                errors = errors + 1;
                if (errors <= 8)
                    $display("  FAIL ports x%0d/x%0d: got %h/%h want %h/%h",
                             i, j, rd1, rd2, val(i[AW-1:0]), val(j[AW-1:0]));
            end
          end

        // ===== 3. x0 reads as zero, whatever is written to it ===============
        write(5'd0, 32'hDEAD_BEEF);
        @(negedge clk); rs1 = 5'd0; rs2 = 5'd0; #1;
        checks = checks + 2;
        if (rd1 !== 32'd0) fail("x0 did not read as zero on port 1");
        if (rd2 !== 32'd0) fail("x0 did not read as zero on port 2");

        write(5'd0, 32'hFFFF_FFFF);
        @(negedge clk); rs1 = 5'd0; #1;
        checks = checks + 1;
        if (rd1 !== 32'd0) fail("x0 stopped reading as zero after a second write");

        // ===== 4. writing x0 disturbs nothing else ==========================
        // The failure this catches: an implementation that stores to regs[0]
        // and masks it only on the read path still works -- until something
        // relies on regs[] being untouched. More usefully, it catches an
        // address decoder that aliases x0 onto another register.
        for (i = 1; i < N; i = i + 1) begin
            @(negedge clk); rs1 = i[AW-1:0]; #1;
            checks = checks + 1;
            if (rd1 !== val(i[AW-1:0])) begin
                errors = errors + 1;
                $display("  FAIL x%0d was disturbed by a write to x0", i);
            end
        end

        // ===== 5. read-during-write returns the OLD value ===================
        // This is what a single-cycle CPU requires: an instruction reads its
        // operands as they were BEFORE it executed. Assert it explicitly so
        // that adding a bypass later is a visible, deliberate change rather
        // than something that quietly alters CPU semantics.
        write(5'd7, 32'hAAAA_0000);
        @(negedge clk);
        rs1 = 5'd7; rd = 5'd7; wdata = 32'hBBBB_1111; we = 1;
        #1;
        checks = checks + 1;
        if (rd1 !== 32'hAAAA_0000)
            fail("read-during-write returned the NEW value; a single-cycle CPU needs the old one");
        @(negedge clk); we = 0;
        // ...and the next cycle sees the new value.
        #1;
        checks = checks + 1;
        if (rd1 !== 32'hBBBB_1111)
            fail("the written value did not appear on the following cycle");

        // ===== 6. the BRAM variant agrees, one cycle later ==================
        // Same stimulus, read a cycle later. This is the whole cost of block
        // RAM in a register file, made concrete.
        write(5'd9, 32'h1234_5678);
        @(negedge clk); rs1 = 5'd9; rs2 = 5'd9;
        @(posedge clk); #1;                     // one cycle of latency
        checks = checks + 2;
        if (brd1 !== 32'h1234_5678) fail("BRAM regfile port 1 wrong after its latency");
        if (brd2 !== 32'h1234_5678) fail("BRAM regfile port 2 wrong after its latency");

        // And its x0 still reads zero, which needed the address to be
        // registered too -- latency makes everything one step more awkward.
        @(negedge clk); rs1 = 5'd0;
        @(posedge clk); #1;
        checks = checks + 1;
        if (brd1 !== 32'd0) fail("BRAM regfile x0 did not read as zero");

        if (errors == 0)
            $display("PASS: %0d checks - all 31 registers from both ports, all 961 port pairs, x0 reads zero and absorbs writes, read-during-write gives the old value, BRAM variant agrees one cycle late", checks);
        else
            $display("FAIL: %0d of %0d checks wrong", errors, checks);
        $finish;
    end
endmodule
