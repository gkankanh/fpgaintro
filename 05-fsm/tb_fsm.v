`timescale 1ns/1ps
// Lesson 05 testbench.
//
// Three machines, three different kinds of check:
//
//   traffic     the state SEQUENCE is right and each state lasts the right
//               number of ticks — an FSM is a claim about order and duration
//   moore/mealy they detect the same sequence, and the Mealy version reports
//               exactly one clock earlier
//   lock        opens on the code, and — the part that matters — handles a
//               wrong symbol that is also a valid prefix
//
// Note the shift from earlier lessons: there is no exhaustive input space to
// sweep. An FSM's input is a SEQUENCE, so the test is a set of chosen
// journeys through the state graph. The useful discipline is coverage: has
// every transition in the diagram been taken at least once?
module tb_fsm;
    reg clk = 0;
    always #20 clk = ~clk;

    integer errors = 0;

    // ------------------------------------------------------------ traffic ---
    reg  t_rst = 1, t_tick = 0;
    wire t_red, t_amber, t_green;
    traffic #(.TICKS_RED(3), .TICKS_GREEN(2)) u_tr (
        .clk(clk), .rst(t_rst), .tick(t_tick),
        .red(t_red), .amber(t_amber), .green(t_green));

    // -------------------------------------------------- moore versus mealy --
    reg  s_rst = 1, s_d = 0;
    wire moore_found, mealy_found;
    seq_moore u_mo (.clk(clk), .rst(s_rst), .d(s_d), .found(moore_found));
    seq_mealy u_me (.clk(clk), .rst(s_rst), .d(s_d), .found(mealy_found));

    integer moore_hits = 0, mealy_hits = 0;
    always @(posedge clk) begin
        if (moore_found) moore_hits = moore_hits + 1;
        if (mealy_found) mealy_hits = mealy_hits + 1;
    end

    // --------------------------------------------------------------- lock ---
    reg        l_rst = 1, l_press = 0;
    reg  [1:0] l_code = 0;
    wire       l_unlocked;
    lock u_lk (.clk(clk), .rst(l_rst),
               .press(l_press), .code(l_code), .unlocked(l_unlocked));

    // Press one button for one clock.
    task enter(input [1:0] c);
    begin
        @(negedge clk); l_code = c; l_press = 1;
        @(negedge clk); l_press = 0;
        @(posedge clk); #1;
    end
    endtask

    task pulse_tick;
    begin
        @(negedge clk); t_tick = 1;
        @(negedge clk); t_tick = 0;
        @(posedge clk); #1;
    end
    endtask

    // Name the lamp pattern so failures read as states, not as bit vectors.
    function [8*10-1:0] lamps(input r, input a, input g);
        lamps = (r && !a && !g) ? "RED" :
                (r &&  a && !g) ? "RED_AMBER" :
                (!r && !a &&  g) ? "GREEN" :
                (!r &&  a && !g) ? "AMBER" : "INVALID";
    endfunction

    task expect_lamps(input [8*10-1:0] want);
    begin
        if (lamps(t_red, t_amber, t_green) !== want) begin
            $display("  FAIL traffic: in %0s, expected %0s",
                     lamps(t_red, t_amber, t_green), want);
            errors = errors + 1;
        end
    end
    endtask

    integer i;
    initial begin
        $dumpfile("fsm.vcd");
        $dumpvars(0, tb_fsm);

        // ===== traffic: order and duration =================================
        @(negedge clk); t_rst = 0;
        @(posedge clk); #1;
        expect_lamps("RED");

        // RED lasts 3 ticks: still red after 2, moves on the 3rd.
        pulse_tick; expect_lamps("RED");
        pulse_tick; expect_lamps("RED");
        pulse_tick; expect_lamps("RED_AMBER");
        // RED_AMBER lasts 1.
        pulse_tick; expect_lamps("GREEN");
        // GREEN lasts 2.
        pulse_tick; expect_lamps("GREEN");
        pulse_tick; expect_lamps("AMBER");
        // AMBER lasts 1, then back to the start — every transition covered.
        pulse_tick; expect_lamps("RED");

        // A state machine must not advance without its enable. Many clocks,
        // no ticks, no movement.
        repeat (50) @(posedge clk);
        #1; expect_lamps("RED");

        // ===== moore versus mealy ==========================================
        // Feed 1,0,1,0,1 — which contains TWO overlapping instances of 101.
        @(negedge clk); s_rst = 0;
        moore_hits = 0; mealy_hits = 0;
        s_d = 1; @(posedge clk);
        s_d = 0; @(posedge clk);
        s_d = 1; @(posedge clk);         // first match completes here
        s_d = 0; @(posedge clk);
        s_d = 1; @(posedge clk);         // second match completes here
        s_d = 0; repeat (3) @(posedge clk);
        #1;

        if (mealy_hits !== 2) begin
            $display("  FAIL mealy: %0d detections, expected 2", mealy_hits);
            errors = errors + 1;
        end
        if (moore_hits !== 2) begin
            $display("  FAIL moore: %0d detections, expected 2", moore_hits);
            errors = errors + 1;
        end

        // The timing difference, checked directly: drive 1,0,1 and sample the
        // two outputs on the clock where the final 1 is present. Mealy is
        // already asserted; Moore is not yet.
        s_rst = 1; @(posedge clk); @(negedge clk); s_rst = 0;
        s_d = 1; @(negedge clk);
        s_d = 0; @(negedge clk);
        s_d = 1;                          // final symbol is present NOW
        #1;
        if (mealy_found !== 1'b1) begin
            $display("  FAIL mealy should assert during the final symbol");
            errors = errors + 1;
        end
        if (moore_found !== 1'b0) begin
            $display("  FAIL moore should NOT have asserted yet");
            errors = errors + 1;
        end
        @(posedge clk); #1;               // one clock later
        if (moore_found !== 1'b1) begin
            $display("  FAIL moore should assert one clock after mealy");
            errors = errors + 1;
        end

        // ===== lock ========================================================
        // The code is 1, 2, 1, 3.
        @(negedge clk); l_rst = 0; @(posedge clk);

        enter(1); enter(2); enter(1); enter(3);
        if (l_unlocked !== 1'b1) begin
            $display("  FAIL lock did not open on the correct code");
            errors = errors + 1;
        end

        // Reset and check a wrong code does nothing.
        @(negedge clk); l_rst = 1; @(posedge clk);
        @(negedge clk); l_rst = 0; @(posedge clk);
        enter(1); enter(2); enter(1); enter(0);
        if (l_unlocked !== 1'b0) begin
            $display("  FAIL lock opened on a wrong code");
            errors = errors + 1;
        end

        // THE CASE THAT MATTERS. Enter 1,2,1,2,1,3.
        //
        // After 1,2,1 the machine expects 3 and receives 2. A machine that
        // restarts on any wrong symbol throws away the fact that the last two
        // symbols it saw were 1,2 — a valid prefix — and will then refuse the
        // correct remainder. This one must keep it and open.
        @(negedge clk); l_rst = 1; @(posedge clk);
        @(negedge clk); l_rst = 0; @(posedge clk);
        enter(1); enter(2); enter(1); enter(2); enter(1); enter(3);
        if (l_unlocked !== 1'b1) begin
            $display("  FAIL lock lost a valid prefix after a wrong symbol");
            errors = errors + 1;
        end

        // And it must not open from a prefix alone.
        @(negedge clk); l_rst = 1; @(posedge clk);
        @(negedge clk); l_rst = 0; @(posedge clk);
        enter(1); enter(2); enter(1);
        if (l_unlocked !== 1'b0) begin
            $display("  FAIL lock opened on a 3-symbol prefix");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: traffic sequence and durations correct, mealy leads moore by one clock, lock keeps a valid prefix after a wrong symbol");
        else
            $display("FAIL: %0d checks wrong", errors);
        $finish;
    end
endmodule
