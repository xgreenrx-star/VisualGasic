#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/editor_regression_helpers.sh"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
OUT_DIR="${OUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/vg-crystal-caverns-XXXXXX")}"
RENDER_MODE="${RENDER_MODE:-headless}"
TIMEOUT_SECS="${TIMEOUT_SECS:-60}"
if [[ ! -x "$GODOT" ]]; then
	echo "ERROR: GODOT must name an executable engine" >&2
	exit 1
fi
case "$RENDER_MODE" in
	headless) args=(--headless --audio-driver Dummy); expected=81; fx_expected=278 ;;
	graphical) args=(--rendering-method gl_compatibility --audio-driver Dummy); expected=89; fx_expected=303 ;;
	*) echo "ERROR: RENDER_MODE must be headless or graphical" >&2; exit 1 ;;
esac
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
if [[ -e "$OUT_DIR/project" || -L "$OUT_DIR/project" ]]; then
	echo "ERROR: use a fresh OUT_DIR" >&2
	exit 1
fi
project="$OUT_DIR/project"
mkdir -p "$project"
cp "$ROOT/samples/showcases/crystal_caverns/"{project.godot,main.tscn,Caverns.vg,regression.gd,editor_regression.gd} "$project/"
cp "$ROOT/samples/showcases/crystal_caverns/"{VisualEffects.vg,SoundEffects.vg,effects_regression.gd,sound_regression.gd,regression_lifecycle.gd} "$project/"
cp -a "$ROOT/samples/showcases/crystal_caverns/shaders" "$project/"
prepare_editor_regression_addon "$project"
import_log="$OUT_DIR/import.log"
rc=0
env -u VG_FORCE_AST timeout "$TIMEOUT_SECS" "$GODOT" --headless --editor --path "$project" \
	--import > "$import_log" 2>&1 || rc=$?
if [[ "$rc" -ne 0 ]] ||
		grep -Eq '^ERROR:|SCRIPT ERROR|Parser Error|Unicode parsing error|handle_crash:|leaked at exit|were leaked' "$import_log"; then
	echo "FAIL: Crystal Caverns editor import (exit=$rc); see $import_log" >&2
	tail -n 35 "$import_log" >&2
	exit 1
fi
editor_log="$OUT_DIR/editor.log"
rc=0
env -u VG_FORCE_AST timeout "$TIMEOUT_SECS" "$GODOT" "${args[@]}" --path "$project" \
	--script editor_regression.gd > "$editor_log" 2>&1 || rc=$?
if [[ "$rc" -ne 0 ]] ||
		! grep -Fxq "EDITOR RESULTS: 190 passed, 0 failed" "$editor_log" ||
		grep -Eq '^ERROR:|SCRIPT ERROR|Parser Error|Unicode parsing error|handle_crash:|leaked at exit|were leaked' "$editor_log"; then
	echo "FAIL: Crystal Caverns editor/$RENDER_MODE (exit=$rc); see $editor_log" >&2
	tail -n 35 "$editor_log" >&2
	exit 1
fi
echo "PASS: Crystal Caverns editor/$RENDER_MODE (190 checks); $editor_log"
for mode in default ast; do
	log="$OUT_DIR/$mode.log"
	environment=(env -u VG_FORCE_AST)
	[[ "$mode" == ast ]] && environment=(env VG_FORCE_AST=1)
	rc=0
	"${environment[@]}" CRYSTAL_CAPTURE="$OUT_DIR/$mode.png" \
		timeout "$TIMEOUT_SECS" "$GODOT" "${args[@]}" --path "$project" \
		--script regression.gd > "$log" 2>&1 || rc=$?
	if [[ "$rc" -ne 0 ]] ||
			! grep -Fxq "CRYSTAL-CAVERNS RESULTS: $expected checks, 0 failures" "$log" ||
			grep -Eq '^ERROR:|SCRIPT ERROR|Parser Error|handle_crash:|leaked at exit|were leaked' "$log"; then
		echo "FAIL: Crystal Caverns $mode/$RENDER_MODE (exit=$rc); see $log" >&2
		tail -n 35 "$log" >&2
		exit 1
	fi
	echo "PASS: Crystal Caverns $mode/$RENDER_MODE ($expected checks); $log"
	fx_log="$OUT_DIR/$mode-effects.log"
	mkdir -p "$OUT_DIR/$mode-effects"
	rc=0
	"${environment[@]}" CRYSTAL_FX_CAPTURE="$OUT_DIR/$mode-effects" \
		timeout "$TIMEOUT_SECS" "$GODOT" "${args[@]}" --path "$project" \
		--script effects_regression.gd > "$fx_log" 2>&1 || rc=$?
	if [[ "$rc" -ne 0 ]] ||
			! grep -Fxq "EFFECTS RESULTS: $fx_expected checks, 0 failures" "$fx_log" ||
			grep -Eq '^ERROR:|SCRIPT ERROR|Parser Error|Shader compilation failed|handle_crash:|leaked at exit|were leaked' "$fx_log"; then
		echo "FAIL: Crystal Caverns effects $mode/$RENDER_MODE (exit=$rc); see $fx_log" >&2
		tail -n 40 "$fx_log" >&2
		exit 1
	fi
	echo "PASS: Crystal Caverns effects $mode/$RENDER_MODE; $fx_log"
	sound_log="$OUT_DIR/$mode-sound.log"
	mkdir -p "$OUT_DIR/$mode-sound"
	rc=0
	"${environment[@]}" CRYSTAL_SOUND_CAPTURE="$OUT_DIR/$mode-sound" \
		timeout "$TIMEOUT_SECS" "$GODOT" "${args[@]}" --audio-driver Dummy --path "$project" \
		--script sound_regression.gd > "$sound_log" 2>&1 || rc=$?
	if [[ "$rc" -ne 0 ]] ||
			! grep -Fxq 'SOUND RESULTS: 95 checks, 0 failures' "$sound_log" ||
			grep -Eq '^ERROR:|SCRIPT ERROR|Parser Error|handle_crash:|leaked at exit|were leaked' "$sound_log"; then
		echo "FAIL: Crystal Caverns sound $mode/$RENDER_MODE (exit=$rc); see $sound_log" >&2
		tail -n 40 "$sound_log" >&2
		exit 1
	fi
	echo "PASS: Crystal Caverns sound $mode/$RENDER_MODE; $sound_log"
done
echo "CRYSTAL-CAVERNS MATRIX: 2/2 modes passed; evidence $OUT_DIR"
