#!/usr/bin/env bash
# Climatist POC — headless VG tests (offline parse + optional live HTTP smoke).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJ="$ROOT/samples/apps/climatist_poc"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
RUNNER="$PROJ/run_headless_vg_test.gd"
USER_DATA="${VG_GODOT_USER_DATA_DIR:-${TMPDIR:-/tmp}/vg-climatist-headless-$$}"
mkdir -p "$USER_DATA"

if [[ ! -x "$GODOT" ]]; then
	echo "Godot not found: $GODOT" >&2
	exit 2
fi

# Ensure GDExtension .so is materialized for this sample (symlink-safe).
if [[ -x "$ROOT/scripts/prepare_ci_gdextension.sh" ]]; then
	VG_GDEXTENSION_SO="${VG_GDEXTENSION_SO:-$ROOT/demo/bin/libvisualgasic.linux.template_debug.x86_64.so}" \
		"$ROOT/scripts/prepare_ci_gdextension.sh" "$PROJ" 2>/dev/null || true
fi

run_vg_test() {
	local vg_file="$1"
	local timeout_sec="${2:-45}"
	echo "── headless $vg_file ──"
	local output
	output="$(timeout "$timeout_sec" "$GODOT" --headless --path "$PROJ" \
		--user-data-dir "$USER_DATA" -s "$RUNNER" "$vg_file" 2>&1 || true)"
	echo "$output"
	if echo "$output" | grep -q "PASS: climatist_pattern_parse"; then
		return 0
	fi
	if echo "$output" | grep -qE "^PASS:"; then
		return 0
	fi
	echo "FAIL: no PASS line for $vg_file" >&2
	return 1
}

echo "=== Climatist POC headless ==="
run_vg_test "res://test_pattern_parse.vg" 60
run_vg_test "res://test_http_util.vg" 60
run_vg_test "res://test_climatist_fixtures.vg" 60

echo "=== OK: climatist headless (offline parse) ==="
echo "Tip: full Pattern HTTP (30 years) is not automated here — Open-Meteo rate-limits burst requests."
