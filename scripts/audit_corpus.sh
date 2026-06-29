#!/bin/bash
# M2 corpus audit: run every corpus/*.vg, compare stdout to Expected output.
# Prints PASS/FAIL per file. Exits 0 only if all pass.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$ROOT/Godot_v4.6.1-stable_linux.x86_64"
TEST_PROJ="$ROOT/test_proj"
CORPUS="$ROOT/corpus"
PASS=0; FAIL=0

run_corpus_file() {
    local src="$1"
    local rel="${src#$ROOT/}"

    # Determine res:// path — copy to test_suite so the project can load it
    local basename="$(basename "$src")"
    local dest="$TEST_PROJ/test_suite/corpus_audit_tmp.vg"
    cp "$src" "$dest"
    echo "res://test_suite/corpus_audit_tmp.vg" > "$TEST_PROJ/current_test.txt"

    # Run and capture stdout (strip Godot engine banner + VG debug lines)
    local raw
    raw="$(timeout 15 "$GODOT" --headless --path "$TEST_PROJ" \
        -s run_corpus.gd 2>&1 || true)"

    # Filter to program-output lines only (skip engine/VG debug lines)
    local actual
    actual="$(echo "$raw" | grep -v "^Godot Engine\|^\[VisualGasic\]\|^\[VG\]\|^ERROR: \|^$\|^WARNING:\|^[[:space:]]*at: \|^Registered class:\|^Initialized Global Var:\|^Parser Error:\|^[[:space:]]*VisualGasic backtrace\|^[[:space:]]*\[[0-9]" | sed 's/[[:space:]]*$//' | sed '/^$/d')"

    # Extract expected output from trailing comment block
    local expected
    expected="$(grep "^'" "$src" | awk '
        /Expected output:/ { found=1; next }
        found { line=$0; sub(/^'"'"' ?/, "", line); print line }
    ' | sed 's/[[:space:]]*$//')"

    rm -f "$dest"

    if [ -z "$expected" ]; then
        echo "SKIP (no expected output): $rel"
        return
    fi

    if [ "$actual" = "$expected" ]; then
        echo "PASS: $rel"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $rel"
        echo "  expected: $(echo "$expected" | head -3 | sed 's/^/    /')"
        echo "  actual:   $(echo "$actual"   | head -3 | sed 's/^/    /')"
        FAIL=$((FAIL + 1))
    fi
}

for vg in $(find "$CORPUS" -name "*.vg" | sort); do
    run_corpus_file "$vg"
done

echo ""
echo "=== CORPUS AUDIT: $PASS pass, $FAIL fail ==="
[ "$FAIL" -eq 0 ]
