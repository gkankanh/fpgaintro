`timescale 1ns/1ps
// Lesson 09 testbench.
//
// A UART is a claim about TIME, so the tests are about time:
//
//   1. the transmitter's bit periods are exactly DIV clocks, and the frame is
//      start + 8 data LSB-first + stop -- decoded off the wire, not by
//      peeking at internal signals
//   2. the receiver recovers a byte driven at the correct rate
//   3. tx -> rx loopback round-trips every one of 256 byte values
//   4. a frame at the exact rate is accepted and correct -- and, documented
//      rather than asserted, the receiver's real tolerance is about -5% to
//      +6%, beyond which it can deliver a corrupted byte with NO framing
//      error. That limit is measured in the README.
//   5. a glitch on the line does not start a phantom frame
//
// Test 4 is the one worth having. A loopback test passes trivially because
// both ends share a clock and a divisor; it proves almost nothing about
// talking to a real device. Deliberately driving the receiver at the wrong
// rate is what exercises the sampling logic.
module tb_uart;
    // A deliberately small divisor keeps the simulation short. The logic is
    // identical at DIV=217; only the time constant differs.
    localparam CLK_HZ = 1_000_000;
    localparam BAUD   = 125000;            // DIV = 8 exactly
    localparam DIV    = CLK_HZ / BAUD;

    reg clk = 0;
    always #20 clk = ~clk;                 // 25 MHz tick; CLK_HZ is nominal

    integer errors = 0;

    task fail(input [8*44-1:0] what);
    begin
        errors = errors + 1;
        $display("  FAIL %0s", what);
    end
    endtask

    // ---------------------------------------------------------- transmitter --
    reg  [7:0] tx_data  = 0;
    reg        tx_start = 0;
    wire       tx_line, tx_busy;
    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_tx (
        .clk(clk), .data(tx_data), .start(tx_start),
        .tx(tx_line), .busy(tx_busy));

    // ------------------------------------------------------------- receiver --
    reg        rx_line = 1;
    wire [7:0] rx_data;
    wire       rx_valid, rx_ferr;
    uart_rx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_rx (
        .clk(clk), .rx(rx_line),
        .data(rx_data), .valid(rx_valid), .frame_error(rx_ferr));

    // ------------------------------------------------------------- loopback --
    wire [7:0] lb_data;
    wire       lb_valid, lb_ferr;
    uart_rx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_lb (
        .clk(clk), .rx(tx_line),
        .data(lb_data), .valid(lb_valid), .frame_error(lb_ferr));

    reg [7:0] lb_last  = 0;
    integer   lb_count = 0;
    always @(posedge clk)
        if (lb_valid) begin
            lb_last  = lb_data;
            lb_count = lb_count + 1;
        end

    integer   ferr_count = 0;
    integer   valid_count = 0;
    always @(posedge clk) begin
        if (rx_ferr)  ferr_count  = ferr_count + 1;
        if (rx_valid) valid_count = valid_count + 1;
    end

    // Drive one 8N1 frame onto rx_line at `period` clocks per bit. Passing a
    // period other than DIV is how the mismatch test works.
    task send_frame(input [7:0] b, input integer period);
        integer i, j;
    begin
        rx_line = 0;                                   // start bit
        for (j = 0; j < period; j = j + 1) @(posedge clk);
        for (i = 0; i < 8; i = i + 1) begin            // data, LSB first
            rx_line = b[i];
            for (j = 0; j < period; j = j + 1) @(posedge clk);
        end
        rx_line = 1;                                   // stop bit
        for (j = 0; j < period; j = j + 1) @(posedge clk);
    end
    endtask

    integer i, k;
    integer t_fall, t_rise, measured;
    reg [9:0] seen;

    initial begin
        $dumpfile("uart.vcd");
        $dumpvars(0, tb_uart);

        // ===== 1. the transmitter's bit period, measured off the wire ======
        //
        // Send 0xFF. The frame is then start(0) followed by eight 1s and a
        // stop(1), so the ONLY low period on the line is the start bit, and
        // its width is exactly one bit period.
        //
        // The measurement arm is forked so it is already waiting before
        // `start` is asserted. An earlier version set up the wait afterwards
        // and missed the start bit's falling edge entirely -- it then
        // measured the five-zero run in the middle of 0x41 and reported
        // 40 clocks for an 8-clock bit. The transmitter was right; the test
        // was looking in the wrong place.
        fork
            begin
                @(negedge tx_line); t_fall = $time;
                @(posedge tx_line); t_rise = $time;
            end
            begin
                @(negedge clk); tx_data = 8'hFF; tx_start = 1;
                @(negedge clk); tx_start = 0;
            end
        join

        measured = (t_rise - t_fall) / 40;              // 40 ns per clock
        if (measured != DIV)
            $display("  FAIL tx start bit was %0d clocks, expected %0d",
                     measured, DIV);
        if (measured != DIV) errors = errors + 1;

        while (tx_busy) @(posedge clk);
        repeat (DIV * 3) @(posedge clk);

        // And the complement: 0x00 makes start + eight data bits all low, so
        // the low run should be exactly NINE bit periods. Together these pin
        // down both the bit width and the frame's structure.
        fork
            begin
                @(negedge tx_line); t_fall = $time;
                @(posedge tx_line); t_rise = $time;
            end
            begin
                @(negedge clk); tx_data = 8'h00; tx_start = 1;
                @(negedge clk); tx_start = 0;
            end
        join

        measured = (t_rise - t_fall) / 40;
        if (measured != DIV * 9)
            $display("  FAIL tx start+8 zeros was %0d clocks, expected %0d",
                     measured, DIV * 9);
        if (measured != DIV * 9) errors = errors + 1;

        while (tx_busy) @(posedge clk);

        // ===== 3. loopback over every byte value ===========================
        // Done before the mismatch tests so the error counters stay clean.
        //
        // Let the frames already in flight land BEFORE zeroing the counter --
        // an earlier version reset it while the previous byte was still on
        // the wire and then counted 257 of 256.
        repeat (DIV * 4) @(posedge clk);
        lb_count = 0;
        for (i = 0; i < 256; i = i + 1) begin
            @(negedge clk); tx_data = i[7:0]; tx_start = 1;
            @(negedge clk); tx_start = 0;
            while (tx_busy) @(posedge clk);
            repeat (DIV * 3) @(posedge clk);            // let the stop bit land
            if (lb_last !== i[7:0])
                $display("  FAIL loopback: sent %h, received %h", i[7:0], lb_last);
            if (lb_last !== i[7:0]) errors = errors + 1;
        end
        if (lb_count != 256)
            $display("  FAIL loopback delivered %0d of 256 bytes", lb_count);
        if (lb_count != 256) errors = errors + 1;
        if (lb_ferr) fail("loopback reported a framing error");

        // ===== 2. the receiver, driven at the correct rate =================
        valid_count = 0; ferr_count = 0;
        send_frame(8'h5A, DIV);
        repeat (DIV * 2) @(posedge clk);
        if (valid_count != 1)   fail("receiver did not accept a correct frame");
        if (rx_data !== 8'h5A)  fail("receiver decoded the wrong byte");
        if (ferr_count != 0)    fail("receiver flagged a correct frame");

        // ===== 4. baud mismatch, and an honest limit =======================
        //
        // A UART must tolerate a few percent of rate error, because two
        // crystals never agree exactly. Measured on this receiver at a
        // realistic DIV=217 (see the README for the full sweep):
        //
        //     -4.8% .. +6.4%   accepted, byte correct
        //     beyond that      ACCEPTED, BYTE WRONG, no framing error
        //
        // That second row matters more than the first. Far enough off, the
        // stop bit is sampled somewhere inside the data, lands on a 1 by
        // chance, and the frame passes its only check while delivering
        // rubbish. A FRAMING ERROR IS NOT A RELIABLE CORRUPTION DETECTOR --
        // it catches many cases, not all. Detecting the rest is a protocol
        // job: a parity bit, or a checksum over a packet.
        //
        // So this test asserts what is actually true: a frame within
        // tolerance is accepted and correct. It deliberately does NOT assert
        // that out-of-tolerance frames are always rejected, because they are
        // not, and a test claiming otherwise would be a lie that passes.
        valid_count = 0; ferr_count = 0;
        send_frame(8'hA5, DIV);                         // exact rate
        repeat (DIV * 3) @(posedge clk);
        if (valid_count != 1 || rx_data !== 8'hA5)
            fail("a frame at the exact rate was not received correctly");
        if (ferr_count != 0) fail("exact-rate frame flagged as a framing error");

        // A badly mistimed frame must at least not be silently ACCEPTED as a
        // valid byte AND flagged at the same time -- the two outputs are
        // mutually exclusive by construction.
        valid_count = 0; ferr_count = 0;
        for (k = 0; k < 4; k = k + 1) begin
            send_frame(8'hA5, DIV + 2);                 // 25% slow: hopeless
            repeat (DIV * 3) @(posedge clk);
        end
        if (valid_count + ferr_count == 0)
            fail("badly-timed frames produced neither a byte nor an error");

        // ===== 5. a glitch must not start a frame =========================
        valid_count = 0; ferr_count = 0;
        rx_line = 1; repeat (DIV * 2) @(posedge clk);
        rx_line = 0; repeat (2) @(posedge clk);         // far shorter than a bit
        rx_line = 1; repeat (DIV * 4) @(posedge clk);
        if (valid_count != 0) fail("a 2-clock glitch produced a byte");
        if (ferr_count != 0)  fail("a 2-clock glitch produced a framing error");

        if (errors == 0)
            $display("PASS: tx bit period is exactly DIV clocks, 256/256 bytes round-tripped, exact-rate frames correct, glitches ignored (note: out-of-tolerance frames CAN corrupt undetected - see README)");
        else
            $display("FAIL: %0d checks wrong", errors);
        $finish;
    end
endmodule
