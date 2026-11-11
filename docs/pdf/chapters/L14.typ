#import "../style.typ": *

= Lesson 14 — Formal verification

#planned

#goals(
  concept: [Proving a property holds for all inputs up to a bound, instead of testing the cases you thought of.],
  build: [A `riscv-formal` proof that the lesson 13 core really implements RV32I.],
  needs: [Lesson 13.],
)[
  - Explain what a bounded model checker does, and what "bounded" excludes.
  - Write assertions, assumptions and covers — and recognise when an assumption has made a proof vacuous.
  - Read a counterexample trace as a minimal failing program.
  - Judge when testing is enough and when it is not.
]

== Why this lesson exists here

Lesson 13 ended with twenty-four passing checks and a CPU that ran. It also
ended by finding a bug that #strong[161 passing decoder checks and a
mutation-tested testbench had missed] — because the bug was in an assumption no
test had asked about.

#why[
  That is the argument for formal methods in one sentence. A testbench tells
  you a design works for the inputs you imagined. For a processor that is
  nowhere near good enough: the bugs live in combinations nobody imagines, and
  the space is far too large to sample.
]

== The idea

A bounded model checker takes a property — "this signal is never high while
that one is low" — and either proves it holds for every reachable state within
#emph[k] cycles of reset, or hands you a concrete trace where it fails.

The word #strong[bounded] is doing real work. A proof to depth 20 says nothing
about a bug that needs 21 cycles to manifest. Depth is traded against solver
time, and choosing it is part of the craft.

Three kinds of statement:

#ttable(
  columns: (auto, 1fr),
  [`assert`], [something that must always be true. The thing being proved.],
  [`assume`], [a constraint on the inputs. #strong[The dangerous one]: assume
               too much and you prove something about a machine nobody will
               build.],
  [`cover`],  [a request for a trace reaching some state. The antidote to the
               above — if a `cover` is unreachable, your assumptions have
               excluded reality.],
)

== `riscv-formal`

An instruction-level specification of RV32I that an implementation can be
checked against, by Claire Wolf. The core exposes a trace interface reporting
what it retired each cycle — which instruction, which registers it read and
wrote, what values — and the framework checks each retirement against the
specification.

What it proves, instruction by instruction: that the result matches the ISA,
that the program counter advanced correctly, that no register was disturbed
that should not have been, and that memory access was properly aligned.

#why[
  This is also where you find out which of the earlier lessons were quietly
  wrong. A formal proof over a CPU exercises the ALU, the register file and the
  decoder far harder than their own testbenches did — and it does so without
  anyone having thought of the case.
]

== What to expect

Formal verification is not a replacement for testing. It is slow, it is
bounded, and writing a property that is both true and useful is a skill. What
it does that testing cannot is #strong[search] rather than sample: it will find
the three-instruction sequence that breaks your forwarding logic, and it will
find it without being told that forwarding exists.
