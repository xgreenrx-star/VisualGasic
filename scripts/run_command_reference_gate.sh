#!/usr/bin/env bash
# Programmer's Reference: static audit + headless parse harness (release gate).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "== Static implementation audit =="
python3 "$ROOT/scripts/audit_command_implementation.py" || {
  code=$?
  if [[ $code -ne 1 ]]; then
    exit "$code"
  fi
  echo "(audit reported known gaps — continuing to runtime harness)"
}
echo ""
echo "== Runtime parse harness =="
exec "$ROOT/scripts/run_command_reference_harness.sh" "$@"
