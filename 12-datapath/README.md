# Lesson 12 — decode and control

**Concept:** turning a 32-bit instruction word into control signals, without executing anything yet.

**You will build:** a decoder for the whole RV32I instruction set, plus the immediate generator.

**Needs the board:** no

**Prerequisites:** lesson 11

**Paths:** editor

> **Status: planned.** Scope and ordering are settled; the code and the written
> lesson are not here yet. Lessons are built in order, so this one is written
> once lesson 11 is complete. See
> [`docs/LESSON_TEMPLATE.md`](../docs/LESSON_TEMPLATE.md) for the shape every
> lesson takes.

---

## Why this lesson exists

The lesson that makes the ISA manual readable. After it, an instruction
encoding diagram stops being a wall of bit numbers and becomes obvious.

## Planned outline

1. the six instruction formats — R, I, S, B, U, J — laid out bit by bit
2. why the opcode is seven bits and always in the same place
3. the immediate generator: five ways of reassembling scattered bits, and why RISC-V scatters them (the sign bit stays put, and mux depth stays shallow)
4. control signals as a decode table: ALU op, operand sources, write enable, branch condition
5. an illegal-instruction output, because lesson 17 will need it
6. testing a decoder against real instructions disassembled by `riscv-objdump`

## Deliverables

- `*.v` — the design, synthesisable and lint-clean
- `tb_*.v` — a self-checking testbench printing `PASS` or `FAIL`
- `README.md` — the written lesson, following the template
- `diagrams/*.wave.json` — timing diagrams where timing is the point
- editor path only: see [why the visual path stops](../docs/src/paths.md)

**Next:** [lesson 13 — rv32i single](../13-rv32i-single/)
