#!/usr/bin/env bash
# CI: build WASM (if needed), verify, export samples/apps/web_hello to HTML5.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="${1:-$ROOT/samples/apps/web_hello}"
OUT_DIR="${2:-$ROOT/build/ci_web_smoke}"
GODOT_VERSION="${GODOT_VERSION:-4.6.1}"
GODOT_FLAVOR="${GODOT_FLAVOR:-stable}"

mkdir -p "$OUT_DIR"
rm -rf "$OUT_DIR"/*
mkdir -p "$OUT_DIR"

if [[ "${VG_SKIP_WEB_BUILD:-0}" != "1" ]] && [[ ! -f addons/visual_gasic/bin/libvisualgasic.web.template_release.wasm32.nothreads.wasm ]]; then
  bash scripts/setup_emsdk.sh
  # shellcheck source=/dev/null
  source thirdparty/emsdk/emsdk_env.sh
  bash scripts/build_web_gdextension.sh template_release
fi

bash scripts/verify_web_gdextension.sh

if [[ -z "${GODOT:-}" ]]; then
  GODOT="$ROOT/Godot_v${GODOT_VERSION}-${GODOT_FLAVOR}_linux.x86_64"
  if [[ ! -x "$GODOT" ]]; then
    echo "Downloading Godot ${GODOT_VERSION} (${GODOT_FLAVOR}, non-Mono) ..."
    wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_FLAVOR}/Godot_v${GODOT_VERSION}-${GODOT_FLAVOR}_linux.x86_64.zip" -O /tmp/godot_web_smoke.zip
    unzip -q -o /tmp/godot_web_smoke.zip -d "$ROOT"
    chmod +x "$GODOT"
  fi
fi

if [[ ! -x "$GODOT" ]]; then
  echo "GODOT not executable: $GODOT" >&2
  exit 1
fi

TEMPLATE_DIR="${HOME}/.local/share/godot/export_templates/${GODOT_VERSION}.${GODOT_FLAVOR}"
if [[ ! -f "$TEMPLATE_DIR/web_nothreads_release.zip" ]]; then
  echo "Installing export templates (including Web) to $TEMPLATE_DIR ..."
  mkdir -p "$TEMPLATE_DIR"
  wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_FLAVOR}/Godot_v${GODOT_VERSION}-${GODOT_FLAVOR}_export_templates.tpz" -O /tmp/godot_export_templates.tpz
  rm -rf /tmp/godot_export_templates_unzip
  mkdir -p /tmp/godot_export_templates_unzip
  unzip -q -o /tmp/godot_export_templates.tpz -d /tmp/godot_export_templates_unzip
  cp -a /tmp/godot_export_templates_unzip/templates/. "$TEMPLATE_DIR/"
fi

PROJ_DIR="$PROJECT"
if [[ -d "$PROJECT" && -f "$PROJECT/project.godot" ]]; then
  PROJ_DIR="$PROJECT"
elif [[ -f "$PROJECT" ]]; then
  PROJ_DIR="$(dirname "$PROJECT")"
else
  echo "Project not found: $PROJECT" >&2
  exit 1
fi

python3 "$ROOT/scripts/strip_tweak_overlay.py" --project "$PROJ_DIR" || true
python3 "$ROOT/scripts/ensure_web_gdextension_export_preset.py" --project "$PROJ_DIR" || true

EXPORT_HTML="$OUT_DIR/index.html"
echo "Exporting $PROJ_DIR (Web) -> $EXPORT_HTML"
"$GODOT" --headless --path "$PROJ_DIR" --export-release "Web" "$EXPORT_HTML" 2>&1 | tail -30

if [[ ! -f "$EXPORT_HTML" ]]; then
  echo "Web export failed: $EXPORT_HTML not created" >&2
  exit 1
fi

echo "Web export smoke OK: $EXPORT_HTML ($(du -h "$EXPORT_HTML" | cut -f1))"

if [[ "${VG_WEB_HEADLESS_VERIFY:-1}" == "1" ]]; then
  echo "Headless browser verify (splash + Open-Meteo HTTP) ..."
  VENV="$ROOT/scripts/.venv-web-debug"
  if [[ ! -x "$VENV/bin/python3" ]]; then
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install -q websocket-client
  fi
  EXPORT_DIR="$(dirname "$EXPORT_HTML")"
  PORT="${VG_WEB_HEADLESS_PORT:-8877}"
  WAIT_MS="${VG_WEB_HEADLESS_WAIT_MS:-180000}"
  if ! "$VENV/bin/python3" "$ROOT/scripts/debug_web_hello_cdp.py" "$PORT" "$WAIT_MS" "$EXPORT_DIR"; then
    echo "Headless web verify failed (Chrome required, or set VG_WEB_HEADLESS_VERIFY=0 to skip)." >&2
    exit 1
  fi
fi
