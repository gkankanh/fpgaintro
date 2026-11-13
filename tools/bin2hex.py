#!/usr/bin/env python3
"""
bin2hex.py — turn a flat binary into the hex format $readmemh expects.

Why this exists
---------------
Lesson 15 compiles C with riscv-gcc and loads the result into the SoC's
memory. The chain is

    riscv64-elf-gcc  ->  .elf  ->  objcopy -O binary  ->  .bin  ->  .hex

and this is the last arrow. `$readmemh` wants one whitespace-separated hex
number per memory entry, and the entries here are 32-bit words, so the job is
to read four bytes at a time LITTLE-ENDIAN (RISC-V is) and print them as eight
hex digits.

    tools/bin2hex.py firmware.bin -o firmware.hex --words 1024

`--words` pads the output to the size of the memory array. Padding matters:
$readmemh leaves entries it was not given as X, and an X propagating out of an
uninitialised word is a simulation that fails in a way nobody can read. Zero is
a defined value, and it decodes to an illegal instruction, so a program that
runs off the end of its code stops at a reported illegal instruction rather
than executing noise.

The output is a SOURCE file as far as the hardware is concerned: $readmemh
reads it at elaboration (lesson 08), so changing the C means resynthesising.
"""
from __future__ import annotations

import argparse
import sys


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    ap.add_argument("binary", help="flat binary from objcopy -O binary")
    ap.add_argument("-o", "--output", help="hex file to write (default: stdout)")
    ap.add_argument("--words", type=int, default=0,
                    help="pad to this many 32-bit words")
    ap.add_argument("--annotate", action="store_true",
                    help="add a word-address comment every 8 words")
    args = ap.parse_args()

    with open(args.binary, "rb") as f:
        data = f.read()

    # A binary that is not a whole number of words is padded, not rejected:
    # the linker aligns sections to 4, but a final .rodata byte array need not
    # end on a word boundary.
    if len(data) % 4:
        data += b"\x00" * (4 - len(data) % 4)

    words = [int.from_bytes(data[i:i + 4], "little") for i in range(0, len(data), 4)]

    if args.words:
        if len(words) > args.words:
            print(f"bin2hex: {len(words)} words of program does not fit in "
                  f"{args.words} words of memory", file=sys.stderr)
            return 1
        words += [0] * (args.words - len(words))

    lines = []
    for i, w in enumerate(words):
        if args.annotate and i % 8 == 0:
            lines.append(f"// word {i:#06x}  byte {i * 4:#06x}")
        lines.append(f"{w:08x}")
    text = "\n".join(lines) + "\n"

    if args.output:
        with open(args.output, "w") as f:
            f.write(text)
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
