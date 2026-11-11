# Cheat sheet

## If you remember one thing

Open a terminal — **`Ctrl` + `` ` ``**, or **Terminal → New Terminal** — and
from the project root:

```bash
make deploy L=0        # build lesson 00 and load it onto the board
make sim    L=5        # simulate lesson 05
make list              # which lesson is which number?
```

`L` is the lesson number. **No navigating, no selecting a folder, no caring
which editor tab is focused.** The terminal opens at the project root, which is
exactly where these work.

| | |
|---|---|
| `make list` | the lesson numbers |
| `make deploy L=n` | build **and** load onto the board |
| `make sim L=n` | run the testbench — must print `PASS` |
| `make wave L=n` | open the waveform |
| `make lint L=n` | strict checks |
| `make synth L=n` | what it cost in LUTs and flip-flops |

Every verb in the table further down also takes `L=n` from the project root.

## The editor way, if you prefer it

**`⌘⌥R`** opens the task picker and lists every task by name, so nothing has to
be recalled. `⌘⌥U` builds and deploys, asking which lesson from a dropdown.

Both are optional. The `L=` commands above do everything.

## The daily loop

Three commands cover almost everything:

| | |
|---|---|
| **`⌘⇧B`** | **simulate** the lesson whose file you have open. Must print `PASS`. |
| **`⌘⌥U`** | **build and deploy** to the board. Asks which lesson. |
| **`⌘⌥G`** | open the **waveform** in gtkwave. |

## All the keys

`alt` is the **⌥ Option** key on a Mac.

| keys | action | which lesson? |
|---|---|---|
| `⌘⇧B` | `make sim` — run the testbench | the open file's |
| `⌘⌥R` | the task picker — everything | you choose |
| `⌘⌥U` | build **and** deploy | asks |
| `⌘⌥B` | build a bitstream only | asks |
| `⌘⌥P` | deploy an existing bitstream | asks |
| `⌘⌥L` | `make lint` — verilator, strict | the open file's |
| `⌘⌥G` | `make wave` — gtkwave | the open file's |
| `⌘⌥Y` | is the board connected? | — |
| `⌘⌥T` | stop the running task | — |

"The open file's" means the task runs in the directory of whichever editor tab
is focused. With a root-level README focused there is no lesson, and the
Makefile will say so rather than failing cryptically.

## Make verbs

Every lesson understands the same ones. Run them from inside a lesson folder.

| verb | does |
|---|---|
| `make sim` | iverilog — run the testbench. **Must print `PASS`.** |
| `make wave` | gtkwave — look at the waveform |
| `make lint` | verilator `-Wall` — latches, widths, multiple drivers |
| `make graph` | yosys + graphviz — render the design as a schematic SVG |
| `make synth` | resource report: LUT4s, flip-flops, BRAM, carry cells |
| `make bit` | yosys → nextpnr → ecppack — a bitstream, with timing closure |
| `make prog` | load into FPGA **SRAM** — volatile, use while iterating |
| `make flash` | write to **SPI flash** — survives power-off |
| `make clean` | delete build products |

From the **course root** instead:

| | |
|---|---|
| `make check` | is the toolchain healthy? |
| `make sim-all` | every lesson's testbench — the regression suite |
| `make lint-all` | verilator across every lesson |
| `make ice` | regenerate the Icestudio projects |
| `make docs` | build the lesson book |
| `make help` | list these |

## The usual confusions

**"No rule to make target `bit'"** — you ran a per-lesson verb in the course
root with no lesson named. Add `L=n`: `make bit L=0`.

**"Open in Integrated Terminal" does nothing** — skip it. Open a plain terminal
with `Ctrl` + `` ` `` and use `make deploy L=0` from the project root instead.
Nothing needs to be selected.

**"No extension found for verilog"** — you pressed the Run/Debug ▶ button.
Verilog is not executed; it is simulated or synthesised. Use `⌘⇧B`. (The ▶
button is mapped to `make sim` in this repo, so it works too.)

**Linting does nothing** — VS Code was launched from the Dock, so the Verilog
extension inherited a bare `PATH` and cannot find verilator. Launch with
`tools/code.sh` instead.

**`make bit` says "Nothing to be done"** — the bitstream is newer than the
source, so there is nothing to rebuild. Run `make clean` first to force it.

**`prog` vs `flash`** — `prog` is SRAM and vanishes at power-off, which is what
you want while iterating. `flash` writes SPI flash so the board boots your
design.

## Open the project correctly

Open the **folder**, not a file — `.vscode/tasks.json` only loads when its
parent is the workspace root:

```bash
cd /Users/gopal/projects/ULX3S && tools/code.sh
```

`tools/code.sh` also puts the toolchain on `PATH`, which the Verilog extension
needs for linting. The Explorer should then show `00-blinky` … `17-extensions`.
