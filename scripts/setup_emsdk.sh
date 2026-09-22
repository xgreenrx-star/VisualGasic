#!/usr/bin/env bash
# Install Emscripten SDK locally for VisualGasic web GDExtension builds.
# Must match Godot official export templates (4.6.x → 4.0.20).
# Idempotent: safe to re-run.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EMSDK_DIR="${EMSDK:-$ROOT/thirdparty/emsdk}"
# Godot 4.6.1 official web builds: godotengine/build-containers 4.6/Dockerfile.web
EMSCRIPTEN_VERSION="${EMSCRIPTEN_VERSION:-4.0.20}"

_emcc_version_line() {
  emcc --version 2>/dev/null | head -1 || true
}

_version_ok() {
  local line
  line="$(_emcc_version_line)"
  [[ -n "$line" ]] && [[ "$line" == *"${EMSCRIPTEN_VERSION}"* ]]
}

if _version_ok; then
  echo "Emscripten OK (Godot ${EMSCRIPTEN_VERSION}): $(_emcc_version_line)"
  exit 0
fi

if command -v emcc >/dev/null 2>&1; then
  echo "WARNING: emcc on PATH does not match Godot web templates (${EMSCRIPTEN_VERSION}):" >&2
  echo "  $(_emcc_version_line)" >&2
  echo "Installing pinned emsdk under $EMSDK_DIR ..." >&2
fi

if [[ ! -d "$EMSDK_DIR" ]]; then
  echo "Cloning emsdk into $EMSDK_DIR ..."
  git clone https://github.com/emscripten-core/emsdk.git "$EMSDK_DIR"
fi

cd "$EMSDK_DIR"
./emsdk install "${EMSCRIPTEN_VERSION}"
./emsdk activate "${EMSCRIPTEN_VERSION}"
# shellcheck source=/dev/null
source ./emsdk_env.sh

if ! _version_ok; then
  echo "error: expected Emscripten ${EMSCRIPTEN_VERSION} after activate, got: $(_emcc_version_line)" >&2
  exit 1
fi

echo "Emscripten ready: $(_emcc_version_line)"
echo "Add to your shell: source $EMSDK_DIR/emsdk_env.sh"
