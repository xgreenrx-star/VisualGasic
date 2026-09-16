#!/usr/bin/env bash
# run_csharp_compute_benchmarks.sh — VG vs GDScript vs C# compute microbenchmarks.
#
# Requires:
#   • Godot 4.6.1+ .NET build (mono/linux .NET editor)
#   • dotnet SDK 8+
#   • Visual Gasic GDExtension (scons target=editor)
#
# Usage:
#   scripts/run_csharp_compute_benchmarks.sh
#   GODOT_MONO=/path/to/Godot_v4.6.1-stable_mono_linux.x86_64 scripts/run_csharp_compute_benchmarks.sh
#
# Exit codes: 0 ok, 1 benchmark failure, 2 missing tooling

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_MONO:-${GODOT:-$ROOT/Godot_v4.6.1-stable_mono_linux.x86_64}}"
DEMO="$ROOT/demo"
GODOT_USER_DATA_DIR="${VG_GODOT_USER_DATA_DIR:-${TMPDIR:-/tmp}/vg-godot-csharp-bench-$$}"

if [[ ! -x "$GODOT" ]]; then
	GODOT="$(command -v godot4-mono 2>/dev/null || command -v godot-mono 2>/dev/null || true)"
fi
if [[ -z "$GODOT" || ! -x "$GODOT" ]]; then
	echo "Godot .NET binary not found." >&2
	echo "Set GODOT_MONO=/path/to/Godot_v4.6.1-stable_mono_linux.x86_64" >&2
	echo "Extract the full .NET zip — GodotSharp/ must sit beside the executable." >&2
	echo "Download: https://godotengine.org/download/archive/4.6.1-stable/" >&2
	exit 2
fi

GODOT_DIR="$(cd "$(dirname "$GODOT")" && pwd)"
if [[ ! -d "$GODOT_DIR/GodotSharp" ]]; then
	echo "GodotSharp/ not found next to $GODOT" >&2
	echo "Extract the full Godot .NET zip (not just the executable)." >&2
	exit 2
fi

if ! command -v dotnet >/dev/null 2>&1; then
	echo "dotnet SDK not found." >&2
	exit 2
fi

"$ROOT/scripts/build_demo_csharp.sh"

if [[ ! -f "$ROOT/bin/libvisualgasic.linux.editor.x86_64.so" && ! -f "$DEMO/bin/libvisualgasic.linux.editor.x86_64.so" ]]; then
	echo "WARNING: Visual Gasic GDExtension not found — rebuild with scons first." >&2
fi

mkdir -p "$GODOT_USER_DATA_DIR" "$DEMO/.godot"
if [[ ! -f "$DEMO/.godot/extension_list.cfg" ]]; then
	printf '%s\n' 'res://addons/visual_gasic/visual_gasic.gdextension' >"$DEMO/.godot/extension_list.cfg"
fi

echo "Running compute benchmarks with C# (demo project, Godot .NET)..."
output="$(timeout 240 "$GODOT" --headless --path "$DEMO" \
	--user-data-dir "$GODOT_USER_DATA_DIR" \
	-s res://test_suites/run_benchmarks.gd 2>&1 || true)"
printf '%s\n' "$output" || true

if [[ "$output" != *"Running benchmarks..."* ]]; then
	echo "Compute benchmark did not start." >&2
	exit 1
fi

if [[ "$output" == *"C# benchmarks: skipped"* ]]; then
	echo "C# benchmarks were skipped — ensure Godot .NET build and dotnet build succeeded." >&2
	exit 1
fi

if [[ "$output" != *"C#:"* ]]; then
	echo "C# benchmark timings not found in output." >&2
	exit 1
fi

if [[ "$output" == *"Checksum mismatch"* ]]; then
	echo "Checksum mismatch in C# benchmark run." >&2
	exit 1
fi

echo "C# compute benchmarks finished."
