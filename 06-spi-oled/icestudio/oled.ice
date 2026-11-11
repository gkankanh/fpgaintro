{
  "version": "1.2",
  "package": {
    "name": "oled",
    "version": "1.0",
    "description": "Lesson 06 - SPI engine, SSD1331 init ROM, computed gradient.",
    "author": "The Open FPGA Course",
    "image": ""
  },
  "design": {
    "board": "ulx3s-85f",
    "graph": {
      "blocks": [
        {
          "id": "bb2ce448-238e-54c3-9c6c-487d6316734a",
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
          "id": "e2d5d638-9c0c-59da-b9e2-5ee70f4b9f96",
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
          "id": "15b273ec-2a10-5fd5-9696-7b57bf266a51",
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
          "id": "98d02e9c-801e-5cd8-892e-f2bfb66ab44f",
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
          "id": "4e94dfa9-0159-5273-934f-6c43b5c7ecd8",
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
          "id": "382db84d-b598-552d-8902-5a2c910f587c",
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
          "id": "d2d16822-550e-5826-8e67-b21ddb4bfda5",
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
          "id": "32d184d0-ff49-520a-81a8-5a1b4f6772ff",
          "type": "basic.code",
          "data": {
            "code": "assign oled_csn = 1'b0;          // sole device on the bus: keep selected\n\n// ---------------- init ROM: SSD1331 datasheet power-up sequence ----------\nlocalparam ROM_LEN = 31;\nreg [7:0] rom [0:ROM_LEN-1];\ninitial begin\n    rom[ 0]=8'hAE;                            // display off\n    rom[ 1]=8'hA0; rom[ 2]=8'h72;             // remap: RGB order, 65k color\n    rom[ 3]=8'hA1; rom[ 4]=8'h00;             // start line 0\n    rom[ 5]=8'hA2; rom[ 6]=8'h00;             // display offset 0\n    rom[ 7]=8'hA4;                            // normal display\n    rom[ 8]=8'hA8; rom[ 9]=8'h3F;             // multiplex 1/64\n    rom[10]=8'hAD; rom[11]=8'h8E;             // master configuration\n    rom[12]=8'hB0; rom[13]=8'h0B;             // power save off\n    rom[14]=8'hB1; rom[15]=8'h31;             // phase 1/2 period\n    rom[16]=8'hB3; rom[17]=8'hF0;             // display clock divide\n    rom[18]=8'hBB; rom[19]=8'h3A;             // precharge level\n    rom[20]=8'hBE; rom[21]=8'h3E;             // VCOMH\n    rom[22]=8'h87; rom[23]=8'h06;             // master current\n    rom[24]=8'hAF;                            // display ON\n    rom[25]=8'h15; rom[26]=8'h00; rom[27]=8'h5F; // column window 0..95\n    rom[28]=8'h75; rom[29]=8'h00; rom[30]=8'h3F; // row window 0..63\nend\n\n// ---------------- byte-level SPI engine (mode 3-ish, MSB first) ----------\n// Each bit takes 4 system clocks -> SCLK = 6.25 MHz (SSD1331 max ~6.6 MHz).\nreg  [7:0] shift;\nreg  [1:0] phase = 0;\nreg  [2:0] bitn  = 0;\nreg        busy  = 0;\nreg        start = 0;\nreg  [7:0] data;\n\nalways @(posedge clk_25mhz) begin\n    if (!busy) begin\n        if (start) begin\n            shift <= data; busy <= 1; phase <= 0; bitn <= 0;\n        end\n    end else begin\n        phase <= phase + 1'b1;\n        case (phase)\n            2'd0: begin oled_clk <= 0; oled_mosi <= shift[7]; end\n            2'd2: oled_clk <= 1;\n            2'd3: begin\n                shift <= {shift[6:0], 1'b0};\n                bitn  <= bitn + 1'b1;\n                if (bitn == 3'd7) busy <= 0;\n            end\n            // Phase 1 deliberately does nothing: it is the setup time\n            // between driving MOSI and raising SCLK. Stated explicitly\n            // because an unlisted case is how you accidentally forget one.\n            //\n            // Note this is safe in a way the same omission would not be in\n            // a combinational block: this block is clocked, so \"no\n            // assignment\" means the registers hold \u2014 it is not a latch.\n            default: ;\n        endcase\n    end\nend\n\n// ---------------- top-level sequencer ------------------------------------\nlocalparam S_RESET = 0, S_WAIT = 1, S_INIT = 2, S_PIXEL = 3;\nreg [1:0]  state = S_RESET;\nreg [15:0] wait_cnt = 0;\nreg [4:0]  rom_i = 0;\n\nreg [6:0] x = 0;                 // 0..95\nreg [5:0] y = 0;                 // 0..63\nreg [7:0] frame = 0;\nreg       lohi = 0;              // which half of the 16-bit pixel\n\n// RGB565 gradient: red follows x, green follows y, blue breathes per frame\nwire [15:0] pixel = { x[6:2], y[5:0], frame[7:3] };\n\nalways @(posedge clk_25mhz) begin\n    start <= 0;\n    case (state)\n        S_RESET: begin\n            oled_resn <= 0;\n            wait_cnt <= wait_cnt + 1'b1;\n            if (&wait_cnt[11:0]) begin oled_resn <= 1; state <= S_WAIT; wait_cnt <= 0; end\n        end\n        S_WAIT: begin                        // let the chip wake after reset\n            wait_cnt <= wait_cnt + 1'b1;\n            if (&wait_cnt) state <= S_INIT;  // ~2.6 ms\n        end\n        S_INIT: if (!busy && !start) begin\n            oled_dc <= 0;\n            data    <= rom[rom_i];\n            start   <= 1;\n            if (rom_i == ROM_LEN-1) state <= S_PIXEL;\n            rom_i   <= rom_i + 1'b1;\n        end\n        S_PIXEL: if (!busy && !start) begin\n            oled_dc <= 1;\n            data    <= lohi ? pixel[7:0] : pixel[15:8];\n            start   <= 1;\n            lohi    <= ~lohi;\n            if (lohi) begin                  // finished low byte -> next pixel\n                if (x == 7'd95) begin\n                    x <= 0;\n                    if (y == 6'd63) begin y <= 0; frame <= frame + 1'b1; end\n                    else            y <= y + 1'b1;\n                end else x <= x + 1'b1;\n            end\n        end\n    endcase\nend\n\nassign led = {state, frame[7:2]};   // debug: state + frame counter\n",
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
                  "name": "oled_resn"
                },
                {
                  "name": "oled_dc"
                },
                {
                  "name": "oled_clk"
                },
                {
                  "name": "oled_mosi"
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
          "id": "a2bc74a9-3cb0-5b11-9c43-6303dd580689",
          "type": "basic.info",
          "data": {
            "info": "## Lesson 06 - SPI and the OLED\n\nThree pieces stacked:\n\n1. a **bit-level SPI engine** - 4 system clocks per bit, so SCLK = 6.25 MHz\n2. a **31-byte init ROM** from the SSD1331 datasheet\n3. a **pixel source** that computes each pixel from its coordinate\n\nThe only interface between (1) and (3) is the `busy`/`start` handshake, which is why the sequencer needs to know nothing about SPI timing.\n\nThere is no framebuffer: the SSD1331 auto-increments its own address pointer, so the design only has to emit bytes in raster order.",
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
            "block": "bb2ce448-238e-54c3-9c6c-487d6316734a",
            "port": "out"
          },
          "target": {
            "block": "32d184d0-ff49-520a-81a8-5a1b4f6772ff",
            "port": "clk_25mhz"
          }
        },
        {
          "source": {
            "block": "32d184d0-ff49-520a-81a8-5a1b4f6772ff",
            "port": "oled_csn"
          },
          "target": {
            "block": "e2d5d638-9c0c-59da-b9e2-5ee70f4b9f96",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "32d184d0-ff49-520a-81a8-5a1b4f6772ff",
            "port": "oled_resn"
          },
          "target": {
            "block": "15b273ec-2a10-5fd5-9696-7b57bf266a51",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "32d184d0-ff49-520a-81a8-5a1b4f6772ff",
            "port": "oled_dc"
          },
          "target": {
            "block": "98d02e9c-801e-5cd8-892e-f2bfb66ab44f",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "32d184d0-ff49-520a-81a8-5a1b4f6772ff",
            "port": "oled_clk"
          },
          "target": {
            "block": "4e94dfa9-0159-5273-934f-6c43b5c7ecd8",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "32d184d0-ff49-520a-81a8-5a1b4f6772ff",
            "port": "oled_mosi"
          },
          "target": {
            "block": "382db84d-b598-552d-8902-5a2c910f587c",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "32d184d0-ff49-520a-81a8-5a1b4f6772ff",
            "port": "led"
          },
          "target": {
            "block": "d2d16822-550e-5826-8e67-b21ddb4bfda5",
            "port": "in"
          },
          "size": 8
        }
      ]
    }
  },
  "dependencies": {}
}
