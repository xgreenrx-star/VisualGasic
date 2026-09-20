#!/usr/bin/env bash
# Install Emscripten SDK locally for VisualGasic web GDExtension builds.
# Idempotent: safe to re-run.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EMSDK_DIR="${EMSDK:-$ROOT/thirdparty/emsdk}"

if command -v emcc >/dev/null 2>&1; then
  echo "emcc already on PATH: $(emcc --version | head -1)"
  exit 0
fi

if [[ ! -d "$EMSDK_DIR" ]]; then
  echo "Cloning emsdk into $EMSDK_DIR ..."
  git clone --depth 1 https://github.com/emscripten-core/emsdk.git "$EMSDK_DIR"
fi

cd "$EMSDK_DIR"
./emsdk install latest
./emsdk activate latest
# shellcheck source=/dev/null
source ./emsdk_env.sh
echo "Emscripten ready: $(emcc --version | head -1)"
echo "Add to your shell: source $EMSDK_DIR/emsdk_env.sh"
