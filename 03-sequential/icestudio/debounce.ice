{
  "version": "1.2",
  "package": {
    "name": "debounce",
    "version": "1.0",
    "description": "Lesson 03 - a saturating-counter debouncer.",
    "author": "ULX3S Digital Design Course",
    "image": ""
  },
  "design": {
    "board": "ulx3s-85f",
    "graph": {
      "blocks": [
        {
          "id": "e9687f0f-c126-4386-b305-83abacb04aad",
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
          "id": "3cf3ea62-3eca-4210-80da-cc4dd4cdc0b6",
          "type": "basic.output",
          "data": {
            "name": "clean",
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
            "x": 888,
            "y": 48
          }
        },
        {
          "id": "f023ec90-5b5d-4c75-8285-d9cf7a14dc5c",
          "type": "basic.input",
          "data": {
            "name": "btn (noisy)",
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
            "y": 168
          }
        },
        {
          "id": "570e9e8e-6b5d-4187-a6a9-6b85637e12cd",
          "type": "basic.constant",
          "data": {
            "name": "COUNT",
            "value": "250000",
            "local": false
          },
          "position": {
            "x": 432,
            "y": -240
          }
        },
        {
          "id": "8b5da012-ceee-472b-9b14-0ad40e2266c3",
          "type": "basic.code",
          "data": {
            "code": "// $clog2 sizes the counter to exactly fit COUNT — one of the few places a\n// system function is allowed in synthesisable code.\nlocalparam CW = $clog2(COUNT + 1);\nreg [CW-1:0] cnt = 0;\n\nalways @(posedge clk) begin\n    if (noisy == clean) begin\n        // They agree: nothing is happening. Hold the timer at zero so a\n        // later disagreement has to wait the full COUNT.\n        cnt <= 0;\n    end else if (cnt == COUNT[CW-1:0]) begin\n        // Disagreed for long enough: accept the new level.\n        clean <= noisy;\n        cnt   <= 0;\n    end else begin\n        cnt <= cnt + 1'b1;\n    end\nend\n",
            "params": [
              {
                "name": "COUNT"
              }
            ],
            "ports": {
              "in": [
                {
                  "name": "clk"
                },
                {
                  "name": "noisy"
                }
              ],
              "out": [
                {
                  "name": "clean"
                }
              ]
            }
          },
          "position": {
            "x": 256,
            "y": -88
          },
          "size": {
            "width": 600,
            "height": 424
          }
        },
        {
          "id": "d4186535-10ff-47e1-a527-69b755d5e361",
          "type": "basic.info",
          "data": {
            "info": "## Lesson 03 - the debouncer\n\nA button is two pieces of springy metal. When they meet they bounce apart and meet again, several times, over 1-10 ms. At 25 MHz that is up to **250,000 clock cycles** of perfectly clean, fully-sampled transitions - so one press genuinely *is* several presses as far as the hardware can tell.\n\nThe rule here: the input must disagree with the current output **continuously** for `COUNT` clocks before the output is allowed to follow. Any shorter disagreement resets the timer, which rejects bounce of any pattern rather than just bounce shorter than one sample period.\n\nThe price is latency: the output lags by `COUNT` clocks. So pick the smallest `COUNT` that comfortably exceeds your switch's bounce time - 250,000 is 10 ms, the usual safe answer.\n\n### Try it\n\nChange `COUNT` on the constant block to 1000 and rebuild. The window is now shorter than the bounce, and the output starts to misbehave again.",
            "readonly": true
          },
          "position": {
            "x": -304,
            "y": -368
          },
          "size": {
            "width": 400,
            "height": 256
          }
        }
      ],
      "wires": [
        {
          "source": {
            "block": "8b5da012-ceee-472b-9b14-0ad40e2266c3",
            "port": "clean"
          },
          "target": {
            "block": "3cf3ea62-3eca-4210-80da-cc4dd4cdc0b6",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "f023ec90-5b5d-4c75-8285-d9cf7a14dc5c",
            "port": "out"
          },
          "target": {
            "block": "8b5da012-ceee-472b-9b14-0ad40e2266c3",
            "port": "noisy"
          }
        },
        {
          "source": {
            "block": "e9687f0f-c126-4386-b305-83abacb04aad",
            "port": "out"
          },
          "target": {
            "block": "8b5da012-ceee-472b-9b14-0ad40e2266c3",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "570e9e8e-6b5d-4187-a6a9-6b85637e12cd",
            "port": "constant-out"
          },
          "target": {
            "block": "8b5da012-ceee-472b-9b14-0ad40e2266c3",
            "port": "COUNT"
          }
        }
      ]
    }
  },
  "dependencies": {},
  "settings": {
    "version": 1,
    "tools": {
      "verify": {
        "override": false,
        "relaxRealToInt": false,
        "relaxIoPrimitives": false,
        "allowLogicLoops": false,
        "verilatorFlags": ""
      },
      "build": {
        "override": false,
        "yosysFlags": "",
        "nextpnrFlags": ""
      },
      "upload": {
        "override": false
      }
    }
  }
}