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

The board runs out of pins long before a 32-bit datapath runs out of ports, so
a port can be handled three other ways instead of being bound:

    "inputs":  [{"port": "inst", "const": "32'h00500093"},   # canvas constant
                {"port": "rs2",  "tie":   "3'd0"}]           # wired in the body
    "outputs": [{"port": "rd2",  "internal": true}]          # kept off the pins

  const     the port becomes a code-block PARAMETER fed by a constant block,
            so it is editable on the canvas and a part-select of it (inst[31:20])
            is legal Verilog. Use it for a wide input the board cannot drive.
  tie       the port becomes a local wire assigned the given expression, which
            may name another port of the same block.
  internal  the port is declared as a local signal and left unconnected. Use it
            for an output you do not have LEDs for; yosys trims the logic that
            only fed it.

A "drive" is the mirror image: an input port the Verilog did not have, whose
name a "tie" expression can then use. It is how a 32-bit port becomes something
the four slide switches can actually move:

    "drives":  [{"name": "sw", "label": "address nibble",
                 "pins": ["sw_3", "sw_2", "sw_1", "sw_0"]}]
    "inputs":  [{"port": "addr", "tie": "{28'h0000000, sw}"}]

Interesting bits of a wide output reach the LEDs through a probe, which adds
one port the Verilog did not have:

    "probes":  [{"name": "leds", "expr": "{illegal, jump, branch, reg_we}",
                 "pins": ["led_3", "led_2", "led_1", "led_0"]}]

One thing is handled with no help from the spec. Icestudio declares a code
block's outputs as `output name` — never `output reg` — so a body that drives
its output from inside an `always` block is a procedural assignment to a wire,
which is illegal Verilog. Where the lesson's .v says `output reg`, this script
declares the reg in the body, names the block's port `<name>_o`, and wires the
two together with a continuous assignment. The body text is never edited.

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

# Block ids must be stable across runs. uuid4() is random, so regenerating an
# unchanged design produced a different file every time -- `make ice` dirtied
# the git tree on every invocation and the diffs were meaningless noise.
# uuid5 derives the id from a name, so the same spec always yields the same
# ids, and a real change to the design is the only thing that shows up in a
# diff.
_NS = uuid.UUID("6ba7b811-9dad-11d1-80b4-00c04fd430c8")   # the RFC 4122 URL namespace
_seq = 0


def _reset_ids() -> None:
    global _seq
    _seq = 0


def _next_id(spec_name: str) -> str:
    global _seq
    _seq += 1
    return str(uuid.uuid5(_NS, f"{spec_name}#{_seq}"))

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


def split_module(path: str, module: str) -> tuple[str, str]:
    """Return (port list text, body text) for `module <name> ... endmodule`.

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
    i, depth, closed_at, opened_at = m.end(), 0, None, None
    while i < len(src):
        c = src[i]
        if c == "(":
            depth += 1
            if depth == 1:
                opened_at = i
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

    return src[opened_at + 1:closed_at], after[semi + 1:end]


def extract_body(path: str, module: str) -> str:
    """The body of `module`, dedented, with hierarchy refused."""
    _, body_text = split_module(path, module)

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


def module_parameters(path: str, module: str) -> list[str]:
    """The names in a module's `#(...)` list, if it has one.

    A code block's parameters come from the spec, and Icestudio gives a
    parameter with nothing wired to it the value 0. A spec that forgets one
    therefore produces a design that builds and is silently wrong — WIDTH 0,
    a divisor of 0 — so the generator insists the spec account for every
    parameter the module declares.
    """
    src = open(path).read()
    m = re.search(r"\bmodule\s+" + re.escape(module) + r"\b\s*#\s*\(", src)
    if not m:
        return []
    i, depth = m.end() - 1, 0
    while i < len(src):
        if src[i] == "(":
            depth += 1
        elif src[i] == ")":
            depth -= 1
            if depth == 0:
                break
        i += 1
    text = strip_comments(src[m.end():i])
    return re.findall(r"\bparameter\s+(?:integer\s+|\[[^\]]*\]\s*)*([A-Za-z_]\w*)", text)


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


# `input wire [W-1:0] a = 0` — direction, optional kind, optional packed
# range (which may be an expression: [$clog2(N)-1:0]), name, optional default.
PORT_RE = re.compile(r"""
    ^\s*(?P<dir>input|output|inout)\s+
    (?:(?P<kind>wire|reg|logic)\s+)?
    (?P<range>(?:\[[^\]]*\]\s*)*)
    (?P<name>[A-Za-z_]\w*)\s*
    (?P<init>=\s*.+)?\s*$
""", re.X | re.S)


def port_declarations(path: str, module: str) -> dict[str, dict]:
    """Lift each port's declaration out of the module header, in order.

    The generator needs three things the .ice format does not record: whether
    a port is a reg (Icestudio cannot declare one), how wide it is declared
    (which may be a parameter expression), and whether it carries an
    initialiser. Reading them off the real .v keeps the generated project from
    drifting: there is no second copy of the interface to maintain.
    """
    ports_text, _ = split_module(path, module)
    ports: dict[str, dict] = {}
    # Split on commas that are not inside brackets or parentheses.
    depth, cur, entries = 0, "", []
    for ch in strip_comments(ports_text):
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        if ch == "," and depth == 0:
            entries.append(cur)
            cur = ""
        else:
            cur += ch
    entries.append(cur)

    for e in entries:
        if not e.strip():
            continue
        m = PORT_RE.match(e)
        if not m:
            raise SystemExit(
                f"mkice: cannot read port declaration {e.strip()!r} "
                f"in module '{module}'.\n"
                f"  Each port needs its own `input`/`output` keyword for this\n"
                f"  script to know its width and whether it is a reg.")
        rng = " ".join(m.group("range").split())
        ports[m.group("name")] = {
            "dir": m.group("dir"),
            "kind": m.group("kind") or "wire",
            "range": rng,
            "init": (m.group("init") or "").strip(),
        }
    return ports


def declaration(name: str, p: dict, value: str | None = None) -> str:
    """A local declaration standing in for a port, as a Verilog statement."""
    kind = "reg" if p["kind"] == "reg" else "wire"
    rng = f"{p['range']} " if p["range"] else ""
    if value is not None:
        return f"{kind} {rng}{name} = {value};"
    return f"{kind} {rng}{name}{(' ' + p['init']) if p['init'] else ''};"


def alias_for(name: str, taken: set[str]) -> str:
    """A port name for the block that does not collide with the body's own."""
    for cand in (f"{name}_o", f"{name}_out", f"{name}_port"):
        if cand not in taken:
            return cand
    i = 2
    while f"{name}_o{i}" in taken:
        i += 1
    return f"{name}_o{i}"


def block(btype: str, data: dict, x: int, y: int, name: str = "") -> dict:
    return {
        "id": _next_id(name),
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
    name = spec.get("name", os.path.basename(spec_path))
    _reset_ids()
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

    # The port declarations in the real .v tell us what the .ice format does
    # not record: which ports are regs, how wide they are declared, and what
    # they initialise to. Specs that supply a body directly have no header to
    # read, so they get none of the handling that depends on it.
    decls: dict[str, dict] = {}
    if "from" in spec:
        decls = port_declarations(os.path.join(here, ref["file"]), ref["module"])

    blocks: list[dict] = []
    wires: list[dict] = []
    code_in: list[dict] = []
    code_out: list[dict] = []
    pending: list[tuple[dict, str, int, bool]] = []  # (io block, port, width, is_input)
    prologue: list[str] = []      # declarations injected above the body
    epilogue: list[str] = []      # assignments injected below it
    params = [(p["name"], p["value"]) for p in spec.get("params", [])]
    handled: set[str] = set()

    # Names the body already uses, so an injected port alias cannot shadow one.
    body_ids = set(re.findall(r"[A-Za-z_]\w*", body))

    def declared(port: str, how: str) -> dict:
        if port not in decls:
            raise SystemExit(
                f"mkice: {os.path.basename(spec_path)} uses \"{how}\" on port "
                f"'{port}', which needs the port's declaration from the .v.\n"
                f"  Either the module has no such port, or this spec supplies "
                f"its body with \"code\" rather than \"from\".")
        return decls[port]

    # Drives first: a tie expression may name one, and an input block has to
    # exist for the name to resolve to anything.
    drive_names = {d["name"] for d in spec.get("drives", [])}
    for i, d in enumerate(spec.get("drives", [])):
        pins, w = port_pins(d, pinout)
        if d["name"] in body_ids:
            raise SystemExit(
                f"mkice: drive '{d['name']}' collides with a name the body "
                f"already uses — pick another.")
        data = {"name": d.get("label", d["name"]), "pins": pins, "virtual": False}
        if w > 1:
            data["range"] = f"[{w - 1}:0]"
        b = block("basic.input", data, X_IN - 288, Y_TOP + i * Y_STEP, name)
        blocks.append(b)
        code_in.append(ranged(d["name"], w))
        pending.append((b, d["name"], w, True))

    pinned_in, pinned_out = [], []
    for s in spec.get("inputs", []):
        port = s["port"]
        handled.add(port)
        if "const" in s:
            # A parameter, not a port: Icestudio wires a constant block to it,
            # and a part-select of a parameter is legal Verilog.
            params.append((port, s["const"]))
        elif "tie" in s:
            prologue.append(declaration(port, declared(port, "tie"), value=s["tie"]))
        else:
            pinned_in.append(s)

    for s in spec.get("outputs", []):
        port = s["port"]
        handled.add(port)
        if s.get("internal"):
            prologue.append(declaration(port, declared(port, "internal")))
        else:
            pinned_out.append(s)

    if decls:
        missing = [p for p in decls if p not in handled]
        if missing:
            raise SystemExit(
                f"mkice: {os.path.basename(spec_path)} does not account for "
                f"port(s) {', '.join(missing)} of '{ref['module']}'.\n"
                f"  Every port needs a pin, a \"const\", a \"tie\" or "
                f"\"internal\": true — an unmentioned port would simply "
                f"vanish from the generated block.")

    dupes = sorted({n for n in (x for x, _ in params) if [x for x, _ in params].count(n) > 1})
    if dupes:
        raise SystemExit(
            f"mkice: {os.path.basename(spec_path)} declares parameter(s) "
            f"{', '.join(dupes)} twice.\n"
            f"  A \"const\" input becomes a parameter by itself, so it must not "
            f"also appear in \"params\" — two parameters of one name is not "
            f"legal Verilog.")

    declared_params = module_parameters(os.path.join(here, ref["file"]),
                                        ref["module"]) if "from" in spec else []
    named = {n for n, _ in params}
    absent = [p for p in declared_params if p not in named]
    if absent:
        raise SystemExit(
            f"mkice: {os.path.basename(spec_path)} does not give a value for "
            f"parameter(s) {', '.join(absent)} of '{ref['module']}'.\n"
            f"  Icestudio defaults an unwired parameter to 0, which builds and "
            f"is silently wrong, so every parameter must be stated.")

    for i, s in enumerate(pinned_in):
        pins, w = port_pins(s, pinout)
        data = {"name": s.get("label", s["port"]), "pins": pins, "virtual": False}
        if w > 1:
            data["range"] = f"[{w - 1}:0]"
        b = block("basic.input", data, X_IN, Y_TOP + i * Y_STEP, name)
        blocks.append(b)
        code_in.append(ranged(s["port"], w, s.get("range")))
        pending.append((b, s["port"], w, True))

    row = 0
    for s in pinned_out:
        port = s["port"]
        pins, w = port_pins(s, pinout)
        data = {"name": s.get("label", port), "pins": pins, "virtual": False}
        if w > 1:
            data["range"] = f"[{w - 1}:0]"
        b = block("basic.output", data, X_OUT, Y_TOP + row * Y_STEP, name)
        blocks.append(b)

        # Icestudio emits `output name`, never `output reg name`. A body that
        # drives this port inside an always block therefore needs the reg
        # declared locally and the port driven continuously from it.
        code_port = port
        if decls.get(port, {}).get("kind") == "reg":
            code_port = alias_for(port, body_ids | set(decls))
            prologue.append(declaration(port, decls[port]))
            epilogue.append(f"assign {code_port} = {port};")

        code_out.append(ranged(code_port, w, s.get("range")))
        pending.append((b, code_port, w, False))
        row += 1

    for pr in spec.get("probes", []):
        pins, w = port_pins(pr, pinout)
        pname = pr["name"]
        if pname in body_ids:
            raise SystemExit(
                f"mkice: probe '{pname}' collides with a name the body "
                f"already uses — pick another.")
        data = {"name": pr.get("label", pname), "pins": pins, "virtual": False}
        if w > 1:
            data["range"] = f"[{w - 1}:0]"
        b = block("basic.output", data, X_OUT, Y_TOP + row * Y_STEP, name)
        blocks.append(b)
        code_out.append(ranged(pname, w))
        epilogue.append(f"assign {pname} = {pr['expr']};")
        pending.append((b, pname, w, False))
        row += 1

    # One ball can hold one port bit: Icestudio writes a LOCATE per bit, and
    # nextpnr rejects a .lpf that names the same site twice.
    claimed: dict[str, str] = {}
    for b in blocks:
        if b["type"] not in ("basic.input", "basic.output"):
            continue
        for pin in b["data"]["pins"]:
            label = f"{b['data']['name']}[{pin['index']}]"
            if pin["value"] in claimed:
                raise SystemExit(
                    f"mkice: {os.path.basename(spec_path)} binds ball "
                    f"{pin['value']} ({pin['name']}) twice: "
                    f"{claimed[pin['value']]} and {label}.\n"
                    f"  Icestudio writes one LOCATE per bit, so nextpnr would "
                    f"see the same site named twice and refuse to place it.")
            claimed[pin["value"]] = label

    if prologue or epilogue:
        head = [
            "// ---------------------------------------------------------------",
            "// Added by tools/mkice.py, not present in the lesson's .v:",
            "// Icestudio declares a code block's outputs as wires, and the",
            "// board has fewer pins than this module has port bits. See",
            "// icestudio/README.md. The module's own text below is verbatim.",
            "// ---------------------------------------------------------------",
        ] + prologue + [""]
        body = "\n".join(head) + "\n" + body
    if epilogue:
        body = body.rstrip("\n") + "\n\n" + "\n".join(
            ["// ---- added by tools/mkice.py: port aliases and probes ----"]
            + epilogue) + "\n"

    code = block(
        "basic.code",
        {
            "code": body,
            "params": [{"name": n} for n, _ in params],
            "ports": {"in": code_in, "out": code_out},
        },
        X_CODE,
        Y_TOP,
        name,
    )
    blocks.append(code)

    # Constants feed the code block's parameters (Icestudio's generics).
    for i, (pname, pvalue) in enumerate(params):
        c = block(
            "basic.constant",
            {"name": pname, "value": str(pvalue), "local": False},
            X_CODE + 32,
            Y_TOP - 160 - i * 80,
            name,
        )
        blocks.append(c)
        wires.append({
            "source": {"block": c["id"], "port": "constant-out"},
            "target": {"block": code["id"], "port": pname},
        })

    if spec.get("info"):
        blocks.append(block(
            "basic.info",
            {"info": spec["info"], "readonly": True},
            X_IN, Y_TOP + max(len(code_in), len(code_out)) * Y_STEP + 64,
            name,
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
