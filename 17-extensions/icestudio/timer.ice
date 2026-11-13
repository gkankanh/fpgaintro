{
  "version": "1.2",
  "package": {
    "name": "timer",
    "version": "1.0",
    "description": "Lesson 17 - the machine timer: a 64-bit counter, a comparator, and the interrupt that comes out of it.",
    "author": "The Open FPGA Course",
    "image": ""
  },
  "design": {
    "board": "ulx3s-85f",
    "graph": {
      "blocks": [
        {
          "id": "831f6b87-e6d1-53a2-b805-70e5015ea20d",
          "type": "basic.input",
          "data": {
            "name": "register: down = mtime, up = mtimecmp",
            "pins": [
              {
                "index": "0",
                "name": "sw_0",
                "value": "E8"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": -240,
            "y": 48
          }
        },
        {
          "id": "c1eb4854-b3c4-5918-8cbb-3cf5f8fe865c",
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
          "id": "b0fac8b9-c4e6-5772-a9d5-8409f30f5aec",
          "type": "basic.input",
          "data": {
            "name": "rst (press UP)",
            "pins": [
              {
                "index": "0",
                "name": "btn_3",
                "value": "R18"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 48,
            "y": 168
          }
        },
        {
          "id": "9ed64a3a-91b4-50a4-9685-2c13016522ef",
          "type": "basic.input",
          "data": {
            "name": "we (press FIRE2 to arm)",
            "pins": [
              {
                "index": "0",
                "name": "btn_2",
                "value": "T1"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 48,
            "y": 288
          }
        },
        {
          "id": "aa560680-4a74-53d4-875e-f0efcedfc858",
          "type": "basic.output",
          "data": {
            "name": "mtip",
            "pins": [
              {
                "index": "0",
                "name": "led_0",
                "value": "B2"
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
          "id": "d056851a-5830-5d8a-ad1a-2021c919458e",
          "type": "basic.output",
          "data": {
            "name": "rdata[31:25]",
            "pins": [
              {
                "index": "6",
                "name": "led_7",
                "value": "H3"
              },
              {
                "index": "5",
                "name": "led_6",
                "value": "E1"
              },
              {
                "index": "4",
                "name": "led_5",
                "value": "E2"
              },
              {
                "index": "3",
                "name": "led_4",
                "value": "D1"
              },
              {
                "index": "2",
                "name": "led_3",
                "value": "D2"
              },
              {
                "index": "1",
                "name": "led_2",
                "value": "C1"
              },
              {
                "index": "0",
                "name": "led_1",
                "value": "C2"
              }
            ],
            "virtual": false,
            "range": "[6:0]"
          },
          "position": {
            "x": 816,
            "y": 168
          }
        },
        {
          "id": "1e2118e5-c3b5-54e1-b2e1-79a2cce8b211",
          "type": "basic.code",
          "data": {
            "code": "// ---------------------------------------------------------------\n// Added by tools/mkice.py, not present in the lesson's .v:\n// Icestudio declares a code block's outputs as wires, and the\n// board has fewer pins than this module has port bits. See\n// icestudio/README.md. The module's own text below is verbatim.\n// ---------------------------------------------------------------\nwire [7:0] addr = asel ? 8'h08 : 8'h00;\nreg [31:0] rdata;\n\nreg [63:0] mtime    = 64'd0;\n// All ones, so that a machine that never arms the timer never takes a\n// timer interrupt. Zero would mean \"the deadline passed before reset\".\nreg [63:0] mtimecmp = {64{1'b1}};\n\nwire [1:0] reg_i = addr[3:2];\n\nlocalparam [1:0] R_TIME = 2'd0, R_TIMEH = 2'd1, R_CMP = 2'd2, R_CMPH = 2'd3;\n\nassign mtip = (mtime >= mtimecmp);\n\nalways @(posedge clk)\n    if (rst) begin\n        mtime    <= 64'd0;\n        mtimecmp <= {64{1'b1}};\n    end else begin\n        mtime <= mtime + 64'd1;\n\n        if (we)\n            case (reg_i)\n                // Writing mtime is allowed by the specification and is\n                // how a platform sets the clock. The increment above is\n                // overridden by this, which is the whole reason it is\n                // written as a separate statement first.\n                R_TIME:  mtime[31:0]     <= wdata;\n                R_TIMEH: mtime[63:32]    <= wdata;\n                R_CMP:   mtimecmp[31:0]  <= wdata;\n                R_CMPH:  mtimecmp[63:32] <= wdata;\n            endcase\n    end\n\nalways @(*)\n    case (reg_i)\n        R_TIME:  rdata = mtime[31:0];\n        R_TIMEH: rdata = mtime[63:32];\n        R_CMP:   rdata = mtimecmp[31:0];\n        R_CMPH:  rdata = mtimecmp[63:32];\n    endcase\n\nwire _unused = &{addr[7:4], addr[1:0], 1'b0};\n\n// ---- added by tools/mkice.py: port aliases and probes ----\nassign rd_hi = rdata[31:25];\n",
            "params": [
              {
                "name": "wdata"
              }
            ],
            "ports": {
              "in": [
                {
                  "name": "asel"
                },
                {
                  "name": "clk"
                },
                {
                  "name": "rst"
                },
                {
                  "name": "we"
                }
              ],
              "out": [
                {
                  "name": "mtip"
                },
                {
                  "name": "rd_hi",
                  "range": "[6:0]",
                  "size": 7
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
          "id": "7e347561-cc05-5910-851a-d530f38cf032",
          "type": "basic.constant",
          "data": {
            "name": "wdata",
            "value": "32'h40000000",
            "local": false
          },
          "position": {
            "x": 416,
            "y": -112
          }
        },
        {
          "id": "efffefba-c70a-5736-927d-6c920cd51e72",
          "type": "basic.info",
          "data": {
            "info": "## Lesson 17 - watch an interrupt become due\n\n`mtime` counts up once per clock and never stops. `mtimecmp` is a value you write. `mtip` is one comparison between them:\n\n```verilog\nassign mtip = (mtime >= mtimecmp);\n```\n\nThat is the entire timer interrupt. There is no edge, no latch, no pending bit to clear - just a comparator whose output happens to be wired into the trap logic.\n\n### Do this\n\n`mtimecmp` resets to all ones, which at 25 MHz is about 23,000 years away, so `mtip` starts dark.\n\n1. **sw0 down** - the port addresses `mtime`. LEDs 7..1 show `rdata[31:25]`, climbing: bit 25 flips every 1.34 s.\n2. **sw0 up, press FIRE2** - writes `0x40000000` into `mtimecmp`.\n3. **sw0 down** again and wait. `0x40000000` at 25 MHz is **43 seconds**; when `mtime` reaches it, **led0 lights** and stays lit.\n4. **Press UP** to reset. `mtime` goes back to 0, `mtimecmp` returns to all ones, and led0 goes out.\n\n### Why it stays lit\n\n`mtip` is `>=`, not `==`, and that is deliberate. An equality would be true for exactly one clock out of 2^64, so a core that happened to have interrupts disabled that cycle would miss the interrupt forever. With `>=` the condition is **level-triggered**: it stays asserted until software moves `mtimecmp` forward, which is exactly what a timer handler does as its last act. Missing it is not possible; ignoring it is a choice.\n\nThat is also why `rst` restores `mtimecmp` to all ones rather than zero. Reset to zero would mean `mtime >= mtimecmp` from the very first cycle, and the core would take a timer trap before it ever ran an instruction.",
            "readonly": true
          },
          "position": {
            "x": 48,
            "y": 592
          }
        }
      ],
      "wires": [
        {
          "source": {
            "block": "7e347561-cc05-5910-851a-d530f38cf032",
            "port": "constant-out"
          },
          "target": {
            "block": "1e2118e5-c3b5-54e1-b2e1-79a2cce8b211",
            "port": "wdata"
          }
        },
        {
          "source": {
            "block": "831f6b87-e6d1-53a2-b805-70e5015ea20d",
            "port": "out"
          },
          "target": {
            "block": "1e2118e5-c3b5-54e1-b2e1-79a2cce8b211",
            "port": "asel"
          }
        },
        {
          "source": {
            "block": "c1eb4854-b3c4-5918-8cbb-3cf5f8fe865c",
            "port": "out"
          },
          "target": {
            "block": "1e2118e5-c3b5-54e1-b2e1-79a2cce8b211",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "b0fac8b9-c4e6-5772-a9d5-8409f30f5aec",
            "port": "out"
          },
          "target": {
            "block": "1e2118e5-c3b5-54e1-b2e1-79a2cce8b211",
            "port": "rst"
          }
        },
        {
          "source": {
            "block": "9ed64a3a-91b4-50a4-9685-2c13016522ef",
            "port": "out"
          },
          "target": {
            "block": "1e2118e5-c3b5-54e1-b2e1-79a2cce8b211",
            "port": "we"
          }
        },
        {
          "source": {
            "block": "1e2118e5-c3b5-54e1-b2e1-79a2cce8b211",
            "port": "mtip"
          },
          "target": {
            "block": "aa560680-4a74-53d4-875e-f0efcedfc858",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "1e2118e5-c3b5-54e1-b2e1-79a2cce8b211",
            "port": "rd_hi"
          },
          "target": {
            "block": "d056851a-5830-5d8a-ad1a-2021c919458e",
            "port": "in"
          },
          "size": 7
        }
      ]
    }
  },
  "dependencies": {}
}
