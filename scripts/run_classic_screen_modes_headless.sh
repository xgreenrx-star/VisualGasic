#!/usr/bin/env bash
# Classic SCREEN modes showcase — headless launcher smoke.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJ="$ROOT/samples/showcases/classic_screen_modes"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
USER_DATA="${VG_GODOT_USER_DATA_DIR:-${TMPDIR:-/tmp}/vg-classic-modes-headless-$$}"
mkdir -p "$USER_DATA"

if [[ ! -x "$GODOT" ]]; then
	echo "Godot not found: $GODOT" >&2
	exit 2
fi

if [[ -x "$ROOT/scripts/prepare_ci_gdextension.sh" ]]; then
	VG_GDEXTENSION_SO="${VG_GDEXTENSION_SO:-$ROOT/demo/bin/libvisualgasic.linux.template_debug.x86_64.so}" \
		"$ROOT/scripts/prepare_ci_gdextension.sh" "$PROJ" 2>/dev/null || true
fi

echo "=== Classic SCREEN modes headless ==="
out="$(timeout 90 "$GODOT" --headless --path "$PROJ" \
	--user-data-dir "$USER_DATA" -s res://run_headless_classic_modes_test.gd 2>&1 || true)"
echo "$out"
echo "$out" | grep -q "PASS: classic_screen_modes_menu" || {
	echo "FAIL: classic screen modes headless" >&2
	exit 1
}
echo "=== OK: classic screen modes headless ==="
