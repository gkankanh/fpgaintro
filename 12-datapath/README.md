# Lesson 12 — decode and control

**Concept:** turning a 32-bit instruction word into control signals — and why
RISC-V's immediate encoding looks deranged and is not.

**You will build:** a decoder for all of RV32I plus the immediate generator,
tested against 52 real instruction encodings.

**Needs the board:** optional — the demo steps through instructions and shows
their control signals

**Prerequisites:** lesson 11

**Paths:** editor only

**By the end you can:**

- Explain why the opcode and register fields sit at fixed positions.
- Explain the immediate layout in terms of multiplexer inputs.
- Avoid the trap that makes every negative `addi` subtract.
- Test a decoder with legal cases adjacent to its illegal ones.

---

## The idea

Nothing executes in this lesson. The decoder only answers *"what does this
instruction want done"*, and lesson 13 wires those answers to lesson 10's ALU
and lesson 11's register file.

### Why the opcode is seven bits and always in `inst[6:0]`

Every other field's *meaning* depends on the opcode, so the opcode must be
decodable before anything else. Putting it at a fixed position means the
register fields, `funct3` and the immediate can all be extracted **in parallel**
with decoding the opcode rather than after it.

The register fields never move either: `rs1` is always `inst[19:15]`, `rs2`
always `inst[24:20]`, `rd` always `inst[11:7]`. So lesson 13 can address the
register file *before the instruction has been understood at all*.

> **Why this matters** — in a single-cycle CPU that parallelism is the
> difference between one mux delay and two on the critical path. The ISA is
> arranged for the benefit of the hardware, repeatedly and deliberately.

## The immediates look deranged

Five formats carry an immediate, each laid out differently:

```
I  imm[11:0]  = inst[31:20]
S  imm[11:5]  = inst[31:25],  imm[4:0]   = inst[11:7]
B  imm[12]    = inst[31],     imm[10:5]  = inst[30:25],
   imm[4:1]   = inst[11:8],   imm[11]    = inst[7]
U  imm[31:12] = inst[31:12]
J  imm[20]    = inst[31],     imm[10:1]  = inst[30:21],
   imm[11]    = inst[20],     imm[19:12] = inst[19:12]
```

B puts `imm[11]` in `inst[7]` while `imm[12]` is in `inst[31]`. J shuffles its
bits out of order entirely. Read as a table it looks like vandalism.

### It is optimised for the hardware you are about to build

Two rules explain all of it:

**1. The sign bit is always `inst[31]`.** Every format. So sign extension needs
no multiplexer at all — just replicate one fixed wire.

**2. Each immediate bit comes from as few different places as possible.**
`imm[10:5]` is `inst[30:25]` in I, S, B *and* J. `imm[4:1]` is `inst[24:21]` in
I and J, `inst[11:8]` in S and B.

Rule 2 is *why* B and J look shuffled: bit positions were assigned to keep them
aligned **across** formats, not in order **within** one.

And it is measurable. Counting the distinct instruction-word positions that
feed each of the 32 immediate output bits — a bit with *N* sources needs an
*N*-input mux:

| sources | bits |
|---|---|
| 1 (no mux at all) | **24** |
| 2 | 7 |
| 3 | 1 |

**41 mux inputs across all 32 bits**, against an upper bound of 160 if the
five layouts were uncorrelated — 26% of it. And the single bit needing three
sources is `imm[11]`:

```
imm[11] <- inst[31]  (I)   inst[20]  (J)   inst[7]  (B)
```

Which is exactly the bit that looks most arbitrary in the spec. It is the one
place the optimisation ran out of room, and the designers put the ugliness
there rather than spread it everywhere.

> **Why this matters** — "the encoding is weird" and "the encoding is
> carefully optimised" are the same observation from two sides. You cannot see
> which it is from the spec; you can see it immediately from the mux count.

Note too that B and J immediates are implicitly multiplied by two — bit 0 is
always zero and is not stored, because instructions are 2-byte aligned. One
extra bit of branch range, free.

## The trap: `addi` with a negative immediate

Lesson 10's ALU takes `{inst[30], funct3}`. For R-type that falls straight out
of the instruction word. For I-type it very nearly does, and the exception is a
**real bug that is easy to ship**:

```
addi x1, x2, -1
```

has `imm = 0xFFF`, so `inst[31:20]` is all ones and **`inst[30]` is 1**. Pass
`{inst[30], funct3} = {1, 000}` to the ALU and it performs **SUB** instead of
ADD — so `addi` with *any* negative immediate silently subtracts.

```verilog
wire use_bit30 = is_reg || (is_imm && funct3 == 3'b101);
wire alu_bit30 = use_bit30 ? inst[30] : 1'b0;
```

`inst[30]` is only meaningful for OP-IMM when `funct3 == 101` — SRLI versus
SRAI. Everywhere else in OP-IMM it is part of the immediate and must be forced
to zero.

> **Watch out** — this is invisible in an R-type-only test, and it is the
> reason lesson 13's first program would otherwise compute nonsense. Any
> immediate ≥ 1024 or negative trips it.

And there is a second override in the same place: loads, stores, jumps, AUIPC
and LUI all need an **addition** regardless of `funct3`, because for those
instructions `funct3` means something else entirely (a width, or which
comparison). So it must not reach the ALU.

> **Watch out — a bug in my own first draft.** `alu_op` was assigned from
> `{alu_bit30, funct3}`, and then a *separate* wire `alu_op_final` applied the
> needs-add override — and was never connected to anything. Every load would
> have asked the ALU for whatever `funct3` happened to mean. `make lint` caught
> the dangling wire. It is a good argument for exactly one assignment per
> output.

## Simulate it

```bash
cd 12-datapath
make sim
```

```
PASS: 157 checks - 52 real instruction encodings decoded, every immediate
format exact, negative addi asks for ADD not SUB, 8 malformed instructions
flagged illegal
```

The vectors are **real encodings**, not invented bit patterns. They were
generated by a small Python assembler (in the lesson's git history, and easy to
rebuild) and each is labelled with the assembly it came from:

```verilog
iv[ 0] = 32'h003100B3;  // add x1,x2,x3
iv[ 1] = 32'h403100B3;  // sub x1,x2,x3
iv[12] = 32'hFFF10093;  // addi x1,x2,-1
```

Covering every format, the sign-extended extremes of each (`±2047` for I,
`±4096` for B, `±1048574` for J), and eight malformed instructions that must
raise `illegal`.

**The legal contrast cases matter as much as the illegal ones.** A decoder that
rejected everything would pass all the illegal tests, so `blt` (`funct3=100`),
`bge` (`funct3=101`) and `sra` (`funct7=0100000`) are asserted *not* to be
flagged — they sit right next to encodings that are.

> **Watch out** — one of my illegal vectors was simply wrong. I wrote
> `0x00314863` intending "branch with `funct3=011`"; it actually has
> `funct3=100`, which is `blt` and perfectly legal. The decoder correctly
> declined to flag it and the test failed. Hand-computing instruction
> encodings is error-prone; compute them with a script and print the fields
> back to check.

### Mutation testing found a hole in the vectors

| mutation | caught? |
|---|---|
| `inst[30]` through for all of OP-IMM (the trap) | ✅ `addi -1 alu_op = 8, expected 0` |
| drop the SRAI exception | ✅ `srai alu_op = 5, expected d` |
| loads do not force ADD | ✅ `load alu_op = 2, expected 0` |
| stores write a register | ✅ `store reg_we = 1, expected 0` |
| JAL writes the ALU result, not pc+4 | ✅ `jal wb_src = 0, expected 2` |
| J-type `imm[11]` from `inst[31]` | ✅ `imm = 000ff7fe, expected 000ffffe` |
| **S-type `imm[0]` forced to zero** | ❌ **survived** |

That last one was a genuine gap. **Every store offset in my vectors happened to
be even** — 12 and −8 — so forcing `imm[0]` to zero was completely invisible.
Adding `sb x3,7(x2)` and `sb x3,-7(x2)` catches it immediately:

```
FAIL inst=003103a3  imm = 00000006, expected 00000007
```

Unlike lesson 11's surviving mutation — which was benign, because the design
was redundant — this one was a real missing test. Mutation testing found the
hole in the *vectors*, not in the design. Both outcomes are useful; telling
them apart is the skill.

## What it cost

`decode_top` — the whole design:

```bash
make synth
```

| resource | count |
|---|---:|
| `LUT4` | 53 |
| `TRELLIS_FF` | 14 |
| `PFUMX` | 14 |
| `L6MUX21` | 9 |

53 of the 85F's 83,640 LUT4 — 0.06% of the part.

`immgen` — the immediate generator:

```bash
make synth M=immgen
```

| resource | count |
|---|---:|
| `LUT4` | 70 |
| `PFUMX` | 17 |
| `L6MUX21` | 10 |

`decode` — the control decoder:

```bash
make synth M=decode
```

| resource | count |
|---|---:|
| `LUT4` | 45 |
| `PFUMX` | 8 |
| `L6MUX21` | 3 |

**The immediate generator costs more than the entire control decoder.** Which
is consistent with the mux count: 41 inputs spread across 32 output bits, plus
the format selection, versus a handful of opcode comparisons producing about
fifteen one-bit control signals.

Both are tiny next to lesson 10's ALU (885 LUT4). Decode is cheap; execution
is where the silicon goes.

## On the board

```bash
make prog
```

`sw[3:0]` steps through sixteen instructions and the LEDs show what each one
wants:

| led | signal |
|---|---|
| 7 | `illegal` |
| 6 | `reg_we` — does it write a register? |
| 5 | `mem_read` — is it a load? |
| 4 | `mem_write` — is it a store? |
| 3 | `branch` |
| 2 | `jump` |
| 1:0 | `wb_src` — 0 = ALU, 1 = memory, 2 = pc+4 |

Position 15 is deliberately malformed, so `led[7]` lights. Positions 5 (`sw`)
and 6 (`beq`) are the two that write no register — `led[6]` goes dark.

## Exercises

1. **Reproduce the mux count.** Write out the immediate table and count the
   distinct sources per output bit. Then invent a "tidier" encoding where each
   format's immediate is contiguous, and count again.
2. **Ship the trap.** Set `use_bit30 = is_reg || is_imm` and run `make sim`.
   Then work out which of lesson 13's instructions would break and how the
   symptom would present.
3. **Add `ECALL`.** Opcode `1110011`, `funct3 = 000`, `imm = 0`. It should not
   be illegal, and should write no register. Lesson 17 needs it.
4. **Make `illegal` stricter.** RV32I also requires SLLI/SRLI/SRAI to have
   `imm[11:5]` of `0000000` or `0100000`. Add that check, then find an
   instruction your decoder used to accept.
5. **Decode by hand.** Take `0xFE310CA3` and work out the instruction, the
   registers and the immediate using only the format table. Then check it
   against the testbench vectors.

## Wrap-up

**What you built.** An instruction decoder and an immediate generator, tested on legal encodings and the illegal ones next door — and the immediate generator costs more than the decoder.

**What to keep.** Fixed field positions are what let every field be decoded in parallel.

**What comes next.** Lesson 13 wires the ALU, the register file and this decoder into a processor.
