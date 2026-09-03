#!/usr/bin/env bash
# run_compile_benchmarks.sh — Headless VG vs GDScript compile/reload timing.
#
# Usage:
#   scripts/run_compile_benchmarks.sh
#
# Exit codes: 0 ok, 1 benchmark failure output, 2 missing godot/binary

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
DEMO="$ROOT/demo"
GODOT_USER_DATA_DIR="${VG_GODOT_USER_DATA_DIR:-${TMPDIR:-/tmp}/vg-godot-compile-$$}"

if [[ ! -x "$GODOT" ]]; then
	GODOT="$(command -v godot || true)"
fi
if [[ -z "$GODOT" || ! -x "$GODOT" ]]; then
	echo "Godot binary not found. Set GODOT=/path/to/godot" >&2
	exit 2
fi

mkdir -p "$GODOT_USER_DATA_DIR" "$DEMO/.godot"
if [[ ! -f "$DEMO/.godot/extension_list.cfg" ]]; then
	printf '%s\n' 'res://addons/visual_gasic/visual_gasic.gdextension' >"$DEMO/.godot/extension_list.cfg"
fi

echo "Running compile benchmarks (demo project)..."
output="$(timeout 180 "$GODOT" --headless --path "$DEMO" \
	--user-data-dir "$GODOT_USER_DATA_DIR" \
	-s res://test_suites/run_compile_benchmarks.gd 2>&1 || true)"
printf '%s\n' "$output" || true

if [[ "$output" != *"=== Visual Gasic Compile Benchmarks ==="* ]]; then
	echo "Compile benchmark did not produce expected header." >&2
	exit 1
fi

if [[ "$output" != *'VisualGasic reload: { "elapsed_us":'* ]]; then
	echo "Compile benchmark did not report VisualGasic timings." >&2
	exit 1
fi

if [[ "$output" != *"Compile benchmarks finished."* ]]; then
	echo "Compile benchmark did not finish." >&2
	exit 1
fi

echo "Compile benchmarks finished."
