#!/bin/bash
# Run each corpus example, exercise declared host scenarios, compare output.
# Prints PASS/FAIL per file. Exits 0 only if all pass.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
TEST_PROJ="$ROOT/test_proj"
CORPUS="${VG_CORPUS_DIR:-$ROOT/corpus}"
GODOT_USER_DATA_DIR="${VG_GODOT_USER_DATA_DIR:-${TMPDIR:-/tmp}/vg-godot-corpus-$$}"
PASS=0; FAIL=0; SKIP=0

if [[ ! -x "$GODOT" ]]; then
  GODOT="$(command -v godot || true)"
fi
if [[ -z "$GODOT" || ! -x "$GODOT" ]]; then
  echo "No Godot binary found. Set GODOT=..." >&2
  exit 2
fi

mkdir -p "$GODOT_USER_DATA_DIR"
AUDIT_DIR="$(mktemp -d "$TEST_PROJ/corpus-audit-XXXXXX")"
cleanup() {
    rm -rf -- "$AUDIT_DIR"
    if [[ -z "${VG_GODOT_USER_DATA_DIR:-}" ]]; then
        rm -rf -- "$GODOT_USER_DATA_DIR"
    fi
}
trap cleanup EXIT
cp -R "$CORPUS/." "$AUDIT_DIR/"
mkdir -p "$TEST_PROJ/.godot"
if [[ ! -f "$TEST_PROJ/.godot/extension_list.cfg" ]]; then
  printf '%s\n' 'res://addons/visual_gasic/visual_gasic.gdextension' \
    >"$TEST_PROJ/.godot/extension_list.cfg"
fi

runtime_errors_match() {
    local src="$1" raw="$2" expected actual count parsed_count
    expected="$(awk '
        /^'\'' Expected handled errors:/ { found=1; next }
        /^'\'' Expected output:/ { found=0 }
        found && /^'\'' [0-9]+\|/ { sub(/^'\'' /, ""); print }
    ' "$src")"
    actual="$(sed -nE 's/^\[VG (Runtime|Handled) Error ([0-9]+)\].*Sub: ([^ ]+) Line: ([0-9]+) .*$/\2|\3|\4/p' <<<"$raw")"
    count="$(grep -cE '^\[VG (Runtime|Handled) Error' <<<"$raw" || true)"
    parsed_count="$(grep -c . <<<"$actual" || true)"
    [[ "$count" -eq "$parsed_count" && "$actual" == "$expected" ]]
}

run_corpus_file() {
    local src="$1"
    local rel="${src#$ROOT/}"
    local expected
    expected="$(grep "^'" "$src" 2>/dev/null | awk '
        /Expected output:/ { found=1; next }
        found { line=$0; sub(/^'"'"' ?/, "", line); print line }
    ' | sed 's/[[:space:]]*$//' | sed '/^$/d')"
    if [ -z "$expected" ]; then
        echo "SKIP (no expected output): $rel"
        SKIP=$((SKIP + 1))
        return
    fi

    # Preserve sibling Include paths and avoid shared current_test.txt state.
    local resource="res://${AUDIT_DIR#$TEST_PROJ/}/${src#$CORPUS/}"

    # Run and capture stdout (strip Godot engine banner + VG debug lines)
    local raw
    local rc=0
    raw="$(timeout 15 "$GODOT" --headless --path "$TEST_PROJ" \
        --user-data-dir "$GODOT_USER_DATA_DIR" \
        -s run_corpus.gd -- "$resource" 2>&1)" || rc=$?

    # Filter to program-output lines only (skip engine/VG debug lines)
    local actual
    actual="$(echo "$raw" | { grep -v "^Godot Engine\|^\[VisualGasic\]\|^\[VG\]\|^\[VG Runtime Error\|^\[VG Handled Error\|^\[VGSocket\] Connected to 127\.0\.0\.1:[0-9][0-9]*$\|^\[PyBridgeFacade\] Tier A.*worker connected (Python \|^\[PyBridgeFacade\] Worker launched (PID [0-9][0-9]*)$\|^\[PyBridgeFacade\] Shutting down\.\.\.$\|^\[PyBridgeFacade\] Worker (PID [0-9][0-9]*) terminated$\|^Including file:\|^VG_CORPUS_COMPLETED$\|^ERROR: \|^$\|^WARNING:\|^[[:space:]]*at: \|^Registered class:\|^Initialized Global Var:\|^Parser Error:\|^[[:space:]]*VisualGasic backtrace\|^[[:space:]]*\[[0-9]" || true; } | sed 's/[[:space:]]*$//' | sed '/^$/d')"

    if [ "$rc" -ne 0 ] || [[ "$raw" != *"VG_CORPUS_COMPLETED"* ]] ||
        ! runtime_errors_match "$src" "$raw" ||
        grep -qE '^SCRIPT ERROR|^ERROR:|^Parser Error|^\[VG\] Parser Error|^Unhandled runtime error|^VisualGasic: Unhandled exception|^FAIL:|ASSERT.*FAIL' <<<"$raw"; then
        echo "FAIL (execution incomplete or errored, rc=$rc): $rel"
        printf '%s\n' "$raw" | head -8 || true
        FAIL=$((FAIL + 1))
    elif [ "$actual" = "$expected" ]; then
        echo "PASS: $rel"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $rel"
        diff -u --label expected --label actual <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") || true
        FAIL=$((FAIL + 1))
    fi
}

while IFS= read -r -d '' vg; do
    run_corpus_file "$vg"
done < <(find "$CORPUS" -name "*.vg" -print0 | sort -z)

if [[ "$PASS" -eq 0 && "$FAIL" -eq 0 && "$SKIP" -eq 0 ]]; then
    echo "ERROR: No corpus examples found in $CORPUS" >&2
    exit 2
fi

echo ""
echo "=== CORPUS AUDIT: $PASS pass, $FAIL fail, $SKIP skipped ==="
[ "$PASS" -gt 0 ] && [ "$FAIL" -eq 0 ] && [ "$SKIP" -eq 0 ]
