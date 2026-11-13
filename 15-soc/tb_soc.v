`timescale 1ns/1ps
// ===========================================================================
//  Lesson 15 — the testbench.
//
//  This one is different from every testbench before it, because what is
//  being tested is no longer a circuit: it is a circuit running a PROGRAM.
//  The stimulus is firmware.hex, compiled from sw/main.c, and the expected
//  result is a string of characters arriving over a serial line.
//
//  HOW IT CHECKS, AND WHY IT CHECKS THAT WAY
//
//  The obvious shortcut is to reach into the design and watch writes to the
//  UART transmit register. That would test everything except the UART, the
//  bus decode and the pin -- which is to say, it would test the parts least
//  likely to be wrong.
//
//  So this testbench behaves like the host at the other end of the cable. It
//  instantiates lesson 09's RECEIVER, points it at the SoC's transmit pin,
//  and reads the bytes off the wire at the agreed baud rate. Everything in
//  between -- the C compiler's output, crt0, the address decoder, the write
//  path, the shift register, the bit timing -- has to be right for a single
//  character to arrive. And it instantiates lesson 09's TRANSMITTER pointed
//  the other way, so the round trip is real in both directions.
//
//  THE BAUD RATE IS WRONG ON PURPOSE. 2.5 Mbaud against a 25 MHz clock is ten
//  clocks per bit, where the board's 115,200 is 217. The logic is identical --
//  the divisor is a parameter, and lesson 09 built it that way -- but the
//  simulation finishes in ten thousand cycles instead of two hundred
//  thousand. Simulating the real baud rate would test nothing extra and cost
//  twenty times the run time.
// ===========================================================================
module tb_soc;
    localparam CLK_HZ = 25_000_000;
    localparam BAUD   = 2_500_000;        // 10 clocks per bit, for the run time
    localparam BIT_CLKS = CLK_HZ / BAUD;

    reg clk = 0;
    always #20 clk = ~clk;                // 25 MHz: 40 ns period

    reg rst = 1;

    wire        tx_line, rx_line;
    wire [7:0]  leds;
    wire [31:0] pc;
    wire        illegal, fault, halt;
    wire [7:0]  halt_code;

    soc #(.MEM_WORDS(512), .FIRMWARE("firmware.hex"),
          .CLK_HZ(CLK_HZ), .BAUD(BAUD)) dut (
        .clk(clk), .rst(rst),
        .gpo(leds), .gpi(16'h0000),
        .uart_tx_pin(tx_line), .uart_rx_pin(rx_line),
        .pc_out(pc), .illegal_out(illegal), .fault_out(fault),
        .halt_out(halt), .halt_code(halt_code));

    // ---- the host's receiver: what the machine said -----------------------
    wire [7:0] got;
    wire       got_valid, got_err;

    uart_rx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_host_rx (
        .clk(clk), .rx(tx_line),
        .data(got), .valid(got_valid), .frame_error(got_err));

    // ---- the host's transmitter: one keystroke ----------------------------
    reg        send = 0;
    wire       send_busy;

    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_host_tx (
        .clk(clk), .data("K"), .start(send),
        .tx(rx_line), .busy(send_busy));

    // ---- what the program is expected to say ------------------------------
    //
    // '?' matches any character. It is used for the cycle count, which is a
    // real measurement and therefore not something to hard-code: the test
    // checks that the machine timed itself and printed eight hex digits, not
    // that it got a particular answer. Everything else is exact.
    // The three lines in the middle are the encoding of `add2` read back out
    // of the program's own memory, so they are a statement about what gcc
    // emitted: `add a0,a0,a1` is 0x00b50533 and `ret` is 0x00008067. A
    // different compiler may pick different registers and change them. If
    // that happens the fix is to run `make dis` and copy the two words --
    // the test is still asserting the right thing, which is that the machine
    // can read its own instructions.
    // EVERY LINE ENDS CR THEN LF, and the escape matters: Verilog has no
    // \r, so iverilog reads "\r" as a plain letter r (0x72) and the
    // backslash vanishes without a warning. \015 is the octal escape the
    // standard does define, and it is a real 0x0D. The program sends both
    // characters because a serial terminal has no line discipline to expand
    // a bare LF for it -- see the comment on putchar in sw/soc.h.
    localparam EXPLEN = 165;
    localparam [8*EXPLEN-1:0] EXPECT =
        {"Hello world from RV32I SoC on ULX3S \015\ndeadbeef\015\nbss ok\015\n",
         "x+y 0000002a\015\nadd2 00b50533 00008067\015\nop 00000033\015\n",
         "Waiting for a character from host\015\nK\015\nCYC ????????\015\nDONE\015\n"};

    function [7:0] expect_ch(input integer i);
        expect_ch = EXPECT[8*(EXPLEN-i)-1 -: 8];
    endfunction

    integer n      = 0;        // how many characters have arrived
    integer errors = 0;
    reg     fault_before_done = 0;

    always @(posedge clk) if (got_valid) begin
        if (n >= EXPLEN) begin
            $display("FAIL: extra character %0d: %c (0x%02h)", n, got, got);
            errors = errors + 1;
        end else if (expect_ch(n) !== "?" && got !== expect_ch(n)) begin
            $display("FAIL: character %0d is %c (0x%02h), expected %c (0x%02h)",
                     n, got, got, expect_ch(n), expect_ch(n));
            errors = errors + 1;
        end
        // Echo the machine's output, so a human running `make sim` sees what
        // the program actually printed rather than only a verdict.
        $write("%c", got);
        n = n + 1;
    end

    always @(posedge clk)
        if (got_err) begin
            $display("FAIL: framing error on the receive line");
            errors = errors + 1;
        end

    // The deliberate wild store is the last thing main does, and the program
    // writes 0x5A to the LEDs one instruction before it. That marker is the
    // boundary, not the text: by the time "DONE" has finished shifting out of
    // a 2.5 Mbaud UART the CPU is thousands of cycles past it, so the
    // characters say nothing about when. Sampling the fault line until the
    // marker appears proves the decoder stayed quiet for the whole program
    // and fired only for the one bad address.
    reg saw_a5 = 0;
    always @(posedge clk) begin
        if (leds == 8'hA5)  saw_a5 <= 1;
        if (leds != 8'h5A)  fault_before_done <= fault;
    end

    // ---- the run ----------------------------------------------------------
    integer i;
    initial begin
        $dumpfile("soc.vcd");
        $dumpvars(0, tb_soc);

        repeat (4) @(posedge clk);
        rst <= 0;

        // The keystroke goes out immediately. The program will not poll for
        // it until it has printed three lines, by which time it is sitting in
        // the receiver's holding register -- which is the entire reason that
        // register exists (mmio.v).
        @(posedge clk);
        send <= 1;
        @(posedge clk);
        send <= 0;

        // Wait for the program to stop, with a generous ceiling. 200,000
        // clocks is twenty times what this program needs; a timeout is a test
        // result, not an accident.
        for (i = 0; i < 200000 && !halt; i = i + 1)
            @(posedge clk);

        if (!halt) begin
            $display("FAIL: the program never reached HALT (pc = 0x%08h)", pc);
            errors = errors + 1;
        end

        // The last character was still in the shift register when main
        // returned: putchar waits for the transmitter to be FREE, not for it
        // to be finished. Give the line time to drain before judging.
        repeat (12 * BIT_CLKS) @(posedge clk);

        // ---- the verdict --------------------------------------------------
        if (n != EXPLEN) begin
            $display("FAIL: %0d characters arrived, expected %0d", n, EXPLEN);
            errors = errors + 1;
        end
        if (illegal) begin
            $display("FAIL: an illegal instruction was executed");
            errors = errors + 1;
        end
        if (!saw_a5) begin
            $display("FAIL: the program never wrote 0xA5 to the LEDs");
            errors = errors + 1;
        end
        if (leds !== 8'h5A) begin
            $display("FAIL: LEDs read 0x%02h, expected the 0x5A marker", leds);
            errors = errors + 1;
        end
        if (halt_code !== 8'h00) begin
            $display("FAIL: main returned %0d", halt_code);
            errors = errors + 1;
        end
        if (fault_before_done) begin
            $display("FAIL: the decoder reported a fault during the program");
            errors = errors + 1;
        end
        if (!fault) begin
            $display("FAIL: the store to 0x0DD00000 was not reported");
            errors = errors + 1;
        end

        $display("");
        if (errors == 0)
            $display("PASS: %0d characters over the wire, both LED writes seen, one wild store caught, halt code %0d",
                     n, halt_code);
        else
            $display("FAIL: %0d problem(s)", errors);
        $finish;
    end
endmodule
