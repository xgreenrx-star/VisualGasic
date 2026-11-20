#!/usr/bin/env bash
# Bounded semantic smoke for CI/release (Task A).
# Runs serially after GDExtension prepare/smoke. Does not soft-fail.
#
# Env:
#   GODOT          — required; absolute Godot binary used by the job
#   SEM_FUZZ_OUT   — evidence directory (default under runner temp /tmp)
#   SEM_FUZZ_SEED  — fixed seed (default 42)
#   SEM_FUZZ_COUNT — case count (default 20)
#   SEM_FUZZ_MODES — must be explicit; default forced_ast,interpreter,default,tier3
#   SEM_FUZZ_TIMEOUT — per-case Godot timeout seconds (default 30)
#   SEM_FUZZ_STEP_TIMEOUT — whole-campaign wall timeout seconds (default 180)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -z "${GODOT:-}" || ! -x "$GODOT" ]]; then
	echo "ERROR: GODOT must be set to an executable Godot binary" >&2
	exit 1
fi

# Modes must not inherit a developer shell's VG_* overrides for the gate itself.
# The campaign sets per-mode env inside each run; clear ambient overrides here.
unset VG_FORCE_AST VG_JIT VG_JIT_LOG || true

SEED="${SEM_FUZZ_SEED:-42}"
COUNT="${SEM_FUZZ_COUNT:-20}"
MODES="${SEM_FUZZ_MODES:-forced_ast,interpreter,default,tier3}"
OUT="${SEM_FUZZ_OUT:-${RUNNER_TEMP:-/tmp}/vg-semantic-ci-smoke}"
CASE_TIMEOUT="${SEM_FUZZ_TIMEOUT:-30}"
STEP_TIMEOUT="${SEM_FUZZ_STEP_TIMEOUT:-180}"

mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
export SEM_FUZZ_OUT="$OUT"
export GODOT

echo "==> semantic CI smoke"
echo "    GODOT=$GODOT"
echo "    OUT=$OUT seed=$SEED count=$COUNT modes=$MODES"
echo "    case_timeout=${CASE_TIMEOUT}s step_timeout=${STEP_TIMEOUT}s"

# 1) Oracle + harness self-tests (includes CI gate propagation probes)
python3 -m tools.semantic_fuzz selftest

# 2) Fixed-seed campaign — modes explicit; fail hard on any issue
set +e
timeout --signal=TERM "$STEP_TIMEOUT" \
	python3 -m tools.semantic_fuzz run \
		--seed "$SEED" \
		--count "$COUNT" \
		--modes "$MODES" \
		--out "$OUT" \
		--timeout "$CASE_TIMEOUT"
rc=$?
set -e

if [[ "$rc" -eq 124 ]]; then
	echo "ERROR: semantic campaign exceeded step timeout (${STEP_TIMEOUT}s)" >&2
	echo "timeout" > "$OUT/gate_status.txt"
	exit 124
fi
if [[ "$rc" -ne 0 ]]; then
	echo "ERROR: semantic campaign failed (exit $rc)" >&2
	echo "campaign_fail" > "$OUT/gate_status.txt"
	exit "$rc"
fi

# 3) Required evidence present
for f in campaign_summary.txt campaign_report.json; do
	if [[ ! -s "$OUT/$f" ]]; then
		echo "ERROR: missing required evidence $OUT/$f" >&2
		echo "missing_evidence" > "$OUT/gate_status.txt"
		exit 1
	fi
done

python3 - "$OUT" <<'PY'
import json, sys
from pathlib import Path
out = Path(sys.argv[1])
rep = json.loads((out / "campaign_report.json").read_text(encoding="utf-8"))
prov = rep.get("provenance") or {}
if not prov.get("binary_sha256"):
    raise SystemExit("ERROR: provenance missing binary_sha256")
if not prov.get("godot_sha256"):
    raise SystemExit("ERROR: provenance missing godot_sha256")
if not prov.get("git_rev") or prov.get("git_rev") == "unknown":
    raise SystemExit("ERROR: provenance missing git_rev")
if rep.get("failure_count", 1) != 0 or not rep.get("ok"):
    raise SystemExit("ERROR: campaign_report reports failures")
if rep.get("generated", 0) < 1:
    raise SystemExit("ERROR: empty campaign")
# Tier-3 request honesty: report actual native_t2 vs native_t3; do not require t3.
paths = rep.get("path_totals") or {}
kn = paths.get("KernelNative") or {}
t2 = int(kn.get("native_t2", 0))
t3 = int(kn.get("native_t3", 0))
summary = out / "native_tier_counts.txt"
summary.write_text(
    f"KernelNative native_t2={t2} native_t3={t3}\n"
    f"note: VG_JIT=3 is a request; native_t3=0 means Tier 3 did not execute\n",
    encoding="utf-8",
)
print(summary.read_text(encoding="utf-8"), end="")
if t2 < 1:
    # On Linux x86-64 editor builds with path instrumentation, eligible kernels
    # must demonstrate native Tier 2 after warmup under default/tier3.
    raise SystemExit("ERROR: no KernelNative native_t2 executions observed (instrumentation/binary stale?)")
print("OK: evidence and native_t2 coverage validated")
PY

echo "ok" > "$OUT/gate_status.txt"
echo "==> semantic CI smoke PASSED"
echo "    summary: $OUT/campaign_summary.txt"
