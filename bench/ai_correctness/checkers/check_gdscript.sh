#!/bin/bash
# Parse-check a GDScript file by loading it in headless Godot.
# Exit 0 = loaded without parser errors.
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
PROJ="$DIR/_gdscript_check_proj"
mkdir -p "$PROJ"

# Minimal project.godot
cat > "$PROJ/project.godot" <<EOF
config_version=5
[application]
config/name="gdscheck"
EOF

cp "$FILE" "$PROJ/candidate.gd"

# A check script: load the candidate; if it parses, GDScript will compile it
# at load time. We catch the result and exit accordingly.
cat > "$PROJ/runner.gd" <<'EOF'
extends SceneTree
func _init():
    var s := GDScript.new()
    var src := FileAccess.get_file_as_string("res://candidate.gd")
    s.source_code = src
    var err := s.reload()
    if err != OK:
        printerr("PARSE_FAIL err=", err)
        quit(1)
        return
    quit(0)
EOF

set +e
OUT="$("$GODOT" --headless --path "$PROJ" --script runner.gd 2>&1)"
EXIT=$?
set -e

if [[ $EXIT -ne 0 ]]; then
    echo "$OUT" | grep -iE "error|parse|script|line " | head -3 >&2
fi
exit $EXIT
