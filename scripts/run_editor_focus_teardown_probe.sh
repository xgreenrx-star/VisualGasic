#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
OUT_DIR="${OUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/vg-editor-focus-XXXXXX")}"
RENDER_MODE="${RENDER_MODE:-headless}"
WINDOW_OWNER="${WINDOW_OWNER:-base}"
CLOSE_BEFORE_QUIT="${CLOSE_BEFORE_QUIT:-0}"
TIMEOUT_SECS="${TIMEOUT_SECS:-90}"

if [[ ! -x "$GODOT" ]]; then
	echo "ERROR: GODOT must name an executable engine" >&2
	exit 1
fi
case "$RENDER_MODE" in
	headless) engine_args=(--headless) ;;
	graphical) engine_args=(--rendering-method gl_compatibility --audio-driver Dummy) ;;
	*) echo "ERROR: RENDER_MODE must be headless or graphical" >&2; exit 1 ;;
esac
case "$WINDOW_OWNER" in
	base|plugin) ;;
	*) echo "ERROR: WINDOW_OWNER must be base or plugin" >&2; exit 1 ;;
esac
case "$CLOSE_BEFORE_QUIT" in
	0) close_before_quit=false ;;
	1) close_before_quit=true ;;
	*) echo "ERROR: CLOSE_BEFORE_QUIT must be 0 or 1" >&2; exit 1 ;;
esac
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
project="$OUT_DIR/project"
if [[ -e "$project" || -L "$project" ]]; then
	echo "ERROR: use a fresh OUT_DIR; $project already exists" >&2
	exit 1
fi
fixture="$ROOT/test_proj/tools/editor_focus_teardown"
mkdir -p "$project/addons/focus_probe"
cp "$fixture/project.godot" "$project/"
cp "$fixture/addons/focus_probe/plugin.cfg" \
	"$fixture/addons/focus_probe/plugin.gd" \
	"$fixture/addons/focus_probe/plugin.gd.uid" "$project/addons/focus_probe/"
printf '\n[probe]\nwindow_owner="%s"\nclose_before_quit=%s\n' \
	"$WINDOW_OWNER" "$close_before_quit" >> "$project/project.godot"
log="$OUT_DIR/editor.log"
if ! timeout "$TIMEOUT_SECS" "$GODOT" "${engine_args[@]}" --editor --path "$project" > "$log" 2>&1; then
	echo "FAIL: editor process failed or timed out; see $log" >&2
	tail -n 20 "$log" >&2
	exit 1
fi
if ! grep -Fxq 'WINDOW-FOCUS READY: no VG extension or custom debugger loaded' "$log"; then
	echo "FAIL: popup probe did not complete; see $log" >&2
	tail -n 20 "$log" >&2
	exit 1
fi
if grep -Eq '^ERROR:|SCRIPT ERROR|Parser Error|leaked at exit|were leaked|instances leaked|signal 11|malloc\(\)|Scan thread aborted' "$log"; then
	echo "FAIL: editor shutdown diagnostics present; see $log" >&2
	grep -A2 -E '^ERROR:|SCRIPT ERROR|Parser Error|leaked|signal 11|malloc\(\)|Scan thread aborted' "$log" >&2
	exit 1
fi
echo "PASS: no-VG $RENDER_MODE popup shutdown, owner=$WINDOW_OWNER, close=$CLOSE_BEFORE_QUIT; full log $log"
