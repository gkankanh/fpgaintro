# Lesson 01 — worked solutions

Answers to exercises 1, 3 and 4. Exercises 2 and 5 are left open on purpose:
2 is exercise 1's method applied to a different universal gate, and 5 is a
testbench change rather than a design change.

Each file is standalone and self-checking:

```bash
cd solutions
../../toolchain/oss-cad-suite/bin/iverilog -g2005 -o ex1.vvp ex1_xnor_from_nand.v
../../toolchain/oss-cad-suite/bin/vvp ex1.vvp
```

Or all three at once:

```bash
make -C solutions
```
