# Choosing your path: editor or Icestudio

Every lesson up to 09 can be done either way, and switching costs nothing.

## The editor path

You write Verilog in a text file. `make sim` runs it, `make wave` shows you the
waveform, `make bit` turns it into a bitstream.

This path scales. By lesson 10 you are describing a 32-bit ALU — about a
thousand gates — and by lesson 13 a whole CPU. Text is the only sane way to
express that, and text is what the rest of the industry uses.

## The visual path

You drag blocks onto a canvas in [Icestudio](https://icestudio.io) and wire
them together. Icestudio generates Verilog and builds it with
[apio](https://github.com/FPGAwars/apio), which wraps the same yosys and
nextpnr underneath — so you are not on a side track, you are driving the same
tools through a different front end.

This path is genuinely better for *seeing structure*. A multiplexer looks like
a multiplexer. A ripple-carry adder visibly ripples. When the question is "what
is actually connected to what", the picture wins.

The repository is already configured for the ULX3S-85F, so for a dual-path
lesson you can simply open the project and press Build:

```bash
open 00-blinky/icestudio/blink.ice
```

## How the two stay in sync

An Icestudio project is a JSON file: blocks, wires, and `basic.code` blocks
holding Verilog *bodies* (ports are declared on the block, not in a `module`
header).

So each lesson keeps a short spec — `icestudio/<name>.json` — naming the
Verilog file to draw from and which board pin each port binds to.
`tools/mkice.py` reads that, lifts the module body out of the real `.v`, and
writes the `.ice`:

```bash
make ice        # regenerate every Icestudio project from its spec
make icecheck   # compile-check all of them, without opening the GUI
```

The consequence is that the diagram and the Verilog cannot drift: the diagram
*is* the Verilog, laid out. Fix a bug in the `.v` and `make ice` propagates it.

**And the projects are checked.** There is no headless Icestudio, so
`tools/icecheck.py` reconstructs the module Icestudio's own compiler would
emit — the rule is short enough to reproduce exactly — and runs iverilog and
yosys over it. That is not a substitute for pressing Build on real hardware,
but it is the same two tools the editor path uses, and it caught four projects
in this repository that could not have built at all.

**One real limitation.** A code block holds a bare module body, so it cannot
instantiate other modules — Icestudio resolves blocks on its canvas, not
through a Verilog namespace. Generation therefore works from **leaf** modules.
A lesson whose top level wires several modules together (lesson 02's
`comb_top`, for instance) ships an `.ice` of one interesting leaf instead, and
`tools/mkice.py` refuses the hierarchical case with an explanation rather than
emitting a project that fails to build.

Composing blocks is what the canvas itself is for, and it is the better way
round: a module you have simulated and verified becomes a reusable block in
`icestudio/collections/`, and you wire it up visually.

And the reverse direction exists too. `make graph` runs your Verilog through
yosys and graphviz and hands you a schematic:

```bash
cd 02-combinational && make graph   # -> comb.svg
```

Which is worth doing on every lesson, at least once. Seeing what yosys inferred
from what you wrote is the fastest way to find the gap between what you meant
and what you said — an `always` block you thought was a register that became a
latch, a comparison you thought was 4 bits wide that became 32.

## Where the visual path changes character

Every lesson but 14 ships a project, but from lesson 10 they are a different
kind of thing, and the specs say so.

The reason is countable. Schematic *entry* stops scaling at roughly the
complexity of a 32-bit datapath: a 32-bit ALU drawn as blocks is a wall of 32
identical slices you cannot read, while as Verilog it is a dozen lines with a
`[31:0]` on them. Parameterisation, loops and arithmetic on bit ranges are
things text does well and pictures do badly. Industry made the same transition
in the late 1980s, for the same reason.

The board agrees, arithmetically. Lesson 12's decoder has 32 bits in and 27
bits of control out; the ULX3S offers 4 slide switches, 7 buttons and 8 LEDs.
You cannot bind 59 port bits to 19 pins, and the generator refuses to pretend
otherwise — it will not even let two port bits share one ball, because nextpnr
rejects the `.lpf` that comes out.

So from lesson 10 a project takes one of three honest shapes:

- a wide input becomes a **canvas constant** you edit and rebuild, which is a
  parameter in the generated Verilog;
- or it is **driven from the switches through one expression** in the spec —
  lesson 12 steps through eight real instructions that way, lesson 13
  sign-extends four switches into a 32-bit operand;
- and the interesting bits of a wide output reach the LEDs through a **probe**,
  while the rest are declared inside the block and left unconnected.

What you get is a working, buildable view of one leaf module with something to
turn, which is worth having. What you do not get is the datapath as a picture.
Those are different claims and the info panel on each canvas makes clear which
one it is making.

Lesson 14 is the one lesson with no project at all, and the reason is worth
knowing: every file in it is a property wrapper that instantiates the design
under proof. A code block cannot instantiate anything, and a proof is not a
bitstream.

Icestudio also remains useful at the top level: wiring a finished core to pins,
clocks and resets is exactly the kind of structural, low-count connectivity
that pictures are good at.
