#import "../style.typ": *

= Lesson 16 — Pipelining

#planned

#goals(
  concept: [Overlapping instructions, and the hazard logic that makes overlap safe.],
  build: [A five-stage version of the same core, running the same programs, at a higher clock.],
  needs: [Lesson 15.],
)[
  - Explain why pipelining raises the clock without making any stage faster.
  - Identify data, control and structural hazards.
  - Explain which hazard forwarding can fix and which it cannot.
  - Measure cycles-per-instruction and say where the cost went.
]

== The argument, already made

Lesson 10 measured a 32-bit ALU at 115.94 MHz. Lesson 13 measured the whole
single-cycle core at #strong[61.24 MHz] — the ALU plus fetch, register read,
memory and writeback, all in series, all paid for by every instruction
including `nop`.

Pipelining does not make any of those steps faster. It overlaps them: while one
instruction is in the ALU, the next is reading registers and the one after is
being fetched. The clock period then only has to cover the #emph[longest single
stage] rather than the whole chain.

#ttable(
  columns: (auto, 1fr),
  [IF], [instruction fetch],
  [ID], [instruction decode and register read],
  [EX], [execute — the ALU],
  [MEM], [data memory access],
  [WB], [write back to the register file],
)

Between each pair sits a pipeline register. #strong[This is where lesson 13's
thirty-two flip-flops become hundreds], and that growth is precisely what
pipelining is.

== The cost: hazards

Overlap is only safe if the overlapping instructions do not interfere, and
mostly they do.

#strong[Data hazards.] An instruction needs a result that an earlier one has
computed but not yet written back. The fix is #emph[forwarding]: route the
result from where it already exists — the EX or MEM stage output — directly to
where it is needed, rather than waiting for the register file.

#strong[The one forwarding cannot fix.] A load's result is not available until
the end of MEM, so an instruction immediately after a load that uses its result
must #emph[stall] — one bubble, every time. Compilers know this and schedule
around it, which is one of the places where an ISA's design and a compiler's
behaviour meet.

#strong[Control hazards.] By the time a branch is resolved, the two
instructions behind it have already been fetched. Either flush them — paying
two cycles on every taken branch — or predict, and pay only when the prediction
is wrong.

== What to measure

Three numbers make the trade concrete:

+ the new maximum clock, against lesson 13's 61.24 MHz
+ the cycles-per-instruction on a real program, which is now above 1 because of
  stalls and flushes
+ the resource cost of the hazard logic and pipeline registers

#why[
  Pipelining is the idea that turned processors from simple to subtle. Doing it
  to a core you already have, with a proof you already wrote in lesson 14, is
  the honest way to see what the complexity buys and what it costs — because
  the specification has not changed, so the lesson 14 proof should still pass.
]
