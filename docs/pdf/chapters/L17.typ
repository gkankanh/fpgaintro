#import "../style.typ": *

= Lesson 17 — Extensions

#planned

#goals(
  concept: [Privileged state, traps, and the extensions that make a core usable rather than merely correct.],
  build: [Control and status registers, a machine-timer interrupt, and hardware multiply.],
  needs: [Lesson 16.],
)[
  - Explain what a trap is and what hardware must save before taking one.
  - Distinguish an exception from an interrupt.
  - Write an interrupt handler in C and know what the hardware did first.
  - Decide when to spend a hardware multiplier and when to iterate.
]

== Optional, and genuinely so

The course's goal is met at lesson 16. This chapter exists because "a correct
RV32I core" and "a core that can run an operating system" are separated by
exactly these pieces, and it is worth seeing how few they are.

== Traps

A trap is a forced, controlled change of control flow. The hardware must save
enough to resume: where it was (`mepc`), why it stopped (`mcause`), and where
to go (`mtvec`). `MRET` reverses it.

#ttable(
  columns: (auto, 1fr),
  [*exception*], [caused by the instruction being executed — an illegal
                  instruction, a misaligned access. Synchronous, and the
                  instruction did not complete.],
  [*interrupt*], [caused by something outside — a timer, a peripheral.
                  Asynchronous, and taken between instructions.],
)

#why[
  Lesson 12's decoder has produced an `illegal` output since the beginning, and
  lesson 13's core halts on it rather than executing nonsense. That signal cost
  one wire and has been waiting for this lesson, which is the point: designing
  the error path in from the start is far cheaper than retrofitting it.
]

== The machine timer

`mtime` counts, `mtimecmp` holds a threshold, and an interrupt fires when one
reaches the other. That is the whole mechanism, and it is enough to build a
pre-emptive scheduler on — which is how a timer interrupt becomes an operating
system.

== The M extension

`MUL` maps onto the hardware multipliers lesson 08 met by accident — the part
has 156 of them. `DIV` has no hardware at all and becomes a multi-cycle state
machine, which is why division is slow on nearly every processor ever built.

#why[
  By now the question "should this be hardware or software?" has a method
  rather than an opinion attached. Measure what the hardware costs, measure
  what the software costs in cycles, and decide — which is what this whole
  course has been teaching.
]
