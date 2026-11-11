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
          "id": "98282c70-6f39-435b-b756-8182cb0ec0ee",
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
          "id": "35b34fb6-8451-4d4f-ab88-ff731811d41e",
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
          "id": "723ce112-c03e-4026-aa47-69331601bd31",
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
          "id": "3556e6fe-0c32-449d-a8db-e31e5712ef91",
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
          "id": "7cb71b61-3872-46fc-935b-f6345894e039",
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
          "id": "f35dfece-3892-4854-8c93-67fa28d11cdc",
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
            "block": "7cb71b61-3872-46fc-935b-f6345894e039",
            "port": "constant-out"
          },
          "target": {
            "block": "3556e6fe-0c32-449d-a8db-e31e5712ef91",
            "port": "COUNT"
          }
        },
        {
          "source": {
            "block": "98282c70-6f39-435b-b756-8182cb0ec0ee",
            "port": "out"
          },
          "target": {
            "block": "3556e6fe-0c32-449d-a8db-e31e5712ef91",
            "port": "clk"
          }
        },
        {
          "source": {
            "block": "35b34fb6-8451-4d4f-ab88-ff731811d41e",
            "port": "out"
          },
          "target": {
            "block": "3556e6fe-0c32-449d-a8db-e31e5712ef91",
            "port": "noisy"
          }
        },
        {
          "source": {
            "block": "3556e6fe-0c32-449d-a8db-e31e5712ef91",
            "port": "clean"
          },
          "target": {
            "block": "723ce112-c03e-4026-aa47-69331601bd31",
            "port": "in"
          }
        }
      ]
    }
  },
  "dependencies": {}
}
