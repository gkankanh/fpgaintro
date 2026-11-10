`timescale 1ns/1ps
// Lesson 04 testbench.
//
// The PLL is deliberately NOT instantiated here: EHXPLLL is a hard analogue
// block with no behavioural model in iverilog. Instead the testbench generates
// two clocks itself, with deliberately awkward periods so their phase
// relationship drifts continuously — which is what two unrelated clocks on a
// real chip actually do.
//
// What is tested:
//   1. sync2 passes a level through with two clocks of latency
//   2. cdc_bus delivers every value exactly once, in order, with no
//      corruption and none lost
//
// What CANNOT be tested, here or anywhere:
//   metastability. Verilog has no notion of setup or hold time, so a flop
//   sampling a signal mid-transition always resolves cleanly and repeatably in
//   simulation. This testbench passing does not prove the crossing is safe on
//   silicon. The two-flop synchroniser is justified by reasoning about the
//   hardware, not by a green test — which is the single most important thing
//   to take from this lesson.
module tb_clocks;

    // Mutually prime periods, so every possible phase relationship occurs
    // over the run rather than the two clocks staying neatly aligned.
    reg src_clk = 0;  always #17 src_clk = ~src_clk;   // ~29.4 MHz
    reg dst_clk = 0;  always #7  dst_clk = ~dst_clk;   // ~71.4 MHz

    integer errors = 0;

    // ------------------------------------------------------------- sync2 ---
    reg  lvl = 0;
    wire lvl_sync;
    sync2 u_s (.clk(dst_clk), .d_async(lvl), .q(lvl_sync));

    // ----------------------------------------------------------- cdc_bus ---
    localparam W = 8;
    reg          src_valid = 0;
    reg  [W-1:0] src_data  = 0;
    wire [W-1:0] dst_data;
    wire         dst_valid;

    cdc_bus #(.W(W)) u_cdc (
        .src_clk(src_clk), .src_valid(src_valid), .src_data(src_data),
        .dst_clk(dst_clk), .dst_data(dst_data),   .dst_valid(dst_valid)
    );

    // Collect everything the destination reports.
    localparam N = 12;
    reg [W-1:0] got [0:N-1];
    integer     n_got = 0;

    always @(posedge dst_clk)
        if (dst_valid) begin
            if (n_got < N) got[n_got] = dst_data;
            n_got = n_got + 1;
        end

    integer i;
    initial begin
        $dumpfile("clocks.vcd");
        $dumpvars(0, tb_clocks);

        // ===== 1. sync2 latency ============================================
        // Two flops, so the level appears at the output two destination clock
        // edges after it is sampled. Allow three to avoid depending on where
        // in the destination period the change happened — that uncertainty is
        // inherent to crossing domains and is not a bug.
        @(negedge dst_clk); lvl = 1;
        repeat (3) @(posedge dst_clk); #1;
        if (lvl_sync !== 1'b1) begin
            $display("  FAIL sync2 did not pass the level through");
            errors = errors + 1;
        end
        @(negedge dst_clk); lvl = 0;
        repeat (3) @(posedge dst_clk); #1;
        if (lvl_sync !== 1'b0) begin
            $display("  FAIL sync2 did not pass the level back");
            errors = errors + 1;
        end

        // ===== 2. cdc_bus delivers everything, intact and in order =========
        // Send N distinct values, spacing them generously — the handshake
        // needs the destination to see each toggle before the next one, which
        // clocks_top guarantees by sending only once per 65,536 source clocks.
        for (i = 0; i < N; i = i + 1) begin
            @(negedge src_clk);
            src_data  = 8'hA0 + i[7:0];
            src_valid = 1;
            @(negedge src_clk);
            src_valid = 0;
            repeat (8) @(posedge src_clk);      // let it land
        end
        repeat (20) @(posedge dst_clk);

        if (n_got !== N) begin
            $display("  FAIL cdc_bus delivered %0d values, expected %0d", n_got, N);
            errors = errors + 1;
        end
        for (i = 0; i < N && i < n_got; i = i + 1)
            if (got[i] !== (8'hA0 + i[7:0])) begin
                $display("  FAIL cdc_bus value %0d: got %h, expected %h",
                         i, got[i], 8'hA0 + i[7:0]);
                errors = errors + 1;
            end

        if (errors == 0)
            $display("PASS: sync2 passes levels, cdc_bus delivered all %0d values in order (metastability is NOT and cannot be tested here)", n_got);
        else
            $display("FAIL: %0d checks wrong", errors);
        $finish;
    end
endmodule
