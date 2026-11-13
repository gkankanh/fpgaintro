#import "style.typ": *

// ===========================================================================
//  From Gates to a RISC-V CPU — the course book.
//
//  Build:  tools/mkpdf.sh      (or: cd docs/pdf && typst compile book.typ)
// ===========================================================================

#let VERSION = "1.0"
#let BUILT   = datetime.today().display("[day] [month repr:long] [year]")

#set document(
  title: "From Gates to a RISC-V CPU",
  author: "The Open FPGA Course",
)

#set page(
  paper: "a4",
  margin: (inside: 26mm, outside: 20mm, top: 22mm, bottom: 22mm),
  numbering: "1",
  number-align: center,
)

#set text(font: ("Libertinus Serif",), size: 10.5pt, lang: "en", fill: ink)
#set par(justify: true, leading: 0.62em, first-line-indent: 0pt, spacing: 0.9em)

#show raw: set text(font: ("JetBrainsMono NFM", "DejaVu Sans Mono"), size: 9pt)
#show raw.where(block: true): it => block(
  width: 100%, fill: panel, inset: (x: 9pt, y: 8pt), radius: 3pt,
  stroke: 0.5pt + rule-col, breakable: true, it,
)

#show link: it => text(fill: accent, it)

#set heading(numbering: none)
#show heading.where(level: 1): it => {
  pagebreak(weak: true)
  block(above: 18pt, below: 14pt)[
    #set text(size: 21pt, weight: "bold")
    #it.body
  ]
}
#show heading.where(level: 2): it => block(above: 16pt, below: 7pt)[
  #set text(size: 13.5pt, weight: "bold"); #it.body
]
#show heading.where(level: 3): it => block(above: 12pt, below: 5pt)[
  #set text(size: 11pt, weight: "bold", fill: mute); #it.body
]

#show figure.caption: it => text(size: 9pt, fill: mute)[#it.body]

// =========================================================== title page ====
#page(numbering: none, margin: (x: 24mm, y: 30mm))[
  #v(44mm)
  #text(size: 32pt, weight: "bold")[From Gates to a\ RISC-V CPU]
  #v(6mm)
  #line(length: 58mm, stroke: 2pt + accent)
  #v(6mm)
  #text(size: 14pt, fill: mute)[
    Hands-on digital design on an FPGA,\
    with an open-source toolchain
  ]
  #v(10mm)
  #text(size: 10.5pt, fill: mute)[
    Eighteen lessons, 00–17, all built, tested and measured.\
    Every number in this book came out of the tools.
  ]
  #v(1fr)
  #text(size: 10pt, fill: mute)[
    Lattice ECP5 `LFE5U-85F` · Radiona ULX3S\
    Yosys · nextpnr · Project Trellis · Icarus Verilog · Verilator\
    #v(3mm)
    Version #VERSION · #BUILT
    #v(3mm)
    This book is licensed under Creative Commons Attribution 4.0
    International.\
    The accompanying code is licensed under the MIT License.\
    Copyright © 2026 The Open FPGA Course.
  ]
]

#set page(numbering: "i")
#counter(page).update(1)

#outline(depth: 2, indent: auto)

#set page(numbering: "1")
#counter(page).update(1)

#include "chapters/01-about.typ"
#include "chapters/02-fpga.typ"
#include "chapters/03-ulx3s.typ"
#include "chapters/04-credits.typ"
#include "chapters/05-install.typ"
#include "chapters/06-howto.typ"

#include "chapters/L00.typ"
#include "chapters/L01.typ"
#include "chapters/L02.typ"
#include "chapters/L03.typ"
#include "chapters/L04.typ"
#include "chapters/L05.typ"
#include "chapters/L06.typ"
#include "chapters/L07.typ"
#include "chapters/L08.typ"
#include "chapters/L09.typ"
#include "chapters/L10.typ"
#include "chapters/L11.typ"
#include "chapters/L12.typ"
#include "chapters/L13.typ"
#include "chapters/L13a-instruction.typ"
#include "chapters/L14.typ"
#include "chapters/L15.typ"
#include "chapters/L16.typ"
#include "chapters/L17.typ"

#include "chapters/A1-pinout.typ"
#include "chapters/A2-commands.typ"
#include "chapters/A3-style.typ"
#include "chapters/A4-reading.typ"
