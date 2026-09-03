#!/usr/bin/env bash
# run_draw_benchmarks.sh — Headless VG vs GDScript vs C++ draw benchmark suite.
#
# Usage:
#   scripts/run_draw_benchmarks.sh
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
if [[ -z "$GODOT" || ! -x "$GODOT" ]]; then
	echo "Godot binary not found. Set GODOT=/path/to/godot" >&2
	exit 2
fi

if [[ ! -f "$ROOT/bin/libvisualgasic.linux.editor.x86_64.so" && ! -f "$ROOT/bin/libvisualgasic.linux.template_release.x86_64.so" ]]; then
	echo "WARNING: Visual Gasic GDExtension not found under bin/ — rebuild with scons first." >&2
fi

mkdir -p "$GODOT_USER_DATA_DIR" "$DEMO/.godot"
if [[ ! -f "$DEMO/.godot/extension_list.cfg" ]]; then
	printf '%s\n' 'res://addons/visual_gasic/visual_gasic.gdextension' >"$DEMO/.godot/extension_list.cfg"
fi

echo "Running draw benchmarks (demo project)..."
output="$(timeout 180 "$GODOT" --headless --path "$DEMO" \
	--user-data-dir "$GODOT_USER_DATA_DIR" \
	-s res://benchmarks/draw/run_draw_benchmarks.gd 2>&1 || true)"
echo "$output"

bench_errors="$(echo "$output" | grep -E '^SCRIPT ERROR:|^ERROR: Failed to load script|^ERROR: Failed to instantiate VisualGasicDrawBenchmark' \
	| grep -v 'plugins/vgmusic/' \
	| grep -v 'Binding duplicate' \
	|| true)"
if [[ -n "$bench_errors" ]]; then
	echo "$bench_errors" >&2
	echo "Draw benchmark run reported errors." >&2
	exit 1
fi

if ! echo "$output" | grep -q '=== Visual Gasic Draw Benchmarks ==='; then
	echo "Draw benchmark did not produce expected header output." >&2
	exit 1
fi

echo "Draw benchmarks finished."
