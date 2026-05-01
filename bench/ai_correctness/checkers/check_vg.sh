#!/bin/bash
# Parse-check a VisualGasic file by loading it inside test_proj/, which
# already has the VG GDExtension and addon wired up. Exit 0 = parses OK.
set -e

GODOT="${GODOT_BIN:-./Godot_v4.6.1-stable_linux.x86_64}"
if [[ ! -x "$GODOT" ]]; then
    if command -v godot >/dev/null 2>&1; then
        GODOT=godot
    else
        echo "ERROR: Godot binary not found. Set GODOT_BIN env var." >&2
        exit 127
    fi
fi

FILE="$(realpath "$1")"
DIR="$(dirname "$0")"
REPO_ROOT="$(realpath "$DIR/../../..")"
PROJ="$REPO_ROOT/test_proj"

if [[ ! -d "$PROJ/addons/visual_gasic" ]]; then
    echo "ERROR: $PROJ/addons/visual_gasic not found" >&2
    exit 127
fi

STAGE="$PROJ/_bench_candidate.vg"
RUNNER="$PROJ/_bench_runner.gd"
cp "$FILE" "$STAGE"

cat > "$RUNNER" <<'EOF'
extends SceneTree
func _init():
    var script := load("res://_bench_candidate.vg")
    if script == null:
        printerr("PARSE_FAIL: load() returned null")
        quit(1)
        return
    quit(0)
EOF

set +e
OUT="$(cd "$REPO_ROOT" && "$GODOT" --headless --path "$PROJ" --script _bench_runner.gd 2>&1)"
EXIT=$?
set -e

rm -f "$STAGE" "$RUNNER" "$STAGE.uid" 2>/dev/null || true

if [[ $EXIT -ne 0 ]]; then
    echo "$OUT" | grep -iE "error|fail|exception|parse" | head -3 >&2
fi
exit $EXIT
