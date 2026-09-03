#!/usr/bin/env bash
# Materialize GDExtension libraries for headless Godot in CI and local runs.
# Fresh clones keep addons/visual_gasic/bin as a symlink → ../../demo/bin (gitignored).
# GitHub Actions is especially sensitive to nested symlinks inside the copied addon
# tree: cp -a preserves symlinks, which leaves bin/ as a broken link even when the
# real library exists elsewhere. We must replace the addon tree with a real, mounted
# copy so Godot can register the GDExtension loader reliably.
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
		rm -rf "$dir"
		mkdir -p "$dir"
	fi
	cp -f "$SO" "$dir/$SO_NAME"
}

materialize_addon_tree() {
	local dest="$1"
	local src="$ROOT/addons/visual_gasic"
	if [[ -L "$dest" || -e "$dest" ]]; then
		echo "==> Replacing addon tree: $dest"
		rm -rf "$dest"
	fi
	mkdir -p "$(dirname "$dest")"
	cp -aL "$src" "$dest"
	materialize_bin "$dest/bin"
}

# Godot 4.6 headless loads GDExtensions from .godot/extension_list.cfg, not by
# scanning the tree. That cache is gitignored, so fresh CI clones never register
# the VisualGasic loader until we seed the list here.
ensure_extension_list() {
	local project_dir="$1"
	mkdir -p "$project_dir/.godot"
	printf '%s\n' 'res://addons/visual_gasic/visual_gasic.gdextension' \
		>"$project_dir/.godot/extension_list.cfg"
}

# Materialize the canonical repo addon first, then mirror into every project that
# loads the extension in CI or headless smoke runs.
materialize_bin "addons/visual_gasic/bin"
materialize_addon_tree "test_proj/addons/visual_gasic"
materialize_addon_tree "demo/addons/visual_gasic"

# Also refresh project copies that are not under demo/test_proj but still load the
# extension in automation or local game-project smoke runs.
while IFS= read -r project_dir; do
	[[ -n "$project_dir" ]] || continue
	if [[ "$project_dir" == "$ROOT/addons" ]]; then
		continue
	fi
	materialize_addon_tree "$project_dir/addons/visual_gasic"
done < <(find "$ROOT" -mindepth 1 -maxdepth 2 -type d \( -path "$ROOT/projects" -o -path "$ROOT/demos" -o -path "$ROOT/demo" -o -path "$ROOT/test_proj" \) -print)

ensure_extension_list "$ROOT/test_proj"
ensure_extension_list "$ROOT/demo"
while IFS= read -r project_godot; do
	ensure_extension_list "$(dirname "$project_godot")"
done < <(find "$ROOT/test_proj" "$ROOT/demo" "$ROOT/demos" "$ROOT/projects" \
	-maxdepth 3 -name project.godot -print 2>/dev/null || true)

for check in \
	"test_proj/.godot/extension_list.cfg" \
	"demo/.godot/extension_list.cfg" \
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
