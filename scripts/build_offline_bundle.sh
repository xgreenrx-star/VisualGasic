#!/usr/bin/env bash
# Build the VisualGasic "offline" installer bundle.
#
# Produces a single .zip per platform that contains:
#   - The platform installer (AppImage or .exe)
#   - A pre-downloaded Godot release zip for that platform
#   - A README telling the user what to do
#
# The installer is then run with --offline pointing at the bundled Godot
# zip, so no internet is required at install time.
#
# Usage:
#   bash scripts/build_offline_bundle.sh 5.1.0-Beta1 [godot-version]
#
# Default Godot version is 4.6.1-stable to match bootstrap_vg.py.
#
set -euo pipefail

VERSION="${1:-}"
GODOT_VERSION="${2:-4.6.1-stable}"
if [[ -z "$VERSION" ]]; then
    echo "usage: $0 <version> [godot-version]" >&2
    exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/release/v$VERSION"
WORK_DIR="$ROOT/build/offline-bundle-$VERSION"
GODOT_BASE="https://github.com/godotengine/godot/releases/download/$GODOT_VERSION"

mkdir -p "$OUT_DIR" "$WORK_DIR"

DL() {
    local url="$1" out="$2"
    if [[ -f "$out" ]]; then
        echo "  (cached) $out"
        return
    fi
    echo "  downloading $url"
    if command -v curl >/dev/null; then
        curl -fL --retry 3 -o "$out" "$url"
    else
        wget -O "$out" "$url"
    fi
}

build_linux_bundle() {
    local appimage="$OUT_DIR/VisualGasic-Installer-v$VERSION-x86_64.AppImage"
    if [[ ! -f "$appimage" ]]; then
        echo "  AppImage not found; building first..."
        bash "$ROOT/scripts/build_appimage.sh" "$VERSION"
    fi
    local godot_zip="Godot_v${GODOT_VERSION}_linux.x86_64.zip"
    DL "$GODOT_BASE/$godot_zip" "$WORK_DIR/$godot_zip"

    local staging="$WORK_DIR/linux"
    rm -rf "$staging"
    mkdir -p "$staging/godot"
    cp "$appimage" "$staging/"
    cp "$WORK_DIR/$godot_zip" "$staging/godot/"

    cat > "$staging/README.txt" <<EOF
VisualGasic Offline Installer — Linux
=====================================

1. Make the AppImage executable (first time only):
       chmod +x VisualGasic-Installer-v$VERSION-x86_64.AppImage

2. Run it offline:
       ./VisualGasic-Installer-v$VERSION-x86_64.AppImage --offline \$(pwd)/godot

That's it. The installer will:
  - Unpack the bundled Godot $GODOT_VERSION
  - Install the VisualGasic editor plugin
  - Create a "MyFirstGame" project in ~/VisualGasic/
  - Add a "VisualGasic IDE" entry to your Applications menu
  - Register .vg files so they open in VisualGasic by double-click
EOF

    local out_zip="$OUT_DIR/VisualGasic-Installer-Offline-v$VERSION-linux-x86_64.zip"
    (cd "$staging" && zip -qr "$out_zip" .)
    echo "  ✓ $(du -h "$out_zip" | cut -f1)  $out_zip"
}

build_windows_bundle() {
    local exe="$OUT_DIR/VisualGasic-Installer-v$VERSION-x86_64.exe"
    if [[ ! -f "$exe" ]]; then
        echo "  .exe not found; building first..."
        bash "$ROOT/scripts/build_windows_installer.sh" "$VERSION"
    fi
    local godot_zip="Godot_v${GODOT_VERSION}_win64.exe.zip"
    DL "$GODOT_BASE/$godot_zip" "$WORK_DIR/$godot_zip"

    local staging="$WORK_DIR/windows"
    rm -rf "$staging"
    mkdir -p "$staging/godot"
    cp "$exe" "$staging/"
    cp "$WORK_DIR/$godot_zip" "$staging/godot/"

    cat > "$staging/README.txt" <<EOF
VisualGasic Offline Installer — Windows
=======================================

1. Double-click:
       VisualGasic-Installer-v$VERSION-x86_64.exe

2. After install, launch "VisualGasic first-time setup" from the Start Menu
   and the bundled Godot $GODOT_VERSION will be used automatically — no
   internet connection required.

The installer will:
  - Install the VisualGasic editor plugin
  - Create a "MyFirstGame" project in %USERPROFILE%\VisualGasic\
  - Add a "VisualGasic IDE" shortcut to the Start Menu and Desktop
  - Register .vg files so they open in VisualGasic by double-click
EOF

    local out_zip="$OUT_DIR/VisualGasic-Installer-Offline-v$VERSION-windows-x86_64.zip"
    (cd "$staging" && zip -qr "$out_zip" .)
    echo "  ✓ $(du -h "$out_zip" | cut -f1)  $out_zip"
}

echo "[Linux] Building offline bundle"
build_linux_bundle

echo "[Windows] Building offline bundle"
build_windows_bundle

echo
echo "Offline bundles written to: $OUT_DIR"
