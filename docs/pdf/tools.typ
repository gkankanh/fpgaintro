#import "style.typ": *

// ===========================================================================
//  Tools and Workflow — the companion volume to "From Gates to a RISC-V CPU".
//
//  Everything operational lives here: installing the toolchain, the make
//  verbs, getting a bitstream onto the board, the pinout, and the exact
//  commands behind every number in the course book. The book itself is then
//  free to be about the concepts, which is the only reason this document
//  exists as a separate file rather than six chapters of front matter nobody
//  reads twice.
//
//  Build:  tools/mkpdf.sh      (or: cd docs/pdf && typst compile tools.typ)
// ===========================================================================

#let VERSION = "1.0"
#let BUILT   = datetime.today().display("[day] [month repr:long] [year]")

#set document(
  title: "Tools and Workflow — The Open FPGA Course",
  author: "The Open FPGA Course",
)

#show: preamble

// =========================================================== title page ====
#page(numbering: none, margin: (x: 24mm, y: 30mm))[
  #v(44mm)
  #text(size: 32pt, weight: "bold")[Tools and\ Workflow]
  #v(6mm)
  #line(length: 58mm, stroke: 2pt + accent)
  #v(6mm)
  #text(size: 14pt, fill: mute)[
    Installing the toolchain, building a lesson,\
    and putting it on the board
  ]
  #v(10mm)
  #text(size: 10.5pt, fill: mute)[
    The companion to #emph[From Gates to a RISC-V CPU].\
    That book explains the circuits; this one runs them.
  ]
  #v(1fr)
  #text(size: 10pt, fill: mute)[
    Lattice ECP5 `LFE5U-85F` · Radiona ULX3S\
    Yosys · nextpnr · Project Trellis · Icarus Verilog · Verilator\
    #v(3mm)
    Version #VERSION · #BUILT
    #v(3mm)
    This document is licensed under Creative Commons Attribution 4.0
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

#include "chapters/T1-install.typ"
#include "chapters/T2-toolchain.typ"
#include "chapters/T3-running.typ"
#include "chapters/T4-board.typ"
#include "chapters/T5-pinout.typ"
#include "chapters/T6-reference.typ"
