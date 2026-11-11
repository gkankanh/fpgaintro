# `common/rtl/` — the promoted module library

The rule is worth stating, because it decides where every reusable module
lives.

## The rule

A module lives **in its lesson folder** while the lesson is about it. The file
you are learning from should be in the directory you are reading, not behind an
include path — that is what makes a lesson readable on its own, on GitHub,
offline.

A module is **promoted here** once it is (a) verified by its lesson's testbench
and (b) actually needed by more than one lesson.

This was expected to happen first at lesson 10, where the CPU gets assembled
out of parts built earlier. It actually happened at **lesson 05**, which needed
lesson 03's debouncer and edge detector to make its combination lock usable on
hardware. The criterion is "used twice", not a particular lesson number.

This mirrors how real projects work: you build something, you verify it, and
only then does it become library code that other things depend on.

## What will land here

| module | built in | used by |
|---|---|---|
| `mux2`, `mux4` | 02-combinational | datapath muxes, 12 onward |
| `adder` | 02-combinational | 10-alu, and so the whole CPU |
| `dec` | 02-combinational | instruction decode, address decode |
| `reg_w` | 03-sequential | PC, instruction register, pipeline registers |
| `sync2`, `cdc_bus` | 04-clocks | any second clock domain |

## What is here now

| module | file | built in | first reused by |
|---|---|---|---|
| `debounce` | `debounce.v` | 03-sequential | 05-fsm |
| `edge_detect` | `debounce.v` | 03-sequential | 05-fsm |

All of them are parameterised by width and **default to 32** — the CPU's width —
so the CPU lessons instantiate them with no parameter at all, and the teaching
lessons narrow them where a complete truth table is worth having.

## The contract

Once a module is here, `make sim-all` is what keeps it honest: a change that
breaks a downstream lesson shows up as a failing testbench in that lesson, not
as a surprise three weeks later. That is the whole reason the course-wide
regression suite exists.

Promoting a module means moving it, not copying it. Its lesson folder then
instantiates it from here too, so there is exactly one copy and the lesson you
learned it in stays runnable.
