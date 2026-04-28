#!/usr/bin/env bash
# Run the VG routing tests (AssetBus / ContextBroker / PluginRegistry).
#
# Exits non-zero on any failure so this script can be used in CI.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$ROOT/Godot_v4.6.1-stable_linux.x86_64"

if [[ ! -x "$GODOT" ]]; then
	echo "Godot binary not found at $GODOT" >&2
	exit 2
fi

# Symlink the test into test_proj if not already present, so res:// resolves.
if [[ ! -e "$ROOT/test_proj/test_vg_routing.gd" ]]; then
	ln -sf ../tests/test_vg_routing.gd "$ROOT/test_proj/test_vg_routing.gd"
fi

cd "$ROOT/test_proj"
output="$("$GODOT" --headless --script res://test_vg_routing.gd 2>&1)"
echo "$output"

if echo "$output" | grep -q "^\[FAIL\]"; then
	exit 1
fi
if ! echo "$output" | grep -q "^=== Done: .* 0 failed ===$"; then
	echo "Test runner did not report a Done line — something crashed." >&2
	exit 1
fi
exit 0
