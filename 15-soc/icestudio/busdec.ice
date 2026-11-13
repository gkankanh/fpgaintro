{
  "version": "1.2",
  "package": {
    "name": "busdec",
    "version": "1.0",
    "description": "Lesson 15 - the address decoder: three comparisons that turn a 32-bit address into a memory map.",
    "author": "The Open FPGA Course",
    "image": ""
  },
  "design": {
    "board": "ulx3s-85f",
    "graph": {
      "blocks": [
        {
          "id": "4d9a3262-4002-581b-ae41-913f3fd9c31b",
          "type": "basic.input",
          "data": {
            "name": "addr[31:28] (sw3..sw0)",
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
          "id": "3fb1ff0c-4736-591c-b569-9e0abe33ede4",
          "type": "basic.input",
          "data": {
            "name": "access (hold FIRE2)",
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
            "y": 48
          }
        },
        {
          "id": "b2d210c2-0e67-577a-ab06-e02313c0ca67",
          "type": "basic.output",
          "data": {
            "name": "sel_mem",
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
          "id": "dc6354ee-1d97-5df4-9ade-1faa2b0e0a12",
          "type": "basic.output",
          "data": {
            "name": "sel_io",
            "pins": [
              {
                "index": "0",
                "name": "led_1",
                "value": "C2"
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
          "id": "d3677727-458c-5933-9381-fc7b433f3c8c",
          "type": "basic.output",
          "data": {
            "name": "fault",
            "pins": [
              {
                "index": "0",
                "name": "led_2",
                "value": "C1"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 816,
            "y": 288
          }
        },
        {
          "id": "c632ab2a-80de-5ae9-a5df-6df4f9576c43",
          "type": "basic.code",
          "data": {
            "code": "// ---------------------------------------------------------------\n// Added by tools/mkice.py, not present in the lesson's .v:\n// Icestudio declares a code block's outputs as wires, and the\n// board has fewer pins than this module has port bits. See\n// icestudio/README.md. The module's own text below is verbatim.\n// ---------------------------------------------------------------\nwire [31:0] addr = {sw, 28'h0000000};\n\n// A real comparison, and the thing that makes a wild pointer reportable\n// instead of silently aliasing onto something innocent.\nwire in_mem = (addr < MEM_BYTES);\nwire in_io  = (addr[31:8] == 24'h80_0000);\n\nassign sel_mem = in_mem;\nassign sel_io  = in_io;\nassign fault   = access && !in_mem && !in_io;\n",
            "params": [
              {
                "name": "MEM_BYTES"
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
                  "name": "access"
                }
              ],
              "out": [
                {
                  "name": "sel_mem"
                },
                {
                  "name": "sel_io"
                },
                {
                  "name": "fault"
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
          "id": "b521e335-dcc0-5719-968b-dffa9e476885",
          "type": "basic.constant",
          "data": {
            "name": "MEM_BYTES",
            "value": "4096",
            "local": false
          },
          "position": {
            "x": 416,
            "y": -112
          }
        },
        {
          "id": "b51bf8e3-23c0-5495-9e0c-28be17f9dedd",
          "type": "basic.info",
          "data": {
            "info": "## Lesson 15 - a memory map is two comparators\n\nThe switches set the top nibble of a 32-bit address; the rest is zero. So:\n\n| sw3..sw0 | address | lights |\n|---|---|---|\n| `0000` | `0x00000000` | **sel_mem** - inside the 4 KB array |\n| `1000` | `0x80000000` | **sel_io** - the peripheral window |\n| anything else | e.g. `0x40000000` | nothing, until you hold FIRE2 |\n\nHold **FIRE2** on an address that is neither, and **fault** lights. That is the whole decoder:\n\n```verilog\nwire in_mem = (addr < MEM_BYTES);\nwire in_io  = (addr[31:8] == 24'h80_0000);\nassign fault = access && !in_mem && !in_io;\n```\n\n### Why `fault` needs `access`\n\n`sel_mem` and `sel_io` are pure functions of the address, so they are safe to compute every cycle whether or not anything is happening. `fault` is not: an address bus idling on a nonsense value is normal, and reporting it would cry wolf on every cycle the CPU is not accessing memory. `access` is what makes the difference between *where the bus is pointing* and *a real access to that place* - which is why the signal exists at all, and why lesson 16 widens it from \"a store\" to \"a store or a load\".\n\n### Try breaking it\n\nRaise `MEM_BYTES` on the constant block to `0x90000000` and rebuild. Now `0x80000000` lights **both** `sel_mem` and `sel_io`, because the regions overlap and nothing in this module says they may not. A real decoder's correctness is entirely in the arithmetic of its bounds - there is no structure to protect you.",
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
            "block": "b521e335-dcc0-5719-968b-dffa9e476885",
            "port": "constant-out"
          },
          "target": {
            "block": "c632ab2a-80de-5ae9-a5df-6df4f9576c43",
            "port": "MEM_BYTES"
          }
        },
        {
          "source": {
            "block": "4d9a3262-4002-581b-ae41-913f3fd9c31b",
            "port": "out"
          },
          "target": {
            "block": "c632ab2a-80de-5ae9-a5df-6df4f9576c43",
            "port": "sw"
          },
          "size": 4
        },
        {
          "source": {
            "block": "3fb1ff0c-4736-591c-b569-9e0abe33ede4",
            "port": "out"
          },
          "target": {
            "block": "c632ab2a-80de-5ae9-a5df-6df4f9576c43",
            "port": "access"
          }
        },
        {
          "source": {
            "block": "c632ab2a-80de-5ae9-a5df-6df4f9576c43",
            "port": "sel_mem"
          },
          "target": {
            "block": "b2d210c2-0e67-577a-ab06-e02313c0ca67",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "c632ab2a-80de-5ae9-a5df-6df4f9576c43",
            "port": "sel_io"
          },
          "target": {
            "block": "dc6354ee-1d97-5df4-9ade-1faa2b0e0a12",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "c632ab2a-80de-5ae9-a5df-6df4f9576c43",
            "port": "fault"
          },
          "target": {
            "block": "d3677727-458c-5933-9381-fc7b433f3c8c",
            "port": "in"
          }
        }
      ]
    }
  },
  "dependencies": {}
}
