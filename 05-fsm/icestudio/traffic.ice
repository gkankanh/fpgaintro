{
  "version": "1.2",
  "package": {
    "name": "traffic",
    "version": "1.0",
    "description": "Lesson 05 - a Moore state machine: the traffic light.",
    "author": "The Open FPGA Course",
    "image": ""
  },
  "design": {
    "board": "ulx3s-85f",
    "graph": {
      "blocks": [
        {
          "id": "b7243f18-a9da-4446-95e4-7f564a9b3f58",
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
          "id": "f6a6b6a5-67eb-4d60-9423-0f49ac8213e9",
          "type": "basic.input",
          "data": {
            "name": "rst",
            "pins": [
              {
                "index": "0",
                "name": "btn_5",
                "value": "U1"
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
          "id": "7b7c2be7-0dfd-4f18-8eaf-e4d358479964",
          "type": "basic.input",
          "data": {
            "name": "tick (press to advance)",
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
            "y": 288
          }
        },
        {
          "id": "93d1275c-b63e-4e84-bbdf-61c414690243",
          "type": "basic.output",
          "data": {
            "name": "red",
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
          "id": "e2be71b6-60f1-4f1d-8899-284adfefc37a",
          "type": "basic.output",
          "data": {
            "name": "amber",
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
          "id": "6ceb1142-edc8-4388-a844-2ba782f44f20",
          "type": "basic.output",
          "data": {
            "name": "green",
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
          "id": "aee46956-0582-43f7-a400-4fb0e59f3d53",
          "type": "basic.code",
          "data": {
            "code": "// State encoding. Written as named constants, never as bare numbers in\n// the case statement \u2014 `2'd2` tells a reader nothing and `S_GREEN` tells\n// them everything.\nlocalparam [1:0] S_RED       = 2'd0,\n                 S_RED_AMBER = 2'd1,\n                 S_GREEN     = 2'd2,\n                 S_AMBER     = 2'd3;\n\n// ENCODING. yosys's `fsm` pass detects this register as a state variable\n// and re-encodes it as it sees fit \u2014 so the constants above are a\n// suggestion, not an instruction. To take control, put an attribute on the\n// state register itself (NOT on the module; it has no effect there):\n//\n//     (* fsm_encoding = \"one-hot\" *) reg [1:0] state = S_RED;\n//     (* fsm_encoding = \"binary\"  *) reg [1:0] state = S_RED;\n//     (* fsm_encoding = \"none\"    *) reg [1:0] state = S_RED;   // keep mine\n//\n// Binary uses ceil(log2(N)) flops and needs a decoder to answer \"which\n// state am I in\". One-hot uses N flops, exactly one high, so that question\n// becomes a single wire with no decoding at all.\n//\n// The textbook trade is \"one-hot costs flops, saves logic\", and on an FPGA\n// the flops are nearly free because every logic cell has one whether you\n// use it or not. So one-hot is supposed to win here.\n//\n// For THIS machine it loses badly \u2014 41 LUT4 against 12. Four states is\n// small, so one-hot's saving on decode never materialises, while every\n// comparison against the state has to be built from four bits instead of\n// two. One-hot earns its keep on wide state machines, not narrow ones.\n//\n// Which is the actual lesson: measure, do not inherit an opinion. The\n// README has the full table.\nreg [1:0] state = S_RED;\nreg [1:0] next;\nreg [2:0] timer = 0;\n\n// How long each state lasts, in ticks. A function of state alone, so it\n// belongs with the next-state logic rather than inside the clocked block.\nreg [2:0] duration;\nalways @(*)\n    case (state)\n        S_RED:       duration = TICKS_RED[2:0];\n        S_RED_AMBER: duration = 3'd1;\n        S_GREEN:     duration = TICKS_GREEN[2:0];\n        S_AMBER:     duration = 3'd1;\n        default:     duration = 3'd1;\n    endcase\n\nwire expired = tick && (timer + 1'b1 >= duration);\n\n// ---- 2. next-state logic: combinational, a pure function --------------\nalways @(*) begin\n    next = state;                 // default: stay put. Assign FIRST, so\n                                  // every path is covered and no latch\n                                  // can be inferred (lesson 02).\n    if (expired)\n        case (state)\n            S_RED:       next = S_RED_AMBER;\n            S_RED_AMBER: next = S_GREEN;\n            S_GREEN:     next = S_AMBER;\n            S_AMBER:     next = S_RED;\n            default:     next = S_RED;\n        endcase\nend\n\n// ---- 1. the state register: one clocked block, and nothing else -------\nalways @(posedge clk)\n    if (rst) begin\n        state <= S_RED;\n        timer <= 0;\n    end else begin\n        state <= next;\n        if (tick) timer <= expired ? 3'd0 : timer + 1'b1;\n    end\n\n// ---- 3. output logic: Moore \u2014 from state alone ------------------------\n// Written as continuous assignments because each lamp is a simple\n// predicate on the state. A `case` assigning three regs would do equally\n// well; this reads better for three independent one-bit outputs.\nassign red   = (state == S_RED) || (state == S_RED_AMBER);\nassign amber = (state == S_RED_AMBER) || (state == S_AMBER);\nassign green = (state == S_GREEN);\n",
            "params": [
              {
                "name": "TICKS_RED"
              },
              {
                "name": "TICKS_GREEN"
              }
            ],
            "ports": {
              "in": [
                {
                  "name": "clk"
                },
                {
                  "name": "rst"
                },
                {
                  "name": "tick"
                }
              ],
              "out": [
                {
                  "name": "red"
                },
                {
                  "name": "amber"
                },
                {
                  "name": "green"
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
          "id": "341f9487-2b96-4669-96bb-82eb20f766ae",
          "type": "basic.constant",
          "data": {
            "name": "TICKS_RED",
            "value": "4",
            "local": false
          },
          "position": {
            "x": 416,
            "y": -112
          }
        },
        {
          "id": "e3e41320-ec5e-41d0-8085-ed86b78984c9",
          "type": "basic.constant",
          "data": {
            "name": "TICKS_GREEN",
            "value": "4",
            "local": false
          },
          "position": {
            "x": 416,
            "y": -192
          }
        },
        {
          "id": "277dfad8-b8e5-45cb-bc0b-580ad5485902",
          "type": "basic.info",
          "data": {
            "info": "## Lesson 05 - the traffic light\n\nA **Moore** state machine: the lamps depend only on which state it is in, never on the inputs.\n\nHere `tick` is wired to a button rather than a one-second timer, so you advance the machine by hand and can watch it step through RED -> RED+AMBER -> GREEN -> AMBER -> RED. The button is **not** debounced in this build, so expect one press to advance it several states - which is lesson 03's point, arriving uninvited.\n\n### The canonical shape\n\nEvery FSM in this course is written as three parts:\n\n1. a **state register** - one clocked block, nothing else in it\n2. **next-state logic** - one combinational block, a pure function\n3. **output logic** - from state alone (Moore)\n\n### The thing to notice\n\nEncoding is a choice, and it is measured rather than assumed. Forcing this machine to one-hot costs **41 LUT4** against **12** for binary - nearly four times worse, because four states is too few for one-hot's decode saving to appear. One-hot earns its keep on wide state machines, not narrow ones.",
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
            "block": "341f9487-2b96-4669-96bb-82eb20f766ae",
            "port": "constant-out"
          },
          "target": {
            "block": "aee46956-0582-43f7-a400-4fb0e59f3d53",
            "port": "TICKS_RED"
          }
        },
        {
          "source": {
            "block": "e3e41320-ec5e-41d0-8085-ed86b78984c9",
            "port": "constant-out"
          },
          "target": {
            "block": "aee46956-0582-43f7-a400-4fb0e59f3d53",
            "port": "TICKS_GREEN"
          }
        },
        {
          "source": {
            "block": "b7243f18-a9da-4446-95e4-7f564a9b3f58",
            "port": "out"
          },
          "target": {
            "block": "aee46956-0582-43f7-a400-4fb0e59f3d53",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "f6a6b6a5-67eb-4d60-9423-0f49ac8213e9",
            "port": "out"
          },
          "target": {
            "block": "aee46956-0582-43f7-a400-4fb0e59f3d53",
            "port": "rst"
          }
        },
        {
          "source": {
            "block": "7b7c2be7-0dfd-4f18-8eaf-e4d358479964",
            "port": "out"
          },
          "target": {
            "block": "aee46956-0582-43f7-a400-4fb0e59f3d53",
            "port": "tick"
          }
        },
        {
          "source": {
            "block": "aee46956-0582-43f7-a400-4fb0e59f3d53",
            "port": "red"
          },
          "target": {
            "block": "93d1275c-b63e-4e84-bbdf-61c414690243",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "aee46956-0582-43f7-a400-4fb0e59f3d53",
            "port": "amber"
          },
          "target": {
            "block": "e2be71b6-60f1-4f1d-8899-284adfefc37a",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "aee46956-0582-43f7-a400-4fb0e59f3d53",
            "port": "green"
          },
          "target": {
            "block": "6ceb1142-edc8-4388-a844-2ba782f44f20",
            "port": "in"
          }
        }
      ]
    }
  },
  "dependencies": {}
}
