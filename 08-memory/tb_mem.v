`timescale 1ns/1ps
// Lesson 08 testbench.
//
// Five things to establish:
//   1. ram_sp stores and returns, with ONE CYCLE of read latency
//   2. ram_sdp serves a write and an unrelated read in the same cycle
//   3. ram_tdp works on both ports, and the same-address case is a hazard
//   4. the font ROM returns what font.hex says it should
//   5. the framebuffer round-trips pixels by coordinate
//   6. mem_test (the hardware self-test) itself passes
//
// The recurring theme is LATENCY. Every synchronous memory in this file
// returns data one clock after the address, and almost every memory bug in
// the rest of this course will be an off-by-one on exactly that.
module tb_mem;
    reg clk = 0;
    always #20 clk = ~clk;

    integer errors = 0;

    task fail(input [8*40-1:0] what);
    begin
        errors = errors + 1;
        $display("  FAIL %0s", what);
    end
    endtask

    // ------------------------------------------------------------- ram_sp ---
    reg         sp_we   = 0;
    reg  [7:0]  sp_addr = 0;
    reg  [31:0] sp_din  = 0;
    wire [31:0] sp_dout;
    ram_sp #(.W(32), .DEPTH(256)) u_sp (
        .clk(clk), .we(sp_we), .addr(sp_addr), .din(sp_din), .dout(sp_dout));

    // ------------------------------------------------------------ ram_sdp ---
    reg         sdp_we    = 0;
    reg  [7:0]  sdp_waddr = 0, sdp_raddr = 0;
    reg  [31:0] sdp_din   = 0;
    wire [31:0] sdp_dout;
    ram_sdp #(.W(32), .DEPTH(256)) u_sdp (
        .wclk(clk), .we(sdp_we), .waddr(sdp_waddr), .din(sdp_din),
        .rclk(clk), .raddr(sdp_raddr), .dout(sdp_dout));

    // ------------------------------------------------------------ ram_tdp ---
    reg         a_we = 0, b_we = 0;
    reg  [7:0]  a_addr = 0, b_addr = 0;
    reg  [31:0] a_din = 0,  b_din = 0;
    wire [31:0] a_dout, b_dout;
    ram_tdp #(.W(32), .DEPTH(256)) u_tdp (
        .clk(clk),
        .we_a(a_we), .addr_a(a_addr), .din_a(a_din), .dout_a(a_dout),
        .we_b(b_we), .addr_b(b_addr), .din_b(b_din), .dout_b(b_dout));

    // ---------------------------------------------------------------- ROM ---
    reg  [9:0] rom_addr = 0;
    wire [7:0] rom_dout;
    font_full u_font (.clk(clk), .addr(rom_addr), .dout(rom_dout));

    // -------------------------------------------------------- framebuffer ---
    reg        fb_we = 0;
    reg  [6:0] fb_wx = 0, fb_rx = 0;
    reg  [5:0] fb_wy = 0, fb_ry = 0;
    reg        fb_wpix = 0;
    wire       fb_rpix;
    framebuffer u_fb (
        .wclk(clk), .we(fb_we), .wx(fb_wx), .wy(fb_wy), .wpix(fb_wpix),
        .rclk(clk), .rx(fb_rx), .ry(fb_ry), .rpix(fb_rpix));

    // ----------------------------------------------------------- mem_test ---
    reg         mt_start = 0;
    wire        mt_busy, mt_done, mt_pass;
    wire [15:0] mt_errors;
    wire [6:0]  mt_progress;
    mem_test #(.DEPTH(128), .W(32)) u_mt (
        .clk(clk), .start(mt_start), .busy(mt_busy), .done(mt_done),
        .pass(mt_pass), .errors(mt_errors), .progress(mt_progress));

    integer i;
    reg [7:0] want_byte;

    initial begin
        $dumpfile("mem.vcd");
        $dumpvars(0, tb_mem);

        // ===== 1. ram_sp: store, and prove the one-cycle read latency ======
        // Two words first.
        @(negedge clk); sp_addr = 8'd7;   sp_din = 32'hDEAD_BEEF; sp_we = 1;
        @(negedge clk); sp_addr = 8'd200; sp_din = 32'h0123_4567;
        @(negedge clk); sp_we = 0;

        // Point at 7 and let one edge pass: dout now holds mem[7].
        @(negedge clk); sp_addr = 8'd7;
        @(posedge clk); #1;
        if (sp_dout !== 32'hDEAD_BEEF) fail("ram_sp did not return the stored word");

        // THE LATENCY, demonstrated: change the address and look BEFORE the
        // next edge. dout must still show the OLD location, because nothing
        // has clocked yet. A combinational read would have followed instantly.
        @(negedge clk); sp_addr = 8'd200;
        #1;
        if (sp_dout !== 32'hDEAD_BEEF)
            fail("ram_sp read is not registered - that shape cannot be a BRAM");

        // ...and after the edge it has followed.
        @(posedge clk); #1;
        if (sp_dout !== 32'h0123_4567) fail("ram_sp second location wrong");

        // The first word survived being read away from.
        @(negedge clk); sp_addr = 8'd7;
        @(posedge clk); #1;
        if (sp_dout !== 32'hDEAD_BEEF) fail("ram_sp lost the first word");

        // ===== 2. ram_sdp: a write and an unrelated read, same cycle =======
        @(negedge clk); sdp_waddr = 8'd10; sdp_din = 32'hAAAA_5555; sdp_we = 1;
        @(negedge clk); sdp_we = 0;
        @(negedge clk); sdp_waddr = 8'd11; sdp_din = 32'h5555_AAAA; sdp_we = 1;
                        sdp_raddr = 8'd10;            // read 10 WHILE writing 11
        @(negedge clk); sdp_we = 0;
        @(posedge clk); #1;
        if (sdp_dout !== 32'hAAAA_5555)
            fail("ram_sdp read was disturbed by a simultaneous write elsewhere");
        @(negedge clk); sdp_raddr = 8'd11;
        repeat (2) @(posedge clk); #1;
        if (sdp_dout !== 32'h5555_AAAA) fail("ram_sdp did not store on the write port");

        // ===== 3. ram_tdp: both ports independently ========================
        @(negedge clk);
        a_addr = 8'd20; a_din = 32'h1111_1111; a_we = 1;
        b_addr = 8'd21; b_din = 32'h2222_2222; b_we = 1;
        @(negedge clk); a_we = 0; b_we = 0;
        // Cross-read: port A reads what B wrote, and vice versa.
        a_addr = 8'd21;
        b_addr = 8'd20;
        repeat (2) @(posedge clk); #1;
        if (a_dout !== 32'h2222_2222) fail("ram_tdp port A could not read port B's write");
        if (b_dout !== 32'h1111_1111) fail("ram_tdp port B could not read port A's write");

        // The same-address-both-writing case is deliberately NOT asserted on.
        // It is a hazard with no defined answer: real silicon gives you
        // something that depends on the block's configuration, and simulation
        // gives you whichever assignment ran last. Asserting any particular
        // result here would be encoding a simulator artefact as a fact.

        // ===== 4. the font ROM ============================================
        // 'A' is ASCII 65, so its 8 rows start at 65*8 = 520. Row 0 of 'A' is
        // 0x18 per font.hex.
        @(negedge clk); rom_addr = 10'd520;
        repeat (2) @(posedge clk); #1;
        if (rom_dout !== 8'h18)
            $display("  FAIL font ROM 'A' row 0: got %h, expected 18", rom_dout);
        if (rom_dout !== 8'h18) errors = errors + 1;

        // Row 3 of 'A' is 0x66, and row 4 is 0x7E (the crossbar).
        @(negedge clk); rom_addr = 10'd524;
        repeat (2) @(posedge clk); #1;
        if (rom_dout !== 8'h7E)
            $display("  FAIL font ROM 'A' row 4: got %h, expected 7E", rom_dout);
        if (rom_dout !== 8'h7E) errors = errors + 1;

        // Character 0 has no glyph: all its rows are zero.
        @(negedge clk); rom_addr = 10'd0;
        repeat (2) @(posedge clk); #1;
        if (rom_dout !== 8'h00) fail("font ROM char 0 should be blank");

        // ===== 5. the framebuffer =========================================
        // Write three pixels at awkward coordinates and read them back.
        @(negedge clk); fb_wx = 7'd0;  fb_wy = 6'd0;  fb_wpix = 1; fb_we = 1;
        @(negedge clk); fb_wx = 7'd95; fb_wy = 6'd63; fb_wpix = 1;
        @(negedge clk); fb_wx = 7'd50; fb_wy = 6'd30; fb_wpix = 1;
        @(negedge clk); fb_we = 0;

        @(negedge clk); fb_rx = 7'd0;  fb_ry = 6'd0;
        repeat (2) @(posedge clk); #1;
        if (fb_rpix !== 1'b1) fail("framebuffer lost the pixel at (0,0)");

        @(negedge clk); fb_rx = 7'd95; fb_ry = 6'd63;
        repeat (2) @(posedge clk); #1;
        if (fb_rpix !== 1'b1) fail("framebuffer lost the pixel at (95,63)");

        @(negedge clk); fb_rx = 7'd50; fb_ry = 6'd30;
        repeat (2) @(posedge clk); #1;
        if (fb_rpix !== 1'b1) fail("framebuffer lost the pixel at (50,30)");

        // Now the aliasing check: an address calculation that maps two
        // coordinates onto one location would have corrupted a neighbour.
        // (1,0) and (0,1) are the classic pair to get wrong.
        //
        // These are written to 0 EXPLICITLY rather than assumed to be 0.
        // Uninitialised memory reads as X in simulation -- the ECP5 happens to
        // zero block RAM from the bitstream, but Verilog does not promise it,
        // and a test that relies on it is testing the simulator. (An earlier
        // version of this file did exactly that and failed here.)
        @(negedge clk); fb_wx = 7'd1; fb_wy = 6'd0; fb_wpix = 0; fb_we = 1;
        @(negedge clk); fb_wx = 7'd0; fb_wy = 6'd1; fb_wpix = 0;
        @(negedge clk); fb_we = 0;

        @(negedge clk); fb_rx = 7'd1; fb_ry = 6'd0;
        repeat (2) @(posedge clk); #1;
        if (fb_rpix !== 1'b0) fail("framebuffer aliased (1,0) onto a written pixel");

        @(negedge clk); fb_rx = 7'd0; fb_ry = 6'd1;
        repeat (2) @(posedge clk); #1;
        if (fb_rpix !== 1'b0) fail("framebuffer aliased (0,1) onto a written pixel");

        // And (0,0) is still set, so the zero-writes above did not clobber it.
        @(negedge clk); fb_rx = 7'd0; fb_ry = 6'd0;
        repeat (2) @(posedge clk); #1;
        if (fb_rpix !== 1'b1) fail("framebuffer lost (0,0) when neighbours were cleared");

        // ===== 6. the hardware self-test passes in simulation too ==========
        @(negedge clk); mt_start = 1;
        @(negedge clk); mt_start = 0;
        // 128 words: 128 writes + 2 clocks per read. Allow plenty.
        for (i = 0; i < 2000 && !mt_done; i = i + 1) @(posedge clk);
        #1;
        if (!mt_done)        fail("mem_test never finished");
        else if (!mt_pass)   $display("  FAIL mem_test reported %0d errors", mt_errors);
        if (mt_done && !mt_pass) errors = errors + 1;

        if (errors == 0)
            $display("PASS: sync read has 1-cycle latency, dual-port reads and writes are independent, font ROM matches font.hex, framebuffer round-trips coordinates, self-test clean");
        else
            $display("FAIL: %0d checks wrong", errors);
        $finish;
    end
endmodule
