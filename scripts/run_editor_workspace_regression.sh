#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/editor_regression_helpers.sh"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
OUT_DIR="${OUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/vg-workspace-XXXXXX")}"
TIMEOUT_SECS="${TIMEOUT_SECS:-300}"
[[ -x "$GODOT" ]] || { echo "ERROR: GODOT must name an executable engine" >&2; exit 1; }
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
project="$OUT_DIR/project"
[[ ! -e "$project" ]] || { echo "ERROR: use a fresh OUT_DIR" >&2; exit 1; }
mkdir -p "$project"
cp "$ROOT/samples/showcases/crystal_caverns/"{project.godot,main.tscn,Caverns.vg} "$project/"
cp "$ROOT/samples/showcases/crystal_caverns/VisualEffects.vg" "$project/"
cp "$ROOT/samples/showcases/crystal_caverns/SoundEffects.vg" "$project/"
cp -a "$ROOT/samples/showcases/crystal_caverns/shaders" "$project/"
prepare_editor_regression_addon "$project"
cp -a "$ROOT/tests/editor_workspace_probe" "$project/addons/workspace_probe"
sed -i 's|enabled=PackedStringArray("res://addons/visual_gasic/plugin.cfg")|enabled=PackedStringArray("res://addons/visual_gasic/plugin.cfg", "res://addons/workspace_probe/plugin.cfg")|' "$project/project.godot"
export XDG_CONFIG_HOME="$OUT_DIR/config" XDG_DATA_HOME="$OUT_DIR/data" XDG_CACHE_HOME="$OUT_DIR/cache"
rc=0
env -u VG_FORCE_AST WORKSPACE_CAPTURE="$OUT_DIR/workspace.png" \
	timeout "$TIMEOUT_SECS" "$GODOT" --editor --path "$project" \
	--rendering-method gl_compatibility --audio-driver Dummy > "$OUT_DIR/editor.log" 2>&1 || rc=$?
if [[ "$rc" -ne 0 ]] ||
		! grep -Fxq 'WORKSPACE RESULTS: 118 passed, 0 failed' "$OUT_DIR/editor.log" ||
		grep -Eq '^ERROR:|SCRIPT ERROR|Parser Error|Unicode parsing error|handle_crash:|\[FAIL\]|leaked at exit|were leaked' "$OUT_DIR/editor.log"; then
	echo "FAIL: workspace regression (exit=$rc); see $OUT_DIR/editor.log" >&2
	tail -n 55 "$OUT_DIR/editor.log" >&2
	exit 1
fi
grep '^WORKSPACE RESULTS:' "$OUT_DIR/editor.log"
echo "PASS: actual editor workspace; evidence $OUT_DIR"
