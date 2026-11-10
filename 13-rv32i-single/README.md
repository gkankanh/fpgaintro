# Lesson 13 — single-cycle RV32I

**Concept:** fetch, decode, execute, memory and writeback in one clock — the simplest thing that is a real CPU.

**You will build:** a core that runs hand-written RISC-V assembly from block RAM and shows results on the LEDs.

**Needs the board:** yes

**Prerequisites:** lesson 12

**Paths:** editor

> **Status: planned.** Scope and ordering are settled; the code and the written
> lesson are not here yet. Lessons are built in order, so this one is written
> once lesson 12 is complete. See
> [`docs/LESSON_TEMPLATE.md`](../docs/LESSON_TEMPLATE.md) for the shape every
> lesson takes.

---

## Why this lesson exists

The point where the course turns over: everything before was a component, this
is the machine. Single-cycle first because the datapath stays visible — no
pipeline registers obscuring who talks to whom.

## Planned outline

1. the datapath drawing before any code: PC, instruction memory, register file, ALU, data memory, writeback mux
2. assembling the pieces from lessons 10, 11 and 12 — they were built for this
3. the program counter: +4, branches, `JAL`, `JALR`
4. loads and stores: byte, halfword, word, and the alignment and sign-extension rules
5. `LUI` and `AUIPC`: building a 32-bit constant from two instructions
6. the clock-period problem: one cycle means the critical path is the entire datapath (lesson 04, now with consequences)
7. a test program assembled by hand and by `riscv-as`, with a testbench that checks final register state

## Deliverables

- `*.v` — the design, synthesisable and lint-clean
- `tb_*.v` — a self-checking testbench printing `PASS` or `FAIL`
- `README.md` — the written lesson, following the template
- `diagrams/*.wave.json` — timing diagrams where timing is the point
- editor path only: see [why the visual path stops](../docs/src/paths.md)

**Next:** [lesson 14 — formal](../14-formal/)
