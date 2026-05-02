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
# Newer whisper.cpp dropped the legacy 'make main' target — it now builds
# via cmake and produces 'whisper-cli' under build/bin/.  Try cmake first
# and fall back to the old Makefile for older checkouts.
if [[ -f CMakeLists.txt ]]; then
    cmake -B build -DCMAKE_BUILD_TYPE=Release >/dev/null
    cmake --build build -j"$(nproc 2>/dev/null || echo 4)" --target whisper-cli 2>&1 | tail -3
else
    make -j"$(nproc 2>/dev/null || echo 4)" main 2>&1 | tail -3
fi
# Find the resulting executable and symlink it to a stable location.
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

# Pre-configure VG's voice settings so STT uses local Whisper on next
# launch — without this users without an OpenAI key would still hit
# 'OpenAI Whisper requires an OpenAI API key'.  Update every existing
# Godot project's vg_ai_voice.cfg.
GODOT_DATA="$HOME/.local/share/godot/app_userdata"
[[ "$(uname -s)" == "Darwin" ]] && GODOT_DATA="$HOME/Library/Application Support/Godot/app_userdata"
WBIN="$DEST/whisper"
WMODEL="$DEST/$MODEL"
if [[ -d "$GODOT_DATA" ]]; then
    while IFS= read -r -d '' proj; do
        cfg="$proj/vg_ai_voice.cfg"
        if [[ -f "$cfg" ]]; then
            # Edit existing cfg in place: flip stt_backend to whisper and
            # set the path/model (preserve all other values).
            python3 - "$cfg" "$WBIN" "$WMODEL" <<'PY'
import sys, re, pathlib
cfg, wbin, wmodel = sys.argv[1], sys.argv[2], sys.argv[3]
p = pathlib.Path(cfg)
text = p.read_text()
def setkv(t, key, val):
    pat = re.compile(rf'^{re.escape(key)}=.*$', re.M)
    line = f'{key}="{val}"'
    return pat.sub(line, t) if pat.search(t) else t.rstrip() + "\n" + line + "\n"
text = setkv(text, "stt_backend", "whisper")
text = setkv(text, "whisper_cpp_path", wbin)
text = setkv(text, "whisper_cpp_model", wmodel)
p.write_text(text)
PY
        else
            cat > "$cfg" <<EOF
[voice]

stt_backend="whisper"
tts_backend="openai"
tts_voice="alloy"
auto_speak_replies=true
whisper_cpp_path="$WBIN"
whisper_cpp_model="$WMODEL"
piper_path="piper"
piper_voice_path=""
EOF
        fi
        echo "  Configured: $cfg"
    done < <(find "$GODOT_DATA" -mindepth 1 -maxdepth 1 -type d -print0)
fi

echo
echo "Restart Godot — mic mode in AI Pair will now use local Whisper"
echo "automatically (no API key, no network)."
