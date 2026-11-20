"""Harness negative tests using fake runner / corrupted observations / handler probes."""

from __future__ import annotations

import copy
import json
import subprocess
from pathlib import Path
from random import Random

from .compare import CompareError, compare_observations
from .generator import (
    generate_batch,
    generate_case,
    gen_module_local_warmup,
    shape_fingerprint,
    structural_fingerprint,
)
from .ir import Assign, Lit, Observe, Program, dumps_program, loads_program
from .oracle_selftest import run_oracle_selftests
from .reducer import reduce_failure
from .reference import evaluate_program
from .runner import (
    RunResult,
    check_required_path,
    classify_timeout_output,
    parse_log,
)


def _detect(code: str, fn) -> str | None:
    try:
        fn()
        return f"MISS:{code}"
    except CompareError as exc:
        if exc.code != code and code != "any":
            return f"WRONG_CODE:{code} got {exc.code}"
        return None
    except Exception as exc:
        if code == "crash_class":
            return None
        return f"OTHER:{code}:{exc}"


def run_harness_selftests() -> list[str]:
    fails = run_oracle_selftests()
    prog = generate_case(42, 0)
    expected = [o.to_dict() for o in evaluate_program(prog).observations]
    if not expected:
        fails.append("expected observations empty for seed 42 index 0")
        return fails

    # wrong value
    bad_val = copy.deepcopy(expected)
    bad_val[0]["value"] = str(int(bad_val[0]["value"]) + 1)
    r = _detect("wrong_value", lambda: compare_observations(expected, bad_val))
    if r:
        fails.append(r)

    # wrong type — must be detectable (runtime TypeName vs expected)
    bad_ty = copy.deepcopy(expected)
    bad_ty[0]["type"] = "Double"
    r = _detect("wrong_type", lambda: compare_observations(expected, bad_ty))
    if r:
        fails.append(r)

    # reordered / missing name
    bad_ord = copy.deepcopy(expected)
    bad_ord[0]["name"] = "not_" + bad_ord[0]["name"]
    r = _detect("reordered_or_missing", lambda: compare_observations(expected, bad_ord))
    if r:
        fails.append(r)

    # missing effect (count)
    r = _detect(
        "count_mismatch",
        lambda: compare_observations(expected, expected[:-1] if len(expected) > 1 else []),
    )
    if r:
        fails.append(r)

    # malformed observation object
    r = _detect("malformed", lambda: compare_observations(expected, [{"name": "x"}]))
    if r:
        fails.append(r)

    # empty campaign refused
    try:
        from .campaign import run_campaign

        run_campaign(1, 0)
        fails.append("MISS:empty_campaign")
    except ValueError:
        pass

    # --- path checks: wrong function must not satisfy ---
    warm = gen_module_local_warmup(Random(1), 1, 0)
    # KernelNative required native_t2, but only SemMain has bytecode — must fail.
    rr = RunResult(
        ok=True,
        path_counts={"SemMain": {"bytecode": 5}, "KernelNative": {"ast": 3}},
        path_events=[{"path": "bytecode", "fn": "SemMain"}, {"path": "ast", "fn": "KernelNative"}],
        mode="default",
    )
    err = check_required_path(warm, "default", rr)
    if not err:
        fails.append("MISS:wrong_function_path_accepted")

    # Fallback masquerading as native
    rr2 = RunResult(
        ok=True,
        path_counts={"KernelNative": {"bytecode": 5}},
        path_events=[{"path": "bytecode", "fn": "KernelNative"}],
        mode="default",
    )
    err = check_required_path(warm, "default", rr2)
    if not err:
        fails.append("MISS:fallback_as_native")

    # Interpreter required-bytecode must reject AST events on the target
    arith = generate_case(42, 0)  # SemMain + bytecode under interpreter
    rr_ast = RunResult(
        ok=True,
        path_counts={"SemMain": {"ast": 1, "bytecode": 1}},
        path_events=[
            {"path": "bytecode", "fn": "SemMain"},
            {"path": "ast", "fn": "SemMain"},
        ],
        mode="interpreter",
    )
    err = check_required_path(arith, "interpreter", rr_ast)
    if not err or "AST" not in err:
        fails.append("MISS:interpreter_ast_on_bytecode_accepted")

    # native_t2 + AST must be rejected (conflicts before success)
    rr_nat_ast = RunResult(
        ok=True,
        path_counts={"KernelNative": {"native_t2": 1, "ast": 1}},
        path_events=[
            {"path": "native_t2", "fn": "KernelNative"},
            {"path": "ast", "fn": "KernelNative"},
        ],
        mode="default",
    )
    err = check_required_path(warm, "default", rr_nat_ast)
    if not err or "AST" not in err:
        fails.append("MISS:native_t2_ast_mixed_accepted")

    # native_t3_or_native_t2 + AST (via native_t2) must be rejected before success return
    rr_or_t2_ast = RunResult(
        ok=True,
        path_counts={"KernelNative": {"native_t2": 2, "ast": 1}},
        path_events=[
            {"path": "native_t2", "fn": "KernelNative"},
            {"path": "ast", "fn": "KernelNative"},
        ],
        mode="tier3",
    )
    err = check_required_path(warm, "tier3", rr_or_t2_ast)
    if not err or "AST" not in err:
        fails.append("MISS:native_t3_or_t2_via_t2_ast_accepted")

    # native_t3_or_native_t2 + AST (via native_t3) must be rejected before success return
    rr_or_t3_ast = RunResult(
        ok=True,
        path_counts={"KernelNative": {"native_t3": 2, "ast": 1}},
        path_events=[
            {"path": "native_t3", "fn": "KernelNative"},
            {"path": "ast", "fn": "KernelNative"},
        ],
        mode="tier3",
    )
    err = check_required_path(warm, "tier3", rr_or_t3_ast)
    if not err or "AST" not in err:
        fails.append("MISS:native_t3_or_t2_via_t3_ast_accepted")

    # Legitimate bytecode warmup then native must pass (both native alternatives)
    rr_warm_t2 = RunResult(
        ok=True,
        path_counts={"KernelNative": {"bytecode": 3, "native_t2": 2}},
        path_events=[
            {"path": "bytecode", "fn": "KernelNative"},
            {"path": "native_t2", "fn": "KernelNative"},
        ],
        mode="default",
    )
    err = check_required_path(warm, "default", rr_warm_t2)
    if err:
        fails.append(f"MISS:warmup_then_native_t2_rejected:{err}")

    rr_warm_or = RunResult(
        ok=True,
        path_counts={"KernelNative": {"bytecode": 2, "native_t3": 3}},
        path_events=[
            {"path": "bytecode", "fn": "KernelNative"},
            {"path": "native_t3", "fn": "KernelNative"},
        ],
        mode="tier3",
    )
    err = check_required_path(warm, "tier3", rr_warm_or)
    if err:
        fails.append(f"MISS:warmup_then_native_t3_or_rejected:{err}")

    # Bytecode-only when native required (no native entry) still fails
    rr_bc_only = RunResult(
        ok=True,
        path_counts={"KernelNative": {"bytecode": 3}},
        path_events=[{"path": "bytecode", "fn": "KernelNative"}],
        mode="default",
    )
    err = check_required_path(warm, "default", rr_bc_only)
    if not err:
        fails.append("MISS:bytecode_as_native_accepted")

    # Fallback-contract must still require bytecode on ShortJoin (not skip validation)
    from .generator import gen_fallback_andalso

    fb = gen_fallback_andalso(1, 16)
    rr3 = RunResult(
        ok=True,
        path_counts={"SemMain": {"bytecode": 1}, "ShortJoin": {"native_t2": 1}},
        path_events=[{"path": "native_t2", "fn": "ShortJoin"}],
        mode="default",
    )
    err = check_required_path(fb, "default", rr3)
    if not err:
        fails.append("MISS:fallback_contract_skipped_path_check")

    # --- timeout handler: realistic TimeoutExpired must classify, not TypeError ---
    class FakeTimeout(subprocess.TimeoutExpired):
        def __init__(self):
            # Mimic mixed None/bytes that previously TypeError'd string concat.
            super().__init__(cmd=["godot"], timeout=1, output=b"partial\n", stderr=None)

    try:
        text, code, timed = classify_timeout_output(FakeTimeout())
        if not timed or code != 124:
            fails.append("MISS:timeout_classify_flags")
        if "partial" not in text:
            fails.append("MISS:timeout_classify_stdout")
    except TypeError as exc:
        fails.append(f"MISS:timeout_handler_typeerror:{exc}")

    # Also None/None
    class EmptyTimeout(subprocess.TimeoutExpired):
        def __init__(self):
            super().__init__(cmd=["godot"], timeout=1, output=None, stderr=None)

    try:
        classify_timeout_output(EmptyTimeout())
    except TypeError as exc:
        fails.append(f"MISS:timeout_empty_typeerror:{exc}")

    # --- malformed log lines / duplicate DONE rejected ---
    pl = parse_log('VG_SEM_OBS kind=value name=r type=Integer value=1\nVG_SEM_OBS broken\n')
    if not pl.error or "malformed observation" not in pl.error:
        fails.append("MISS:malformed_obs_ignored")
    pl = parse_log(
        "VG_SEM_DONE case=a\nVG_SEM_OBS kind=value name=r type=Integer value=1\nVG_SEM_DONE case=a\n"
    )
    if not pl.error or "duplicate" not in pl.error:
        fails.append("MISS:duplicate_done_ignored")

    # --- failure_code preserved for compare failures ---
    from .campaign import _write_failure_bundle
    import tempfile

    with tempfile.TemporaryDirectory() as td:
        case_out = Path(td) / "case" / "interpreter"
        fake_rr = RunResult(
            ok=True,
            mode="interpreter",
            observations=[{"name": "r", "type": "Integer", "value": "0"}],
            bound_path_module="res://sem_fuzz_runs/test/case/interpreter/case.vg",
            bound_path_module_key="sem_fuzz_ir/case/interpreter",
        )
        _write_failure_bundle(
            case_out,
            prog,
            expected,
            fake_rr,
            failure_code="wrong_value",
            compare_error="demo",
        )
        meta = json.loads((case_out / "failure.json").read_text(encoding="utf-8"))
        if meta.get("failure_code") != "wrong_value":
            fails.append(f"MISS:failure_code_null got {meta.get('failure_code')!r}")
        prog_meta = json.loads((case_out / "program.json").read_text(encoding="utf-8"))
        if prog_meta.get("mode") != "interpreter":
            fails.append("MISS:program_json_mode")

    # --- replay mode resolution must not invent interpreter ---
    from .campaign import _resolve_saved_mode

    with tempfile.TemporaryDirectory() as td:
        d = Path(td) / "default"
        d.mkdir()
        (d / "program.json").write_text(json.dumps({"mode": "default"}), encoding="utf-8")
        if _resolve_saved_mode(d) != "default":
            fails.append("MISS:replay_mode_default")
        d2 = Path(td) / "forced_ast"
        d2.mkdir()
        (d2 / "ir.json").write_text("{}", encoding="utf-8")
        # directory name fallback
        if _resolve_saved_mode(d2) != "forced_ast":
            fails.append("MISS:replay_mode_dirname")

    # reproducibility + honest distinctness (no salt)
    a = generate_batch(99, 100)
    b = generate_batch(99, 100)
    if [p.case_id for p in a] != [p.case_id for p in b]:
        # case_ids may differ if generate_batch skips collisions with different index walks —
        # require same fingerprints sequence instead.
        if [structural_fingerprint(p) for p in a] != [structural_fingerprint(p) for p in b]:
            fails.append("MISS:reproducible_batch")
    fps = {structural_fingerprint(p) for p in a}
    shapes = {shape_fingerprint(p) for p in a}
    if len(fps) != 100:
        fails.append(f"MISS:distinct_full only {len(fps)}/100")
    # Shapes must show real structural variety — salt-only uniqueness is forbidden.
    if len(shapes) < 8:
        fails.append(f"MISS:distinct_shapes only {len(shapes)} (need structural families)")
    # No Observe named salt
    if any(
        isinstance(st, Observe) and st.name == "salt"
        for p in a
        for st in p.main
    ):
        fails.append("MISS:salt_observe_still_present")

    # Emitter must not hardcode type=Integer in the Print template.
    from .emitter import emit_program

    src = emit_program(prog)
    if 'type=Integer value="' in src:
        fails.append("MISS:hardcoded_type_in_emitter")
    if "TypeName(_sem_obs)" not in src:
        fails.append("MISS:runtime_typename_missing")

    # reducer shrinks synthetic failing case
    fat = generate_case(7, 3)
    if sum(1 for s in fat.main if isinstance(s, Observe)) < 2:
        fat.main.append(Observe("extra", Lit(value=1)))

    def still_fails(p: Program) -> bool:
        return sum(1 for s in p.main if isinstance(s, Observe)) >= 2

    red = reduce_failure(fat, still_fails=still_fails, max_attempts=30, time_limit_secs=5)
    if not red.shrunk:
        trivial = Program(
            case_id="reduce_seed",
            seed=0,
            index=0,
            family="arith_lit_left",
            main=[
                Assign("x", Lit(value=1)),
                Observe("a", Lit(value=1)),
                Observe("b", Lit(value=2)),
            ],
        )
        red = reduce_failure(trivial, still_fails=still_fails, max_attempts=20)
    if not red.shrunk:
        fails.append("MISS:reducer_shrink")
    elif sum(1 for s in red.minimized.main if isinstance(s, Observe)) < 2:
        fails.append("MISS:reducer_broke_failure_identity")

    # IR roundtrip
    text = dumps_program(prog)
    prog2 = loads_program(text)
    if dumps_program(prog2) != text:
        fails.append("MISS:ir_roundtrip")

    # --- Exact failure identity for reduction (end-to-end negative proofs) ---
    from .identity import make_reduce_predicate, preserves_failure_identity
    import tools.semantic_fuzz.identity as identity_mod

    orig = generate_case(42, 0)
    orig.path_target = "SemMain"
    orig.required_path = {"interpreter": "bytecode", "forced_ast": "ast"}
    cand = copy.deepcopy(orig)
    expected_obs = [o.to_dict() for o in evaluate_program(cand).observations]
    if not expected_obs:
        fails.append("MISS:identity_expected_empty")
        return fails

    # wrong-value → wrong-type must be rejected
    wrong_type_obs = copy.deepcopy(expected_obs)
    wrong_type_obs[0]["type"] = "Double"
    rr_wt = RunResult(
        ok=True,
        observations=wrong_type_obs,
        path_counts={"SemMain": {"bytecode": 1}},
        path_events=[{"path": "bytecode", "fn": "SemMain"}],
        mode="interpreter",
    )
    idchk = preserves_failure_identity(
        original=orig,
        candidate=cand,
        mode="interpreter",
        failure_code="wrong_value",
        rr=rr_wt,
        expected=expected_obs,
    )
    if idchk.ok:
        fails.append("MISS:wrong_value_to_wrong_type_accepted")

    # Same class wrong_value with intact bytecode path is accepted
    wrong_val_obs = copy.deepcopy(expected_obs)
    wrong_val_obs[0]["value"] = str(int(wrong_val_obs[0]["value"]) + 99)
    rr_wv = RunResult(
        ok=True,
        observations=wrong_val_obs,
        path_counts={"SemMain": {"bytecode": 1}},
        path_events=[{"path": "bytecode", "fn": "SemMain"}],
        mode="interpreter",
    )
    idchk = preserves_failure_identity(
        original=orig,
        candidate=cand,
        mode="interpreter",
        failure_code="wrong_value",
        rr=rr_wv,
        expected=expected_obs,
    )
    if not idchk.ok:
        fails.append(f"MISS:exact_wrong_value_rejected:{idchk.reason}")

    # native/bytecode → unintended AST fallback rejected for wrong_value identity
    rr_ast_fb = RunResult(
        ok=True,
        observations=wrong_val_obs,
        path_counts={"SemMain": {"ast": 1}},
        path_events=[{"path": "ast", "fn": "SemMain"}],
        mode="interpreter",
    )
    idchk = preserves_failure_identity(
        original=orig,
        candidate=cand,
        mode="interpreter",
        failure_code="wrong_value",
        rr=rr_ast_fb,
        expected=expected_obs,
    )
    if idchk.ok:
        fails.append("MISS:ast_fallback_identity_accepted")

    # Native-required original: bytecode-only (no native) rejected
    warm_orig = gen_module_local_warmup(Random(2), 2, 0)
    warm_cand = copy.deepcopy(warm_orig)
    warm_exp = [o.to_dict() for o in evaluate_program(warm_cand).observations]
    warm_wrong = copy.deepcopy(warm_exp)
    if warm_wrong:
        warm_wrong[0]["value"] = str(int(warm_wrong[0]["value"]) + 1)
    rr_bc_fb = RunResult(
        ok=True,
        observations=warm_wrong,
        path_counts={"KernelNative": {"bytecode": 4}},
        path_events=[{"path": "bytecode", "fn": "KernelNative"}],
        mode="default",
    )
    idchk = preserves_failure_identity(
        original=warm_orig,
        candidate=warm_cand,
        mode="default",
        failure_code="wrong_value",
        rr=rr_bc_fb,
        expected=warm_exp,
    )
    if idchk.ok:
        fails.append("MISS:native_to_bytecode_fallback_identity_accepted")

    # make_reduce_predicate end-to-end: patched runner returns wrong_type → pred False
    with tempfile.TemporaryDirectory() as td:
        def fake_run(p, **kwargs):
            obs = [o.to_dict() for o in evaluate_program(p).observations]
            if obs:
                obs = copy.deepcopy(obs)
                obs[0]["type"] = "Double"
            return RunResult(
                ok=True,
                observations=obs,
                path_counts={"SemMain": {"bytecode": 1}},
                path_events=[{"path": "bytecode", "fn": "SemMain"}],
                mode="interpreter",
            )

        real_run = identity_mod.run_program
        identity_mod.run_program = fake_run  # type: ignore
        try:
            pred = make_reduce_predicate(
                original=orig,
                mode="interpreter",
                failure_code="wrong_value",
                work_root=Path(td),
                timeout_secs=5,
            )
            if pred(cand):
                fails.append("MISS:reduce_pred_accepts_wrong_type")
            # AST fallback under patched runner
            def fake_run_ast(p, **kwargs):
                obs = [o.to_dict() for o in evaluate_program(p).observations]
                if obs:
                    obs = copy.deepcopy(obs)
                    obs[0]["value"] = str(int(obs[0]["value"]) + 1)
                return RunResult(
                    ok=True,
                    observations=obs,
                    path_counts={"SemMain": {"ast": 1}},
                    path_events=[{"path": "ast", "fn": "SemMain"}],
                    mode="interpreter",
                )

            identity_mod.run_program = fake_run_ast  # type: ignore
            pred2 = make_reduce_predicate(
                original=orig,
                mode="interpreter",
                failure_code="wrong_value",
                work_root=Path(td),
                timeout_secs=5,
            )
            if pred2(cand):
                fails.append("MISS:reduce_pred_accepts_ast_fallback")

            # Mixed native_t2+AST under default must fail identity via predicate
            warm_p = gen_module_local_warmup(Random(9), 9, 0)
            warm_c = copy.deepcopy(warm_p)
            warm_e = [o.to_dict() for o in evaluate_program(warm_c).observations]

            def fake_run_native_t2_ast(p, **kwargs):
                obs = copy.deepcopy([o.to_dict() for o in evaluate_program(p).observations])
                if obs:
                    obs[0]["value"] = str(int(obs[0]["value"]) + 1)
                return RunResult(
                    ok=True,
                    observations=obs,
                    path_counts={"KernelNative": {"native_t2": 2, "ast": 1}},
                    path_events=[
                        {"path": "native_t2", "fn": "KernelNative"},
                        {"path": "ast", "fn": "KernelNative"},
                    ],
                    mode="default",
                )

            identity_mod.run_program = fake_run_native_t2_ast  # type: ignore
            pred_t2 = make_reduce_predicate(
                original=warm_p,
                mode="default",
                failure_code="wrong_value",
                work_root=Path(td),
                timeout_secs=5,
            )
            if pred_t2(warm_c):
                fails.append("MISS:reduce_pred_accepts_native_t2_ast_mix")

            # Mixed native_t3+AST under tier3 (native_t3_or_native_t2) via predicate
            def fake_run_native_t3_ast(p, **kwargs):
                obs = copy.deepcopy([o.to_dict() for o in evaluate_program(p).observations])
                if obs:
                    obs[0]["value"] = str(int(obs[0]["value"]) + 1)
                return RunResult(
                    ok=True,
                    observations=obs,
                    path_counts={"KernelNative": {"native_t3": 2, "ast": 1}},
                    path_events=[
                        {"path": "native_t3", "fn": "KernelNative"},
                        {"path": "ast", "fn": "KernelNative"},
                    ],
                    mode="tier3",
                )

            identity_mod.run_program = fake_run_native_t3_ast  # type: ignore
            pred_t3 = make_reduce_predicate(
                original=warm_p,
                mode="tier3",
                failure_code="wrong_value",
                work_root=Path(td),
                timeout_secs=5,
            )
            if pred_t3(warm_c):
                fails.append("MISS:reduce_pred_accepts_native_t3_or_ast_mix")

            # Warmup bytecode + native (no AST) with wrong_value must still preserve
            def fake_run_warmup_native(p, **kwargs):
                obs = copy.deepcopy([o.to_dict() for o in evaluate_program(p).observations])
                if obs:
                    obs[0]["value"] = str(int(obs[0]["value"]) + 1)
                return RunResult(
                    ok=True,
                    observations=obs,
                    path_counts={"KernelNative": {"bytecode": 3, "native_t2": 2}},
                    path_events=[
                        {"path": "bytecode", "fn": "KernelNative"},
                        {"path": "native_t2", "fn": "KernelNative"},
                    ],
                    mode="default",
                )

            identity_mod.run_program = fake_run_warmup_native  # type: ignore
            pred_ok = make_reduce_predicate(
                original=warm_p,
                mode="default",
                failure_code="wrong_value",
                work_root=Path(td),
                timeout_secs=5,
            )
            if not pred_ok(warm_c):
                fails.append("MISS:reduce_pred_rejects_warmup_then_native")
        finally:
            identity_mod.run_program = real_run

    return fails
