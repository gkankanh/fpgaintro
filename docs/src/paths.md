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

So each dual-path lesson keeps a short spec — `icestudio/<name>.json` — naming
the Verilog file to draw from and which board pin each port binds to.
`tools/mkice.py` reads that, lifts the module body out of the real `.v`, and
writes the `.ice`:

```bash
make ice      # regenerate every Icestudio project from its spec
```

The consequence is that the diagram and the Verilog cannot drift: the diagram
*is* the Verilog, laid out. Fix a bug in the `.v` and `make ice` propagates it.

And the reverse direction exists too. `make graph` runs your Verilog through
yosys and graphviz and hands you a schematic:

```bash
cd 02-combinational && make graph   # -> comb.svg
```

Which is worth doing on every lesson, at least once. Seeing what yosys inferred
from what you wrote is the fastest way to find the gap between what you meant
and what you said — an `always` block you thought was a register that became a
latch, a comparison you thought was 4 bits wide that became 32.

## Where the visual path stops

Lessons 10 onward are editor-only.

This is not an arbitrary cut-off, and it is worth understanding rather than
just accepting: schematic entry stops scaling at roughly the complexity of a
32-bit datapath. A 32-bit ALU drawn as blocks is a wall of 32 identical slices
you cannot read; expressed as Verilog it is a dozen lines with a `[31:0]` on
them. Parameterisation, loops and arithmetic on bit ranges are things text does
well and pictures do badly.

Industry made the same transition in the late 1980s, for the same reason.

Icestudio remains useful at the top level even then: wiring a finished core to
pins, clocks and resets is exactly the kind of structural, low-count
connectivity that pictures are good at.
