{
  "version": "1.2",
  "package": {
    "name": "font",
    "version": "1.0",
    "description": "Lesson 08 - a 32x8 ROM, addressed by hand: four glyphs, eight rows each, read out on the LEDs.",
    "author": "The Open FPGA Course",
    "image": ""
  },
  "design": {
    "board": "ulx3s-85f",
    "graph": {
      "blocks": [
        {
          "id": "aeb440d2-1cb4-5451-82ef-14085ec0b38a",
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
          "id": "944dfe1a-6f8e-52ad-9eff-8876f652ee64",
          "type": "basic.input",
          "data": {
            "name": "addr: FIRE2+sw3 = glyph, sw2..sw0 = row",
            "pins": [
              {
                "index": "4",
                "name": "btn_2",
                "value": "T1"
              },
              {
                "index": "3",
                "name": "sw_3",
                "value": "E7"
              },
              {
                "index": "2",
                "name": "sw_2",
                "value": "D7"
              },
              {
                "index": "1",
                "name": "sw_1",
                "value": "D8"
              },
              {
                "index": "0",
                "name": "sw_0",
                "value": "E8"
              }
            ],
            "virtual": false,
            "range": "[4:0]"
          },
          "position": {
            "x": 48,
            "y": 168
          }
        },
        {
          "id": "f86f5ac5-3142-5cec-ba4b-65d57f679939",
          "type": "basic.output",
          "data": {
            "name": "dout (one glyph row)",
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
            "y": 48
          }
        },
        {
          "id": "017e7754-5253-546e-912a-968515323bb9",
          "type": "basic.code",
          "data": {
            "code": "// ---------------------------------------------------------------\n// Added by tools/mkice.py, not present in the lesson's .v:\n// Icestudio declares a code block's outputs as wires, and the\n// board has fewer pins than this module has port bits. See\n// icestudio/README.md. The module's own text below is verbatim.\n// ---------------------------------------------------------------\nreg [7:0] dout;\n\nreg [7:0] mem [0:31];\ninitial begin                   // glyph 0: H\n    mem[ 0]=8'h66; mem[ 1]=8'h66; mem[ 2]=8'h66; mem[ 3]=8'h7E;\n    mem[ 4]=8'h66; mem[ 5]=8'h66; mem[ 6]=8'h66; mem[ 7]=8'h00;\n    mem[ 8]=8'h7E; mem[ 9]=8'h60; mem[10]=8'h60; mem[11]=8'h7C; // E\n    mem[12]=8'h60; mem[13]=8'h60; mem[14]=8'h7E; mem[15]=8'h00;\n    mem[16]=8'h60; mem[17]=8'h60; mem[18]=8'h60; mem[19]=8'h60; // L\n    mem[20]=8'h60; mem[21]=8'h60; mem[22]=8'h7E; mem[23]=8'h00;\n    mem[24]=8'h3C; mem[25]=8'h66; mem[26]=8'h66; mem[27]=8'h66; // O\n    mem[28]=8'h66; mem[29]=8'h66; mem[30]=8'h3C; mem[31]=8'h00;\nend\nalways @(posedge clk)\n    dout <= mem[addr];\n\n// ---- added by tools/mkice.py: port aliases and probes ----\nassign dout_o = dout;\n",
            "params": [],
            "ports": {
              "in": [
                {
                  "name": "clk"
                },
                {
                  "name": "addr",
                  "range": "[4:0]",
                  "size": 5
                }
              ],
              "out": [
                {
                  "name": "dout_o",
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
          "id": "96cd088c-9b44-5bf1-a4d7-fd4a87ee45e0",
          "type": "basic.info",
          "data": {
            "info": "## Lesson 08 - read a ROM with your fingers\n\nThe same 32-entry font ROM lesson 07 reads at 25 MHz, addressed by hand instead. `addr[4:3]` picks the glyph and `addr[2:0]` picks the row, so:\n\n| FIRE2 | sw3 | glyph |\n|---|---|---|\n| released | 0 | **H** |\n| released | 1 | **E** |\n| held | 0 | **L** |\n| held | 1 | **O** |\n\nHold FIRE2 for the second pair, then walk `sw2..sw0` through 0..7 and read the glyph off the LEDs one row at a time. The H really is there in the lights \u2014 rows 0 to 3 are `01100110`, `01100110`, `01100110`, `01111110`: two uprights, then the crossbar.\n\n### The point\n\n`always @(posedge clk) dout <= mem[addr];` is the shape that *can* become block RAM: a registered read, one address, no asynchronous path from `addr` to `dout`. The shape gives yosys the choice. The size decides which way it jumps, and the measured numbers are the argument:\n\n| module | contents | synth_ecp5 gives |\n|---|---|---|\n| `font_small` | 32 x 8 = 256 bits | 9 LUT4 + 4 PFUMX + 5 FF, **no** block RAM |\n| `font_full` | 1024 x 8 = 8 Kbit | **1 DP16KD**, and no LUTs at all |\n\nSo this project's ROM is built out of logic, because 256 bits inside an 18 Kbit block RAM would waste 98% of it. Lesson 07's full font gets the block RAM instead, from the same five lines of Verilog.\n\nChange the *shape*, though, and the choice disappears. `assign dout = mem[addr];` asks for an asynchronous read, which a DP16KD cannot do at any size, so even `font_full` would come back as a mountain of LUTs. That one clock of latency is what you are paying for the memory \u2014 and it is why lesson 16's pipeline needs a fetch stage of its own.",
            "readonly": true
          },
          "position": {
            "x": 48,
            "y": 352
          }
        }
      ],
      "wires": [
        {
          "source": {
            "block": "aeb440d2-1cb4-5451-82ef-14085ec0b38a",
            "port": "out"
          },
          "target": {
            "block": "017e7754-5253-546e-912a-968515323bb9",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "944dfe1a-6f8e-52ad-9eff-8876f652ee64",
            "port": "out"
          },
          "target": {
            "block": "017e7754-5253-546e-912a-968515323bb9",
            "port": "addr"
          },
          "size": 5
        },
        {
          "source": {
            "block": "017e7754-5253-546e-912a-968515323bb9",
            "port": "dout_o"
          },
          "target": {
            "block": "f86f5ac5-3142-5cec-ba4b-65d57f679939",
            "port": "in"
          },
          "size": 8
        }
      ]
    }
  },
  "dependencies": {}
}
