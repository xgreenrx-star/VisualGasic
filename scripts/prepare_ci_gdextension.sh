#!/usr/bin/env bash
# Materialize GDExtension libraries for headless Godot in CI and local runs.
# Fresh clones keep addons/visual_gasic/bin as a symlink → ../../bin (gitignored).
# Godot's extension loader is more reliable with a real directory + .so copy.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SO="${VG_GDEXTENSION_SO:-demo/bin/libvisualgasic.linux.editor.x86_64.so}"
if [[ ! -f "$SO" ]]; then
	echo "ERROR: GDExtension library not found: $SO (run scons platform=linux target=editor first)" >&2
	exit 1
fi

materialize_bin() {
	local dir="$1"
	if [[ -L "$dir" ]] || [[ ! -d "$dir" ]]; then
		rm -f "$dir"
		mkdir -p "$dir"
	fi
	cp -f "$SO" "$dir/$(basename "$SO")"
	ls -la "$dir/"
}

echo "==> Materializing GDExtension bin directories from $SO"
materialize_bin "addons/visual_gasic/bin"
materialize_bin "demo/addons/visual_gasic/bin"

echo "==> OK: $(readlink -f addons/visual_gasic/bin/$(basename "$SO"))"
