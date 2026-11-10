// stage01 — SSD1331 color OLED (96x64, RGB565) over SPI.
// Concepts: an FSM sequenced from a ROM, a bit-shifting SPI engine,
// and pixels computed on the fly (no framebuffer).
//
// Flow: hold reset low -> wait -> stream init bytes (DC=0) from ROM,
// ending with the column/row window commands -> stream pixel data
// (DC=1) forever. A frame counter animates the blue channel.
module oled_top (
    input  wire clk_25mhz,
    output wire oled_csn,
    output reg  oled_resn = 0,
    output reg  oled_dc   = 0,
    output reg  oled_clk  = 0,
    output reg  oled_mosi = 0,
    output wire [7:0] led
);
    assign oled_csn = 1'b0;          // sole device on the bus: keep selected

    // ---------------- init ROM: SSD1331 datasheet power-up sequence ----------
    localparam ROM_LEN = 31;
    reg [7:0] rom [0:ROM_LEN-1];
    initial begin
        rom[ 0]=8'hAE;                            // display off
        rom[ 1]=8'hA0; rom[ 2]=8'h72;             // remap: RGB order, 65k color
        rom[ 3]=8'hA1; rom[ 4]=8'h00;             // start line 0
        rom[ 5]=8'hA2; rom[ 6]=8'h00;             // display offset 0
        rom[ 7]=8'hA4;                            // normal display
        rom[ 8]=8'hA8; rom[ 9]=8'h3F;             // multiplex 1/64
        rom[10]=8'hAD; rom[11]=8'h8E;             // master configuration
        rom[12]=8'hB0; rom[13]=8'h0B;             // power save off
        rom[14]=8'hB1; rom[15]=8'h31;             // phase 1/2 period
        rom[16]=8'hB3; rom[17]=8'hF0;             // display clock divide
        rom[18]=8'hBB; rom[19]=8'h3A;             // precharge level
        rom[20]=8'hBE; rom[21]=8'h3E;             // VCOMH
        rom[22]=8'h87; rom[23]=8'h06;             // master current
        rom[24]=8'hAF;                            // display ON
        rom[25]=8'h15; rom[26]=8'h00; rom[27]=8'h5F; // column window 0..95
        rom[28]=8'h75; rom[29]=8'h00; rom[30]=8'h3F; // row window 0..63
    end

    // ---------------- byte-level SPI engine (mode 3-ish, MSB first) ----------
    // Each bit takes 4 system clocks -> SCLK = 6.25 MHz (SSD1331 max ~6.6 MHz).
    reg  [7:0] shift;
    reg  [1:0] phase = 0;
    reg  [2:0] bitn  = 0;
    reg        busy  = 0;
    reg        start = 0;
    reg  [7:0] data;

    always @(posedge clk_25mhz) begin
        if (!busy) begin
            if (start) begin
                shift <= data; busy <= 1; phase <= 0; bitn <= 0;
            end
        end else begin
            phase <= phase + 1'b1;
            case (phase)
                2'd0: begin oled_clk <= 0; oled_mosi <= shift[7]; end
                2'd2: oled_clk <= 1;
                2'd3: begin
                    shift <= {shift[6:0], 1'b0};
                    bitn  <= bitn + 1'b1;
                    if (bitn == 3'd7) busy <= 0;
                end
            endcase
        end
    end

    // ---------------- top-level sequencer ------------------------------------
    localparam S_RESET = 0, S_WAIT = 1, S_INIT = 2, S_PIXEL = 3;
    reg [1:0]  state = S_RESET;
    reg [15:0] wait_cnt = 0;
    reg [4:0]  rom_i = 0;

    reg [6:0] x = 0;                 // 0..95
    reg [5:0] y = 0;                 // 0..63
    reg [7:0] frame = 0;
    reg       lohi = 0;              // which half of the 16-bit pixel

    // RGB565 gradient: red follows x, green follows y, blue breathes per frame
    wire [15:0] pixel = { x[6:2], y[5:0], frame[7:3] };

    always @(posedge clk_25mhz) begin
        start <= 0;
        case (state)
            S_RESET: begin
                oled_resn <= 0;
                wait_cnt <= wait_cnt + 1'b1;
                if (&wait_cnt[11:0]) begin oled_resn <= 1; state <= S_WAIT; wait_cnt <= 0; end
            end
            S_WAIT: begin                        // let the chip wake after reset
                wait_cnt <= wait_cnt + 1'b1;
                if (&wait_cnt) state <= S_INIT;  // ~2.6 ms
            end
            S_INIT: if (!busy && !start) begin
                oled_dc <= 0;
                data    <= rom[rom_i];
                start   <= 1;
                if (rom_i == ROM_LEN-1) state <= S_PIXEL;
                rom_i   <= rom_i + 1'b1;
            end
            S_PIXEL: if (!busy && !start) begin
                oled_dc <= 1;
                data    <= lohi ? pixel[7:0] : pixel[15:8];
                start   <= 1;
                lohi    <= ~lohi;
                if (lohi) begin                  // finished low byte -> next pixel
                    if (x == 7'd95) begin
                        x <= 0;
                        if (y == 6'd63) begin y <= 0; frame <= frame + 1'b1; end
                        else            y <= y + 1'b1;
                    end else x <= x + 1'b1;
                end
            end
        endcase
    end

    assign led = {state, frame[7:2]};   // debug: state + frame counter
endmodule
