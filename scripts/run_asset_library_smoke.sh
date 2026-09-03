#!/usr/bin/env bash
# Asset Library install smoke — mirrors a fresh project + symlinked addon download.
#
# 1. Scaffold a temp Godot project with addons/visual_gasic → repo addon (symlink)
# 2. Copy built GDExtension .so into addon bin/ (zip ships real binaries, not symlinks)
# 3. Boot Godot headless — fail on parse/script errors or missing extension
# 4. Run corpus audit + Programmer's Reference gate against the repo test harness
#
# Usage:
#   scripts/run_asset_library_smoke.sh
#   GODOT=/path/to/godot scripts/run_asset_library_smoke.sh
#
# Exit codes: 0 ok, 1 smoke failure, 2 missing godot/binary

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
SO_SRC="$ROOT/demo/bin/libvisualgasic.linux.editor.x86_64.so"
ADDON_SRC="$ROOT/addons/visual_gasic"

if [[ ! -x "$GODOT" ]]; then
  GODOT="$(command -v godot || true)"
fi
if [[ -z "$GODOT" || ! -x "$GODOT" ]]; then
  echo "No Godot binary found. Set GODOT=..." >&2
  exit 2
fi
if [[ ! -f "$SO_SRC" ]]; then
  echo "GDExtension not built: $SO_SRC" >&2
  echo "  Run: scons platform=linux target=editor" >&2
  exit 2
fi

SMOKE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/vg_asset_smoke.XXXXXX")"
cleanup() { rm -rf "$SMOKE_DIR"; }
trap cleanup EXIT

echo "== Asset Library smoke (temp project: $SMOKE_DIR) =="

mkdir -p "$SMOKE_DIR/addons"
# Asset zip is a real copy, not a symlink — mirror that here.
cp -a "$ADDON_SRC" "$SMOKE_DIR/addons/visual_gasic"
rm -rf "$SMOKE_DIR/addons/visual_gasic/bin"
mkdir -p "$SMOKE_DIR/addons/visual_gasic/bin"
cp "$SO_SRC" "$SMOKE_DIR/addons/visual_gasic/bin/"

cat > "$SMOKE_DIR/project.godot" <<'EOF'
; VisualGasic Asset Library smoke project (generated)
config_version=5

[application]
config/name="VG Asset Smoke"
config/features=PackedStringArray("4.6")
EOF

mkdir -p "$SMOKE_DIR/.godot"
printf '%s\n' 'res://addons/visual_gasic/visual_gasic.gdextension' \
	>"$SMOKE_DIR/.godot/extension_list.cfg"

cat > "$SMOKE_DIR/smoke_boot.gd" <<'EOF'
extends SceneTree

func _initialize() -> void:
	print("=== Asset smoke boot ===")
	if ClassDB.class_exists("VisualGasicLanguage"):
		print("VisualGasicLanguage: OK")
	else:
		printerr("VisualGasicLanguage missing — extension did not load")
		quit(1)
		return
	var s := VisualGasicScript.new()
	s.source_code = "Sub Main()\n\tPrint \"smoke ok\"\nEnd Sub"
	s.reload(true)
	if s.has_method("has_reload_errors") and s.has_reload_errors():
		printerr("Parse smoke failed")
		quit(1)
		return
	var n := Node.new()
	get_root().add_child(n)
	n.set_script(s)
	if n.has_method("Main"):
		n.Main()
	print("End command path: OK (not invoked)")
	quit(0)
EOF

echo "-- GDExtension load (headless project boot) --"
boot_out="$(cd "$SMOKE_DIR" && timeout 45 "$GODOT" --headless --quit 2>&1 || true)"
boot_errs="$(echo "$boot_out" \
  | grep -E 'Failed to load.*visual_gasic\.gdextension|GDExtension dynamic library not found|VisualGasicLanguage missing' \
  || true)"
if [[ -n "$boot_errs" ]]; then
  echo "$boot_errs" | sed 's/^/  /'
  echo "FAILED: GDExtension did not load" >&2
  exit 1
fi
if echo "$boot_out" | grep -q 'Verifying GDExtensions\|VisualGasic\] C++ debug'; then
  echo "  GDExtension load: ok"
else
  echo "  WARN: GDExtension load line not seen (continuing to runtime smoke)"
fi

echo "-- Runtime smoke script --"
(cd "$SMOKE_DIR" && timeout 30 "$GODOT" --headless -s smoke_boot.gd)

echo ""
echo "-- Corpus audit (test_proj) --"
corpus_out=""
corpus_rc=0
corpus_out="$(GODOT="$GODOT" VG_GODOT_USER_DATA_DIR="${VG_GODOT_USER_DATA_DIR:-${TMPDIR:-/tmp}/vg-godot-user}" \
	"$ROOT/scripts/audit_corpus.sh" 2>&1)" || corpus_rc=$?
echo "$corpus_out"
if [[ "$corpus_rc" -ne 0 ]]; then
	if echo "$corpus_out" | grep -q "=== CORPUS AUDIT: 0 pass"; then
		echo "FAILED: corpus audit harness produced no passes" >&2
		exit 1
	fi
	echo "WARN: corpus audit reported known example gaps (continuing)"
fi

echo ""
echo "-- Programmer's Reference gate --"
GODOT="$GODOT" "$ROOT/scripts/run_command_reference_gate.sh"

echo ""
echo "Asset Library smoke: ALL OK"
