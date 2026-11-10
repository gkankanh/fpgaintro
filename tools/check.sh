#!/usr/bin/env bash
# Verify the course toolchain is present and actually runs.
# Run this after tools/install.sh, or whenever something stops working.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/toolchain/oss-cad-suite/bin"
fail=0

ok()   { printf '  \033[32m✓\033[0m %-22s %s\n' "$1" "$2"; }
bad()  { printf '  \033[31m✗\033[0m %-22s %s\n' "$1" "$2"; fail=1; }
warn() { printf '  \033[33m-\033[0m %-22s %s\n' "$1" "$2"; }

echo "Toolchain in $BIN"
# These are required: no lesson works without them.
for t in iverilog vvp yosys nextpnr-ecp5 ecppack verilator gtkwave dot; do
  if [ ! -x "$BIN/$t" ]; then bad "$t" "MISSING — run tools/install.sh"; continue; fi
  # graphviz wants -V; everything else here understands --version.
  case "$t" in dot) vflag=-V ;; *) vflag=--version ;; esac
  ok "$t" "$("$BIN/$t" $vflag 2>&1 | head -1 | cut -c1-54)"
done

echo ""
echo "Optional (needed only by the lessons noted)"
for t in openFPGALoader fujprog; do
  [ -x "$BIN/$t" ] && ok "$t" "programming the board" || warn "$t" "board programming unavailable"
done
[ -x "$BIN/sby" ]  && ok "sby" "formal proofs (lesson 12)" || warn "sby" "lesson 12 needs SymbiYosys"
command -v mdbook >/dev/null && ok "mdbook" "$(mdbook --version)" || warn "mdbook" "docs site; 'make docs' needs it"
command -v node >/dev/null && ok "node" "$(node --version) — renders WaveDrom timing diagrams" || warn "node" "timing diagrams cannot be rendered"

for g in riscv64-unknown-elf-gcc riscv32-unknown-elf-gcc riscv64-elf-gcc riscv-none-elf-gcc; do
  if command -v "$g" >/dev/null; then ok "riscv cc" "$g (lesson 13 runs C)"; rv=1; break; fi
done
[ "${rv:-0}" = 1 ] || warn "riscv cc" "lesson 13 needs a RISC-V C compiler"

[ -d /Applications/icestudio.app ] || [ -d "$HOME/Applications/icestudio.app" ] \
  && ok "Icestudio" "visual path available" || warn "Icestudio" "visual lesson path unavailable"

echo ""
echo "Smoke test: lesson 00 simulation"
if out=$(cd "$ROOT/00-blinky" && make sim 2>&1); then
  echo "$out" | grep -q PASS && ok "make sim" "$(echo "$out" | grep PASS | head -1)" \
                             || bad "make sim" "ran but did not PASS"
else
  bad "make sim" "failed to run"
fi

echo ""
[ $fail -eq 0 ] && echo "Ready. Start at 00-blinky/README.md" \
               || { echo "Something is missing above. Run tools/install.sh."; exit 1; }
