#!/usr/bin/env bash
# Headless smoke: Brotato VG scripts parse + spawn-path regression tests.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"

echo "=== Brotato spawn regression ==="
"$ROOT/run_test_suite.sh" --vg-only test_spawn_getparent.vg
"$ROOT/run_test_suite.sh" --vg-only test_add_child_scene.vg

echo "=== Brotato project smoke ==="
"$ROOT/scripts/ci_smoke.sh" "$ROOT/samples/games/brotato_vg"

echo "=== OK: spawn tests + brotato smoke passed ==="
