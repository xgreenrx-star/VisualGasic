#!/usr/bin/env bash
# QB ABC Showcase — headless input smoke (launcher + engine key-edge regression).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJ="$ROOT/samples/showcases/qb_abc_showcase"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
USER_DATA="${VG_GODOT_USER_DATA_DIR:-${TMPDIR:-/tmp}/vg-qb-abc-headless-$$}"
mkdir -p "$USER_DATA"

if [[ ! -x "$GODOT" ]]; then
	echo "Godot not found: $GODOT" >&2
	exit 2
fi

if [[ -x "$ROOT/scripts/prepare_ci_gdextension.sh" ]]; then
	VG_GDEXTENSION_SO="${VG_GDEXTENSION_SO:-$ROOT/demo/bin/libvisualgasic.linux.template_debug.x86_64.so}" \
		"$ROOT/scripts/prepare_ci_gdextension.sh" "$PROJ" 2>/dev/null || true
fi

run_gd() {
	local proj="$1"
	local script="$2"
	local label="$3"
	echo "── $label ──"
	local out
	out="$(timeout 90 "$GODOT" --headless --path "$proj" \
		--user-data-dir "$USER_DATA" -s "$script" 2>&1 || true)"
	echo "$out"
	echo "$out" | grep -q "PASS: $label" || {
		echo "FAIL: missing PASS: $label" >&2
		return 1
	}
}

echo "=== QB ABC headless ==="
run_gd "$ROOT/test_proj" "res://run_input_key_edge_inject.gd" "input_key_edge_press"
run_gd "$PROJ" "res://run_headless_showcase_test.gd" "qb_abc_showcase_input"
echo "=== OK: qb abc headless ==="
