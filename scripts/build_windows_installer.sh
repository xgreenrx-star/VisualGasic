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

echo "[3/5] Staging bundled VG addon (offline payload)"
mkdir -p "$BUILD_DIR/offline/addons"
# Copy the addon tree. Use rsync if available, else cp -r.
if command -v rsync >/dev/null; then
    rsync -a --exclude='__pycache__' --exclude='*.pyc' \
          "$ROOT/addons/visual_gasic/" "$BUILD_DIR/offline/addons/visual_gasic/"
else
    cp -r "$ROOT/addons/visual_gasic" "$BUILD_DIR/offline/addons/"
fi

echo "[4/5] Downloading Python ${PYTHON_VERSION} embeddable"
PY_ZIP="$BUILD_DIR/python-embed.zip"
DL "$PYTHON_ZIP_URL" "$PY_ZIP"
mkdir -p "$BUILD_DIR/python"
unzip -q "$PY_ZIP" -d "$BUILD_DIR/python"
rm -f "$PY_ZIP"
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
