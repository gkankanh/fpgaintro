`timescale 1ns/1ps
// ===========================================================================
//  Lesson 16 testbench — the same program, the same answers, a different
//  machine.
//
//  THE TEST IS LESSON 13'S TEST. ../13-rv32i-single/test.hex, byte for byte,
//  with the same thirty expected results. That is the point: a pipelined core
//  is not a new processor, it is the same processor rearranged, and the way
//  to say so convincingly is to run the old machine's conformance program on
//  the new machine and demand identical answers.
//
//  If forwarding is wrong, or a bubble is missing, or a branch flushes one
//  instruction too few, these checks fail -- and they fail with the name of
//  the computation that went wrong, not with a waveform to squint at.
//
//  It also measures. Lesson 13 ran this program in 109 cycles at one
//  instruction per cycle. This core issues the same instructions with
//  bubbles in between, so it takes MORE cycles and runs at a HIGHER clock,
//  and which of those wins is a question with an arithmetic answer rather
//  than an opinion.
//
//  TWO MACHINES RUN HERE, in one simulation:
//
//    A. cpu5_sys with lesson 13's conformance program -- is it still RV32I?
//    B. soc5 with lesson 15's compiled C -- is it still a computer?
//
//  They share a clock and nothing else. Both have to pass.
//
//  Reading the results: lesson 13's testbench had a `peek` port into its
//  combinational data memory. A synchronous memory would need a third port
//  for that, so this testbench reads the array directly instead. It is the
//  same architectural state -- what the program stored -- read a different
//  way, and no part of the core is reached into.
// ===========================================================================
module tb_pipe;
    reg clk = 0;
    always #20 clk = ~clk;

    reg rst = 1;

    wire [31:0] pc;
    wire        illegal, retire;

    cpu5_sys #(.IMEM_WORDS(256), .DMEM_WORDS(256),
               .PROGRAM("../13-rv32i-single/test.hex")) u_sys (
        .clk(clk), .rst(rst),
        .pc_out(pc), .illegal_out(illegal), .retire_out(retire));

    integer errors = 0, checks = 0;
    integer cycles = 0, retired = 0;

    // `illegal` must never assert: every instruction in test.s is valid.
    integer illegal_seen = 0;
    always @(posedge clk)
        if (illegal && !rst) illegal_seen = illegal_seen + 1;

    // Read a word of data memory. mem is indexed by WORD, the program
    // addresses it by BYTE.
    function [31:0] dmem(input [31:0] byte_addr);
        dmem = u_sys.u_dmem.mem[byte_addr[9:2]];
    endfunction

    task expect(input [31:0] addr, input [31:0] want, input [8*28-1:0] what);
    begin
        checks = checks + 1;
        if (dmem(addr) !== want) begin
            errors = errors + 1;
            $display("  FAIL [%03h] %0s: got %h, expected %h",
                     addr, what, dmem(addr), want);
        end
    end
    endtask

    // =====================================================================
    //  Machine B — lesson 15's SoC, with this lesson's core inside it
    // =====================================================================
    localparam CLK_HZ   = 25_000_000;
    localparam BAUD     = 2_500_000;        // ten clocks a bit, as in lesson 15
    localparam BIT_CLKS = CLK_HZ / BAUD;

    wire        soc_tx, soc_rx;
    wire [7:0]  soc_leds;
    wire [31:0] soc_pc;
    wire        soc_illegal, soc_fault, soc_halt, soc_retire;
    wire [7:0]  soc_halt_code;

    soc5 #(.MEM_WORDS(512), .FIRMWARE("../15-soc/firmware.hex"),
           .CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_soc (
        .clk(clk), .rst(rst),
        .gpo(soc_leds), .gpi(16'h0000),
        .uart_tx_pin(soc_tx), .uart_rx_pin(soc_rx),
        .pc_out(soc_pc), .illegal_out(soc_illegal), .fault_out(soc_fault),
        .halt_out(soc_halt), .halt_code(soc_halt_code),
        .retire_out(soc_retire));

    wire [7:0] got;
    wire       got_valid, got_err;

    uart_rx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_host_rx (
        .clk(clk), .rx(soc_tx),
        .data(got), .valid(got_valid), .frame_error(got_err));

    reg  send = 0;
    wire send_busy;

    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_host_tx (
        .clk(clk), .data("K"), .start(send), .tx(soc_rx), .busy(send_busy));

    // The same 107 characters lesson 15 produced. Byte for byte: the program
    // did not change, so its output may not either. (It is literally the same
    // image -- this testbench reads ../15-soc/firmware.hex -- so editing
    // lesson 15's sw/main.c changes this expectation too.)
    localparam EXPLEN = 107;
    localparam [8*EXPLEN-1:0] EXPECT =
        {"Hello world from RV32I SoC on ULX3S \ndeadbeef\nbss ok\n",
         "Waiting for a character from host\nK\nCYC ????????\nDONE\n"};

    function [7:0] expect_ch(input integer i);
        expect_ch = EXPECT[8*(EXPLEN-i)-1 -: 8];
    endfunction

    integer n = 0, soc_errors = 0;
    integer soc_cycles = 0, soc_retired = 0;
    reg     soc_running = 0, saw_a5 = 0, fault_before_marker = 0;

    always @(posedge clk) if (got_valid) begin
        if (n >= EXPLEN) begin
            $display("FAIL(soc): extra character %0d: %c", n, got);
            soc_errors = soc_errors + 1;
        end else if (expect_ch(n) !== "?" && got !== expect_ch(n)) begin
            $display("FAIL(soc): character %0d is %c, expected %c",
                     n, got, expect_ch(n));
            soc_errors = soc_errors + 1;
        end
        $write("%c", got);
        n = n + 1;
    end

    always @(posedge clk) begin
        if (got_err) begin
            $display("FAIL(soc): framing error on the receive line");
            soc_errors = soc_errors + 1;
        end
        if (soc_leds == 8'hA5) saw_a5 <= 1;
        if (soc_leds != 8'h5A) fault_before_marker <= soc_fault;
        if (soc_running && !soc_halt) begin
            soc_cycles  = soc_cycles + 1;
            soc_retired = soc_retired + (soc_retire ? 1 : 0);
        end
    end

    initial begin
        $dumpfile("pipe.vcd");
        $dumpvars(0, tb_pipe);

        repeat (3) @(posedge clk);
        @(negedge clk); rst = 0;
        soc_running = 1;

        // Run until the program sets its done flag at 0x1FC.
        while (dmem(32'h1FC) !== 32'd1 && cycles < 20000) begin
            @(posedge clk);
            #1;
            cycles  = cycles + 1;
            retired = retired + (retire ? 1 : 0);
        end

        if (cycles >= 20000) begin
            $display("  FAIL program never set its done flag (pc = %h)", pc);
            errors = errors + 1;
        end else
            $display("  program finished in %0d cycles, %0d instructions retired, pc = %h",
                     cycles, retired, pc);

        if (illegal_seen != 0) begin
            $display("  FAIL illegal asserted %0d times", illegal_seen);
            errors = errors + 1;
        end

        // The `bad` path writes 0xBAD; memory starts as X, so check it is not
        // that value rather than checking it is zero.
        checks = checks + 1;
        if (dmem(32'h1F8) === 32'hBAD) begin
            $display("  FAIL program took a branch it should not have");
            errors = errors + 1;
        end

        // ---- the thirty checks, identical to lesson 13's --------------------
        expect(32'h100, 32'd13,        "add 10+3");
        expect(32'h104, 32'd7,         "sub 10-3");
        expect(32'h108, 32'd9,         "addi -1  (the trap)");
        expect(32'h10c, 32'hFFFFF800,  "addi -2048");

        expect(32'h110, 32'h000000F0,  "and");
        expect(32'h114, 32'h0000FFF0,  "or");
        expect(32'h118, 32'h0000FF00,  "xor");

        expect(32'h11c, 32'hFFFFFFFC,  "srai -16>>2 = -4");
        expect(32'h120, 32'h0000000F,  "srli -16>>>28 logical");
        expect(32'h124, 32'h0000FF00,  "slli");

        expect(32'h128, 32'd1,         "slt  -1 < 1 signed");
        expect(32'h12c, 32'd0,         "sltu -1 < 1 unsigned");

        expect(32'h130, 32'h00000078,  "lb  low byte");
        expect(32'h134, 32'h00000012,  "lbu high byte");
        expect(32'h138, 32'h00001234,  "lh  upper half");
        expect(32'h13c, 32'h1234FF78,  "sb  patched one byte");
        expect(32'h140, 32'hFFFFFF80,  "lb  sign-extended");
        expect(32'h144, 32'h00000080,  "lbu zero-extended");

        expect(32'h148, 32'd55,        "loop sum 1..10");
        expect(32'h14c, 32'd99,        "jal/ret return value");
        expect(32'h150, 32'd1,         "branches not taken");
        expect(32'h154, 32'hABCDE000,  "lui");
        expect(32'h158, 32'h00005A5A,  "jalr through a register");

        $display("  machine A: %0d checks, %0d errors", checks, errors);

        // The host's keystroke. It goes out now -- long after machine A has
        // finished, and thousands of cycles before the C program polls for
        // it, which is the entire reason the receiver holds a byte.
        @(posedge clk);
        send <= 1;
        @(posedge clk);
        send <= 0;

        // ---- machine B: wait for the C program to halt --------------------
        begin : run_soc
            integer i;
            for (i = 0; i < 300000 && !soc_halt; i = i + 1)
                @(posedge clk);

            if (!soc_halt) begin
                $display("FAIL(soc): the program never reached HALT (pc = %h)", soc_pc);
                soc_errors = soc_errors + 1;
            end

            // The last character is still in the shift register: putchar waits
            // for the transmitter to be FREE, not for it to be finished.
            repeat (12 * BIT_CLKS) @(posedge clk);
        end

        if (n != EXPLEN) begin
            $display("FAIL(soc): %0d characters arrived, expected %0d", n, EXPLEN);
            soc_errors = soc_errors + 1;
        end
        if (soc_illegal) begin
            $display("FAIL(soc): an illegal instruction was executed");
            soc_errors = soc_errors + 1;
        end
        if (!saw_a5) begin
            $display("FAIL(soc): the program never wrote 0xA5 to the LEDs");
            soc_errors = soc_errors + 1;
        end
        if (soc_leds !== 8'h5A) begin
            $display("FAIL(soc): LEDs read 0x%02h, expected the 0x5A marker", soc_leds);
            soc_errors = soc_errors + 1;
        end
        if (soc_halt_code !== 8'h00) begin
            $display("FAIL(soc): main returned %0d", soc_halt_code);
            soc_errors = soc_errors + 1;
        end
        if (fault_before_marker) begin
            $display("FAIL(soc): the decoder reported a fault during the program");
            soc_errors = soc_errors + 1;
        end
        if (!soc_fault) begin
            $display("FAIL(soc): the store to 0x0DD00000 was not reported");
            soc_errors = soc_errors + 1;
        end

        $display("  machine B: %0d characters, %0d cycles, %0d instructions retired",
                 n, soc_cycles, soc_retired);

        $display("");
        if (errors == 0 && soc_errors == 0)
            $display("PASS: lesson 13's program gives identical results (%0d checks) and lesson 15's C runs unchanged",
                     checks);
        else
            $display("FAIL: %0d conformance errors, %0d system errors", errors, soc_errors);
        $finish;
    end
endmodule
