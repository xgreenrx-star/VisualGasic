#!/usr/bin/env bash
# Linux workaround: libvisualgasic.linux.editor.x86_64.so can SIGSEGV on dlopen
# (null init hook) while template_release loads cleanly. Godot editor mode only
# needs a loadable library for the editor slot — release binary is sufficient
# until the editor-target link is fixed upstream.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[[ "$(uname -s)" == "Linux" ]] || exit 0

EDITOR_SO="demo/bin/libvisualgasic.linux.editor.x86_64.so"
RELEASE_SO="demo/bin/libvisualgasic.linux.template_release.x86_64.so"
DEBUG_SO="demo/bin/libvisualgasic.linux.template_debug.x86_64.so"

[[ -f "$RELEASE_SO" ]] || exit 0

editor_dlopen_ok() {
	[[ -f "$EDITOR_SO" ]] || return 1
	python3 - <<'PY' "$EDITOR_SO"
import ctypes, sys
try:
    ctypes.CDLL(sys.argv[1])
except OSError:
    sys.exit(2)
PY
}

if editor_dlopen_ok; then
	exit 0
fi

echo "==> Linux editor GDExtension dlopen failed — using template_release for editor slot" >&2
cp -f "$RELEASE_SO" "$EDITOR_SO"

install_bin_dir() {
	local dir="$1"
	mkdir -p "$dir"
	cp -f "$EDITOR_SO" "$dir/libvisualgasic.linux.editor.x86_64.so"
	[[ -f "$DEBUG_SO" ]] && cp -f "$DEBUG_SO" "$dir/libvisualgasic.linux.template_debug.x86_64.so"
	cp -f "$RELEASE_SO" "$dir/libvisualgasic.linux.template_release.x86_64.so"
}

install_bin_dir "addons/visual_gasic/bin"
install_bin_dir "demo/bin"

while IFS= read -r bin_dir; do
	[[ -n "$bin_dir" ]] || continue
	install_bin_dir "$bin_dir"
done < <(find "$ROOT" -path "*/addons/visual_gasic/bin" -type d 2>/dev/null || true)

echo "==> Patched editor slot from template_release" >&2
