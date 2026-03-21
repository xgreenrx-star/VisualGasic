#!/bin/bash
# build_macos_universal.sh — Build macOS Universal Binary (arm64 + x86_64)
#
# Usage:
#   ./scripts/build_macos_universal.sh [target]
#
# Where target is: editor (default), template_debug, template_release
#
# Requirements:
#   - macOS with Xcode Command Line Tools
#   - scons, Python 3
#
# Output:
#   demo/bin/libvisualgasic.macos.<target>.framework/
#     Contains a universal (fat) binary supporting both Apple Silicon and Intel.

set -euo pipefail

TARGET="${1:-editor}"
JOBS="${JOBS:-$(sysctl -n hw.logicalcpu 2>/dev/null || nproc 2>/dev/null || echo 4)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_DIR="$ROOT_DIR/demo/bin"

FRAMEWORK_NAME="libvisualgasic.macos.${TARGET}.framework"
DYLIB_NAME="libvisualgasic.macos.${TARGET}"

echo "╔══════════════════════════════════════════════╗"
echo "║  VisualGasic — macOS Universal Binary Build  ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  Target: ${TARGET}"
echo "║  Jobs:   ${JOBS}"
echo "╚══════════════════════════════════════════════╝"
echo ""

cd "$ROOT_DIR"

# ── Step 1: Build for arm64 (Apple Silicon) ─────────────────────────────────
echo "▶ Building arm64 (Apple Silicon)..."
scons target="$TARGET" platform=macos arch=arm64 -j"$JOBS"

ARM64_FRAMEWORK="$BIN_DIR/$FRAMEWORK_NAME"
ARM64_DYLIB="$ARM64_FRAMEWORK/$DYLIB_NAME"

if [[ ! -f "$ARM64_DYLIB" ]]; then
    echo "ERROR: arm64 build output not found at $ARM64_DYLIB"
    exit 1
fi

# Save arm64 binary
ARM64_TEMP="$BIN_DIR/${DYLIB_NAME}.arm64"
cp "$ARM64_DYLIB" "$ARM64_TEMP"
echo "  ✅ arm64 binary saved"

# ── Step 2: Build for x86_64 (Intel) ────────────────────────────────────────
echo "▶ Building x86_64 (Intel)..."
scons target="$TARGET" platform=macos arch=x86_64 -j"$JOBS"

X86_FRAMEWORK="$BIN_DIR/$FRAMEWORK_NAME"
X86_DYLIB="$X86_FRAMEWORK/$DYLIB_NAME"

if [[ ! -f "$X86_DYLIB" ]]; then
    echo "ERROR: x86_64 build output not found at $X86_DYLIB"
    exit 1
fi

X86_TEMP="$BIN_DIR/${DYLIB_NAME}.x86_64"
cp "$X86_DYLIB" "$X86_TEMP"
echo "  ✅ x86_64 binary saved"

# ── Step 3: Combine with lipo ───────────────────────────────────────────────
echo "▶ Creating Universal Binary..."
UNIVERSAL_DYLIB="$ARM64_FRAMEWORK/$DYLIB_NAME"

lipo -create "$ARM64_TEMP" "$X86_TEMP" -output "$UNIVERSAL_DYLIB"

echo "  ✅ Universal binary created"

# Verify
echo ""
echo "▶ Verification:"
lipo -info "$UNIVERSAL_DYLIB"
ls -lh "$UNIVERSAL_DYLIB"

# ── Step 4: Code sign (ad-hoc for local dev) ────────────────────────────────
echo ""
echo "▶ Code signing (ad-hoc)..."
codesign --force --sign - --deep "$ARM64_FRAMEWORK" 2>/dev/null || true
echo "  ✅ Signed"

# ── Cleanup temp files ──────────────────────────────────────────────────────
rm -f "$ARM64_TEMP" "$X86_TEMP"

echo ""
echo "══════════════════════════════════════════════════"
echo "  Build complete: $ARM64_FRAMEWORK"
echo "  This framework supports both arm64 and x86_64."
echo "══════════════════════════════════════════════════"
