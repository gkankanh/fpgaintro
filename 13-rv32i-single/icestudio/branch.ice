{
  "version": "1.2",
  "package": {
    "name": "branch",
    "version": "1.0",
    "description": "Lesson 13 - the branch unit: six conditions from three comparisons, and why signed is not unsigned.",
    "author": "The Open FPGA Course",
    "image": ""
  },
  "design": {
    "board": "ulx3s-85f",
    "graph": {
      "blocks": [
        {
          "id": "a48b1c25-55d5-5abc-bb79-768e6cd2bfdc",
          "type": "basic.input",
          "data": {
            "name": "rs1 (4-bit, sign-extended)",
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
            "x": -240,
            "y": 48
          }
        },
        {
          "id": "48365331-3baf-542a-92d7-670fc47f07b5",
          "type": "basic.input",
          "data": {
            "name": "funct3: LEFT DOWN UP",
            "pins": [
              {
                "index": "2",
                "name": "btn_5",
                "value": "U1"
              },
              {
                "index": "1",
                "name": "btn_4",
                "value": "V1"
              },
              {
                "index": "0",
                "name": "btn_3",
                "value": "R18"
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
          "id": "3de19fcf-c03a-5fea-b964-5a44ba9947f9",
          "type": "basic.output",
          "data": {
            "name": "taken",
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
          "id": "6f54b1a8-eb29-5afd-8417-0d2e22215e76",
          "type": "basic.code",
          "data": {
            "code": "// ---------------------------------------------------------------\n// Added by tools/mkice.py, not present in the lesson's .v:\n// Icestudio declares a code block's outputs as wires, and the\n// board has fewer pins than this module has port bits. See\n// icestudio/README.md. The module's own text below is verbatim.\n// ---------------------------------------------------------------\nwire [31:0] a = {{28{sw[3]}}, sw};\nreg taken;\n\nwire eq  = (a == b);\nwire ltu = (a < b);\nwire lt  = ($signed(a) < $signed(b));   // $signed, for the same reason\n                                        // lesson 10's SRA needed it\n\nalways @(*)\n    case (funct3)\n        3'b000: taken =  eq;    // BEQ\n        3'b001: taken = !eq;    // BNE\n        3'b100: taken =  lt;    // BLT\n        3'b101: taken = !lt;    // BGE\n        3'b110: taken =  ltu;   // BLTU\n        3'b111: taken = !ltu;   // BGEU\n        // funct3 010 and 011 are not branches; lesson 12's decoder\n        // flags them illegal. A default is still required, or this\n        // combinational block infers a latch.\n        default: taken = 1'b0;\n    endcase\n\n// ---- added by tools/mkice.py: port aliases and probes ----\nassign taken_o = taken;\n",
            "params": [
              {
                "name": "b"
              }
            ],
            "ports": {
              "in": [
                {
                  "name": "sw",
                  "range": "[3:0]",
                  "size": 4
                },
                {
                  "name": "funct3",
                  "range": "[2:0]",
                  "size": 3
                }
              ],
              "out": [
                {
                  "name": "taken_o"
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
          "id": "c4af863e-99c9-545e-a8fc-32feef9560be",
          "type": "basic.constant",
          "data": {
            "name": "b",
            "value": "32'd7",
            "local": false
          },
          "position": {
            "x": 416,
            "y": -112
          }
        },
        {
          "id": "99ced1c0-de9d-5669-9b6b-d5967ec0e107",
          "type": "basic.info",
          "data": {
            "info": "## Lesson 13 - would this branch be taken?\n\nThe branch unit answers one question about two registers: `a` is rs1, `b` is rs2, and `taken` says whether the PC should move. Here `b` is fixed at 7 and `a` is the four slide switches **sign-extended** to 32 bits, so `0000`..`0111` are 0..7 and `1000`..`1111` are -8..-1.\n\nThe three buttons are `funct3`, held together:\n\n| hold | funct3 | branch | taken when | lights for |\n|---|---|---|---|---|\n| nothing | 000 | BEQ | a = 7 | `0111` only |\n| UP | 001 | BNE | a != 7 | everything but `0111` |\n| LEFT | 100 | BLT | a < 7, signed | `0000`..`0110` and all of `1xxx` |\n| LEFT+UP | 101 | BGE | a >= 7, signed | `0111` only |\n| LEFT+DOWN | 110 | BLTU | a < 7, unsigned | `0000`..`0110` only |\n| LEFT+DOWN+UP | 111 | BGEU | a >= 7, unsigned | `0111` and all of `1xxx` |\n\n### The experiment worth doing\n\nSet the switches to `1111`, which is -1.\n\n- Hold **LEFT** (BLT): the LED **lights**. -1 is less than 7.\n- Hold **LEFT+DOWN** (BLTU): it **goes out**. The same bit pattern read as unsigned is 4,294,967,295, which is not less than 7.\n\nThe bits did not change. The comparison did. That is why RV32I spends separate opcodes on signed and unsigned compare, and why the module computes one with `$signed()` and one without:\n\n```verilog\nwire ltu = (a < b);\nwire lt  = ($signed(a) < $signed(b));\n```\n\nSix branch conditions come out of three comparisons and some inversions - `BGE` is just `!lt`, `BNE` is just `!eq`. Six comparators would be four too many, and on a 32-bit datapath a comparator is not cheap.\n\n### Not on pins\n\nBoth operands are 32 bits wide, so one is a canvas constant and the other is four switches widened in the wire that feeds it. The `default` arm of the case - which is what stops `funct3` 010 and 011 from inferring a latch - is in the body where you can read it.",
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
            "block": "c4af863e-99c9-545e-a8fc-32feef9560be",
            "port": "constant-out"
          },
          "target": {
            "block": "6f54b1a8-eb29-5afd-8417-0d2e22215e76",
            "port": "b"
          }
        },
        {
          "source": {
            "block": "a48b1c25-55d5-5abc-bb79-768e6cd2bfdc",
            "port": "out"
          },
          "target": {
            "block": "6f54b1a8-eb29-5afd-8417-0d2e22215e76",
            "port": "sw"
          },
          "size": 4
        },
        {
          "source": {
            "block": "48365331-3baf-542a-92d7-670fc47f07b5",
            "port": "out"
          },
          "target": {
            "block": "6f54b1a8-eb29-5afd-8417-0d2e22215e76",
            "port": "funct3"
          },
          "size": 3
        },
        {
          "source": {
            "block": "6f54b1a8-eb29-5afd-8417-0d2e22215e76",
            "port": "taken_o"
          },
          "target": {
            "block": "3de19fcf-c03a-5fea-b964-5a44ba9947f9",
            "port": "in"
          }
        }
      ]
    }
  },
  "dependencies": {}
}
