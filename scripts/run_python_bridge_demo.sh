#!/usr/bin/env bash
# Run a Python bridge .vg demo via test_proj (GDExtension + optional typed protocol).
# Usage: scripts/run_python_bridge_demo.sh [demo_filename]
#   demo_filename defaults to demo_python_bridge.vg
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

NAME="${1:-demo_python_bridge.vg}"
SRC="$ROOT/demos/Utilities/PythonBridge/$NAME"
if [[ ! -f "$SRC" ]]; then
	echo "ERROR: demo not found: $SRC" >&2
	echo "Available:" >&2
	ls -1 "$ROOT/demos/Utilities/PythonBridge/"*.vg 2>/dev/null | xargs -n1 basename >&2
	exit 1
fi

GODOT="${GODOT:-./Godot_v4.6.1-stable_linux.x86_64}"
if [[ ! -x "$GODOT" ]]; then
	echo "ERROR: Godot binary not found: $GODOT" >&2
	exit 1
fi

bash scripts/prepare_ci_gdextension.sh

DEST_DIR="$ROOT/test_proj/demos/python"
mkdir -p "$DEST_DIR"
cp -f "$SRC" "$DEST_DIR/$NAME"
echo "res://demos/python/$NAME" > "$ROOT/test_proj/current_test.txt"

UD="${VG_GODOT_USER_DATA_DIR:-${TMPDIR:-/tmp}/vg-py-demo-$$}"
mkdir -p "$UD"

echo "==> Running $NAME (project: test_proj, user-data-dir: $UD)"
"$GODOT" --headless --path test_proj --user-data-dir "$UD" -s res://run_demo_main.gd
