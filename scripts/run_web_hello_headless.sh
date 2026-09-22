#!/usr/bin/env bash
# Local headless check: export web_hello (if needed), serve, Chrome CDP smoke.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EXPORT="${1:-$ROOT/build/web/web_hello}"
PORT="${2:-8060}"
WAIT_MS="${3:-120000}"

if [[ ! -f "$EXPORT/index.html" ]]; then
  bash scripts/vg_make_web_export.sh samples/apps/web_hello Web build/web
  EXPORT="$ROOT/build/web/web_hello"
fi

VENV="$ROOT/scripts/.venv-web-debug"
if [[ ! -x "$VENV/bin/python3" ]]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -q websocket-client
fi

exec "$VENV/bin/python3" "$ROOT/scripts/debug_web_hello_cdp.py" "$PORT" "$WAIT_MS" "$EXPORT"
