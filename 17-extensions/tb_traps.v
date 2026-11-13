`timescale 1ns/1ps
// ===========================================================================
//  Lesson 17 testbench — a program that is interrupted, and survives.
//
//  Same shape as lesson 15's: the testbench is the host at the other end of
//  the serial cable, decoding what the machine says with lesson 09's
//  receiver. What is different is what the machine says, and why.
//
//  Every line of the expected output is a trap that was taken and returned
//  from. `E` is an ECALL, `I` is an illegal instruction the handler stepped
//  over -- which on lesson 13's core would have halted the machine dead --
//  and each `T` is a timer interrupt, caused by nothing in the instruction
//  stream at all.
//
//  The cycle and instruction counts are wildcards, because they are
//  measurements. What is checked is that the machine can count itself.
//
//  AND, AS IN LESSON 16, TWO MACHINES RUN HERE. The second one is the same
//  core with two plain memories, running lesson 13's conformance program and
//  checked against the same thirty results. decode_ext.v claims instruction
//  encodings that lesson 12's decoder used to reject, and one funct3 compared
//  too loosely would quietly redefine an ordinary instruction. The way to
//  find out is to run the old program and demand the old answers.
// ===========================================================================
module tb_traps;
    localparam CLK_HZ   = 25_000_000;
    localparam BAUD     = 2_500_000;      // ten clocks a bit, as in lesson 15
    localparam BIT_CLKS = CLK_HZ / BAUD;

    reg clk = 0;
    always #20 clk = ~clk;

    reg rst = 1;

    wire        tx_line, rx_line;
    wire [7:0]  leds;
    wire [31:0] pc, mcause;
    wire        fault, halt, trap, retire;
    wire [7:0]  halt_code;

    soc17 #(.MEM_WORDS(4096), .FIRMWARE("firmware.hex"),
            .CLK_HZ(CLK_HZ), .BAUD(BAUD)) dut (
        .clk(clk), .rst(rst),
        .gpo(leds), .gpi(16'h0000),
        .uart_tx_pin(tx_line), .uart_rx_pin(rx_line),
        .pc_out(pc), .fault_out(fault),
        .halt_out(halt), .halt_code(halt_code), .retire_out(retire),
        .trap_out(trap), .mcause_out(mcause));

    assign rx_line = 1'b1;                // nothing is typed at this machine

    wire [7:0] got;
    wire       got_valid, got_err;

    uart_rx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_host_rx (
        .clk(clk), .rx(tx_line),
        .data(got), .valid(got_valid), .frame_error(got_err));

    // EVERY LINE ENDS CR THEN LF, and the escape matters: Verilog has no
    // \r, so iverilog reads "\r" as a plain letter r (0x72) and the
    // backslash vanishes without a warning. \015 is the octal escape the
    // standard does define, and it is a real 0x0D. The program sends both
    // characters because a serial terminal has no line discipline to expand
    // a bare LF for it -- see the comment on putchar in sw/soc.h.
    localparam EXPLEN = 112;
    localparam [8*EXPLEN-1:0] EXPECT =
        {"RV32IM\015\nE\015\nI\015\nT\015\nT\015\nT\015\n",
         "MUL be991a08\015\nDIV 0001e240\015\nREM 00000315\015\nSDV fffe1dc0\015\n",
         "CYC ???????? INS ????????\015\nDONE\015\n"};

    function [7:0] expect_ch(input integer i);
        expect_ch = EXPECT[8*(EXPLEN-i)-1 -: 8];
    endfunction

    integer n = 0, errors = 0;
    integer traps_seen = 0, irqs_seen = 0;

    always @(posedge clk) if (got_valid) begin
        if (n >= EXPLEN) begin
            $display("FAIL: extra character %0d: %c (0x%02h)", n, got, got);
            errors = errors + 1;
        end else if (expect_ch(n) !== "?" && got !== expect_ch(n)) begin
            $display("FAIL: character %0d is %c (0x%02h), expected %c (0x%02h)",
                     n, got, got, expect_ch(n), expect_ch(n));
            errors = errors + 1;
        end
        $write("%c", got);
        n = n + 1;
    end

    // Count traps as the hardware takes them, and interrupts separately. The
    // program's letters say what the SOFTWARE thinks happened; these say what
    // the HARDWARE did, and a lesson about traps should check both.
    always @(posedge clk) begin
        if (got_err) begin
            $display("FAIL: framing error on the receive line");
            errors = errors + 1;
        end
        if (trap && !rst) begin
            traps_seen = traps_seen + 1;
            if (mcause[31]) irqs_seen = irqs_seen + 1;
        end
    end

    // =====================================================================
    //  The second machine: lesson 13's program, on this lesson's core
    // =====================================================================
    wire [31:0] conf_pc;
    wire        conf_trap, conf_retire;

    cpu5t_sys #(.IMEM_WORDS(256), .DMEM_WORDS(256),
                .PROGRAM("../13-rv32i-single/test.hex")) u_conf (
        .clk(clk), .rst(rst),
        .pc_out(conf_pc), .trap_out(conf_trap), .retire_out(conf_retire));

    integer conf_errors = 0, conf_checks = 0;
    integer conf_cycles = 0, conf_retired = 0, conf_traps = 0;

    always @(posedge clk)
        if (conf_trap && !rst) conf_traps = conf_traps + 1;

    function [31:0] dmem(input [31:0] byte_addr);
        dmem = u_conf.u_dmem.mem[byte_addr[9:2]];
    endfunction

    task expect(input [31:0] addr, input [31:0] want, input [8*28-1:0] what);
    begin
        conf_checks = conf_checks + 1;
        if (dmem(addr) !== want) begin
            conf_errors = conf_errors + 1;
            $display("  FAIL [%03h] %0s: got %h, expected %h",
                     addr, what, dmem(addr), want);
        end
    end
    endtask

    initial begin : conformance
        integer guard;
        @(negedge rst);
        guard = 0;
        while (dmem(32'h1FC) !== 32'd1 && guard < 20000) begin
            @(posedge clk);
            #1;
            guard        = guard + 1;
            conf_cycles  = guard;
            conf_retired = conf_retired + (conf_retire ? 1 : 0);
        end

        if (guard >= 20000) begin
            $display("  FAIL: lesson 13's program never finished (pc = %h)", conf_pc);
            conf_errors = conf_errors + 1;
        end

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

        // Every instruction in test.s is legal RV32I, so a core that traps
        // while running it has broken something it used to get right.
        if (conf_traps != 0) begin
            $display("  FAIL: lesson 13's program took %0d traps", conf_traps);
            conf_errors = conf_errors + 1;
        end
    end

    integer i;
    initial begin
        $dumpfile("traps.vcd");
        $dumpvars(0, tb_traps);

        repeat (4) @(posedge clk);
        rst <= 0;

        for (i = 0; i < 400000 && !halt; i = i + 1)
            @(posedge clk);

        if (!halt) begin
            $display("FAIL: the program never reached HALT (pc = 0x%08h)", pc);
            errors = errors + 1;
        end

        repeat (12 * BIT_CLKS) @(posedge clk);

        if (n != EXPLEN) begin
            $display("FAIL: %0d characters arrived, expected %0d", n, EXPLEN);
            errors = errors + 1;
        end
        // One ECALL, one illegal instruction, three timer interrupts.
        if (traps_seen != 5) begin
            $display("FAIL: the hardware took %0d traps, expected 5", traps_seen);
            errors = errors + 1;
        end
        if (irqs_seen != 3) begin
            $display("FAIL: %0d of them were interrupts, expected 3", irqs_seen);
            errors = errors + 1;
        end
        if (leds !== 8'h5A) begin
            $display("FAIL: LEDs read 0x%02h, expected 0x5A", leds);
            errors = errors + 1;
        end
        if (halt_code !== 8'h00) begin
            $display("FAIL: main returned %0d", halt_code);
            errors = errors + 1;
        end
        if (fault) begin
            $display("FAIL: a bus fault was reported; this program makes none");
            errors = errors + 1;
        end

        $display("  RV32I conformance: %0d checks, %0d errors, %0d cycles, %0d instructions",
                 conf_checks, conf_errors, conf_cycles, conf_retired);

        $display("");
        if (errors == 0 && conf_errors == 0)
            $display("PASS: %0d characters, %0d traps taken (%0d of them timer interrupts), every one returned from, and lesson 13's program still gives all %0d answers",
                     n, traps_seen, irqs_seen, conf_checks);
        else
            $display("FAIL: %0d system problem(s), %0d conformance problem(s)",
                     errors, conf_errors);
        $finish;
    end
endmodule
