{
  "version": "1.2",
  "package": {
    "name": "gates",
    "version": "1.0",
    "description": "Lesson 01 - every two-input gate, plus NAND-only equivalents.",
    "author": "ULX3S Digital Design Course",
    "image": ""
  },
  "design": {
    "board": "ulx3s-85f",
    "graph": {
      "blocks": [
        {
          "id": "3ccba515-1a94-4da9-85d2-75ed2c773949",
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
          "id": "190225e1-a97e-44c9-b84c-bf98fd325600",
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
          "id": "3b7eec46-4f00-437e-b437-414712933b24",
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
          "id": "701eb365-2a57-4441-ab68-810ba2095f9c",
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
          "id": "d8d5639f-f124-4be8-a5e4-e68d7700b9ef",
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
          "id": "7c16be9b-e504-4301-b658-6d480d5e19bd",
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
          "id": "c8c060cd-ac8d-444a-a881-f9af7c76ed8e",
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
          "id": "b8b7723d-384b-4aa5-a4c7-234f3d78d946",
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
          "id": "9f526d91-8751-413e-a676-9ba849dc9e8f",
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
          "id": "40957a22-cc77-4c59-aed7-46e056e3c3e9",
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
          "id": "8aff9e15-43bd-422c-975b-ed09aeff496f",
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
          "id": "79396576-c844-4c05-a702-9d85561970b0",
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
          "id": "3d6c6105-9c23-4bb4-8bbd-1f4e4e5d7ee0",
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
          "id": "fa5c996c-7b78-4204-8647-6a9d7e350440",
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
          "id": "c3c21cd1-eeb9-48c8-8548-2df5d98f880b",
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
            "block": "3ccba515-1a94-4da9-85d2-75ed2c773949",
            "port": "out"
          },
          "target": {
            "block": "fa5c996c-7b78-4204-8647-6a9d7e350440",
            "port": "a"
          }
        },
        {
          "source": {
            "block": "190225e1-a97e-44c9-b84c-bf98fd325600",
            "port": "out"
          },
          "target": {
            "block": "fa5c996c-7b78-4204-8647-6a9d7e350440",
            "port": "b"
          }
        },
        {
          "source": {
            "block": "fa5c996c-7b78-4204-8647-6a9d7e350440",
            "port": "y_and"
          },
          "target": {
            "block": "3b7eec46-4f00-437e-b437-414712933b24",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "fa5c996c-7b78-4204-8647-6a9d7e350440",
            "port": "y_or"
          },
          "target": {
            "block": "701eb365-2a57-4441-ab68-810ba2095f9c",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "fa5c996c-7b78-4204-8647-6a9d7e350440",
            "port": "y_not"
          },
          "target": {
            "block": "d8d5639f-f124-4be8-a5e4-e68d7700b9ef",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "fa5c996c-7b78-4204-8647-6a9d7e350440",
            "port": "y_nand"
          },
          "target": {
            "block": "7c16be9b-e504-4301-b658-6d480d5e19bd",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "fa5c996c-7b78-4204-8647-6a9d7e350440",
            "port": "y_nor"
          },
          "target": {
            "block": "c8c060cd-ac8d-444a-a881-f9af7c76ed8e",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "fa5c996c-7b78-4204-8647-6a9d7e350440",
            "port": "y_xnor"
          },
          "target": {
            "block": "b8b7723d-384b-4aa5-a4c7-234f3d78d946",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "fa5c996c-7b78-4204-8647-6a9d7e350440",
            "port": "y_xor"
          },
          "target": {
            "block": "9f526d91-8751-413e-a676-9ba849dc9e8f",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "fa5c996c-7b78-4204-8647-6a9d7e350440",
            "port": "n_xor"
          },
          "target": {
            "block": "40957a22-cc77-4c59-aed7-46e056e3c3e9",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "fa5c996c-7b78-4204-8647-6a9d7e350440",
            "port": "n_not"
          },
          "target": {
            "block": "8aff9e15-43bd-422c-975b-ed09aeff496f",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "fa5c996c-7b78-4204-8647-6a9d7e350440",
            "port": "n_and"
          },
          "target": {
            "block": "79396576-c844-4c05-a702-9d85561970b0",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "fa5c996c-7b78-4204-8647-6a9d7e350440",
            "port": "n_or"
          },
          "target": {
            "block": "3d6c6105-9c23-4bb4-8bbd-1f4e4e5d7ee0",
            "port": "in"
          }
        }
      ]
    }
  },
  "dependencies": {}
}
