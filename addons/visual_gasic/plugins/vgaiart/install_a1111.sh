#!/usr/bin/env bash
# Install AUTOMATIC1111 Stable Diffusion WebUI for the VG AI Art plugin.
#
# What this gives you:
#   • A free, local image generator that runs at http://127.0.0.1:7860
#   • Character-consistent sprite generation (same seed = same character)
#   • Optional ControlNet support for walk/run/jump cycles via OpenPose
#
# Cost: $0 forever, but heavy:
#   • ~6 GB of Python deps (downloaded on first webui.sh run)
#   • ~4 GB for the default SD 1.5 checkpoint
#   • Needs a GPU for reasonable speed (CPU works but is ~30 s/frame at 512²)
#
# Usage:
#   bash scripts/install_a1111.sh
#
# Then start the server:
#   ~/stable-diffusion-webui/webui.sh --api --listen=127.0.0.1
#
# The first launch downloads dependencies and the SD 1.5 checkpoint
# (~10 minutes on a fast connection). Subsequent launches are quick.
#
set -euo pipefail

# A parent venv (e.g. the user has activated VisualGasic's .venv before
# launching the IDE) makes webui.sh skip its own venv creation, then fall
# back to /usr/bin/python which is blocked by PEP 668 on Debian/Ubuntu.
# Force webui.sh to build its own venv.
unset VIRTUAL_ENV PYTHONHOME

DEST="${A1111_DIR:-$HOME/stable-diffusion-webui}"
REPO="https://github.com/AUTOMATIC1111/stable-diffusion-webui.git"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${CYAN}ℹ${NC}  $1"; }
success() { echo -e "${GREEN}✅${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $1"; }
error()   { echo -e "${RED}✗${NC}  $1" >&2; }

echo -e "${BOLD}${CYAN}"
echo "  ╔════════════════════════════════════════╗"
echo "  ║  A1111 Stable Diffusion installer      ║"
echo "  ║  for VG AI Art plugin                  ║"
echo "  ╚════════════════════════════════════════╝"
echo -e "${NC}"

info "Install location: $DEST"
echo ""
warn "This will download ~10 GB of data (Python deps + SD 1.5 model)."
warn "GPU strongly recommended (NVIDIA CUDA or AMD ROCm). CPU works but is slow."
echo ""

# ── Prereq checks ──────────────────────────────────────────────────────────
need=()
command -v git    >/dev/null || need+=(git)
command -v python3 >/dev/null || need+=(python3)
command -v wget   >/dev/null || need+=(wget)
if (( ${#need[@]} > 0 )); then
    error "Missing required tools: ${need[*]}"
    echo "  Debian/Ubuntu: sudo apt install ${need[*]} python3-venv"
    echo "  macOS:         brew install ${need[*]}"
    exit 1
fi

# Python 3.10/3.11 are the official supported versions; 3.12+ may need patches.
PY_VER=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
case "$PY_VER" in
    3.10|3.11) ;;
    *) warn "Your Python is $PY_VER. A1111 officially supports 3.10/3.11; you may hit pip errors." ;;
esac

# python3-venv is required on Debian/Ubuntu — without it `python3 -m venv`
# fails and webui.sh silently falls back to system pip, which then crashes
# under PEP 668 ("externally-managed-environment").
if ! python3 -m venv --help >/dev/null 2>&1; then
    error "Python 'venv' module is missing."
    echo "  Debian/Ubuntu: sudo apt install python3-venv python3-pip"
    echo "  Fedora:        sudo dnf install python3-virtualenv"
    exit 1
fi

# ── Clone ───────────────────────────────────────────────────────────────────
if [[ -d "$DEST/.git" ]]; then
    info "Repo already exists at $DEST — pulling latest..."
    git -C "$DEST" pull --ff-only || warn "Pull failed; continuing with existing checkout."
else
    info "Cloning AUTOMATIC1111/stable-diffusion-webui..."
    git clone --depth 1 "$REPO" "$DEST"
fi

# ── Pre-clone Stable Diffusion repo from a mirror ──────────────────────────
# A1111 v1.10.1 hardcodes https://github.com/Stability-AI/stablediffusion.git
# but Stability-AI deleted that repo (404 as of 2025+). Pre-cloning into
# $DEST/repositories/stable-diffusion-stability-ai with the exact commit
# webui expects makes webui's clone step a no-op.
SD_REPO_DIR="$DEST/repositories/stable-diffusion-stability-ai"
SD_MIRROR="${STABLE_DIFFUSION_REPO:-https://github.com/GooglePhone/stablediffusion.git}"
SD_COMMIT="${STABLE_DIFFUSION_COMMIT_HASH:-cf1d67a6fd5ea1aa600c4df58e5b47da45f6bdbf}"
mkdir -p "$DEST/repositories"
if [[ ! -d "$SD_REPO_DIR/.git" ]]; then
    info "Pre-cloning Stable Diffusion repo from mirror ($SD_MIRROR)..."
    if git clone "$SD_MIRROR" "$SD_REPO_DIR"; then
        git -C "$SD_REPO_DIR" checkout "$SD_COMMIT" 2>/dev/null || \
            warn "Could not check out commit $SD_COMMIT (will let webui retry)."
    else
        warn "SD mirror clone failed. webui's first launch will likely also fail."
        warn "Try: STABLE_DIFFUSION_REPO=https://github.com/honeyvig/stablediffusion.git"
    fi
fi

# ── webui-user.sh: pip constraints to keep setuptools<80 ───────────────────
# pip's build isolation grabs the newest setuptools by default. setuptools
# 80+ removed the legacy `pkg_resources` module, breaking source builds of
# CLIP and a few other A1111 deps. PIP_CONSTRAINT pins it back.
# We also pin numpy<2 because torch 2.1.2 doesn't constrain numpy and pip
# happily picks numpy 2.x, which then ABI-mismatches scikit-image's wheel.
USER_SH="$DEST/webui-user.sh"
CONSTRAINT_FILE="$DEST/.vg_pip_constraints.txt"
cat > "$CONSTRAINT_FILE" <<'EOF'
setuptools<80
numpy<2
EOF
if ! grep -q "PIP_CONSTRAINT" "$USER_SH" 2>/dev/null; then
    {
        echo ""
        echo "# Added by VG AI Art installer"
        echo "export PIP_CONSTRAINT=\"$CONSTRAINT_FILE\""
        echo "# Force webui to build its own venv even if the launcher inherited one."
        echo "unset VIRTUAL_ENV PYTHONHOME"
        echo ""
        echo "# Auto-detect GPU and add CPU fallback flags if absent."
        echo "# nvidia-smi exits 0 only when an NVIDIA driver+GPU is present."
        echo "# rocminfo similarly for AMD ROCm."
        echo "if ! command -v nvidia-smi >/dev/null 2>&1 || ! nvidia-smi -L 2>/dev/null | grep -q GPU; then"
        echo "    if ! command -v rocminfo >/dev/null 2>&1 || ! rocminfo 2>/dev/null | grep -q 'Device Type:.*GPU'; then"
        echo "        echo '[VG] No GPU detected — running on CPU (slow). Add a GPU + drivers for fast generation.'"
        echo "        export COMMANDLINE_ARGS=\"\${COMMANDLINE_ARGS:-} --skip-torch-cuda-test --no-half --use-cpu all\""
        echo "    fi"
        echo "fi"
    } >> "$USER_SH"
    info "Patched webui-user.sh with PIP_CONSTRAINT and GPU autodetect."
fi

# ── Force-correct already-installed deps if a previous run picked wrong ──
# versions (e.g. numpy 2.x while webui pinned 1.26.2).
if [[ -x "$DEST/venv/bin/pip" ]]; then
    info "Reconciling venv versions (numpy<2, setuptools<80)..."
    PIP_CONSTRAINT="$CONSTRAINT_FILE" "$DEST/venv/bin/pip" install -q \
        "numpy==1.26.2" "setuptools<80" "scikit-image==0.21.0" \
        2>&1 | tail -3 || warn "Reconcile pass had warnings (usually fine)."
fi

# ── Patch api.py for starlette 0.26+ middleware guard ──────────────────────
# A1111 v1.10.1 calls `app.middleware("http")` after gradio has built the
# middleware stack. Starlette 0.26+ enforces "no middleware after start"
# and raises RuntimeError. Reset middleware_stack so it gets rebuilt.
API_PY="$DEST/modules/api/api.py"
if [[ -f "$API_PY" ]] && ! grep -q "VG: starlette 0.26" "$API_PY"; then
    info "Patching modules/api/api.py for starlette middleware guard..."
    sed -i 's|^        api_middleware(self.app)$|        self.app.middleware_stack = None  # VG: starlette 0.26+ guard\n        api_middleware(self.app)|' "$API_PY"
fi

# ── Default checkpoint ─────────────────────────────────────────────────────
MODEL_DIR="$DEST/models/Stable-diffusion"
mkdir -p "$MODEL_DIR"
DEFAULT_CKPT="v1-5-pruned-emaonly.safetensors"
DEFAULT_URL="https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/$DEFAULT_CKPT"

if ls "$MODEL_DIR"/*.safetensors >/dev/null 2>&1 || ls "$MODEL_DIR"/*.ckpt >/dev/null 2>&1; then
    success "A checkpoint is already installed in $MODEL_DIR — skipping download."
else
    info "Downloading default SD 1.5 checkpoint (~4 GB)..."
    if ! wget --show-progress -q -O "$MODEL_DIR/$DEFAULT_CKPT" "$DEFAULT_URL"; then
        warn "Checkpoint download failed."
        warn "Manually drop any .safetensors model into $MODEL_DIR before running webui."
    fi
fi

# ── ControlNet extension (optional but recommended for walk cycles) ────────
EXT_DIR="$DEST/extensions"
mkdir -p "$EXT_DIR"
if [[ ! -d "$EXT_DIR/sd-webui-controlnet" ]]; then
    info "Installing sd-webui-controlnet extension (for OpenPose walk cycles)..."
    git clone --depth 1 https://github.com/Mikubill/sd-webui-controlnet "$EXT_DIR/sd-webui-controlnet" || \
        warn "ControlNet install failed (non-fatal)."
fi

CN_MODEL_DIR="$EXT_DIR/sd-webui-controlnet/models"
mkdir -p "$CN_MODEL_DIR"
CN_OPENPOSE="control_v11p_sd15_openpose.pth"
CN_OPENPOSE_URL="https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/$CN_OPENPOSE"
if [[ ! -f "$CN_MODEL_DIR/$CN_OPENPOSE" ]]; then
    info "Downloading ControlNet OpenPose model (~1.4 GB)..."
    wget --show-progress -q -O "$CN_MODEL_DIR/$CN_OPENPOSE" "$CN_OPENPOSE_URL" || \
        warn "OpenPose model download failed (non-fatal — only needed for pose-locked cycles)."
fi

# ── ControlNet Python deps (force-installed; svglib needs system cairo to
# build from source, and insightface fails to auto-install at runtime). ──
if [[ -x "$DEST/venv/bin/pip" ]]; then
    info "Pre-installing ControlNet python deps (svglib, insightface, mediapipe)…"
    # mediapipe 0.10.35 ships without `solutions` submodule on Python 3.11;
    # 0.10.14 has it. svglib 1.5.1 has wheels (avoids cairo build).
    "$DEST/venv/bin/pip" install --no-warn-script-location \
        "mediapipe==0.10.14" "svglib==1.5.1" "insightface==0.7.3" \
        2>&1 | tail -3 || warn "ControlNet deps install had warnings (non-fatal)."
    # insightface drags in numpy 2.x + protobuf 7 — pin them back.
    "$DEST/venv/bin/pip" install --force-reinstall --no-deps \
        "numpy==1.26.2" "protobuf==3.20.0" 2>&1 | tail -3 \
        || warn "Could not pin numpy/protobuf (non-fatal)."
fi

# ── sd-webui-rembg (background removal for clean sprite cutouts) ──────────
# Adds a /rembg API endpoint we call before pixelifying so the final
# 32×32 sprite has clean alpha instead of speckled "background noise".
if [[ ! -d "$EXT_DIR/sd-webui-rembg" ]]; then
    info "Installing sd-webui-rembg extension (background removal)..."
    git clone --depth 1 https://github.com/AUTOMATIC1111/stable-diffusion-webui-rembg \
        "$EXT_DIR/sd-webui-rembg" || \
        warn "rembg install failed (non-fatal — sprites will still generate, just with backgrounds)."
fi
# Pre-install rembg's Python deps so its install.py doesn't fail at startup.
if [[ -x "$DEST/venv/bin/pip" ]]; then
    info "Pre-installing rembg python deps (rembg, onnxruntime)…"
    "$DEST/venv/bin/pip" install --no-warn-script-location \
        "rembg==2.0.50" "onnxruntime" \
        2>&1 | tail -3 || warn "rembg deps install had warnings (non-fatal)."
fi

# ── Done ───────────────────────────────────────────────────────────────────
success "A1111 installed at $DEST"
echo ""
echo -e "${BOLD}Next steps:${NC}"
echo ""
echo "  1. Start the WebUI in API mode (first launch downloads deps, ~5-10 min):"
echo ""
echo "       cd $DEST"
echo "       ./webui.sh --api --listen=127.0.0.1"
echo ""
echo "  2. Wait for the line: ${BOLD}Running on local URL:  http://127.0.0.1:7860${NC}"
echo ""
echo "  3. In Visual Gasic, open the AI Art plugin and select the"
echo "     ${BOLD}'Local Stable Diffusion (A1111)'${NC} backend."
echo ""
echo "     Click ⚙ → Refresh to verify connection."
echo ""
warn "Leave webui running in its own terminal while you generate art."
echo ""
