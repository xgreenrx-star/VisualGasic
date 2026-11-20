#!/usr/bin/env bash
# Explicit known-defect lane — fail-closed judge (not grep-only).
# Defect: dual-import same-name Twin → first import (via_qual=11 @ mod_a).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT="${SEM_C2_KNOWN_OUT:-${RUNNER_TEMP:-/tmp}/vg-semantic-c2-known-defects}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
rm -f "$OUT/gate_status.txt" "$OUT/summary.txt"
echo "fail" >"$OUT/gate_status.txt"

if [[ -z "${GODOT:-}" || ! -x "$GODOT" ]]; then
	echo "ERROR: GODOT must be set" >&2
	echo "early_failure=missing_GODOT" >"$OUT/summary.txt"
	exit 1
fi

# Clear inherited mode env before applying intended mode.
unset VG_FORCE_AST VG_JIT VG_JIT_LOG || true

RES="res://test_suite/test_sem_c2_dual_import_twin_KNOWN_DEFECT.vg"
LOG="$OUT/dual_import_twin.log"
JUDGE_ERR="$OUT/dual_import_twin.judge.err"

set +e
env VG_SEM_PATH=1 VG_JIT=0 timeout 60 "$GODOT" --headless --path test_proj \
	--user-data-dir "$OUT/user_dual" \
	-s run_suite.gd -- "$RES" >"$LOG" 2>&1
rc=$?
set -e

set +e
line="$(python3 -m tools.semantic_fuzz.c2_known_defect_gate --log "$LOG" --exit-code "$rc" 2>"$JUDGE_ERR")"
jrc=$?
set -e

{
	echo "resource=$RES"
	echo "child_exit=$rc"
	echo "judge_exit=$jrc"
	echo "judge_line=$line"
	grep -E '^C2_KNOWN_DEFECT|^C2_KNOWN_DEFECT_|^OBSERVED|^EXPECTED_CORRECT|^PASS:|^FAIL:|^VG_SEM_PATH.*Twin|^VG_SUITE_COMPLETED' "$LOG" || true
} | tee "$OUT/summary.txt"

if [[ "$jrc" -ne 0 ]]; then
	echo "ERROR: known-defect gate FAIL — see $OUT/summary.txt" >&2
	echo "fail" >"$OUT/gate_status.txt"
	exit 1
fi
if [[ "$line" != OK* ]]; then
	echo "ERROR: known-defect gate malformed OK line: $line" >&2
	echo "fail" >"$OUT/gate_status.txt"
	exit 1
fi

echo "ok_known_defects_visible" >"$OUT/gate_status.txt"
echo "==> C2 known-defect lane OK (exact defect signature still visible): $OUT/summary.txt"
