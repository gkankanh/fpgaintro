{
  "version": "1.2",
  "package": {
    "name": "text",
    "version": "1.0",
    "description": "Lesson 07 - HELLO on the OLED: a font ROM and per-pixel coordinate math, with no framebuffer.",
    "author": "The Open FPGA Course",
    "image": ""
  },
  "design": {
    "board": "ulx3s-85f",
    "graph": {
      "blocks": [
        {
          "id": "f0468f1d-44ce-5434-83d8-8f637f6f2ece",
          "type": "basic.input",
          "data": {
            "name": "clk_25mhz",
            "pins": [
              {
                "index": "0",
                "name": "clk",
                "value": "G2"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 48,
            "y": 48
          }
        },
        {
          "id": "af0785b8-8d36-55f3-a5b0-0e9d011d2a65",
          "type": "basic.output",
          "data": {
            "name": "oled_csn",
            "pins": [
              {
                "index": "0",
                "name": "oled_csn",
                "value": "N2"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 816,
            "y": 48
          }
        },
        {
          "id": "4759101a-a4e2-5c32-9f1a-a501e6a15cb2",
          "type": "basic.output",
          "data": {
            "name": "oled_resn",
            "pins": [
              {
                "index": "0",
                "name": "oled_resn",
                "value": "P2"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 816,
            "y": 168
          }
        },
        {
          "id": "d294d3ab-43e5-5fac-b061-8c1ca50c29f7",
          "type": "basic.output",
          "data": {
            "name": "oled_dc",
            "pins": [
              {
                "index": "0",
                "name": "oled_dc",
                "value": "P1"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 816,
            "y": 288
          }
        },
        {
          "id": "895507ca-b686-5871-b25d-10e5bc91cab7",
          "type": "basic.output",
          "data": {
            "name": "oled_clk",
            "pins": [
              {
                "index": "0",
                "name": "oled_clk",
                "value": "P4"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 816,
            "y": 408
          }
        },
        {
          "id": "ae6ef0a6-03bd-5e2e-a8b3-1214a0e1956f",
          "type": "basic.output",
          "data": {
            "name": "oled_mosi",
            "pins": [
              {
                "index": "0",
                "name": "oled_mosi",
                "value": "P3"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 816,
            "y": 528
          }
        },
        {
          "id": "353d7233-8cde-5a0c-a2a4-83db8db7f23a",
          "type": "basic.output",
          "data": {
            "name": "led",
            "pins": [
              {
                "index": "7",
                "name": "led_7",
                "value": "H3"
              },
              {
                "index": "6",
                "name": "led_6",
                "value": "E1"
              },
              {
                "index": "5",
                "name": "led_5",
                "value": "E2"
              },
              {
                "index": "4",
                "name": "led_4",
                "value": "D1"
              },
              {
                "index": "3",
                "name": "led_3",
                "value": "D2"
              },
              {
                "index": "2",
                "name": "led_2",
                "value": "C1"
              },
              {
                "index": "1",
                "name": "led_1",
                "value": "C2"
              },
              {
                "index": "0",
                "name": "led_0",
                "value": "B2"
              }
            ],
            "virtual": false,
            "range": "[7:0]"
          },
          "position": {
            "x": 816,
            "y": 648
          }
        },
        {
          "id": "9ea27ae5-80f9-523a-9173-401139f58d7d",
          "type": "basic.code",
          "data": {
            "code": "// ---------------------------------------------------------------\n// Added by tools/mkice.py, not present in the lesson's .v:\n// Icestudio declares a code block's outputs as wires, and the\n// board has fewer pins than this module has port bits. See\n// icestudio/README.md. The module's own text below is verbatim.\n// ---------------------------------------------------------------\nreg oled_resn = 0;\nreg oled_dc = 0;\nreg oled_clk = 0;\nreg oled_mosi = 0;\n\nassign oled_csn = 1'b0;          // sole device on the bus: keep selected\n\n// ---------------- init ROM: SSD1331 datasheet power-up sequence ----------\nlocalparam ROM_LEN = 31;\nreg [7:0] rom [0:ROM_LEN-1];\ninitial begin\n    rom[ 0]=8'hAE;                            // display off\n    rom[ 1]=8'hA0; rom[ 2]=8'h72;             // remap: RGB order, 65k color\n    rom[ 3]=8'hA1; rom[ 4]=8'h00;             // start line 0\n    rom[ 5]=8'hA2; rom[ 6]=8'h00;             // display offset 0\n    rom[ 7]=8'hA4;                            // normal display\n    rom[ 8]=8'hA8; rom[ 9]=8'h3F;             // multiplex 1/64\n    rom[10]=8'hAD; rom[11]=8'h8E;             // master configuration\n    rom[12]=8'hB0; rom[13]=8'h0B;             // power save off\n    rom[14]=8'hB1; rom[15]=8'h31;             // phase 1/2 period\n    rom[16]=8'hB3; rom[17]=8'hF0;             // display clock divide\n    rom[18]=8'hBB; rom[19]=8'h3A;             // precharge level\n    rom[20]=8'hBE; rom[21]=8'h3E;             // VCOMH\n    rom[22]=8'h87; rom[23]=8'h06;             // master current\n    rom[24]=8'hAF;                            // display ON\n    rom[25]=8'h15; rom[26]=8'h00; rom[27]=8'h5F; // column window 0..95\n    rom[28]=8'h75; rom[29]=8'h00; rom[30]=8'h3F; // row window 0..63\nend\n\n// ---------------- byte-level SPI engine (mode 3-ish, MSB first) ----------\n// Each bit takes 4 system clocks -> SCLK = 6.25 MHz (SSD1331 max ~6.6 MHz).\nreg  [7:0] shift;\nreg  [1:0] phase = 0;\nreg  [2:0] bitn  = 0;\nreg        busy  = 0;\nreg        start = 0;\nreg  [7:0] data;\n\nalways @(posedge clk_25mhz) begin\n    if (!busy) begin\n        if (start) begin\n            shift <= data; busy <= 1; phase <= 0; bitn <= 0;\n        end\n    end else begin\n        phase <= phase + 1'b1;\n        case (phase)\n            2'd0: begin oled_clk <= 0; oled_mosi <= shift[7]; end\n            2'd2: oled_clk <= 1;\n            2'd3: begin\n                shift <= {shift[6:0], 1'b0};\n                bitn  <= bitn + 1'b1;\n                if (bitn == 3'd7) busy <= 0;\n            end\n            default: ;      // phase 1 idles: MOSI setup time. See lesson 06.\n        endcase\n    end\nend\n\n// ---------------- top-level sequencer ------------------------------------\nlocalparam S_RESET = 0, S_WAIT = 1, S_INIT = 2, S_PIXEL = 3;\nreg [1:0]  state = S_RESET;\nreg [15:0] wait_cnt = 0;\nreg [4:0]  rom_i = 0;\n\nreg [6:0] x = 0;                 // 0..95\nreg [5:0] y = 0;                 // 0..63\nreg [7:0] frame = 0;\nreg       lohi = 0;              // which half of the 16-bit pixel\n\n// ---------------- font ROM: 8x8 glyphs for H,E,L,O ----------------------\nreg [7:0] font [0:31];          // 4 glyphs x 8 rows, bit7 = leftmost pixel\ninitial begin                   // glyph 0: H\n    font[ 0]=8'h66; font[ 1]=8'h66; font[ 2]=8'h66; font[ 3]=8'h7E;\n    font[ 4]=8'h66; font[ 5]=8'h66; font[ 6]=8'h66; font[ 7]=8'h00;\n    font[ 8]=8'h7E; font[ 9]=8'h60; font[10]=8'h60; font[11]=8'h7C; // E\n    font[12]=8'h60; font[13]=8'h60; font[14]=8'h7E; font[15]=8'h00;\n    font[16]=8'h60; font[17]=8'h60; font[18]=8'h60; font[19]=8'h60; // L\n    font[20]=8'h60; font[21]=8'h60; font[22]=8'h7E; font[23]=8'h00;\n    font[24]=8'h3C; font[25]=8'h66; font[26]=8'h66; font[27]=8'h66; // O\n    font[28]=8'h66; font[29]=8'h66; font[30]=8'h3C; font[31]=8'h00;\nend\n\n// \"HELLO\": 5 chars, 16px each = 80px wide at x 8..87, 16px tall at y 24..39\nwire in_text = (x >= 7'd8) && (x < 7'd88) && (y >= 6'd24) && (y < 6'd40);\nwire [6:0] tx = x - 7'd8;                    // 0..79 inside the text band\n// tx[0] is intentionally never read: the 2x scale means each font column\n// covers two screen pixels, so the column select is tx[3:1] and the low\n// bit is discarded. Told to verilator explicitly rather than waived\n// globally, because an unused bit is usually a mistake.\n/* verilator lint_off UNUSEDSIGNAL */\nwire _tx_lsb_unused = tx[0];\n/* verilator lint_on UNUSEDSIGNAL */\nwire [2:0] ci = tx[6:4];                     // character cell 0..4\nwire [1:0] glyph = (ci == 3'd0) ? 2'd0 :     // H\n                   (ci == 3'd1) ? 2'd1 :     // E\n                   (ci == 3'd4) ? 2'd3 :     // O\n                                  2'd2 ;     // L, L\nwire [2:0] frow = y[3:1] - 3'd4;             // (y-24)/2 within 0..7\nwire [2:0] fcol = tx[3:1];                   // (tx/2) & 7\nwire font_bit = font[{glyph, frow}][3'd7 - fcol];\n\n// white text over the animated gradient background\nwire [15:0] bg    = { x[6:2], y[5:0], frame[7:3] };\nwire [15:0] pixel = (in_text && font_bit) ? 16'hFFFF : bg;\n\nalways @(posedge clk_25mhz) begin\n    start <= 0;\n    case (state)\n        S_RESET: begin\n            oled_resn <= 0;\n            wait_cnt <= wait_cnt + 1'b1;\n            if (&wait_cnt[11:0]) begin oled_resn <= 1; state <= S_WAIT; wait_cnt <= 0; end\n        end\n        S_WAIT: begin                        // let the chip wake after reset\n            wait_cnt <= wait_cnt + 1'b1;\n            if (&wait_cnt) state <= S_INIT;  // ~2.6 ms\n        end\n        S_INIT: if (!busy && !start) begin\n            oled_dc <= 0;\n            data    <= rom[rom_i];\n            start   <= 1;\n            if (rom_i == ROM_LEN-1) state <= S_PIXEL;\n            rom_i   <= rom_i + 1'b1;\n        end\n        S_PIXEL: if (!busy && !start) begin\n            oled_dc <= 1;\n            data    <= lohi ? pixel[7:0] : pixel[15:8];\n            start   <= 1;\n            lohi    <= ~lohi;\n            if (lohi) begin                  // finished low byte -> next pixel\n                if (x == 7'd95) begin\n                    x <= 0;\n                    if (y == 6'd63) begin y <= 0; frame <= frame + 1'b1; end\n                    else            y <= y + 1'b1;\n                end else x <= x + 1'b1;\n            end\n        end\n    endcase\nend\n\nassign led = {state, frame[7:2]};   // debug: state + frame counter\n\n// ---- added by tools/mkice.py: port aliases and probes ----\nassign oled_resn_o = oled_resn;\nassign oled_dc_o = oled_dc;\nassign oled_clk_o = oled_clk;\nassign oled_mosi_o = oled_mosi;\n",
            "params": [],
            "ports": {
              "in": [
                {
                  "name": "clk_25mhz"
                }
              ],
              "out": [
                {
                  "name": "oled_csn"
                },
                {
                  "name": "oled_resn_o"
                },
                {
                  "name": "oled_dc_o"
                },
                {
                  "name": "oled_clk_o"
                },
                {
                  "name": "oled_mosi_o"
                },
                {
                  "name": "led",
                  "range": "[7:0]",
                  "size": 8
                }
              ]
            }
          },
          "position": {
            "x": 384,
            "y": 48
          }
        },
        {
          "id": "1b5b1aad-4806-5218-8410-b8b3d0740aaa",
          "type": "basic.info",
          "data": {
            "info": "## Lesson 07 - a font ROM, and no framebuffer\n\nLesson 06 computed each pixel from its coordinate. This does the same thing, but the function now includes a **lookup**: given (x, y), work out which glyph covers that pixel, which of its 8 rows, and which of its 8 columns, then read the row out of the font ROM and test one bit.\n\n```\nglyph = (x - X0) >> 4        two-times scaling, so 16 px per glyph\ncol   = ((x - X0) >> 1) & 7\nrow   = ((y - Y0) >> 1) & 7\npixel = font[{glyph, row}][7 - col]\n```\n\nA 96x64 framebuffer would be 6144 bits of block RAM. The ROM is 32 bytes. That is the whole argument for computing pixels instead of storing them, and it is why this fits in a lesson rather than a chapter.\n\n### What to look for\n\nThe `basic.code` block has one input and six outputs, and all the structure is in the body \u2014 because at this size the structure *is* arithmetic, and arithmetic is the one thing a schematic shows worse than text. Lesson 08 is where the memory arrives and the picture gets interesting again.",
            "readonly": true
          },
          "position": {
            "x": 48,
            "y": 832
          }
        }
      ],
      "wires": [
        {
          "source": {
            "block": "f0468f1d-44ce-5434-83d8-8f637f6f2ece",
            "port": "out"
          },
          "target": {
            "block": "9ea27ae5-80f9-523a-9173-401139f58d7d",
            "port": "clk_25mhz"
          }
        },
        {
          "source": {
            "block": "9ea27ae5-80f9-523a-9173-401139f58d7d",
            "port": "oled_csn"
          },
          "target": {
            "block": "af0785b8-8d36-55f3-a5b0-0e9d011d2a65",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "9ea27ae5-80f9-523a-9173-401139f58d7d",
            "port": "oled_resn_o"
          },
          "target": {
            "block": "4759101a-a4e2-5c32-9f1a-a501e6a15cb2",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "9ea27ae5-80f9-523a-9173-401139f58d7d",
            "port": "oled_dc_o"
          },
          "target": {
            "block": "d294d3ab-43e5-5fac-b061-8c1ca50c29f7",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "9ea27ae5-80f9-523a-9173-401139f58d7d",
            "port": "oled_clk_o"
          },
          "target": {
            "block": "895507ca-b686-5871-b25d-10e5bc91cab7",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "9ea27ae5-80f9-523a-9173-401139f58d7d",
            "port": "oled_mosi_o"
          },
          "target": {
            "block": "ae6ef0a6-03bd-5e2e-a8b3-1214a0e1956f",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "9ea27ae5-80f9-523a-9173-401139f58d7d",
            "port": "led"
          },
          "target": {
            "block": "353d7233-8cde-5a0c-a2a4-83db8db7f23a",
            "port": "in"
          },
          "size": 8
        }
      ]
    }
  },
  "dependencies": {}
}
