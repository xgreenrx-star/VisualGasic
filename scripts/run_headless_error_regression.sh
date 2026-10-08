#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
OUT_DIR="${OUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/vg-headless-errors-XXXXXX")}"
mkdir -p "$OUT_DIR"
if [[ ! -x "$GODOT" ]]; then
	echo "ERROR: GODOT must name an executable engine" >&2
	exit 1
fi
for mode in default ast; do
	log="$OUT_DIR/$mode.log"
	rc=0
	if [[ "$mode" == ast ]]; then
		mode_args=(env VG_FORCE_AST=1)
	else
		mode_args=(env -u VG_FORCE_AST)
	fi
	timeout 10 "${mode_args[@]}" "$GODOT" --headless --path test_proj \
		-s run_suite.gd -- res://tools/headless_unhandled_error.vg > "$log" 2>&1 || rc=$?
	if [[ "$rc" -ne 0 ]] ||
			! grep -Fxq 'PASS: headless event loop continues' "$log" ||
			! grep -Fxq VG_SUITE_COMPLETED "$log" ||
			! grep -Fq '[VG Runtime Error 879]' "$log" ||
			! grep -Fq "Unhandled runtime error in '_Ready': Error 879" "$log" ||
			grep -Eq '^ERROR:|SCRIPT ERROR|handle_crash:|leaked at exit|were leaked' "$log"; then
		echo "FAIL: $mode headless unhandled error (exit=$rc); see $log" >&2
		tail -n 20 "$log" >&2
		exit 1
	fi
	echo "PASS: $mode unhandled error remains visible without a modal dialog"
done
echo "HEADLESS-ERROR RESULTS: 2 passed, 0 failed"
