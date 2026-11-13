{
  "version": "1.2",
  "package": {
    "name": "slowpath",
    "version": "1.0",
    "description": "Lesson 04 - eight dependent adds between two registers: a critical path you can measure.",
    "author": "The Open FPGA Course",
    "image": ""
  },
  "design": {
    "board": "ulx3s-85f",
    "graph": {
      "blocks": [
        {
          "id": "b13381e6-b8c7-5911-ba55-4be1c1e0c00b",
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
          "id": "5e5368c7-bef9-5a04-a09f-3d6161bd990c",
          "type": "basic.input",
          "data": {
            "name": "a (buttons = high nibble, switches = low)",
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
            "y": 168
          }
        },
        {
          "id": "b026a0d6-b4d9-5307-a259-871e842ceff8",
          "type": "basic.output",
          "data": {
            "name": "y (8 adds later)",
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
          "id": "64002dad-739e-52fe-ac7d-59908c51b4ee",
          "type": "basic.code",
          "data": {
            "code": "// ---------------------------------------------------------------\n// Added by tools/mkice.py, not present in the lesson's .v:\n// Icestudio declares a code block's outputs as wires, and the\n// board has fewer pins than this module has port bits. See\n// icestudio/README.md. The module's own text below is verbatim.\n// ---------------------------------------------------------------\nreg [W-1:0] y = 0;\n\nwire [W-1:0] stage [0:DEPTH];\nassign stage[0] = a;\n\ngenvar i;\ngenerate\n    for (i = 0; i < DEPTH; i = i + 1) begin : chain\n        assign stage[i+1] = stage[i] + (stage[i] ^ (i + 1));\n    end\nendgenerate\n\nalways @(posedge clk)\n    y <= stage[DEPTH];\n\n// ---- added by tools/mkice.py: port aliases and probes ----\nassign y_o = y;\n",
            "params": [
              {
                "name": "W"
              },
              {
                "name": "DEPTH"
              }
            ],
            "ports": {
              "in": [
                {
                  "name": "clk"
                },
                {
                  "name": "a",
                  "range": "[7:0]",
                  "size": 8
                }
              ],
              "out": [
                {
                  "name": "y_o",
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
          "id": "84f66156-0965-54c3-95d6-bd14d4090464",
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
          "id": "c7d79d0c-eeb5-5270-8ff8-ecd2a2499582",
          "type": "basic.constant",
          "data": {
            "name": "DEPTH",
            "value": "8",
            "local": false
          },
          "position": {
            "x": 416,
            "y": -192
          }
        },
        {
          "id": "610c83f6-84b5-5a0a-87a3-6dfc01551ef8",
          "type": "basic.info",
          "data": {
            "info": "## Lesson 04 - the critical path, on the canvas\n\n`DEPTH` dependent adds sit between the input register and the output register. Each stage needs the previous stage's result, so the adders cannot be done in parallel: the delays add up, and their sum is the **critical path** that decides the clock this design can run at.\n\n### What to do with it\n\nBuild it and read the Icestudio console. You will find **no maximum frequency reported at all** \u2014 nextpnr says `No Fmax available; no interior timing paths found`. That is not a broken project, it is the definition doing its job: a critical path runs from one flip-flop to another, and here `a` arrives from the switches and `y` leaves for the LEDs, so the only paths are pad-to-register ones. Pads are not registers.\n\nTo *measure* the chain you need a register feeding it, which is what `slow_top.v` adds on the editor path \u2014 and that is where lesson 04's real surprise is waiting. Raising `DEPTH` does **not** reliably lower the achieved frequency: yosys works out what the chain computes and builds that instead of what was written, so the number can go *up* as you ask for more adds. The lesson README records both ways the experiment defeated itself, and the measurements.\n\nWhich is the thing to take away: you cannot read your critical path off your source code. Read the tool's report.\n\n### What this project cannot show you\n\nThe lesson's other two halves need a **PLL** to raise the clock until timing genuinely fails, and a two-clock crossing to make metastability visible. The PLL is an ECP5 hard block (`EHXPLLL`) and `cdc_bus` needs a second clock the board's pin list does not offer, so both stay on the editor path: `cd 04-clocks && make bit` is where you watch the deliberate failure happen.",
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
            "block": "84f66156-0965-54c3-95d6-bd14d4090464",
            "port": "constant-out"
          },
          "target": {
            "block": "64002dad-739e-52fe-ac7d-59908c51b4ee",
            "port": "W"
          }
        },
        {
          "source": {
            "block": "c7d79d0c-eeb5-5270-8ff8-ecd2a2499582",
            "port": "constant-out"
          },
          "target": {
            "block": "64002dad-739e-52fe-ac7d-59908c51b4ee",
            "port": "DEPTH"
          }
        },
        {
          "source": {
            "block": "b13381e6-b8c7-5911-ba55-4be1c1e0c00b",
            "port": "out"
          },
          "target": {
            "block": "64002dad-739e-52fe-ac7d-59908c51b4ee",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "5e5368c7-bef9-5a04-a09f-3d6161bd990c",
            "port": "out"
          },
          "target": {
            "block": "64002dad-739e-52fe-ac7d-59908c51b4ee",
            "port": "a"
          },
          "size": 8
        },
        {
          "source": {
            "block": "64002dad-739e-52fe-ac7d-59908c51b4ee",
            "port": "y_o"
          },
          "target": {
            "block": "b026a0d6-b4d9-5307-a259-871e842ceff8",
            "port": "in"
          },
          "size": 8
        }
      ]
    }
  },
  "dependencies": {}
}
