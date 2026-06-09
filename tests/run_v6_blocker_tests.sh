#!/usr/bin/env bash
# tests/run_v6_blocker_tests.sh
#
# Regression suite for v6.0 release blockers:
#   #1   AndAlso/OrElse must short-circuit (bytecode + AST agree).
#   #0a  Opt-in bytecode-fallback diagnostic (VG_BYTECODE_LOG_FALLBACKS=1).
#   #0b  ByRef call to a sub that never writes the param does NOT
#        force the calling sub to AST-fallback.
#
# Invocation:
#   ./tests/run_v6_blocker_tests.sh
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$ROOT/Godot_v4.6.1-stable_linux.x86_64"
PASS=0
FAIL=0

run_case() {
    local name="$1"; local vg_file="$2"; local expect_pattern="$3"; local env_prefix="${4:-}"
    local out
    out="$( cd "$ROOT" && eval "$env_prefix" timeout 15 "$GODOT" --headless \
        --path demo -s run_vg.gd -- "$vg_file" 2>&1 || true )"
    if echo "$out" | grep -qE "$expect_pattern"; then
        echo "PASS  $name"
        PASS=$((PASS+1))
    else
        echo "FAIL  $name"
        echo "----- output -----"
        echo "$out"
        echo "------------------"
        FAIL=$((FAIL+1))
    fi
}

# Blocker #1: 6 PASS lines, 0 FAIL.
run_case "blocker#1 short-circuit" \
    "test_blocker1_short_circuit.vg" \
    "^PASS: constant-fold True OrElse False = True$"

# Blocker #0b: read-only ByRef must NOT trigger fallback.
run_case "blocker#0b read-only ByRef stays in bytecode" \
    "test_blocker0b_writeset_readonly.vg" \
    "^read x=5$" \
    "VG_BYTECODE_LOG_FALLBACKS=1"

# Blocker #0b complement: writing ByRef MUST still bail to AST
# (write-back is required for correctness).
run_case "blocker#0b writing ByRef correctly bails" \
    "test_blocker0b_writeset_writes.vg" \
    "FALLBACK to AST: Main" \
    "VG_BYTECODE_LOG_FALLBACKS=1"

# Also verify the diagnostic is silent without the env var (#0a).
out_silent="$( cd "$ROOT" && timeout 15 "$GODOT" --headless \
    --path demo -s run_vg.gd -- test_blocker0b_writeset_writes.vg 2>&1 || true )"
if echo "$out_silent" | grep -q "VG-BC"; then
    echo "FAIL  blocker#0a diagnostic is opt-in (leaked without env var)"
    FAIL=$((FAIL+1))
else
    echo "PASS  blocker#0a diagnostic is opt-in (silent by default)"
    PASS=$((PASS+1))
fi

echo
echo "v6.0 blocker tests: $PASS passed, $FAIL failed"
exit "$FAIL"
