# Lesson 14 — formal verification

**Concept:** proving a property for all inputs up to a bound, instead of testing the cases you thought of.

**You will build:** a `riscv-formal` proof that the lesson 13 core really implements RV32I.

**Needs the board:** no

**Prerequisites:** lesson 13

**Paths:** editor

> **Status: planned.** Scope and ordering are settled; the code and the written
> lesson are not here yet. Lessons are built in order, so this one is written
> once lesson 13 is complete. See
> [`docs/LESSON_TEMPLATE.md`](../docs/LESSON_TEMPLATE.md) for the shape every
> lesson takes.

---

## Why this lesson exists

A testbench tells you a design works for inputs you imagined. For a CPU that
is nowhere near enough — the bugs live in combinations nobody imagines. This
is also where you find out which earlier lessons were quietly wrong.

## Planned outline

1. what a bounded model checker does, and what 'bounded' excludes
2. assertions, assumptions and covers — and how assuming too much proves nothing at all
3. a property about the ALU, and watching sby find a counterexample you would never have written a test for
4. `riscv-formal`: an instruction-level specification of RV32I to check a core against
5. wiring the RVFI trace interface into the lesson 13 core
6. reading a counterexample: sby hands you the shortest instruction sequence that breaks you

## Deliverables

- `*.v` — the design, synthesisable and lint-clean
- `tb_*.v` — a self-checking testbench printing `PASS` or `FAIL`
- `README.md` — the written lesson, following the template
- `diagrams/*.wave.json` — timing diagrams where timing is the point
- editor path only: see [why the visual path stops](../docs/src/paths.md)

**Next:** [lesson 15 — soc](../15-soc/)
