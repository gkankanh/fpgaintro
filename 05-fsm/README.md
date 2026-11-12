# Lesson 05 — finite state machines

**Concept:** encoding "where have I got to" as a register, with transitions as
combinational logic.

**You will build:** a traffic light, a pair of sequence detectors that
demonstrate Moore versus Mealy, and a combination lock that opens on a secret
button sequence.

**Needs the board:** yes — the lock is worth using

**Prerequisites:** lesson 04

**Paths:** editor + visual

**By the end you can:**

- Write an FSM in the canonical three-part form, and say why it is three parts.
- Choose between Moore and Mealy on the basis of what the consumer needs.
- Measure state encoding rather than inheriting a rule about it.
- Handle a wrong symbol in a sequence detector without losing a valid prefix.
- Test by transition coverage, since there is no input space to sweep.

---

## The idea

A state machine is the smallest useful idea in digital design that is not just
logic: a register holding *where you are*, and combinational logic deciding
*where you go next*.

That is all. Everything structural follows from it, and so does the shape every
FSM in this course takes:

1. **a state register** — one clocked block, containing nothing else
2. **next-state logic** — one combinational block, a pure function of state
   and inputs
3. **output logic** — from state (Moore), or state and inputs (Mealy)

Splitting (1) from (2) is not stylistic. It makes the only sequential element
trivially obvious, so the next-state block can be read as a plain truth table
and you never have to wonder what is registered.

> **Why this matters** — the SPI engine in lesson 06, the UART in lesson 09 and
> the CPU's control unit in lesson 13 are all this one pattern at increasing
> scale. The CPU is not a different kind of thing; it is a state machine whose
> state includes a program counter.

**Draw the diagram first.** On paper, before any Verilog: bubbles for states,
arrows labelled with the condition that takes them. The Verilog is then
transcription. Skipping this step is how you end up with a machine that has a
state you cannot reach and a transition you cannot explain.

## The traffic light — [`traffic.v`](./traffic.v)

Four states in a fixed cycle, each lasting a set number of ticks.

```verilog
localparam [1:0] S_RED = 2'd0, S_RED_AMBER = 2'd1,
                 S_GREEN = 2'd2, S_AMBER = 2'd3;
```

Named constants, never bare numbers in the `case`. `2'd2` tells a reader
nothing; `S_GREEN` tells them everything.

The next-state block opens by assigning a default:

```verilog
always @(*) begin
    next = state;             // stay put unless something says otherwise
    if (expired)
        case (state)
            S_RED:   next = S_RED_AMBER;
            ...
            default: next = S_RED;
        endcase
end
```

> **Watch out** — that first line is doing two jobs. It expresses "stay in this
> state", and it guarantees every path assigns `next`, so no latch can be
> inferred (lesson 02's trap). Writing the default first, then overriding, is
> the habit; it makes the latch impossible rather than merely absent.
>
> The `default:` inside the `case` is the same discipline one level down. Here
> all four states are covered so it can never fire — which is exactly when
> people leave it out, and exactly when a future fifth state will bite.

Timing comes from a **tick enable**, not a divided clock — lesson 04's rule.
The FSM advances only when `tick` pulses, so the same machine runs at one
second per state on hardware and at whatever rate the testbench likes.

## Moore versus Mealy — [`lock.v`](./lock.v)

Two machines that detect the same sequence (`1, 0, 1`), differing only in where
the output comes from.

```verilog
// Moore — from state alone. Four states; the fourth exists to produce output.
assign found = (state == S_101);

// Mealy — from state AND input. Three states; output on the transition.
assign found = (state == S_10) && d;
```

| | Moore | Mealy |
|---|---|---|
| output depends on | state | state **and** input |
| states needed | 4 | 3 |
| timing | one clock **late** | **immediate** |
| output is | registered, glitch-free | combinational, inherits input glitches |

The testbench checks the timing difference directly: with the final `1`
present, the Mealy output is already asserted and the Moore output is not; one
clock later, Moore asserts.

Neither is correct in general. The question is whether the consumer needs the
answer *now* or needs it *clean*. A Mealy output feeding another FSM's
next-state logic in the same cycle is a combinational path between two state
machines — occasionally what you want, frequently a timing problem.

And then the measurement, which does not say what the textbook says:

| module | cost |
|---|---|
| `seq_moore` | 2 `LUT4`, 2 `TRELLIS_FF` |
| `seq_mealy` | **5 `LUT4`**, 2 `TRELLIS_FF` |

Mealy has **fewer states** and costs **more logic**. The state saving buys
nothing, because 3 states and 4 states both fit in two flip-flops, while making
the output depend on the input adds real gates. The textbook trade is real on
an ASIC where you count flops; here flops come free with the LUTs.

## State encoding, measured

How states map to bits is a choice. **Binary** uses ⌈log₂N⌉ flip-flops and
needs a decoder to answer "which state am I in". **One-hot** uses N flip-flops
with exactly one high, so that question becomes a single wire.

In Verilog you express it with an attribute on the state register — not on the
module, where it does nothing:

```verilog
(* fsm_encoding = "one-hot" *) reg [1:0] state = S_RED;
```

Without it, yosys's `fsm` pass re-encodes as it sees fit, so the constants you
wrote are a suggestion rather than an instruction.

For the traffic light:

| encoding | cost |
|---|---|
| *(yosys's choice)* | 11 `LUT4`, 3 `PFUMX`, 5 `TRELLIS_FF` |
| `"binary"` | 12 `LUT4`, 3 `PFUMX`, 5 `TRELLIS_FF` |
| `"none"` (keep mine) | 11 `LUT4`, 3 `PFUMX`, 5 `TRELLIS_FF` |
| `"one-hot"` | **41 `LUT4`**, 18 `PFUMX`, 12 `L6MUX21`, 7 `TRELLIS_FF` |

One-hot is nearly four times worse. The conventional advice — "one-hot is
usually better on an FPGA, since flops are free" — is wrong *for this machine*,
because four states is too few for the decode saving to materialise, while
every comparison against the state now has to be built from four bits instead
of two. One-hot earns its keep on wide state machines, not narrow ones.

> **Why this matters more than the numbers** — that is twice in two lessons
> that a received rule did not survive measurement (lesson 04: you cannot read
> your critical path off your source). The method is the content: `make synth`
> takes two seconds, and it outranks anything anyone tells you about what
> *usually* costs less.

## The lock, and the mistake everyone makes

The deliverable is a lock opening on the sequence **1, 2, 1, 3**. The states
are easy. The interesting question is: **what happens on a wrong symbol?**

The obvious answer — go back to the start — is wrong. Enter `1, 2, 1, 2`:
after `1, 2, 1` the machine wants `3` and gets `2`. But the last two symbols it
saw were `1, 2`, which is a valid *prefix* of the code. Restarting throws that
away, and the lock then refuses `1, 2, 1, 2, 1, 3` even though the correct code
is right there at the end.

```verilog
S_3: next = (code == C3) ? S_OPEN :
            (code == C1) ? S_2 :      // "1,2" survives as a prefix
            (code == C0) ? S_1 : S_0;
```

Every state needs this treatment: on a wrong symbol, fall back to the longest
suffix of what you have seen that is still a prefix of the code. Doing it by
hand is fiddly and easy to get subtly wrong — it is precisely what the KMP
string-matching algorithm automates, and precisely the class of bug lesson 14's
formal tools find for you without being asked.

The testbench checks it explicitly, because it is the one case a casual test
would miss.

## Simulate it

```bash
cd 05-fsm
make sim
```

```
PASS: traffic sequence and durations correct, mealy leads moore by one clock,
lock keeps a valid prefix after a wrong symbol
```

**Testing an FSM is different from everything before it.** There is no input
space to sweep: the input is a *sequence*, so the test is a set of chosen
journeys through the state graph. The useful discipline is **coverage** — has
every arrow in your diagram been taken at least once? The traffic light test
walks the full cycle for exactly that reason, and then holds the clock running
with no ticks to confirm the machine does not advance without its enable.

The lock tests four journeys: the correct code, a wrong code, a three-symbol
prefix (must not open), and the prefix-preservation case.

```bash
make wave
```

Add `state` to the viewer as a single bus and read it as a trace of the journey
— that view is why FSMs are pleasant to debug.

## What it cost

`fsm_top` — the whole design:

```bash
make synth
```

| resource | count |
|---|---:|
| `LUT4` | 75 |
| `TRELLIS_FF` | 113 |
| `CCU2C` | 49 |
| `PFUMX` | 12 |
| `L6MUX21` | 3 |

75 of the 85F's 83,640 LUT4 — 0.09% of the part.

113 flip-flops, all accountable:

| | flip-flops |
|---|---|
| one-second tick divider (25 bits) | 25 |
| traffic: 2 state + 3 timer | 5 |
| four debouncers: 18-bit counter + `clean` each | 76 |
| four edge detectors | 4 |
| lock state | 3 |
| **total** | **113** |

And the 49 CCU2C are the counters: 13 for the 25-bit divider plus 9 each for
the four 18-bit debounce counters.

Note the proportion. **The state machines are 8 flip-flops out of 113.** The
rest is debouncing and timekeeping — the plumbing needed to talk to the
physical world. That ratio is normal, and it is worth seeing once: the
interesting logic is usually a small fraction of a real design.

## On the board

```bash
make prog
```

- `led[2:0]` — the traffic light, one second per state
- `led[6:4]` — the lock's state, exposed so you can watch it
- `led[7]` — unlocked
- `btn[1..4]` — enter symbols 0–3. **The code is 1, 2, 1, 3**, i.e.
  `btn[2]`, `btn[3]`, `btn[2]`, `btn[4]`
- `btn[5]` — reset the lock

The thing to actually try: enter `1, 2, 1` and watch the state reach 3. Now
press `btn[3]` (symbol 2) — a *wrong* symbol — and watch the state fall to **2,
not 0**. That is the prefix being preserved, visible on LEDs. Then press
`btn[2]`, `btn[4]` and it opens.

The debouncers come from [`common/rtl/`](../common/rtl/). Lesson 03 built them;
this lesson is the second user, which is what moved them there.

## Icestudio

```bash
open 05-fsm/icestudio/traffic.ice
```

The traffic light as a block. The state diagram is still something you draw on
paper — Icestudio shows you the module's *interface*, not its state graph,
which is a fair reminder that block diagrams and state diagrams answer
different questions.

## Exercises

1. **Force the encoding.** Add `(* fsm_encoding = "one-hot" *)` to `traffic`'s
   state register and run `make synth`. Reproduce the table above. Then add a
   fifth and sixth state and see whether the gap narrows.
2. **Infer a latch.** Delete `next = state;` from the top of the traffic
   light's combinational block. `make sim` may still pass. `make lint` will
   not — read what verilator says.
3. **Break the prefix logic.** Change the lock's `S_3` so a wrong symbol always
   returns to `S_0`. Which of the four lock tests fails? Then find the shortest
   button sequence that the broken lock refuses but the correct one accepts.
4. **Make the lock Mealy.** Assert `unlocked` combinationally on the final
   correct press rather than from a state. Does a state disappear? What does
   `make synth` say, and would you ship it?
5. **Add a pedestrian request.** A button that, when pressed during `S_GREEN`,
   shortens the green phase. Draw the modified state diagram first, then
   implement it, then extend the testbench to cover the new transitions.

## Wrap-up

**What you built.** A traffic light, a Moore and a Mealy sequence detector, and a combination lock — 113 flip-flops, of which the state machines are eight.

**What to keep.** Encodings are measured, not inherited: one-hot cost four times binary here.

**What comes next.** Lesson 06 points an FSM at a real peripheral, whose datasheet decides what the states have to be.
