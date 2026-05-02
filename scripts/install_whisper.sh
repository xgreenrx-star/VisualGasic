#!/usr/bin/env bash
# Install whisper.cpp (local speech-to-text) + the tiny English model.
#
# Total download: ~80 MB.  Files land in ~/.local/share/whisper/.
# VG auto-detects them on next launch via plugin.gd::_bootstrap_whisper.
#
# Usage:
#   bash scripts/install_whisper.sh
#
# Note: whisper.cpp ships source, not prebuilt binaries.  This script
# requires a working C++ toolchain (build-essential on Debian/Ubuntu,
# Xcode CLT on macOS).
#
set -euo pipefail

DEST="${WHISPER_DIR:-$HOME/.local/share/whisper}"
mkdir -p "$DEST"
cd "$DEST"

REPO="https://github.com/ggerganov/whisper.cpp.git"
MODEL="${WHISPER_MODEL:-ggml-tiny.en.bin}"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$MODEL"

if ! command -v cmake >/dev/null && ! command -v make >/dev/null; then
    echo "Need 'make' or 'cmake' to build whisper.cpp." >&2
    echo "  Debian/Ubuntu: sudo apt install build-essential" >&2
    echo "  macOS:         xcode-select --install" >&2
    exit 1
fi

echo "[1/3] Cloning whisper.cpp..."
if [[ ! -d whisper.cpp ]]; then
    git clone --depth 1 "$REPO" whisper.cpp
fi

echo "[2/3] Building (this takes a minute)..."
cd whisper.cpp
make -j"$(nproc 2>/dev/null || echo 4)" main 2>&1 | tail -5
# Newer versions of whisper.cpp put binaries under build/bin/.  Find the
# resulting executable and symlink it to a stable location so VG's
# auto-detect doesn't have to chase upstream layout changes.
BIN=""
for cand in main build/bin/main build/bin/whisper-cli; do
    if [[ -x "$cand" ]]; then BIN="$(pwd)/$cand"; break; fi
done
if [[ -z "$BIN" ]]; then
    echo "Build finished but no main/whisper-cli binary found." >&2
    exit 1
fi
ln -sf "$BIN" "$DEST/whisper"
cd "$DEST"

echo "[3/3] Downloading model ($MODEL, ~75 MB)..."
if [[ ! -f "$MODEL" ]]; then
    curl -fsSL -o "$MODEL" "$MODEL_URL"
fi

echo
echo "  ✓ whisper installed at $DEST/whisper"
echo "  ✓ model:                $DEST/$MODEL"
echo
echo "Restart Godot — mic mode in AI Pair will now use local Whisper"
echo "automatically (no API key, no network)."
