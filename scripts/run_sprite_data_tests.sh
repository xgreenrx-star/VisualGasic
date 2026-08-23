#!/usr/bin/env bash
# Headless tests for labeled sprite Data blocks (resolver, sync, palettes).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
HOST="${HOST_PROJECT:-$ROOT/test_proj}"

if [[ ! -x "$GODOT" ]]; then
	echo "Godot binary not found at $GODOT" >&2
	exit 2
fi

echo "── sprite_data headless tests (host: $HOST) ──"
out="$(timeout 60 "$GODOT" --headless --path "$HOST" -s "$ROOT/tests/test_sprite_data_resolver.gd" 2>&1)" || ec=$?
echo "$out"
if ! echo "$out" | grep -q "RESULTS:.*0 failed"; then
	if [[ "${ec:-0}" -ne 0 ]]; then
		exit 1
	fi
	exit 1
fi

echo ""
echo "── context_analyzer headless tests (host: $HOST) ──"
out2="$(timeout 60 "$GODOT" --headless --path "$HOST" -s "$ROOT/tests/test_context_analyzer.gd" 2>&1)" || ec2=$?
echo "$out2"
if ! echo "$out2" | grep -q "RESULTS:.*0 failed"; then
	if [[ "${ec2:-0}" -ne 0 ]]; then
		exit 1
	fi
	exit 1
fi

echo ""
echo "── literal_resolver headless tests (host: $HOST) ──"
out3="$(timeout 60 "$GODOT" --headless --path "$HOST" -s "$ROOT/tests/test_literal_resolver.gd" 2>&1)" || ec3=$?
echo "$out3"
if echo "$out3" | grep -q "RESULTS:.*0 failed"; then
	exit 0
fi
if [[ "${ec3:-0}" -ne 0 ]]; then
	exit 1
fi
exit 1
