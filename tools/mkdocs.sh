#!/usr/bin/env bash
# Build the lesson book.
#
# Single source of truth: each lesson's README.md lives beside its code, so it
# is readable on GitHub and offline. mdBook insists every page live under its
# src/ directory, so this script copies the lesson READMEs into
# docs/src/lessons/ and generates SUMMARY.md from the folder names. Nothing is
# authored in docs/src/lessons — it is regenerated and gitignored.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ACTION="${1:-build}"
OUT="docs/src/lessons"
rm -rf "$OUT"; mkdir -p "$OUT/diagrams"

# mdBook serves only what is under src/, while the diagrams live beside the
# lessons they belong to. Copy them in; the sed below repoints the links.
cp docs/diagrams/*.svg "$OUT/diagrams/" 2>/dev/null || true
cp [0-9][0-9]-*/diagrams/*.svg "$OUT/diagrams/" 2>/dev/null || true

cp CHEATSHEET.md docs/src/cheatsheet.md

SUMMARY="docs/src/SUMMARY.md"
{
  echo "# Summary"
  echo ""
  echo "[Introduction](./introduction.md)"
  echo "[Getting started](./getting-started.md)"
  echo "[Choosing your path: editor or Icestudio](./paths.md)"
  echo "[Cheat sheet](./cheatsheet.md)"
  echo ""
  echo "# Lessons"
  echo ""
} > "$SUMMARY"

for d in [0-9][0-9]-*; do
  [ -d "$d" ] || continue
  num="${d%%-*}"
  slug="${d#*-}"
  title="$(echo "$slug" | tr '-' ' ')"
  if [ -f "$d/README.md" ]; then
    # Three link fixups, because a lesson README is written to be read in the
    # repository and the site has a different shape:
    #   1. links to sibling source files are dropped, text kept -- the site
    #      has no copy of the Verilog to point at;
    #   2. diagrams move to lessons/diagrams/, copied in below;
    #   3. the reference pages sit one level up from lessons/.
    sed -E -e "s@\[([^]]*)\]\(\.\/[^)]*\)@\1@g" \
           -e "s@\]\(\.\./docs/diagrams/@](diagrams/@g" \
           -e "s@\]\(\.\./docs/src/@](../@g" \
        "$d/README.md" > "$OUT/$d.md"
    # Prefer the document's own H1 for the nav label.
    h1="$(grep -m1 '^# ' "$d/README.md" | sed 's/^# //')"
    echo "- [${h1:-$num — $title}](./lessons/$d.md)" >> "$SUMMARY"
  else
    echo "- [$num — $title]()" >> "$SUMMARY"   # drafted, not written yet
  fi
done

{
  echo ""
  echo "# Reference"
  echo ""
  echo "- [ULX3S board pinout](./reference-pinout.md)"
  echo "- [Toolchain cheat sheet](./reference-toolchain.md)"
  echo "- [Verilog style rules](./reference-style.md)"
} >> "$SUMMARY"

echo "generated $SUMMARY and $OUT/ ($(ls "$OUT"/*.md | wc -l | tr -d ' ') lessons)"

if ! command -v mdbook >/dev/null; then
  echo ""
  echo "mdbook is not installed, so the site was not built."
  echo "The Markdown is complete and readable as-is; to build the site:"
  echo "    brew install mdbook      # or: cargo install mdbook"
  exit 0
fi

cd docs
case "$ACTION" in
  build) mdbook build && echo "book built: docs/book/index.html" ;;
  serve) echo "serving on http://localhost:3000 (ctrl-c to stop)"; mdbook serve -p 3000 ;;
  *)     echo "usage: tools/mkdocs.sh [build|serve]"; exit 1 ;;
esac
