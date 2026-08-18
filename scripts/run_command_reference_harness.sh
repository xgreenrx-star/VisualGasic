#!/usr/bin/env bash
# Run Programmer's Reference parse/run harness (headless Godot).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/Godot_v4.6.1-stable_linux.x86_64}"
if [[ ! -x "$GODOT" ]]; then
  GODOT="$(command -v godot || true)"
fi
if [[ -z "$GODOT" || ! -x "$GODOT" ]]; then
  echo "No Godot binary found. Set GODOT=..." >&2
  exit 1
fi
exec "$GODOT" --headless --path "$ROOT/demo" -s "$ROOT/tests/test_command_reference_harness.gd" "$@"
