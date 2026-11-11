#!/usr/bin/env python3
"""
svg-flatten.py — turn theme-aware SVGs into print-ready ones.

Why this exists
---------------
The course diagrams are authored once and have to work in three places: on
GitHub in light mode, on GitHub in dark mode, and in the PDF. The first two are
handled by CSS custom properties plus a prefers-color-scheme media query:

    :root { --ink: #1f2328; }
    @media (prefers-color-scheme: dark) { :root { --ink: #e6edf3; } }
    .wire { stroke: var(--ink); }

The PDF is the problem. Typst renders SVG through resvg, which supports CSS
selectors but NOT custom properties -- `var(--ink)` does not resolve, every
fill falls back to black, and strokes disappear. Diagrams come out as solid
black rectangles with invisible labels. (Verified, not assumed.)

So this script resolves the variables itself: it reads the `:root` block,
substitutes every `var(--name)` with its literal value, and drops the dark-mode
media query. The originals stay theme-aware for the web; the flattened copies
are generated, print-only, and gitignored.

    tools/svg-flatten.py --all                    # every diagram -> docs/pdf/figures/
    tools/svg-flatten.py a.svg -o b.svg
"""
from __future__ import annotations

import argparse
import glob
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

# `--name: value;` inside a rule block.
VAR_DECL = re.compile(r"--([\w-]+)\s*:\s*([^;}]+)\s*;")
# A whole `@media ... { ... }` block, assuming one level of nesting inside.
MEDIA = re.compile(r"@media[^{]*\{(?:[^{}]*\{[^{}]*\}\s*)*[^{}]*\}", re.S)
VAR_USE = re.compile(r"var\(\s*--([\w-]+)\s*(?:,\s*([^)]*))?\)")


def flatten(svg: str) -> tuple[str, int, int]:
    """Return (flattened svg, variables resolved, media blocks removed)."""
    # 1. Collect the LIGHT theme values: the :root block that is not inside a
    #    media query. Take declarations before stripping, so the dark ones
    #    (inside @media) never enter the table.
    outside = MEDIA.sub("", svg)
    values = {m.group(1): m.group(2).strip() for m in VAR_DECL.finditer(outside)}

    # 2. Drop the dark-mode blocks entirely.
    svg, n_media = MEDIA.subn("", svg)

    # 3. Resolve var(--x) and var(--x, fallback), repeatedly in case a
    #    variable's value is itself a var().
    resolved = 0

    def sub(m: re.Match) -> str:
        nonlocal resolved
        name, fallback = m.group(1), m.group(2)
        if name in values:
            resolved += 1
            return values[name]
        if fallback is not None:
            resolved += 1
            return fallback.strip()
        print(f"  warning: --{name} has no value and no fallback",
              file=sys.stderr)
        return "currentColor"

    for _ in range(4):
        svg, n = VAR_USE.subn(sub, svg)
        if n == 0:
            break

    # 4. The custom-property declarations are now dead weight; remove them so
    #    the output is plain, portable SVG that any renderer handles.
    svg = VAR_DECL.sub("", svg)
    # Tidy the empty :root rule that usually remains.
    svg = re.sub(r":root\s*\{\s*\}", "", svg)

    return svg, resolved, n_media


def add_background(svg: str) -> str:
    """Insert a white background rect, so the figure is opaque on the page."""
    m = re.search(r"<svg[^>]*viewBox\s*=\s*\"([^\"]+)\"", svg)
    if not m:
        return svg
    x, y, w, h = (float(v) for v in m.group(1).replace(",", " ").split())
    rect = (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#ffffff"/>')
    end = svg.index(">", m.start()) + 1
    return svg[:end] + "\n  " + rect + svg[end:]


def process(src: str, dst: str) -> None:
    svg = open(src).read()
    svg, nvar, nmedia = flatten(svg)
    svg = add_background(svg)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(dst, "w") as f:
        f.write(svg)
    print(f"  {os.path.relpath(src, ROOT):52s} "
          f"{nvar:3d} vars, {nmedia} media block(s) dropped")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("source", nargs="?")
    ap.add_argument("-o", "--output")
    ap.add_argument("--all", action="store_true",
                    help="flatten every committed diagram into docs/pdf/figures/")
    args = ap.parse_args()

    if args.all:
        out = os.path.join(ROOT, "docs", "pdf", "figures")
        srcs = sorted(glob.glob(os.path.join(ROOT, "docs", "diagrams", "*.svg")) +
                      glob.glob(os.path.join(ROOT, "[0-9][0-9]-*", "diagrams", "*.svg")))
        if not srcs:
            print("svg-flatten: no diagrams found")
            return 1
        for s in srcs:
            process(s, os.path.join(out, os.path.basename(s)))
        print(f"\n{len(srcs)} figures -> {os.path.relpath(out, ROOT)}/")
        return 0

    if not args.source:
        ap.error("give a source file, or --all")
    process(args.source, args.output or args.source.replace(".svg", ".print.svg"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
