{
  "version": "1.2",
  "package": {
    "name": "seg7",
    "version": "1.0",
    "description": "Lesson 02 - a 7-segment hex decoder: 4 bits in, 7 segments out.",
    "author": "ULX3S Digital Design Course",
    "image": ""
  },
  "design": {
    "board": "ulx3s-85f",
    "graph": {
      "blocks": [
        {
          "id": "d440a4d8-c00d-43c8-b6ea-6a05e917b0e5",
          "type": "basic.input",
          "data": {
            "name": "hex (slide switches)",
            "pins": [
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
            "range": "[3:0]"
          },
          "position": {
            "x": 48,
            "y": 48
          }
        },
        {
          "id": "e3e388d3-8f62-4ff3-9f6e-3b23070c4bb2",
          "type": "basic.output",
          "data": {
            "name": "seg (abcdefg)",
            "pins": [
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
            "range": "[6:0]"
          },
          "position": {
            "x": 816,
            "y": 48
          }
        },
        {
          "id": "51194180-7f06-4048-800a-3aebf9bff9b3",
          "type": "basic.code",
          "data": {
            "code": "                           // always @(*) \u2014 it is not a register\nalways @(*) begin\n    case (hex)\n        //                   abcdefg\n        4'h0: seg = 7'b1111110;\n        4'h1: seg = 7'b0110000;\n        4'h2: seg = 7'b1101101;\n        4'h3: seg = 7'b1111001;\n        4'h4: seg = 7'b0110011;\n        4'h5: seg = 7'b1011011;\n        4'h6: seg = 7'b1011111;\n        4'h7: seg = 7'b1110000;\n        4'h8: seg = 7'b1111111;\n        4'h9: seg = 7'b1111011;\n        4'hA: seg = 7'b1110111;\n        4'hB: seg = 7'b0011111;   // lowercase b: 8 and B would be identical\n        4'hC: seg = 7'b1001110;\n        4'hD: seg = 7'b0111101;   // lowercase d, for the same reason\n        4'hE: seg = 7'b1001111;\n        4'hF: seg = 7'b1000111;\n        // Every one of the 16 cases is covered, so this `default` can\n        // never fire. It is here anyway, because a combinational `always`\n        // block that does not assign on every path infers a LATCH \u2014 a\n        // storage element with no clock, which is almost never what you\n        // meant. Make the default a reflex; `make lint` will tell you when\n        // you forget.\n        default: seg = 7'b0000000;\n    endcase\nend\n",
            "params": [],
            "ports": {
              "in": [
                {
                  "name": "hex",
                  "range": "[3:0]",
                  "size": 4
                }
              ],
              "out": [
                {
                  "name": "seg",
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
          "id": "a0031377-4dd2-49f3-8c75-a880831146ab",
          "type": "basic.info",
          "data": {
            "info": "## Lesson 02 - the hex decoder\n\nSet the four slide switches to a hex digit and read the segment pattern on `led[6:0]`, in the order `abcdefg`:\n\n```\n     aaaa        led_6 = a   top\n    f    b       led_5 = b   top right\n    f    b       led_4 = c   bottom right\n     gggg        led_3 = d   bottom\n    e    c       led_2 = e   bottom left\n    e    c       led_1 = f   top left\n     dddd        led_0 = g   middle\n```\n\nSwitches at `1010` (hex A) should give `1110111`.\n\n### The thing to notice\n\nThe code block holds a 16-way `case`. The lesson's `seg7_rom` module expresses the identical truth table as an array of constants instead - and both cost exactly **7 LUT4**. A `case` is not 'logic' and an array is not 'memory'; both describe a function of four inputs, and only the function survives.\n\n### Why this block and not the whole lesson\n\nAn Icestudio code block cannot instantiate other modules, so the lesson's `comb_top` (which wires seg7, an adder and a mux together) cannot be generated as one block. Composing modules is what the Icestudio canvas itself is for - that is the next step, and lesson 03 starts putting reusable blocks in `icestudio/collections/`.",
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
            "block": "d440a4d8-c00d-43c8-b6ea-6a05e917b0e5",
            "port": "out"
          },
          "target": {
            "block": "51194180-7f06-4048-800a-3aebf9bff9b3",
            "port": "hex"
          },
          "size": 4
        },
        {
          "source": {
            "block": "51194180-7f06-4048-800a-3aebf9bff9b3",
            "port": "seg"
          },
          "target": {
            "block": "e3e388d3-8f62-4ff3-9f6e-3b23070c4bb2",
            "port": "in"
          },
          "size": 7
        }
      ]
    }
  },
  "dependencies": {}
}
