# Lesson 11 — the register file

**Concept:** two reads and one write per cycle from one array, and the special case of x0.

**You will build:** RV32I's 32x32-bit register file, with the write-then-read hazard handled.

**Needs the board:** no

**Prerequisites:** lesson 10

**Paths:** editor

> **Status: planned.** Scope and ordering are settled; the code and the written
> lesson are not here yet. Lessons are built in order, so this one is written
> once lesson 10 is complete. See
> [`docs/LESSON_TEMPLATE.md`](../docs/LESSON_TEMPLATE.md) for the shape every
> lesson takes.

---

## Why this lesson exists

Small, but it fixes the shape of the datapath. How many ports the register
file has determines how many operands an instruction can have, which is a
large part of why RISC instruction sets look the way they do.

## Planned outline

1. why two read ports: every R-type instruction needs rs1 and rs2 in the same cycle
2. x0 hardwired to zero — reads return 0, writes are discarded, and how much of the ISA that simplifies
3. flip-flops vs BRAM: 1,024 flip-flops, or two block RAMs with a cycle of read latency (lesson 08's trade-off again)
4. the read-during-write hazard, and why bypassing it matters even in a single-cycle CPU
5. testing: write every register, read it back from both ports, confirm x0 stays zero

## Deliverables

- `*.v` — the design, synthesisable and lint-clean
- `tb_*.v` — a self-checking testbench printing `PASS` or `FAIL`
- `README.md` — the written lesson, following the template
- `diagrams/*.wave.json` — timing diagrams where timing is the point
- editor path only: see [why the visual path stops](../docs/src/paths.md)

**Next:** [lesson 12 — datapath](../12-datapath/)
