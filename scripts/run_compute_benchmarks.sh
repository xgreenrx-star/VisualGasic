#!/usr/bin/env bash
# run_compute_benchmarks.sh — Headless VG vs GDScript vs C++ compute microbenchmark suite.
#
# Usage:
#   scripts/run_compute_benchmarks.sh
#
# Exit codes: 0 ok, 1 benchmark failure output, 2 missing godot/binary

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
DEMO="$ROOT/demo"
GODOT_USER_DATA_DIR="${VG_GODOT_USER_DATA_DIR:-${TMPDIR:-/tmp}/vg-godot-bench-$$}"

if [[ ! -x "$GODOT" ]]; then
	GODOT="$(command -v godot || true)"
fi
if [[ ! -x "$GODOT" ]]; then
	echo "Godot binary not found. Set GODOT=/path/to/godot" >&2
	exit 2
fi

if [[ ! -f "$ROOT/bin/libvisualgasic.linux.editor.x86_64.so" && ! -f "$ROOT/demo/bin/libvisualgasic.linux.editor.x86_64.so" ]]; then
	echo "WARNING: Visual Gasic GDExtension not found — rebuild with scons first." >&2
fi

mkdir -p "$GODOT_USER_DATA_DIR" "$DEMO/.godot"
if [[ ! -f "$DEMO/.godot/extension_list.cfg" ]]; then
	printf '%s\n' 'res://addons/visual_gasic/visual_gasic.gdextension' >"$DEMO/.godot/extension_list.cfg"
fi

echo "Running compute benchmarks (demo project)..."
output="$(timeout 180 "$GODOT" --headless --path "$DEMO" \
	--user-data-dir "$GODOT_USER_DATA_DIR" \
	-s res://test_suites/run_benchmarks.gd 2>&1 || true)"
echo "$output"

bench_fatal="$(echo "$output" | grep -E '^ERROR: Failed to load script|^ERROR: Failed to instantiate VisualGasicDrawBenchmark' \
	| grep -E 'run_benchmarks|run_draw_benchmarks|bench\.vg|benchmarks/draw|VisualGasicDrawBenchmark' \
	|| true)"
if [[ -n "$bench_fatal" ]]; then
	echo "$bench_fatal" >&2
	echo "Compute benchmark run reported fatal errors." >&2
	exit 1
fi

if ! echo "$output" | grep -q '=== Arithmetic ==='; then
	echo "Compute benchmark did not produce expected output." >&2
	exit 1
fi

if ! echo "$output" | grep -q 'VisualGasic: { "elapsed_us":'; then
	echo "Compute benchmark did not report VisualGasic timings (extension may not have loaded)." >&2
	exit 1
fi

echo "Compute benchmarks finished."
