#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
VERSION="$(tr -d '[:space:]' < VERSION)"
OUT="$ROOT/release/v$VERSION"
mkdir -p "$OUT"
for platform in linux windows; do
  for target in editor template_debug template_release; do
    suffix=so
    [[ "$platform" == windows ]] && suffix=dll
    test -s "addons/visual_gasic/bin/libvisualgasic.$platform.$target.x86_64.$suffix"
  done
done
for target in editor template_debug template_release; do
  test -s "addons/visual_gasic/bin/libvisualgasic.macos.$target.framework/libvisualgasic.macos.$target"
done
for target in template_debug template_release; do
  test -s "addons/visual_gasic/bin/libvisualgasic.web.$target.wasm32.nothreads.wasm"
done
WORK="$(mktemp -d "${TMPDIR:-/tmp}/vg-release-package.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

test -s addons/visual_gasic/plugins/vgmusic/bin/LICENSE
for target in template_debug template_release; do
  test -s "addons/visual_gasic/plugins/vgmusic/bin/libgdsion.linux.$target.x86_64.so"
  test -s "addons/visual_gasic/plugins/vgmusic/bin/libgdsion.windows.$target.x86_64.dll"
  test -s "addons/visual_gasic/plugins/vgmusic/bin/libgdsion.macos.$target.framework/libgdsion.macos.$target"
done
cat > addons/visual_gasic/plugins/vgmusic/libgdsion.gdextension <<'EOF'
[configuration]
compatibility_minimum = "4.3"
entry_symbol = "gdsion_library_init"
[libraries]
linux.debug.x86_64 = "res://addons/visual_gasic/plugins/vgmusic/bin/libgdsion.linux.template_debug.x86_64.so"
linux.release.x86_64 = "res://addons/visual_gasic/plugins/vgmusic/bin/libgdsion.linux.template_release.x86_64.so"
windows.debug.x86_64 = "res://addons/visual_gasic/plugins/vgmusic/bin/libgdsion.windows.template_debug.x86_64.dll"
windows.release.x86_64 = "res://addons/visual_gasic/plugins/vgmusic/bin/libgdsion.windows.template_release.x86_64.dll"
macos.debug = "res://addons/visual_gasic/plugins/vgmusic/bin/libgdsion.macos.template_debug.framework"
macos.release = "res://addons/visual_gasic/plugins/vgmusic/bin/libgdsion.macos.template_release.framework"
EOF
bash scripts/build_asset_library_zip.sh "$VERSION"
cp "$OUT/VisualGasic_AssetLibrary_v$VERSION.zip" "$OUT/VisualGasic-v$VERSION.zip"
mkdir -p "$WORK/full"
unzip -q "$OUT/VisualGasic_AssetLibrary_v$VERSION.zip" -d "$WORK/full"
cp README.md CHANGELOG.md LICENSE VERSION "RELEASE_NOTES_v$VERSION.md" "$WORK/full/"
cp install.sh install.ps1 install.py vg "$WORK/full/"
git ls-files -z docs tutorials samples | tar --null -T - -cf - | tar -xf - -C "$WORK/full"
# Sample addon links resolve to the bundled addon, not the developer checkout.
(cd "$WORK/full" && zip -qry "$OUT/VisualGasic-Examples-and-Docs-v$VERSION.zip" .)

for platform in linux windows macos web; do
  mkdir -p "$WORK/$platform/addons/visual_gasic/bin"
  cp addons/visual_gasic/visual_gasic.gdextension "$WORK/$platform/addons/visual_gasic/"
  case "$platform" in
    macos) cp -a addons/visual_gasic/bin/libvisualgasic.macos.*.framework "$WORK/$platform/addons/visual_gasic/bin/" ;;
    *) cp addons/visual_gasic/bin/libvisualgasic."$platform".* "$WORK/$platform/addons/visual_gasic/bin/" ;;
  esac
  (cd "$WORK/$platform" && zip -qr "$OUT/VisualGasic-Binaries-v$VERSION-$platform.zip" addons)
done
bash scripts/build_appimage.sh "$VERSION"
bash scripts/build_windows_installer.sh "$VERSION"
bash scripts/build_offline_bundle.sh "$VERSION"
bash scripts/build_macos_installer.sh "$VERSION"
git rev-parse HEAD > "$OUT/BUILD_COMMIT.txt"
(cd "$OUT" && sha256sum *.zip *.exe "VisualGasic-Installer-v$VERSION-x86_64.AppImage" BUILD_COMMIT.txt > SHA256SUMS)
