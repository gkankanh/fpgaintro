#import "style.typ": *

// ===========================================================================
//  From Gates to a RISC-V CPU — the course book.
//
//  THE CONCEPTS ONLY. Installing the toolchain, the make verbs, programming
//  the board, the pinout and the command reference live in the companion
//  document, tools.typ, so that this one can be read rather than consulted.
//
//  Build:  tools/mkpdf.sh      (or: cd docs/pdf && typst compile book.typ)
// ===========================================================================

#let VERSION = "1.0"
#let BUILT   = datetime.today().display("[day] [month repr:long] [year]")

#set document(
  title: "From Gates to a RISC-V CPU",
  author: "The Open FPGA Course",
)

#show: preamble

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
    Setup, commands and the board's pinout: #emph[Tools and Workflow].
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

// Depth 1: one line per chapter, so the contents is a list of lessons you can
// run your finger down rather than four pages of subsections. Every heading is
// still a PDF bookmark, so a reader who wants "What it cost" in lesson 11 can
// jump straight to it from the viewer's outline pane.
#outline(depth: 1, indent: auto)

#set page(numbering: "1")
#counter(page).update(1)

#part("Part I", "The big picture", (
  ("The big picture", "A chip that becomes your circuit, and why Verilog is a description rather than a program"),
  ("The fabric, and what it costs", "Lookup tables, carry chains, the board, the chip, and the shape of the course"),
))[
  What an FPGA is, what the fabric is made of, and what "what it cost" means —
  the pages the rest of the book assumes. If you have written gateware for a
  living, start at Part II.
]

#include "chapters/B1-bigpicture.typ"
#include "chapters/B2-fabric.typ"

#part("Part II", "Digital logic", (
  ("Lesson 00 — Blinky", "A counter is a frequency divider, and every flip-flop is accounted for"),
  ("Lesson 01 — Logic gates", "What a LUT4 costs, and why minimising gate count stops mattering"),
  ("Lesson 02 — Combinational logic", "Multiplexers, decoders, and a hand-built adder against `+`"),
  ("Lesson 03 — Sequential logic", "Flip-flops, shift registers, debouncing, and `<=` against `=`"),
  ("Lesson 04 — Clocks and timing", "The critical path, a PLL, and crossing between clock domains"),
  ("Lesson 05 — Finite state machines", "The three-part form, Moore against Mealy, and encodings measured"),
))[
  Gates, combinational structures, clocked state, timing, and state machines.
  Ends with a synchronous controller you designed, simulated and ran on the
  board.
]

#include "chapters/L00.typ"
#include "chapters/L01.typ"
#include "chapters/L02.typ"
#include "chapters/L03.typ"
#include "chapters/L04.typ"
#include "chapters/L05.typ"

#part("Part III", "Interfaces and memory", (
  ("Lesson 06 — SPI and the OLED", "A state machine pointed at a datasheet, and what its test cannot prove"),
  ("Lesson 07 — Font ROM and coordinate maths", "Choosing constants so the arithmetic disappears"),
  ("Lesson 08 — Memories", "The one line that decides between a block RAM and 919 LUT4"),
  ("Lesson 09 — UART", "Sampling, framing, and a testbench that asserted something false"),
))[
  A display over SPI, a font ROM, the FPGA's own memories, and a UART. Ends
  with a small interactive system with a screen and a serial console.
]

#include "chapters/L06.typ"
#include "chapters/L07.typ"
#include "chapters/L08.typ"
#include "chapters/L09.typ"

#part("Part IV", "The processor", (
  ("Lesson 10 — The ALU", "Where the shifter turns out to be 80% of it, and exhaustive testing dies"),
  ("Lesson 11 — The register file", "Two read ports, one write port, and `x0`"),
  ("Lesson 12 — Decode and control", "Immediates that look like vandalism, and why they are not"),
  ("Lesson 13 — A single-cycle RV32I processor", "The core, running assembled programs — plus one instruction, end to end"),
))[
  The ALU, the register file, decode and immediates, then the single-cycle
  core. Ends with a program of your own running on the board, and one
  instruction followed through it end to end.
]

#include "chapters/L10.typ"
#include "chapters/L11.typ"
#include "chapters/L12.typ"
#include "chapters/L13.typ"
// Not a chapter of its own: one instruction walked through the machine lesson
// 13 just finished, so it belongs inside that lesson rather than beside it.
#include "chapters/L13a-instruction.typ"

#part("Part V", "Verification and extension", (
  ("Lesson 14 — Formal verification", "Proving the ALU rather than sampling it — and a proof that was worthless"),
  ("Lesson 15 — A system on chip", "A memory map, peripherals, and a program compiled by GCC"),
  ("Lesson 16 — Pipelining", "Five stages: what the clock buys, and what CPI costs"),
  ("Lesson 17 — CSRs, traps and the M extension", "A machine that reports an illegal instruction instead of halting"),
))[
  A formal proof of the ALU, a computer that runs compiled C, the same core
  pipelined and measured against the first, then CSRs, traps and a timer
  interrupt.
]

#include "chapters/L14.typ"
#include "chapters/L15.typ"
#include "chapters/L16.typ"
#include "chapters/L17.typ"

#part("Appendices", "Reference", (
  ("A — Numbers that matter", "Every count and every frequency in the book, in one set of tables"),
  ("B — Verilog style rules", "The conventions the lessons follow, and the mistake each one prevents"),
  ("C — Where to go next", "Specifications, books, cores worth reading, and what was left out"),
))[
  Every measurement in the book in one place, the style rules every lesson
  follows, and where to go next.
]

#include "chapters/A1-numbers.typ"
#include "chapters/A2-style.typ"
#include "chapters/A3-reading.typ"
