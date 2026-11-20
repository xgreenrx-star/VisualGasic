#!/usr/bin/env bash
# Bounded C2 scalar-call campaign (domain=c2). Does not replace Phase 1 smoke.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -z "${GODOT:-}" || ! -x "$GODOT" ]]; then
	echo "ERROR: GODOT must be set" >&2
	exit 1
fi

OUT="${SEM_C2_CAMPAIGN_OUT:-${RUNNER_TEMP:-/tmp}/vg-semantic-c2-campaign}"
SEED="${SEM_C2_CAMPAIGN_SEED:-42}"
# Default covers all C2_FAMILIES (14) so imports/recursion/early are not skipped.
COUNT="${SEM_C2_CAMPAIGN_COUNT:-14}"
MODES="${SEM_C2_CAMPAIGN_MODES:-forced_ast,interpreter,default,tier3}"
TIMEOUT="${SEM_C2_CAMPAIGN_TIMEOUT:-45}"
# Set SEM_C2_SKIP_FAMILY_GATE=1 only for local debugging (never in CI).
SKIP_FAMILY_GATE="${SEM_C2_SKIP_FAMILY_GATE:-0}"

mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
echo "fail" >"$OUT/gate_status.txt"

unset VG_FORCE_AST VG_JIT VG_JIT_LOG || true

echo "==> semantic C2 campaign"
echo "    GODOT=$GODOT seed=$SEED count=$COUNT modes=$MODES"
echo "    OUT=$OUT"

set +e
python3 -m tools.semantic_fuzz run \
	--domain c2 \
	--seed "$SEED" \
	--count "$COUNT" \
	--modes "$MODES" \
	--out "$OUT" \
	--timeout "$TIMEOUT"
rc=$?
set -e

if [[ "$rc" -ne 0 ]]; then
	echo "ERROR: C2 campaign failed (exit $rc)" >&2
	echo "fail" >"$OUT/gate_status.txt"
	exit "$rc"
fi

if [[ "$SKIP_FAMILY_GATE" != "1" ]]; then
	set +e
	python3 -m tools.semantic_fuzz.c2_family_coverage "$OUT/campaign_report.json"
	gate_rc=$?
	set -e
	if [[ "$gate_rc" -ne 0 ]]; then
		echo "ERROR: C2 family coverage gate failed" >&2
		echo "fail_coverage" >"$OUT/gate_status.txt"
		exit "$gate_rc"
	fi
fi

echo "ok" >"$OUT/gate_status.txt"
echo "==> semantic C2 campaign PASSED: $OUT/campaign_summary.txt"
