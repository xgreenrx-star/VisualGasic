#!/bin/bash
#
# VisualGasic Release Build Script
# Builds binaries for all platforms, packages addon + installers + docs into release zips
#
# Usage:
#   ./scripts/build_release.sh                 # Reads version from VERSION file
#   ./scripts/build_release.sh 4.4.0-rc1       # Override version
#
# Output:
#   release/v<version>/VisualGasic_v<version>_linux_x86_64.zip
#   release/v<version>/VisualGasic_v<version>_windows_x86_64.zip
#   release/v<version>/VisualGasic_v<version>_macos_universal.zip  (macOS host only)
#
# Requirements:
#   - scons, g++  (Linux build)
#   - x86_64-w64-mingw32-g++  (Windows cross-compile, install: sudo apt install g++-mingw-w64-x86-64)
#   - On macOS: Xcode command line tools (for macOS builds)
#

set -e

# ── Configuration ───────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

VERSION="${1:-$(cat VERSION | tr -d '[:space:]')}"
RELEASE_DIR="release/v${VERSION}"
NPROC=$(nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo 4)

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
step()    { echo -e "\n${BOLD}${YELLOW}[$1] $2${NC}"; }

echo -e "${BOLD}${GREEN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║  VisualGasic Release Builder v${VERSION}  ║"
echo "  ║  Building for Linux, Windows, macOS      ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ── Preflight checks ───────────────────────────────────────────────────────
step "1/7" "Preflight checks..."

if [[ ! -f "SConstruct" ]]; then
    error "SConstruct not found. Run from the VisualGasic project root."
    exit 1
fi

if ! command -v scons &>/dev/null; then
    error "scons not found. Install it: pip install scons"
    exit 1
fi

info "Version: ${BOLD}${VERSION}${NC}"
info "Output:  ${BOLD}${RELEASE_DIR}/${NC}"
info "Threads: ${NPROC}"

# Check for MinGW (Windows cross-compile)
HAS_MINGW=false
if command -v x86_64-w64-mingw32-g++ &>/dev/null; then
    HAS_MINGW=true
    info "MinGW: ✅ available (Windows cross-compile enabled)"
else
    warn "MinGW not found — skipping Windows build"
    warn "  Install with: sudo apt install g++-mingw-w64-x86-64"
fi

# Check for macOS
IS_MACOS=false
if [[ "$OSTYPE" == "darwin"* ]]; then
    IS_MACOS=true
    info "Platform: macOS (universal binary enabled)"
else
    info "Platform: Linux (macOS build skipped — requires macOS host)"
fi

# ── Build Linux ─────────────────────────────────────────────────────────────
step "2/7" "Building Linux x86_64..."

for target in editor template_debug template_release; do
    info "Building linux/$target..."
    scons platform=linux target=$target -j$NPROC 2>&1 | tail -1
done
success "Linux builds complete"

# ── Build Windows (cross-compile) ──────────────────────────────────────────
if $HAS_MINGW; then
    step "3/7" "Building Windows x86_64 (MinGW cross-compile)..."

    for target in editor template_debug template_release; do
        info "Building windows/$target..."
        scons platform=windows target=$target -j$NPROC 2>&1 | tail -1
    done
    success "Windows builds complete"
else
    step "3/7" "Skipping Windows build (no MinGW)"
fi

# ── Build macOS (native only) ──────────────────────────────────────────────
if $IS_MACOS; then
    step "4/7" "Building macOS Universal (x86_64 + arm64)..."

    for target in editor template_debug template_release; do
        info "Building macos/$target x86_64..."
        scons platform=macos target=$target arch=x86_64 -j$NPROC 2>&1 | tail -1

        info "Building macos/$target arm64..."
        scons platform=macos target=$target arch=arm64 -j$NPROC 2>&1 | tail -1
    done

    # Combine with lipo
    if [[ -x "scripts/build_macos_universal.sh" ]]; then
        info "Creating universal binaries with lipo..."
        bash scripts/build_macos_universal.sh
    fi
    success "macOS builds complete"
else
    step "4/7" "Skipping macOS build (requires macOS host)"
fi

# ── Stage common files ──────────────────────────────────────────────────────
step "5/7" "Staging release files..."

STAGING="$RELEASE_DIR/staging"
rm -rf "$STAGING"
mkdir -p "$STAGING/addons/visual_gasic/bin"

# Copy addon GDScript files
cp addons/visual_gasic/*.gd "$STAGING/addons/visual_gasic/" 2>/dev/null || true
cp addons/visual_gasic/*.cfg "$STAGING/addons/visual_gasic/" 2>/dev/null || true
cp addons/visual_gasic/*.svg "$STAGING/addons/visual_gasic/" 2>/dev/null || true
cp addons/visual_gasic/visual_gasic.gdextension "$STAGING/addons/visual_gasic/"

# Copy prototypes if present
[[ -d addons/visual_gasic/prototypes ]] && cp -r addons/visual_gasic/prototypes "$STAGING/addons/visual_gasic/"

# Copy plugins (Working Nodes, AGCK, VG3D, Web Publish, etc.)
[[ -d addons/visual_gasic/plugins ]] && cp -r addons/visual_gasic/plugins "$STAGING/addons/visual_gasic/"

# Strip the disabled/incomplete gdsfx precursor -- it has no plugin.cfg (never
# loads as a plugin), depends on GDScript files that were never committed, and
# only exists for reference. Shipping it in the Asset Library submission adds
# confusion for reviewers with no functional benefit; vgsfx/ fully supersedes it.
rm -rf "$STAGING/addons/visual_gasic/plugins/_disabled.gdsfx"

# Copy installers and CLI
cp install.sh install.ps1 install.py vg "$STAGING/"
chmod +x "$STAGING/vg" "$STAGING/install.sh"

# Copy documentation
cp README.md CHANGELOG.md LICENSE "$STAGING/"
cp RELEASE_NOTES_v*.md "$STAGING/" 2>/dev/null || true
cp CONTRIBUTING.md "$STAGING/" 2>/dev/null || true

# Copy docs (excluding dev-only)
cp -r docs "$STAGING/" 2>/dev/null || true
rm -rf "$STAGING/docs/archive" "$STAGING/docs/development" 2>/dev/null || true

# Copy examples, demos, tutorials, beta showcase project
cp -r examples "$STAGING/" 2>/dev/null || true
cp -r demos "$STAGING/" 2>/dev/null || true
cp -r tutorials "$STAGING/" 2>/dev/null || true
mkdir -p "$STAGING/projects"
[[ -d projects/vg_beta_showcase ]] && cp -r projects/vg_beta_showcase "$STAGING/projects/"

# Clean caches and dev artifacts
find "$STAGING" -name "*.uid" -delete 2>/dev/null || true
find "$STAGING" -name "*.os" -delete 2>/dev/null || true
find "$STAGING" -name "*.o" -delete 2>/dev/null || true
find "$STAGING" -name ".godot" -type d -exec rm -rf {} + 2>/dev/null || true
find "$STAGING" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find "$STAGING" -name ".DS_Store" -delete 2>/dev/null || true
find "$STAGING" -name "*.import" -delete 2>/dev/null || true
find "$STAGING" -name ".git*" -not -name ".gitignore" -delete 2>/dev/null || true

# Strip nested addon binaries from demos/examples (top-level addon is enough;
# nested copies bloat the zip to multi-GB).
find "$STAGING/demos" "$STAGING/examples" -path '*/addons/visual_gasic/bin' -type d -exec rm -rf {} + 2>/dev/null || true

# Strip other bloat: stray bin/ dirs inside examples/demos (not part of the
# addon), the huge examples/assetlibs/ folder (downloaded 3rd-party assets
# that users can re-download themselves), and any .import asset caches left
# inside samples.
find "$STAGING/demos" "$STAGING/examples" -maxdepth 3 -type d -name bin -exec rm -rf {} + 2>/dev/null || true
rm -rf "$STAGING/examples/assetlibs" 2>/dev/null || true
find "$STAGING" -type d -name ".import" -exec rm -rf {} + 2>/dev/null || true

# Strip dev/debug-symbol GDExtension builds (~80 MB each) from every addon
# copy. They're only needed for engine debugging, not end-user runs.
# Use -L so we follow symlinked addon trees inside demos/examples.
find -L "$STAGING" -type f \( -name '*.template_debug.dev.*' -o -name '*.editor.dev.*' \) -delete 2>/dev/null || true

success "Staging complete"

# ── Create platform zips ───────────────────────────────────────────────────
step "6/7" "Creating release archives..."

# Linux zip
LINUX_DIR="$RELEASE_DIR/VisualGasic_v${VERSION}_linux_x86_64"
cp -r "$STAGING" "$LINUX_DIR"
# Copy non-dev variants only (skip *.editor.dev.* / *.template_debug.dev.* — ~80 MB each)
find demo/bin -name "*.linux.*" ! -name "*.dev.*" -exec cp {} "$LINUX_DIR/addons/visual_gasic/bin/" \; 2>/dev/null || true
(cd "$RELEASE_DIR" && zip -qr "VisualGasic_v${VERSION}_linux_x86_64.zip" "VisualGasic_v${VERSION}_linux_x86_64")
rm -rf "$LINUX_DIR"
success "Linux zip: VisualGasic_v${VERSION}_linux_x86_64.zip"

# Windows zip
if $HAS_MINGW; then
    WIN_DIR="$RELEASE_DIR/VisualGasic_v${VERSION}_windows_x86_64"
    cp -r "$STAGING" "$WIN_DIR"
    # Copy non-dev variants only (skip *.editor.dev.* / *.template_debug.dev.* — ~80 MB each)
    find demo/bin -name "*.windows.*" ! -name "*.dev.*" -exec cp {} "$WIN_DIR/addons/visual_gasic/bin/" \; 2>/dev/null || true
    (cd "$RELEASE_DIR" && zip -qr "VisualGasic_v${VERSION}_windows_x86_64.zip" "VisualGasic_v${VERSION}_windows_x86_64")
    rm -rf "$WIN_DIR"
    success "Windows zip: VisualGasic_v${VERSION}_windows_x86_64.zip"
fi

# macOS zip
if $IS_MACOS; then
    MAC_DIR="$RELEASE_DIR/VisualGasic_v${VERSION}_macos_universal"
    cp -r "$STAGING" "$MAC_DIR"
    find demo/bin -name "*.macos.*" -exec cp -r {} "$MAC_DIR/addons/visual_gasic/bin/" \; 2>/dev/null || true
    (cd "$RELEASE_DIR" && zip -qr "VisualGasic_v${VERSION}_macos_universal.zip" "VisualGasic_v${VERSION}_macos_universal")
    rm -rf "$MAC_DIR"
    success "macOS zip: VisualGasic_v${VERSION}_macos_universal.zip"
fi

# Clean staging
rm -rf "$STAGING"

# ── Godot Asset Library zip (addon-only, all platform binaries) ─────────────
step "7/8" "Building Godot Asset Library zip..."

# build_asset_library_zip.sh requires bin/ to dereference to demo/bin with all targets.
if [[ ! -L addons/visual_gasic/bin ]]; then
    rm -rf addons/visual_gasic/bin
    ln -sf ../../demo/bin addons/visual_gasic/bin
fi
bash "$SCRIPT_DIR/build_asset_library_zip.sh" "$VERSION"
success "Asset Library zip ready"

# ── Summary ─────────────────────────────────────────────────────────────────
step "8/8" "Release build complete!"

echo ""
echo -e "${GREEN}${BOLD}  ╔══════════════════════════════════════════╗"
echo "  ║     ✅ Release Build Complete!            ║"
echo -e "  ╚══════════════════════════════════════════╝${NC}"
echo ""
echo "  Version:  ${VERSION}"
echo "  Output:   ${RELEASE_DIR}/"
echo ""

ls -lh "$RELEASE_DIR/"*.zip 2>/dev/null | while read line; do
    echo "    $line"
done

echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo "    1. Test each zip in a fresh Godot project"
echo "    2. Tag the release:  git tag v${VERSION} && git push origin v${VERSION}"
echo "    3. CI will build + publish the GitHub Release automatically"
echo "    4. Or upload manually:  gh release create v${VERSION} ${RELEASE_DIR}/*.zip ${RELEASE_DIR}/*.AppImage ${RELEASE_DIR}/*.exe"
echo ""
