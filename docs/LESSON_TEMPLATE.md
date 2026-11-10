# Lesson NN — <topic>

> Copy this file to `NN-topic/README.md` and work through it. Delete the
> quoted guidance notes as you go. The shape matters: readers rely on every
> lesson answering the same questions in the same order.

**Concept:** <one line — the single idea this lesson teaches.>

**You will build:** <one line — the deliverable, concretely.>

**Needs the board:** no / yes, for the last section

**Prerequisites:** lesson NN

---

## The idea

> Two to four paragraphs. State the concept, say why it exists, and connect it
> to something the reader already has in their hands from an earlier lesson.
> Assume an engineer who once knew this: no condescension, no ground-up
> re-derivation, but no hand-waving either.
>
> Include a picture. A block diagram (hand-authored SVG in `docs/diagrams/`) or
> a timing diagram (WaveDrom JSON in this lesson's `diagrams/`). If the concept
> is about *when* things happen, it needs a timing diagram, not prose.

## The design

> Walk through the source. Not line by line — explain the *decisions*:
> why this width, why this is registered and that is not, what breaks if you
> do it the obvious way instead. Quote the interesting fragments inline rather
> than reproducing the whole file; the file is right there.
>
> Call out the thing that will bite them:
>
> > **Watch out** — <the mistake this design makes easy to make.>

## Simulate it

```bash
cd NN-topic
make sim
```

```
PASS: ...
```

> Say what the testbench actually checks, and what it deliberately does not.
> Then point at the waveform and say what to look for in it — a reader who
> opens gtkwave and sees forty signals needs to be told which three matter.

```bash
make wave
```

## See the structure

```bash
make graph      # -> NN.svg, the schematic yosys inferred
```

> One observation about the schematic. Something that is visible there and not
> obvious in the text.

## What it cost

```bash
make synth
```

| | |
|---|---|
| LUT4 | n |
| flip-flops | n |

> One sentence relating the number to the design: "32 flip-flops, one per bit,
> as expected" or "18 LUTs for what looked like 4 gates, because...".

## On the board

> Only if applicable. Say exactly what the reader should see, including how
> long to wait and what the failure looks like.

```bash
make prog
```

## Icestudio

> Only for dual-path lessons. Both of these:
>
> ```bash
> open NN-topic/icestudio/<name>.ice
> ```
>
> - what the diagram shows that the text does not
> - which block to change for the exercises below

## Exercises

> Three to five, ordered easy to hard. Each one should teach something by
> *breaking*, and should say what the reader will see when it breaks — a
> prediction they can check is worth ten instructions they can follow.
>
> 1. Change X to Y. Predict what happens, then try it.
> 2. Deliberately introduce <the classic mistake>. Find it in the waveform.
> 3. Extend the design to <small addition>, and extend the testbench first.
>
> Exercises are prompts, not homework to be marked: each should state what the
> reader will observe when it works, so they can check themselves. Worked
> solutions in `solutions/` are optional — ship them only where the answer is
> genuinely hard to self-check (lesson 01 has a set; most lessons do not need
> one). If a testbench change is the whole answer, leave it open.

## What you should now be able to explain

> Three or four bullets. If a reader cannot answer these, the lesson did not
> work and they should re-read rather than move on.
>
> - ...

**Next:** lesson NN+1 — <topic>, which needs <what this lesson built>.
