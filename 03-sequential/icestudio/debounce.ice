{
  "version": "1.2",
  "package": {
    "name": "debounce",
    "version": "1.0",
    "description": "Lesson 03 - a saturating-counter debouncer.",
    "author": "The Open FPGA Course",
    "image": ""
  },
  "design": {
    "board": "ulx3s-85f",
    "graph": {
      "blocks": [
        {
          "id": "21ef2853-859e-502c-9c8a-1046b5e9921d",
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
          "id": "cc8b3d30-c4f8-5ecc-869e-ed8a00767b97",
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
          "id": "ec0dd259-6b72-5da1-ac1c-ffc1c085d6b0",
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
            "x": 816,
            "y": 48
          }
        },
        {
          "id": "5961e6d6-e2f2-595d-8183-47a471e6b9d7",
          "type": "basic.code",
          "data": {
            "code": "// $clog2 sizes the counter to exactly fit COUNT \u2014 one of the few places a\n// system function is allowed in synthesisable code.\nlocalparam CW = $clog2(COUNT + 1);\nreg [CW-1:0] cnt = 0;\n\nalways @(posedge clk) begin\n    if (noisy == clean) begin\n        // They agree: nothing is happening. Hold the timer at zero so a\n        // later disagreement has to wait the full COUNT.\n        cnt <= 0;\n    end else if (cnt == COUNT[CW-1:0]) begin\n        // Disagreed for long enough: accept the new level.\n        clean <= noisy;\n        cnt   <= 0;\n    end else begin\n        cnt <= cnt + 1'b1;\n    end\nend\n",
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
            "x": 384,
            "y": 48
          }
        },
        {
          "id": "e1e90db0-b645-5eba-bb5c-39c9831b86bc",
          "type": "basic.constant",
          "data": {
            "name": "COUNT",
            "value": "250000",
            "local": false
          },
          "position": {
            "x": 416,
            "y": -112
          }
        },
        {
          "id": "1381f31b-3eb1-5468-afc6-45701b60a5dc",
          "type": "basic.info",
          "data": {
            "info": "## Lesson 03 - the debouncer\n\nA button is two pieces of springy metal. When they meet they bounce apart and meet again, several times, over 1-10 ms. At 25 MHz that is up to **250,000 clock cycles** of perfectly clean, fully-sampled transitions - so one press genuinely *is* several presses as far as the hardware can tell.\n\nThe rule here: the input must disagree with the current output **continuously** for `COUNT` clocks before the output is allowed to follow. Any shorter disagreement resets the timer, which rejects bounce of any pattern rather than just bounce shorter than one sample period.\n\nThe price is latency: the output lags by `COUNT` clocks. So pick the smallest `COUNT` that comfortably exceeds your switch's bounce time - 250,000 is 10 ms, the usual safe answer.\n\n### Try it\n\nChange `COUNT` on the constant block to 1000 and rebuild. The window is now shorter than the bounce, and the output starts to misbehave again.",
            "readonly": true
          },
          "position": {
            "x": 48,
            "y": 352
          }
        }
      ],
      "wires": [
        {
          "source": {
            "block": "e1e90db0-b645-5eba-bb5c-39c9831b86bc",
            "port": "constant-out"
          },
          "target": {
            "block": "5961e6d6-e2f2-595d-8183-47a471e6b9d7",
            "port": "COUNT"
          }
        },
        {
          "source": {
            "block": "21ef2853-859e-502c-9c8a-1046b5e9921d",
            "port": "out"
          },
          "target": {
            "block": "5961e6d6-e2f2-595d-8183-47a471e6b9d7",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "cc8b3d30-c4f8-5ecc-869e-ed8a00767b97",
            "port": "out"
          },
          "target": {
            "block": "5961e6d6-e2f2-595d-8183-47a471e6b9d7",
            "port": "noisy"
          }
        },
        {
          "source": {
            "block": "5961e6d6-e2f2-595d-8183-47a471e6b9d7",
            "port": "clean"
          },
          "target": {
            "block": "ec0dd259-6b72-5da1-ac1c-ffc1c085d6b0",
            "port": "in"
          }
        }
      ]
    }
  },
  "dependencies": {}
}
