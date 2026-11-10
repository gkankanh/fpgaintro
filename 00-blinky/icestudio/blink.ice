{
  "version": "1.2",
  "package": {
    "name": "blink",
    "version": "1.0",
    "description": "Lesson 00 - a counter divides 25 MHz down to human speed.",
    "author": "ULX3S Digital Design Course",
    "image": ""
  },
  "design": {
    "board": "ulx3s-85f",
    "graph": {
      "blocks": [
        {
          "id": "a3c99092-162c-42a9-a0bc-271e3c7c92d5",
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
          "id": "17dd9059-f827-49f6-ac63-f292440e86e3",
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
          "id": "7617efd4-2bbd-4341-a6ff-2349310f34ec",
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
          "id": "a11299fc-ccac-479a-82d9-304c51450214",
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
          "id": "cbfd43b1-9b34-44db-a9b1-e0ff4508a5ed",
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
            "block": "a11299fc-ccac-479a-82d9-304c51450214",
            "port": "constant-out"
          },
          "target": {
            "block": "7617efd4-2bbd-4341-a6ff-2349310f34ec",
            "port": "WIDTH"
          }
        },
        {
          "source": {
            "block": "a3c99092-162c-42a9-a0bc-271e3c7c92d5",
            "port": "out"
          },
          "target": {
            "block": "7617efd4-2bbd-4341-a6ff-2349310f34ec",
            "port": "clk_25mhz"
          }
        },
        {
          "source": {
            "block": "7617efd4-2bbd-4341-a6ff-2349310f34ec",
            "port": "led"
          },
          "target": {
            "block": "17dd9059-f827-49f6-ac63-f292440e86e3",
            "port": "in"
          },
          "size": 8
        }
      ]
    }
  },
  "dependencies": {}
}
