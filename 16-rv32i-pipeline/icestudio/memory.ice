{
  "version": "1.2",
  "package": {
    "name": "memory",
    "version": "1.0",
    "description": "Lesson 16 - the dual-port synchronous memory: write a word with a button, read it back on the other port.",
    "author": "The Open FPGA Course",
    "image": ""
  },
  "design": {
    "board": "ulx3s-85f",
    "graph": {
      "blocks": [
        {
          "id": "c5d7503f-ce2e-5542-bd35-9b835328e35b",
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
          "id": "a7612cbd-f7bb-5a05-82fe-e1f9747e83ed",
          "type": "basic.input",
          "data": {
            "name": "a_addr (sw3..sw0)",
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
            "y": 168
          }
        },
        {
          "id": "3dbb7ffd-8df8-57ec-ba7d-9e1dabf2e766",
          "type": "basic.input",
          "data": {
            "name": "b_we (press FIRE2 to store)",
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
          "id": "3e8b9112-8fad-5a29-ad29-bb6ca8acf483",
          "type": "basic.output",
          "data": {
            "name": "a_data[7:0]",
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
          "id": "977c6156-4ce3-587a-9b8a-116ec0ec72b1",
          "type": "basic.code",
          "data": {
            "code": "// ---------------------------------------------------------------\n// Added by tools/mkice.py, not present in the lesson's .v:\n// Icestudio declares a code block's outputs as wires, and the\n// board has fewer pins than this module has port bits. See\n// icestudio/README.md. The module's own text below is verbatim.\n// ---------------------------------------------------------------\nwire a_en = 1'b1;\nwire b_en = 1'b0;\nwire [$clog2(WORDS)-1:0] b_addr = a_addr;\nwire [3:0] b_be = 4'hF;\nreg [31:0] a_data;\nreg [31:0] b_data;\n\nreg [31:0] mem [0:WORDS-1];\n\ngenerate if (FILE != \"\") begin : g_init\n    initial $readmemh(FILE, mem);\nend endgenerate\n\n// Port A. One line, and it is the whole reason this design gets block RAM.\nalways @(posedge clk)\n    if (a_en) a_data <= mem[a_addr];\n\n// Port B. The read and the write are mutually exclusive by construction\n// -- a load does not store and a store does not load -- which matters,\n// because a DP16KD port does one or the other in a cycle and writing\n// Verilog that asks for both is how you lose the block RAM again.\n//\n// `b_en` comes from the core's dmem_re: the signal lesson 15 wanted and\n// could not have, because a single-cycle core never knew which cycles\n// were loads. A pipeline knows, because the MEM stage is a place rather\n// than a moment.\nalways @(posedge clk) begin\n    if (b_we) begin\n        if (b_be[0]) mem[b_addr][ 7: 0] <= b_wdata[ 7: 0];\n        if (b_be[1]) mem[b_addr][15: 8] <= b_wdata[15: 8];\n        if (b_be[2]) mem[b_addr][23:16] <= b_wdata[23:16];\n        if (b_be[3]) mem[b_addr][31:24] <= b_wdata[31:24];\n    end\n    if (b_en) b_data <= mem[b_addr];\nend\n\n// ---- added by tools/mkice.py: port aliases and probes ----\nassign a_lo = a_data[7:0];\n",
            "params": [
              {
                "name": "WORDS"
              },
              {
                "name": "FILE"
              },
              {
                "name": "b_wdata"
              }
            ],
            "ports": {
              "in": [
                {
                  "name": "clk"
                },
                {
                  "name": "a_addr",
                  "range": "[3:0]",
                  "size": 4
                },
                {
                  "name": "b_we"
                }
              ],
              "out": [
                {
                  "name": "a_lo",
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
          "id": "9e46f034-e81a-5925-bca3-6c4dc31e8df1",
          "type": "basic.constant",
          "data": {
            "name": "WORDS",
            "value": "16",
            "local": false
          },
          "position": {
            "x": 416,
            "y": -112
          }
        },
        {
          "id": "44744915-e68f-55e2-83f4-7c882b6e0e2d",
          "type": "basic.constant",
          "data": {
            "name": "FILE",
            "value": "\"\"",
            "local": false
          },
          "position": {
            "x": 416,
            "y": -192
          }
        },
        {
          "id": "80e79ff2-ca56-55aa-974c-b080058fb6a6",
          "type": "basic.constant",
          "data": {
            "name": "b_wdata",
            "value": "32'h000000A5",
            "local": false
          },
          "position": {
            "x": 416,
            "y": -272
          }
        },
        {
          "id": "e7df7a4d-b9b3-5279-80a9-08efd2fd1a78",
          "type": "basic.info",
          "data": {
            "info": "## Lesson 16 - two ports, one memory\n\nPick an address on the switches. Port A reads it every cycle and the LEDs show the low byte. Press **FIRE2** and port B writes `0xA5` to the same address - so the LEDs go from garbage to `10100101` and stay there.\n\nThen move the switches and come back. The byte is still where you left it, and the addresses you never wrote still read as whatever the block RAM powered up with.\n\n### What this is really showing\n\n`FILE` is empty, so the memory starts **uninitialised**. In simulation that is X, and lesson 08's point was that X is the correct answer: a memory you read before writing is a bug, and X is the only value that says so out loud. On real hardware there is no X - the block RAM comes up with something, usually zero, and the bug becomes invisible. That gap between simulation and silicon is worth feeling once.\n\n### Why two ports at all\n\nA 5-stage pipeline has an instruction fetch in IF and a load or store in MEM **in the same cycle**. One port cannot serve both, and the ECP5's DP16KD block RAM has exactly two - which is why the pipeline is affordable at all.\n\nNote what each port does **not** do: a port reads or writes in a cycle, never both. Here `b_en` is tied low while `b_we` is on a button, so port B only ever stores. Asking a DP16KD port for a read and a write in one cycle is how you lose the block RAM and get the whole array built out of flip-flops instead.\n\nThe four byte-enables are tied to `4'hF` - a full 32-bit word. They are what make `sb` and `sh` possible without a read-modify-write, and the editor path's testbench exercises them properly: `cd 16-rv32i-pipeline && make sim`.",
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
            "block": "9e46f034-e81a-5925-bca3-6c4dc31e8df1",
            "port": "constant-out"
          },
          "target": {
            "block": "977c6156-4ce3-587a-9b8a-116ec0ec72b1",
            "port": "WORDS"
          }
        },
        {
          "source": {
            "block": "44744915-e68f-55e2-83f4-7c882b6e0e2d",
            "port": "constant-out"
          },
          "target": {
            "block": "977c6156-4ce3-587a-9b8a-116ec0ec72b1",
            "port": "FILE"
          }
        },
        {
          "source": {
            "block": "80e79ff2-ca56-55aa-974c-b080058fb6a6",
            "port": "constant-out"
          },
          "target": {
            "block": "977c6156-4ce3-587a-9b8a-116ec0ec72b1",
            "port": "b_wdata"
          }
        },
        {
          "source": {
            "block": "c5d7503f-ce2e-5542-bd35-9b835328e35b",
            "port": "out"
          },
          "target": {
            "block": "977c6156-4ce3-587a-9b8a-116ec0ec72b1",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "a7612cbd-f7bb-5a05-82fe-e1f9747e83ed",
            "port": "out"
          },
          "target": {
            "block": "977c6156-4ce3-587a-9b8a-116ec0ec72b1",
            "port": "a_addr"
          },
          "size": 4
        },
        {
          "source": {
            "block": "3dbb7ffd-8df8-57ec-ba7d-9e1dabf2e766",
            "port": "out"
          },
          "target": {
            "block": "977c6156-4ce3-587a-9b8a-116ec0ec72b1",
            "port": "b_we"
          }
        },
        {
          "source": {
            "block": "977c6156-4ce3-587a-9b8a-116ec0ec72b1",
            "port": "a_lo"
          },
          "target": {
            "block": "3e8b9112-8fad-5a29-ad29-bb6ca8acf483",
            "port": "in"
          },
          "size": 8
        }
      ]
    }
  },
  "dependencies": {}
}
