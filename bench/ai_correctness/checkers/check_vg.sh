#!/bin/bash
# Parse-check a VisualGasic file by loading it in headless Godot via the
# VG GDExtension. Exit 0 = parses OK (script class loaded without errors).
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
PROJ="$DIR/_vg_check_proj"
mkdir -p "$PROJ"

# Minimal project that loads the VG GDExtension and the addon
cat > "$PROJ/project.godot" <<EOF
config_version=5
[application]
config/name="vgcheck"
[editor_plugins]
enabled=PackedStringArray()
EOF

# Symlink the compiled extension + addon if not already linked
[[ -L "$PROJ/bin" ]] || ln -s "$REPO_ROOT/bin" "$PROJ/bin"
[[ -L "$PROJ/visual_gasic.gdextension" ]] || ln -s "$REPO_ROOT/visual_gasic.gdextension" "$PROJ/visual_gasic.gdextension" 2>/dev/null || true

cp "$FILE" "$PROJ/candidate.vg"

cat > "$PROJ/runner.gd" <<'EOF'
extends SceneTree
func _init():
    var script := load("res://candidate.vg")
    if script == null:
        printerr("PARSE_FAIL: load() returned null")
        quit(1)
        return
    quit(0)
EOF

"$GODOT" --headless --path "$PROJ" --script runner.gd >/dev/null 2>&1
EXIT=$?
exit $EXIT
