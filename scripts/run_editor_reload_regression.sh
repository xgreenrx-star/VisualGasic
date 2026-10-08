#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
TIMEOUT_SECS="${TIMEOUT_SECS:-120}"
OUT_DIR="${OUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/vg-editor-reload-XXXXXX")}"
RENDER_MODE="${RENDER_MODE:-headless}"

if [[ ! -x "$GODOT" ]]; then
	echo "ERROR: GODOT must name an executable engine" >&2
	exit 1
fi
case "$RENDER_MODE" in
	headless)
		engine_args=(--headless)
		import_mode_args=()
		;;
	graphical)
		engine_args=(--rendering-method gl_compatibility --audio-driver Dummy)
		import_mode_args=(--headless)
		;;
	*) echo "ERROR: RENDER_MODE must be headless or graphical" >&2; exit 1 ;;
esac
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
cd "$ROOT"
for name in native-probe brotato_vg brotato3d; do
	if [[ -e "$OUT_DIR/$name" || -L "$OUT_DIR/$name" ]]; then
		echo "ERROR: use a fresh OUT_DIR; $OUT_DIR/$name already exists" >&2
		exit 1
	fi
done

bootstrap() {
	local project="$1"
	mkdir -p "$project/addons" "$project/.godot"
	ln -sfn "$ROOT/addons/visual_gasic" "$project/addons/visual_gasic"
	printf '%s\n' res://addons/visual_gasic/visual_gasic.gdextension > "$project/.godot/extension_list.cfg"
}

run_engine() {
	local project="$1" log="$2"
	shift 2
	if ! timeout "$TIMEOUT_SECS" "$GODOT" "${engine_args[@]}" --path "$project" "$@" > "$log" 2>&1; then
		echo "FAIL: engine failed or timed out; see $log" >&2
		tail -n 20 "$log" >&2
		exit 1
	fi
	if grep -Eq 'HOT-RELOAD-SELFTEST.*FAIL:|HOT-RELOAD-SELFTEST.*[1-9][0-9]* failed|signal 11|SIGSEGV|malloc\(\)|double free|Parser Error|SCRIPT ERROR' "$log"; then
		echo "FAIL: fatal or script diagnostic; see $log" >&2
		exit 1
	fi
}

probe="$OUT_DIR/native-probe"
bootstrap "$probe"
cat > "$probe/project.godot" <<'PROJECT'
config_version=5
[application]
config/name="VG Hot Reload Regression"
run/main_scene="res://main.tscn"
[rendering]
renderer/rendering_method="gl_compatibility"
PROJECT
printf '[gd_scene format=3]\n[node name="Probe" type="Node"]\n' > "$probe/main.tscn"
VG_HOT_RELOAD_SELFTEST=1 run_engine "$probe" "$OUT_DIR/native-probe.log" --quit
if ! grep -Fq '[HOT-RELOAD-SELFTEST] RESULTS: 9 passed, 0 failed' "$OUT_DIR/native-probe.log"; then
	echo "FAIL: native probe did not complete all nine checks" >&2
	exit 1
fi
if grep -Eq '^ERROR:|leaked at exit|were leaked' "$OUT_DIR/native-probe.log"; then
	echo "FAIL: native probe produced errors or teardown leaks; see $OUT_DIR/native-probe.log" >&2
	exit 1
fi
echo "PASS: native reload-all/queued-reload/lifetime checks"

for sample in brotato_vg brotato3d; do
	project="$OUT_DIR/$sample"
	mkdir -p "$project"
	git ls-files -z "samples/games/$sample" |
		tar --null -T - -cf - |
		tar -xf - -C "$project" --strip-components=3
	bootstrap "$project"
	log="$OUT_DIR/$sample-import.log"
	run_engine "$project" "$log" "${import_mode_args[@]}" --editor --import
	if ! grep -Eq '\[ DONE \].*loading_editor_layout' "$log" ||
			! grep -Fq '[VG Hot Reload] Reloaded ' "$log"; then
		echo "FAIL: $sample did not complete editor loading and exercise reload-all; see $log" >&2
		exit 1
	fi
	if ! grep -Eq '\.vg::VisualGasicScript::' "$project/.godot/editor/filesystem_cache10"; then
		echo "FAIL: $sample editor cache does not recognize VG scripts; see $log" >&2
		exit 1
	fi
	if grep -Eq 'No loader found for resource: res://assets/fonts/Kenney_Pixel\.ttf|Failed loading resource: res://themes/default_theme\.tres|Error loading custom project theme' "$log"; then
		echo "FAIL: $sample cold import could not defer the custom theme until its font was imported; see $log" >&2
		exit 1
	fi
	runtime_log="$OUT_DIR/$sample-runtime.log"
	run_engine "$project" "$runtime_log" --quit-after 60
	if grep -Eq '^ERROR:|SCRIPT ERROR' "$runtime_log"; then
		echo "FAIL: $sample game startup did not load its imported theme cleanly; see $runtime_log" >&2
		exit 1
	fi
	echo "PASS: pristine $sample import and themed game startup completed ($RENDER_MODE)"
	# Editor teardown diagnostics are retained and not counted as clean shutdown.
	grep -E '^ERROR:|leaked at exit|were leaked|Canceling suspended' "$log" || true
done
echo "RESULTS: 3/3 reload regressions and both Brotato theme startups passed; logs retained in $OUT_DIR"
