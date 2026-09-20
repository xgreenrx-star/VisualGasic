#!/usr/bin/env bash
# Verify Visual Gasic Web (WASM) GDExtension binaries are present for export.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

RELEASE_WASM="addons/visual_gasic/bin/libvisualgasic.web.template_release.wasm32.nothreads.wasm"
DEBUG_WASM="addons/visual_gasic/bin/libvisualgasic.web.template_debug.wasm32.nothreads.wasm"

if [[ ! -f "$RELEASE_WASM" ]]; then
  echo "Missing required Web GDExtension: $RELEASE_WASM" >&2
  echo "Build with: bash scripts/build_web_gdextension.sh" >&2
  exit 1
fi

if [[ ! -f "$DEBUG_WASM" ]]; then
  echo "Warning: debug WASM missing ($DEBUG_WASM) — release export may still work." >&2
fi

echo "OK: Web GDExtension ready ($(du -h "$RELEASE_WASM" | cut -f1) release)"
