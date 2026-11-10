# Lesson 03 — sequential logic

**Concept:** the flip-flop: the only component that makes time exist.

**You will build:** a debounced button that increments a counter exactly once per press.

**Needs the board:** yes

**Prerequisites:** lesson 02

**Paths:** editor + visual

> **Status: planned.** Scope and ordering are settled; the code and the written
> lesson are not here yet. Lessons are built in order, so this one is written
> once lesson 02 is complete. See
> [`docs/LESSON_TEMPLATE.md`](../docs/LESSON_TEMPLATE.md) for the shape every
> lesson takes.

---

## Why this lesson exists

Everything from here on is a state machine, and every state machine is flip-
flops plus logic deciding what goes into them. The button is the excuse; the
content is the discipline of synchronous design.

## Planned outline

1. the D flip-flop, and what `always @(posedge clk)` compiles to on this fabric
2. registers and shift registers, and why blocking assignment silently destroys them
3. `<=` vs `=` demonstrated as two schematics from `make graph`, not as a rule to memorise
4. counters as dividers (lesson 00 again, now with the theory under it)
5. a mechanical switch is not a digital input: contact bounce, and what it does to a counter
6. a debouncer as a saturating counter; choosing the time constant from the switch's datasheet
7. edge detection: turning a level into a one-clock pulse, which every later lesson needs

## Deliverables

- `*.v` — the design, synthesisable and lint-clean
- `tb_*.v` — a self-checking testbench printing `PASS` or `FAIL`
- `README.md` — the written lesson, following the template
- `diagrams/*.wave.json` — timing diagrams where timing is the point
- `icestudio/*.json` + generated `.ice` — the visual path

**Next:** [lesson 04 — clocks](../04-clocks/)
