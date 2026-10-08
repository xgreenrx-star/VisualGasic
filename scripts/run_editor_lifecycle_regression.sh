#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/editor_regression_helpers.sh"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
OUT_DIR="${OUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/vg-editor-lifecycle-XXXXXX")}"
RENDER_MODE="${RENDER_MODE:-headless}"
TIMEOUT_SECS="${TIMEOUT_SECS:-120}"
FULL_PLUGIN="${FULL_PLUGIN:-0}"
EXIT_ENABLED="${EXIT_ENABLED:-0}"

if [[ ! -x "$GODOT" ]]; then
	echo "ERROR: GODOT must name an executable engine" >&2
	exit 1
fi
case "$RENDER_MODE" in
	headless) engine_args=(--headless); live_debugger=false; expected_checks=50 ;;
	graphical) engine_args=(--rendering-method gl_compatibility --audio-driver Dummy); live_debugger=true; expected_checks=64 ;;
	*) echo "ERROR: RENDER_MODE must be headless or graphical" >&2; exit 1 ;;
esac
case "$FULL_PLUGIN" in
	0) plugin_config=plugin.cfg; summary_prefix=EDITOR-LIFECYCLE ;;
	1) plugin_config=full_plugin.cfg; summary_prefix=FULL-EDITOR-LIFECYCLE; expected_checks=23 ;;
	*) echo "ERROR: FULL_PLUGIN must be 0 or 1" >&2; exit 1 ;;
esac
case "$EXIT_ENABLED" in
	0) exit_enabled=false ;;
	1)
		if [[ "$FULL_PLUGIN" != 1 ]]; then
			echo "ERROR: EXIT_ENABLED requires FULL_PLUGIN=1" >&2
			exit 1
		fi
		exit_enabled=true
		expected_checks=$((expected_checks + 1))
		;;
	*) echo "ERROR: EXIT_ENABLED must be 0 or 1" >&2; exit 1 ;;
esac
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
project="$OUT_DIR/project"
if [[ -e "$project" || -L "$project" ]]; then
	echo "ERROR: use a fresh OUT_DIR; $project already exists" >&2
	exit 1
fi
mkdir -p "$project/addons" "$project/.godot"
prepare_editor_regression_addon "$project"
ln -s "$ROOT/test_proj/tools/editor_lifecycle" "$project/addons/lifecycle_test"
cat > "$project/project.godot" <<PROJECT
config_version=5
[application]
config/name="VG Editor Lifecycle Regression"
run/main_scene="res://main.tscn"
[editor]
run/main_run_args="--headless --audio-driver Dummy"
[rendering]
renderer/rendering_method="gl_compatibility"
[vg]
tests/live_debugger=$live_debugger
tests/exit_enabled=$exit_enabled
PROJECT
cat > "$project/main.tscn" <<'SCENE'
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://addons/lifecycle_test/game.gd" id="1"]
[node name="Fixture" type="Node"]
script = ExtResource("1")
SCENE
if [[ "$FULL_PLUGIN" == 1 ]]; then
	printf '\n[autoload]\nVGDebugHandler="*res://addons/visual_gasic/vg_debug_handler.gd"\n' >> "$project/project.godot"
fi
import_log="$OUT_DIR/import.log"
if ! timeout "$TIMEOUT_SECS" "$GODOT" --headless --editor --import --path "$project" \
		> "$import_log" 2>&1 ||
		grep -Eq '^ERROR:|SCRIPT ERROR|Parser Error|leaked at exit|were leaked|signal 11|Scan thread aborted' "$import_log"; then
	echo "FAIL: lifecycle fixture import failed; see $import_log" >&2
	tail -n 20 "$import_log" >&2
	exit 1
fi
printf '\n[editor_plugins]\nenabled=PackedStringArray("res://addons/lifecycle_test/%s")\n' \
	"$plugin_config" >> "$project/project.godot"
log="$OUT_DIR/editor.log"
if ! timeout "$TIMEOUT_SECS" "$GODOT" "${engine_args[@]}" --editor --path "$project" > "$log" 2>&1; then
	echo "FAIL: editor lifecycle process failed or timed out; see $log" >&2
	tail -n 20 "$log" >&2
	exit 1
fi
if ! grep -Fxq "$summary_prefix RESULTS: $expected_checks passed, 0 failed" "$log" ||
		grep -Eq '^ERROR:|SCRIPT ERROR|Parser Error|VG Runtime Error|leaked at exit|were leaked|instances leaked|signal 11|malloc\(\)|Scan thread aborted' "$log"; then
	echo "FAIL: lifecycle checks incomplete or diagnostics present; see $log" >&2
	grep -E 'EDITOR-LIFECYCLE|ERROR:|leaked|aborted' "$log" >&2 || true
	exit 1
fi
grep "^$summary_prefix RESULTS:" "$log"
echo "PASS: isolated $RENDER_MODE editor lifecycle; full log $log"
