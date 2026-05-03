#!/usr/bin/env bash
# Install Piper neural TTS + the five voices VG personas use.
#
# Total download: ~340 MB (Piper binary ~25 MB + 5 voice models @ ~63 MB).
# Files land in ~/.local/share/piper/.  VG auto-detects them on next launch
# (no further configuration needed — see plugin.gd::_bootstrap_piper).
#
# Usage:
#   bash scripts/install_piper.sh
#
set -euo pipefail

DEST="${PIPER_DIR:-$HOME/.local/share/piper}"
mkdir -p "$DEST"
cd "$DEST"

PIPER_VERSION="${PIPER_VERSION:-2023.11.14-2}"
case "$(uname -s)-$(uname -m)" in
    Linux-x86_64)   ARCH="linux_x86_64" ;;
    Linux-aarch64)  ARCH="linux_aarch64" ;;
    Darwin-x86_64)  ARCH="macos_x64" ;;
    Darwin-arm64)   ARCH="macos_aarch64" ;;
    *)
        echo "Unsupported platform: $(uname -s)-$(uname -m)" >&2
        echo "See https://github.com/rhasspy/piper/releases for binaries." >&2
        exit 1
        ;;
esac

echo "[1/2] Installing Piper binary into $DEST/piper/ ..."
if [[ ! -x "$DEST/piper/piper" ]]; then
    curl -fsSL "https://github.com/rhasspy/piper/releases/download/${PIPER_VERSION}/piper_${ARCH}.tar.gz" \
        | tar xz
    echo "      done."
else
    echo "      already installed."
fi

# Voice models VG personas map to.
VOICES=(
    "en_US-amy-medium"                      # default
    "en_US-hfc_female-medium"               # Narcea
    "en_US-ryan-medium"                     # Bob
    "en_GB-alan-medium"                     # Skippy
    "en_GB-northern_english_male-medium"    # Orac
    "en_US-lessac-medium"                   # HAL 9000
)

echo "[2/2] Downloading voice models (6 × ~63 MB)..."
for v in "${VOICES[@]}"; do
    if [[ -f "$DEST/$v.onnx" ]]; then
        echo "      $v  (already installed)"
        continue
    fi
    lang_region="${v%%-*}"
    rest="${v#*-}"
    name="${rest%%-*}"
    quality="${rest##*-}"
    lang="${lang_region%%_*}"
    base="https://huggingface.co/rhasspy/piper-voices/resolve/main/$lang/$lang_region/$name/$quality/$v"
    echo "      $v ..."
    curl -fsSL -o "$DEST/$v.onnx"      "$base.onnx"
    curl -fsSL -o "$DEST/$v.onnx.json" "$base.onnx.json"
done

echo
echo "  ✓ Piper installed at $DEST"
echo "  ✓ Voices: ${VOICES[*]}"

# Pre-configure VG's voice settings so Piper is used immediately on next
# launch — without this the user would have to flip tts_backend in the
# Voice Settings dialog.  Each Godot project keeps its own user:// folder
# under ~/.local/share/godot/app_userdata; write the config into every
# project we can find so the change "just works".
GODOT_DATA="$HOME/.local/share/godot/app_userdata"
[[ "$(uname -s)" == "Darwin" ]] && GODOT_DATA="$HOME/Library/Application Support/Godot/app_userdata"
PIPER_BIN="$DEST/piper/piper"
PIPER_VOICE="$DEST/en_US-amy-medium.onnx"
if [[ -d "$GODOT_DATA" ]]; then
    while IFS= read -r -d '' proj; do
        cat > "$proj/vg_ai_voice.cfg" <<EOF
[voice]

stt_backend="openai"
tts_backend="piper"
tts_voice="alloy"
auto_speak_replies=true
whisper_cpp_path="whisper"
whisper_cpp_model=""
piper_path="$PIPER_BIN"
piper_voice_path="$PIPER_VOICE"
EOF
        echo "  Configured: $proj/vg_ai_voice.cfg"
    done < <(find "$GODOT_DATA" -mindepth 1 -maxdepth 1 -type d -print0)
fi

echo
echo "Restart Godot and switch any AI Pair persona — voice mode now uses"
echo "Piper neural TTS automatically (no extra config needed)."
