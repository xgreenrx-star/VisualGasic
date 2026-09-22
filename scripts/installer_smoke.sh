#!/usr/bin/env bash
# M9 installer smoke — static checks + lightweight bootstrap helpers (no full Godot download).
#
# Usage:
#   bash scripts/installer_smoke.sh
#   bash scripts/installer_smoke.sh --ffi   # also run NativeLibrary slice from test_v3_features
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() { echo "installer_smoke: FAIL: $*" >&2; exit 1; }
ok() { echo "installer_smoke: OK: $*"; }

echo "=== M9 installer smoke (static) ==="

python3 "$ROOT/scripts/bootstrap_vg.py" --help | grep -q -- '--with-cursor-mcp' \
  || fail "bootstrap_vg.py missing --with-cursor-mcp"
python3 "$ROOT/scripts/bootstrap_vg.py" --help | grep -q -- '--with-piper' \
  || fail "bootstrap_vg.py missing --with-piper"
python3 "$ROOT/scripts/bootstrap_vg.py" --help | grep -q -- '--with-whisper' \
  || fail "bootstrap_vg.py missing --with-whisper"
ok "bootstrap companion CLI flags present"

grep -q 'InstallCursorMcp' "$ROOT/scripts/windows_installer.nsi" \
  || fail "windows_installer.nsi missing Cursor MCP wizard"
grep -q '\-\-with-cursor-mcp' "$ROOT/scripts/windows_installer.nsi" \
  || fail "windows_installer.nsi does not pass --with-cursor-mcp to bootstrap"
ok "Windows NSIS Cursor + bootstrap wiring"

grep -q 'with_cursor_mcp' "$ROOT/scripts/bootstrap_gui.py" \
  || fail "bootstrap_gui.py missing Cursor MCP option"
ok "Tk bootstrap GUI companion section"

grep -q 'auto_show_project_wizard=true' "$ROOT/scripts/bootstrap_vg.py" \
  || fail "scaffold template missing auto_show_project_wizard"
ok "Scaffolded projects enable project setup wizard"

# Python MCP writer (same shape as vg_cursor_mcp_config.gd)
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
python3 - <<PY
import json, sys
sys.path.insert(0, "$ROOT/scripts")
import bootstrap_vg as bvg
from pathlib import Path
p = Path("$TMP") / "proj"
p.mkdir()
bvg.write_cursor_mcp_config(p)
data = json.loads((p / ".cursor" / "mcp.json").read_text())
assert data["mcpServers"]["visual-gasic"]["url"] == "http://127.0.0.1:8766/mcp"
PY
ok "write_cursor_mcp_config merge"

grep -q 'auto_show_project_wizard' "$ROOT/addons/visual_gasic/visual_gasic_plugin.gd" \
  || fail "plugin missing auto_show_project_wizard default"
grep -q 'VGCursorMcpConfig\|vg_cursor_mcp_config' "$ROOT/addons/visual_gasic/vg_first_run_dialog.gd" \
  || fail "first-run dialog missing Cursor MCP step"
ok "Godot first-run / plugin defaults"

grep -q 'parse_declare' "$ROOT/src/visual_gasic_parser.cpp" \
  || fail "parser missing parse_declare (M8 Declare/DllImport)"
grep -q 'ffi_declares' "$ROOT/src/visual_gasic_ast.h" \
  || fail "AST missing ffi_declares"
grep -q 'VG_FFI_CAST' "$ROOT/src/visual_gasic_instance_class.cpp" \
  || fail "FFI runtime missing cdecl/stdcall (VG_FFI_CAST)"
grep -q 'PLATFORM_SKIP_FILES' "$ROOT/run_test_suite.sh" \
  || fail "run_test_suite.sh missing platform FFI skips"
ok "M8 Declare/DllImport parser wiring"

for f in install_piper.sh install_whisper.sh install_piper.ps1 install_whisper.ps1; do
  [[ -f "$ROOT/scripts/$f" ]] || fail "missing scripts/$f"
done
ok "Piper/Whisper install scripts present"

if [[ "${1:-}" == "--ffi" ]]; then
  echo ""
  echo "=== M8 FFI smoke (NativeLibrary in test_v3_features) ==="
  if [[ -x "$ROOT/run_test_suite.sh" ]]; then
    ffi_out=$(bash "$ROOT/run_test_suite.sh" test_declare_ffi.vg 2>&1) || true
    echo "$ffi_out" | tail -20
    echo "$ffi_out" | grep -q '^PASS:' || fail "test_declare_ffi.vg did not PASS"
    ok "test_declare_ffi.vg (M8 libc FFI)"
  else
    echo "installer_smoke: skip FFI run (run_test_suite.sh not found or headless Godot unavailable)"
  fi
fi

echo ""
echo "installer_smoke: all checks passed."
