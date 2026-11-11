#!/usr/bin/env bash
# Run this lesson's proofs and print one PASS/FAIL line, so that formal
# verification joins the course-wide regression suite like any other lesson.
#
#   ./run-proofs.sh          the fast proofs (a few seconds)
#   ./run-proofs.sh --all    including the register file (about a minute)
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
export PATH="$PWD/../toolchain/oss-cad-suite/bin:$PATH"

command -v sby >/dev/null || { echo "FAIL: sby not found — run tools/install.sh"; exit 1; }

fail=0
rf="not run (use --all)"
run() {  # name  sbyfile  task  what-counts-as-success
    local name="$1" f="$2" t="${3:-}" want="$4"
    printf '  %-34s ' "$name"
    out=$(sby -f "$f" $t 2>&1); rc=$?
    # `expect` in the .sby file makes rc 0 whenever the outcome was the
    # intended one, so rc is the verdict even for proofs meant to fail.
    if [ $rc -eq 0 ]; then
        printf '%s\n' "$want"
    else
        printf 'UNEXPECTED (rc=%d)\n' "$rc"; fail=1
        echo "$out" | grep -E "failed assertion|Unreached|ERROR" | head -3 | sed 's/^/      /'
    fi
}

echo "Proofs:"
run "ALU correct for all 2**64 inputs"  alu.sby      prove  "proved"
run "ALU properties are not vacuous"    alu.sby      cover  "all covers reached"
if [ "${1:-}" = "--all" ]; then
    run "register file, every 12-op seq"  regfile.sby prove  "proved"
    run "register file covers"            regfile.sby cover  "all covers reached"
    rf="proved for every 12-operation sequence"
fi
echo "Demonstrations:"
run "broken ALU is caught"              broken.sby   ""     "counterexample found, as intended"
run "over-assumption still 'proves'"    vacuous.sby  prove  "passed, as intended"
run "...and cover detects it"           vacuous.sby  cover  "cover unreachable, as intended"

echo ""
if [ $fail -eq 0 ]; then
    # Claim only what was actually run. A lesson about proof should not
    # overstate its own result.
    echo "PASS: ALU proved correct for every one of 2**64 inputs; register file $rf;"
    echo "      both demonstrations behaved as designed"
else
    echo "FAIL: a proof did not behave as expected"
fi
exit $fail
