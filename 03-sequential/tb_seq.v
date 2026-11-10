`timescale 1ns/1ps
// Lesson 03 testbench.
//
// Three separate experiments, because this lesson has three claims to prove:
//
//   1. the two shift registers behave differently — `<=` is a 3-stage delay
//      line, `=` collapses to one stage
//   2. the debouncer turns a bouncing input into one clean transition
//   3. the edge detector emits exactly one pulse per rising edge
//   4. reg_w loads on enable and holds otherwise
//
// Experiment 2 is the first test in this course that cannot be exhaustive.
// There is no "all possible bounce patterns" — so instead a specific, realistic
// pattern is injected and the output is checked for the property that matters:
// exactly one transition.
module tb_seq;
    reg clk = 0;
    always #20 clk = ~clk;              // 25 MHz: 40 ns period

    integer errors = 0;

    // ----------------------------------------------------- shift registers --
    reg d = 0;
    wire [2:0] q_nb, q_b;
    shift_nonblocking u_nb (.clk(clk), .d(d), .q(q_nb));
    shift_blocking    u_b  (.clk(clk), .d(d), .q(q_b));

    // ---------------------------------------------------------- debouncer ---
    // COUNT is tiny here so the simulation is short. On hardware it is
    // 250,000; the logic is identical, only the time constant differs.
    localparam DB = 20;
    reg  noisy = 0;
    wire clean;
    debounce #(.COUNT(DB)) u_db (.clk(clk), .noisy(noisy), .clean(clean));

    integer clean_transitions = 0;
    reg     clean_prev = 0;
    always @(posedge clk) begin
        if (clean !== clean_prev) clean_transitions = clean_transitions + 1;
        clean_prev <= clean;
    end

    // ------------------------------------------------------------- reg_w ---
    // Narrowed to 8 bits here; it defaults to 32, the CPU width.
    reg  [7:0] rd = 0;
    reg        ren = 0;
    wire [7:0] rq;
    reg_w #(.W(8)) u_reg (.clk(clk), .en(ren), .d(rd), .q(rq));

    // ------------------------------------------------------ edge detector ---
    reg  lvl = 0;
    wire rise, fall;
    edge_detect u_ed (.clk(clk), .level(lvl), .rise(rise), .fall(fall));

    integer rise_pulses = 0, fall_pulses = 0;
    always @(posedge clk) begin
        if (rise) rise_pulses = rise_pulses + 1;
        if (fall) fall_pulses = fall_pulses + 1;
    end

    integer i;
    initial begin
        $dumpfile("seq.vcd");
        $dumpvars(0, tb_seq);

        // ===== 1. the two shift registers ==================================
        // Drive a one-clock pulse through and watch where it goes.
        //
        // Timing care: `d` is changed on the NEGEDGE so it is stable well
        // before the posedge that samples it. Then each check happens just
        // after the posedge that acted on it — getting this ordering wrong is
        // how a testbench ends up measuring the wrong clock cycle.
        @(negedge clk); d = 1;

        // First clock edge with d=1. The non-blocking version has the pulse in
        // stage a only. The blocking version has it in all three at once,
        // because each line saw the new value of the line above.
        @(posedge clk); #1;
        if (q_nb !== 3'b001) begin
            $display("  FAIL nonblocking after 1 clk: q=%b, expected 001", q_nb);
            errors = errors + 1;
        end
        if (q_b !== 3'b111) begin
            $display("  FAIL blocking after 1 clk: q=%b, expected 111", q_b);
            errors = errors + 1;
        end

        @(negedge clk); d = 0;          // end the pulse

        // The pulse walks along the non-blocking chain: a -> b -> c.
        // In the blocking version it simply vanishes, all three stages
        // following d together.
        @(posedge clk); #1;
        if (q_nb !== 3'b010) begin
            $display("  FAIL nonblocking after 2 clk: q=%b, expected 010", q_nb);
            errors = errors + 1;
        end
        if (q_b !== 3'b000) begin
            $display("  FAIL blocking after 2 clk: q=%b, expected 000", q_b);
            errors = errors + 1;
        end

        @(posedge clk); #1;
        if (q_nb !== 3'b100) begin
            $display("  FAIL nonblocking after 3 clk: q=%b, expected 100", q_nb);
            errors = errors + 1;
        end

        // One more: the pulse leaves the chain entirely.
        @(posedge clk); #1;
        if (q_nb !== 3'b000) begin
            $display("  FAIL nonblocking after 4 clk: q=%b, expected 000", q_nb);
            errors = errors + 1;
        end

        // ===== 2. the debouncer ============================================
        // A realistic press: the contact makes and breaks several times over
        // a few clocks, then settles high. Every one of these transitions is
        // shorter than DB, so none of them should reach `clean`.
        clean_transitions = 0;
        @(negedge clk);
        for (i = 0; i < 6; i = i + 1) begin
            noisy = 1; repeat (2) @(negedge clk);
            noisy = 0; repeat (3) @(negedge clk);
        end
        noisy = 1;                                  // settles closed
        repeat (DB + 10) @(negedge clk);

        if (clean !== 1'b1) begin
            $display("  FAIL debounce: clean=%b after settling high", clean);
            errors = errors + 1;
        end
        if (clean_transitions !== 1) begin
            $display("  FAIL debounce: %0d transitions on clean, expected 1",
                     clean_transitions);
            errors = errors + 1;
        end

        // Release, equally noisily, and expect exactly one more transition.
        clean_transitions = 0;
        for (i = 0; i < 6; i = i + 1) begin
            noisy = 0; repeat (2) @(negedge clk);
            noisy = 1; repeat (3) @(negedge clk);
        end
        noisy = 0;
        repeat (DB + 10) @(negedge clk);

        if (clean !== 1'b0) begin
            $display("  FAIL debounce: clean=%b after settling low", clean);
            errors = errors + 1;
        end
        if (clean_transitions !== 1) begin
            $display("  FAIL debounce release: %0d transitions, expected 1",
                     clean_transitions);
            errors = errors + 1;
        end

        // ===== 3. the edge detector ========================================
        // Hold the level high for many clocks: still exactly one pulse.
        rise_pulses = 0; fall_pulses = 0;
        @(negedge clk); lvl = 1;
        repeat (10) @(negedge clk);
        lvl = 0;
        repeat (10) @(negedge clk);

        if (rise_pulses !== 1) begin
            $display("  FAIL edge_detect: %0d rise pulses, expected 1", rise_pulses);
            errors = errors + 1;
        end
        if (fall_pulses !== 1) begin
            $display("  FAIL edge_detect: %0d fall pulses, expected 1", fall_pulses);
            errors = errors + 1;
        end

        // Three rapid edges must give three pulses — the detector must not
        // be accidentally debouncing anything itself.
        rise_pulses = 0;
        for (i = 0; i < 3; i = i + 1) begin
            lvl = 1; @(negedge clk);
            lvl = 0; @(negedge clk);
        end
        if (rise_pulses !== 3) begin
            $display("  FAIL edge_detect: %0d pulses for 3 edges", rise_pulses);
            errors = errors + 1;
        end

        // ===== 4. the enabled register =====================================
        // Loads when enabled...
        @(negedge clk); rd = 8'hA5; ren = 1;
        @(posedge clk); #1;
        if (rq !== 8'hA5) begin
            $display("  FAIL reg_w did not load: q=%h, expected A5", rq);
            errors = errors + 1;
        end

        // ...and holds when not, however much `d` changes.
        @(negedge clk); ren = 0; rd = 8'h3C;
        repeat (5) @(posedge clk);
        #1;
        if (rq !== 8'hA5) begin
            $display("  FAIL reg_w did not hold: q=%h, expected A5", rq);
            errors = errors + 1;
        end

        // Enabling again picks up whatever `d` is now.
        @(negedge clk); ren = 1;
        @(posedge clk); #1;
        if (rq !== 8'h3C) begin
            $display("  FAIL reg_w reload: q=%h, expected 3C", rq);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: shift registers differ as expected, debounce gives 1 transition per press, edge detect gives 1 pulse per edge, reg_w loads and holds");
        else
            $display("FAIL: %0d checks wrong", errors);
        $finish;
    end
endmodule
