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
          "id": "c3d144bc-d28f-4522-afae-b8c7d65fbc67",
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
          "id": "b7b447eb-c3b3-41aa-a5ab-e00af6371278",
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
          "id": "fc2afdb2-272c-4818-9326-4778bd75663d",
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
          "id": "fcfee5a9-58f8-4126-840b-8e7093d7d2ed",
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
          "id": "9e8a31db-3769-423e-8ac5-071834d0ef0d",
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
          "id": "64d327ce-929b-4353-aa8f-0f7c78897bbf",
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
          "id": "471f3665-3bfa-4944-93ca-1c4a772f14b3",
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
          "id": "a1597fe8-8ac1-4cf4-877d-15b7d4ca4eb9",
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
          "id": "7e845d13-7d63-4db3-b6e4-f8e567278e2a",
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
          "id": "2ded98fa-422a-4b27-8a14-9144a95b6674",
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
          "id": "2a1bd9fa-e9ad-4d72-b63a-efa29c2a8770",
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
          "id": "40602b9e-2baa-4aaf-8e38-623de7960bfe",
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
          "id": "cc9711db-d081-4705-b181-4f8f8727dea4",
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
          "id": "04bfbbfd-3df2-4f68-b2fe-b60fae53cf04",
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
          "id": "74c99165-feb4-4689-bee8-3becfd156e2f",
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
            "block": "c3d144bc-d28f-4522-afae-b8c7d65fbc67",
            "port": "out"
          },
          "target": {
            "block": "04bfbbfd-3df2-4f68-b2fe-b60fae53cf04",
            "port": "a"
          }
        },
        {
          "source": {
            "block": "b7b447eb-c3b3-41aa-a5ab-e00af6371278",
            "port": "out"
          },
          "target": {
            "block": "04bfbbfd-3df2-4f68-b2fe-b60fae53cf04",
            "port": "b"
          }
        },
        {
          "source": {
            "block": "04bfbbfd-3df2-4f68-b2fe-b60fae53cf04",
            "port": "y_and"
          },
          "target": {
            "block": "fc2afdb2-272c-4818-9326-4778bd75663d",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "04bfbbfd-3df2-4f68-b2fe-b60fae53cf04",
            "port": "y_or"
          },
          "target": {
            "block": "fcfee5a9-58f8-4126-840b-8e7093d7d2ed",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "04bfbbfd-3df2-4f68-b2fe-b60fae53cf04",
            "port": "y_not"
          },
          "target": {
            "block": "9e8a31db-3769-423e-8ac5-071834d0ef0d",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "04bfbbfd-3df2-4f68-b2fe-b60fae53cf04",
            "port": "y_nand"
          },
          "target": {
            "block": "64d327ce-929b-4353-aa8f-0f7c78897bbf",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "04bfbbfd-3df2-4f68-b2fe-b60fae53cf04",
            "port": "y_nor"
          },
          "target": {
            "block": "471f3665-3bfa-4944-93ca-1c4a772f14b3",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "04bfbbfd-3df2-4f68-b2fe-b60fae53cf04",
            "port": "y_xnor"
          },
          "target": {
            "block": "a1597fe8-8ac1-4cf4-877d-15b7d4ca4eb9",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "04bfbbfd-3df2-4f68-b2fe-b60fae53cf04",
            "port": "y_xor"
          },
          "target": {
            "block": "7e845d13-7d63-4db3-b6e4-f8e567278e2a",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "04bfbbfd-3df2-4f68-b2fe-b60fae53cf04",
            "port": "n_xor"
          },
          "target": {
            "block": "2ded98fa-422a-4b27-8a14-9144a95b6674",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "04bfbbfd-3df2-4f68-b2fe-b60fae53cf04",
            "port": "n_not"
          },
          "target": {
            "block": "2a1bd9fa-e9ad-4d72-b63a-efa29c2a8770",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "04bfbbfd-3df2-4f68-b2fe-b60fae53cf04",
            "port": "n_and"
          },
          "target": {
            "block": "40602b9e-2baa-4aaf-8e38-623de7960bfe",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "04bfbbfd-3df2-4f68-b2fe-b60fae53cf04",
            "port": "n_or"
          },
          "target": {
            "block": "cc9711db-d081-4705-b181-4f8f8727dea4",
            "port": "in"
          }
        }
      ]
    }
  },
  "dependencies": {}
}
