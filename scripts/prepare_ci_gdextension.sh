#!/usr/bin/env bash
# Materialize GDExtension libraries for headless Godot in CI and local runs.
# Fresh clones keep addons/visual_gasic/bin as a symlink → ../../demo/bin (gitignored).
# Godot's extension loader is more reliable with real bin/ dirs and non-symlinked
# project addon paths (GitHub Actions runners can fail to load through symlinks).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SO="${VG_GDEXTENSION_SO:-demo/bin/libvisualgasic.linux.editor.x86_64.so}"
SO_NAME="$(basename "$SO")"

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
	cp -f "$SO" "$dir/$SO_NAME"
}

replace_addon_symlink() {
	local dest="$1"
	if [[ -L "$dest" ]]; then
		echo "==> Replacing addon symlink with real tree: $dest"
		rm -f "$dest"
		cp -a addons/visual_gasic "$dest"
	elif [[ ! -d "$dest" ]]; then
		echo "==> Copying addon tree: $dest"
		mkdir -p "$(dirname "$dest")"
		cp -a addons/visual_gasic "$dest"
	fi
}

echo "==> Materializing GDExtension bin from $SO"
materialize_bin "addons/visual_gasic/bin"

replace_addon_symlink "test_proj/addons/visual_gasic"
replace_addon_symlink "demo/addons/visual_gasic"

for check in \
	"addons/visual_gasic/visual_gasic.gdextension" \
	"addons/visual_gasic/bin/$SO_NAME" \
	"test_proj/addons/visual_gasic/visual_gasic.gdextension" \
	"test_proj/addons/visual_gasic/bin/$SO_NAME" \
	"demo/addons/visual_gasic/visual_gasic.gdextension" \
	"demo/addons/visual_gasic/bin/$SO_NAME"; do
	if [[ ! -f "$check" ]]; then
		echo "ERROR: missing $check after prepare" >&2
		exit 1
	fi
done

if command -v ldd >/dev/null 2>&1; then
	missing=$(ldd "addons/visual_gasic/bin/$SO_NAME" | grep "not found" || true)
	if [[ -n "$missing" ]]; then
		echo "ERROR: unresolved shared libraries for GDExtension:" >&2
		echo "$missing" >&2
		exit 1
	fi
fi

echo "==> Layout OK"
ls -la addons/visual_gasic/bin/
echo "==> OK: $(readlink -f "addons/visual_gasic/bin/$SO_NAME")"
