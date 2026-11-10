# Lesson 05 — finite state machines

**Concept:** encoding 'where am I in a process' as a register, with transitions as combinational logic.

**You will build:** a traffic-light controller, then a button-sequence lock that opens on a secret combination.

**Needs the board:** yes

**Prerequisites:** lesson 04

**Paths:** editor + visual

> **Status: planned.** Scope and ordering are settled; the code and the written
> lesson are not here yet. Lessons are built in order, so this one is written
> once lesson 04 is complete. See
> [`docs/LESSON_TEMPLATE.md`](../docs/LESSON_TEMPLATE.md) for the shape every
> lesson takes.

---

## Why this lesson exists

The SPI engine in lesson 06, the UART in lesson 09 and the CPU's control unit
in lesson 13 are all this one pattern at increasing scale. Get the shape right
here and the rest is bookkeeping.

## Planned outline

1. the state diagram on paper first — the design happens before the Verilog
2. the canonical two-block form: one clocked block for state, one combinational for next-state
3. Moore vs Mealy: outputs from state alone, or from state and input, and the timing difference it makes
4. binary vs one-hot encoding, measured on this fabric with `make synth`
5. `default:` in every case statement, and the latch you infer without it
6. testing an FSM: drive sequences, assert outputs, and cover every transition at least once

## Deliverables

- `*.v` — the design, synthesisable and lint-clean
- `tb_*.v` — a self-checking testbench printing `PASS` or `FAIL`
- `README.md` — the written lesson, following the template
- `diagrams/*.wave.json` — timing diagrams where timing is the point
- `icestudio/*.json` + generated `.ice` — the visual path

**Next:** [lesson 06 — spi oled](../06-spi-oled/)
