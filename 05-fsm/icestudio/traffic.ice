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
          "id": "33d85ca3-f55d-5a1d-aeaa-6a80743358b8",
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
          "id": "2f8c61f4-4796-5ff7-9e4e-77d6781eca14",
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
          "id": "f5e91948-01a2-56d6-852e-4b1d6ea2f3f4",
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
          "id": "8bc48192-7643-50f7-b3f6-88ac356feb76",
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
          "id": "50a44134-5b0a-5b63-9175-4ee162075b41",
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
          "id": "df992906-8402-53bc-9a76-2b1cd847936e",
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
          "id": "e1ad7e7a-d8f8-5a56-b3c8-eb70299de548",
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
          "id": "442d9d9a-172d-58af-a5fb-fd4400f04b5c",
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
          "id": "1cc5b498-d491-5fc9-af3e-49454dfbaeec",
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
          "id": "018e8681-966c-516d-8c02-7c2c148d7b13",
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
            "block": "442d9d9a-172d-58af-a5fb-fd4400f04b5c",
            "port": "constant-out"
          },
          "target": {
            "block": "e1ad7e7a-d8f8-5a56-b3c8-eb70299de548",
            "port": "TICKS_RED"
          }
        },
        {
          "source": {
            "block": "1cc5b498-d491-5fc9-af3e-49454dfbaeec",
            "port": "constant-out"
          },
          "target": {
            "block": "e1ad7e7a-d8f8-5a56-b3c8-eb70299de548",
            "port": "TICKS_GREEN"
          }
        },
        {
          "source": {
            "block": "33d85ca3-f55d-5a1d-aeaa-6a80743358b8",
            "port": "out"
          },
          "target": {
            "block": "e1ad7e7a-d8f8-5a56-b3c8-eb70299de548",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "2f8c61f4-4796-5ff7-9e4e-77d6781eca14",
            "port": "out"
          },
          "target": {
            "block": "e1ad7e7a-d8f8-5a56-b3c8-eb70299de548",
            "port": "rst"
          }
        },
        {
          "source": {
            "block": "f5e91948-01a2-56d6-852e-4b1d6ea2f3f4",
            "port": "out"
          },
          "target": {
            "block": "e1ad7e7a-d8f8-5a56-b3c8-eb70299de548",
            "port": "tick"
          }
        },
        {
          "source": {
            "block": "e1ad7e7a-d8f8-5a56-b3c8-eb70299de548",
            "port": "red"
          },
          "target": {
            "block": "8bc48192-7643-50f7-b3f6-88ac356feb76",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "e1ad7e7a-d8f8-5a56-b3c8-eb70299de548",
            "port": "amber"
          },
          "target": {
            "block": "50a44134-5b0a-5b63-9175-4ee162075b41",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "e1ad7e7a-d8f8-5a56-b3c8-eb70299de548",
            "port": "green"
          },
          "target": {
            "block": "df992906-8402-53bc-9a76-2b1cd847936e",
            "port": "in"
          }
        }
      ]
    }
  },
  "dependencies": {}
}
