#!/usr/bin/env bash
# ===========================================================================
#  Cross-validate tools/rvasm.py against the GNU assembler.
#
#  rvasm.py is a 400-line assembler written for this course, and it agrees
#  with lesson 12's independently-derived encodings on every instruction they
#  share. That is cross-validation between two of my own implementations,
#  which is worth something but is not the same as agreeing with the
#  reference.
#
#  So: when the GNU RISC-V toolchain is installed -- which lesson 15 needs
#  anyway for compiling C -- assemble the same source both ways and compare.
#
#      tools/check-asm.sh 13-rv32i-single/test.s
#
#  Install the toolchain with:  tools/install.sh --with-riscv
# ===========================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-$ROOT/13-rv32i-single/test.s}"

AS=""; OBJCOPY=""
for p in riscv64-unknown-elf riscv32-unknown-elf riscv64-elf riscv-none-elf; do
  if command -v "$p-as" >/dev/null 2>&1; then AS="$p-as"; OBJCOPY="$p-objcopy"; break; fi
done

if [ -z "$AS" ]; then
  cat <<'MSG'
check-asm: no GNU RISC-V assembler found, so no cross-validation was done.

  rvasm.py is still self-consistent and agrees with lesson 12's
  independently-derived encodings -- but "agrees with the reference" is a
  stronger claim, and this is how to earn it:

      tools/install.sh --with-riscv
      tools/check-asm.sh

  Lesson 15 needs the toolchain regardless, for compiling C.
MSG
  exit 0
fi

echo "Comparing tools/rvasm.py against $AS"
echo "  source: $SRC"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Ours.
python3 "$ROOT/tools/rvasm.py" "$SRC" -o "$TMP/ours.hex" >/dev/null || exit 1
grep -v '^//' "$TMP/ours.hex" | tr 'a-f' 'A-F' > "$TMP/ours.txt"

# Theirs. -march=rv32i so no compressed instructions appear.
"$AS" -march=rv32i -mabi=ilp32 -o "$TMP/t.o" "$SRC" || {
  echo "  $AS rejected the source; the two assemblers may differ on syntax"
  exit 1; }
"$OBJCOPY" -O binary "$TMP/t.o" "$TMP/t.bin" || exit 1
python3 - "$TMP/t.bin" > "$TMP/theirs.txt" <<'PY'
import sys, struct
d = open(sys.argv[1], 'rb').read()
for i in range(0, len(d) - 3, 4):
    print(f"{struct.unpack('<I', d[i:i+4])[0]:08X}")
PY

if diff -q "$TMP/ours.txt" "$TMP/theirs.txt" >/dev/null; then
  n=$(wc -l < "$TMP/ours.txt" | tr -d ' ')
  echo "  IDENTICAL: $n instructions, byte for byte"
else
  echo "  DIFFERENCES (ours | theirs):"
  diff -y --width=40 "$TMP/ours.txt" "$TMP/theirs.txt" | grep -E '[|<>]' | head -20
  echo ""
  echo "  Note: a difference is not automatically rvasm's fault -- GNU as"
  echo "  relaxes some pseudo-instructions differently (li in particular)."
  echo "  Compare the listings before concluding anything:"
  echo "      python3 tools/rvasm.py $SRC --list"
  exit 1
fi
