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
          "id": "75fe531a-d74c-44de-b9dd-352c92a489f1",
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
          "id": "8deb903a-1917-4cd1-a085-b6d3cc8f0681",
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
          "id": "bc8e5530-bc7b-48da-846e-f1ad293166a2",
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
          "id": "3126e0f4-5588-471f-a0c5-bf7e60eac8e6",
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
          "id": "fa8b7860-9837-476d-907b-5937debc87e8",
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
          "id": "4cf6624b-6c77-4cd1-aba2-730a09d1d27a",
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
          "id": "e0e00dee-3f3a-45da-b80f-a8fceac7da99",
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
          "id": "28bdeb8a-3c45-4916-9118-e1611cacb9ec",
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
          "id": "36a13813-de83-4d69-819b-bef41037f9ea",
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
            "block": "e0e00dee-3f3a-45da-b80f-a8fceac7da99",
            "port": "constant-out"
          },
          "target": {
            "block": "4cf6624b-6c77-4cd1-aba2-730a09d1d27a",
            "port": "CLK_HZ"
          }
        },
        {
          "source": {
            "block": "28bdeb8a-3c45-4916-9118-e1611cacb9ec",
            "port": "constant-out"
          },
          "target": {
            "block": "4cf6624b-6c77-4cd1-aba2-730a09d1d27a",
            "port": "BAUD"
          }
        },
        {
          "source": {
            "block": "75fe531a-d74c-44de-b9dd-352c92a489f1",
            "port": "out"
          },
          "target": {
            "block": "4cf6624b-6c77-4cd1-aba2-730a09d1d27a",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "8deb903a-1917-4cd1-a085-b6d3cc8f0681",
            "port": "out"
          },
          "target": {
            "block": "4cf6624b-6c77-4cd1-aba2-730a09d1d27a",
            "port": "start"
          }
        },
        {
          "source": {
            "block": "bc8e5530-bc7b-48da-846e-f1ad293166a2",
            "port": "out"
          },
          "target": {
            "block": "4cf6624b-6c77-4cd1-aba2-730a09d1d27a",
            "port": "data"
          },
          "size": 8
        },
        {
          "source": {
            "block": "4cf6624b-6c77-4cd1-aba2-730a09d1d27a",
            "port": "tx"
          },
          "target": {
            "block": "3126e0f4-5588-471f-a0c5-bf7e60eac8e6",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "4cf6624b-6c77-4cd1-aba2-730a09d1d27a",
            "port": "busy"
          },
          "target": {
            "block": "fa8b7860-9837-476d-907b-5937debc87e8",
            "port": "in"
          }
        }
      ]
    }
  },
  "dependencies": {}
}
