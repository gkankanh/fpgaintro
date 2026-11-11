#!/usr/bin/env bash
# ===========================================================================
#  tools/install.sh — get a new machine ready for this course.
#
#  Installs the open FPGA toolchain (yosys, nextpnr-ecp5, prjtrellis,
#  iverilog, verilator, gtkwave, openFPGALoader) into ./toolchain/, which is
#  gitignored. Nothing is installed system-wide and nothing needs sudo, so
#  removing the toolchain/ directory undoes everything this script does.
#
#      tools/install.sh                 # the FPGA toolchain (required)
#      tools/install.sh --with-riscv    # + a RISC-V C compiler (lesson 13+)
#      tools/install.sh --with-docs     # + mdbook, to build the lesson site
#      tools/install.sh --with-pdf      # + typst, to build the course book
#      tools/install.sh --all           # everything
#
#  The lessons themselves need only the base install. The extras are called
#  out by the lessons that use them.
# ===========================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TC="$ROOT/toolchain"
WITH_RISCV=0
WITH_DOCS=0
WITH_PDF=0

for a in "$@"; do
  case "$a" in
    --with-riscv) WITH_RISCV=1 ;;
    --with-docs)  WITH_DOCS=1 ;;
    --all)        WITH_RISCV=1; WITH_DOCS=1 ;;
    -h|--help)    sed -n '3,18p' "$0" | sed 's/^#  \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $a (try --help)"; exit 1 ;;
  esac
done

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
note() { printf '    %s\n' "$*"; }
die()  { printf '\n\033[31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

# ------------------------------------------------------- platform detection --
OS="$(uname -s)"; ARCH="$(uname -m)"
case "$OS/$ARCH" in
  Darwin/arm64)         PLAT=darwin-arm64 ;;
  Darwin/x86_64)        PLAT=darwin-x64 ;;
  Linux/x86_64)         PLAT=linux-x64 ;;
  Linux/aarch64|Linux/arm64) PLAT=linux-arm64 ;;
  *) die "unsupported platform $OS/$ARCH. Build the toolchain from source, or
     install oss-cad-suite manually into $TC/oss-cad-suite." ;;
esac
say "Platform: $PLAT"

for c in curl tar python3 make git; do
  command -v "$c" >/dev/null || die "'$c' is required but not installed."
done

# --------------------------------------------------- 1. the FPGA toolchain --
if [ -x "$TC/oss-cad-suite/bin/yosys" ]; then
  say "FPGA toolchain already present"
  note "$("$TC/oss-cad-suite/bin/yosys" -V | head -1)"
  note "to reinstall: rm -rf $TC/oss-cad-suite && tools/install.sh"
else
  say "Installing the open FPGA toolchain (oss-cad-suite, ~1 GB download)"
  note "Source: github.com/YosysHQ/oss-cad-suite-build"

  # Ask GitHub for the newest release rather than pinning a date that rots.
  API=https://api.github.com/repos/YosysHQ/oss-cad-suite-build/releases/latest
  TAG="$(curl -fsSL "$API" | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')" \
    || die "could not reach GitHub to find the latest toolchain release."
  STAMP="${TAG//-/}"
  URL="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/$TAG/oss-cad-suite-$PLAT-$STAMP.tgz"
  note "Release: $TAG"

  mkdir -p "$TC"
  TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
  curl -fL --progress-bar "$URL" -o "$TMP/oss-cad-suite.tgz" \
    || die "download failed: $URL"
  note "Unpacking..."
  tar -xzf "$TMP/oss-cad-suite.tgz" -C "$TC"
  [ -x "$TC/oss-cad-suite/bin/yosys" ] || die "unpacked, but yosys is not where expected."

  # macOS quarantines downloaded binaries; without this every tool prompts.
  if [ "$OS" = Darwin ]; then
    note "Clearing macOS quarantine flags..."
    xattr -dr com.apple.quarantine "$TC/oss-cad-suite" 2>/dev/null || true
  fi
fi

# --------------------------------------------------- 2. RISC-V C compiler ---
if [ "$WITH_RISCV" = 1 ]; then
  say "Installing a RISC-V C compiler (needed from lesson 13)"
  if command -v riscv64-unknown-elf-gcc >/dev/null || command -v riscv64-elf-gcc >/dev/null; then
    note "already installed"
  elif command -v brew >/dev/null; then
    # riscv-software-src/riscv tap carries a prebuilt bare-metal toolchain.
    brew tap riscv-software-src/riscv 2>/dev/null || true
    brew install riscv-tools || note "brew install failed; see the note below"
  elif command -v apt-get >/dev/null; then
    note "run: sudo apt-get install gcc-riscv64-unknown-elf"
  else
    note "no package manager found."
  fi
  command -v riscv64-unknown-elf-gcc >/dev/null || {
    note "If this did not work, prebuilt toolchains are available from"
    note "  github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases"
    note "Lessons 00-12 do not need it; only lesson 13 onward compiles C."
  }
fi

# ------------------------------------------------------------- 3. mdbook ----
if [ "$WITH_DOCS" = 1 ]; then
  say "Installing mdbook (builds the lesson site)"
  if command -v mdbook >/dev/null; then note "already installed: $(mdbook --version)"
  elif command -v brew  >/dev/null; then brew install mdbook
  elif command -v cargo >/dev/null; then cargo install mdbook
  else note "install Rust (rustup.rs) then: cargo install mdbook"; fi
fi

# -------------------------------------------------------------- 4. typst ----
if [ "$WITH_PDF" = 1 ]; then
  say "Installing typst (typesets the course book)"
  if command -v typst >/dev/null; then note "already installed: $(typst --version)"
  elif command -v brew  >/dev/null; then brew install typst
  elif command -v cargo >/dev/null; then cargo install --locked typst-cli
  else
    note "no package manager found. typst is a single binary:"
    note "  https://github.com/typst/typst/releases"
  fi
fi

# ------------------------------------------------------------- 5. verify ----
say "Verifying"
exec "$ROOT/tools/check.sh"
