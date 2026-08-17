#!/usr/bin/env bash
# Narcea form smoke — headless chat-first synthesis path (no network).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$ROOT/Godot_v4.6.1-stable_linux.x86_64"
HOST="$ROOT/projects/vg_narcea_test"
SCRIPT="$ROOT/tests/test_narcea_form_smoke.gd"
TIMEOUT="${NARCEA_FORM_SMOKE_TIMEOUT:-60}"

[[ -x "$GODOT" ]] || { echo "ERROR: Godot not found at $GODOT" >&2; exit 2; }
[[ -d "$HOST" ]] || { echo "ERROR: host project missing: $HOST" >&2; exit 2; }

output="$(timeout "$TIMEOUT" "$GODOT" --headless --path "$HOST" -s "$SCRIPT" 2>&1 || true)"
echo "$output"
if echo "$output" | grep -q "RESULTS: .* passed, 0 failed"; then
	echo "✅ Narcea form smoke PASSED"
	exit 0
fi
echo "❌ Narcea form smoke FAILED"
exit 1
