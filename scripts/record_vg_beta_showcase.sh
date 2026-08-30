#!/usr/bin/env bash
# record_vg_beta_showcase.sh — Frame-perfect capture via Godot Movie Maker.
#
# Same pipeline as projects/demoscene_intro ( --write-movie → AVI → optional MP4 ).
# Plays tour → backrooms hub → all demos → end card, then quits automatically.
#
# Usage:
#   scripts/record_vg_beta_showcase.sh
#   GODOT=/path/to/godot scripts/record_vg_beta_showcase.sh
#
# Output:
#   projects/vg_beta_showcase/vg_beta_showcase.avi
#   vg_beta_showcase.mp4  (repo root, when ffmpeg is installed)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
PROJECT="$ROOT/projects/vg_beta_showcase"
AVI="$PROJECT/vg_beta_showcase.avi"
MP4="$ROOT/vg_beta_showcase.mp4"

if [[ ! -x "$GODOT" ]]; then
	echo "Godot binary not found at $GODOT" >&2
	echo "  (override with GODOT=/path/to/godot)" >&2
	exit 2
fi

echo "── Bootstrap extension import (one-time / CI cache) ──"
(cd "$PROJECT" && "$GODOT" --headless --quit --editor >/dev/null 2>&1 || true)

echo "── Recording showcase (~6–8 min real time) ──"
echo "   Project: $PROJECT"
echo "   Output:  $AVI"
rm -f "$AVI"

(cd "$PROJECT" && "$GODOT" \
	--path . \
	--write-movie res://vg_beta_showcase.avi \
	--resolution 1280x720 \
	--fixed-fps 60)

if [[ ! -f "$AVI" ]]; then
	echo "ERROR: Movie Maker did not create $AVI" >&2
	exit 1
fi

echo "── AVI written: $AVI ──"

if command -v ffmpeg >/dev/null 2>&1; then
	echo "── Converting to H.264 MP4 ──"
	ffmpeg -y -hide_banner -loglevel error \
		-i "$AVI" \
		-c:v libx264 -crf 18 -pix_fmt yuv420p \
		-c:a aac -b:a 192k \
		"$MP4"
	echo "Done: $MP4"
else
	echo "Install ffmpeg to auto-convert to $MP4"
	echo "  ffmpeg -i \"$AVI\" -c:v libx264 -crf 18 -pix_fmt yuv420p -c:a aac -b:a 192k \"$MP4\""
fi
