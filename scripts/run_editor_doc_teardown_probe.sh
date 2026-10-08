#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
OUT_DIR="${OUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/vg-doc-teardown-XXXXXX")}"
SCRIPT_COUNT="${SCRIPT_COUNT:-400}"
RENDER_MODE="${RENDER_MODE:-graphical}"
TIMEOUT_SECS="${TIMEOUT_SECS:-120}"
if [[ ! -x "$GODOT" || ! "$SCRIPT_COUNT" =~ ^[1-9][0-9]*$ ]]; then
	echo "ERROR: executable GODOT and positive SCRIPT_COUNT required" >&2
	exit 1
fi
case "$RENDER_MODE" in
	graphical) args=(--rendering-method gl_compatibility --audio-driver Dummy) ;;
	headless) args=(--headless) ;;
	*) echo "ERROR: invalid RENDER_MODE" >&2; exit 1 ;;
esac
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
project="$OUT_DIR/project"
if [[ -e "$project" || -L "$project" ]]; then
	echo "ERROR: use a fresh OUT_DIR" >&2
	exit 1
fi
mkdir -p "$project/addons/doc_probe" "$project/scripts"
cp "$ROOT/test_proj/tools/editor_doc_teardown/plugin.gd" \
	"$ROOT/test_proj/tools/editor_doc_teardown/plugin.cfg" "$project/addons/doc_probe/"
cat > "$project/project.godot" <<'PROJECT'
config_version=5
[application]
config/name="No-VG Documentation Teardown"
[rendering]
renderer/rendering_method="gl_compatibility"
PROJECT
for ((index=0; index<SCRIPT_COUNT; index++)); do
	script="$project/scripts/fixture_$index.gd"
	printf 'extends RefCounted\n\n' > "$script"
	for ((method=0; method<32; method++)); do
		printf 'func value_%s() -> int:\n\treturn %s\n\n' "$method" "$method" >> "$script"
	done
done
import_log="$OUT_DIR/import.log"
if ! timeout "$TIMEOUT_SECS" "$GODOT" --headless --editor --import --path "$project" \
		> "$import_log" 2>&1 ||
		grep -Eq '^ERROR:|SCRIPT ERROR|Parser Error|handle_crash:' "$import_log"; then
	echo "FAIL: initial fixture import; see $import_log" >&2
	exit 1
fi
printf '\n[editor_plugins]\nenabled=PackedStringArray("res://addons/doc_probe/plugin.cfg")\n' \
	>> "$project/project.godot"
log="$OUT_DIR/editor.log"
rc=0
timeout "$TIMEOUT_SECS" "$GODOT" "${args[@]}" --editor --path "$project" \
	> "$log" 2>&1 || rc=$?
if [[ "$rc" -ne 0 ]] ||
		! grep -Fxq 'DOC-TEARDOWN: filesystem scan completed; quitting' "$log" ||
		grep -Eq '^ERROR:|SCRIPT ERROR|Parser Error|handle_crash:|leaked at exit|were leaked' "$log"; then
	echo "FAIL: no-VG documentation teardown (exit=$rc); see $log" >&2
	tail -n 24 "$log" >&2
	exit 1
fi
echo "PASS: no-VG $RENDER_MODE documentation teardown; log $log"
