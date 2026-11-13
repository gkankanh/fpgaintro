#import "../style.typ": *

= One instruction, end to end

Lessons 10 to 13 built an ALU, a register file, a decoder and a processor to
hold them. This chapter builds nothing. It takes a #emph[single] instruction
and walks it through the machine you now have, naming every file it touches on
the way — and then answers the four questions that always follow.

#align(center)[
  #block(inset: 10pt)[
    `add x5, x6, x7`
  ]
]

Add the contents of `x6` and `x7`, put the result in `x5`. With `x6 = 10` and
`x7 = 20`, afterwards `x5 = 30` and the two sources are untouched. That is the
whole of what the instruction set promises; everything below is how the promise
is kept.

#why[
  If the previous four chapters worked, nothing here will be new — and that is
  the point of reading it. A processor is not a thing you understand all at
  once; it is four things you already understand, arriving in order.
]

== Thirty-two bits that mean "add"

The instruction is not text and is never parsed. It is one 32-bit number, and
the hardware reads fields out of it by position. R-type, from bit 31 down:

#ttable(
  columns: (auto, auto, auto, 1fr),
  [*field*], [*bits*], [*width*], [*for this instruction*],
  [`funct7`], [31–25], [7], [`0000000`],
  [`rs2`],    [24–20], [5], [`00111` — x7],
  [`rs1`],    [19–15], [5], [`00110` — x6],
  [`funct3`], [14–12], [3], [`000`],
  [`rd`],     [11–7],  [5], [`00101` — x5],
  [`opcode`], [6–0],   [7], [`0110011` — register-register integer op],
)

Assembled by this repository's own assembler, which is where the number below
comes from rather than from arithmetic done by hand:

```
$ python3 tools/rvasm.py add.s --list
00000008  007302b3   add  t0, t1, t2
```

#measured("the same thirty-two bits, three ways")[
  ```
  0000000  00111  00110  000  00101  0110011
  funct7    rs2    rs1  funct3  rd    opcode

  0000 0000 0111 0011 0000 0010 1011 0011   =   0x007302B3
  ```
  `t0`, `t1` and `t2` #emph[are] `x5`, `x6` and `x7` — the ABI names the
  assembler accepts are the same five bits.
]

== Why the fields are where they are

Three questions that the layout above always provokes, and they have better
answers than "because the specification says so".

=== Why is the opcode at the bottom?

Because every other field's #emph[meaning] depends on it, so it must be
readable first — and a field at a fixed position is readable immediately rather
than after something else has been worked out. Lesson 12 made the consequence
concrete: the register fields never move either, so lesson 13's core addresses
the register file #emph[before the instruction has been understood at all].
Decode and register read happen at the same time, not one after the other.

=== Why five bits for a register number?

Because #strong[2#super[5] = 32], and RV32I has 32 registers. Five bits span
`00000` (x0) through `11111` (x31) and there is nothing left over.

#watch[
  Address width and data width are different things, and conflating them is a
  common first mistake. Each register is 32 bits #emph[wide], and its address is
  5 bits #emph[long]. The file holds 32 × 32 = 1,024 bits of state and needs 15
  address bits across its three ports to reach them — lesson 11 measured the
  whole thing at 266 LUT4 and 32 distributed-RAM cells.
]

=== Why seven bits for `funct7`?

Not because anything needs seven. #strong[Because seven is what is left.]

```
32 − 7 (opcode) − 5 (rd) − 3 (funct3) − 5 (rs1) − 5 (rs2)  =  7 bits
```

The other five fields are sized by what they must hold, they are nailed to
fixed positions so they can be read in parallel, and `funct7` is the remainder
of a 32-bit word after the useful fields have been placed. The architecture
then spends that space distinguishing a handful of operation pairs — `ADD` from
`SUB`, `SRL` from `SRA` — and leaves the rest for later.

#measured("how much of funct7 this course's hardware actually uses: one bit")[
  ```verilog
  assign alu_op = needs_add ? 4'b0000 : {alu_bit30, funct3};
  ```
  From `12-datapath/decode.v`. The ALU operation is chosen by `funct3` plus
  #strong[`inst[30]` alone] — one bit of the seven. The other six are never
  consulted to decide #emph[what to do] — they are only checked to decide
  whether the instruction is #emph[legal] at all, which is what that lesson's
  `bad_funct7` test does.
]

So: the encoding spends seven bits, the hardware reads one, and the gap between
those two numbers is encoding space held in reserve. That is a design choice
about the future, not a requirement of arithmetic.

== The journey

=== 1. Fetch

The program counter — 32 flip-flops, and in a single-cycle core the only state
the processor has — addresses instruction memory. `imem_addr = pc`, the memory
answers combinationally, and `inst` is the 32-bit number above.

=== 2. Decode, and register read, together

`decode.v` splits the instruction into control signals; `immgen.v` extracts an
immediate that this instruction will not use. Simultaneously, because the
register fields are at fixed positions, `rs1 = inst[19:15]` and
`rs2 = inst[24:20]` go straight to the register file. No instruction has been
"understood" yet and the operands are already being fetched.

The decoder does not add. It identifies, and it asserts `reg_we`.

=== 3. Execute

The ALU of lesson 10 receives `a = 10`, `b = 20` and `alu_op = {0, 000}`, and
produces 30. Underneath, a 32-bit adder — which lesson 02 built out of gates at
212 cells and lesson 10 got for 17 `CCU2C` and #emph[no LUT4 at all] by writing
`+` and letting the fabric's carry chain do it.

=== 4. Write-back

`wb_src` selects the ALU result over the memory and PC+4 paths, `rd = x5`, and
at the clock edge the register file takes the write. Had `rd` been `x0`, the
register file would have discarded it — which is lesson 11's one-line mechanism
and the reason `jal x0, label` needs no special case anywhere.

=== 5. The next instruction

Not a branch, not a jump: `pc <= pc + 4`. The same clock edge that writes `x5`
advances the program counter, which is what makes this a single-cycle machine.

== What it looks like in the simulator

Running those five steps on the lesson 13 core, printing the core's own signals
at each negative edge:

#measured("observed, on the core from lesson 13")[
  ```
  pc=00000004  inst=01400393  rs1=x0(0)   rs2=x20(x)  alu_y=20  rd=x7  reg_we=1
  pc=00000008  inst=007302b3  rs1=x6(10)  rs2=x7(20)  alu_y=30  rd=x5  reg_we=1
  pc=0000000c  inst=10502023  rs1=x0(0)   rs2=x5(30)  alu_y=256 rd=x0  reg_we=0
  pc=00000010  inst=0000006f  ...
  x5 stored to 0x100 = 30
  ```
]

The middle line is the instruction. `inst` is the number this chapter opened
with, `rs1` and `rs2` carry 10 and 20, the ALU produces 30, `rd` is x5 and
`reg_we` is high. The line below it is the store that proves it: `rs2=x5(30)`
— the register really does hold 30 on the next cycle.

#watch[
  Look at the third line's `reg_we=0` and the first line's `rs2=x20(x)`. The
  store writes no register, so its `rd` field is not a destination; and `li`
  has no second source, so the bits sitting in `rs2` name a register nobody
  asked for and the value read is #emph[X]. Both are harmless — nothing
  downstream looks — and both are the hardware reading fields it cannot yet
  know are meaningless. That is the price of decoding in parallel, and it is
  cheap.
]

== The control signals, and what they are called here

Textbooks name these after the classic MIPS datapath. This course names them
after what they select, and they are the same signals:

#ttable(
  columns: (auto, auto, 1fr),
  [*textbook*], [*this course*], [*for `add x5, x6, x7`*],
  [`RegWrite`],   [`reg_we`],     [1 — the result is kept],
  [`ALUSrc`],     [`alu_b_imm`],  [0 — operand B is `rs2`, not the immediate],
  [`ALUOp`],      [`alu_op`],     [`0000` — add],
  [`MemRead`],    [`mem_read`],   [0],
  [`MemWrite`],   [`mem_write`],  [0],
  [`MemToReg`],   [`wb_src`],     [`WB_ALU` — the ALU result, not memory],
  [`Branch`],     [`branch`],     [0 — the next PC is `pc + 4`],
)

== The ten operations that share this opcode

`0110011` is not "add". It is "register-register integer operation", and
`funct3` with one bit of `funct7` picks which:

#ttable(
  columns: (auto, auto, auto, 1fr),
  [*instruction*], [*`funct7`*], [*`funct3`*], [],
  [`ADD`],  [`0000000`], [`000`], [the one in this chapter],
  [`SUB`],  [`0100000`], [`000`], [same `funct3`; `inst[30]` is the difference],
  [`SLL`],  [`0000000`], [`001`], [],
  [`SLT`],  [`0000000`], [`010`], [signed],
  [`SLTU`], [`0000000`], [`011`], [unsigned],
  [`XOR`],  [`0000000`], [`100`], [],
  [`SRL`],  [`0000000`], [`101`], [logical],
  [`SRA`],  [`0100000`], [`101`], [arithmetic; `inst[30]` again],
  [`OR`],   [`0000000`], [`110`], [],
  [`AND`],  [`0000000`], [`111`], [],
)

Ten instructions, one opcode, and exactly two places where `funct7` matters.
Note how little of the ALU's cost this table represents: lesson 10 measured the
whole ALU at 885 LUT4, of which the barrel shifter — `SLL`, `SRL`, `SRA`, three
rows — is about 80%.

== How many instructions does RISC-V have?

There is no single answer, and the reason is the architecture's main idea.

#ttable(
  columns: (auto, 1fr),
  [*RV32I*], [
    40 instructions in the unprivileged base: `LUI`, `AUIPC`, `JAL`, `JALR`,
    six branches, five loads, three stores, nine register-immediate and ten
    register-register operations, plus `FENCE`, `ECALL` and `EBREAK`
  ],
  [*M*], [multiply and divide — lesson 17 adds these],
  [*Zicsr*], [the CSR instructions — lesson 17 adds these too],
  [*A, F, D*], [atomics, single- and double-precision floating point],
  [*C*], [16-bit compressed encodings],
  [*B, V*], [bit manipulation, vectors],
)

A RISC-V processor implements the base plus whichever extensions it chooses,
and says so in the `misa` register. #strong[This course's core implements RV32I
less `FENCE`, `ECALL` and `EBREAK` at lesson 13], adds `Zicsr` and `M` at
lesson 17, and is honest in both chapters about what it has not been tested
against.

#why[
  Modularity is why `MUL` hides under opcode `0110011` with
  `funct7 = 0000001` rather than taking an opcode of its own. Opcodes are the
  scarce resource in a fixed 32-bit encoding; an extension that needed one
  would be an extension that could not coexist with another. Lesson 12's
  `funct7` legality check is exactly what makes `MUL` illegal on a core without
  M — which is what the specification requires, and why that check was worth
  writing before there was anything to reject.
]

== What this chapter is not

It is one instruction, on one implementation, explained completely. It is not a
specification: instruction legality, privileged behaviour and extension
encodings are defined by the official RISC-V ISA manuals, and anything built to
interoperate should be checked against those rather than against this. The
reading list at the end of this book says where they are.

What it #emph[is] is the answer to "but what actually happens?" — and the answer
turns out to be four modules you built, in order, inside one clock period.
