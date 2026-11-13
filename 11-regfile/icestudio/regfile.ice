{
  "version": "1.2",
  "package": {
    "name": "regfile",
    "version": "1.0",
    "description": "Lesson 11 - a register file with two read ports, one write port, and an x0 that absorbs writes.",
    "author": "The Open FPGA Course",
    "image": ""
  },
  "design": {
    "board": "ulx3s-85f",
    "graph": {
      "blocks": [
        {
          "id": "4d0d8654-a9da-5089-affd-8e81fbc44314",
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
          "id": "d4fc967e-2df1-53aa-b3ba-d3d6bb436c45",
          "type": "basic.input",
          "data": {
            "name": "rs1 (read address)",
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
            "y": 168
          }
        },
        {
          "id": "6d54c790-e667-52a8-9811-1b189da4c593",
          "type": "basic.input",
          "data": {
            "name": "we (press FIRE2 to write)",
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
          "id": "77806ae1-2558-53f1-af82-68b98e688345",
          "type": "basic.input",
          "data": {
            "name": "rd (write address: LEFT/DOWN/UP)",
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
            "y": 408
          }
        },
        {
          "id": "02803818-2584-58a2-b733-31d5ae4805e0",
          "type": "basic.output",
          "data": {
            "name": "rd1 (port 1 read data)",
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
          "id": "85201ba0-ec27-536e-b671-e8bac6b4d92a",
          "type": "basic.code",
          "data": {
            "code": "// ---------------------------------------------------------------\n// Added by tools/mkice.py, not present in the lesson's .v:\n// Icestudio declares a code block's outputs as wires, and the\n// board has fewer pins than this module has port bits. See\n// icestudio/README.md. The module's own text below is verbatim.\n// ---------------------------------------------------------------\nwire [$clog2(N)-1:0] rs2 = {$clog2(N){1'b0}};\nwire [W-1:0] rd2;\n\nreg [W-1:0] regs [0:N-1];\n\n// x0 absorbs writes. `rd != 0` is the entire mechanism -- and note it\n// costs one comparator, not a special case in the read path.\nalways @(posedge clk)\n    if (we && rd != {$clog2(N){1'b0}})\n        regs[rd] <= wdata;\n\n// x0 reads as zero. Note this is a MUX on the output, not a value stored\n// in regs[0]: storing zero there would work until something wrote to it.\nassign rd1 = (rs1 == {$clog2(N){1'b0}}) ? {W{1'b0}} : regs[rs1];\nassign rd2 = (rs2 == {$clog2(N){1'b0}}) ? {W{1'b0}} : regs[rs2];\n\n// In a SINGLE-CYCLE CPU this needs no write-to-read bypass, and it is\n// worth being clear why, because it is a common source of confusion.\n//\n// During cycle N an instruction reads rs1 and rs2, computes, and its\n// result is written at the END of cycle N by the clock edge. So a read of\n// the register being written returns the OLD value -- which is correct:\n// the instruction must see its operands as they were before it ran.\n//\n// Bypass becomes necessary when a read and a write belong to DIFFERENT\n// instructions in flight at once. That is lesson 16's pipeline, and\n// regfile_bram.v below shows the shape of the fix.\n",
            "params": [
              {
                "name": "W"
              },
              {
                "name": "N"
              },
              {
                "name": "wdata"
              }
            ],
            "ports": {
              "in": [
                {
                  "name": "clk"
                },
                {
                  "name": "rs1",
                  "range": "[2:0]",
                  "size": 3
                },
                {
                  "name": "we"
                },
                {
                  "name": "rd",
                  "range": "[2:0]",
                  "size": 3
                }
              ],
              "out": [
                {
                  "name": "rd1",
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
          "id": "8abac065-2a33-5fd0-9547-5f4b90a6e64f",
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
          "id": "ce82e4a8-e783-5ce4-b0c9-2d7569040f1a",
          "type": "basic.constant",
          "data": {
            "name": "N",
            "value": "8",
            "local": false
          },
          "position": {
            "x": 416,
            "y": -192
          }
        },
        {
          "id": "1b6acbbd-6945-5d61-9efd-8e463edd98d8",
          "type": "basic.constant",
          "data": {
            "name": "wdata",
            "value": "8'hA5",
            "local": false
          },
          "position": {
            "x": 416,
            "y": -272
          }
        },
        {
          "id": "bc380e1d-5016-5e9c-b4c2-5d6e73df1bc8",
          "type": "basic.info",
          "data": {
            "info": "## Lesson 11 - write a register, read it back\n\n`wdata` is the constant `0xA5`. To store it:\n\n1. pick a destination with **UP / DOWN / LEFT** held as the three bits of `rd`\n2. press **FIRE2** while holding them - that is `we`\n3. set `sw2..sw0` to the same number to read it back on `rd1`\n\n`0xA5` is `10100101`, which is easy to recognise on eight LEDs and not symmetric, so you can also see that nothing got reversed on the way.\n\n### Now try register 0\n\nWrite `0xA5` to `rd` = 0, then read `rs1` = 0. The LEDs stay dark. Two lines make that true:\n\n```verilog\nif (we && rd != 0) regs[rd] <= wdata;          // x0 absorbs writes\nassign rd1 = (rs1 == 0) ? 0 : regs[rs1];        // x0 reads as zero\n```\n\nThe second line is the one that matters, and it is a mux on the *output*, not a zero stored in `regs[0]`. Storing a zero would work right up until something managed to write there; a mux cannot be wrong.\n\n### What is tied off\n\nThe real module has two read ports. There are only eight LEDs, so `rs2` is tied to zero and `rd2` is declared but left unconnected - yosys trims the logic that fed it. Both ports are exercised together in the editor path's testbench, which is also where the 32x32 version runs: `cd 11-regfile && make sim`.",
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
            "block": "8abac065-2a33-5fd0-9547-5f4b90a6e64f",
            "port": "constant-out"
          },
          "target": {
            "block": "85201ba0-ec27-536e-b671-e8bac6b4d92a",
            "port": "W"
          }
        },
        {
          "source": {
            "block": "ce82e4a8-e783-5ce4-b0c9-2d7569040f1a",
            "port": "constant-out"
          },
          "target": {
            "block": "85201ba0-ec27-536e-b671-e8bac6b4d92a",
            "port": "N"
          }
        },
        {
          "source": {
            "block": "1b6acbbd-6945-5d61-9efd-8e463edd98d8",
            "port": "constant-out"
          },
          "target": {
            "block": "85201ba0-ec27-536e-b671-e8bac6b4d92a",
            "port": "wdata"
          }
        },
        {
          "source": {
            "block": "4d0d8654-a9da-5089-affd-8e81fbc44314",
            "port": "out"
          },
          "target": {
            "block": "85201ba0-ec27-536e-b671-e8bac6b4d92a",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "d4fc967e-2df1-53aa-b3ba-d3d6bb436c45",
            "port": "out"
          },
          "target": {
            "block": "85201ba0-ec27-536e-b671-e8bac6b4d92a",
            "port": "rs1"
          },
          "size": 3
        },
        {
          "source": {
            "block": "6d54c790-e667-52a8-9811-1b189da4c593",
            "port": "out"
          },
          "target": {
            "block": "85201ba0-ec27-536e-b671-e8bac6b4d92a",
            "port": "we"
          }
        },
        {
          "source": {
            "block": "77806ae1-2558-53f1-af82-68b98e688345",
            "port": "out"
          },
          "target": {
            "block": "85201ba0-ec27-536e-b671-e8bac6b4d92a",
            "port": "rd"
          },
          "size": 3
        },
        {
          "source": {
            "block": "85201ba0-ec27-536e-b671-e8bac6b4d92a",
            "port": "rd1"
          },
          "target": {
            "block": "02803818-2584-58a2-b733-31d5ae4805e0",
            "port": "in"
          },
          "size": 8
        }
      ]
    }
  },
  "dependencies": {}
}
