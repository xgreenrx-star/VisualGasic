#!/bin/bash
# VisualGasic Installer for Linux/macOS
# Installs the VisualGasic addon globally and the `vg` CLI tool
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/install.sh | bash
#
# What it does:
#   1. Downloads the latest VisualGasic release from GitHub
#   2. Installs the addon to ~/.local/share/visual_gasic/ (Linux)
#      or ~/Library/Application Support/VisualGasic/ (macOS)
#   3. Installs the `vg` CLI tool to ~/.local/bin/vg
#
# After installation, create new VG-ready projects with:
#   vg new MyGame
#   cd MyGame && godot .

set -e

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}ℹ${NC}  $1"; }
success() { echo -e "${GREEN}✅${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $1"; }
error()   { echo -e "${RED}✗${NC}  $1" >&2; }

echo -e "${BOLD}${CYAN}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║     VisualGasic Installer             ║"
echo "  ║    VB6-style language for Godot 4     ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${NC}"

# ── Detect OS ───────────────────────────────────────────────────────────────
if [[ "$OSTYPE" == "darwin"* ]]; then
    VG_GLOBAL_DIR="$HOME/Library/Application Support/VisualGasic"
    PLATFORM="macOS"
else
    VG_GLOBAL_DIR="$HOME/.local/share/visual_gasic"
    PLATFORM="Linux"
fi

BIN_DIR="$HOME/.local/bin"
VG_ADDON_DIR="$VG_GLOBAL_DIR/addons/visual_gasic"

info "Platform: $PLATFORM"
info "Install location: $VG_GLOBAL_DIR"
info "CLI tool: $BIN_DIR/vg"
echo ""

# ── Download ────────────────────────────────────────────────────────────────
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

REPO_URL="https://github.com/xgreenrx-star/VisualGasic"

# Default: download the latest release (including pre-releases/Beta tags).
# Override with VG_INSTALL_TAG=vX.Y.Z or VG_INSTALL_REF=main.
TAG="${VG_INSTALL_TAG:-}"
REF="${VG_INSTALL_REF:-}"

if ! command -v curl &> /dev/null; then
    error "curl is required. Install it with your package manager."
    exit 1
fi

if ! command -v unzip &> /dev/null; then
    error "unzip is required. Install it with your package manager."
    exit 1
fi

if [[ -z "$TAG" && -z "$REF" ]]; then
    info "Looking up latest release..."
    API="https://api.github.com/repos/xgreenrx-star/VisualGasic/releases"
    TAG=$(curl -sSL -H "Accept: application/vnd.github+json" "$API" \
        | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
fi

if [[ -n "$TAG" ]]; then
    ARCHIVE_URL="$REPO_URL/archive/refs/tags/$TAG.zip"
    SOURCE_SUBDIR="VisualGasic-${TAG#v}"
    info "Downloading release $TAG from GitHub..."
else
    ARCHIVE_URL="$REPO_URL/archive/refs/heads/${REF:-main}.zip"
    SOURCE_SUBDIR="VisualGasic-${REF:-main}"
    info "Downloading ${REF:-main} branch from GitHub..."
fi

if ! curl -sSL "$ARCHIVE_URL" -o "$TEMP_DIR/visualgasic.zip"; then
    error "Download failed. Check your internet connection."
    exit 1
fi

info "Extracting..."
cd "$TEMP_DIR"
unzip -q visualgasic.zip
SOURCE_DIR="$TEMP_DIR/$SOURCE_SUBDIR"
# Some tag zips name the top-level differently; fall back to the sole dir.
if [[ ! -d "$SOURCE_DIR" ]]; then
    SOURCE_DIR=$(find "$TEMP_DIR" -maxdepth 1 -mindepth 1 -type d | head -1)
fi

# ── Install addon globally ──────────────────────────────────────────────────
info "Installing addon to $VG_GLOBAL_DIR..."
mkdir -p "$VG_GLOBAL_DIR/addons"

# Remove old install
[[ -d "$VG_ADDON_DIR" ]] && rm -rf "$VG_ADDON_DIR"

# Copy addon
cp -r "$SOURCE_DIR/addons/visual_gasic" "$VG_ADDON_DIR"

# Remove .uid files (regenerated per-project)
find "$VG_ADDON_DIR" -name "*.uid" -delete 2>/dev/null || true

# Copy version
if [[ -f "$SOURCE_DIR/VERSION" ]]; then
    cp "$SOURCE_DIR/VERSION" "$VG_GLOBAL_DIR/VERSION"
fi

# ── Install vg CLI tool ────────────────────────────────────────────────────
info "Installing 'vg' CLI tool to $BIN_DIR..."
mkdir -p "$BIN_DIR"
cp "$SOURCE_DIR/vg" "$BIN_DIR/vg"
chmod +x "$BIN_DIR/vg"

# ── Check PATH ──────────────────────────────────────────────────────────────
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    warn "$BIN_DIR is not in your PATH."
    echo ""
    echo "  Add it to your shell config:"
    if [[ -f "$HOME/.zshrc" ]]; then
        echo "    echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc"
        echo "    source ~/.zshrc"
    else
        echo "    echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
        echo "    source ~/.bashrc"
    fi
    echo ""
fi

# ── Detect naming conflict with system vg (cgvg package) ───────────────────
SYSTEM_VG=""
for p in /usr/bin/vg /bin/vg /usr/local/bin/vg; do
    if [[ -x "$p" && "$p" != "$BIN_DIR/vg" ]]; then
        # Check if it's the cgvg Perl helper, not ours
        if head -1 "$p" 2>/dev/null | grep -q perl; then
            SYSTEM_VG="$p"
            break
        fi
    fi
done

if [[ -n "$SYSTEM_VG" ]]; then
    warn "Name conflict detected: ${BOLD}$SYSTEM_VG${NC} (from the 'cgvg' package)"
    echo ""
    echo "  Your shell may run the wrong 'vg' command. To fix this:"
    echo ""
    echo "  ${BOLD}Option 1:${NC} Refresh your shell's command cache:"
    echo "    hash -r            # then try: vg version"
    echo ""
    echo "  ${BOLD}Option 2:${NC} Remove the conflicting package:"
    echo "    sudo apt remove cgvg"
    echo ""
    echo "  ${BOLD}Option 3:${NC} Use the full path:"
    echo "    $BIN_DIR/vg new MyGame"
    echo ""
    echo "  You can also use ${BOLD}visualgasic${NC} as an alias (installed alongside vg)."
    echo ""
fi

# ── Install 'visualgasic' alias (conflict-proof) ───────────────────────────
ln -sf "$BIN_DIR/vg" "$BIN_DIR/visualgasic"

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
VG_VER="unknown"
[[ -f "$VG_GLOBAL_DIR/VERSION" ]] && VG_VER=$(cat "$VG_GLOBAL_DIR/VERSION")
FILE_COUNT=$(find "$VG_ADDON_DIR" -type f | wc -l)
DIR_SIZE=$(du -sh "$VG_ADDON_DIR" | cut -f1)

echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║     ✅ Installation Complete!         ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${NC}"
echo "  Version:  $VG_VER"
echo "  Files:    $FILE_COUNT files ($DIR_SIZE)"
echo "  Addon:    $VG_GLOBAL_DIR"
echo "  CLI:      $BIN_DIR/vg  (also available as 'visualgasic')"
echo ""
echo -e "  ${BOLD}Quick Start:${NC}"
echo "    vg new MyGame        # Create a new VG project"
echo "    cd MyGame && godot . # Open in Godot"
echo ""
echo -e "  ${BOLD}Add VG to an existing project:${NC}"
echo "    cd /path/to/project"
echo "    vg install"
echo ""

# ── Optional: Piper neural TTS for AI Pair voice mode ──────────────────────
if [[ -t 0 && -t 1 && "${VG_INSTALL_PIPER:-}" != "0" ]]; then
    echo -e "  ${BOLD}Optional:${NC} natural-sounding voice for AI Pair (~340 MB download)"
    echo "    The default OS TTS (espeak / say) is robotic. Piper voices match"
    echo "    each persona (Bob = American, Skippy = British, Orac = Yorkshire, etc.)"
    echo ""
    read -r -p "  Install Piper neural TTS now? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        if [[ -f "$VG_GLOBAL_DIR/scripts/install_piper.sh" ]]; then
            bash "$VG_GLOBAL_DIR/scripts/install_piper.sh"
        else
            curl -fsSL "$REPO_URL/raw/main/scripts/install_piper.sh" | bash
        fi
    else
        info "Skipped. Run later with: bash <(curl -sSL $REPO_URL/raw/main/scripts/install_piper.sh)"
    fi
    echo ""
fi

# ── Optional: local Whisper STT for AI Pair voice mode ────────────────────
if [[ -t 0 && -t 1 && "${VG_INSTALL_WHISPER:-}" != "0" ]]; then
    echo -e "  ${BOLD}Optional:${NC} local speech-to-text for AI Pair (~75 MB download)"
    echo "    Without this, the 🎙 mic button requires an OpenAI API key."
    echo "    whisper.cpp runs locally — no key, no network. Builds from source"
    echo "    (needs cmake + a C++ compiler, ~1 minute)."
    echo ""
    read -r -p "  Install local Whisper STT now? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        if [[ -f "$VG_GLOBAL_DIR/scripts/install_whisper.sh" ]]; then
            bash "$VG_GLOBAL_DIR/scripts/install_whisper.sh"
        else
            curl -fsSL "$REPO_URL/raw/main/scripts/install_whisper.sh" | bash
        fi
    else
        info "Skipped. Run later with: bash <(curl -sSL $REPO_URL/raw/main/scripts/install_whisper.sh)"
    fi
    echo ""
fi

echo "  Documentation: $REPO_URL"
echo ""
