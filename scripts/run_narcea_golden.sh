#!/usr/bin/env bash
# Narcea Golden Path harness — Tier A (fixture) and Tier B (recorded replay).
#
# Usage:
#   bash scripts/run_narcea_golden.sh              # Tier A
#   bash scripts/run_narcea_golden.sh --tier B     # replay recorded/*_response.txt
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$ROOT/Godot_v4.6.1-stable_linux.x86_64"
HOST_PROJECT="$ROOT/projects/vg_narcea_test"
TEST_SCRIPT="$ROOT/tests/test_narcea_golden_spec.gd"
TIMEOUT="${NARCEA_GOLDEN_TIMEOUT:-90}"
TIER="A"

while [[ $# -gt 0 ]]; do
	case "$1" in
		--tier)
			TIER="${2:-A}"
			shift 2
			;;
		-h|--help)
			echo "Usage: $0 [--tier A|B|C|ALL]"
			echo ""
			echo "  A    Canonical fixture (default)"
			echo "  B    Replay tests/narcea_golden/recorded/*_response.txt"
			echo "  C    Live Gemini eval (NARCEA_LIVE=1; NARCEA_LIVE_SKIP_API=1 skips HTTP)"
			echo "  ALL  Run A, then B, then C (skip-api unless NARCEA_LIVE=1)"
			exit 0
			;;
		*)
			echo "Unknown argument: $1" >&2
			exit 2
			;;
	esac
done

if [[ ! -x "$GODOT" ]]; then
	echo "ERROR: Godot binary not found at $GODOT" >&2
	exit 2
fi
if [[ ! -d "$HOST_PROJECT" ]]; then
	echo "ERROR: Host project not found at $HOST_PROJECT" >&2
	exit 2
fi

_run_one_tier() {
	local tier="$1"
	local prev_tier="$TIER"
	TIER="$tier"
	echo "=== Narcea Golden Path Runner (Tier $tier) ==="
	echo "Host: $HOST_PROJECT"
	echo ""

	case "$tier" in
		C|c)
			if [[ "${NARCEA_LIVE:-}" != "1" ]]; then
				export NARCEA_LIVE=1
				export NARCEA_LIVE_SKIP_API=1
				echo "(NARCEA_LIVE not set — using NARCEA_LIVE_SKIP_API=1 for Tier C)"
			fi
			export NARCEA_LIVE=1
			LIVE_SCRIPT="$ROOT/tests/test_narcea_live_gemini.gd"
			SUITE_SCRIPT="$ROOT/tests/test_narcea_live_suite.gd"
			if [[ ! -f "$LIVE_SCRIPT" ]]; then
				echo "ERROR: $LIVE_SCRIPT not found" >&2
				return 2
			fi
			TIMEOUT="${NARCEA_LIVE_TIMEOUT:-180}"
			fail=0
			output="$(timeout "$TIMEOUT" "$GODOT" --headless --path "$HOST_PROJECT" -s "$LIVE_SCRIPT" 2>&1 || true)"
			echo "$output"
			echo "$output" | grep -q "RESULTS: .* passed, 0 failed" || fail=1
			if [[ -f "$SUITE_SCRIPT" ]]; then
				echo ""
				echo "--- Tier C2: multi-scenario suite ---"
				export NARCEA_LIVE_SKIP_API=1
				out2="$(timeout "$TIMEOUT" "$GODOT" --headless --path "$HOST_PROJECT" -s "$SUITE_SCRIPT" 2>&1 || true)"
				echo "$out2"
				echo "$out2" | grep -q "RESULTS: .* passed, 0 failed" || fail=1
			fi
			if [[ "$fail" -eq 0 ]]; then
				echo ""
				echo "✅ Narcea Golden Tier C PASSED"
				return 0
			fi
			echo ""
			echo "❌ Narcea Golden Tier C FAILED"
			return 1
			;;
		A|a|B|b)
			export NARCEA_GOLDEN_TIER="${tier^^}"
			fail=0
			output="$(timeout "$TIMEOUT" "$GODOT" --headless --path "$HOST_PROJECT" -s "$TEST_SCRIPT" 2>&1 || true)"
			echo "$output"
			echo "$output" | grep -q "RESULTS: .* passed, 0 failed" || fail=1
			if [[ "${tier^^}" == "A" && -f "$ROOT/tests/test_narcea_form_smoke.gd" ]]; then
				echo ""
				echo "--- Tier A2: chat-first form smoke ---"
				out_smoke="$(timeout 60 "$GODOT" --headless --path "$HOST_PROJECT" -s "$ROOT/tests/test_narcea_form_smoke.gd" 2>&1 || true)"
				echo "$out_smoke"
				echo "$out_smoke" | grep -q "RESULTS: .* passed, 0 failed" || fail=1
			fi
			if [[ "$fail" -eq 0 ]]; then
				echo ""
				echo "✅ Narcea Golden Tier $tier PASSED"
				return 0
			fi
			echo ""
			echo "❌ Narcea Golden Tier $tier FAILED"
			return 1
			;;
		*)
			echo "Unknown tier: $tier (use A, B, C, or ALL)" >&2
			return 2
			;;
	esac
}

if [[ "$TIER" == "ALL" || "$TIER" == "all" ]]; then
	FAIL=0
	for t in A B C; do
		_run_one_tier "$t" || FAIL=1
		echo ""
	done
	exit "$FAIL"
fi

_run_one_tier "$TIER"
exit $?
