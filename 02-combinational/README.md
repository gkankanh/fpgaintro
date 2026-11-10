# Lesson 02 — combinational logic

**Concept:** gates assembled into the three structures everything else is made
of — muxes, decoders, adders — and the last chance to test every possible
input.

**You will build:** a 7-segment hex decoder and a 4-bit adder, both verified
exhaustively, wired together on the board by a multiplexer.

**Needs the board:** no (there is a demo if you have one)

**Prerequisites:** lesson 01

**Paths:** editor + visual

---

## The idea

Lesson 01 was single gates. Real designs are not built from gates any more than
prose is built from letters — they are built from a small number of recurring
structures. Three of them account for most of a CPU:

**The multiplexer** selects. One of several inputs reaches the output, chosen by
a select signal. Every point in a datapath where a value "comes from here, or
from there" is a mux, and lesson 13's CPU is mostly muxes with arithmetic
between them.

**The decoder** is the mux's mirror image: one input number, and exactly one of
2ⁿ outputs goes high. Wherever a number has to become a *choice* — instruction
decode, address decode, chip select, one-hot state — there is a decoder.

**The adder** is the first structure with an interesting internal shape, because
each bit's result depends on a carry from the bit below. That dependency is the
reason addition takes *time*, and it is the thing that will set your clock
frequency in lesson 10.

All three are combinational: no clock, no memory, output a pure function of
input. Which has a lovely consequence — a 4-bit adder has 2⁴ × 2⁴ × 2 = 512
possible inputs, and you can simply test all of them.

> **Why this matters** — this is the last lesson in the course where exhaustive
> testing is a strategy rather than a wish. The counts go 4, then 16, then 512.
> A 32-bit adder would be 2⁶⁵ cases. Lesson 10 has to test by randomised
> comparison against a model, and lesson 14 exists because even that is not
> enough. Enjoy certainty while it is affordable.

## The design

Four files, grouped by concept rather than one module per file.

### Muxes and decoders — [`mux.v`](./mux.v)

```verilog
module mux2 #(parameter W = 1) (
    input wire [W-1:0] d0, d1, input wire sel, output wire [W-1:0] y);
    assign y = sel ? d1 : d0;
endmodule
```

Parameterised by width, because a mux does not care what it is selecting
between. Written once at `W` bits, instantiated at 7 in the board demo — that
is what parameters are for.

The decoder has a trap in it worth the whole file:

```verilog
localparam M = 1 << N;
assign y = { {(M-1){1'b0}}, 1'b1 } << sel;
```

> **Watch out** — in Verilog, the result of `a << b` is **as wide as `a`**. So
> `assign y = 1'b1 << sel;` shifts a one-bit value, everything falls off the
> end, and `y` is always zero. The literal must be widened to `M` bits *before*
> it is shifted, which is what that concatenation does. This class of bug —
> silent truncation from an operand's width — is the most common way Verilog
> betrays you, and it does not announce itself.

### The hex decoder — [`seg7.v`](./seg7.v)

The same truth table written two ways: a `case` statement, and a ROM array
indexed by the digit. The testbench checks both against expected patterns *and*
against each other.

```verilog
default: seg = 7'b0000000;
```

> **Watch out** — all 16 cases are covered, so that `default` can never fire.
> It is there anyway, because a combinational `always` block that fails to
> assign its output on some path infers a **latch**: a storage element with no
> clock. Make the default a reflex.

### Addition — [`adder4.v`](./adder4.v)

One bit of addition is two gates' worth of logic:

```verilog
assign s    = a ^ b ^ cin;                 // odd number of ones
assign cout = (a & b) | (cin & (a ^ b));   // at least two ones
```

Four of those chained, with `generate` stamping out the copies:

```verilog
wire [4:0] c;
assign c[0] = cin;
genvar i;
generate
    for (i = 0; i < 4; i = i + 1) begin : stage
        full_adder fa (.a(a[i]), .b(b[i]), .cin(c[i]),
                       .s(s[i]), .cout(c[i+1]));
    end
endgenerate
```

`generate` is a compile-time loop. It does not run; it stamps out four
instances. The same four lines produce a 32-bit adder by changing one number.

And then the version you would actually write:

```verilog
wire [4:0] sum = a + b + cin;      // 5 bits, so the carry survives
```

> **Watch out** — `a + b + cin` assigned to a 4-bit destination throws the carry
> away silently. Widening the intermediate to 5 bits is what keeps it. Same
> family of bug as the shift above: in Verilog, width is part of the meaning.

## Simulate it

```bash
cd 02-combinational
make sim
```

```
PASS: 1572 checks, all exhaustive
```

Four complete sweeps: 4 decoder cases checked one-hot, 16 digits through both
decoder implementations, all 512 adder combinations against a 5-bit computed
reference *and* ripple-against-behavioural, and all 512 mux combinations.

Note how the reference is computed:

```verilog
want = {1'b0, a} + {1'b0, b} + {4'b0, cin};
```

Explicitly widened, so the reference cannot inherit the same truncation bug it
is supposed to catch. A reference model that shares your mistake proves
nothing.

## What it cost

This is where the lesson earns its keep. Measured with `make synth` on each
module separately:

| module | cost |
|---|---|
| `full_adder` | 2 LUT4 |
| `adder4_ripple` — built by hand from gates | 24 LUT4 + 10 PFUMX + 7 L6MUX21 |
| `adder4_behav` — just `a + b + cin` | **3 CCU2C** |
| `seg7` — case statement | 7 LUT4 |
| `seg7_rom` — ROM array | 7 LUT4 |
| `mux2` at W=1 | 1 LUT4 |
| `mux4` at W=1 | 4 LUT4 + 2 PFUMX + 1 L6MUX21 |
| `dec` at N=2 | 4 LUT4 |

Three things to take from that table.

**The two hex decoders cost exactly the same.** Seven LUT4s each. One is a
`case` statement and one is an array of constants, and the synthesiser cannot
tell the difference, because there is no difference — both describe the same
function of four inputs. A `case` is not "logic" and an array is not "memory".
Lesson 01's point, one level up.

**The hand-built adder is roughly eight times more expensive than `+`.** Not
slightly: 41 cells against 3. And the reason is specific — look at what is
*absent* from the ripple adder's row. There are no `CCU2C` cells.

`CCU2C` is the ECP5's dedicated carry logic, a purpose-built adder running up
each column of the fabric, and it is nearly free (lesson 00 met it: a 26-bit
counter cost 13 of them and one LUT). When you write `a + b`, yosys recognises
addition and maps straight onto it. When you write the same function as
explicit gates, yosys sees gate soup — it cannot prove that pile of XORs and
ANDs is an adder, so it cannot use the carry chain, and ABC restructures the
logic for shallow depth using the ECP5's wide-mux resources. More cells, and a
longer critical path.

**So the two lessons point in opposite directions, and both are true.** In
lesson 01 the synthesiser discarded your structure and kept only the function.
Here it kept your structure, because your structure prevented it from
recognising the function. The rule underneath both: *write what you mean, at
the highest level you can, and let the tool match it to the hardware.* Build
the ripple adder once to understand what a carry is. Then write `+` forever.

```bash
make graph      # -> comb_top.svg
```

Worth comparing the two adders' schematics side by side.

## On the board

```bash
make prog
```

- `sw[3:0]` — the hex digit, and the adder's `a`
- `btn[4:1]` — the adder's `b` (hold them)
- `btn[5]` — carry in
- `btn[6]` — display select: **released** shows the seven segment bits on
  `led[6:0]`, **pressed** shows `{carry, sum}` on `led[4:0]`
- `led[7]` — which mode you are in

Set the switches to `1010` and read `led[6:0]` as segments `abcdefg`: you should
get `1110111`, which is the letter A.

The buttons are not debounced and do not need to be — bounce on a combinational
input makes an LED flicker, not an answer wrong. That stops being true the
moment something is clocked, which is lesson 03.

## Icestudio

```bash
open 02-combinational/icestudio/seg7.ice
```

The hex decoder as a block: four switch inputs, seven segment outputs, and the
16-way `case` inside. Set the switches and read the pattern.

Note what is *not* here: `comb_top`, which wires the decoder, the adder and the
mux together. An Icestudio code block holds a bare module body and cannot
instantiate other modules — Icestudio resolves blocks on the canvas, not
through a Verilog namespace. So the visual path generates from **leaf** modules,
and composing them is Icestudio's own job: you would make `seg7` a reusable
block in `icestudio/collections/` and wire it up by hand.

`tools/mkice.py` refuses to generate from a hierarchical module rather than
producing a project that fails to build, so you will get a clear error rather
than a puzzle.

## Exercises

Predictions first — each of these is more useful if you work out what will
happen before you run it.

1. **Break the shift.** Change the decoder to `assign y = 1'b1 << sel;` and run
   `make sim`. Predict the failure before you look.
2. **Lose the carry.** Change `adder4_behav` to `wire [3:0] sum = a + b + cin;`
   and assign `cout = 1'b0`. How many of the 512 cases fail, and can you say
   which ones without running it?
3. **Infer a latch.** Delete the `default` from `seg7` *and* one of the sixteen
   cases. `make sim` still passes. `make lint` does not — read what verilator
   says, then look at `make graph` and find the latch.
4. **Scale the ripple.** Make `adder4_ripple` 16 bits by changing the loop
   bound and the port widths. Compare its cost to a 16-bit `a + b`. The ratio
   gets worse — why?
5. **Build mux4 from mux2.** Instantiate three `mux2`s in a tree instead of
   using nested conditionals. Does it cost the same? (It should. Why is this
   case different from exercise 4's adder?)

## What you should now be able to explain

- Why a mux and a decoder are mirror images, and where each appears in a CPU.
- Why `1'b1 << sel` is always zero, and the general rule behind it.
- Why a `case` statement and a ROM array cost the same.
- Why the hand-built adder costs 8× what `+` does, in terms of what yosys can
  and cannot recognise.
- Why combinational `always` blocks need a `default`.
- Why 512 test cases is exhaustive here and hopeless by lesson 10.

**Next:** [lesson 03 — sequential logic](../03-sequential/), where a clock
arrives and outputs start depending on the past.
