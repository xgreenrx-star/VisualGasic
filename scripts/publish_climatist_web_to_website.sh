#!/usr/bin/env bash
# Export Climatist POC to HTML5 and copy into the GitHub Pages tree (non-prominent /play/ path).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJ="$ROOT/samples/apps/climatist_poc"
BUILD="$ROOT/build/web"
SITE_PLAY="$ROOT/website/temporary-placeholder-site/play/climatist"

if [[ "${VG_SKIP_WEB_BUILD:-0}" != "1" ]] && [[ ! -f "$ROOT/addons/visual_gasic/bin/libvisualgasic.web.template_release.wasm32.nothreads.wasm" ]]; then
  echo "Building WASM GDExtension (first time) ..."
  bash "$ROOT/scripts/setup_emsdk.sh"
  # shellcheck source=/dev/null
  source "$ROOT/thirdparty/emsdk/emsdk_env.sh"
  bash "$ROOT/scripts/build_web_gdextension.sh" template_release
fi

bash "$ROOT/scripts/verify_web_gdextension.sh"

bash "$ROOT/scripts/vg_make_web_export.sh" "$PROJ" Web "$BUILD"

rm -rf "$SITE_PLAY"
mkdir -p "$SITE_PLAY"
cp -a "$BUILD/climatist_poc/." "$SITE_PLAY/"

python3 "$ROOT/scripts/patch_godot_web_github_pages.py" "$SITE_PLAY"

echo "Published: $SITE_PLAY/index.html"
echo "Local test: python3 $ROOT/scripts/serve_web_export.py $SITE_PLAY"
echo "Pages URL path: /play/climatist/index.html (footer link on site)"
