#!/usr/bin/env bash
# Narcea Golden Path harness — Tier A (deterministic) today; Tier B/C later.
#
# Usage:
#   bash scripts/run_narcea_golden.sh              # default: Tier A
#   bash scripts/run_narcea_golden.sh --tier A
#   bash scripts/run_narcea_golden.sh --tier B     # (recorded replay — not yet implemented)
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$ROOT/Godot_v4.6.1-stable_linux.x86_64"
HOST_PROJECT="$ROOT/projects/vg_narcea_test"
TEST_SCRIPT="$ROOT/tests/test_narcea_golden_spec.gd"
TIMEOUT="${NARCEA_GOLDEN_TIMEOUT:-45}"
TIER="A"

while [[ $# -gt 0 ]]; do
	case "$1" in
		--tier)
			TIER="${2:-A}"
			shift 2
			;;
		-h|--help)
			echo "Usage: $0 [--tier A|B|C]"
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
if [[ ! -f "$TEST_SCRIPT" ]]; then
	echo "ERROR: Test script not found at $TEST_SCRIPT" >&2
	exit 2
fi

echo "=== Narcea Golden Path Runner (Tier $TIER) ==="
echo "Host: $HOST_PROJECT"
echo ""

case "$TIER" in
	A|a)
		output="$(timeout "$TIMEOUT" "$GODOT" --headless --path "$HOST_PROJECT" -s "$TEST_SCRIPT" 2>&1 || true)"
		echo "$output"
		if echo "$output" | grep -q "RESULTS: .* passed, 0 failed"; then
			echo ""
			echo "✅ Narcea Golden Tier A PASSED"
			exit 0
		fi
		echo ""
		echo "❌ Narcea Golden Tier A FAILED"
		exit 1
		;;
	B|b)
		echo "Tier B (recorded transcript replay) is not implemented yet."
		echo "See tests/narcea_golden/README.md — Phase 2."
		exit 2
		;;
	C|c)
		echo "Tier C (live API eval) is not implemented yet."
		echo "Set NARCEA_LIVE=1 and see tests/narcea_golden/README.md — Phase 3."
		exit 2
		;;
	*)
		echo "Unknown tier: $TIER (use A, B, or C)" >&2
		exit 2
		;;
esac
