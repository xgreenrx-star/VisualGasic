#!/usr/bin/env bash
# Build libvisualgasic.*.wasm for Godot 4.6 HTML5 export (single-threaded / no COOP-COEP).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TARGET="${1:-template_release}"
THREADS="${VG_WEB_THREADS:-no}"

if ! command -v emcc >/dev/null 2>&1; then
  if [[ -f "$ROOT/thirdparty/emsdk/emsdk_env.sh" ]]; then
    # shellcheck source=/dev/null
    source "$ROOT/thirdparty/emsdk/emsdk_env.sh"
  else
    echo "Emscripten not found. Run: bash scripts/setup_emsdk.sh" >&2
    exit 1
  fi
fi

if ! command -v emcc >/dev/null 2>&1; then
  echo "emcc still not on PATH after emsdk_env.sh" >&2
  exit 1
fi

NPROC="$(nproc 2>/dev/null || echo 4)"
echo "Building VisualGasic GDExtension for web ($TARGET, threads=$THREADS) ..."

scons platform=web target="$TARGET" arch=wasm32 threads="$THREADS" -j"$NPROC"

if [[ "$TARGET" == "template_release" ]]; then
  scons platform=web target=template_debug arch=wasm32 threads="$THREADS" -j"$NPROC"
fi

echo "WASM outputs in demo/bin/ and addons/visual_gasic/bin/:"
ls -lh addons/visual_gasic/bin/libvisualgasic.web.*.wasm 2>/dev/null || ls -lh demo/bin/libvisualgasic.web.*.wasm
