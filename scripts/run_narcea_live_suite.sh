#!/usr/bin/env bash
# Multi-provider Narcea live eval — replays fixtures offline or calls live APIs.
#
# Offline (CI-safe):
#   NARCEA_LIVE=1 NARCEA_LIVE_SKIP_API=1 bash scripts/run_narcea_live_suite.sh
#
# Live Gemini:
#   NARCEA_LIVE=1 NARCEA_PROVIDER=gemini NARCEA_GEMINI_KEY=... bash scripts/run_narcea_live_suite.sh
#
# Live Ollama (local):
#   NARCEA_LIVE=1 NARCEA_PROVIDER=ollama NARCEA_MODEL=qwen2.5-coder:7b bash scripts/run_narcea_live_suite.sh
#
# Single scenario:
#   NARCEA_SCENARIO=counter_form ...
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$ROOT/Godot_v4.6.1-stable_linux.x86_64"
HOST="$ROOT/projects/vg_narcea_test"
SCRIPT="$ROOT/tests/test_narcea_live_suite.gd"
# HTTP timeout (NARCEA_LIVE_TIMEOUT) + headroom for scaffold/apply/rubric scoring.
HTTP_TIMEOUT="${NARCEA_LIVE_TIMEOUT:-180}"
TIMEOUT="${NARCEA_SUITE_TIMEOUT:-$((HTTP_TIMEOUT + 120))}"

export NARCEA_LIVE="${NARCEA_LIVE:-1}"

[[ -x "$GODOT" ]] || { echo "ERROR: Godot not found at $GODOT" >&2; exit 2; }
[[ -d "$HOST" ]] || { echo "ERROR: host project missing: $HOST" >&2; exit 2; }

echo "=== Narcea Live Suite Runner ==="
echo "Provider: ${NARCEA_PROVIDER:-gemini}  Skip API: ${NARCEA_LIVE_SKIP_API:-0}"
echo ""

output="$(timeout "$TIMEOUT" "$GODOT" --headless --path "$HOST" -s "$SCRIPT" 2>&1 || true)"
echo "$output"
if echo "$output" | grep -q "RESULTS: .* passed, 0 failed"; then
	echo ""
	echo "✅ Narcea live suite PASSED"
	exit 0
fi
echo ""
echo "❌ Narcea live suite FAILED"
exit 1
