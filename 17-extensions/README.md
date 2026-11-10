# Lesson 17 — extensions

**Concept:** privileged state, traps, and the extensions that make a core usable rather than merely correct.

**You will build:** CSRs, a machine-timer interrupt, and hardware multiply.

**Needs the board:** yes

**Prerequisites:** lesson 16

**Paths:** editor

> **Status: planned.** Scope and ordering are settled; the code and the written
> lesson are not here yet. Lessons are built in order, so this one is written
> once lesson 16 is complete. See
> [`docs/LESSON_TEMPLATE.md`](../docs/LESSON_TEMPLATE.md) for the shape every
> lesson takes.

---

## Why this lesson exists

Genuinely optional — the course's goal is met at lesson 16. It is here because
'a correct RV32I core' and 'a core that can run an RTOS' are separated by
exactly these pieces, and it is worth seeing how few they are.

## Planned outline

1. CSRs: the control and status registers, and `CSRRW`/`CSRRS`/`CSRRC`
2. the trap mechanism: `mtvec`, `mepc`, `mcause`, `MRET`
3. exceptions you already have — illegal instruction, misaligned access — reported properly
4. the machine timer: `mtime`/`mtimecmp`, and a periodic interrupt
5. an interrupt handler in C, and what must be saved before it runs
6. the M extension: `MUL` using the ECP5's hardware multipliers, `DIV` as a multi-cycle FSM
7. optional: an instruction cache, and measuring whether it actually helps

## Deliverables

- `*.v` — the design, synthesisable and lint-clean
- `tb_*.v` — a self-checking testbench printing `PASS` or `FAIL`
- `README.md` — the written lesson, following the template
- `diagrams/*.wave.json` — timing diagrams where timing is the point
- editor path only: see [why the visual path stops](../docs/src/paths.md)

This is the last lesson.
