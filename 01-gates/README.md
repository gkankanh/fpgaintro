# Lesson 01 — logic gates

**Concept:** AND, OR, NOT, NAND, NOR, XOR — and the fact that an FPGA contains none of them.

**You will build:** every two-input gate, each verified against its complete truth table, plus NAND-only versions of all of them.

**Needs the board:** no

**Prerequisites:** lesson 00

**Paths:** editor + visual

> **Status: planned.** Scope and ordering are settled; the code and the written
> lesson are not here yet. Lessons are built in order, so this one is written
> once lesson 00 is complete. See
> [`docs/LESSON_TEMPLATE.md`](../docs/LESSON_TEMPLATE.md) for the shape every
> lesson takes.

---

## Why this lesson exists

There are no gates inside this FPGA. There are 4-input lookup tables, and
every gate you write becomes some entries in one. This is the lesson where
that stops being a fact you have read and becomes something you have measured:
a 2-input AND and a 4-input XOR cost the same. That single observation
reshapes how you estimate cost for the rest of the course, and it is why
nobody minimises gate count any more.

## Planned outline

1. `assign` as a wire, not a statement: `&`, `|`, `~`, `^` and their negations
2. truth tables as exhaustive testbenches — four input combinations, so test all four
3. bitwise vs logical operators (`&` vs `&&`) and the bug that hides between them
4. NAND is universal: build NOT, AND, OR and XOR from NAND alone, and verify each against the direct version
5. De Morgan's laws, demonstrated by proving two different expressions have identical truth tables
6. `make synth` on each gate: why a 2-input AND and a 4-input XOR both cost exactly one LUT4
7. `make graph`: what yosys actually built

## Deliverables

- `*.v` — the design, synthesisable and lint-clean
- `tb_*.v` — a self-checking testbench printing `PASS` or `FAIL`
- `README.md` — the written lesson, following the template
- `diagrams/*.wave.json` — timing diagrams where timing is the point
- `icestudio/*.json` + generated `.ice` — the visual path

**Next:** [lesson 02 — combinational](../02-combinational/)
