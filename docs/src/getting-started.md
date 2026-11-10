# Getting started

## Install

```bash
git clone <this repo> && cd ULX3S
tools/install.sh
make check
```

`tools/install.sh` downloads [oss-cad-suite](https://github.com/YosysHQ/oss-cad-suite-build)
(about 1 GB) into `toolchain/`, which is gitignored. Nothing is installed
system-wide, nothing needs `sudo`, and deleting `toolchain/` undoes it.

Options:

| Flag | Adds | Needed by |
|---|---|---|
| *(none)* | yosys, nextpnr-ecp5, prjtrellis, iverilog, verilator, gtkwave, openFPGALoader, sby | lessons 00–12 |
| `--with-riscv` | a RISC-V bare-metal C compiler | lesson 13 onward |
| `--with-docs` | mdbook | building this site |
| `--all` | all of the above | |

`make check` then verifies each tool really runs and simulates lesson 00 as a
smoke test. It should end with `Ready.`

## Your first lesson

```bash
cd 00-blinky
make sim      # expect: PASS: 8 toggles, period 256 clks
make wave     # look at the counter in gtkwave
make synth    # see what it cost: a handful of flip-flops
```

With a board attached:

```bash
make prog     # loads into SRAM — gone at power-off
make flash    # writes SPI flash — boots on power-up
```

## Editor setup

Launch VS Code through the wrapper so the toolchain is on `PATH`:

```bash
tools/code.sh
```

This matters: VS Code extensions inherit the environment of whatever launched
the editor. Started from the Dock, `PATH` is bare, the Verilog extension cannot
find `verilator`, and linting silently does nothing — one of those failures that
looks like "the extension is broken".

VS Code will offer to install the recommended extensions from
`.vscode/extensions.json`. `Cmd+Shift+B` simulates whichever lesson you have a
file open in; the other `make` verbs are on the task list
(`Cmd+Shift+P` → *Run Task*).

Any editor works — the Makefiles are the interface, not the editor.

## Board setup

The ULX3S appears as an FTDI device (VID `0403`, PID `6015`). On macOS it works
out of the box with `openFPGALoader`. On Linux you need udev rules so you are
not root:

```bash
sudo cp /etc/udev/rules.d/99-openfpgaloader.rules /dev/null  # see below
```

Use the rules file shipped with
[openFPGALoader](https://github.com/trabucayre/openFPGALoader/blob/master/99-openfpgaloader.rules),
then `sudo udevadm control --reload`.

To check the board is seen:

```bash
toolchain/oss-cad-suite/bin/openFPGALoader --detect -b ulx3s
```

## If something goes wrong

| Symptom | Cause |
|---|---|
| `make sim` says `command not found` | toolchain missing — run `tools/install.sh` |
| macOS: "cannot be opened because the developer cannot be verified" | quarantine flags; `xattr -dr com.apple.quarantine toolchain/oss-cad-suite` |
| linting does nothing in VS Code | editor launched without the toolchain on `PATH` — use `tools/code.sh` |
| `openFPGALoader` finds nothing | wrong USB port (use the one marked for the FPGA), or a charge-only cable |
| `nextpnr` fails timing | the design is too slow for 25 MHz; look at the critical path it reports |
