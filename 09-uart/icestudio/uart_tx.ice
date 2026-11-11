{
  "version": "1.2",
  "package": {
    "name": "uart_tx",
    "version": "1.0",
    "description": "Lesson 09 - the UART transmitter: a shift register and a modulus.",
    "author": "ULX3S Digital Design Course",
    "image": ""
  },
  "design": {
    "board": "ulx3s-85f",
    "graph": {
      "blocks": [
        {
          "id": "2f59d107-499d-4936-aea9-4829d7669672",
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
          "id": "d9ab4922-8863-4933-8bb9-068453eae46d",
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
          "id": "df07ce3c-1680-430d-8923-3dcd5f6ae0df",
          "type": "basic.input",
          "data": {
            "name": "data (slide switches)",
            "pins": [
              {
                "index": "7",
                "name": "sw_3",
                "value": "E7"
              },
              {
                "index": "6",
                "name": "sw_2",
                "value": "D7"
              },
              {
                "index": "5",
                "name": "sw_1",
                "value": "D8"
              },
              {
                "index": "4",
                "name": "sw_0",
                "value": "E8"
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
          "id": "fbe235a4-ab4f-4682-9368-c9979d6d1c17",
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
          "id": "1e66cd99-8876-4528-9722-13ef339193ed",
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
          "id": "d9d711da-fbf9-44b8-af53-523e7320266d",
          "type": "basic.code",
          "data": {
            "code": "localparam integer DIV = CLK_HZ / BAUD;\nlocalparam integer CW  = $clog2(DIV);\n\n// Sized explicitly, so the comparison below is not a 32-bit integer\n// against an 8-bit counter. Widen then slice, rather than relying on an\n// implicit narrowing -- lesson 08's lesson, and lesson 02's before it.\nlocalparam [31:0]   DIV_W    = DIV - 1;\nlocalparam [CW-1:0] DIV_LAST = DIV_W[CW-1:0];\n\nreg [CW-1:0] cnt   = 0;\nreg [3:0]    bitn  = 0;\nreg [9:0]    shift = 10'h3FF;   // all ones: the idle line\n\n// The whole frame lives in one shift register, and the output is simply\n// its low bit. Loading {stop, data, start} means shift[0] is the start bit\n// immediately, and once the frame has been shifted out the register is all\n// ones again -- so the line returns to idle with no special case.\nassign tx = shift[0];\n\nalways @(posedge clk)\n    if (!busy) begin\n        if (start) begin\n            shift <= {1'b1, data, 1'b0};   // stop, 8 data (LSB first), start\n            cnt   <= 0;\n            bitn  <= 0;\n            busy  <= 1;\n        end\n    end else if (cnt == DIV_LAST) begin\n        cnt   <= 0;\n        shift <= {1'b1, shift[9:1]};       // shift right, ones trailing in\n        bitn  <= bitn + 1'b1;\n        if (bitn == 4'd9) busy <= 0;       // start + 8 data + stop = 10\n    end else\n        cnt <= cnt + 1'b1;\n",
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
                  "name": "busy"
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
          "id": "642f6073-0369-4c10-a568-f354514f8200",
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
          "id": "378656bf-91fe-4be2-80ff-64c56a000af6",
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
          "id": "46d97ee2-77d0-4ed8-b1cc-51f08b4156a4",
          "type": "basic.info",
          "data": {
            "info": "## Lesson 09 - the UART transmitter\n\nThe whole 8N1 frame lives in one 10-bit shift register, loaded as `{stop, data, start}`, and the output is simply its low bit. Ones trail in from the top, so when the frame finishes the register is all ones again and the line returns to idle with **no special case for idle at all**.\n\n### Baud rate is a counter modulus\n\n```\n25,000,000 / 115,200 = 217.0139\n```\n\nSo DIV = 217, giving 115,207 baud - 0.0064% fast, which over 9.5 bit periods is 0.06% of a bit. Nothing.\n\n### Try it\n\nChange `BAUD` on the constant block to 9600 and rebuild, then open your terminal at 9600. Same design, different modulus.\n\nThe slide switches are wired to the data byte twice (high nibble and low nibble), so four switches set a repeating byte - enough to see something arrive.",
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
            "block": "642f6073-0369-4c10-a568-f354514f8200",
            "port": "constant-out"
          },
          "target": {
            "block": "d9d711da-fbf9-44b8-af53-523e7320266d",
            "port": "CLK_HZ"
          }
        },
        {
          "source": {
            "block": "378656bf-91fe-4be2-80ff-64c56a000af6",
            "port": "constant-out"
          },
          "target": {
            "block": "d9d711da-fbf9-44b8-af53-523e7320266d",
            "port": "BAUD"
          }
        },
        {
          "source": {
            "block": "2f59d107-499d-4936-aea9-4829d7669672",
            "port": "out"
          },
          "target": {
            "block": "d9d711da-fbf9-44b8-af53-523e7320266d",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "d9ab4922-8863-4933-8bb9-068453eae46d",
            "port": "out"
          },
          "target": {
            "block": "d9d711da-fbf9-44b8-af53-523e7320266d",
            "port": "start"
          }
        },
        {
          "source": {
            "block": "df07ce3c-1680-430d-8923-3dcd5f6ae0df",
            "port": "out"
          },
          "target": {
            "block": "d9d711da-fbf9-44b8-af53-523e7320266d",
            "port": "data"
          },
          "size": 8
        },
        {
          "source": {
            "block": "d9d711da-fbf9-44b8-af53-523e7320266d",
            "port": "tx"
          },
          "target": {
            "block": "fbe235a4-ab4f-4682-9368-c9979d6d1c17",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "d9d711da-fbf9-44b8-af53-523e7320266d",
            "port": "busy"
          },
          "target": {
            "block": "1e66cd99-8876-4528-9722-13ef339193ed",
            "port": "in"
          }
        }
      ]
    }
  },
  "dependencies": {}
}
