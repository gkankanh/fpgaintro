#!/usr/bin/env python3
"""
mkice.py — generate an Icestudio (.ice) project from a small JSON spec.

Why this exists
---------------
This course is dual-path: every lesson can be done by typing Verilog in an
editor, or by wiring blocks in Icestudio. Hand-drawing each diagram in the GUI
and keeping it in step with the Verilog would rot immediately, so instead each
dual-path lesson ships an `icestudio/<name>.json` spec and this script renders
the `.ice` file that Icestudio opens.

The `.ice` format (v1.2) is plain JSON:

    design.graph.blocks[]   basic.input / basic.output / basic.code /
                            basic.constant / basic.info
    design.graph.wires[]    {source:{block,port}, target:{block,port}, size?}

A `basic.code` block holds the *body* of a module — ports are declared in the
block's own data, not in a `module ... endmodule` header. That is the one real
difference from the hand-written `.v` file. Rather than make a lesson keep its
logic in a body-only include (indirection, in the very first lesson), this
script extracts the body out of the real `.v`. Lesson sources therefore stay
ordinary readable Verilog — exactly what a learner should be reading — and the
dual path is handled by tooling.

Spec format (see 00-blinky/icestudio/blink.json for a worked example):

    {
      "name":    "blink",                  # output file: blink.ice
      "board":   "ulx3s-85f",
      "info":    "markdown shown in the canvas",
      "from":    {"file": "../blink.v", "module": "blink"},  # body extracted
      # ...or  "code": "body.vh"  to point at a body-only file instead
      "params":  [{"name": "WIDTH", "value": "26"}],
      "inputs":  [{"port": "clk",  "pin":  "clk"}],
      "outputs": [{"port": "q",    "pins": ["led_7", "led_6"]}]
    }

A single "pin" is a 1-bit port; a "pins" list makes a bus, MSB first, and the
generated code-block port gets the matching [N-1:0] range.

Usage:  tools/mkice.py 00-blinky/icestudio/blink.json [...]
        tools/mkice.py --all          # every icestudio/*.json in the repo
"""
from __future__ import annotations

import glob
import json
import os
import re
import sys
import uuid

# Icestudio ships one pinout.json per board; it maps the friendly pin names
# used on the canvas ("led_0") to the FPGA ball ("B2").
BOARD_DIRS = [
    "/Applications/icestudio.app/Contents/Resources/app.nw/resources/boards",
    os.path.expanduser("~/.icestudio/boards"),
]

# Canvas layout: inputs in a left column, the code block in the middle,
# outputs in a right column. Icestudio lets the user drag things afterwards.
X_IN, X_CODE, X_OUT = 48, 384, 816
Y_TOP, Y_STEP = 48, 120


def load_pinout(board: str) -> dict[str, str]:
    for d in BOARD_DIRS:
        p = os.path.join(d, board, "pinout.json")
        if os.path.isfile(p):
            return {e["name"]: e["value"] for e in json.load(open(p))}
    raise SystemExit(
        f"mkice: no pinout.json for board '{board}'.\n"
        f"  Looked in: {', '.join(BOARD_DIRS)}\n"
        f"  Is Icestudio installed, and is the board name right?"
    )


def extract_body(path: str, module: str) -> str:
    """Pull the body out of `module <name> ... endmodule` in a .v file.

    Icestudio code blocks carry a body with no header, so the lesson's plain
    Verilog has to be unwrapped. This is deliberately strict: if the shape is
    not exactly one matching module with a parenthesised port list, it fails
    loudly rather than quietly emitting half a design.
    """
    if not os.path.isfile(path):
        raise SystemExit(f"mkice: no such Verilog file: {path}")
    src = open(path).read()

    m = re.search(r"\bmodule\s+" + re.escape(module) + r"\b", src)
    if not m:
        raise SystemExit(f"mkice: module '{module}' not found in {path}")

    # Walk from the module keyword to the ')' closing the *port* list,
    # counting parens so a '#(parameters)' list does not fool us.
    i, depth, closed_at = m.end(), 0, None
    while i < len(src):
        c = src[i]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                closed_at = i
                if re.match(r"\s*\(", src[i + 1:]):   # that was #(...); ports follow
                    i += 1
                    continue
                break
        i += 1
    if closed_at is None:
        raise SystemExit(f"mkice: could not find the port list of '{module}'")

    after = src[closed_at + 1:]
    semi, end = after.find(";"), after.find("endmodule")
    if semi < 0:
        raise SystemExit(f"mkice: malformed header for module '{module}'")
    if end < 0:
        raise SystemExit(f"mkice: no 'endmodule' for module '{module}'")

    body_text = after[semi + 1:end]

    # An Icestudio basic.code block is a bare module body — it cannot
    # instantiate other modules, because Icestudio resolves blocks on the
    # canvas, not through a Verilog namespace. Catch that here rather than
    # letting the user discover it as a build failure in the GUI.
    #
    # Heuristic: `<module> <instance> (` or `<module> #(params) <instance> (`
    # at statement level. Two separate patterns rather than one with an
    # optional group, because an optional group lets the regex engine
    # backtrack and split a single word in two — `case (hex)` was being read
    # as module `cas`, instance `e`. Requiring real whitespace between the
    # two identifiers is what prevents that.
    KEYWORDS = {"if", "case", "casez", "casex", "for", "while", "repeat",
                "always", "initial", "assign", "begin", "end", "function",
                "task", "generate", "endgenerate", "wire", "reg", "localparam",
                "parameter", "integer", "genvar", "else", "posedge", "negedge"}
    INST_PATTERNS = (
        r"^[ \t]*([A-Za-z_]\w*)[ \t]+([A-Za-z_]\w*)[ \t]*\(",
        r"^[ \t]*([A-Za-z_]\w*)[ \t]*#[ \t]*\([^;]*?\)[ \t]*([A-Za-z_]\w*)[ \t]*\(",
    )
    hits = [mm for pat in INST_PATTERNS
            for mm in re.finditer(pat, body_text, re.MULTILINE)
            if mm.group(1) not in KEYWORDS and mm.group(2) not in KEYWORDS]
    for mm in hits:
        raise SystemExit(
            f"mkice: module '{module}' instantiates '{mm.group(1)}' "
            f"(as '{mm.group(2)}').\n"
            f"  An Icestudio code block cannot instantiate other modules, so a\n"
            f"  hierarchical top cannot be generated this way. Point the spec at\n"
            f"  a leaf module instead, or build the hierarchy on the Icestudio\n"
            f"  canvas from blocks in icestudio/collections/.")

    lines = [ln.rstrip() for ln in body_text.strip("\n").split("\n")]
    indents = [len(ln) - len(ln.lstrip()) for ln in lines if ln.strip()]
    cut = min(indents) if indents else 0
    return "\n".join(ln[cut:] if ln.strip() else "" for ln in lines).strip("\n") + "\n"


def block(btype: str, data: dict, x: int, y: int) -> dict:
    return {
        "id": str(uuid.uuid4()),
        "type": btype,
        "data": data,
        "position": {"x": x, "y": y},
    }


def port_pins(spec: dict, pinout: dict[str, str]) -> tuple[list[dict], int]:
    """Resolve a spec's "pin"/"pins" into Icestudio pin records, MSB first."""
    names = spec["pins"] if "pins" in spec else [spec["pin"]]
    pins = []
    for i, name in enumerate(names):
        if name not in pinout:
            raise SystemExit(
                f"mkice: '{name}' is not a pin on this board.\n"
                f"  Try one of: clk, led_0..led_7, btn_0..btn_6, sw_0..sw_3,\n"
                f"  oled_clk, oled_mosi, oled_dc, oled_resn, oled_csn, ftdi_*"
            )
        # index counts down so pins[0] is the MSB, matching Verilog [N-1:0].
        pins.append({
            "index": str(len(names) - 1 - i),
            "name": name,
            "value": pinout[name],
        })
    return pins, len(names)


def ranged(name: str, width: int, rng: str | None = None) -> dict:
    """A code-block port record: bare name if 1 bit, else name + range.

    `rng` lets a spec state the port's declared range verbatim, for the case
    where the Verilog is not zero-based — `input [6:1] btn` must stay [6:1],
    or the extracted body's `btn[6]` is out of range. Width is checked against
    the number of pins bound so the two cannot disagree silently.
    """
    if rng:
        m = re.fullmatch(r"\s*\[\s*(\d+)\s*:\s*(\d+)\s*\]\s*", rng)
        if not m:
            raise SystemExit(f"mkice: port '{name}': range {rng!r} is not [hi:lo]")
        hi, lo = int(m.group(1)), int(m.group(2))
        declared = abs(hi - lo) + 1
        if declared != width:
            raise SystemExit(
                f"mkice: port '{name}': range {rng} is {declared} bits but "
                f"{width} pin(s) were bound — one of them is wrong.")
        return {"name": name, "range": f"[{hi}:{lo}]", "size": width}
    if width == 1:
        return {"name": name}
    return {"name": name, "range": f"[{width - 1}:0]", "size": width}


def build(spec_path: str) -> str:
    spec = json.load(open(spec_path))
    here = os.path.dirname(os.path.abspath(spec_path))
    board = spec.get("board", "ulx3s-85f")
    pinout = load_pinout(board)

    if "from" in spec:
        ref = spec["from"]
        body = extract_body(os.path.join(here, ref["file"]), ref["module"])
    elif "code" in spec:
        body_path = os.path.join(here, spec["code"])
        if not os.path.isfile(body_path):
            raise SystemExit(f"mkice: code body not found: {body_path}")
        body = open(body_path).read().rstrip() + "\n"
    else:
        raise SystemExit(f"mkice: {spec_path} needs either 'from' or 'code'")

    blocks: list[dict] = []
    wires: list[dict] = []
    code_in: list[dict] = []
    code_out: list[dict] = []
    pending: list[tuple[dict, str, int, bool]] = []  # (io block, port, width, is_input)

    for i, s in enumerate(spec.get("inputs", [])):
        pins, w = port_pins(s, pinout)
        data = {"name": s.get("label", s["port"]), "pins": pins, "virtual": False}
        if w > 1:
            data["range"] = f"[{w - 1}:0]"
        b = block("basic.input", data, X_IN, Y_TOP + i * Y_STEP)
        blocks.append(b)
        code_in.append(ranged(s["port"], w, s.get("range")))
        pending.append((b, s["port"], w, True))

    for i, s in enumerate(spec.get("outputs", [])):
        pins, w = port_pins(s, pinout)
        data = {"name": s.get("label", s["port"]), "pins": pins, "virtual": False}
        if w > 1:
            data["range"] = f"[{w - 1}:0]"
        b = block("basic.output", data, X_OUT, Y_TOP + i * Y_STEP)
        blocks.append(b)
        code_out.append(ranged(s["port"], w, s.get("range")))
        pending.append((b, s["port"], w, False))

    code = block(
        "basic.code",
        {
            "code": body,
            "params": [{"name": p["name"]} for p in spec.get("params", [])],
            "ports": {"in": code_in, "out": code_out},
        },
        X_CODE,
        Y_TOP,
    )
    blocks.append(code)

    # Constants feed the code block's parameters (Icestudio's generics).
    for i, p in enumerate(spec.get("params", [])):
        c = block(
            "basic.constant",
            {"name": p["name"], "value": str(p["value"]), "local": False},
            X_CODE + 32,
            Y_TOP - 160 - i * 80,
        )
        blocks.append(c)
        wires.append({
            "source": {"block": c["id"], "port": "constant-out"},
            "target": {"block": code["id"], "port": p["name"]},
        })

    if spec.get("info"):
        blocks.append(block(
            "basic.info",
            {"info": spec["info"], "readonly": True},
            X_IN, Y_TOP + max(len(spec.get("inputs", [])),
                              len(spec.get("outputs", []))) * Y_STEP + 64,
        ))

    # Wire each I/O block straight to the like-named port on the code block.
    for b, port, w, is_input in pending:
        wire = ({"source": {"block": b["id"], "port": "out"},
                 "target": {"block": code["id"], "port": port}}
                if is_input else
                {"source": {"block": code["id"], "port": port},
                 "target": {"block": b["id"], "port": "in"}})
        if w > 1:
            wire["size"] = w
        wires.append(wire)

    ice = {
        "version": "1.2",
        "package": {
            "name": spec.get("name", ""),
            "version": spec.get("version", "1.0"),
            "description": spec.get("description", ""),
            "author": spec.get("author", ""),
            "image": "",
        },
        "design": {"board": board, "graph": {"blocks": blocks, "wires": wires}},
        "dependencies": {},
    }

    out = os.path.join(here, spec["name"] + ".ice")
    with open(out, "w") as f:
        json.dump(ice, f, indent=2)
        f.write("\n")
    return out


def main(argv: list[str]) -> int:
    args = argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    if args[0] == "--all":
        root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
        args = sorted(glob.glob(os.path.join(root, "*", "icestudio", "*.json")))
        if not args:
            print("mkice: no icestudio/*.json specs found")
            return 0
    for p in args:
        print(f"  {os.path.relpath(build(p))}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
