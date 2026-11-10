`timescale 1ns/1ps
// Lesson 04 — board demo: three clock domains on one chip.
//
//   clk_25mhz   the crystal, straight from pin G2
//   clk_100mhz  from the PLL
//   clk_40mhz   from the PLL (generated, unused here — see the exercises)
//
// What you see: led[3:0] counts at one rate and led[7:4] at four times that
// rate, from the same counter width. That visible difference IS the PLL.
//
// What you cannot see: whether the clock-domain crossing is correct. That is
// the point of the lesson — the failure mode is probabilistic and invisible,
// which is why the defence is structural rather than empirical.
module clocks_top (
    input  wire       clk_25mhz,
    input  wire [2:1] btn,
    output wire [7:0] led
);
    // --- the PLL -----------------------------------------------------------
    wire clk_100mhz, clk_40mhz, locked;
    pll u_pll (
        .clk_25mhz (clk_25mhz),
        .clk_100mhz(clk_100mhz),
        .clk_40mhz (clk_40mhz),
        .locked    (locked)
    );

    // `locked` is asynchronous to everything, so it gets synchronised into the
    // domain that uses it. Logic in a PLL domain must be held in reset until
    // the loop has settled, or it runs on a clock that is still wandering.
    wire rst_100;
    sync2 u_sync_rst (.clk(clk_100mhz), .d_async(~locked), .q(rst_100));

    // --- a counter in each domain ------------------------------------------
    reg [23:0] count_25  = 0;
    reg [23:0] count_100 = 0;

    always @(posedge clk_25mhz)
        count_25 <= count_25 + 1'b1;

    always @(posedge clk_100mhz)
        if (rst_100) count_100 <= 0;
        else         count_100 <= count_100 + 1'b1;

    // --- cross a value between the domains ---------------------------------
    // The 25 MHz counter's top byte is handed to the 100 MHz domain, once per
    // wrap of its low 16 bits. src_valid is a single-clock pulse, and the gap
    // between pulses (65,536 clocks) is enormously longer than the two or
    // three destination clocks the handshake needs — the constraint cdc_bus
    // documents is satisfied by a wide margin.
    wire        tick_25 = (count_25[15:0] == 16'hFFFF);
    wire [7:0]  crossed;
    wire        crossed_valid;

    cdc_bus #(.W(8)) u_cdc (
        .src_clk   (clk_25mhz),
        .src_valid (tick_25),
        .src_data  (count_25[23:16]),
        .dst_clk   (clk_100mhz),
        .dst_data  (crossed),
        .dst_valid (crossed_valid)
    );

    // Count how many values have arrived, in the destination domain. If the
    // crossing works, this tracks the source counter exactly.
    reg [7:0] arrivals = 0;
    always @(posedge clk_100mhz)
        if (rst_100)            arrivals <= 0;
        else if (crossed_valid) arrivals <= arrivals + 1'b1;

    // --- what reaches the LEDs ---------------------------------------------
    // Released: the two counters side by side, so the 4x rate difference is
    // visible. Pressed: the crossed value next to the arrival count, which
    // should agree.
    assign led = btn[1] ? {crossed[3:0], arrivals[3:0]}
                        : {count_100[23:20], count_25[23:20]};

    // clk_40mhz is generated but unused in this build; see exercise 4.
    wire _unused = &{clk_40mhz, btn[2], 1'b0};
endmodule
