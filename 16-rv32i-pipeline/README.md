# Lesson 16 — pipelining

**Concept:** overlapping instructions, and the hazard logic that makes overlap safe.

**You will build:** a 5-stage version of the same core, running the same programs, at a higher clock.

**Needs the board:** yes

**Prerequisites:** lesson 15

**Paths:** editor

**By the end you can:**

- Explain why pipelining raises the clock without making any stage faster.
- Identify data, control and structural hazards.
- Explain which hazard forwarding can fix and which it cannot.
- Measure cycles-per-instruction and say where the cost went.

> **Status: planned.** Scope and ordering are settled; the code and the written
> lesson are not here yet. Lessons are built in order, so this one is written
> once lesson 15 is complete. See
> [`docs/LESSON_TEMPLATE.md`](../docs/LESSON_TEMPLATE.md) for the shape every
> lesson takes.

---

## Why this lesson exists

Pipelining is the idea that turned CPUs from simple to subtle. Doing it to a
core you already have, with a proof you already wrote, is the honest way to
see what the complexity buys and what it costs.

## Planned outline

1. IF, ID, EX, MEM, WB, and the pipeline registers between them
2. why the clock can now be faster: the critical path is one stage, not the whole datapath
3. data hazards: needing a result that has not been written back yet
4. forwarding paths, and the one hazard forwarding cannot fix (load-use)
5. stalling: bubbles, and the logic that inserts them
6. control hazards: a taken branch means the two instructions already fetched are wrong
7. flushing versus predicting, and measuring CPI on a real program to see what it cost
8. re-running the lesson 14 proof: the specification did not change, so the proof should still pass

## Deliverables

- `*.v` — the design, synthesisable and lint-clean
- `tb_*.v` — a self-checking testbench printing `PASS` or `FAIL`
- `README.md` — the written lesson, following the template
- `diagrams/*.wave.json` — timing diagrams where timing is the point
- editor path only: see [why the visual path stops](../docs/src/paths.md)

**Next:** [lesson 17 — extensions](../17-extensions/)
