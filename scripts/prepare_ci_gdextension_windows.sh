#!/usr/bin/env bash
# Materialize Windows editor GDExtension for headless Godot on CI (Git Bash / MSYS).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DLL="${VG_GDEXTENSION_DLL:-demo/bin/libvisualgasic.windows.editor.x86_64.dll}"
DLL_NAME="$(basename "$DLL")"

if [[ ! -f "$DLL" ]]; then
	echo "ERROR: GDExtension DLL not found: $DLL (run scons platform=windows target=editor first)" >&2
	exit 1
fi

materialize_bin() {
	local dir="$1"
	if [[ -L "$dir" ]] || [[ ! -d "$dir" ]]; then
		rm -rf "$dir"
		mkdir -p "$dir"
	fi
	cp -f "$DLL" "$dir/$DLL_NAME"
}

materialize_addon_tree() {
	local dest="$1"
	local src="$ROOT/addons/visual_gasic"
	if [[ -L "$dest" ]] || [[ ! -d "$dest" ]]; then
		rm -rf "$dest"
		mkdir -p "$dest"
		cp -a "$src/." "$dest/" 2>/dev/null || true
	fi
	materialize_bin "$dest/bin"
}

ensure_extension_list() {
	local project_dir="$1"
	mkdir -p "$project_dir/.godot"
	printf '%s\n' 'res://addons/visual_gasic/visual_gasic.gdextension' >"$project_dir/.godot/extension_list.cfg"
}

materialize_bin "addons/visual_gasic/bin"
if [[ -d "$ROOT/test_proj" ]]; then
	if [[ -L "$ROOT/test_proj/addons/visual_gasic" ]] || [[ ! -d "$ROOT/test_proj/addons/visual_gasic" ]]; then
		rm -rf "$ROOT/test_proj/addons/visual_gasic"
		mkdir -p "$ROOT/test_proj/addons/visual_gasic"
		cp -aL "$ROOT/addons/visual_gasic/." "$ROOT/test_proj/addons/visual_gasic/"
	fi
	materialize_bin "$ROOT/test_proj/addons/visual_gasic/bin"
	ensure_extension_list "$ROOT/test_proj"
fi

for check in \
	"addons/visual_gasic/bin/$DLL_NAME" \
	"test_proj/addons/visual_gasic/bin/$DLL_NAME" \
	"test_proj/.godot/extension_list.cfg"; do
	[[ -f "$check" ]] || { echo "ERROR: missing $check after prepare" >&2; exit 1; }
done

echo "==> OK: addons/visual_gasic/bin/$DLL_NAME"
