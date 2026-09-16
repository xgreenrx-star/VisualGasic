#!/usr/bin/env bash
# record_narcea_movie_demo.sh — Frame-perfect Narcea × Cursor movie capture.
#
# Usage:
#   scripts/record_narcea_movie_demo.sh
#   GODOT=/path/to/godot scripts/record_narcea_movie_demo.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
PROJECT="$ROOT/samples/showcases/vg_narcea_movie_demo"
AVI="$PROJECT/vg_narcea_movie.avi"
MP4="$ROOT/vg_narcea_movie.mp4"

if [[ ! -x "$GODOT" ]]; then
	echo "Godot binary not found at $GODOT" >&2
	exit 2
fi

echo "── Bootstrap extension import ──"
(cd "$PROJECT" && "$GODOT" --headless --quit --editor >/dev/null 2>&1 || true)

echo "── Recording Narcea movie demo (~2–3 min) ──"
rm -f "$AVI"

(cd "$PROJECT" && "$GODOT" \
	--path . \
	--write-movie res://vg_narcea_movie.avi \
	--resolution 1280x720 \
	--fixed-fps 60)

if [[ ! -f "$AVI" ]]; then
	echo "ERROR: Movie Maker did not create $AVI" >&2
	exit 1
fi

if command -v ffmpeg >/dev/null 2>&1; then
	ffmpeg -y -hide_banner -loglevel error \
		-i "$AVI" \
		-c:v libx264 -crf 18 -pix_fmt yuv420p \
		-c:a aac -b:a 192k \
		"$MP4"
	echo "Done: $MP4"
else
	echo "AVI: $AVI (install ffmpeg for MP4)"
fi
