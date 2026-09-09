#!/usr/bin/env bash
# Headless tests for labeled vector Data blocks (resolver, sync, VGV I/O).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
HOST="${HOST_PROJECT:-$ROOT/test_proj}"

if [[ ! -x "$GODOT" ]]; then
	echo "Godot binary not found at $GODOT" >&2
	exit 2
fi

echo "── vector_data headless tests (host: $HOST) ──"
out="$(timeout 60 "$GODOT" --headless --path "$HOST" -s "$ROOT/tests/test_vector_data_resolver.gd" 2>&1)" || ec=$?
echo "$out"
if ! echo "$out" | grep -q "RESULTS:.*0 failed"; then
	if [[ "${ec:-0}" -ne 0 ]]; then
		exit 1
	fi
	exit 1
fi
echo "ok"
