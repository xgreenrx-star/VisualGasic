#!/usr/bin/env bash
# Provider matrix — run Narcea offline suite per provider and append metrics CSV.
#
# Usage:
#   bash scripts/run_narcea_provider_matrix.sh
#   NARCEA_LIVE=1 bash scripts/run_narcea_provider_matrix.sh   # include live if keys set
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$ROOT/Godot_v4.6.1-stable_linux.x86_64"
HOST="$ROOT/projects/vg_narcea_test"
SCRIPT="$ROOT/tests/test_narcea_live_suite.gd"
METRICS="$ROOT/tests/narcea_golden/metrics/narcea_suite_runs.csv"

[[ -x "$GODOT" ]] || { echo "ERROR: Godot not found at $GODOT" >&2; exit 2; }

PROVIDERS=(gemini openai claude ollama)
export NARCEA_LIVE="${NARCEA_LIVE:-1}"
export NARCEA_LIVE_SKIP_API="${NARCEA_LIVE_SKIP_API:-1}"

echo "=== Narcea Provider Matrix ==="
echo "Mode: $([[ "$NARCEA_LIVE_SKIP_API" == "1" ]] && echo offline-fixtures || echo live-api)"
echo ""

FAIL=0
for p in "${PROVIDERS[@]}"; do
	echo "--- Provider: $p ---"
	export NARCEA_PROVIDER="$p"
	unset NARCEA_SCENARIO
	out="$(timeout 300 "$GODOT" --headless --path "$HOST" -s "$SCRIPT" 2>&1 || true)"
	echo "$out" | tail -5
	if echo "$out" | grep -q "RESULTS: .* passed, 0 failed"; then
		echo "✅ $p"
	else
		echo "❌ $p"
		FAIL=1
	fi
	echo ""
done

echo "Metrics: $METRICS"
[[ -f "$METRICS" ]] && tail -5 "$METRICS" || true
exit "$FAIL"
