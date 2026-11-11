`timescale 1ns/1ps
// Lesson 08 — board demo: test a real block RAM on real silicon.
//
//   btn[1]   start the test
//   led[7]   pass   (test finished with zero errors)
//   led[6]   done
//   led[5]   busy
//   led[4:0] progress while running, error count when finished
//
// 1024 words of 32 bits is 32,768 bits -- two DP16KD blocks. The test writes
// all of it and reads all of it back in about 3,000 clocks, so at 25 MHz it is
// over in 120 microseconds: press the button and it is already done.
module mem_top (
    input  wire       clk_25mhz,
    input  wire [2:1] btn,
    output wire [7:0] led
);
    wire        clean;
    wire        busy, done, pass;
    wire [15:0] errors;
    wire [9:0]  progress;

    debounce #(.COUNT(250_000)) u_db (
        .clk(clk_25mhz), .noisy(btn[1]), .clean(clean));

    mem_test #(.DEPTH(1024), .W(32)) u_test (
        .clk(clk_25mhz), .start(clean),
        .busy(busy), .done(done), .pass(pass),
        .errors(errors), .progress(progress)
    );

    // While running, show the top bits of the address being tested so there
    // is visible motion; when finished, show the error count. Folding the
    // low address bits in keeps every bit of `progress` read -- an unused bit
    // is usually a mistake, so it is better to consume it deliberately than
    // to waive the warning.
    wire [4:0] running = progress[9:5] ^ {progress[4:0]};

    assign led = {pass, done, busy, done ? errors[4:0] : running};

    wire _unused = &{btn[2], errors[15:5], 1'b0};
endmodule
