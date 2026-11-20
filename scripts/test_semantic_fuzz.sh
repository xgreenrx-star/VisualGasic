#!/usr/bin/env bash
# Semantic fuzz harness self-tests (no Godot campaign).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
python3 -m tools.semantic_fuzz selftest
