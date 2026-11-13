#import "../style.typ": *

= Lesson 16 — Pipelining

#goals(
  concept: [Overlapping instructions, and the hazard logic that makes overlap safe.],
  build: [A 5-stage version of the same core, running the same programs, at nearly twice the clock.],
  needs: [Lesson 15, and lesson 04's PLL. A board.],
)[
  - Explain why pipelining raises the clock without making any stage faster.
  - Identify data, control and structural hazards.
  - Explain which hazard forwarding can fix and which it cannot.
  - Measure cycles-per-instruction and say where every extra cycle went.
  - Say when pipelining makes a program #emph[slower], and prove it.
]

== The same work, cut into five pieces

```
IF  ──>  ID  ──>  EX  ──>  MEM  ──>  WB
fetch   decode    ALU     memory   register
        + read    +       access    write
        regs    branch
```

Registers between the pieces, so five instructions can be in the machine at
once and the clock period only has to cover the longest #strong[piece] instead
of the whole chain. Lesson 13's core did all of it between one clock edge and
the next and measured 61.24 MHz; as a computer with real memory it measured 28.

Nothing in this lesson makes any single step faster. The clock goes up because
no step has to finish inside the same period as all the others.

#why[
  A pipeline is not a different processor. It is the same parts in a different
  arrangement: the ALU is still lesson 10's, the register file lesson 11's, the
  decoder and immediate generator lesson 12's, the branch comparator and
  aligners lesson 13's. Not one of those files is touched — which is why lesson
  14's proof of the ALU still holds, unchanged and un-rerun.
]

It costs three things, and they are the whole of the core.

#strong[Registers.] Lesson 13's entire core had 32 flip-flops: the program
counter. This one has 414. That difference #emph[is] pipelining.

#strong[Hazards.] Instruction #emph[N+1] may need a result instruction #emph[N]
has not written yet. Forwarding, stalling and flushing, in that order of
preference.

#strong[CPI above 1.] The single-cycle core retired exactly one instruction per
cycle by construction. This one manages it only when nothing goes wrong.

== The memory's output register is the IF/ID register

A block RAM's output is registered inside the block — lesson 08's rule, and the
reason lesson 15's asynchronous memory cost 2,756 LUT4 and not one `DP16KD`. A
pipelined core asks in one stage and uses the answer in the next, which is
exactly the shape a block RAM offers.

So the pipeline does not merely tolerate the memory's latency. #strong[It is the
reason the latency is free.] The register holding the fetched instruction for
the whole of ID is the block RAM's own output register, which costs nothing
because the block RAM has it either way — and its clock enable is how the core
stalls.

== Hazards

=== Forwarding

Two places already hold a value the ALU is about to need: the `EX/MEM` register,
holding the instruction one ahead, whose ALU result is computed; and `MEM/WB`,
holding the instruction two ahead — including a #emph[loaded] word, which
exists nowhere else yet. `EX/MEM` wins when both match, because the nearer
instruction is the more recent one.

#watch[
  The MEM-stage value of a #strong[load] is not its result, it is its
  #emph[address]. Forwarding that gives the program a pointer where it wanted a
  value, and it computes confident nonsense. The stall below is what prevents
  it, and the core carries a simulation-only assertion that fires if it ever
  does not.
]

=== The bypass lesson 11 predicted

Lesson 11's register file has no write-to-read bypass, and its comment said
exactly why that was right then and wrong now: bypass becomes necessary when a
read and a write belong to #emph[different] instructions in flight at once.

Here is that case. An instruction in WB writes its result at the end of a cycle;
an instruction in ID reads the register file during that cycle and gets the old
value. They are four instructions apart — too far for EX forwarding, too close
for the write to have landed. One multiplexer on each read port fixes it.

=== The one forwarding cannot fix

A load's result does not #strong[exist] until WB: the memory is synchronous, so
the word asked for in MEM arrives in the cycle after. An instruction needing it
one instruction later would have to read it a cycle before it exists, and no
amount of wiring moves a value backwards in time.

So: stall one cycle. That is the load-use hazard, it costs exactly one bubble,
and it is why compilers bother to schedule an unrelated instruction into the
slot after a load. A bubble, incidentally, is not a special instruction — it is
`valid` going low with every state-changing control signal forced off.

=== Control

Branches resolve in EX, using the #emph[forwarded] operands, which is why
resolving them in ID would need a second forwarding network. Resolving in EX
costs #strong[two] wrong instructions on every taken branch. Resolving in ID
would cost one. Predicting would cost none, when right.

== The bug this lesson actually hit

The C program from lesson 15 halted on an illegal instruction a few instructions
after printing its echo. The instruction was `0x20737362`, which is ASCII
`"bss "`.

The machine had decoded a string constant.

The last instruction of `main()` is a `jal`, and the word after it is the first
four bytes of `.rodata`. The pipeline fetches it — of course it does; it does
not know the jump is taken until EX — and throws it away correctly, because the
flush keeps it from ever reaching EX. But an exception is not something an
instruction #emph[does]. It is something it #strong[is], and the
illegal-instruction latch was looking at it anyway.

#found[
  The fix is `&& !redirect`, and the rule behind it is one every real processor
  obeys: #strong[an instruction that is squashed raises nothing]. Real pipelines
  carry an exception down the stages with its instruction and raise it at
  commit, for exactly this reason — by then they know whether it was ever going
  to run.

  Lesson 13's core could not have had this bug: it never fetches speculatively,
  so every instruction it decodes is one it executes. This is not a bug in trap
  logic. It is a #emph[control hazard] wearing a disguise — and it is why the
  conformance program passed while the C did not. Hand-written assembly has a
  real instruction after every jump; a compiler puts its string table there.
]

== What it cost

#cost([`cpu5` — the pipelined core],
      (LUT4: 2110, TRELLIS_FF: 414, CCU2C: 95, PFUMX: 597, L6MUX21: 279,
       TRELLIS_DPR16X4: 32),
      cmd: "make synth M=cpu5")[
  Against lesson 13's core at 1,765 LUT4 and #strong[32] flip-flops. The
  pipeline cost 345 LUT4 and 382 flip-flops — a 13-fold increase in state for a
  20% increase in logic, which is the shape of the bargain.
]

#cost([`memory_sync` — the same 2 KB as lesson 15],
      (LUT4: 121, TRELLIS_FF: 117, DP16KD: 2),
      cmd: "make synth M=memory_sync")[
  Lesson 15's version of this memory cost #strong[2,756 LUT4] and 512
  distributed RAM cells. The difference between the two files is that one reads
  combinationally and this one does not.
]

#measured("the whole computer, against lesson 15's")[
  #ttable(
    columns: (auto, auto, auto),
    [], [*lesson 15*], [*lesson 16*],
    [`LUT4`],            [4,821], [*2,588*],
    [`TRELLIS_FF`],      [146],   [*678*],
    [`DP16KD`],          [0],     [*2*],
    [`TRELLIS_DPR16X4`], [544],   [32],
  )
]

#strong[The pipelined computer is smaller.] A more complex core, four sets of
pipeline registers, a forwarding network and hazard logic — and 2,233
#emph[fewer] LUT4, because the memory moved into two block RAMs out of 208. The
pipeline cost 345 LUT4; the memory it made possible paid that back seven times
over.

And the memory now scales, which it could not before: at 16 KB the design uses
2,285 LUT4 and 16 block RAMs, and still closes at 46 MHz. Eight times the
memory, fewer LUT4, same clock. In lesson 15, doubling 2 KB to 4 KB cost 2,442
LUT4 and broke timing.

== What it cost in time, and what it bought

Both machines placed and routed three times with different placer seeds, at the
same 25 MHz constraint, so the numbers compare.

#measured("the clock nearly doubles")[
  #ttable(
    columns: (auto, auto),
    [lesson 15 — single-cycle computer], [27.28 / 28.21 / 28.00 MHz],
    [*lesson 16 — pipelined computer*], [*49.48 / 47.52 / 45.74 MHz*],
  )
]

Now the other half of the arithmetic. The conformance program runs 109
instructions in #strong[148] cycles here, against 109 on the single-cycle core:
CPI 1.358 against 1.000.

The C delay loop is the clearer case, because it is small enough to count by
hand — six instructions, a hundred iterations, and the program's own stopwatch
reports 606 cycles on the single-cycle machine and 1,207 here.

#measured("every cycle of one loop iteration")[
  #ttable(
    columns: (1fr, auto),
    [six instructions], [6],
    [`lw` → `addi` load-use stall], [1],
    [`lw` → `bge` load-use stall], [1],
    [taken `bge`, two instructions flushed], [2],
    [taken `jal`, two instructions flushed], [2],
    [*per iteration*], [*12*],
  )
  12 × 100 = 1,200, plus 7 cycles of loop entry and pipeline fill: 1,207.
]

=== So is it faster? Not always

Time is cycles divided by clock, and both changed. Taking the slowest seed for
each machine:

#measured("two programs, opposite answers")[
  #ttable(
    columns: (1fr, auto, auto, auto),
    [*program*], [*lesson 15*], [*lesson 16*], [],
    [conformance, 109 instructions], [3.89 µs], [3.24 µs], [*1.20× faster*],
    [the `volatile` delay loop], [21.6 µs], [26.4 µs], [*0.82× — slower*],
  )
]

#strong[Pipelining made one program 20% faster and the other 18% slower.] The
clock went up 1.63×; the delay loop's CPI went up 1.99×, and 1.99 is more than
1.63.

That loop is the worst case on purpose — every iteration is a load immediately
followed by its use, twice, and two taken branches — and it is also exactly the
shape of code a naive benchmark contains. The honest summary is that pipelining
buys #emph[permission to raise the clock], and whether that is a win depends on
the program. Which is not what the textbook diagram suggests.

== On the board, where the clock is yours to set

#why[
  A pipeline running at the same clock is a #strong[slower machine]: the same
  instructions in more cycles, each cycle the same length. Everything pipelining
  gives you arrives as permission to raise the clock, and if you do not raise
  it, you have paid for the hazard logic and bought nothing.
]

Lesson 15's machine runs at the board's 25 MHz oscillator because it cannot go
faster. This one closes at 46, so the board top instantiates lesson 04's PLL —
the same file, unchanged — and runs the computer at #strong[40 MHz]. Forty and
not forty-six: the slowest placer seed measured 45.74, and taking 46 because one
run said 46 is how you ship a machine that works on the bench and fails in July.
The shipped build closes at 48.55 MHz against its 40 MHz constraint.

The UART divisor comes from a parameter, so it follows the PLL with nothing else
changed, which is why lesson 09 made it a parameter.

Load lesson 15's bitstream, reset, read the cycle count the program prints. Load
this one, reset, read it again: #strong[it is larger], on a machine that is
faster. That is the whole lesson in two numbers on a screen.
