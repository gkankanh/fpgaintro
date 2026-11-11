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
          "id": "913a6885-dd2f-4135-a877-d6b02f7db442",
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
          "id": "a8c2cead-33b8-4a5f-a3c8-818f549a4703",
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
          "id": "ad3eb178-843b-4210-b9b3-047b036b446e",
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
          "id": "1e34c206-c0a1-43e9-a450-ef2d6ae4142f",
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
          "id": "334640e5-b18e-4cbe-ba63-96654cb129e2",
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
          "id": "32858c3d-6629-469a-a140-730d3ccb1976",
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
          "id": "6613d957-5c07-40bc-9103-aea225fa530f",
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
          "id": "73bc8b43-4f70-45bc-a57d-05209c1d17f6",
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
          "id": "fc8fd4d7-89d9-4cb6-ad44-c790bc99e5f3",
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
          "id": "da970463-d40e-4ca6-a392-76d4c84d6334",
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
          "id": "a936bc7a-3f00-4436-83c8-aec160fb0980",
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
          "id": "f7c91ab9-03c3-4a7d-abbe-fe25ce845bac",
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
          "id": "bacec617-5d07-43f9-a5e5-327fc13fc235",
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
          "id": "a982ec90-03df-46d9-9950-ba4e33acd6a8",
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
          "id": "9ce106d6-b076-4419-a272-06acd44ebcd1",
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
            "block": "913a6885-dd2f-4135-a877-d6b02f7db442",
            "port": "out"
          },
          "target": {
            "block": "a982ec90-03df-46d9-9950-ba4e33acd6a8",
            "port": "a"
          }
        },
        {
          "source": {
            "block": "a8c2cead-33b8-4a5f-a3c8-818f549a4703",
            "port": "out"
          },
          "target": {
            "block": "a982ec90-03df-46d9-9950-ba4e33acd6a8",
            "port": "b"
          }
        },
        {
          "source": {
            "block": "a982ec90-03df-46d9-9950-ba4e33acd6a8",
            "port": "y_and"
          },
          "target": {
            "block": "ad3eb178-843b-4210-b9b3-047b036b446e",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "a982ec90-03df-46d9-9950-ba4e33acd6a8",
            "port": "y_or"
          },
          "target": {
            "block": "1e34c206-c0a1-43e9-a450-ef2d6ae4142f",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "a982ec90-03df-46d9-9950-ba4e33acd6a8",
            "port": "y_not"
          },
          "target": {
            "block": "334640e5-b18e-4cbe-ba63-96654cb129e2",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "a982ec90-03df-46d9-9950-ba4e33acd6a8",
            "port": "y_nand"
          },
          "target": {
            "block": "32858c3d-6629-469a-a140-730d3ccb1976",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "a982ec90-03df-46d9-9950-ba4e33acd6a8",
            "port": "y_nor"
          },
          "target": {
            "block": "6613d957-5c07-40bc-9103-aea225fa530f",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "a982ec90-03df-46d9-9950-ba4e33acd6a8",
            "port": "y_xnor"
          },
          "target": {
            "block": "73bc8b43-4f70-45bc-a57d-05209c1d17f6",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "a982ec90-03df-46d9-9950-ba4e33acd6a8",
            "port": "y_xor"
          },
          "target": {
            "block": "fc8fd4d7-89d9-4cb6-ad44-c790bc99e5f3",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "a982ec90-03df-46d9-9950-ba4e33acd6a8",
            "port": "n_xor"
          },
          "target": {
            "block": "da970463-d40e-4ca6-a392-76d4c84d6334",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "a982ec90-03df-46d9-9950-ba4e33acd6a8",
            "port": "n_not"
          },
          "target": {
            "block": "a936bc7a-3f00-4436-83c8-aec160fb0980",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "a982ec90-03df-46d9-9950-ba4e33acd6a8",
            "port": "n_and"
          },
          "target": {
            "block": "f7c91ab9-03c3-4a7d-abbe-fe25ce845bac",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "a982ec90-03df-46d9-9950-ba4e33acd6a8",
            "port": "n_or"
          },
          "target": {
            "block": "bacec617-5d07-43f9-a5e5-327fc13fc235",
            "port": "in"
          }
        }
      ]
    }
  },
  "dependencies": {}
}
