#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
OUT="$ROOT/release/v$VERSION"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/vg-archive-smoke.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
unzip -q "$OUT/VisualGasic_AssetLibrary_v$VERSION.zip" -d "$WORK"
test ! -L "$WORK/addons/visual_gasic/bin"
cat > "$WORK/project.godot" <<'EOF'
config_version=5
[application]
config/name="VisualGasic packaged archive smoke"
[editor_plugins]
enabled=PackedStringArray("res://addons/visual_gasic/plugin.cfg")
EOF
cat > "$WORK/check.gd" <<'EOF'
extends SceneTree
func _initialize() -> void:
	if not ClassDB.class_exists("VisualGasicLanguage"):
		push_error("Packaged VisualGasic extension did not load")
		quit(1)
		return
	var script = ClassDB.instantiate("VisualGasicScript")
	script.source_code = "Function Result() As Integer\nResult = 42\nEnd Function"
	if script.reload() != OK:
		push_error("Packaged VG script did not parse")
		quit(1)
		return
	var node := Node.new()
	root.add_child(node)
	node.set_script(script)
	if node.call("Result") != 42:
		push_error("Packaged VG script returned an incorrect result")
		quit(1)
		return
	node.free()
	print("PACKAGED ARCHIVE: PASS")
	quit()
EOF
LOG="$OUT/asset-smoke.log"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
env -u VG_FORCE_AST timeout 180 "$GODOT" --headless --editor --audio-driver Dummy \
  --path "$WORK" --import > "$LOG" 2>&1
env -u VG_FORCE_AST timeout 60 "$GODOT" --headless --audio-driver Dummy \
  --path "$WORK" --script check.gd >> "$LOG" 2>&1
if grep -Eq '^ERROR:|SCRIPT ERROR|Parser Error|handle_crash:|leaked at exit|were leaked' "$LOG"; then
  tail -60 "$LOG"
  exit 1
fi
grep -Fx 'PACKAGED ARCHIVE: PASS' "$LOG"
(cd "$OUT" && sha256sum -c SHA256SUMS)
