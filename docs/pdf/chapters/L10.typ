#import "../style.typ": *

= Lesson 10 — The ALU

== The idea

From here the modules are not illustrations. They are the processor's parts.

RV32I's integer ALU has #strong[ten operations and not one more]: add, sub,
three shifts, two comparisons, and three bitwise operations. A CISC machine
might have hundreds. Everything else is built by the compiler out of these —
negation is `sub` from `x0`, bitwise NOT is `xor` with −1, branch-if-greater is
branch-if-less with the operands swapped.

That austerity is the "reduced" in RISC, and it is a claim about what
#emph[hardware] should cost rather than about what programmers should write.

=== The encoding is a gift

The operation selector is `{instruction[30], funct3}` — four bits. Only
#strong[two] operations need bit 30, and they are exactly the two pairs where
one is the signed or arithmetic variant of the other: `ADD`/`SUB` and
`SRL`/`SRA`. So lesson 12's decoder pulls this field straight out of the
instruction word with no translation table at all.

#fig("/figures/alu-slice.svg",
     [One bit of the ALU in gates. Every operation is computed on every cycle;
      the opcode only decides which result is allowed out.],
     width: 100%)

== Theory

=== One adder does four jobs

`a − b == a + (~b) + 1` in two's complement, so subtraction is the #emph[same]
adder with `b` inverted and the carry-in set. And both comparisons fall out of
that same subtraction for free:

#strong[Unsigned less-than is the borrow.] Carry-out is 1 when there was no
borrow, i.e. when `a >= b`. So `a < b` is simply `~carry` — no comparator at
all.

#strong[Signed less-than is where ALUs go wrong.] It is not a comparison of the
raw bits, and it is not simply the sign of the difference either, because the
difference can overflow:

```verilog
wire overflow = (a[W-1] ^ b[W-1]) & (sum[W-1] ^ a[W-1]);
wire lt       = sum[W-1] ^ overflow;
```

#watch[
  The shortcut that nearly works: "if the signs differ, the answer is just
  `a`'s sign; a negative number is always less than a positive one." That is
  true, and implementing it that way passes almost every test you would write
  by hand. It fails exactly where the subtraction overflows — `INT_MIN` against
  `INT_MAX`, and `0` against `INT_MIN`.
]

=== The shift trap

```verilog
wire [W-1:0] sra = $signed(a) >>> sh;
```

`>>>` is an arithmetic shift #strong[only if its left operand is signed].
Writing `a >>> sh` on an unsigned wire silently performs a #emph[logical]
shift. It compiles, simulates, lints clean, and is wrong for every negative
input. `$signed(a)` is the whole fix, and this is the most common ALU bug there
is.

== Exhaustive testing dies here

A 32-bit ALU has 2#super[32] × 2#super[32] × 10 input combinations — about
4.6 × 10#super[19]. At a billion a second, 1,460 years.

What replaces it is the pattern for everything from here on:

+ #strong[Directed edge cases.] Twelve interesting operands — zero, one, −1,
  `INT_MAX`, `INT_MIN`, `INT_MIN+1`, −2, alternating patterns, shift amounts 31
  and 32 — crossed against each other for all ten operations. 1,440 vectors
  covering every extreme against every other extreme.

+ #strong[Randomised comparison against a reference model.] 20,000 vectors. The
  model uses Verilog's operators and `$signed`; the design builds the same
  answers from an adder and explicit overflow logic. Two different routes to
  one answer.

+ #strong[An independent second implementation, where a model would prove
  nothing.] This is the subtle one. The design's shifts #emph[are] Verilog's
  shift operators, so checking them against the same operators tests nothing
  whatsoever. They are cross-checked instead against an iterative shifter that
  moves one place per clock — a genuinely different implementation that can
  disagree.

=== Mutation testing

A test that has never caught a bug is unproven. So: break the design
deliberately and check the test notices.

#measured("three mutations, three catches, with the exact operands named")[
  #ttable(
    columns: (auto, auto),
    [`sra = a >> sh` — drop `$signed`], [caught: `a=ffffffff b=1 -> 7fffffff`],
    [`lt = sum[W-1]` — drop overflow],  [caught: `a=0 b=80000000 -> 1`],
    [`ltu = carry` — wrong polarity],   [caught: `a=0 b=1 -> 0`],
  )
]

#why[
  Mutation testing is the only way to know a testbench has teeth. Lesson 09
  found a testbench asserting something false and passing; this is the
  systematic version of that check, and every testbench from here on is worth
  mutating once.
]

== What it cost

The surprise is in the proportions, so each piece is reported on its own.

#cost([`alu` — the whole thing],
      (LUT4: 885, CCU2C: 17, PFUMX: 281, L6MUX21: 127),
      cmd: "make synth M=alu", share: true)[]

#cost([`adder` — 32-bit addition], (CCU2C: 17), cmd: "make synth M=adder")[
  Essentially free: no LUT4 at all.
]

#cost([`shift_barrel` — single-cycle shifting],
      (LUT4: 667, PFUMX: 262, L6MUX21: 139),
      cmd: "make synth M=shift_barrel")[
  #strong[About 80% of the ALU], for one operation out of ten.
]

#cost([`shift_iterative` — the same shifts, 31 cycles],
      (LUT4: 76, TRELLIS_FF: 40, CCU2C: 3, PFUMX: 32, L6MUX21: 1),
      cmd: "make synth M=shift_iterative")[]

The adder — what you would assume an ALU is mostly about — is seventeen carry
cells, because the fabric has dedicated carry hardware. Shifting has
#emph[none], so a barrel shifter is a tree of multiplexers five layers deep and
32 wide, three times over for the three shift kinds.

The iterative shifter is #strong[seven times smaller] and takes up to 31
cycles. On an 8-bit microcontroller that is the usual choice. In a single-cycle
CPU it is not available at all, so lesson 13 pays for the barrel shifter
whether it likes it or not.

#why[
  "Which operations are expensive" is a property of the fabric, not intuition.
  Addition is free here and shifting is not; on a chip with no carry chain the
  answer would invert.
]

== What it cost in time — the ceiling lesson 13 will hit

A registered 32-bit ALU closes at #strong[115.94 MHz], with the critical path
running through the adder's carry chain #emph[and] the ten-way result
multiplexer. Both on one path — which is precisely the argument lesson 16 makes
for splitting them across pipeline stages.
