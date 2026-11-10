# Lesson 02 — combinational logic

**Concept:** logic with no memory, built up into useful blocks — and testable exhaustively.

**You will build:** a 7-segment hex decoder and a 4-bit ripple-carry adder.

**Needs the board:** no

**Prerequisites:** lesson 01

**Paths:** editor + visual

> **Status: planned.** Scope and ordering are settled; the code and the written
> lesson are not here yet. Lessons are built in order, so this one is written
> once lesson 01 is complete. See
> [`docs/LESSON_TEMPLATE.md`](../docs/LESSON_TEMPLATE.md) for the shape every
> lesson takes.

---

## Why this lesson exists

The last point in the course where exhaustive verification is possible — 512
cases take microseconds. From lesson 03 onward there is state, the input space
becomes sequences rather than combinations, and you are back to choosing test
cases. Build the habit while the habit is cheap.

## Planned outline

1. the multiplexer: the conditional operator, `case`, and why muxes are the most common structure in a CPU
2. decoders: 2-to-4, 4-to-16, and where they turn up (instruction decode, address decode, chip select)
3. a 7-segment hex decoder written three ways — `case`, a ROM array, minimised logic — all with identical truth tables
4. the full adder, then a 4-bit ripple-carry chain, then just `a + b`, with the three schematics compared
5. carry propagation as the reason addition has a critical path at all
6. exhaustive testing: 2^9 = 512 cases for a 4-bit adder with carry-in, so check every one

## Deliverables

- `*.v` — the design, synthesisable and lint-clean
- `tb_*.v` — a self-checking testbench printing `PASS` or `FAIL`
- `README.md` — the written lesson, following the template
- `diagrams/*.wave.json` — timing diagrams where timing is the point
- `icestudio/*.json` + generated `.ice` — the visual path

**Next:** [lesson 03 — sequential](../03-sequential/)
