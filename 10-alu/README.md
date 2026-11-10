# Lesson 10 — the ALU

**Concept:** 32-bit arithmetic and logic as one combinational block, selected by a function code.

**You will build:** the complete RV32I ALU: add, sub, and, or, xor, three shifts, and signed/unsigned comparison.

**Needs the board:** no

**Prerequisites:** lesson 08

**Paths:** editor

> **Status: planned.** Scope and ordering are settled; the code and the written
> lesson are not here yet. Lessons are built in order, so this one is written
> once lesson 08 is complete. See
> [`docs/LESSON_TEMPLATE.md`](../docs/LESSON_TEMPLATE.md) for the shape every
> lesson takes.

---

## Why this lesson exists

The first piece of the CPU, and the one where corner cases are most expensive
later. A wrong `SRA` on negative numbers is a bug you will meet five lessons
from now as a mysterious failure in compiled C.

## Planned outline

1. the RV32I operation set, and why it is exactly this set and no more
2. add and subtract from one adder, via two's-complement negation
3. `SLT` vs `SLTU`: signed comparison is not `<` on raw bits — the sign and overflow reasoning
4. the three shifts: logical left, logical right, arithmetic right, and the sign-extension trap in `SRA`
5. barrel shifter vs iterative shifter: LUTs against cycles, a real engineering choice
6. the critical path through a 32-bit adder, and what lesson 04 said that means for clock speed
7. testing: 2^64 input pairs is impossible, so directed edge cases plus randomised comparison against a reference model

## Deliverables

- `*.v` — the design, synthesisable and lint-clean
- `tb_*.v` — a self-checking testbench printing `PASS` or `FAIL`
- `README.md` — the written lesson, following the template
- `diagrams/*.wave.json` — timing diagrams where timing is the point
- editor path only: see [why the visual path stops](../docs/src/paths.md)

**Next:** [lesson 11 — regfile](../11-regfile/)
