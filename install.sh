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

info "Downloading VisualGasic from GitHub..."

REPO_URL="https://github.com/xgreenrx-star/VisualGasic"
ARCHIVE_URL="$REPO_URL/archive/refs/heads/main.zip"

if ! command -v curl &> /dev/null; then
    error "curl is required. Install it with your package manager."
    exit 1
fi

if ! command -v unzip &> /dev/null; then
    error "unzip is required. Install it with your package manager."
    exit 1
fi

if ! curl -sSL "$ARCHIVE_URL" -o "$TEMP_DIR/visualgasic.zip"; then
    error "Download failed. Check your internet connection."
    exit 1
fi

info "Extracting..."
cd "$TEMP_DIR"
unzip -q visualgasic.zip
SOURCE_DIR="$TEMP_DIR/VisualGasic-main"

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
echo "  CLI:      $BIN_DIR/vg"
echo ""
echo -e "  ${BOLD}Quick Start:${NC}"
echo "    vg new MyGame        # Create a new VG project"
echo "    cd MyGame && godot . # Open in Godot"
echo ""
echo -e "  ${BOLD}Add VG to an existing project:${NC}"
echo "    cd /path/to/project"
echo "    vg install"
echo ""
echo "  Documentation: $REPO_URL"
echo ""
