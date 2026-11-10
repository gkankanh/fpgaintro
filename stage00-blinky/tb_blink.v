`timescale 1ns/1ps
// Testbench: shrink WIDTH so the sim is short, prove the LED toggles
// with the right period (2^WIDTH clocks per full cycle).
module tb_blink;
    reg clk = 0;
    always #20 clk = ~clk;        // 25 MHz

    wire [7:0] led8;
    wire led = led8[7];
    blink #(.WIDTH(8)) dut (.clk_25mhz(clk), .led(led8));

    integer edges = 0;
    reg last = 0;
    integer t_rise = 0, period = 0;

    initial begin
        $dumpfile("blink.vcd");
        $dumpvars(0, tb_blink);
        // NB: led is driven by a non-blocking assign, so the monitor sees
        // each edge one clock later. 8 toggles land on clocks 9..65.
        repeat (1026) @(posedge clk);  // 4 periods of led8[7] at WIDTH=8
        if (edges == 8 && period == 256) $display("PASS: %0d toggles, period %0d clks", edges, period);
        else                            $display("FAIL: %0d toggles, period %0d clks (want 8, 256)", edges, period);
        $finish;
    end

    integer n = 0;
    always @(posedge clk) begin
        n = n + 1;
        if (led !== last) begin
            edges = edges + 1;
            if (led) begin
                if (t_rise != 0) period = n - t_rise;
                t_rise = n;
            end
            last = led;
        end
    end
endmodule
