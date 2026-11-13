#import "../style.typ": *

= Lesson 17 — CSRs, traps and the M extension

#goals(
  concept: [Privileged state, traps, and the extensions that make a core usable rather than merely correct.],
  build: [CSRs, a machine-timer interrupt, and hardware multiply and divide — with the handler written in C.],
  needs: [Lesson 16, a board, and the GNU RISC-V toolchain.],
)[
  - Explain what a trap is and what hardware must save before taking one.
  - Distinguish an exception from an interrupt.
  - Write an interrupt handler in C and know what the hardware did first.
  - Decide when to spend a hardware multiplier and when to iterate.
  - Explain why a CSR write has to serialise a pipeline.
]

== What a core that halts cannot do

Lesson 13's core, and lesson 16's, do the same thing with an instruction they
do not understand: #strong[they stop]. The program counter freezes, a light
comes on, and that is the end of the machine.

Real processors trap: save where they were, record why, and jump to an address
the software chose. The difference between a core that halts and a core that
could run an operating system is almost entirely this lesson, and it is smaller
than you would think.

#why[
  A trap is the only mechanism by which software gets control of a machine it
  is not currently running on. System calls, page faults, debuggers,
  timer-driven scheduling, and every "something went wrong" message you have
  ever seen are the same four registers and one jump.
]

This lesson is genuinely optional — the course's goal is met at lesson 16. It
is here because #emph[a correct RV32I core] and #emph[a core that could run an
RTOS] are separated by exactly these pieces.

== Four additions to lesson 16's core

=== A second decoder

Lesson 12's decoder recognises nine opcodes and calls everything else illegal,
which includes every instruction this lesson needs. A second decoder claims
them, and the core computes `illegal = base_illegal AND NOT ext_legal`. That is
the smallest honest change: lesson 12's decoder is a finished, measured
artifact, and a lesson that quietly rewrites an earlier one invalidates its
numbers.

#why[
  `MUL` is opcode `0110011` — the same as `ADD` — distinguished only by
  `funct7 = 0000001`. RISC-V does that deliberately: opcodes are scarce, and an
  extension needing its own opcode is one that cannot coexist with another.
  Lesson 12's `funct7` check is exactly what makes `MUL` illegal on a core
  without M, which is what the specification requires, and why that check was
  worth writing. #strong[An extension is a decoder.]
]

=== Traps, and why they are precise

Nine registers hold the privileged state. Taking a trap is a redirect with
bookkeeping: save the PC in `mepc`, say why in `mcause`, copy `MIE` into
`MPIE` and clear `MIE` so the handler is not immediately interrupted, and jump
to `mtvec`. #strong[Four registers and a jump] — that is all the hardware does.

Traps are decided in ID, before the instruction has done anything. So
everything ahead of it in the pipeline completes, because those instructions
are earlier in program order; the trapping instruction is squashed, having
changed nothing; and everything behind it is flushed by the redirect. The
machine stops between two instructions, exactly, with `mepc` naming the
boundary.

That property is #strong[precision], and it is not optional: a handler that
cannot tell what has happened cannot return from it. It is also the hardest
thing about traps in a deep pipeline, and the reason real cores carry an
exception down the stages with its instruction and raise it at commit.

#watch[
  Taking a trap requires `!redirect` — lesson 16's rule about squashed
  instructions. There it stopped the machine halting on a string constant; here
  it is what keeps traps precise, because an instruction on the wrong path of a
  branch must not trap. It is not going to run.
]

=== Interrupts

Everything above is caused by an instruction. The machine timer is not: its
pending bit goes high because #emph[time passed], and that is the entire
difference between an exception and an interrupt. It arrives as one input wire.

#watch[
  The timer's interrupt is a #strong[level], not an event: it stays asserted
  while `mtime >= mtimecmp`. A handler that returns without moving `mtimecmp`
  forward is re-entered the instant `MRET` re-enables interrupts, forever. This
  is the classic first bug with a timer.
]

Adding the timer to the system cost one line — a select line and an entry in
the read multiplexer. The address decoder, the compiler and the linker script
are all unchanged. That is what a memory map buys.

=== An EX stage that can take longer than a cycle

Multiply and divide do not finish in a cycle, so for the first time in this
course EX can say "not yet" — which needs a stall that holds the instruction
#emph[in] EX rather than ahead of it.

#ttable(
  columns: (auto, auto, 1fr),
  [*stall*], [*who waits*], [*what EX gets*],
  [load-use (lesson 16)], [the instruction in ID], [a bubble],
  [multiply or divide], [the instruction in EX], [nothing — it holds],
)

Both are one signal to the rest of the pipeline, which is why adding the
divider beside the multiplier changed nothing anywhere else.

== The bug this lesson actually hit

The program printed its greeting twice.

```asm
csrw  mtvec, a5     # in EX, writing mtvec at the end of this cycle
ecall               # in ID, reading mtvec to find out where to go
```

Both in the machine at once, one stage apart. The `ECALL` read the #emph[old]
`mtvec` — zero, because nothing had set it yet — and jumped to address zero,
which is the first instruction of the program. The machine restarted itself,
printed its greeting again, set `mtvec` again, and the second `ECALL` worked.
On the board that would look like a glitch.

#found[
  Lesson 16's forwarding network cannot help, and the reason is worth more than
  the fix. Forwarding moves #strong[values] between instructions. This is not a
  value: it is a change to how the machine #emph[behaves] — where traps go,
  whether interrupts are allowed, what the timer is compared against. There is
  no wire to forward "the rules are different now" along.

  So the pipeline serialises: while a CSR instruction is in EX, nothing is
  decoded behind it. One bubble per CSR instruction — the right price for an
  instruction a program executes a few dozen times, and the reason real
  instruction sets describe CSR writes as #emph[serialising] rather than as
  ordinary register writes.
]

== A handler in C

```c
__attribute__((interrupt("machine")))
void trap_entry(void)
```

That attribute asks gcc for a function that can be jumped to by #strong[
hardware] rather than called by software. It saves and restores every register
it touches — a normal function may clobber the temporaries freely, this one may
not clobber anything — and it returns with `MRET` instead of `RET`, which
restores the interrupt enable and jumps to `mepc`. Disassemble it and count the
stores in its prologue: that stack traffic is the cost of an interrupt, before
any of your code runs.

`mepc` points #emph[at] the faulting instruction, not after it — right for a
page fault, where you fix the problem and re-run it, wrong for `ECALL`, where
re-running would trap again immediately. The handler decides, which is the
point.

#why[
  There is no C syntax for a control and status register, and no reason there
  should be: they are not memory, they have no addresses C can form, and the
  instructions take the CSR number as an #emph[immediate], so it must be a
  compile-time constant. Hence macros that paste the name into inline assembly.
  This is the floor of the C abstraction, and every operating system has a
  header that looks like it.
]

=== One flag, two extensions

`-march=rv32im_zicsr`. The `m` makes `a * b` one instruction instead of a call
into libgcc. The `zicsr` makes `csrr` assemble #emph[at all] — the CSR
instructions were part of the base integer ISA until 2019, when they were split
into their own extension, because a core needing no privileged state should not
have to implement six instructions to be called RV32I. The hardware does not
care: the decoder would have claimed them under any name.

== What it cost

#cost([`soc17_top` — the whole machine],
      (LUT4: 3866, TRELLIS_FF: 1285, CCU2C: 366, PFUMX: 896, L6MUX21: 340,
       TRELLIS_DPR16X4: 32, DP16KD: 16, MULT18X18D: 4, EHXPLLL: 1),
      share: true)[
  Four hard multipliers and sixteen block RAMs, for a computer with 16 KB of
  memory that takes interrupts.
]

#measured("where the additions went, each synthesised on its own")[
  #ttable(
    columns: (auto, auto, auto, auto, 1fr),
    [*module*], [*`LUT4`*], [*`TRELLIS_FF`*], [*`MULT18X18D`*], [],
    [`cpu5t`],      [3,270], [887], [4], [this lesson's core],
    [`cpu5`],       [2,110], [414], [0], [lesson 16's, for comparison],
    [`csr`],        [1,402], [225], [0], [nine registers and the trap state],
    [`div_unit`],   [528],   [169], [0], [32 cycles of restoring division],
    [`mul_unit`],   [36],    [68],  [*4*], [the DSPs do the work],
    [`timer`],      [164],   [128], [0], [two 64-bit registers, one comparator],
    [`decode_ext`], [56],    [0],   [0], [every instruction this lesson added],
  )
]

#strong[The whole privileged architecture is a decoder of 56 LUT4] and a
register file of about 1,400. Traps are cheap; what they enable is not, but the
mechanism itself is smaller than the ALU.

#strong[Multiply costs 36 LUT4 and four DSP blocks; divide costs 528 LUT4 and
no DSP at all.] That asymmetry is the whole of the M extension in two rows:
multiplication is a block the chip already has, and division is a state machine
you have to build. It is why `a / b` is expensive in C and `a * b` is not, and
why compilers turn division by a constant into a multiply by a magic number.

`cpu5t` is 1,160 LUT4 and 473 flip-flops more than `cpu5`. The modules above
sum to more than that, because a module synthesised alone must build every
output it exposes — the same effect lesson 13 measured when `cpu` came out
larger than the `cpu_top` containing it.

== What it cost in time

This core #strong[does not close timing at lesson 16's 40 MHz], and finding out
why took three builds and nine place-and-route runs.

#measured("three versions of one multiplier")[
  #ttable(
    columns: (1fr, auto, auto, auto),
    [*build*], [*constraint*], [*three placer seeds*], [*verdict*],
    [combinational multiplier], [40 MHz], [34.5 / 34.9 / 35.5], [fails all three],
    [product registered], [40 MHz], [41.1 / 40.1 / *39.6*], [fails one in three],
    […and operands registered too], [40 MHz], [38.5 / 39.8 / 41.5], [fails two in three],
    [*shipped: product registered*], [*35.71 MHz*], [*39.7 / 39.8 / 39.5*], [*passes*],
  )
]

Built combinationally, the 32×32 multiplier #emph[was] the critical path of the
machine, and nextpnr named it exactly: 29 ns from the block RAM's output,
through the forwarding network, the four DSPs and the carry chain that sums
their partial products, into the `EX/MEM` register. Lesson 16's core without it
closed at 46 MHz.

Registering the product fixed most of that, and the multiply became a two-cycle
instruction — which is what real cores do, and why every instruction-timing
table lists multiply latency separately from throughput.

#why[
  The third row is the one worth having. Registering the #emph[operands] as
  well is the textbook next step: split the long path in two, get a faster
  clock. It bought #strong[nothing] — the same clock within the placer's own
  spread — and cost an extra cycle on every multiply. The multiplier had
  stopped being the critical path after the first register, and a second one
  optimises something that is no longer the problem.

  The only reason anyone knows that is that it was measured three times rather
  than once. A single run of this design lands anywhere between 38.5 and 41.5
  MHz depending on a random seed, and either number alone tells a confident,
  wrong story.
]

So the board runs at 35.7 MHz, from this lesson's own PLL, about 10% below the
slowest measured placement — the same kind of margin lesson 16 leaves at 40.

#measured("the three computers in this course")[
  #ttable(
    columns: (1fr, auto, auto),
    [], [*clock*], [*why*],
    [lesson 15 — single-cycle], [25 MHz], [it closes at 28; the oscillator is 25],
    [lesson 16 — pipelined], [40 MHz], [closes at 45.7, worst seed],
    [*lesson 17 — with traps and M*], [*35.7 MHz*], [closes at 39.5, worst seed],
  )
]

#strong[Privileged state and hardware multiply cost about six megahertz.] That
is the price of this lesson, stated the way this course states prices.

== What this machine still does not do

#ttable(
  columns: (auto, 1fr),
  [*modes*], [
    machine mode only. No user mode, no supervisor mode, no virtual memory —
    so no protection: every instruction can reach every CSR
  ],
  [*CSRs*], [
    an unimplemented CSR reads as zero. The specification says it should raise
    an illegal-instruction exception, and a core meaning to run an operating
    system must do that
  ],
  [*misaligned access*], [
    still not detected, as in lesson 13. The aligner does something
    well-defined and wrong; a real core traps
  ],
  [*interrupts*], [
    the timer, and nothing else. No external interrupt controller, no software
    interrupt, no nesting — a handler runs with interrupts disabled until it
    returns
  ],
  [*compliance*], [
    the official `riscv-arch-test` suite has not been run against this core.
    What is claimed is what was measured: lesson 13's conformance program gives
    identical results, and the lesson 14 proof of the ALU still holds
  ],
)

So: a machine that traps, handles interrupts, multiplies in hardware and counts
its own cycles — built from a single logic gate in seventeen steps.
