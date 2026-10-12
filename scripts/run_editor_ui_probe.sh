#!/usr/bin/env bash
# Open the Godot editor on a virtual display and check the Behavior evidence
# panel and the Last change card. Not part of run_test_suite.sh.
#
# Usage:
#   scripts/run_editor_ui_probe.sh
#   scripts/run_editor_ui_probe.sh /path/to/Godot
#
# Requires xvfb-run and a Godot binary with the opengl3 driver (Mesa is fine).
# Screenshots and the log land in build/editor_ui_probe/<godot-version>/.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${1:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
USERDATA="${HOME}/.local/share/godot/app_userdata/VG UI Probe"
SRC="$ROOT/samples/showcases/crystal_caverns"
PROBE_SRC="$ROOT/tools/editor_ui_probe"

if [[ ! -x "$GODOT" ]]; then
	echo "Godot binary not found at $GODOT" >&2
	exit 2
fi
if ! command -v xvfb-run >/dev/null 2>&1; then
	echo "xvfb-run is required" >&2
	exit 2
fi

RAW="$("$GODOT" --version 2>/dev/null | head -1 || true)"
VER="$(printf '%s\n' "$RAW" | sed -n 's/^\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')"
if [[ -z "$VER" ]]; then
	VER="unknown"
fi
DEST="$ROOT/build/editor_ui_probe/$VER"
mkdir -p "$DEST"

TMP="$(mktemp -d /tmp/vg-ui-probe.XXXXXX)"
cleanup() {
	rm -rf "$TMP"
	rm -rf "$USERDATA"
}
trap cleanup EXIT
rm -rf "$USERDATA"

cp -a "$SRC" "$TMP/game"
rm -f "$TMP/game/addons/visual_gasic"
ln -s "$ROOT/addons/visual_gasic" "$TMP/game/addons/visual_gasic"
cp "$PROBE_SRC/zz_dump.gd" "$TMP/game/zz_dump.gd"
mkdir -p "$TMP/game/addons/zz_probe"
cp "$PROBE_SRC/plugin.cfg" "$PROBE_SRC/probe.gd" "$TMP/game/addons/zz_probe/"

python3 - "$TMP/game/project.godot" <<'PY'
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
old_name = 'config/name="Crystal Caverns"'
new_name = 'config/name="VG UI Probe"'
if old_name not in text:
    sys.exit("project name line missing")
text = text.replace(old_name, new_name, 1)
old_plugins = 'enabled=PackedStringArray("res://addons/visual_gasic/plugin.cfg")'
new_plugins = 'enabled=PackedStringArray("res://addons/visual_gasic/plugin.cfg", "res://addons/zz_probe/plugin.cfg")'
if old_plugins not in text:
    sys.exit("editor plugin line missing")
text = text.replace(old_plugins, new_plugins, 1)
if "\n[vg]\n" not in text and not text.startswith("[vg]\n"):
    if not text.endswith("\n"):
        text += "\n"
    text += "\n[vg]\n\nevidence/runtime_ring=false\n"
open(path, "w", encoding="utf-8").write(text)
PY

echo "dump $VER"
"$GODOT" --headless --path "$TMP/game" --rendering-driver opengl3 \
	--script "$TMP/game/zz_dump.gd" >"$DEST/dump.log" 2>&1
dump_ec=$?
if [[ $dump_ec -ne 0 ]]; then
	echo "snapshot dump failed ($dump_ec)" >&2
	exit 1
fi
SNAP="$USERDATA/probe_snapshot.json"
if [[ ! -f "$SNAP" ]]; then
	echo "snapshot missing at $SNAP" >&2
	exit 1
fi
cp "$SNAP" "$TMP/snapshot.json"
cp "$SNAP" "$DEST/snapshot.json"

python3 - "$TMP/game/zz_ui_probe.json" "$TMP/snapshot.json" "$DEST" <<'PY'
import json, sys
open(sys.argv[1], "w", encoding="utf-8").write(json.dumps({
    "snapshot": sys.argv[2],
    "out": sys.argv[3],
}))
PY

echo "editor $VER"
set +e
timeout --signal=TERM 360 xvfb-run -a -s "-screen 0 1600x1000x24" \
	"$GODOT" --editor --path "$TMP/game" \
	--rendering-driver opengl3 --resolution 1600x1000 \
	>"$DEST/editor.log" 2>&1
editor_ec=$?
set -e
echo "editor exit $editor_ec"

if [[ $editor_ec -eq 124 ]]; then
	echo "editor timed out" >&2
	exit 1
fi
if [[ ! -f "$DEST/probe_log.txt" ]]; then
	echo "probe log missing" >&2
	exit 1
fi
if grep -q "SCRIPT ERROR" "$DEST/editor.log"; then
	echo "editor log contains SCRIPT ERROR" >&2
	exit 1
fi
if ! grep -q "\[PASS\] editor_ui_probe" "$DEST/probe_log.txt"; then
	echo "probe did not pass" >&2
	exit 1
fi
if grep -q "^PROBE: FAIL " "$DEST/editor.log"; then
	echo "probe reported a failure" >&2
	exit 1
fi
echo "PASS editor_ui_probe $VER"
exit 0
