# Lesson 09 — UART

**Concept:** agreeing on timing with a device you share no clock with.

**You will build:** a transmitter, a receiver, and a loopback that echoes what you type in a terminal.

**Needs the board:** yes

**Prerequisites:** lesson 05

**Paths:** editor + visual

> **Status: planned.** Scope and ordering are settled; the code and the written
> lesson are not here yet. Lessons are built in order, so this one is written
> once lesson 05 is complete. See
> [`docs/LESSON_TEMPLATE.md`](../docs/LESSON_TEMPLATE.md) for the shape every
> lesson takes.

---

## Why this lesson exists

This is how your CPU will say hello in lesson 15. It is also the first design
that has to be right about *time* rather than just logic, and the first where
a passing simulation can still fail on hardware — which is why it follows
lesson 04.

## Planned outline

1. the 8N1 frame: start bit, eight data bits LSB-first, stop bit — with a timing diagram of all of it
2. baud rate as a counter modulus: 25,000,000 / 115,200 = 217.0, and what the 0.014 error costs over ten bits
3. transmit: an FSM that shifts out, with a `busy` flag the rest of the design respects
4. receive: why you oversample 16x and sample mid-bit rather than at the edge
5. framing errors: what to do when the stop bit is not where it should be
6. `ftdi_rxd` vs `ftdi_txd` — named from the FTDI's point of view, and the classic wiring mistake
7. talking to it: `screen /dev/tty.usbserial-* 115200`

## Deliverables

- `*.v` — the design, synthesisable and lint-clean
- `tb_*.v` — a self-checking testbench printing `PASS` or `FAIL`
- `README.md` — the written lesson, following the template
- `diagrams/*.wave.json` — timing diagrams where timing is the point
- `icestudio/*.json` + generated `.ice` — the visual path

**Next:** [lesson 10 — alu](../10-alu/)
