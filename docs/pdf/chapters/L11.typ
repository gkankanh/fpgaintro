#import "../style.typ": *

= Lesson 11 — The register file

#goals(
  concept: [Two reads and one write per cycle from one array, and the one register hardwired to zero.],
  build: [RV32I's 32 × 32-bit register file, plus a block-RAM alternative, measured against each other at two very different sizes.],
  needs: [Lesson 10.],
)[
  - Explain why RISC instructions have at most two source registers.
  - Explain what `x0` buys, and count the instructions it eliminates.
  - Justify a combinational read here, having been warned against one in lesson 08.
  - Explain why read-during-write must return the old value.
  - Distinguish a mutation that survives from a test that is weak.
]

== The shape is dictated by the instruction set

```
add rd, rs1, rs2
```

One instruction, #strong[two source operands read in the same cycle], one
result written. So: two read ports and one write port. If the file had three
read ports, instructions could have three sources. If it had one, R-type
instructions as we know them could not exist.

#why[
  The instruction set and the register file are the same design decision seen
  from two sides. Register-file ports are expensive, and that cost is visible
  in the shape of every RISC instruction set — this is the clearest example in
  the course of hardware constraints writing software syntax.
]

== `x0`

Reads of `x0` return zero; writes are discarded. Two lines of Verilog, and they
simplify the whole instruction set. None of the following are real instructions
— they are assembler conveniences that exist #emph[because] one register reads
as zero and swallows writes:

#ttable(
  columns: (auto, auto),
  [*what you write*], [*what it assembles to*],
  [`mv rd, rs`],   [`addi rd, rs, 0`],
  [`li rd, imm`],  [`addi rd, x0, imm`],
  [`nop`],         [`addi x0, x0, 0`],
  [`not rd, rs`],  [`xori rd, rs, -1`],
  [`neg rd, rs`],  [`sub rd, x0, rs`],
  [`beqz rs, L`],  [`beq rs, x0, L`],
  [`j L`],         [`jal x0, L` — throw the return address away],
  [`ret`],         [`jalr x0, 0(x1)`],
)

One register sacrificed; eight instructions avoided. `jal x0, L` is the
neatest: a jump-and-link whose link register is the bit bucket #emph[is] an
unconditional jump, so the ISA needs no `j` opcode at all.

== Combinational reads, and why lesson 08 agrees

A single-cycle CPU must read its operands, compute, and write back inside one
clock period, so the read has to be combinational. Lesson 08 showed that rules
out block RAM — which sounded like a warning, and here is the correct answer,
because lesson 08's #emph[other] finding applies: at a few tens of entries the
fabric builds arrays from lookup tables as distributed RAM, cheaply and with no
latency.

#measured("at 32 registers, asking for block RAM does not even get you block RAM")[
  #ttable(
    columns: (auto, auto),
    [combinational read], [266 LUT4 + 198 muxes + 32 DPR16X4],
    [registered read],    [214 LUT4 + 108 FF + 32 DPR16X4 — #strong[no DP16KD at all]],
  )
  Thirty-two entries is too small for the synthesiser to spend a block on, so
  the "block RAM version" got distributed RAM too — the same storage, plus 108
  flip-flops of pipeline registers, plus a cycle of latency, for nothing.
]

#measured("at 1024 registers the trade flips decisively")[
  #ttable(
    columns: (auto, auto),
    [combinational read], [#strong[3,660 LUT4] + 454 muxes + 1,024 DPR16X4],
    [registered read],    [#strong[4 DP16KD] + 192 LUT4 + 131 FF],
  )
]

Same two modules, same code, opposite conclusion — decided entirely by size. A
vector machine's register file lives on the right of that table; RV32I's lives
firmly on the left.

== Read-during-write returns the old value

During cycle #emph[N] an instruction reads its operands, computes, and its
result is written by the clock edge at the #emph[end] of cycle #emph[N]. So a
read of the register being written returns the #strong[old] value — which is
not a limitation but a requirement: an instruction must see its operands as
they were before it ran.

#watch[
  This confuses people in both directions. Some expect a write-to-read bypass
  and are surprised by the old value; others add one and silently change what
  their CPU computes. The testbench asserts the old value explicitly, so adding
  a bypass later is a visible, deliberate change.

  Bypass becomes #emph[necessary] when a read and a write belong to different
  instructions in flight at once — lesson 16's pipeline, and the block-RAM
  variant above, where latency forces the issue.
]

== A mutation that should survive

Four mutations; three caught. The fourth — #emph[allowing writes to `x0`] —
survives, and that is the interesting result.

It survives because `x0`'s behaviour is enforced in #strong[two independent
places] and either one alone suffices. With the write guard gone, `regs[0]`
holds garbage that the read mask makes unobservable. Remove #emph[both] and the
test fails immediately.

#why[
  So the correct reading is not "the test is weak" but "the code is
  deliberately redundant" — and no behavioural test can distinguish them,
  because there is no behavioural difference. A test reaching inside to inspect
  `regs[0]` would be testing the implementation rather than the contract.

  #strong[A surviving mutation means either your test missed something, or your
  code has belt-and-braces redundancy. Check which before fixing anything.]
  Lesson 12 meets the other kind.
]

== Exhaustive testing is briefly back

A register file has 32 addresses, not 2#super[32] values, so the thing that
matters — #emph[which register] — can be swept completely. All 961 pairs of
distinct registers are read simultaneously, which is what catches a second port
quietly sharing the first one's address decoder.
