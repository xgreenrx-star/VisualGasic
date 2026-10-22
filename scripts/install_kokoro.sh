#!/usr/bin/env bash
# Install Sherpa-ONNX + Kokoro-82M English voices for Visual Gasic TTS.
#
# Total download: ~350 MB (runtime ~28 MB + kokoro-en-v0_19 ~320 MB).
# Files land in ~/.local/share/visual_gasic/tts (macOS: Application Support).
# VG auto-detects them on next launch — no extra Voice Settings step.
#
# Usage:
#   bash scripts/install_kokoro.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHERPA_VERSION="${SHERPA_VERSION:-1.13.8}"
MODEL_NAME="kokoro-en-v0_19"

case "$(uname -s)-$(uname -m)" in
    Linux-x86_64)
        DEST="${KOKORO_DIR:-$HOME/.local/share/visual_gasic/tts}"
        RUNTIME_ARCHIVE="sherpa-onnx-v${SHERPA_VERSION}-linux-x64-shared.tar.bz2"
        BIN_NAME="sherpa-onnx-offline-tts"
        ;;
    Linux-aarch64)
        DEST="${KOKORO_DIR:-$HOME/.local/share/visual_gasic/tts}"
        RUNTIME_ARCHIVE="sherpa-onnx-v${SHERPA_VERSION}-linux-aarch64-shared-cpu.tar.bz2"
        BIN_NAME="sherpa-onnx-offline-tts"
        ;;
    Darwin-x86_64)
        DEST="${KOKORO_DIR:-$HOME/Library/Application Support/visual_gasic/tts}"
        RUNTIME_ARCHIVE="sherpa-onnx-v${SHERPA_VERSION}-osx-x64-shared.tar.bz2"
        BIN_NAME="sherpa-onnx-offline-tts"
        ;;
    Darwin-arm64)
        DEST="${KOKORO_DIR:-$HOME/Library/Application Support/visual_gasic/tts}"
        RUNTIME_ARCHIVE="sherpa-onnx-v${SHERPA_VERSION}-osx-arm64-shared.tar.bz2"
        BIN_NAME="sherpa-onnx-offline-tts"
        ;;
    *)
        echo "Unsupported platform: $(uname -s)-$(uname -m)" >&2
        echo "See https://github.com/k2-fsa/sherpa-onnx/releases" >&2
        exit 1
        ;;
esac

mkdir -p "$DEST/runtime" "$DEST/models"
cd "$DEST"

echo "[1/4] Installing Sherpa-ONNX runtime into $DEST/runtime ..."
if [[ ! -x "$DEST/runtime/bin/$BIN_NAME" && ! -x "$(find "$DEST/runtime" -name "$BIN_NAME" -type f 2>/dev/null | head -n1)" ]]; then
    curl -fL "https://github.com/k2-fsa/sherpa-onnx/releases/download/v${SHERPA_VERSION}/${RUNTIME_ARCHIVE}" \
        -o "$DEST/$RUNTIME_ARCHIVE"
    tar -xjf "$DEST/$RUNTIME_ARCHIVE" -C "$DEST/runtime" --strip-components=1
    rm -f "$DEST/$RUNTIME_ARCHIVE"
    echo "      done."
else
    echo "      already installed."
fi

BIN_PATH="$(find "$DEST/runtime" -name "$BIN_NAME" -type f | head -n1)"
LIB_DIR="$DEST/runtime/lib"
if [[ ! -x "$BIN_PATH" ]]; then
    echo "Could not find $BIN_NAME after extract." >&2
    exit 1
fi
chmod +x "$BIN_PATH"

echo "[2/4] Writing $DEST/vg-tts launcher ..."
if [[ "$(uname -s)" == "Darwin" ]]; then
    cat > "$DEST/vg-tts" <<EOF
#!/bin/sh
export DYLD_LIBRARY_PATH="$LIB_DIR\${DYLD_LIBRARY_PATH:+:\$DYLD_LIBRARY_PATH}"
exec "$BIN_PATH" "\$@"
EOF
else
    cat > "$DEST/vg-tts" <<EOF
#!/bin/sh
export LD_LIBRARY_PATH="$LIB_DIR\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec "$BIN_PATH" "\$@"
EOF
fi
chmod +x "$DEST/vg-tts"

echo "[3/4] Building persistent Kokoro daemon ..."
DAEMON_SRC="$SCRIPT_DIR/vg_tts_daemon.c"
DAEMON_BIN="$DEST/runtime/bin/vg-tts-daemon"
INCLUDE_DIR="$DEST/runtime/include"
if [[ -f "$DAEMON_SRC" ]] && command -v gcc >/dev/null 2>&1; then
    mkdir -p "$DEST/runtime/bin"
    RPATH_FLAG="-Wl,-rpath,\$ORIGIN/../lib"
    if [[ "$(uname -s)" == "Darwin" ]]; then
        RPATH_FLAG="-Wl,-rpath,@executable_path/../lib"
    fi
    gcc -O2 -o "$DAEMON_BIN" "$DAEMON_SRC" \
        -I"$INCLUDE_DIR" -L"$LIB_DIR" -lsherpa-onnx-c-api "$RPATH_FLAG"
    chmod +x "$DAEMON_BIN"
    if [[ "$(uname -s)" == "Darwin" ]]; then
        cat > "$DEST/vg-tts-daemon" <<EOF
#!/bin/sh
export DYLD_LIBRARY_PATH="$LIB_DIR\${DYLD_LIBRARY_PATH:+:\$DYLD_LIBRARY_PATH}"
exec "$DAEMON_BIN" "\$@"
EOF
    else
        cat > "$DEST/vg-tts-daemon" <<EOF
#!/bin/sh
export LD_LIBRARY_PATH="$LIB_DIR\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec "$DAEMON_BIN" "\$@"
EOF
    fi
    chmod +x "$DEST/vg-tts-daemon"
    echo "      daemon ready."
else
    echo "      skipped (need gcc and $DAEMON_SRC). One-shot vg-tts still works, but each line reloads the model."
fi

echo "[4/4] Downloading Kokoro English pack (~320 MB) ..."
if [[ -f "$DEST/models/$MODEL_NAME/model.onnx" ]]; then
    echo "      $MODEL_NAME  (already installed)"
else
    curl -fL "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/${MODEL_NAME}.tar.bz2" \
        -o "$DEST/${MODEL_NAME}.tar.bz2"
    tar -xjf "$DEST/${MODEL_NAME}.tar.bz2" -C "$DEST/models"
    rm -f "$DEST/${MODEL_NAME}.tar.bz2"
    echo "      done."
fi

if [[ ! -f "$DEST/models/$MODEL_NAME/model.onnx" ]]; then
    echo "Kokoro model files missing after extract." >&2
    exit 1
fi

echo
echo "  Kokoro TTS installed at $DEST"
echo "  Voices: af_bella, am_michael, bm_george, bm_lewis, … (11 English speakers)"

GODOT_DATA="$HOME/.local/share/godot/app_userdata"
[[ "$(uname -s)" == "Darwin" ]] && GODOT_DATA="$HOME/Library/Application Support/Godot/app_userdata"
if [[ -d "$GODOT_DATA" ]]; then
    while IFS= read -r -d '' proj; do
        cat > "$proj/vg_ai_voice.cfg" <<EOF
[voice]

stt_backend="openai"
tts_backend="kokoro"
tts_voice="alloy"
auto_speak_replies=true
whisper_cpp_path="whisper"
whisper_cpp_model=""
piper_path="piper"
piper_voice_path=""
EOF
        echo "  Configured: $proj/vg_ai_voice.cfg"
    done < <(find "$GODOT_DATA" -mindepth 1 -maxdepth 1 -type d -print0)
fi

echo
echo "Restart Godot. Vibe Code and Ash flight voice now use Kokoro when present."
echo "Orac = bm_george, Narcea = af_nicole, Skippy = bm_lewis."
