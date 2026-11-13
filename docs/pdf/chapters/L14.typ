#import "../style.typ": *

= Lesson 14 — Formal verification

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

#fig("/figures/formal-search.svg",
     [The same input space three times: sampled, searched, and shrunk to a line
      by an assumption that was slightly too strong.])

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

== What it actually did

#measured("the ALU, proved rather than sampled")[
  Lesson 10 computed that checking all 2#super[32] × 2#super[32] × 10 ALU
  inputs would take #strong[1,460 years] at a billion a second, and settled for
  1,440 directed vectors plus 20,000 random ones.

  The proof covers every one of them in #strong[one second]. The ALU is
  combinational, so depth 1 examines the entire input space — for
  combinational logic, "bounded" costs nothing at all.

  The register file, which has state, is proved for #strong[every sequence of
  twelve operations] over every address and every data value, in 58 seconds.
]

The register file proof uses the technique worth taking away:

```verilog
(* anyconst *) reg [4:0] watched;   // the SOLVER picks the address
always @(posedge clk)
    if (we && rd == watched && watched != 0) shadow <= wdata;
always @(*)
    if (shadow_valid && rs1 == watched) assert (rd1 == shadow);
```

`anyconst` makes this a proof rather than a spot check: the solver chooses
`watched` and must satisfy the property for #emph[every] choice, so one shadow
register establishes a fact about all thirty-two.

== Catching a real bug

The lesson ships a deliberately broken ALU — lesson 10's, with signed
less-than using the shortcut that omits the overflow term. That failing region
is a vanishing fraction of 2#super[64] pairs, and 20,000 random vectors would
very likely miss it.

#measured("the solver found it in under a second")[
  ```
  a = 0x80008000   signed  -2147450880
  b = 0x57FE8001   signed   1476296705
  signed:  -2147450880 < 1476296705  ->  1
  broken ALU answered:  0
  ```
  Signs differ, the difference overflows, and the shortcut is wrong —
  precisely the case lesson 10 described. Nobody told the solver to look there.
]

#watch[
  The first thing a formal tool finds is usually a bug in your #emph[property].
  The first run of this proof failed with the design perfectly correct: the
  property used `y[sh-1:0]`, which is not a legal variable part-select, against
  a nonsensical right-hand side. Expect this.
]

== The failure mode that makes formal dangerous

#found[
  A proof can pass and be worth nothing. The lesson's `vacuous.v` uses the
  #strong[real] ALU, makes #strong[true] assertions, and #strong[passes] —
  because of one line:

  ```verilog
  assume (a == b);
  ```

  With the operands forced equal, `a < b` is false for every input the solver
  may consider. The assertion becomes `0 == 0`, the overflow logic is never
  exercised, and an ALU returning constant zero for SLT would pass identically.

  Nobody writes that deliberately. They write an assumption to exclude an input
  the design is not meant to handle, it is slightly too strong, and the hole is
  invisible — because a passing proof looks the same either way.
]

The antidote is `cover`, and it is not optional. Running the vacuous example's
cover task reports both covers #strong[unreached], which is the only signal
that the proof above was hollow.

#why[
  #strong[A formal proof is only as good as its assumptions, and nothing in a
  passing result tells you whether they were right.] The real ALU proof carries
  seven covers for this reason — that signed and unsigned comparison genuinely
  disagree, that `SRA` differs from `SRL`, that addition wraps — and all seven
  are reached.
]

== What it cost

Nothing, and the absence is deliberate: this lesson has no design of its own.
It proves lesson 10's ALU and lesson 11's register file, both of which report
their own area. What this lesson spends is #strong[solver time], and
`run-proofs.sh` prints it.

== What this lesson does not do

`riscv-formal` itself — checking a whole core against an instruction-level
specification of RV32I — needs the core to expose a retirement trace interface
and the riscv-formal repository alongside. That is a lesson's work on its own
and is not here yet. What #emph[is] here is the technique it rests on, applied
to the two components the CPU is mostly built from.

Formal verification is not a replacement for testing. It is bounded, and
writing a property that is both true and useful is a skill. What it does that
testing cannot is #strong[search] rather than sample.
