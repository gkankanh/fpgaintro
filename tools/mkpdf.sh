#!/usr/bin/env bash
# ===========================================================================
#  tools/mkpdf.sh — build the two course books.
#
#      docs/pdf/book.pdf    From Gates to a RISC-V CPU  — the concepts
#      docs/pdf/tools.pdf   Tools and Workflow          — install, build, deploy
#
#  They are split because they are consulted differently: one is read front to
#  back, the other is opened at the page you need. Both share style.typ, so
#  they look like one pair.
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
#      tools/mkpdf.sh            build both PDFs
#      tools/mkpdf.sh --watch    rebuild the course book on every save
#      tools/mkpdf.sh --watch tools    …or the tools book
# ===========================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v typst >/dev/null 2>&1; then
  cat <<'MSG'
mkpdf: typst is not installed, so the books cannot be typeset.

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
  exec typst watch "${2:-book}.typ" "${2:-book}.pdf"
fi

for doc in book tools; do
  typst compile "$doc.typ" "$doc.pdf"
  size=$(ls -lh "$doc.pdf" | awk '{print $5}')
  printf '    docs/pdf/%-9s %s\n' "$doc.pdf" "$size"
done
