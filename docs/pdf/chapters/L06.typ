#import "../style.typ": *

= Lesson 06 — SPI and the OLED

#goals(
  concept: [A state machine that talks to a real chip, on that chip's terms.],
  build: [The SSD1331 colour OLED brought up from cold and filled with an animated gradient — with no framebuffer anywhere.],
  needs: [Lesson 05. A board, to see it.],
)[
  - Read a datasheet's timing requirements and turn them into clock counts.
  - Set up data before clocking it, and say why that ordering is universal.
  - Use a `busy`/`start` handshake to separate timing from sequencing.
  - Recognise when a design needs no frame buffer at all.
]

== The idea

Everything so far was self-contained: your logic, your clock, your decisions.
This is the first lesson where another piece of silicon has opinions, written
down in a datasheet, and your design must satisfy them.

The SSD1331 speaks 4-wire SPI. The contract is: you supply the clock, at no
more than about 6.6 MHz; data goes out most significant bit first; `D/C` is a
#emph[level] rather than a bit in the stream, saying whether this byte is a
command or pixel data; and `RES#` must be held low on power-up and then
released with a real delay before anything else.

#fig("/figures/spi-byte.svg",
     [One byte. Four system clocks per bit gives 25 MHz ÷ 4 = 6.25 MHz, inside
      the datasheet's limit.])

== Theory

=== Set up the data, then clock it

The four phases do distinct jobs: drive the data line on phase 0, raise the
clock on phase 2 so the data has been stable for two clocks before the chip
samples it, and advance the shift register on phase 3.

#why[
  "Set up the data, #emph[then] clock it" is the whole of synchronous interface
  design. The same reasoning sets the sample point in lesson 09's UART
  receiver, where the receiver cannot control the clock and must infer the
  safest moment to look. Phase 1 in this design does nothing at all, and that
  idleness is the setup time.
]

=== The handshake

```verilog
if (!busy && !start) begin ... end
```

`busy` is the entire interface between the bit-level engine and everything
above it. The sequencer that pushes initialisation bytes and pixel data obeys
one rule — do not touch `data` or raise `start` while `busy` is high — and
therefore needs to know #emph[nothing] about SPI timing.

That separation is why the same sequencer survives unchanged into lesson 07,
which replaces only the pixel function.

#watch[
  `start <= 0;` sits at the top of the sequencer's always block, before the
  case. That makes `start` a one-clock pulse by default which any branch may
  override. Forget it and `start` stays high, the engine re-triggers
  immediately, and you send one byte twenty-five million times a second.
]

=== No framebuffer

96 × 64 × 16 bits is 98,304 bits, which would fit in block RAM easily. It is
not needed, because the SSD1331's internal address pointer auto-increments: set
the column and row window once during initialisation, and every subsequent data
byte lands in the next pixel automatically.

So the design only has to produce bytes in raster order, and `x`/`y` counters
mirroring the chip's own pointer are enough. The pixel is #emph[computed] from
the coordinate the moment it is asked for:

```verilog
wire [15:0] pixel = { x[6:2], y[5:0], frame[7:3] };
```

#why[
  Recognising that a buffer is unnecessary is worth as much as knowing how to
  build one. Lesson 08 builds the framebuffer that lesson 15's software will
  need — but a design that can compute its output on demand should.
]

== What it cost

#measured("the whole display controller")[
  #ttable(
    columns: (auto, auto),
    [`LUT4`],       [108],
    [`TRELLIS_FF`], [72],
    [`CCU2C`],      [22],
    [`PFUMX`],      [29],
  )
  The 72 flip-flops are the shift register, the phase and bit counters, the
  state, the reset delay counter, and the x/y/frame counters. The 29
  multiplexers are mostly the 31-entry initialisation ROM, which the
  synthesiser built out of logic because it is far too small to be worth a
  block RAM — a decision lesson 08 examines properly.
]

== Testing an interface

The testbench decodes the SPI stream the way the OLED would: it samples the
data line on each rising clock edge, assembles bytes, checks the first 31
against the expected initialisation sequence with `D/C` low, then confirms
pixel data keeps arriving with `D/C` high.

#why[
  It reconstructs bytes #emph[from the wire] rather than peeking at internal
  signals, so it tests the contract the other chip cares about. A bit-order or
  clock-phase error that an internal check would miss fails here.

  But note the limit: a passing simulation does not prove the design meets a
  datasheet. Halve the clock divider and the simulation still passes while the
  hardware probably will not. When another chip's timing is involved,
  simulation is necessary and not sufficient.
]
