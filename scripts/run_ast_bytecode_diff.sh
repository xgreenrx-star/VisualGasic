#!/usr/bin/env bash
# ============================================================================
# Bytecode vs AST differential harness
# ============================================================================
# Runs the same .vg tests twice:
#   1) default path (bytecode VM when compilation succeeds)
#   2) VG_FORCE_AST=1 (AST tree-walk only)
# Diffs PASS:/FAIL: lines and checks execution status. Any mismatch is a
# dual-path bug candidate; crashes, timeouts, runtime errors and empty runs fail.
#
# Usage:
#   ./scripts/run_ast_bytecode_diff.sh              # default hot set
#   ./scripts/run_ast_bytecode_diff.sh test_byref*  # filter (suite basename glob)
#   ./scripts/run_ast_bytecode_diff.sh --all        # every suite test_*.vg
#
# Env:
#   GODOT — Godot binary (auto-detected like run_test_suite.sh)
#   TIMEOUT_SECS — per-test timeout (default 20)
# ============================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TEST_DIR="test_proj/test_suite"
RUNNER="run_suite.gd"
TIMEOUT_SECS="${TIMEOUT_SECS:-20}"
OUT_DIR="${TMPDIR:-/tmp}/vg-ast-bc-diff-$$"
mkdir -p "$OUT_DIR"

# Default hot set: arithmetic, ByRef, Godot ctors, nested calls — dual-path landmines.
DEFAULT_HOT=(
	test_operators.vg
	test_math_funcs.vg
	test_constants.vg
	test_boolean_or_regression.vg
	test_byref_array_slot.vg
	test_byref_byval.vg
	test_byref_ast_import.vg
	test_byref_import.vg
	test_vector2_direct.vg
	test_vector2i_direct.vg
	test_vector2i_bytecode.vg
	test_vector2i_new_empty.vg
	test_vector2_int_args.vg
	test_vector2_subtract_normalized.vg
	test_color_direct.vg
	test_color_constants.vg
	test_nested_same_object_call.vg
	test_array_bracket_index.vg
	test_array_func_arg.vg
	test_arrays.vg
	test_for_loop.vg
	test_loop_var_modify.vg
	test_classdb_instantiate.vg
	test_variant_tostring.vg
)

FILTERS=()
USE_ALL=0
while [[ $# -gt 0 ]]; do
	case "$1" in
		--all) USE_ALL=1; shift ;;
		*) FILTERS+=("$1"); shift ;;
	esac
done

# Godot binary detection (mirrors run_test_suite.sh)
GODOT="${GODOT:-}"
if [[ -z "$GODOT" || ! -x "$GODOT" ]]; then
	for candidate in \
		"./Godot_v4.6.1-stable_linux.x86_64" \
		"./Godot_v4.6-stable_linux.x86_64" \
		"./Godot_v4.5.1-stable_linux.x86_64" \
		./Godot_v4.6*_linux.x86_64 \
		./Godot_v4.5*_linux.x86_64; do
		if [[ -x "$candidate" ]]; then
			GODOT="$candidate"
			break
		fi
	done
fi
if [[ -z "$GODOT" || ! -x "$GODOT" ]]; then
	echo "ERROR: Godot binary not found" >&2
	exit 1
fi

GODOT_USER_DATA_DIR="${VG_GODOT_USER_DATA_DIR:-${TMPDIR:-/tmp}/vg-godot-user-diff-$$}"
mkdir -p "$GODOT_USER_DATA_DIR"
GODOT_BASE_ARGS=(--headless --path test_proj --user-data-dir "$GODOT_USER_DATA_DIR" -s "$RUNNER")

collect_tests() {
	if [[ "$USE_ALL" -eq 1 ]]; then
		find "$TEST_DIR" -name 'test_*.vg' -type f -printf '%f\n' | sort
		return
	fi
	if [[ ${#FILTERS[@]} -gt 0 ]]; then
		for filter in "${FILTERS[@]}"; do
			find "$TEST_DIR" -name '*.vg' -name "$filter" -type f -printf '%f\n'
		done | sort -u
		return
	fi
	for f in "${DEFAULT_HOT[@]}"; do
		[[ -f "$TEST_DIR/$f" ]] && echo "$f"
	done
}

mapfile -t TEST_FILES < <(collect_tests)
if [[ ${#TEST_FILES[@]} -eq 0 ]]; then
	echo "No matching tests."
	exit 1
fi

echo "╔══════════════════════════════════════════════════╗"
echo "║  VG AST ↔ bytecode differential                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo "Godot: $GODOT"
echo "Tests: ${#TEST_FILES[@]}"
echo "Out:   $OUT_DIR"
echo ""

# Smoke: bytecode path must produce PASS
smoke_rc=0
smoke_out=$(timeout "$TIMEOUT_SECS" env -u VG_FORCE_AST "$GODOT" "${GODOT_BASE_ARGS[@]}" -- res://test_suite/test_arr_simple.vg 2>&1) || smoke_rc=$?
if [[ "$smoke_rc" -ne 0 ]] || ! echo "$smoke_out" | grep -q "^PASS:" || ! echo "$smoke_out" | grep -q '^VG_SUITE_COMPLETED$'; then
	echo "FATAL: GDExtension smoke failed (bytecode path)"
	echo "$smoke_out" | tail -40
	exit 1
fi

# Smoke: AST force must also load and run (may FAIL assertions — that's OK for smoke)
# We only require the process not crash and that VG prints something.
smoke_rc=0
smoke_ast=$(timeout "$TIMEOUT_SECS" env VG_FORCE_AST=1 "$GODOT" "${GODOT_BASE_ARGS[@]}" -- res://test_suite/test_arr_simple.vg 2>&1) || smoke_rc=$?
if [[ "$smoke_rc" -ne 0 ]] || ! echo "$smoke_ast" | grep -q '^PASS:' || ! echo "$smoke_ast" | grep -q '^VG_SUITE_COMPLETED$'; then
	echo "FATAL: VG_FORCE_AST smoke failed"
	echo "$smoke_ast" | tail -40
	exit 1
fi
echo "Smoke OK (default + forced AST)"
echo ""

extract_assertions() {
	# Normalize: only PASS:/FAIL: lines, strip trailing CR, sort for set-diff friendliness
	grep -E '^(PASS|FAIL):' "$1" 2>/dev/null | sed 's/\r$//' | sort || true
}

MISMATCHES=0
BOTH_OK=0
BC_ONLY_FAIL=0
AST_ONLY_FAIL=0
BOTH_FAIL=0
NO_ASSERT=0
EXEC_FAILURES=0

for fname in "${TEST_FILES[@]}"; do
	bc_raw="$OUT_DIR/${fname}.bc.raw"
	ast_raw="$OUT_DIR/${fname}.ast.raw"
	bc_assert="$OUT_DIR/${fname}.bc.txt"
	ast_assert="$OUT_DIR/${fname}.ast.txt"

	bc_rc=0
	ast_rc=0
	timeout "$TIMEOUT_SECS" env -u VG_FORCE_AST "$GODOT" "${GODOT_BASE_ARGS[@]}" -- "res://test_suite/$fname" >"$bc_raw" 2>&1 || bc_rc=$?
	timeout "$TIMEOUT_SECS" env VG_FORCE_AST=1 "$GODOT" "${GODOT_BASE_ARGS[@]}" -- "res://test_suite/$fname" >"$ast_raw" 2>&1 || ast_rc=$?
	if [[ "$bc_rc" -ne 0 || "$ast_rc" -ne 0 ]] ||
		! grep -q '^VG_SUITE_COMPLETED$' "$bc_raw" ||
		! grep -q '^VG_SUITE_COMPLETED$' "$ast_raw" ||
		grep -qE '^\[VG Runtime Error|^SCRIPT ERROR:|^ERROR:.*(Failed to load|Cannot open)|handle_crash:|Segmentation fault|Aborted' "$bc_raw" "$ast_raw"; then
		echo "  EXEC-FAIL  $fname  (bc rc=$bc_rc ast rc=$ast_rc; inspect raw logs)"
		EXEC_FAILURES=$((EXEC_FAILURES + 1))
		continue
	fi

	extract_assertions "$bc_raw" >"$bc_assert"
	extract_assertions "$ast_raw" >"$ast_assert"

	bc_pass=$(grep -c '^PASS:' "$bc_assert" || true)
	bc_fail=$(grep -c '^FAIL:' "$bc_assert" || true)
	ast_pass=$(grep -c '^PASS:' "$ast_assert" || true)
	ast_fail=$(grep -c '^FAIL:' "$ast_assert" || true)

	if [[ ! -s "$bc_assert" && ! -s "$ast_assert" ]]; then
		echo "  ???  $fname  (no assertions either path)"
		NO_ASSERT=$((NO_ASSERT + 1))
		continue
	fi

	if cmp -s "$bc_assert" "$ast_assert"; then
		if [[ "$bc_fail" -gt 0 || "$ast_fail" -gt 0 ]]; then
			echo "  BOTH-FAIL  $fname  (bc $bc_pass/$bc_fail  ast $ast_pass/$ast_fail) — same FAIL set"
			BOTH_FAIL=$((BOTH_FAIL + 1))
		else
			echo "  OK         $fname  (bc=$bc_pass  ast=$ast_pass)"
			BOTH_OK=$((BOTH_OK + 1))
		fi
		continue
	fi

	MISMATCHES=$((MISMATCHES + 1))
	echo "  DIFF       $fname  (bc pass=$bc_pass fail=$bc_fail  ast pass=$ast_pass fail=$ast_fail)"
	diff -u "$bc_assert" "$ast_assert" | sed 's/^/       /' || true

	if [[ "$bc_fail" -eq 0 && "$ast_fail" -gt 0 ]]; then
		AST_ONLY_FAIL=$((AST_ONLY_FAIL + 1))
	elif [[ "$ast_fail" -eq 0 && "$bc_fail" -gt 0 ]]; then
		BC_ONLY_FAIL=$((BC_ONLY_FAIL + 1))
	fi
done

echo ""
echo "══════════════════════════════════════════════════"
echo "SUMMARY"
echo "  Matched OK:     $BOTH_OK"
echo "  Matched FAIL:   $BOTH_FAIL"
echo "  Mismatches:     $MISMATCHES"
echo "    AST-only fail:$AST_ONLY_FAIL"
echo "    BC-only fail: $BC_ONLY_FAIL"
echo "  No assertions:  $NO_ASSERT"
echo "  Execution fail: $EXEC_FAILURES"
echo "  Artifacts:      $OUT_DIR"
echo ""

if [[ "$MISMATCHES" -gt 0 || "$BOTH_FAIL" -gt 0 || "$NO_ASSERT" -gt 0 || "$EXEC_FAILURES" -gt 0 ]]; then
	echo "TEST FAILURES — investigate divergences, failed assertions and execution logs above"
	exit 1
fi
echo "All compared tests agree across bytecode and AST paths."
exit 0
