#import "../style.typ": *

= Installation

Everything needed for lessons 00 through 14 is one command and about a
gigabyte. Nothing is installed system-wide, nothing needs administrator
rights, and removing the `toolchain/` directory undoes all of it.

== The short version

```bash
git clone <this repository> && cd ULX3S
tools/install.sh
make check
```

`make check` verifies that every tool actually runs and then simulates lesson
00 as a smoke test. It should end with `Ready.`

== What the installer does

`tools/install.sh` detects your platform, asks GitHub for the newest
#link("https://github.com/YosysHQ/oss-cad-suite-build")[OSS CAD Suite] release
rather than pinning a date that rots, downloads it into `toolchain/`, and — on
macOS — clears the quarantine flags that would otherwise make every tool prompt
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
ARM64). On an unsupported platform the script says so and tells you where to
put a toolchain you build yourself.

== Verifying it

```bash
make check
```

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

A missing *optional* tool is reported with a dash rather than a cross, and the
check still passes — `openFPGALoader` is only needed with a board attached,
`sby` only in lesson 14, a RISC-V compiler only from lesson 15.

== The board

The ULX3S appears as an FTDI device, vendor `0403`, product `6015`. One USB
cable carries both the programmer and the serial port.

```bash
toolchain/oss-cad-suite/bin/openFPGALoader --detect -b ulx3s
```

A working board answers with its JTAG identity:

```
idcode 0x41113043
manufacturer lattice
family ECP5
model  LFE5U-85
```

On macOS this works with no driver installation. On Linux you need udev rules
so that programming does not require root; the rules file shipped with
openFPGALoader is the one to use, followed by
`sudo udevadm control --reload`.

#watch[
  The ULX3S has two USB connectors. Only one of them is wired to the FPGA's
  programmer. If `--detect` finds nothing, try the other one before
  suspecting anything else — and check the cable is a data cable rather than a
  charge-only one, which is the other common cause of a board that appears
  dead.
]

== Editor setup

Any editor works, because the Makefiles are the interface. For VS Code the
repository ships a complete configuration:

```bash
tools/code.sh
```

Launch it that way rather than from the Dock. Editor extensions inherit the
environment of whatever started the editor, and from a desktop launcher that
environment has a bare `PATH` — so the Verilog extension cannot find
`verilator` and linting silently does nothing. `tools/code.sh` puts the
toolchain on `PATH` first.

The workspace then offers one task per lesson, so running a lesson is
#strong[Terminal → Run Task → `▶ deploy 00 blinky`] — two clicks, and it does
not matter which file is open.

#watch[
  VS Code tasks can only read the *focused editor tab*; there is no way for
  them to see what is highlighted in the file tree. So clicking a folder in the
  sidebar genuinely cannot select a lesson, no matter how the tasks are
  configured. That is why the repository enumerates the lessons as tasks
  instead.
]

== Icestudio, for the visual path

Icestudio is a separate download from
#link("https://icestudio.io")[icestudio.io]. Set the board to
#strong[ULX3S-85F] once, in the setup wizard, and the lessons' `.ice` projects
open and build with no further configuration.

Icestudio brings its own copy of the toolchain, so the two paths do not share
`toolchain/` — which is harmless, if a little redundant on disk.
