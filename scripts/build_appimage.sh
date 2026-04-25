#!/bin/bash
# Build a Linux AppImage that wraps scripts/bootstrap_vg.py.
# The AppImage is double-clickable and runs the first-time installer
# (downloads Godot, scaffolds a project, creates a "VisualGasic IDE"
# Apps menu entry, registers .vg files).
#
# Usage:  bash scripts/build_appimage.sh [version]
# Output: release/v<version>/VisualGasic-Installer-v<version>-x86_64.AppImage

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

VERSION="${1:-$(cat VERSION)}"
OUT_DIR="release/v${VERSION}"
APPDIR="$OUT_DIR/VisualGasic-Installer.AppDir"
APPIMAGE="$OUT_DIR/VisualGasic-Installer-v${VERSION}-x86_64.AppImage"
APPIMAGETOOL_URL="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
APPIMAGETOOL="$OUT_DIR/appimagetool-x86_64.AppImage"

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${CYAN}ℹ${NC}  $*"; }
success() { echo -e "${GREEN}✅${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*"; }

info "Building VisualGasic Installer AppImage ${BOLD}v${VERSION}${NC}"

if ! command -v python3 > /dev/null; then
    echo "python3 is required to build (and run) this AppImage." >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" \
         "$APPDIR/usr/share/visualgasic" \
         "$APPDIR/usr/share/applications" \
         "$APPDIR/usr/share/icons/hicolor/256x256/apps"

# ── Payload ────────────────────────────────────────────────────────────────
info "Staging payload..."
cp scripts/bootstrap_vg.py "$APPDIR/usr/bin/bootstrap_vg.py"
cp scripts/bootstrap_gui.py "$APPDIR/usr/bin/bootstrap_gui.py"
chmod +x "$APPDIR/usr/bin/bootstrap_vg.py"

# Bundle the full VG addon so the installer doesn't need network to copy it
# (only Godot needs to be downloaded, and that can also be offline).
cp -r addons/visual_gasic "$APPDIR/usr/share/visualgasic/addons_visual_gasic"
# Strip .uid files
find "$APPDIR/usr/share/visualgasic/addons_visual_gasic" -name "*.uid" -delete 2>/dev/null || true
cp VERSION "$APPDIR/usr/share/visualgasic/VERSION"

# ── AppRun ─────────────────────────────────────────────────────────────────
cat > "$APPDIR/AppRun" << 'APPRUN'
#!/bin/sh
# AppRun — entry point invoked when the user double-clicks the AppImage.
HERE="$(dirname "$(readlink -f "$0")")"
export VG_BOOTSTRAP_APPDIR="$HERE"

# Expose the bundled addon so bootstrap_vg.py picks it up as "offline".
# The AppImage mount itself is read-only, so stage the offline tree in a
# writable cache directory.
OFFLINE_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/visualgasic-installer"
OFFLINE_DIR="$OFFLINE_CACHE/offline"
mkdir -p "$OFFLINE_DIR/addons"
ln -sfn "$HERE/usr/share/visualgasic/addons_visual_gasic" \
        "$OFFLINE_DIR/addons/visual_gasic"
cp "$HERE/usr/share/visualgasic/VERSION" "$OFFLINE_DIR/VERSION" 2>/dev/null || true

if ! command -v python3 > /dev/null; then
    xmessage -center "VisualGasic Installer needs Python 3.
Please install python3 via your distribution's package manager and run this again." 2>/dev/null
    echo "python3 not found on PATH." >&2
    exit 1
fi

# Warn about missing Tkinter (used by the graphical wizard). We still
# fall through to text-mode if unavailable, but most users will want
# the GUI, so point them at the fix.
if ! python3 -c 'import tkinter' 2>/dev/null; then
    if command -v zenity > /dev/null; then
        zenity --warning --no-wrap --title='VisualGasic Installer' \
          --text="Tkinter is not installed, so the graphical wizard cannot open.

Install it with:
    sudo apt install python3-tk
        (or your distro's equivalent)

Or run this AppImage from a terminal to use the text-mode installer." 2>/dev/null || true
    fi
fi

# Default flags: open the graphical wizard so the user can pick the Godot
# version, project name/folder, and AI keys; auto-launch the IDE at the end
# so they land inside it. Power users can override with --no-gui or by
# passing their own flags (which are appended after these defaults).
exec python3 "$HERE/usr/bin/bootstrap_vg.py" --gui --offline "$OFFLINE_DIR" --launch "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

# ── .desktop ───────────────────────────────────────────────────────────────
cat > "$APPDIR/visualgasic-installer.desktop" << DESKTOP
[Desktop Entry]
Type=Application
Name=VisualGasic Installer
Comment=Install VisualGasic + Godot and scaffold a starter project
Exec=AppRun
Icon=visualgasic-installer
Categories=Development;IDE;
Terminal=false
DESKTOP
cp "$APPDIR/visualgasic-installer.desktop" "$APPDIR/usr/share/applications/visualgasic-installer.desktop"

# ── Icon ───────────────────────────────────────────────────────────────────
ICON_SRC=""
for cand in addons/visual_gasic/icon.png \
            docs/screenshots/icon.png \
            icon.png; do
    if [[ -f "$cand" ]]; then ICON_SRC="$cand"; break; fi
done

if [[ -z "$ICON_SRC" && -f "addons/visual_gasic/icon.svg" ]]; then
    # Try to rasterize the SVG if rsvg-convert or convert is available.
    if command -v rsvg-convert > /dev/null; then
        rsvg-convert -w 256 -h 256 addons/visual_gasic/icon.svg \
            -o "$APPDIR/visualgasic-installer.png"
        ICON_SRC="$APPDIR/visualgasic-installer.png"
    elif command -v convert > /dev/null; then
        convert -background none -resize 256x256 \
            addons/visual_gasic/icon.svg "$APPDIR/visualgasic-installer.png"
        ICON_SRC="$APPDIR/visualgasic-installer.png"
    fi
fi

if [[ -n "$ICON_SRC" ]]; then
    cp "$ICON_SRC" "$APPDIR/visualgasic-installer.png"
    cp "$ICON_SRC" "$APPDIR/usr/share/icons/hicolor/256x256/apps/visualgasic-installer.png"
else
    warn "No icon source found; generating a minimal placeholder PNG."
    # 1x1 transparent PNG placeholder (AppImage requires *some* icon file).
    python3 -c "
import base64, pathlib
p = pathlib.Path('$APPDIR/visualgasic-installer.png')
p.write_bytes(base64.b64decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkAAIAAAoAAv/lxKUAAAAASUVORK5CYII='
))
cp=pathlib.Path('$APPDIR/usr/share/icons/hicolor/256x256/apps/visualgasic-installer.png')
cp.write_bytes(p.read_bytes())
"
fi

# ── Download appimagetool if needed ────────────────────────────────────────
if [[ ! -x "$APPIMAGETOOL" ]]; then
    info "Downloading appimagetool..."
    curl -sSL -o "$APPIMAGETOOL" "$APPIMAGETOOL_URL"
    chmod +x "$APPIMAGETOOL"
fi

# ── Build ──────────────────────────────────────────────────────────────────
info "Running appimagetool..."
ARCH=x86_64 "$APPIMAGETOOL" --no-appstream "$APPDIR" "$APPIMAGE" 2>&1 | tail -10

if [[ ! -f "$APPIMAGE" ]]; then
    echo "AppImage build failed." >&2
    exit 1
fi

chmod +x "$APPIMAGE"
success "AppImage built: $APPIMAGE ($(du -h "$APPIMAGE" | cut -f1))"

echo
echo "  Run it: ${BOLD}./$APPIMAGE${NC}"
echo "  Or:      ${BOLD}chmod +x $APPIMAGE && double-click in your file manager${NC}"
