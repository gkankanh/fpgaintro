#!/usr/bin/env python3
"""
rvasm.py — a small RV32I assembler, producing $readmemh output.

Why this exists
---------------
Lesson 13's CPU needs programs, and lesson 15 compiles C with riscv-gcc. In
between there is a gap: hand-encoding instructions in hex is miserable and
error-prone (lesson 12 shipped a wrong test vector that way), while installing
a full GNU toolchain just to write twenty instructions is heavy.

So: enough assembler to write test programs, in one readable file, with no
dependencies. It supports the whole RV32I instruction set, labels, the common
pseudo-instructions, and the directives the lessons need.

    tools/rvasm.py prog.s -o prog.hex          # one word per line, for $readmemh
    tools/rvasm.py prog.s --list               # show the encoding beside the source

The output is a SOURCE file as far as the hardware is concerned: $readmemh
reads it at elaboration time (lesson 08), so changing the program means
resynthesising.
"""
from __future__ import annotations

import argparse
import re
import sys

# --------------------------------------------------------------------- tables

R_TYPE = {   # name: (funct7, funct3)
    "add": (0x00, 0), "sub": (0x20, 0), "sll": (0x00, 1), "slt": (0x00, 2),
    "sltu": (0x00, 3), "xor": (0x00, 4), "srl": (0x00, 5), "sra": (0x20, 5),
    "or": (0x00, 6), "and": (0x00, 7),
}
I_ARITH = {  # name: funct3
    "addi": 0, "slti": 2, "sltiu": 3, "xori": 4, "ori": 6, "andi": 7,
}
I_SHIFT = {  # name: (funct3, funct7-ish high bits of the immediate)
    "slli": (1, 0x00), "srli": (5, 0x00), "srai": (5, 0x20),
}
LOADS = {"lb": 0, "lh": 1, "lw": 2, "lbu": 4, "lhu": 5}
STORES = {"sb": 0, "sh": 1, "sw": 2}
BRANCHES = {"beq": 0, "bne": 1, "blt": 4, "bge": 5, "bltu": 6, "bgeu": 7}

OP_REG, OP_IMM, OP_LOAD, OP_STORE = 0x33, 0x13, 0x03, 0x23
OP_BRANCH, OP_JAL, OP_JALR, OP_LUI, OP_AUIPC = 0x63, 0x6F, 0x67, 0x37, 0x17
OP_SYSTEM = 0x73

ABI = {
    "zero": 0, "ra": 1, "sp": 2, "gp": 3, "tp": 4, "t0": 5, "t1": 6, "t2": 7,
    "s0": 8, "fp": 8, "s1": 9, "a0": 10, "a1": 11, "a2": 12, "a3": 13,
    "a4": 14, "a5": 15, "a6": 16, "a7": 17, "s2": 18, "s3": 19, "s4": 20,
    "s5": 21, "s6": 22, "s7": 23, "s8": 24, "s9": 25, "s10": 26, "s11": 27,
    "t3": 28, "t4": 29, "t5": 30, "t6": 31,
}


class AsmError(Exception):
    pass


def bits(v: int, hi: int, lo: int) -> int:
    return (v >> lo) & ((1 << (hi - lo + 1)) - 1)


def reg(tok: str) -> int:
    t = tok.strip().lower()
    if t in ABI:
        return ABI[t]
    m = re.fullmatch(r"x(\d{1,2})", t)
    if m and 0 <= int(m.group(1)) <= 31:
        return int(m.group(1))
    raise AsmError(f"not a register: {tok!r}")


def fits_signed(v: int, n: int) -> bool:
    return -(1 << (n - 1)) <= v < (1 << (n - 1))


# ------------------------------------------------------------------ encoders

def enc_r(f7, rs2, rs1, f3, rd, op):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_i(imm, rs1, f3, rd, op):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_s(imm, rs2, rs1, f3, op):
    i = imm & 0xFFF
    return (bits(i, 11, 5) << 25) | (rs2 << 20) | (rs1 << 15) | \
           (f3 << 12) | (bits(i, 4, 0) << 7) | op


def enc_b(imm, rs2, rs1, f3, op):
    i = imm & 0x1FFF
    return (bits(i, 12, 12) << 31) | (bits(i, 10, 5) << 25) | (rs2 << 20) | \
           (rs1 << 15) | (f3 << 12) | (bits(i, 4, 1) << 8) | \
           (bits(i, 11, 11) << 7) | op


def enc_u(imm20, rd, op):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | op


def enc_j(imm, rd, op):
    i = imm & 0x1FFFFF
    return (bits(i, 20, 20) << 31) | (bits(i, 10, 1) << 21) | \
           (bits(i, 11, 11) << 20) | (bits(i, 19, 12) << 12) | (rd << 7) | op


# -------------------------------------------------------------------- parsing

def split_operands(rest: str) -> list[str]:
    return [p.strip() for p in rest.split(",")] if rest.strip() else []


MEM_RE = re.compile(r"^(-?(?:0x)?[0-9a-fA-F]+|\w+)?\s*\(\s*(\S+?)\s*\)$")


def parse_mem(tok: str, labels, pc) -> tuple[int, int]:
    """Parse `offset(reg)`; offset may be omitted, numeric, or a label."""
    m = MEM_RE.match(tok.strip())
    if not m:
        raise AsmError(f"expected offset(reg), got {tok!r}")
    off_s, rs = m.group(1), m.group(2)
    off = 0 if off_s is None else value(off_s, labels, pc)
    return off, reg(rs)


def value(tok: str, labels, pc) -> int:
    """A number, a label, or %hi/%lo of one."""
    t = tok.strip()
    m = re.fullmatch(r"%(hi|lo)\(\s*(\S+?)\s*\)", t)
    if m:
        kind, name = m.group(1), m.group(2)
        v = value(name, labels, pc)
        if kind == "hi":
            # The low 12 bits are added as a SIGNED value by the following
            # addi, so borrow one if bit 11 is set.
            return ((v + 0x800) >> 12) & 0xFFFFF
        return ((v & 0xFFF) ^ 0x800) - 0x800
    if t in labels:
        return labels[t]
    try:
        return int(t, 0)
    except ValueError:
        raise AsmError(f"cannot evaluate {tok!r}")


# ------------------------------------------------------------------ assembler

def assemble(src: str, base: int = 0):
    """Two passes: collect labels, then emit. Returns (words, listing)."""
    lines = []
    for lineno, raw in enumerate(src.split("\n"), 1):
        text = raw.split("#")[0].split("//")[0].rstrip()
        if text.strip():
            lines.append((lineno, raw.rstrip(), text.strip()))

    # ---- pass 1: label addresses, counting how many words each line emits
    labels: dict[str, int] = {}
    pc = base
    pass1 = []
    for lineno, raw, text in lines:
        while True:
            m = re.match(r"^([A-Za-z_.$][\w.$]*)\s*:\s*(.*)$", text)
            if not m:
                break
            labels[m.group(1)] = pc
            text = m.group(2).strip()
        if not text:
            continue
        parts = text.split(None, 1)
        mnem = parts[0].lower()
        rest = parts[1] if len(parts) > 1 else ""
        n = words_emitted(mnem, rest)
        pass1.append((lineno, raw, mnem, rest, pc))
        pc += 4 * n

    # ---- pass 2: encode
    words: list[int] = []
    listing: list[str] = []
    for lineno, raw, mnem, rest, at in pass1:
        try:
            ws = encode(mnem, rest, labels, at)
        except AsmError as e:
            raise AsmError(f"line {lineno}: {e}\n    {raw.strip()}")
        for k, w in enumerate(ws):
            listing.append(f"{at + 4*k:08x}  {w:08x}   "
                           f"{raw.strip() if k == 0 else '  (continued)'}")
            words.append(w & 0xFFFFFFFF)
    return words, listing, labels


def words_emitted(mnem: str, rest: str) -> int:
    """Pseudo-instructions that expand to two words must be counted in pass 1."""
    if mnem in ("li",):
        try:
            v = int(split_operands(rest)[1], 0)
            return 1 if fits_signed(v, 12) else 2
        except (ValueError, IndexError):
            return 2
    if mnem in ("la", "call"):
        return 2
    return 1


def encode(mnem, rest, labels, pc) -> list[int]:
    o = split_operands(rest)

    # ---------------------------------------------------------- directives
    if mnem in (".word", ".4byte"):
        return [value(x, labels, pc) & 0xFFFFFFFF for x in o]
    if mnem == ".nop":
        return [enc_i(0, 0, 0, 0, OP_IMM)]

    # ------------------------------------------------- pseudo-instructions
    if mnem == "nop":
        return [enc_i(0, 0, 0, 0, OP_IMM)]
    if mnem == "mv":
        return [enc_i(0, reg(o[1]), 0, reg(o[0]), OP_IMM)]
    if mnem == "not":
        return [enc_i(-1, reg(o[1]), 4, reg(o[0]), OP_IMM)]
    if mnem == "neg":
        return [enc_r(0x20, reg(o[1]), 0, 0, reg(o[0]), OP_REG)]
    if mnem == "seqz":
        return [enc_i(1, reg(o[1]), 3, reg(o[0]), OP_IMM)]
    if mnem == "snez":
        return [enc_r(0x00, reg(o[1]), 0, 3, reg(o[0]), OP_REG)]
    if mnem == "li":
        rd, v = reg(o[0]), value(o[1], labels, pc)
        if fits_signed(v, 12):
            return [enc_i(v, 0, 0, rd, OP_IMM)]
        hi = ((v + 0x800) >> 12) & 0xFFFFF
        lo = ((v & 0xFFF) ^ 0x800) - 0x800
        return [enc_u(hi, rd, OP_LUI), enc_i(lo, rd, 0, rd, OP_IMM)]
    if mnem == "la":
        rd, v = reg(o[0]), value(o[1], labels, pc)
        hi = ((v + 0x800) >> 12) & 0xFFFFF
        lo = ((v & 0xFFF) ^ 0x800) - 0x800
        return [enc_u(hi, rd, OP_LUI), enc_i(lo, rd, 0, rd, OP_IMM)]
    if mnem == "j":
        return [enc_j(value(o[0], labels, pc) - pc, 0, OP_JAL)]
    if mnem == "jr":
        return [enc_i(0, reg(o[0]), 0, 0, OP_JALR)]
    if mnem == "ret":
        return [enc_i(0, 1, 0, 0, OP_JALR)]
    if mnem in ("beqz", "bnez", "bltz", "bgez"):
        f3 = {"beqz": 0, "bnez": 1, "bltz": 4, "bgez": 5}[mnem]
        return [enc_b(value(o[1], labels, pc) - pc, 0, reg(o[0]), f3, OP_BRANCH)]
    if mnem in ("bgt", "ble", "bgtu", "bleu"):
        # Swap the operands; RISC-V has no reversed branches on purpose.
        f3 = {"bgt": 4, "ble": 5, "bgtu": 6, "bleu": 7}[mnem]
        return [enc_b(value(o[2], labels, pc) - pc,
                      reg(o[0]), reg(o[1]), f3, OP_BRANCH)]

    # ------------------------------------------------- real instructions
    if mnem in R_TYPE:
        f7, f3 = R_TYPE[mnem]
        return [enc_r(f7, reg(o[2]), reg(o[1]), f3, reg(o[0]), OP_REG)]
    if mnem in I_ARITH:
        v = value(o[2], labels, pc)
        if not fits_signed(v, 12):
            raise AsmError(f"immediate {v} does not fit in 12 signed bits")
        return [enc_i(v, reg(o[1]), I_ARITH[mnem], reg(o[0]), OP_IMM)]
    if mnem in I_SHIFT:
        f3, top = I_SHIFT[mnem]
        sh = value(o[2], labels, pc)
        if not 0 <= sh < 32:
            raise AsmError(f"shift amount {sh} out of range 0..31")
        return [enc_i((top << 5) | sh, reg(o[1]), f3, reg(o[0]), OP_IMM)]
    if mnem in LOADS:
        off, rs1 = parse_mem(o[1], labels, pc)
        return [enc_i(off, rs1, LOADS[mnem], reg(o[0]), OP_LOAD)]
    if mnem in STORES:
        off, rs1 = parse_mem(o[1], labels, pc)
        return [enc_s(off, reg(o[0]), rs1, STORES[mnem], OP_STORE)]
    if mnem in BRANCHES:
        target = value(o[2], labels, pc)
        off = target - pc
        if off % 2:
            raise AsmError("branch target is not 2-byte aligned")
        if not fits_signed(off, 13):
            raise AsmError(f"branch offset {off} out of range")
        return [enc_b(off, reg(o[1]), reg(o[0]), BRANCHES[mnem], OP_BRANCH)]
    if mnem == "jal":
        if len(o) == 1:                      # jal label  ->  rd = ra
            return [enc_j(value(o[0], labels, pc) - pc, 1, OP_JAL)]
        return [enc_j(value(o[1], labels, pc) - pc, reg(o[0]), OP_JAL)]
    if mnem == "jalr":
        if len(o) == 1:
            return [enc_i(0, reg(o[0]), 0, 1, OP_JALR)]
        off, rs1 = parse_mem(o[1], labels, pc)
        return [enc_i(off, rs1, 0, reg(o[0]), OP_JALR)]
    if mnem == "lui":
        return [enc_u(value(o[1], labels, pc), reg(o[0]), OP_LUI)]
    if mnem == "auipc":
        return [enc_u(value(o[1], labels, pc), reg(o[0]), OP_AUIPC)]
    if mnem == "ecall":
        return [enc_i(0, 0, 0, 0, OP_SYSTEM)]
    if mnem == "ebreak":
        return [enc_i(1, 0, 0, 0, OP_SYSTEM)]

    raise AsmError(f"unknown instruction {mnem!r}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("source")
    ap.add_argument("-o", "--output", help="hex file for $readmemh")
    ap.add_argument("--base", type=lambda s: int(s, 0), default=0,
                    help="address of the first instruction (default 0)")
    ap.add_argument("--list", action="store_true",
                    help="print address, encoding and source side by side")
    args = ap.parse_args()

    try:
        words, listing, labels = assemble(open(args.source).read(), args.base)
    except AsmError as e:
        print(f"rvasm: {e}", file=sys.stderr)
        return 1

    if args.list:
        for line in listing:
            print(line)
        if labels:
            print("\nlabels:")
            for k in sorted(labels, key=lambda k: labels[k]):
                print(f"  {labels[k]:08x}  {k}")

    if args.output:
        with open(args.output, "w") as f:
            f.write(f"// Generated by tools/rvasm.py from {args.source}\n")
            f.write("// One 32-bit instruction per line, for $readmemh.\n")
            f.write("// This is a SOURCE file: regenerate it and resynthesise.\n")
            for w in words:
                f.write(f"{w:08X}\n")
        print(f"{args.output}: {len(words)} instructions "
              f"({4*len(words)} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
