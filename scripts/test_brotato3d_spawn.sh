#!/usr/bin/env bash
# Headless spawn/combat stress for brotato3d — catches main-loop deadlocks on mob spawn/hit.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
PROJ="$ROOT/samples/games/brotato3d"

if [[ ! -x "$GODOT" ]]; then
	echo "Godot binary not found at $GODOT" >&2
	exit 2
fi

run_test() {
	local script="$1"
	echo "── $script ──"
	cd "$PROJ"
	local output
	output="$(timeout 90 "$GODOT" --headless --path . --script "$script" 2>&1 || true)"
	echo "$output"
	if echo "$output" | grep -q "^PASS:"; then
		return 0
	fi
	echo "FAIL: $script did not PASS" >&2
	return 1
}

echo "=== Brotato3D headless regression ==="
run_test "test_combat_with_mobs.gd"
run_test "test_spawn_stress.gd"
echo "=== OK: brotato3d spawn stress passed ==="
