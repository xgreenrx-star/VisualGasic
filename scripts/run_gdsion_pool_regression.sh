#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
OUT_DIR="${OUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/vg-gdsion-pool-XXXXXX")}"
CPP="$ROOT/vendor/gdsion/godot-cpp"
LIB="$CPP/bin/libgodot-cpp.linux.template_debug.x86_64.a"
if [[ ! -x "$GODOT" || ! -f "$LIB" ]]; then
	echo "ERROR: executable GODOT and built vendor/gdsion godot-cpp debug library required" >&2
	exit 1
fi
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
project="$OUT_DIR/project"
if [[ -e "$project" || -L "$project" ]]; then
	echo "ERROR: use a fresh OUT_DIR; $project already exists" >&2
	exit 1
fi
if ! git -C "$ROOT/vendor/gdsion" apply --reverse --check \
		"$ROOT/addons/visual_gasic/plugins/vgmusic/gdsion_pool_lifetime.patch" 2>/dev/null; then
	echo "ERROR: apply the GDSiON pool lifetime patch with build_gdsion.sh first" >&2
	exit 1
fi
mkdir -p "$project/.godot"
"${CXX:-g++}" -std=c++17 -shared -fPIC -fvisibility=hidden -g \
	-I"$CPP/include" -I"$CPP/gen/include" -I"$CPP/gdextension" \
	-I"$ROOT/vendor/gdsion/src" "$ROOT/test_proj/tools/gdsion_pool_selftest.cpp" \
	"$LIB" -o "$project/libpool_probe.so" > "$OUT_DIR/build.log" 2>&1 || {
	echo "FAIL: native pool probe build failed; see $OUT_DIR/build.log" >&2
	tail -n 20 "$OUT_DIR/build.log" >&2
	exit 1
}
printf 'config_version=5\n[application]\nconfig/name="GDSiON Pool Regression"\n' > "$project/project.godot"
cat > "$project/pool_probe.gdextension" <<'EXTENSION'
[configuration]
entry_symbol="gdsion_pool_probe_init"
compatibility_minimum="4.3"
[libraries]
linux.debug.x86_64="res://libpool_probe.so"
EXTENSION
printf '%s\n' res://pool_probe.gdextension > "$project/.godot/extension_list.cfg"
log="$OUT_DIR/engine.log"
if ! timeout 60 env MALLOC_PERTURB_=165 GLIBC_TUNABLES=glibc.malloc.check=3 \
		"$GODOT" --headless --path "$project" --editor --quit > "$log" 2>&1; then
	echo "FAIL: native pool probe crashed or timed out; see $log" >&2
	tail -n 20 "$log" >&2
	exit 1
fi
if ! grep -Fxq 'GDSION-POOL RESULTS: 14 passed, 0 failed' "$log" ||
		grep -Eq '^ERROR:|GDSION-POOL FAIL:|leaked|signal 11|malloc\(\)|double free' "$log"; then
	echo "FAIL: native pool checks incomplete or diagnostics present; see $log" >&2
	tail -n 20 "$log" >&2
	exit 1
fi
grep '^GDSION-POOL RESULTS:' "$log"
echo "PASS: allocator-perturbed pool lifecycle; full log $log"
