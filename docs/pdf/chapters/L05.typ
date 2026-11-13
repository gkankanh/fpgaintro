#import "../style.typ": *

= Lesson 05 — Finite state machines

== The idea

A state machine is a register holding #emph[where you are], and combinational
logic deciding #emph[where you go next]. That is all, and everything structural
follows from it:

+ a #strong[state register] — one clocked block, containing nothing else
+ #strong[next-state logic] — one combinational block, a pure function
+ #strong[output logic] — from state (Moore), or state and inputs (Mealy)

#fig("/figures/fsm-shape.svg",
     [The canonical three parts, and where Moore and Mealy differ: one dashed
      feedback path, and one coloured path that is the whole of the
      distinction.])

Splitting (1) from (2) is not stylistic. It makes the only sequential element
trivially obvious, so the next-state block reads as a plain truth table and you
never wonder what is registered.

#why[
  The SPI engine in lesson 06, the UART in lesson 09 and the CPU's control in
  lesson 13 are all this one pattern at increasing scale. The CPU is not a
  different kind of thing; it is a state machine whose state includes a program
  counter.
]

#strong[Draw the diagram first], on paper, before any Verilog: bubbles for
states, arrows labelled with the condition that takes them. Skipping that step
is how you end up with a state you cannot reach and a transition you cannot
explain.

== Moore and Mealy

Two machines detecting the same sequence, differing only in where the output
comes from:

#ttable(
  columns: (auto, auto, auto),
  [], [*Moore*], [*Mealy*],
  [output depends on], [state], [state #strong[and] input],
  [states needed],     [4],     [3],
  [timing],            [one clock #strong[late]], [#strong[immediate]],
  [output is],         [registered, glitch-free], [combinational],
)

Neither is correct in general. The question is whether the consumer needs the
answer #emph[now] or needs it #emph[clean]. A Mealy output feeding another
FSM's next-state logic in the same cycle is a combinational path between two
state machines — occasionally what you want, frequently a timing problem.

== Two textbook rules, measured

#measured("Mealy has fewer states and costs more")[
  #ttable(
    columns: (auto, auto),
    [`seq_moore`], [2 `LUT4`, 2 `TRELLIS_FF`],
    [`seq_mealy`], [#strong[5 `LUT4`], 2 `TRELLIS_FF`],
  )
  Mealy genuinely needs fewer states — 3 against 4 — and the saving buys
  nothing, because both counts fit in two flip-flops, while making the output
  depend on the input adds real gates. The textbook trade is an #emph[ASIC]
  trade, where you count flops.
]

#measured("one-hot encoding, which is supposed to suit FPGAs, loses badly")[
  #ttable(
    columns: (auto, auto),
    [*encoding*], [*cost*],
    [the synthesiser's own choice], [11 `LUT4`, 3 `PFUMX`, 5 `TRELLIS_FF`],
    [`"binary"`],  [12 `LUT4`, 3 `PFUMX`, 5 `TRELLIS_FF`],
    [`"one-hot"`], [#strong[41 `LUT4`], 18 `PFUMX`, 12 `L6MUX21`, 7 `TRELLIS_FF`],
  )
  Nearly four times worse. Four states is too few for one-hot's decode saving
  to appear, while every comparison against the state must now be built from
  four bits instead of two. One-hot earns its keep on #emph[wide] state
  machines, not narrow ones.
]

In Verilog the encoding is an attribute on the state register — not on the
module, where it does nothing. Without it the synthesiser re-encodes as it sees
fit, so the constants you wrote are a suggestion rather than an instruction.

`make synth` takes two seconds, and it outranks anything anyone tells you
about what #emph[usually] costs less.

== The mistake everyone makes

A lock opening on the sequence #strong[1, 2, 1, 3]. The states are easy. The
interesting question is #emph[what happens on a wrong symbol].

The obvious answer — go back to the start — is wrong. Enter `1, 2, 1, 2`: after
`1, 2, 1` the machine wants `3` and gets `2`. But the last two symbols it saw
were `1, 2`, which is a valid #emph[prefix] of the code. Restarting throws that
away, and the lock then refuses `1, 2, 1, 2, 1, 3` even though the correct code
is right there at the end.

Every state needs the same treatment: on a wrong symbol, fall back to the
longest suffix of what you have seen that is still a prefix of the code. Doing
it by hand is fiddly and easy to get subtly wrong — it is precisely what the
Knuth–Morris–Pratt string-matching algorithm automates, and precisely the class
of bug lesson 14's formal tools find without being asked.

== Testing changes shape

An FSM's input is a #emph[sequence], so there is no space to sweep. The test is
a set of chosen journeys through the state graph, and the discipline is
#strong[transition coverage]: has every arrow in your diagram been taken at
least once?

The traffic-light test walks the full cycle for that reason, and then runs many
clocks with no ticks to confirm the machine does not advance without its
enable.

== What it cost

#cost([`fsm_top` — the whole design],
      (LUT4: 75, TRELLIS_FF: 113, CCU2C: 49, PFUMX: 12, L6MUX21: 3),
      share: true)[]

#measured("113 flip-flops, and the proportion is the lesson")[
  #ttable(
    columns: (auto, auto),
    [one-second tick divider (25 bits)], [25],
    [traffic light: 2 state + 3 timer],  [5],
    [four debouncers],                   [76],
    [four edge detectors],               [4],
    [lock state],                        [3],
    [*total*],                           [*113*],
  )
  #strong[The state machines are 8 flip-flops out of 113.] The rest is
  debouncing and timekeeping — the plumbing needed to talk to the physical
  world. That ratio is normal, and worth seeing once: the interesting logic is
  usually a small fraction of a real design.
]
