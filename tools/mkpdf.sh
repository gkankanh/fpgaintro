#!/usr/bin/env bash
# ===========================================================================
#  tools/mkpdf.sh — build the course book.
#
#  Two steps, because they solve different problems:
#
#    1. FLATTEN THE DIAGRAMS. The course's SVGs are theme-aware, using CSS
#       custom properties and a prefers-color-scheme media query so one file
#       works on GitHub in both light and dark mode. Typst renders SVG through
#       resvg, which supports CSS selectors but NOT custom properties -- so
#       var(--ink) does not resolve, every fill falls back to black and strokes
#       vanish. Diagrams come out as solid black rectangles with invisible
#       labels. tools/svg-flatten.py resolves the variables and drops the dark
#       theme, producing print-ready copies in docs/pdf/figures/.
#
#    2. TYPESET. Typst embeds SVG as VECTOR graphics, so every figure in the
#       PDF is resolution-independent -- zoom to 1600% and the lines stay
#       sharp. That is why Typst rather than a Markdown-to-PDF converter, which
#       would rasterise.
#
#      tools/mkpdf.sh            build docs/pdf/book.pdf
#      tools/mkpdf.sh --watch    rebuild on every save, for writing
# ===========================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v typst >/dev/null 2>&1; then
  cat <<'MSG'
mkpdf: typst is not installed, so the book cannot be typeset.

    macOS:  brew install typst
    Linux:  see https://github.com/typst/typst/releases  (a single binary)
    any:    cargo install --locked typst-cli

Typst is used rather than LaTeX because it is one ~45 MB binary instead of a
multi-gigabyte distribution, and because it embeds SVG as vector graphics
rather than rasterising it.

The lessons themselves are readable without it: every chapter of the book
corresponds to a lesson README in the repository, and `make docs` builds an
HTML version.
MSG
  exit 1
fi

echo "==> flattening diagrams for print"
python3 tools/svg-flatten.py --all

echo ""
echo "==> typesetting"
cd docs/pdf
if [ "${1:-}" = "--watch" ]; then
  exec typst watch book.typ book.pdf
fi
typst compile book.typ book.pdf

pages=$(typst compile --format png --ppi 1 book.typ /tmp/_pp{0p}.png 2>/dev/null \
        && ls /tmp/_pp*.png 2>/dev/null | wc -l | tr -d ' ' || echo "?")
rm -f /tmp/_pp*.png
size=$(ls -lh book.pdf | awk '{print $5}')
echo ""
echo "    docs/pdf/book.pdf — ${pages} pages, ${size}"
