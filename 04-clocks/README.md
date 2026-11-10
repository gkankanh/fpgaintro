# Lesson 04 — clocks and timing

**Concept:** what a clock actually is in an FPGA, and what the tools are checking when they check timing.

**You will build:** a PLL generating several frequencies, a design that deliberately fails timing, and a safe crossing between two clock domains.

**Needs the board:** yes

**Prerequisites:** lesson 03

**Paths:** editor

> **Status: planned.** Scope and ordering are settled; the code and the written
> lesson are not here yet. Lessons are built in order, so this one is written
> once lesson 03 is complete. See
> [`docs/LESSON_TEMPLATE.md`](../docs/LESSON_TEMPLATE.md) for the shape every
> lesson takes.

---

## Why this lesson exists

Lesson 00 used the clock without asking what it was; lesson 03 used it to
build registers. This lesson is where the clock stops being a given and
becomes a thing with properties you must respect. It is also the lesson that
explains the single most common FPGA failure mode: a design that simulates
perfectly, passes every testbench, and misbehaves intermittently on hardware.
Simulation has no notion of setup time.

## Planned outline

1. setup and hold: why a flip-flop needs its input stable before *and* after the edge, and what the ECP5's numbers are
2. the critical path: `nextpnr --freq 25` reports it, and `make bit` fails when it cannot be met
3. why combinational depth and clock speed trade against each other — the pipelining argument, 12 lessons early
4. clock enables vs clock gating: why you divide to make an *enable*, never a clock
5. the global clock network: why a derived clock on ordinary routing has skew and a real clock does not
6. the ECP5's `EHXPLLL`: generating 100 MHz and 40 MHz from the 25 MHz crystal, and reading the primitive's parameters
7. two clock domains, and metastability: what happens when a flip-flop samples a changing input
8. the two-flop synchroniser, and why it works for a bit and not for a bus
9. handing a multi-bit value across domains: a handshake, or a FIFO, and why a plain register is a bug

## Deliverables

- `*.v` — the design, synthesisable and lint-clean
- `tb_*.v` — a self-checking testbench printing `PASS` or `FAIL`
- `README.md` — the written lesson, following the template
- `diagrams/*.wave.json` — timing diagrams where timing is the point
- editor path only: see [why the visual path stops](../docs/src/paths.md)

**Next:** [lesson 05 — fsm](../05-fsm/)
