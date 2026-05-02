#!/usr/bin/env bash
# Build the VisualGasic Windows installer .exe.
#
# This script runs on Linux (uses makensis from the nsis Debian package)
# and produces a .exe that, when run on Windows, installs the VG first-time
# setup flow (Python + bootstrap_vg.py + bundled addon).
#
# Usage:
#   bash scripts/build_windows_installer.sh 5.1.0-Beta1
#
# Requires:
#   - makensis  (apt install nsis)
#   - curl or wget
#   - unzip
#
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    echo "usage: $0 <version>   e.g. $0 5.1.0-Beta1" >&2
    exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build/win-installer-$VERSION"
OUTPUT_DIR="$ROOT/release/v$VERSION"
OUTPUT="$OUTPUT_DIR/VisualGasic-Installer-v$VERSION-x86_64.exe"

# Python embeddable zip — required so end users don't need Python installed.
# Pinned version for reproducibility; update as needed.
PYTHON_VERSION="3.12.7"
PYTHON_ZIP_URL="https://www.python.org/ftp/python/${PYTHON_VERSION}/python-${PYTHON_VERSION}-embed-amd64.zip"

command -v makensis >/dev/null || { echo "makensis not found. Install with: sudo apt install nsis" >&2; exit 1; }
command -v unzip    >/dev/null || { echo "unzip not found." >&2; exit 1; }

DL() {
    local url="$1" out="$2"
    if command -v curl >/dev/null; then
        curl -fL --retry 3 -o "$out" "$url"
    else
        wget -O "$out" "$url"
    fi
}

echo "[1/5] Cleaning build dir: $BUILD_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

echo "[2/5] Staging bootstrap_vg.py"
cp "$ROOT/scripts/bootstrap_vg.py" "$BUILD_DIR/bootstrap_vg.py"
cp "$ROOT/scripts/bootstrap_gui.py" "$BUILD_DIR/bootstrap_gui.py"
# Optional Piper TTS downloader — invoked from the NSI installer when
# the user ticks the "Install Piper neural TTS" checkbox on the Ollama
# page.  Always shipped (it's tiny) so users can re-run it later.
cp "$ROOT/scripts/install_piper.ps1" "$BUILD_DIR/install_piper.ps1"

echo "[3/5] Staging bundled VG addon (offline payload)"
mkdir -p "$BUILD_DIR/offline/addons"
# Copy the addon tree. Dereference symlinks (-L / --copy-links) so the
# addons/visual_gasic/bin -> ../../bin link is materialised — otherwise the
# bundled addon ships a broken symlink and install_vg_addon() fails with
# "No such file or directory: .../bin".
if command -v rsync >/dev/null; then
    rsync -aL --exclude='__pycache__' --exclude='*.pyc' \
          "$ROOT/addons/visual_gasic/" "$BUILD_DIR/offline/addons/visual_gasic/"
else
    cp -rL "$ROOT/addons/visual_gasic" "$BUILD_DIR/offline/addons/"
fi

# The vgmusic plugin's libgdsion.gdextension references Windows DLLs that
# are not committed (bin/ is gitignored, GDSiON is built per-platform).
# Without the .dll the GDExtension fails to load on Windows, the
# Controller autoload stays in its uninitialised stub state, and the
# embedded Bosca Ceoil view shows up with no music grid. Pull the upstream
# release archive at build time so every Windows installer ships them.
GDSION_VERSION="0.7-beta8"
GDSION_URL="https://github.com/YuriSizov/gdsion/releases/download/${GDSION_VERSION}/libgdsion-windows.zip"
GDSION_DEST="$BUILD_DIR/offline/addons/visual_gasic/plugins/vgmusic/bin"
if [[ ! -f "$GDSION_DEST/libgdsion.windows.template_debug.x86_64.dll" ]]; then
    echo "[3b/5] Downloading GDSiON ${GDSION_VERSION} Windows binaries"
    GDSION_TMP="$BUILD_DIR/.gdsion-windows.zip"
    DL "$GDSION_URL" "$GDSION_TMP"
    mkdir -p "$GDSION_DEST"
    unzip -j -o -q "$GDSION_TMP" 'bin/libgdsion.windows*.dll' -d "$GDSION_DEST"
    rm -f "$GDSION_TMP"
fi

echo "[4/5] Downloading Python ${PYTHON_VERSION} embeddable"
PY_ZIP="$BUILD_DIR/python-embed.zip"
DL "$PYTHON_ZIP_URL" "$PY_ZIP"
mkdir -p "$BUILD_DIR/python"
unzip -q "$PY_ZIP" -d "$BUILD_DIR/python"
rm -f "$PY_ZIP"

# Bundle Mozilla CA bundle so HTTPS works on fresh Windows installs whose
# system trust store has not been populated yet by Automatic Root Certificates
# Update. bootstrap_vg.py picks this up via the SSL_CERT_FILE env var (set by
# windows_installer.nsi) and the explicit cadata fallback.
echo "[4b/5] Downloading Mozilla CA bundle (cacert.pem)"
DL "https://curl.se/ca/cacert.pem" "$BUILD_DIR/cacert.pem"
# The embeddable distribution disables site-packages by default; bootstrap_vg.py
# uses only stdlib so that's fine. We just need to make sure .pth files can
# import from the current directory.
PTH_FILE="$(ls "$BUILD_DIR/python"/python*._pth 2>/dev/null | head -1)"
if [[ -n "$PTH_FILE" ]]; then
    # Uncomment "import site" so the script directory is on sys.path.
    sed -i 's/^#import site/import site/' "$PTH_FILE"
fi

echo "[5/5] Running makensis"
cd "$ROOT"
makensis -V2 \
    -DVERSION="$VERSION" \
    -DBUILD_DIR="$BUILD_DIR" \
    -DOUTPUT_FILE="$OUTPUT" \
    "$ROOT/scripts/windows_installer.nsi"

SIZE=$(du -h "$OUTPUT" | cut -f1)
echo
echo "  ✓ Built $OUTPUT  ($SIZE)"
echo "  Copy to a Windows machine and double-click to run."
