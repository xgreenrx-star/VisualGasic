#!/usr/bin/env bash
# run_gameplay_benchmarks.sh — Tier B/C gameplay realism suite (VG vs GDScript).
#
# Usage:
#   scripts/run_gameplay_benchmarks.sh
#   scripts/run_gameplay_benchmarks.sh | tee demo/benchmarks/gameplay/bench_output.txt
#
# Exit codes: 0 ok, 1 benchmark failure output, 2 missing godot/binary

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
DEMO="$ROOT/demo"
GODOT_USER_DATA_DIR="${VG_GODOT_USER_DATA_DIR:-${TMPDIR:-/tmp}/vg-godot-gp-bench-$$}"

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

echo "Running gameplay realism benchmarks (demo project)..."
output="$(timeout 240 "$GODOT" --headless --path "$DEMO" \
	--user-data-dir "$GODOT_USER_DATA_DIR" \
	-s res://benchmarks/gameplay/run_gameplay_benchmarks.gd 2>&1 || true)"
printf '%s\n' "$output" || true

bench_fatal="$(printf '%s\n' "$output" | grep -E '^ERROR: Failed to load script|^SCRIPT ERROR' \
	| grep -E 'run_gameplay_benchmarks|bench\.vg' \
	|| true)"
if [[ -n "$bench_fatal" ]]; then
	echo "$bench_fatal" >&2
	echo "Gameplay benchmark run reported fatal errors." >&2
	exit 1
fi

if [[ "$output" != *"=== IntegerLoop [B"* ]]; then
	echo "Gameplay benchmark did not produce expected output." >&2
	exit 1
fi

if [[ "$output" != *'VisualGasic: { "elapsed_us":'* ]]; then
	echo "Gameplay benchmark did not report VisualGasic timings (extension may not have loaded)." >&2
	exit 1
fi

echo "Gameplay benchmarks finished."
