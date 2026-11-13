#import "../style.typ": *

= Installing

One command, about a gigabyte, and nothing system-wide. Deleting the
`toolchain/` directory undoes all of it.

```bash
git clone <this repository> && cd ULX3S
tools/install.sh
make check
```

`make check` verifies that every tool runs, then simulates lesson 00 as a
smoke test. It ends with `Ready.`

== What the installer does

`tools/install.sh` detects your platform, asks GitHub for the newest
#link("https://github.com/YosysHQ/oss-cad-suite-build")[OSS CAD Suite] release
rather than pinning a date that rots, unpacks it into `toolchain/`, and on
macOS clears the quarantine flags that would otherwise make every tool prompt
for confirmation.

#ttable(
  columns: (auto, auto, 1fr),
  [*flag*], [*adds*], [*needed by*],
  [#emph[none]], [
    yosys, nextpnr-ecp5, Project Trellis, Icarus Verilog, Verilator, GTKWave,
    openFPGALoader, SymbiYosys
  ], [lessons 00–14],
  [`--with-riscv`], [a RISC-V bare-metal C compiler], [lesson 15 onward],
  [`--with-docs`],  [mdBook, for the HTML version of the lessons], [optional],
  [`--all`],        [all of the above], [],
)

Supported platforms are macOS (Intel and Apple Silicon) and Linux (x86-64 and
ARM64). On anything else the script says so, and says where to put a toolchain
you build yourself.

== What `make check` reports

#ttable(
  columns: (auto, 1fr),
  [`✓ iverilog`],     [simulation],
  [`✓ yosys`],        [synthesis],
  [`✓ nextpnr-ecp5`], [place and route],
  [`✓ ecppack`],      [bitstream packing],
  [`✓ verilator`],    [linting],
  [`✓ gtkwave`],      [waveforms],
  [`✓ dot`],          [schematics],
  [`✓ make sim`],     [`PASS: 8 toggles, period 256 clks`],
)

A missing #emph[optional] tool is a dash rather than a cross, and the check
still passes: `openFPGALoader` matters only with a board attached, `sby` only
in lesson 14, a RISC-V compiler only from lesson 15.

== Editor setup

Any editor works — the Makefiles are the interface. For VS Code the repository
ships a complete configuration, and the one thing that matters is how you
launch it:

```bash
tools/code.sh
```

Watch out. Editor extensions inherit the environment of whatever started the
editor, and a desktop launcher gives them a bare `PATH`. Started from the Dock,
the Verilog extension cannot find `verilator` and linting silently does
nothing — a failure that looks exactly like a broken extension.
`tools/code.sh` puts `toolchain/` on `PATH` first. Open the #strong[folder],
not a file, or `.vscode/tasks.json` never loads.

The workspace then offers one task per lesson, so running a lesson is
#strong[Terminal → Run Task → `▶ deploy 00 blinky`] — two clicks, and it does
not matter which file is open. VS Code tasks can only read the #emph[focused
editor tab]; nothing lets them see what is selected in the file tree, which is
why the lessons are enumerated as tasks instead.

== Icestudio, for the visual path

Icestudio is a separate download from
#link("https://icestudio.io")[icestudio.io]. Set the board to
#strong[ULX3S-85F] once in the setup wizard and the lessons' `.ice` projects
open and build with no further configuration. It brings its own copy of the
toolchain, so the two paths do not share `toolchain/` — redundant on disk,
harmless otherwise.
