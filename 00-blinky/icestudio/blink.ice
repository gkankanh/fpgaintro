{
  "version": "1.2",
  "package": {
    "name": "blink",
    "version": "1.0",
    "description": "Lesson 00 - a counter divides 25 MHz down to human speed.",
    "author": "The Open FPGA Course",
    "image": ""
  },
  "design": {
    "board": "ulx3s-85f",
    "graph": {
      "blocks": [
        {
          "id": "738a7b4f-66f5-5954-8acd-8e7b9c1607a2",
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
          "id": "5811d654-9003-51ad-b284-4e4589e2654c",
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
            "y": 48
          }
        },
        {
          "id": "6898b8ce-2223-5b31-8543-3db3b7deedd8",
          "type": "basic.code",
          "data": {
            "code": "reg [WIDTH-1:0] count = 0;\nalways @(posedge clk_25mhz)\n    count <= count + 1'b1;\nassign led = count[WIDTH-1 -: 8];   // top 8 bits: binary odometer\n",
            "params": [
              {
                "name": "WIDTH"
              }
            ],
            "ports": {
              "in": [
                {
                  "name": "clk_25mhz"
                }
              ],
              "out": [
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
          "id": "e50fcf39-6194-52c4-b615-160d15b833f5",
          "type": "basic.constant",
          "data": {
            "name": "WIDTH",
            "value": "26",
            "local": false
          },
          "position": {
            "x": 416,
            "y": -112
          }
        },
        {
          "id": "71f6b647-c44d-5886-82d1-58a21b074b9c",
          "type": "basic.info",
          "data": {
            "info": "## Lesson 00 - blinky\n\nThe 25 MHz board clock is far too fast to see. A **counter** is a frequency divider: bit *n* of a counter toggles every 2^n clocks. Tapping the top 8 bits gives a binary odometer slow enough to watch.\n\n- `WIDTH` = 26, so bit 25 toggles about every 1.3 s.\n- Change `WIDTH` on the constant block and rebuild to speed it up or slow it down.\n\nThis is the same logic as `blink.v` in the lesson folder - the code block body is generated from it, so both paths describe one design.",
            "readonly": true
          },
          "position": {
            "x": 48,
            "y": 232
          }
        }
      ],
      "wires": [
        {
          "source": {
            "block": "e50fcf39-6194-52c4-b615-160d15b833f5",
            "port": "constant-out"
          },
          "target": {
            "block": "6898b8ce-2223-5b31-8543-3db3b7deedd8",
            "port": "WIDTH"
          }
        },
        {
          "source": {
            "block": "738a7b4f-66f5-5954-8acd-8e7b9c1607a2",
            "port": "out"
          },
          "target": {
            "block": "6898b8ce-2223-5b31-8543-3db3b7deedd8",
            "port": "clk_25mhz"
          }
        },
        {
          "source": {
            "block": "6898b8ce-2223-5b31-8543-3db3b7deedd8",
            "port": "led"
          },
          "target": {
            "block": "5811d654-9003-51ad-b284-4e4589e2654c",
            "port": "in"
          },
          "size": 8
        }
      ]
    }
  },
  "dependencies": {}
}
