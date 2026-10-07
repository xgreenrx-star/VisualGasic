#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${OUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/vg-import-heap-XXXXXX")}"
ITERATIONS="${ITERATIONS:-3}"
if [[ ! "$ITERATIONS" =~ ^[1-9][0-9]*$ ]]; then
	echo "ERROR: ITERATIONS must be a positive integer" >&2
	exit 1
fi
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
for ((iteration=1; iteration<=ITERATIONS; iteration++)); do
	echo "HEAP-STRESS: iteration $iteration/$ITERATIONS"
	OUT_DIR="$OUT_DIR/iteration-$iteration" MALLOC_PERTURB_=165 \
		GLIBC_TUNABLES=glibc.malloc.check=3 "$ROOT/scripts/run_editor_reload_regression.sh"
done
echo "HEAP-STRESS RESULTS: $ITERATIONS iterations completed; import diagnostics retained in $OUT_DIR"
