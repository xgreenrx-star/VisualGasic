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

echo "Running draw benchmarks (demo project)..."
cd "$DEMO"
output="$(timeout 180 "$GODOT" --headless -s res://benchmarks/draw/run_draw_benchmarks.gd 2>&1 || true)"
echo "$output"

if echo "$output" | grep -qE '^SCRIPT ERROR:|^ERROR: Failed to load script|^ERROR: Failed to instantiate VisualGasicDrawBenchmark'; then
	echo "Draw benchmark run reported errors." >&2
	exit 1
fi

if ! echo "$output" | grep -q '=== Visual Gasic Draw Benchmarks ==='; then
	echo "Draw benchmark did not produce expected header output." >&2
	exit 1
fi

echo "Draw benchmarks finished."
