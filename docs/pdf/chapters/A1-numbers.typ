#import "../style.typ": *

= Appendix A — Numbers that matter

Every measurement in this book, in one place. The lessons give the context and
the reasoning; this is for the reader who wants the shape of the costs without
the narrative, or who wants to check their own build against the course's.

All counts are `make synth` — `synth_ecp5` plus `stat`, not a placed design.
All frequencies are `make bit`, where `nextpnr` reports the routed design's
maximum for each clock. The exact toolchain versions are in
#emph[Tools and Workflow]; a different release can move a LUT4 count by a few
percent.

== The part

#ttable(
  columns: (auto, auto),
  [*resource on the 85F*], [*count*],
  [LUT4],         [83,640],
  [Flip-flops],   [83,640],
  [Block RAM `DP16KD`], [208 × 18 Kbit],
  [Multipliers `MULT18X18D`], [156],
  [PLLs `EHXPLLL`], [4],
  [Board clock],  [25 MHz],
)

== Whole designs, lesson by lesson

Each lesson's top module, as built — the figure that answers "how much of the
part did that take".

#ttable(
  breakable: true,
  columns: (auto, 1fr, auto, auto),
  [*lesson*], [*top module*], [*`LUT4`*], [*`TRELLIS_FF`*],
  [00], [`blink` — a 26-bit counter],              [1],     [26],
  [01], [`gates_top` — eleven outputs, no state],  [7],     [—],
  [02], [`comb_top`],                              [14],    [—],
  [03], [`seq_top`],                               [24],    [29],
  [04], [`clocks_top` — with a PLL],               [19],    [67],
  [05], [`fsm_top`],                               [75],    [113],
  [06], [`oled_top` — the display controller],     [108],   [72],
  [07], [`text_top` — font and coordinate math],   [185],   [72],
  [08], [`mem_top` — two block RAMs],              [80],    [61],
  [09], [`uart_top` — both halves],                [91],    [71],
  [12], [`decode_top`],                            [53],    [14],
  [13], [`cpu_top` — core, memories, board wiring],[1,268], [40],
  [15], [`soc_top` — the whole computer],          [4,821], [146],
  [16], [`cpu5` — the pipelined core],             [2,110], [414],
  [17], [`soc17_top` — with traps and M],          [3,866], [1,285],
)

Lessons 10 and 11 are modules rather than board designs, and lesson 14 proves
lessons 10 and 11 rather than building anything.

== The processor, part by part

#ttable(
  columns: (auto, 1fr, auto),
  [*lesson*], [*module*], [*`LUT4`*],
  [10], [`alu` — the whole thing],                      [885],
  [10], [`adder` — 32-bit addition (`CCU2C` only)],      [0 (17 `CCU2C`)],
  [10], [`shift_barrel` — single-cycle shifting],        [667],
  [10], [`shift_iterative` — the same shifts, 31 cycles],[76],
  [11], [`regfile` — combinational read, as RV32I needs],[266],
  [11], [`regfile_bram` — the same file, asking for BRAM],[214],
  [12], [`immgen` — the immediate generator],            [70],
  [12], [`decode` — the control decoder],                [45],
  [13], [`cpu` — the processor itself],                  [1,765],
  [15], [`memory` — 2 KB, two asynchronous read ports],  [2,756],
  [15], [`busdec` — the entire memory map],              [20],
  [15], [`mmio` — UART, LEDs, buttons, stopwatch],       [200],
  [16], [`memory_sync` — the same 2 KB, synchronous],    [121 (2 `DP16KD`)],
)

Two of those lines are the course's sharpest cost lessons. The barrel shifter
is 80% of the ALU — 667 LUT4 against the adder's 17 carry cells — because the
fabric has dedicated carry hardware and no dedicated shift hardware. And 2 KB
of memory costs 2,756 LUT4 when read asynchronously and 121 LUT4 plus two block
RAMs when read synchronously: the same capacity, a factor of twenty apart,
decided by one clock edge.

== Where the hand-built version lost

#ttable(
  columns: (1fr, auto, auto),
  [*the same function, two ways*], [*the expensive way*], [*the cheap way*],
  [32-bit adder (lesson 02)],       [138 `LUT4` + 74 mux], [17 `CCU2C`],
  [16-way decode as `case` vs. array (lesson 02)], [7 `LUT4`], [7 `LUT4`],
  [4-state FSM, one-hot vs. the tool's choice (lesson 05)], [41 `LUT4`], [11 `LUT4`],
  [Moore vs. Mealy sequence detector (lesson 05)], [5 `LUT4` (Mealy)], [2 `LUT4` (Moore)],
  [1 KB font ROM: logic vs. block RAM (lesson 08)], [9 `LUT4` (32 bytes)], [1 `DP16KD` (1 KB)],
)

== Maximum frequency

#ttable(
  columns: (1fr, auto, auto),
  [*design*], [*constraint*], [*achieved*],
  [32-bit ALU alone (lesson 10)],                [25 MHz], [115.94 MHz],
  [Single-cycle core, small memories (lesson 13)],[25 MHz], [61.24 MHz],
  [The same core as a computer (lesson 15)],      [25 MHz], [27.28 / 28.21 / 28.00 MHz],
  [— with 4 KB of memory instead of 2 KB],        [25 MHz], [25.14 / 24.44 / 24.40 MHz,
                                                             #strong[fails 2 runs in 3]],
  [— with 1 KB],                                  [25 MHz], [31.73 / 30.63 / 30.49 MHz],
  [Pipelined computer (lesson 16)],               [25 MHz], [49.48 / 47.52 / 45.74 MHz],
  [— as shipped, at its own PLL clock],           [40 MHz], [48.55 MHz],
  [With traps and M (lesson 17)],                 [35.7 MHz],[39.7 / 39.8 / 39.5 MHz],
  [— the same core asked for 40 MHz],             [40 MHz], [34.5 / 34.9 / 35.5 MHz,
                                                             #strong[fails all three]],
)

Three seeds, where three are given, because place-and-route is randomised and a
single run is not a measurement. Lesson 17's shipped 35.7 MHz is about 10%
below the best seed's result, which is the margin that makes the build
reproducible rather than lucky.

== What pipelining bought and cost

#ttable(
  columns: (1fr, auto, auto),
  [], [*lesson 15, single-cycle*], [*lesson 16, pipelined*],
  [clock],                         [28 MHz],  [45.7 MHz worst seed (1.63×)],
  [CPI, conformance program],      [1.000],   [1.358],
  [CPI, the C delay loop],         [1.000],   [1.99×],
  [`LUT4` (core only)],            [1,765],   [2,110],
  [`TRELLIS_FF` (core only)],      [32],      [414],
  [net effect],                    [—],       [one program 20% faster,
                                               the other 18% slower],
)

The delay loop is the worst case on purpose — every iteration is a load
immediately followed by its use, twice, and two taken branches. Pipelining buys
#emph[permission to raise the clock]; whether that is a win depends on the
code.

== Flip-flops, accounted for

Lesson 05 reports 113 flip-flops, and the whole of the course's method is that
they decompose exactly:

#ttable(
  columns: (1fr, auto),
  [one-second tick divider (25 bits)], [25],
  [traffic light: 2 state + 3 timer],  [5],
  [four debouncers],                   [76],
  [four edge detectors],               [4],
  [lock state],                        [3],
  [*total*],                           [*113*],
)

The state machines are 8 flip-flops out of 113. The rest is debouncing and
timekeeping — the plumbing needed to talk to the physical world. That ratio is
normal, and worth seeing once.
