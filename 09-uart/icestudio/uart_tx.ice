{
  "version": "1.2",
  "package": {
    "name": "uart_tx",
    "version": "1.0",
    "description": "Lesson 09 - the UART transmitter: a shift register and a modulus.",
    "author": "The Open FPGA Course",
    "image": ""
  },
  "design": {
    "board": "ulx3s-85f",
    "graph": {
      "blocks": [
        {
          "id": "1956dbad-f0d0-57af-a607-6dd9a9e62f2e",
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
          "id": "e69927a2-b522-54e7-a9d8-f84f70a568f2",
          "type": "basic.input",
          "data": {
            "name": "start (press)",
            "pins": [
              {
                "index": "0",
                "name": "btn_1",
                "value": "R1"
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
          "id": "72067d1d-a1c7-5dd8-92d1-2fa890ce354a",
          "type": "basic.input",
          "data": {
            "name": "data (buttons = high nibble, switches = low)",
            "pins": [
              {
                "index": "7",
                "name": "btn_6",
                "value": "H16"
              },
              {
                "index": "6",
                "name": "btn_5",
                "value": "U1"
              },
              {
                "index": "5",
                "name": "btn_4",
                "value": "V1"
              },
              {
                "index": "4",
                "name": "btn_3",
                "value": "R18"
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
            "range": "[7:0]"
          },
          "position": {
            "x": 48,
            "y": 288
          }
        },
        {
          "id": "4c372c59-e148-56af-8f50-2ef4e838dadd",
          "type": "basic.output",
          "data": {
            "name": "tx -> host",
            "pins": [
              {
                "index": "0",
                "name": "ftdi_rxd",
                "value": "L4"
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
          "id": "fdc6034f-f0c4-58af-8fff-e7b1a104289b",
          "type": "basic.output",
          "data": {
            "name": "busy",
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
            "y": 168
          }
        },
        {
          "id": "e2b32098-c8c2-5b96-ba07-27f895ddfe80",
          "type": "basic.code",
          "data": {
            "code": "// ---------------------------------------------------------------\n// Added by tools/mkice.py, not present in the lesson's .v:\n// Icestudio declares a code block's outputs as wires, and the\n// board has fewer pins than this module has port bits. See\n// icestudio/README.md. The module's own text below is verbatim.\n// ---------------------------------------------------------------\nreg busy = 0;\n\nlocalparam integer DIV = CLK_HZ / BAUD;\nlocalparam integer CW  = $clog2(DIV);\n\n// Sized explicitly, so the comparison below is not a 32-bit integer\n// against an 8-bit counter. Widen then slice, rather than relying on an\n// implicit narrowing -- lesson 08's lesson, and lesson 02's before it.\nlocalparam [31:0]   DIV_W    = DIV - 1;\nlocalparam [CW-1:0] DIV_LAST = DIV_W[CW-1:0];\n\nreg [CW-1:0] cnt   = 0;\nreg [3:0]    bitn  = 0;\nreg [9:0]    shift = 10'h3FF;   // all ones: the idle line\n\n// The whole frame lives in one shift register, and the output is simply\n// its low bit. Loading {stop, data, start} means shift[0] is the start bit\n// immediately, and once the frame has been shifted out the register is all\n// ones again -- so the line returns to idle with no special case.\nassign tx = shift[0];\n\nalways @(posedge clk)\n    if (!busy) begin\n        if (start) begin\n            shift <= {1'b1, data, 1'b0};   // stop, 8 data (LSB first), start\n            cnt   <= 0;\n            bitn  <= 0;\n            busy  <= 1;\n        end\n    end else if (cnt == DIV_LAST) begin\n        cnt   <= 0;\n        shift <= {1'b1, shift[9:1]};       // shift right, ones trailing in\n        bitn  <= bitn + 1'b1;\n        if (bitn == 4'd9) busy <= 0;       // start + 8 data + stop = 10\n    end else\n        cnt <= cnt + 1'b1;\n\n// ---- added by tools/mkice.py: port aliases and probes ----\nassign busy_o = busy;\n",
            "params": [
              {
                "name": "CLK_HZ"
              },
              {
                "name": "BAUD"
              }
            ],
            "ports": {
              "in": [
                {
                  "name": "clk"
                },
                {
                  "name": "start"
                },
                {
                  "name": "data",
                  "range": "[7:0]",
                  "size": 8
                }
              ],
              "out": [
                {
                  "name": "tx"
                },
                {
                  "name": "busy_o"
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
          "id": "0a18324e-f2dc-5687-8b4a-1f90536e03f9",
          "type": "basic.constant",
          "data": {
            "name": "CLK_HZ",
            "value": "25000000",
            "local": false
          },
          "position": {
            "x": 416,
            "y": -112
          }
        },
        {
          "id": "9db75b7c-8a45-5c50-a105-91caf5d729a7",
          "type": "basic.constant",
          "data": {
            "name": "BAUD",
            "value": "115200",
            "local": false
          },
          "position": {
            "x": 416,
            "y": -192
          }
        },
        {
          "id": "d80f9548-152b-5c2f-bbff-8c0645200cba",
          "type": "basic.info",
          "data": {
            "info": "## Lesson 09 - the UART transmitter\n\nThe whole 8N1 frame lives in one 10-bit shift register, loaded as `{stop, data, start}`, and the output is simply its low bit. Ones trail in from the top, so when the frame finishes the register is all ones again and the line returns to idle with **no special case for idle at all**.\n\n### Baud rate is a counter modulus\n\n```\n25,000,000 / 115,200 = 217.0139\n```\n\nSo DIV = 217, giving 115,207 baud - 0.0064% fast, which over 9.5 bit periods is 0.06% of a bit. Nothing.\n\n### Try it\n\nChange `BAUD` on the constant block to 9600 and rebuild, then open your terminal at 9600. Same design, different modulus.\n\nThe data byte is split across the board: the four direction buttons are the high nibble, the four slide switches the low nibble. So holding UP with switch 0 on sends 0x11.\n\nAn earlier version of this spec bound the same four switches to *both* nibbles. That cannot work, and it is worth knowing why: Icestudio writes one `LOCATE COMP` per port bit, so a repeated pin names the same FPGA ball twice in the .lpf, and nextpnr stops with `cannot be bound to bel ... already bound`. `tools/mkice.py` now refuses it at generation time.",
            "readonly": true
          },
          "position": {
            "x": 48,
            "y": 472
          }
        }
      ],
      "wires": [
        {
          "source": {
            "block": "0a18324e-f2dc-5687-8b4a-1f90536e03f9",
            "port": "constant-out"
          },
          "target": {
            "block": "e2b32098-c8c2-5b96-ba07-27f895ddfe80",
            "port": "CLK_HZ"
          }
        },
        {
          "source": {
            "block": "9db75b7c-8a45-5c50-a105-91caf5d729a7",
            "port": "constant-out"
          },
          "target": {
            "block": "e2b32098-c8c2-5b96-ba07-27f895ddfe80",
            "port": "BAUD"
          }
        },
        {
          "source": {
            "block": "1956dbad-f0d0-57af-a607-6dd9a9e62f2e",
            "port": "out"
          },
          "target": {
            "block": "e2b32098-c8c2-5b96-ba07-27f895ddfe80",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "e69927a2-b522-54e7-a9d8-f84f70a568f2",
            "port": "out"
          },
          "target": {
            "block": "e2b32098-c8c2-5b96-ba07-27f895ddfe80",
            "port": "start"
          }
        },
        {
          "source": {
            "block": "72067d1d-a1c7-5dd8-92d1-2fa890ce354a",
            "port": "out"
          },
          "target": {
            "block": "e2b32098-c8c2-5b96-ba07-27f895ddfe80",
            "port": "data"
          },
          "size": 8
        },
        {
          "source": {
            "block": "e2b32098-c8c2-5b96-ba07-27f895ddfe80",
            "port": "tx"
          },
          "target": {
            "block": "4c372c59-e148-56af-8f50-2ef4e838dadd",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "e2b32098-c8c2-5b96-ba07-27f895ddfe80",
            "port": "busy_o"
          },
          "target": {
            "block": "fdc6034f-f0c4-58af-8fff-e7b1a104289b",
            "port": "in"
          }
        }
      ]
    }
  },
  "dependencies": {}
}
