#import "../style.typ": *

= Lesson 09 — UART

#goals(
  concept: [Agreeing about time with a device you share no clock with.],
  build: [A transmitter, a receiver, and an echo server you can type into from a terminal.],
  needs: [Lesson 05, and lesson 04 for the synchroniser. A board — this is where the FPGA talks to your computer.],
)[
  - Explain why a start bit exists when there is no clock on the wire.
  - Compute a baud divisor and judge whether its error matters.
  - Decide where in a bit to sample, and why.
  - Explain why a framing error is not a reliable corruption detector.
]

== The idea

There is #strong[no clock on the wire]. Two chips, two crystals, one signal
line each way. Everything depends on both ends agreeing in advance how long a
bit lasts, and on one edge to say when to start counting.

That is the whole of 8N1: a start bit (the line falls from idle-high), eight
data bits least significant first, and a stop bit. Ten bit periods, no
handshake, no acknowledgement.

#fig("/figures/uart-sampling.svg",
     [An 8N1 frame, with the receiver sampling at the midpoint of every bit.])

=== Baud rate is a counter modulus

$ 25,000,000 / 115,200 = 217.0139 $

So the divisor is 217, giving 115,207 baud — #strong[0.0064% fast]. Over the
9.5 bit periods to the middle of the stop bit that accumulates to 0.06% of a
bit, which is nothing. Even 216 or 218 would be fine, at 4.5% of a bit.

== Where the textbook had to be overruled

Every UART reference says: build a clock at 16 times the baud rate and sample
on its eighth tick. That is how a 16550 works, because a 16550 is #emph[given]
a 16× baud clock. Here it does not work.

#measured("16× oversampling is unavailable on a 25 MHz crystal")[
  115,200 × 16 = 1,843,200 Hz, and 25,000,000 / 1,843,200 = 13.5634 — not an
  integer.
  #ttable(
    columns: (auto, auto, auto, auto),
    [*divisor*], [*baud*], [*error*], [*drift by the stop bit*],
    [13], [120,192], [+4.33%], [#strong[+41% of a bit]],
    [14], [111,607], [−3.12%], [#strong[−30% of a bit]],
  )
  Either way the stop bit gets sampled inside bit 7 and the frame is lost.
]

#why[
  The 16× clock is a good idea #emph[given a crystal chosen for it], and a bad
  idea given this one. So: count the bit period directly — which divides
  cleanly — and sample at the half-way point. Same underlying idea, which is to
  put the sample as far from both edges as possible, implemented to fit the
  clock you actually have.
]

The receiver re-checks the start bit at its own midpoint, which is what makes a
glitch harmless: a brief disturbance looks like a start bit for a few clocks,
and confirming it at the midpoint rejects it rather than reading eight bits of
noise.

#watch[
  The receive line comes straight from a pin, driven by #emph[another chip's
  oscillator]. It is asynchronous, so it goes through a two-flop synchroniser
  before anything looks at it. Lesson 04 exists for this moment, and this is
  the first lesson that genuinely needs it.
]

== The honest limit

A receiver must absorb some rate error, because two crystals never agree.
Driving frames at a range of rates against a correctly-configured receiver:

#measured("tolerance, and what lies beyond it")[
  #ttable(
    columns: (auto, auto),
    [*sender error*], [*result*],
    [+6.4% … −4.8%], [accepted, byte correct],
    [beyond that],   [#strong[accepted, byte WRONG, no framing error]],
  )
]

The out-of-tolerance frames are #emph[not rejected]. Far enough off, the
stop-bit sample lands somewhere inside the data, finds a 1 by chance, and the
frame passes its only check.

#why[
  #strong[A framing error is not a reliable corruption detector.] It catches
  many cases; it does not catch all of them. Detecting the rest is a
  #emph[protocol] job — a parity bit, or a checksum over a packet. Hardware
  that cannot distinguish "correct" from "plausible" needs software that can.
]

#found[
  The lesson's testbench originally asserted that mistimed frames were never
  silently corrupted — and passed. The sweep above disproves that claim. #strong[A
  test that asserts something false and passes is worse than no test], so it now
  asserts what is true and the tolerance window is documented with its numbers
  instead.
]

== What a loopback test does not prove

Running all 256 byte values through transmitter into receiver is worth having —
it finds bit-order and framing mistakes. But both ends share a clock and a
divisor, so it #strong[cannot find a timing problem], which is the entire
difficulty of a UART. The tolerance sweep is the test that does.

#found[
  A second testbench bug, worth knowing because the pattern recurs. The
  bit-period measurement asserted `start` and #emph[then] set up a wait for the
  line's falling edge. The edge had already happened, so it measured the next
  one — the five-zero run inside the letter `A` — and reported 40 clocks for an
  8-clock bit. The transmitter was correct; the test was looking in the wrong
  place. Measuring edges in a testbench needs `fork`/`join` so the monitor is
  already waiting before the stimulus starts.
]

== What it cost

#cost([`uart_top` — both halves, the echo and the LEDs],
      (LUT4: 91, TRELLIS_FF: 71, CCU2C: 8, PFUMX: 16, L6MUX21: 7),
      share: true)[]

#cost([`uart_tx` — the transmitter],
      (LUT4: 23, TRELLIS_FF: 22, CCU2C: 4, PFUMX: 1),
      cmd: "make synth M=uart_tx")[]

#cost([`uart_rx` — the receiver],
      (LUT4: 48, TRELLIS_FF: 33, CCU2C: 4, PFUMX: 9, L6MUX21: 4),
      cmd: "make synth M=uart_rx")[
  The receiver costs more than twice the transmitter. That is the resource
  footprint of not knowing when the bits start: the transmitter only has to
  count, while the receiver has to work out #emph[when to look].
]

#watch[
  The pin names are from the #strong[FTDI's] point of view. `ftdi_rxd` is where
  the FTDI #emph[receives], so the FPGA drives it; `ftdi_txd` is where the FTDI
  transmits, so the FPGA reads it. `output ftdi_rxd` and `input ftdi_txd` are
  correct and look backwards. This is the classic place to lose an afternoon.
]

== Wrap-up

#strong[What you built.] A UART transmitter and receiver that talk to a terminal over the same cable that programs the board — 23 LUT4 against the receiver's 48.

#strong[What to keep.] The receiver pays, in logic, for not knowing when the bits start.

#strong[What comes next.] Lesson 10 begins the processor. The UART comes back in lesson 15 as its console.
