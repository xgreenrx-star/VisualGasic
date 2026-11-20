#!/usr/bin/env bash
# Phase 2 C2 deterministic fixture lane — four-mode *request* lane.
# Enables VG_SEM_PATH for evidence; does NOT claim verified path coverage for
# imports (function-name-only traces lack module identity). See contracts.
#
# Does NOT write test_proj/current_test.txt — invokes:
#   godot … -s run_suite.gd -- res://test_suite/<fixture>.vg
#
# Evidence layout under SEM_C2_OUT:
#   latest_run.txt              → absolute path of this invocation
#   c2_fixture_summary.txt      → mirror of this run's summary
#   gate_status.txt             → ok | ok_with_known_failures | fail (never stale ok)
#   run_<id>/
#     c2_fixture_summary.txt, gate_status.txt
#     <base>__<mode>.log, .paths, .judge.err
#     user_<base>_<mode>/       (Godot user-data; not uploaded)
#
# Env:
#   GODOT, SEM_C2_OUT, SEM_C2_MODES, SEM_C2_FIXTURES
#   SEM_C2_JUDGE_PY  — interpreter for the Python judge module (default python3)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

JUDGE_PY="${SEM_C2_JUDGE_PY:-python3}"

unset VG_FORCE_AST VG_JIT VG_JIT_LOG || true

OUT="${SEM_C2_OUT:-${RUNNER_TEMP:-/tmp}/vg-semantic-c2-fixtures}"
# Empty SEM_C2_MODES must fail closed (do not treat "" as unset → defaults).
if [[ -n "${SEM_C2_MODES+x}" ]]; then
	MODES="$SEM_C2_MODES"
else
	MODES="forced_ast,interpreter,default,tier3"
fi
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

# Invalidate any prior root success status *before* GODOT validation so a
# missing/invalid GODOT cannot leave a stale ok from a previous invocation.
rm -f "$OUT/gate_status.txt" "$OUT/c2_fixture_summary.txt" "$OUT/latest_run.txt"
echo "fail" >"$OUT/gate_status.txt"

if [[ -z "${GODOT:-}" || ! -x "$GODOT" ]]; then
	echo "ERROR: GODOT must be set to an executable Godot binary" >&2
	echo "early_failure=missing_or_invalid_GODOT" >"$OUT/c2_fixture_summary.txt"
	exit 1
fi

# Fresh invocation stamp — never treat stale logs as this run's evidence.
RUN_ID="$(date +%Y%m%d%H%M%S)-$$"
RUN_DIR="$OUT/run_$RUN_ID"
mkdir -p "$RUN_DIR"
INV_OUT="$RUN_DIR"
echo "fail" >"$INV_OUT/gate_status.txt"
echo "$INV_OUT" >"$OUT/latest_run.txt"

fail_early() {
	local msg="$1"
	echo "ERROR: $msg" >&2
	echo "fail" >"$INV_OUT/gate_status.txt"
	echo "fail" >"$OUT/gate_status.txt"
	echo "early_failure=$msg" >"$INV_OUT/c2_fixture_summary.txt"
	cp -f "$INV_OUT/c2_fixture_summary.txt" "$OUT/c2_fixture_summary.txt"
	exit 1
}

DEFAULT_FIXTURES=(
	"res://test_suite/test_sem_c2_calls_byref.vg"
	"res://test_suite/test_sem_c2_mod_identity.vg"
	"res://test_suite/test_sem_c2_twin_a_only.vg"
	"res://test_suite/test_sem_c2_twin_b_only.vg"
	"res://test_suite/test_sem_c2_alt_basename.vg"
	"res://test_suite/test_byref_byval.vg"
	"res://test_suite/test_byref_array_slot.vg"
	"res://test_suite/test_byref_computed_index.vg"
	"res://test_suite/test_byref_import.vg"
	"res://test_suite/test_byref_ast_import.vg"
	"res://test_suite/test_byref_caller_import.vg"
)
if [[ -n "${SEM_C2_FIXTURES:-}" ]]; then
	# shellcheck disable=SC2206
	FIXTURES=(${SEM_C2_FIXTURES})
else
	FIXTURES=("${DEFAULT_FIXTURES[@]}")
fi

IFS=',' read -r -a MODE_ARR_RAW <<< "$MODES"
MODE_ARR=()
for mode in "${MODE_ARR_RAW[@]}"; do
	mode="$(echo "$mode" | tr -d '[:space:]')"
	[[ -z "$mode" ]] && continue
	MODE_ARR+=("$mode")
done

if [[ ${#MODE_ARR[@]} -eq 0 ]]; then
	fail_early "SEM_C2_MODES is empty — refusing zero-run lane"
fi
if [[ ${#FIXTURES[@]} -eq 0 ]]; then
	fail_early "no fixtures selected — refusing zero-run lane"
fi

requested=$(( ${#MODE_ARR[@]} * ${#FIXTURES[@]} ))

echo "==> semantic C2 fixtures (four-mode request lane; path coverage not claimed for imports)"
echo "    GODOT=$GODOT"
echo "    OUT=$INV_OUT modes=${MODE_ARR[*]}"
echo "    fixtures=${#FIXTURES[@]} requested_cases=$requested"

overall=0
known_any=0
completed=0
summary="$INV_OUT/c2_fixture_summary.txt"
: >"$summary"
{
	echo "lane=four_mode_request_not_verified_path_coverage"
	echo "run_id=$RUN_ID"
	echo "requested_cases=$requested"
} >>"$summary"

run_one() {
	local mode="$1"
	local res="$2"
	local base
	base="$(basename "$res" .vg)"
	local log="$INV_OUT/${base}__${mode}.log"
	local judge_err="$INV_OUT/${base}__${mode}.judge.err"
	local env_export=(VG_SEM_PATH=1)
	case "$mode" in
		forced_ast) env_export+=(VG_FORCE_AST=1);;
		interpreter) env_export+=(VG_JIT=0);;
		default) ;;
		tier3) env_export+=(VG_JIT=3);;
		*)
			echo "ERROR: unknown mode $mode" >&2
			return 2
			;;
	esac

	# Isolation: do not touch test_proj/current_test.txt — pass path after --.
	set +e
	env "${env_export[@]}" timeout 60 "$GODOT" --headless --path test_proj \
		--user-data-dir "$INV_OUT/user_${base}_${mode}" \
		-s run_suite.gd -- "$res" >"$log" 2>&1
	local rc=$?
	set -e

	local gate_args=(
		--log "$log"
		--exit-code "$rc"
		--base "$base"
		--resource "$res"
		--mode "$mode"
		--summary-line
	)

	local line="" jrc=0
	set +e
	line="$("$JUDGE_PY" -m tools.semantic_fuzz.c2_fixture_gate "${gate_args[@]}" 2>"$judge_err")"
	jrc=$?
	set -e

	# Fail closed: judge must exit 0 AND emit a contract-valid OK verdict.
	if [[ "$jrc" -ne 0 ]]; then
		echo "FAIL $base mode=$mode judge_exit=$jrc exit=$rc reasons=[judge_nonzero_exit]" | tee -a "$summary"
		if [[ -n "$line" ]]; then
			echo "  judge_stdout=$line" >>"$summary"
		fi
		if [[ -s "$judge_err" ]]; then
			echo "  judge_stderr=$(head -c 500 "$judge_err" | tr '\n' ' ')" >>"$summary"
		fi
		return 1
	fi
	if [[ -z "$line" ]]; then
		echo "FAIL $base mode=$mode exit=$rc reasons=[empty_judge_stdout]" | tee -a "$summary"
		return 1
	fi

	# Structured contract check (real python3; JUDGE_PY may be a stub).
	local parse_rc=0 parse_detail=""
	parse_detail="$(python3 -c "
from tools.semantic_fuzz.c2_fixture_gate import VerdictContract, validate_positive_verdict
from tools.semantic_fuzz.c2_fixture_manifest import resolve_resource
import sys
line, base, mode, child_exit, resource = sys.argv[1:6]
resolved = resolve_resource(resource)
if resolved is None:
    print('unknown_resource')
    sys.exit(1)
res_base, expect = resolved
if res_base != base:
    print('resource_base_mismatch')
    sys.exit(1)
ok, detail = validate_positive_verdict(
    line,
    VerdictContract(
        base=base,
        mode=mode,
        child_exit=int(child_exit),
        expect=expect,
        resource=resource,
    ),
)
print(detail)
sys.exit(0 if ok else 1)
" "$line" "$base" "$mode" "$rc" "$res")" || parse_rc=$?
	if [[ "$parse_rc" -ne 0 ]]; then
		echo "FAIL $base mode=$mode exit=$rc reasons=[invalid_judge_verdict:$parse_detail] stdout=$line" | tee -a "$summary"
		return 1
	fi

	echo "$line" | tee -a "$summary"
	if [[ "$line" == *known=* ]]; then
		known_any=1
	fi
	grep '^VG_SEM_PATH ' "$log" >"$INV_OUT/${base}__${mode}.paths" 2>/dev/null || true
	completed=$((completed + 1))
	return 0
}

for mode in "${MODE_ARR[@]}"; do
	for res in "${FIXTURES[@]}"; do
		if ! run_one "$mode" "$res"; then
			overall=1
		fi
	done
done

{
	echo "completed_cases=$completed"
	echo "--- known failures (this invocation only) ---"
	grep -h '^C2_KNOWN_FAIL ' "$INV_OUT"/*.log 2>/dev/null || true
} >>"$summary"

cp -f "$summary" "$OUT/c2_fixture_summary.txt"

if [[ "$overall" -ne 0 ]]; then
	echo "fail" >"$INV_OUT/gate_status.txt"
	cp -f "$INV_OUT/gate_status.txt" "$OUT/gate_status.txt"
	echo "ERROR: semantic C2 fixtures failed — see $summary and logs in $INV_OUT" >&2
	exit 1
fi
if [[ "$completed" -ne "$requested" ]]; then
	echo "fail" >"$INV_OUT/gate_status.txt"
	cp -f "$INV_OUT/gate_status.txt" "$OUT/gate_status.txt"
	echo "ERROR: completed_cases=$completed != requested_cases=$requested" >&2
	exit 1
fi
if [[ "$known_any" -eq 1 ]]; then
	echo "ok_with_known_failures" >"$INV_OUT/gate_status.txt"
	cp -f "$INV_OUT/gate_status.txt" "$OUT/gate_status.txt"
	echo "==> semantic C2 fixtures PASSED WITH KNOWN FAILURES (see summary)"
else
	echo "ok" >"$INV_OUT/gate_status.txt"
	cp -f "$INV_OUT/gate_status.txt" "$OUT/gate_status.txt"
	echo "==> semantic C2 fixtures PASSED"
fi
echo "    summary: $summary"
echo "    note: module-qualified path contracts enforced for manifest path_requirements; other fixtures assertion-only; tier3 request ≠ native_t3"
