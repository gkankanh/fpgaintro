{
  "version": "1.2",
  "package": {
    "name": "shifter",
    "version": "1.0",
    "description": "Lesson 10 - the barrel shifter: one expression, three instructions, no clock.",
    "author": "The Open FPGA Course",
    "image": ""
  },
  "design": {
    "board": "ulx3s-85f",
    "graph": {
      "blocks": [
        {
          "id": "2dd0a500-44c4-5c78-89c3-e9d288ac6454",
          "type": "basic.input",
          "data": {
            "name": "sh (shift amount)",
            "pins": [
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
            "range": "[2:0]"
          },
          "position": {
            "x": 48,
            "y": 48
          }
        },
        {
          "id": "6632f2e2-7d9c-579a-bf81-9c67d9efb6da",
          "type": "basic.input",
          "data": {
            "name": "right (sw3)",
            "pins": [
              {
                "index": "0",
                "name": "sw_3",
                "value": "E7"
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
          "id": "06884253-ad0e-58cc-b7a3-1c7d23e96db9",
          "type": "basic.input",
          "data": {
            "name": "arith (hold FIRE2)",
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
          "id": "12ae74ff-de1f-53bb-8b0a-fec31bec4b7d",
          "type": "basic.output",
          "data": {
            "name": "y = a shifted",
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
          "id": "e871fc54-8fa9-5be8-b31c-c6fff3fccbde",
          "type": "basic.code",
          "data": {
            "code": "assign y = right ? (arith ? ($signed(a) >>> sh) : (a >> sh))\n                 : (a << sh);\n",
            "params": [
              {
                "name": "W"
              },
              {
                "name": "a"
              }
            ],
            "ports": {
              "in": [
                {
                  "name": "sh",
                  "range": "[2:0]",
                  "size": 3
                },
                {
                  "name": "right"
                },
                {
                  "name": "arith"
                }
              ],
              "out": [
                {
                  "name": "y",
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
          "id": "e99ff6c8-2a7a-55aa-982b-8e52872b7ada",
          "type": "basic.constant",
          "data": {
            "name": "W",
            "value": "8",
            "local": false
          },
          "position": {
            "x": 416,
            "y": -112
          }
        },
        {
          "id": "f8f44694-becd-55ec-a77f-6929b7137311",
          "type": "basic.constant",
          "data": {
            "name": "a",
            "value": "8'b10110010",
            "local": false
          },
          "position": {
            "x": 416,
            "y": -192
          }
        },
        {
          "id": "4c84b987-ed85-5822-bac3-282760c35422",
          "type": "basic.info",
          "data": {
            "info": "## Lesson 10 - a barrel shifter you can turn by hand\n\nThe whole module is one expression:\n\n```verilog\nassign y = right ? (arith ? ($signed(a) >>> sh) : (a >> sh))\n                 : (a << sh);\n```\n\nThree of RV32I's shifts - SLL, SRL and SRA - are that one line plus two control bits, and there is no clock anywhere in it. A barrel shifter is pure combinational logic: a tree of muxes, one level per bit of `sh`, which is why its cost grows as W log W and not W squared.\n\n### Turn it\n\n`a` is the constant `10110010`, editable on the canvas. Set `sw2..sw0` to the shift amount and watch the LEDs:\n\n- **sw3 down** - shift left. Zeros come in at the right.\n- **sw3 up** - shift right, zeros in at the left (SRL).\n- **sw3 up, holding FIRE2** - shift right *arithmetic* (SRA). Now the sign bit comes in instead, so `10110010` stays negative however far you shift it, and `11111111` is where it ends up.\n\nThat difference is the entire reason `$signed()` is in the expression, and the reason RV32I spends an instruction bit (`inst[30]`) distinguishing SRL from SRA.\n\n### Why the width is 8\n\nThe lesson's ALU is 32 bits wide; 32 inputs and 32 outputs is 64 pins the board does not have. At `W` = 8 the logic is identical and `sh` needs 3 bits instead of 5. The 32-bit version is verified in the editor path, where a testbench can drive all 32 bits at once: `cd 10-alu && make sim`.",
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
            "block": "e99ff6c8-2a7a-55aa-982b-8e52872b7ada",
            "port": "constant-out"
          },
          "target": {
            "block": "e871fc54-8fa9-5be8-b31c-c6fff3fccbde",
            "port": "W"
          }
        },
        {
          "source": {
            "block": "f8f44694-becd-55ec-a77f-6929b7137311",
            "port": "constant-out"
          },
          "target": {
            "block": "e871fc54-8fa9-5be8-b31c-c6fff3fccbde",
            "port": "a"
          }
        },
        {
          "source": {
            "block": "2dd0a500-44c4-5c78-89c3-e9d288ac6454",
            "port": "out"
          },
          "target": {
            "block": "e871fc54-8fa9-5be8-b31c-c6fff3fccbde",
            "port": "sh"
          },
          "size": 3
        },
        {
          "source": {
            "block": "6632f2e2-7d9c-579a-bf81-9c67d9efb6da",
            "port": "out"
          },
          "target": {
            "block": "e871fc54-8fa9-5be8-b31c-c6fff3fccbde",
            "port": "right"
          }
        },
        {
          "source": {
            "block": "06884253-ad0e-58cc-b7a3-1c7d23e96db9",
            "port": "out"
          },
          "target": {
            "block": "e871fc54-8fa9-5be8-b31c-c6fff3fccbde",
            "port": "arith"
          }
        },
        {
          "source": {
            "block": "e871fc54-8fa9-5be8-b31c-c6fff3fccbde",
            "port": "y"
          },
          "target": {
            "block": "12ae74ff-de1f-53bb-8b0a-fec31bec4b7d",
            "port": "in"
          },
          "size": 8
        }
      ]
    }
  },
  "dependencies": {}
}
