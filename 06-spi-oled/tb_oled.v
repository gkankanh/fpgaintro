`timescale 1ns/1ps
// Testbench: act like an SSD1331. Sample MOSI on rising SCLK, rebuild the
// byte stream, and check three things:
//   1. reset pulse precedes any clocking
//   2. the 31 init bytes arrive exactly as the datasheet sequence, all DC=0
//   3. pixel data follows with DC=1, first pixels matching the gradient
module tb_oled;
    reg clk = 0;
    always #20 clk = ~clk;   // 25 MHz

    wire csn, resn, dc, sclk, mosi;
    wire [7:0] led;
    oled_top dut (.clk_25mhz(clk), .oled_csn(csn), .oled_resn(resn),
                  .oled_dc(dc), .oled_clk(sclk), .oled_mosi(mosi), .led(led));

    // expected init sequence (keep in sync with the datasheet, not the DUT!)
    reg [7:0] expect_rom [0:30];
    initial begin
        expect_rom[0]=8'hAE;  expect_rom[1]=8'hA0;  expect_rom[2]=8'h72;
        expect_rom[3]=8'hA1;  expect_rom[4]=8'h00;  expect_rom[5]=8'hA2;
        expect_rom[6]=8'h00;  expect_rom[7]=8'hA4;  expect_rom[8]=8'hA8;
        expect_rom[9]=8'h3F;  expect_rom[10]=8'hAD; expect_rom[11]=8'h8E;
        expect_rom[12]=8'hB0; expect_rom[13]=8'h0B; expect_rom[14]=8'hB1;
        expect_rom[15]=8'h31; expect_rom[16]=8'hB3; expect_rom[17]=8'hF0;
        expect_rom[18]=8'hBB; expect_rom[19]=8'h3A; expect_rom[20]=8'hBE;
        expect_rom[21]=8'h3E; expect_rom[22]=8'h87; expect_rom[23]=8'h06;
        expect_rom[24]=8'hAF; expect_rom[25]=8'h15; expect_rom[26]=8'h00;
        expect_rom[27]=8'h5F; expect_rom[28]=8'h75; expect_rom[29]=8'h00;
        expect_rom[30]=8'h3F;
    end

    integer nbyte = 0, errors = 0, nbits = 0;
    reg [7:0] cur = 0;
    reg resn_released = 0, clocked_before_reset = 0;

    always @(posedge resn) resn_released = 1;   // resn starts low at power-on
    always @(posedge sclk) begin
        if (!resn_released || !resn) clocked_before_reset = 1;
        cur = {cur[6:0], mosi};
        nbits = nbits + 1;
        if (nbits == 8) begin
            nbits = 0;
            if (nbyte < 31) begin
                if (cur !== expect_rom[nbyte]) begin
                    errors = errors + 1;
                    $display("  init byte %0d: got %02x want %02x", nbyte, cur, expect_rom[nbyte]);
                end
                if (dc !== 1'b0) begin errors = errors + 1;
                    $display("  init byte %0d: DC high", nbyte); end
            end else begin
                if (dc !== 1'b1) begin errors = errors + 1;
                    $display("  data byte %0d: DC low", nbyte-31); end
                // pixel 0 is x=0,y=0,frame=0 -> 0x0000; pixel 4 (x=4) -> red bit
                if (nbyte == 31 && cur !== 8'h00) begin errors = errors + 1;
                    $display("  first data byte: got %02x want 00", cur); end
                if (nbyte == 39 && cur !== {5'd1, 3'd0}) begin  // x=4: r5=1 -> hi byte 0x08
                    errors = errors + 1;
                    $display("  pixel x=4 hi byte: got %02x want 08", cur);
                end
            end
            nbyte = nbyte + 1;
        end
    end

    initial begin
        $dumpfile("oled.vcd");
        $dumpvars(0, tb_oled);
        // reset(4096) + wait(65536) + 51 bytes * 32 clks ~ 72k clocks
        repeat (75000) @(posedge clk);
        if (clocked_before_reset) begin errors = errors + 1;
            $display("  SCLK active before/during reset"); end
        if (nbyte < 51) begin errors = errors + 1;
            $display("  only %0d bytes seen, want >= 51", nbyte); end
        if (errors == 0) $display("PASS: %0d bytes, init sequence + pixel stream OK", nbyte);
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end
endmodule
