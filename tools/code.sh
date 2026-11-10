#!/usr/bin/env bash
# Launch VS Code with the FPGA toolchain already on PATH.
#
# Why this exists: VS Code extensions inherit the environment of the process
# that launched the editor. Started from the Dock, that environment has a bare
# PATH, so the Verilog extension cannot find verilator/iverilog and linting
# silently does nothing. Launching through this script fixes it for the whole
# editor session — linting, tasks and the integrated terminal alike.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$ROOT/toolchain/oss-cad-suite/bin:$PATH"

CODE="code"
command -v code >/dev/null 2>&1 || \
  CODE="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"

[ -x "$CODE" ] || { echo "VS Code CLI not found. Install it from the Command"
                    echo "Palette: 'Shell Command: Install code in PATH'."; exit 1; }
exec "$CODE" "$ROOT" "$@"
