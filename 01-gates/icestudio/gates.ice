{
  "version": "1.2",
  "package": {
    "name": "gates",
    "version": "1.0",
    "description": "Lesson 01 - every two-input gate, plus NAND-only equivalents.",
    "author": "The Open FPGA Course",
    "image": ""
  },
  "design": {
    "board": "ulx3s-85f",
    "graph": {
      "blocks": [
        {
          "id": "837043b7-c276-586f-94a8-968cdc83ab24",
          "type": "basic.input",
          "data": {
            "name": "a (FIRE1)",
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
            "y": 48
          }
        },
        {
          "id": "98c983ad-18f3-5c32-9178-6b6f669f9079",
          "type": "basic.input",
          "data": {
            "name": "b (FIRE2)",
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
            "y": 168
          }
        },
        {
          "id": "3853be2e-cb31-58a5-9da0-d91028e339c3",
          "type": "basic.output",
          "data": {
            "name": "AND",
            "pins": [
              {
                "index": "0",
                "name": "led_7",
                "value": "H3"
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
          "id": "64320c0a-cfcb-5abd-816d-5f40a0a7645c",
          "type": "basic.output",
          "data": {
            "name": "OR",
            "pins": [
              {
                "index": "0",
                "name": "led_6",
                "value": "E1"
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
          "id": "5a1e7f0d-2cc9-5d1b-bbd4-fb6b1d1ca143",
          "type": "basic.output",
          "data": {
            "name": "NOT a",
            "pins": [
              {
                "index": "0",
                "name": "led_5",
                "value": "E2"
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
          "id": "9e139b0d-d04f-5977-8d1f-1e64872aede5",
          "type": "basic.output",
          "data": {
            "name": "NAND",
            "pins": [
              {
                "index": "0",
                "name": "led_4",
                "value": "D1"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 816,
            "y": 408
          }
        },
        {
          "id": "a5f50fef-4703-5d0e-87e3-5eb111b47d2c",
          "type": "basic.output",
          "data": {
            "name": "NOR",
            "pins": [
              {
                "index": "0",
                "name": "led_3",
                "value": "D2"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 816,
            "y": 528
          }
        },
        {
          "id": "4c2135d1-1ba6-54b2-a67f-2c5da261eef7",
          "type": "basic.output",
          "data": {
            "name": "XNOR",
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
            "y": 648
          }
        },
        {
          "id": "11b41006-cff4-540e-ad72-4889bfa99273",
          "type": "basic.output",
          "data": {
            "name": "XOR (direct)",
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
            "y": 768
          }
        },
        {
          "id": "7ecea736-7cb5-5c2c-b027-08265b53f70d",
          "type": "basic.output",
          "data": {
            "name": "XOR (4 NANDs)",
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
            "y": 888
          }
        },
        {
          "id": "cae397c9-5caa-50bc-98be-aca2233f658f",
          "type": "basic.output",
          "data": {
            "name": "NOT from NAND",
            "pins": [
              {
                "index": "0",
                "name": "gp0",
                "value": "B11"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 816,
            "y": 1008
          }
        },
        {
          "id": "42980d70-829a-5ee8-bd59-9d3e7e442435",
          "type": "basic.output",
          "data": {
            "name": "AND from NAND",
            "pins": [
              {
                "index": "0",
                "name": "gp1",
                "value": "A10"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 816,
            "y": 1128
          }
        },
        {
          "id": "55cfb152-684f-57fe-94ab-4293da918c1a",
          "type": "basic.output",
          "data": {
            "name": "OR from NAND",
            "pins": [
              {
                "index": "0",
                "name": "gp2",
                "value": "A9"
              }
            ],
            "virtual": false
          },
          "position": {
            "x": 816,
            "y": 1248
          }
        },
        {
          "id": "28accbaa-b3f4-5f83-830d-a5aa6a0f3e40",
          "type": "basic.code",
          "data": {
            "code": "// ---------------------------------------------------------------- direct\n// `assign` is not a statement that runs. It is a permanent connection:\n// whenever `a` or `b` changes, the output follows. There is no \"when\".\nassign y_and  =   a & b;\nassign y_or   =   a | b;\nassign y_not  =  ~a;\nassign y_nand = ~(a & b);\nassign y_nor  = ~(a | b);\nassign y_xor  =   a ^ b;\nassign y_xnor = ~(a ^ b);\n\n// ------------------------------------------------------- NAND-only forms\n// NAND is a universal gate: every Boolean function can be built from it\n// alone. Four constructions, each one line, each verified by the\n// testbench against the direct version above.\n\nwire nab = ~(a & b);                 // the shared NAND(a, b)\n\n// NOT a = NAND(a, a): both inputs the same, so the AND is just `a`.\nassign n_not = ~(a & a);\n\n// AND = NOT(NAND) = NAND(NAND(a,b), NAND(a,b)).\nassign n_and = ~(nab & nab);\n\n// OR = NAND(NOT a, NOT b). This is De Morgan:  a | b  ==  ~(~a & ~b).\nwire na = ~(a & a);\nwire nb = ~(b & b);\nassign n_or = ~(na & nb);\n\n// XOR from four NANDs \u2014 the classic construction.\n//   w1 = NAND(a, NAND(a,b))   is 1 unless a=1 and b=0\n//   w2 = NAND(b, NAND(a,b))   is 1 unless b=1 and a=0\n//   XOR = NAND(w1, w2)\nwire w1 = ~(a & nab);\nwire w2 = ~(b & nab);\nassign n_xor = ~(w1 & w2);\n",
            "params": [],
            "ports": {
              "in": [
                {
                  "name": "a"
                },
                {
                  "name": "b"
                }
              ],
              "out": [
                {
                  "name": "y_and"
                },
                {
                  "name": "y_or"
                },
                {
                  "name": "y_not"
                },
                {
                  "name": "y_nand"
                },
                {
                  "name": "y_nor"
                },
                {
                  "name": "y_xnor"
                },
                {
                  "name": "y_xor"
                },
                {
                  "name": "n_xor"
                },
                {
                  "name": "n_not"
                },
                {
                  "name": "n_and"
                },
                {
                  "name": "n_or"
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
          "id": "977de54e-c3dd-5594-b594-df8581b24590",
          "type": "basic.info",
          "data": {
            "info": "## Lesson 01 - logic gates\n\nPress **FIRE1** (`a`) and **FIRE2** (`b`) and read the LEDs.\n\n`led_1` is XOR written directly as `a ^ b`. `led_0` is the same function built from **four NANDs**. They are always identical - that is NAND universality, on hardware.\n\nThe other three NAND-built forms (NOT, AND, OR) go to GPIO pins `gp0`-`gp2` because the board only has eight LEDs; the testbench checks them.\n\n### The thing to notice\n\nThis FPGA has no gates. Every one of these becomes a **4-input lookup table** - sixteen configuration bits holding a truth table. A 2-input AND and a 4-input XOR cost exactly the same: one LUT4.\n\nSo the whole design is **7 LUT4s for 11 outputs**: the synthesiser works out what each output *is* and shares what it can. It never builds your NAND chain.",
            "readonly": true
          },
          "position": {
            "x": 48,
            "y": 1432
          }
        }
      ],
      "wires": [
        {
          "source": {
            "block": "837043b7-c276-586f-94a8-968cdc83ab24",
            "port": "out"
          },
          "target": {
            "block": "28accbaa-b3f4-5f83-830d-a5aa6a0f3e40",
            "port": "a"
          }
        },
        {
          "source": {
            "block": "98c983ad-18f3-5c32-9178-6b6f669f9079",
            "port": "out"
          },
          "target": {
            "block": "28accbaa-b3f4-5f83-830d-a5aa6a0f3e40",
            "port": "b"
          }
        },
        {
          "source": {
            "block": "28accbaa-b3f4-5f83-830d-a5aa6a0f3e40",
            "port": "y_and"
          },
          "target": {
            "block": "3853be2e-cb31-58a5-9da0-d91028e339c3",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "28accbaa-b3f4-5f83-830d-a5aa6a0f3e40",
            "port": "y_or"
          },
          "target": {
            "block": "64320c0a-cfcb-5abd-816d-5f40a0a7645c",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "28accbaa-b3f4-5f83-830d-a5aa6a0f3e40",
            "port": "y_not"
          },
          "target": {
            "block": "5a1e7f0d-2cc9-5d1b-bbd4-fb6b1d1ca143",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "28accbaa-b3f4-5f83-830d-a5aa6a0f3e40",
            "port": "y_nand"
          },
          "target": {
            "block": "9e139b0d-d04f-5977-8d1f-1e64872aede5",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "28accbaa-b3f4-5f83-830d-a5aa6a0f3e40",
            "port": "y_nor"
          },
          "target": {
            "block": "a5f50fef-4703-5d0e-87e3-5eb111b47d2c",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "28accbaa-b3f4-5f83-830d-a5aa6a0f3e40",
            "port": "y_xnor"
          },
          "target": {
            "block": "4c2135d1-1ba6-54b2-a67f-2c5da261eef7",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "28accbaa-b3f4-5f83-830d-a5aa6a0f3e40",
            "port": "y_xor"
          },
          "target": {
            "block": "11b41006-cff4-540e-ad72-4889bfa99273",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "28accbaa-b3f4-5f83-830d-a5aa6a0f3e40",
            "port": "n_xor"
          },
          "target": {
            "block": "7ecea736-7cb5-5c2c-b027-08265b53f70d",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "28accbaa-b3f4-5f83-830d-a5aa6a0f3e40",
            "port": "n_not"
          },
          "target": {
            "block": "cae397c9-5caa-50bc-98be-aca2233f658f",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "28accbaa-b3f4-5f83-830d-a5aa6a0f3e40",
            "port": "n_and"
          },
          "target": {
            "block": "42980d70-829a-5ee8-bd59-9d3e7e442435",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "28accbaa-b3f4-5f83-830d-a5aa6a0f3e40",
            "port": "n_or"
          },
          "target": {
            "block": "55cfb152-684f-57fe-94ab-4293da918c1a",
            "port": "in"
          }
        }
      ]
    }
  },
  "dependencies": {}
}
