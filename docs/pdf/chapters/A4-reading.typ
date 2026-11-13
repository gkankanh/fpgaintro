#import "../style.typ": *

= Appendix D — Where to go next

== Specifications worth having open

#ttable(
  columns: (auto, 1fr),
  [#strong[The RISC-V ISA manual, volume 1]], [
    Unprivileged instructions. Free, readable, and short enough to actually
    read — which is unusual for an ISA specification and is part of why this
    course can end where it does.
  ],
  [#strong[The RISC-V ISA manual, volume 2]], [
    Privileged architecture: the CSRs, traps and the machine timer that
    lesson 17 is about.
  ],
  [#strong[Lattice ECP5 family datasheet]], [
    The authoritative numbers for the part: setup and hold times, block RAM
    configurations, PLL ranges.
  ],
  [#strong[SSD1331 datasheet]], [
    The display controller of lessons 06 and 07. Worth reading once as an
    example of the genre.
  ],
)

== Books

#ttable(
  columns: (auto, 1fr),
  [#strong[Patterson & Hennessy, #emph[Computer Organization and Design],
   RISC-V edition]], [
    The standard text, and the one this course's lessons 10 through 16 run
    parallel to. Where this book measures, that one explains — they complement
    each other well.
  ],
  [#strong[Harris & Harris, #emph[Digital Design and Computer Architecture]]], [
    Starts further back and covers the Verilog alongside the architecture.
    Closest in spirit to this course.
  ],
  [#strong[Nisan & Schocken, #emph[The Elements of Computing Systems]]], [
    The Nand2Tetris book. Builds a complete machine from NAND upward in
    simulation, and then a compiler and an operating system on top of it. A
    different and excellent answer to the same question.
  ],
)

== Projects to read

#ttable(
  columns: (auto, 1fr),
  [#strong[picorv32]], [
    A small, well-documented RV32I core by Claire Wolf. The natural next thing
    to read after finishing lesson 13 — a production-quality version of what
    you just built.
  ],
  [#strong[SERV]], [
    The world's smallest RISC-V core, by Olof Kindgren — bit-serial, around 200
    LUTs. A superb demonstration that "correct" and "fast" are independent
    axes.
  ],
  [#strong[VexRiscv]], [
    A configurable RV32 core generator. Shows what a pipeline, caches and an
    MMU look like at production scale.
  ],
  [#strong[LiteX]], [
    An SoC builder. Where you go when you want a CPU #emph[and] SDRAM,
    Ethernet, video and an SD card, without building all of them yourself.
  ],
  [#strong[The ULX3S examples]], [
    The ULX3S project's own repository — SDRAM controllers, video output, emulators of
    older machines. Written for this exact board.
  ],
)

== Things this course deliberately left out

Each would make a good next project:

+ #strong[An SDRAM controller.] The board has 32 MB of it, 16 bits wide, and it
  needs refresh, row activation and careful timing. The single hardest thing on
  this board, and the thing that turns a toy into a computer.
+ #strong[Digital video output.] Serialisation at ten times the pixel clock,
  which needs the PLL of lesson 04 used in anger.
+ #strong[Caches.] Lesson 16's pipeline makes memory the bottleneck; a cache is
  the answer, and cache coherence is where it gets genuinely hard.
+ #strong[A compiler back end.] Lesson 15 uses GCC. Targeting your own
  instruction set with LLVM is a large project and an education in why ISAs
  look the way they do.
+ #strong[Formal proof of the pipeline.] Lesson 14 proves the single-cycle
  core. Doing the same for lesson 16's pipelined version is strictly harder and
  strictly more valuable, because that is where the subtle bugs live.

== A closing thought

The most transferable thing in this course is not Verilog, and it is not
RISC-V. It is the habit of asking #emph[what did that actually cost] and then
running the two-second command that answers it.

Four times in these lessons, a rule that everyone knows turned out to be wrong
for the fabric in front of us — and in each case the measurement took less time
than arguing about it would have. That habit works on tools you have not met,
on chips that do not exist yet, and on problems that are not about hardware at
all.
