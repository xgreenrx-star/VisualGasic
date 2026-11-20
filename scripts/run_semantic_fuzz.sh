#!/usr/bin/env bash
# Seeded semantic fuzz campaign (Phase 1).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
SEED="${1:-42}"
COUNT="${2:-100}"
MODES="${SEM_FUZZ_MODES:-forced_ast,interpreter,default}"
OUT="${SEM_FUZZ_OUT:-$(mktemp -d "${TMPDIR:-/tmp}/vg-sem-fuzz-XXXXXX")}"
export SEM_FUZZ_OUT="$OUT"
echo "semantic_fuzz out=$OUT seed=$SEED count=$COUNT modes=$MODES"
python3 -m tools.semantic_fuzz run --seed "$SEED" --count "$COUNT" --modes "$MODES" --out "$OUT"
echo "report: $OUT/campaign_summary.txt"
