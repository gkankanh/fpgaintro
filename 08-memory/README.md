# Lesson 08 — memories

**Concept:** inferring block RAM instead of logic, and what the synthesiser needs to see to do it.

**You will build:** a dual-port framebuffer the display reads while something else writes — the memory the CPU will later use.

**Needs the board:** yes

**Prerequisites:** lesson 07

**Paths:** editor

> **Status: planned.** Scope and ordering are settled; the code and the written
> lesson are not here yet. Lessons are built in order, so this one is written
> once lesson 07 is complete. See
> [`docs/LESSON_TEMPLATE.md`](../docs/LESSON_TEMPLATE.md) for the shape every
> lesson takes.

---

## Why this lesson exists

Lesson 07 computes each pixel on demand because it has nowhere to put one. A
CPU needs memory it can address randomly. This is also the lesson where `make
synth` becomes essential rather than interesting: the difference between
inferring BRAM and inferring flip-flops is a design that fits and one that
does not.

## Planned outline

1. the ECP5's DP16KD: 18 Kbit, true dual-port, and why it is not just a big register file
2. the coding pattern yosys recognises as BRAM, and the small deviations that silently give you 16,000 flip-flops
3. synchronous read: BRAM output is always registered, and the one-cycle latency that follows from that
4. lesson 07's font ROM became 185 LUTs; a 1,024-byte font will not — finding where the trade-off flips
5. `$readmemh` and initialised ROM: fonts, microcode, and later, CPU test programs
6. single-port, simple dual-port, true dual-port: what the hardware can actually give you
7. a framebuffer: written by coordinate, read by raster scan, two ports, two different access patterns

## Deliverables

- `*.v` — the design, synthesisable and lint-clean
- `tb_*.v` — a self-checking testbench printing `PASS` or `FAIL`
- `README.md` — the written lesson, following the template
- `diagrams/*.wave.json` — timing diagrams where timing is the point
- editor path only: see [why the visual path stops](../docs/src/paths.md)

**Next:** [lesson 09 — uart](../09-uart/)
