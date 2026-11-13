#!/usr/bin/env python3
"""
icecheck.py — compile-check a generated Icestudio project without the GUI.

Why this exists
---------------
There is no headless Icestudio, so for a long time the only way to know whether
a generated `.ice` actually builds was to open it by hand and press Build. That
left most of the course's projects marked "not yet opened" — unverified rather
than suspect, but unverified all the same.

A `.ice` is not a mystery, though. Icestudio's own compiler turns a
`basic.code` block into one Verilog module, and the rule it uses is short
enough to reproduce exactly (see `module()` in Icestudio's
`scripts/services/compiler.js`):

    module <name> #(
     parameter <P> = <value, or 0 when nothing is wired>
    )(
     input  [range] <in port>,
     output [range] <out port>
    );
    <the code block's body, verbatim>
    endmodule

Note what that header does NOT say: an output is declared `output name`, with
no `reg`. An Icestudio code block therefore cannot hold a body that drives its
output from inside an `always` block — that is a procedural assignment to a
wire, which is illegal Verilog. This script exists mostly to catch that class
of mistake, because it is invisible in the JSON and obvious to a compiler.

What it checks, per project:
  1. the reconstructed module compiles       (iverilog -g2005 -Wall)
  2. it synthesises for the real part        (yosys synth_ecp5)
  3. every bound pin exists on the board     (Icestudio's own pinout.json)
  4. no two bound pins share one FPGA ball   (a duplicate LOCATE in the .lpf)

Checks 1 and 2 are the strong ones: they are the same two tools the editor
path runs, so a project that passes them fails in the GUI only for reasons
that live in the GUI. Pressing Build on real hardware is still the final word.

Usage:  tools/icecheck.py 00-blinky/icestudio/blink.ice [...]
        tools/icecheck.py --all        # every icestudio/*.ice in the repo
        tools/icecheck.py --all -v     # show the reconstructed Verilog too
"""
from __future__ import annotations

import glob
import json
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
TOOLS = os.path.join(ROOT, "toolchain", "oss-cad-suite", "bin")

BOARD_DIRS = [
    "/Applications/icestudio.app/Contents/Resources/app.nw/resources/boards",
    os.path.expanduser("~/.icestudio/boards"),
]


def tool(name: str) -> str:
    """Prefer the course's own toolchain, fall back to PATH."""
    local = os.path.join(TOOLS, name)
    return local if os.path.isfile(local) else name


def load_pinout(board: str) -> dict[str, str] | None:
    for d in BOARD_DIRS:
        p = os.path.join(d, board, "pinout.json")
        if os.path.isfile(p):
            return {e["name"]: e["value"] for e in json.load(open(p))}
    return None


def reconstruct(ice: dict) -> tuple[str, str]:
    """Rebuild the Verilog module Icestudio would generate for the code block.

    Returns (module_name, source). Mirrors compiler.js: parameters come from
    the constants wired to the block, ports are declared with their range and
    no `reg`, and the body is inserted verbatim.
    """
    blocks = ice["design"]["graph"]["blocks"]
    wires = ice["design"]["graph"]["wires"]

    code = [b for b in blocks if b["type"] == "basic.code"]
    if len(code) != 1:
        raise SystemExit(
            f"icecheck: expected exactly one basic.code block, found {len(code)}.\n"
            f"  This script reconstructs a single-code-block project, which is\n"
            f"  what tools/mkice.py emits. A hand-drawn design with several\n"
            f"  blocks has to be checked by building it in the GUI."
        )
    code = code[0]
    data = code["data"]

    # A constant block feeds a parameter by being wired to the port that
    # carries the parameter's name. Icestudio falls back to 0 for a parameter
    # with nothing wired to it, so reproduce that rather than erroring.
    consts = {b["id"]: b["data"] for b in blocks if b["type"] == "basic.constant"}
    values: dict[str, str] = {}
    for w in wires:
        src, tgt = w["source"], w["target"]
        if src["block"] in consts and tgt["block"] == code["id"]:
            values[tgt["port"]] = str(consts[src["block"]].get("value", "0"))

    name = "icecheck_top"
    params = [p["name"].lstrip("@") for p in data.get("params", [])]

    header = f"module {name}"
    if params:
        decls = [f" parameter {p} = {values.get(p, '0')}" for p in params]
        header += " #(\n" + ",\n".join(decls) + "\n)"

    ports = []
    for p in data["ports"].get("in", []):
        rng = f"{p['range']} " if p.get("range") else ""
        ports.append(f" input {rng}{p['name'].lstrip('@')}")
    for p in data["ports"].get("out", []):
        rng = f"{p['range']} " if p.get("range") else ""
        ports.append(f" output {rng}{p['name'].lstrip('@')}")
    for p in data["ports"].get("inout", []):
        rng = f"{p['range']} " if p.get("range") else ""
        ports.append(f" inout {rng}{p['name'].lstrip('@')}")

    header += "(\n" + ",\n".join(ports) + "\n);\n"
    return name, header + data["code"].rstrip("\n") + "\nendmodule\n"


def check_pins(ice: dict, problems: list[str]) -> None:
    board = ice["design"].get("board", "ulx3s-85f")
    pinout = load_pinout(board)
    if pinout is None:
        problems.append(f"pinout for board '{board}' not found — pin checks skipped")
        return

    seen: dict[str, str] = {}      # ball -> the port bit that claimed it
    for b in ice["design"]["graph"]["blocks"]:
        if b["type"] not in ("basic.input", "basic.output"):
            continue
        label = b["data"].get("name", "?")
        for pin in b["data"].get("pins", []):
            nm, ball = pin.get("name"), pin.get("value")
            if nm not in pinout:
                problems.append(f"pin '{nm}' ({label}) is not a pin on {board}")
            elif pinout[nm] != ball:
                problems.append(
                    f"pin '{nm}' ({label}) is recorded as ball {ball}, "
                    f"but {board} puts it at {pinout[nm]} — regenerate with mkice")
            bit = f"{label}[{pin.get('index')}]"
            if ball in seen:
                problems.append(
                    f"ball {ball} ({nm}) is bound twice: {seen[ball]} and {bit}. "
                    f"Icestudio writes one LOCATE per bit, so the .lpf would "
                    f"name {ball} twice and nextpnr rejects it")
            else:
                seen[ball] = bit


def run(cmd: list[str], cwd: str) -> tuple[int, str]:
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    return p.returncode, (p.stdout + p.stderr).strip()


def check(path: str, verbose: bool = False) -> list[str]:
    ice = json.load(open(path))
    problems: list[str] = []
    name, src = reconstruct(ice)
    if verbose:
        print("    " + "\n    ".join(src.split("\n")))

    check_pins(ice, problems)

    with tempfile.TemporaryDirectory() as d:
        v = os.path.join(d, name + ".v")
        with open(v, "w") as f:
            f.write(src)

        rc, out = run([tool("iverilog"), "-g2005", "-Wall", "-o", os.devnull, v], d)
        if rc != 0:
            problems.append("iverilog rejected the reconstructed module:\n      " +
                            "\n      ".join(out.split("\n")[:12]))
        elif out:
            # -Wall warnings are worth seeing but are not failures: a lesson
            # body may legitimately warn (an unused port on a probe-only
            # project, say).
            for line in out.split("\n")[:6]:
                problems.append(f"iverilog warning: {line}")

        rc, out = run([tool("yosys"), "-q", "-p",
                       f"read_verilog {v}; synth_ecp5 -top {name}"], d)
        if rc != 0:
            tail = [l for l in out.split("\n") if l.strip()][-10:]
            problems.append("yosys could not synthesise it:\n      " +
                            "\n      ".join(tail))

    return problems


def main(argv: list[str]) -> int:
    args = [a for a in argv[1:] if a not in ("-v", "--verbose")]
    verbose = len(args) != len(argv[1:])

    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    if args[0] == "--all":
        args = sorted(glob.glob(os.path.join(ROOT, "*", "icestudio", "*.ice")))
        if not args:
            print("icecheck: no icestudio/*.ice projects found")
            return 0

    bad = 0
    for p in args:
        rel = os.path.relpath(p, ROOT)
        problems = check(p, verbose)
        hard = [x for x in problems if not x.startswith("iverilog warning")]
        if not problems:
            print(f"  PASS  {rel}")
        elif not hard:
            print(f"  PASS  {rel}")
            for x in problems:
                print(f"          {x}")
        else:
            bad += 1
            print(f"  FAIL  {rel}")
            for x in problems:
                print(f"        - {x}")
    print(f"\n  {len(args) - bad}/{len(args)} projects pass")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
