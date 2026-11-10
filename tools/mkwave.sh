#!/usr/bin/env bash
# ===========================================================================
#  tools/mkwave.sh — render timing diagrams from WaveDrom sources to SVG.
#
#  Timing diagrams are the single most useful picture in digital design, and
#  hand-drawing them in SVG is miserable. So each lesson keeps its diagrams as
#  WaveDrom JSON next to its code:
#
#      09-uart/diagrams/uart-frame.wave.json   ->   uart-frame.svg
#
#  The JSON is the source of truth and is committed; the SVG is generated and
#  gitignored, except where a lesson commits one deliberately (use -k).
#
#  WaveDrom is an npm package, fetched on demand with npx. That is a network
#  download the first time, so this is a separate explicit step rather than
#  something `make sim` does behind your back.
#
#      tools/mkwave.sh              # render every *.wave.json in the repo
#      tools/mkwave.sh path.json    # render one
# ===========================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v npx >/dev/null; then
  cat <<'MSG'
mkwave: npx (Node.js) not found, so timing diagrams cannot be rendered.

  macOS:  brew install node
  Linux:  your distro's nodejs package

The .wave.json sources are committed and readable, and every lesson also
describes its timing in prose and in its testbench, so nothing is lost by
skipping this step — you just will not see the pictures.
MSG
  exit 0
fi

if [ "$#" -gt 0 ]; then
  SRCS=("$@")
else
  # No globstar on macOS's bash 3.2, so use find.
  IFS=$'\n' read -r -d '' -a SRCS < <(find . -name '*.wave.json' \
      -not -path './toolchain/*' -not -path './node_modules/*' | sort && printf '\0')
fi

if [ "${#SRCS[@]}" -eq 0 ]; then
  echo "mkwave: no *.wave.json sources found"
  exit 0
fi

for src in "${SRCS[@]}"; do
  out="${src%.wave.json}.svg"
  printf '  %-54s -> %s\n' "$src" "$(basename "$out")"
  npx -y wavedrom-cli -i "$src" -s "$out"
done
echo "rendered ${#SRCS[@]} diagram(s)"
