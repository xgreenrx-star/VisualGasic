#!/usr/bin/env bash
# Export a VG Godot project to HTML5 (requires WASM GDExtension + Godot 4.6+ export templates).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${1:-}"
PRESET="${2:-Web}"
OUT_DIR="${3:-$ROOT/build/web}"

if [[ -z "$PROJECT" ]]; then
  echo "Usage: $0 <path/to/project.godot or project_dir> [preset_name] [output_dir]" >&2
  exit 1
fi

if [[ -d "$PROJECT" ]]; then
  PROJECT="$(cd "$PROJECT" && pwd)/project.godot"
fi
PROJ_DIR="$(dirname "$PROJECT")"

GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
  # Web export requires non-Mono Godot 4.x (Mono builds refuse HTML5 export).
  for c in "$ROOT/Godot_v4.6.1-stable_linux.x86_64" \
           "$ROOT/Godot_v4.6.1-stable_mono_linux_x86_64/Godot_v4.6.1-stable_mono_linux.x86_64"; do
    if [[ -x "$c" ]]; then GODOT="$c"; break; fi
  done
fi

WASM="addons/visual_gasic/bin/libvisualgasic.web.template_release.wasm32.nothreads.wasm"
if [[ ! -f "$PROJ_DIR/$WASM" && ! -f "$ROOT/$WASM" ]]; then
  echo "Missing $WASM — run: bash scripts/build_web_gdextension.sh" >&2
  exit 1
fi

python3 "$ROOT/scripts/strip_tweak_overlay.py" --project "$PROJ_DIR"

mkdir -p "$OUT_DIR"
NAME="$(basename "$PROJ_DIR")"
DEST="$OUT_DIR/$NAME"
rm -rf "$DEST"
mkdir -p "$DEST"

echo "Exporting $PROJ_DIR preset=$PRESET -> $DEST"
"$GODOT" --headless --path "$PROJ_DIR" --export-release "$PRESET" "$DEST/index.html"

echo "Done: $DEST/index.html"
