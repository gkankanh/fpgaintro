#import "../style.typ": *

= Getting a design onto the board

== Is the board there?

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

Watch out. The ULX3S has #strong[two] USB connectors and only one of them is
wired to the FPGA's programmer. If `--detect` finds nothing, try the other
socket before suspecting anything else — and check the cable is a data cable
rather than a charge-only one, which is the other common cause of a board that
appears dead.

On macOS this works with no driver installation. On Linux you need udev rules
so that programming does not require root: use the rules file shipped with
openFPGALoader, then `sudo udevadm control --reload`.

== Build, then load

```bash
make bit       # yosys -> nextpnr -> ecppack, with timing closure
make prog      # into the FPGA's configuration SRAM
make flash     # into the SPI flash beside it
```

Or, from the project root, both steps at once — the command you will use most:

```bash
make deploy L=0
```

#ttable(
  columns: (auto, 1fr),
  [`make prog`],  [straight into the FPGA's configuration SRAM. Takes about a
                   second, and is gone the moment the board loses power. This
                   is what you use while iterating],
  [`make flash`], [into the SPI flash chip beside the FPGA, from which the
                   FPGA reloads itself at every power-on. This is what you use
                   when the design is finished],
)

The ECP5 holds its configuration in on-chip SRAM, which is why there are two
commands rather than one. An FPGA that has not been configured does nothing
whatsoever — it is not running an idle loop; there is no loop.

Watch out. `make bit` reporting "Nothing to be done" means the bitstream is
newer than its sources, so there is genuinely nothing to rebuild. If you
believe otherwise, the usual cause is a build input the lesson did not declare
— a `$readmemh` image, most often. `make clean` forces it.

== Talking to it over serial

From lesson 09 onward a design can print. Lessons 15 and 17 add
`make console`, which tells you the port and the incantation rather than
pretending to be a terminal emulator:

```bash
make console
#   macOS:  screen /dev/cu.usbserial-* 115200    (quit: ctrl-a k y)
#   Linux:  picocom -b 115200 /dev/ttyUSB0       (quit: ctrl-a ctrl-x)
```

Two things about this cost an evening each if you meet them the hard way.

#strong[Use `/dev/cu.*`, not `/dev/tty.*`.] On macOS the `tty` device blocks on
open until carrier detect is asserted, which an FTDI cable never does. The open
simply hangs, with no error to search for.

#strong[Quit the console before `make prog`.] The ULX3S puts JTAG and this UART
on one FT231X, so openFPGALoader cannot claim the chip while a terminal holds
the port. It fails with `unable to claim usb device`.

== Software, where a lesson has software

Lessons 15 and 17 run compiled C, so they add a software half to the same
Makefile:

#ttable(
  columns: (auto, 1fr),
  [`make firmware`], [`riscv64-elf-gcc` → `objcopy` → `tools/bin2hex.py`,
                      producing `firmware.hex`],
  [`make size`],     [where the program went — `.text` against `.bss`, and the
                      memory it has to fit in],
  [`make dis`],      [the program as the CPU sees it. Worth doing once: every
                      instruction in there is one your decoder has to
                      recognise],
  [`make console`],  [the serial incantation, above],
)

`firmware.hex` is checked in, and `make clean` leaves it alone, so a reader
with no RISC-V compiler can still simulate, synthesise and flash those lessons
— they just cannot change the program. `RVPREFIX` overrides the compiler
prefix; `MEM_WORDS` the memory size the image is padded to.

Lesson 13 assembles rather than compiles, with the course's own assembler:

```bash
make prog-asm      # tools/rvasm.py test.s -> test.hex, and a listing
make check-asm     # cross-validate that assembler against GNU as
```

== Proofs, where a lesson proves something

Lesson 14 has no design of its own — it proves lesson 10's ALU and lesson 11's
register file — so its `make sim` runs the proofs, which is what puts formal
verification into the course-wide regression suite:

#ttable(
  columns: (auto, 1fr),
  [`make sim`],            [the quick proofs, as part of `make sim-all`],
  [`make formal`],         [everything, including the register file (about a
                            minute)],
  [`make formal-broken`],  [a deliberately broken ALU, so the solver produces a
                            counterexample],
  [`make formal-vacuous`], [a proof that passes and is worthless, with the
                            cover that shows it],
  [`make wave`],           [the counterexample trace from the broken proof],
)

`lint`, `synth`, `bit` and `prog` in lesson 14 print a note pointing at lessons
10 and 11, where those designs are already checked.

== When something goes wrong

#ttable(
  breakable: true,
  columns: (auto, 1fr),
  [`command not found`], [
    the toolchain is missing — run `tools/install.sh`
  ],
  [macOS: "cannot be opened"], [
    quarantine flags; `xattr -dr com.apple.quarantine toolchain/oss-cad-suite`
  ],
  [linting does nothing], [
    the editor was launched without the toolchain on `PATH` — use
    `tools/code.sh`
  ],
  [`No rule to make target 'bit'`], [
    `make` ran in the project root with no lesson named. Add `L=n`, or open a
    file inside a lesson first
  ],
  [`Nothing to be done for 'bit'`], [
    the bitstream is newer than the source. `make clean` to force a rebuild
  ],
  [`openFPGALoader` finds nothing], [
    wrong USB socket, or a charge-only cable
  ],
  [`unable to claim usb device`], [
    a serial console still holds the FT231X. Quit it, then program
  ],
  ["no extension found for verilog"], [
    you pressed the editor's Run/Debug button. Verilog is not #emph[executed] —
    it is simulated or synthesised. Use `make sim`
  ],
  [`nextpnr` fails timing], [
    the design is too slow for the requested clock. Read the critical path it
    reports; lesson 04 is about exactly this
  ],
  [a serial console that hangs on open], [
    `/dev/tty.*` on macOS. Use `/dev/cu.*`
  ],
)
