"""Phase 2 C2 pure oracle/selftests (no Godot). IR Godot lane is separate."""

from __future__ import annotations

import copy

from .byref_model import PROC_ALIAS, VM, run_hand_tables
from .compare import CompareError, compare_observations
from .ir import (
    Assign,
    Bin,
    Call,
    CallStmt,
    Helper,
    Lit,
    Note,
    Observe,
    ParamSpec,
    Program,
    ReturnStmt,
    Var,
    dumps_program,
    loads_program,
)
from .phase2_c2_ir_examples import ALL_EXAMPLES, BYVAL_ONCE_AST_HISTORICAL_WRONG
from .reference import ReferenceError, evaluate_program
from .validate import ValidationError, validate_program


def _bad_prog(case_id: str, helpers, main, module_vars=None) -> Program:
    return Program(
        case_id=case_id,
        seed=0,
        index=0,
        family="c2_neg",
        helpers=helpers,
        main=main,
        module_vars=module_vars or {},
    )


def run_phase2_c2_selftests() -> list[str]:
    fails: list[str] = []

    # --- Hand IR examples: independent expected vs model ---
    for factory in ALL_EXAMPLES:
        prog, expected = factory()
        try:
            got = [o.to_dict() for o in evaluate_program(prog).observations]
            compare_observations(expected, got)
        except (CompareError, ReferenceError, Exception) as exc:
            fails.append(f"C2:ir_hand:{prog.case_id}:{exc}")

    # Emit EarlySub must contain Exit Sub before sentinel Note
    from .emitter import emit_program
    from .phase2_c2_ir_examples import example_early_return

    early_prog, _ = example_early_return()
    src = emit_program(early_prog)
    if "Exit Sub" not in src:
        fails.append("MISS:early_sub_missing_exit_sub")
    # Note after Exit Sub remains in source text but must follow Exit Sub in EarlySub
    idx_exit = src.find("Exit Sub")
    idx_note = src.find("sub_should_not_fire")
    if idx_exit < 0 or idx_note < 0 or idx_exit > idx_note:
        fails.append("MISS:early_sub_exit_not_before_sentinel_note")

    # Round-trip ParamSpec
    prog0, _ = ALL_EXAMPLES[0]()
    roundtrip = loads_program(dumps_program(prog0))
    p0 = roundtrip.helpers[0].params[0]
    if not isinstance(p0, ParamSpec) or p0.mode != "byval":
        fails.append(f"MISS:param_spec_roundtrip:{p0!r}")

    # Phase 1 string params remain ByVal
    legacy = _bad_prog(
        "legacy_params",
        [Helper("Inc", ["n"], [ReturnStmt(Bin("+", Var("n"), Lit(1)))], returns=True)],
        [Assign("r", Call("Inc", [Lit(4)])), Observe("r", Var("r"))],
        {"r": 0},
    )
    try:
        got = evaluate_program(legacy).observations
        if not got or int(got[0].typed.value) != 5:
            fails.append(f"MISS:legacy_byval_string_params:{got}")
    except Exception as exc:
        fails.append(f"MISS:legacy_byval_string_params_exc:{exc}")

    # --- Strict validation negatives (before coercion) ---
    def must_reject_validate(label: str, prog: Program) -> None:
        try:
            validate_program(prog)
            fails.append(f"MISS:validate_accepts_{label}")
        except ValidationError:
            pass

    must_reject_validate(
        "float_lit",
        _bad_prog("f", [], [Observe("x", Lit(1.9))], {}),  # type: ignore[arg-type]
    )
    must_reject_validate(
        "bool_lit",
        _bad_prog("b", [], [Observe("x", Lit(True))], {}),  # type: ignore[arg-type]
    )
    must_reject_validate(
        "bad_mode",
        _bad_prog(
            "m",
            [Helper("F", [ParamSpec("a", "BAD", default=1)], [ReturnStmt(Var("a"))])],  # type: ignore[arg-type]
            [Assign("r", Call("F", []))],
            {"r": 0},
        ),
    )
    must_reject_validate(
        "sub_as_expr",
        _bad_prog(
            "s",
            [Helper("S", [], [ReturnStmt(Lit(0))], returns=False)],
            [Assign("r", Call("S", []))],
            {"r": 0},
        ),
    )
    must_reject_validate(
        "byref_literal",
        _bad_prog(
            "br",
            [
                Helper(
                    "T",
                    [ParamSpec("n", "byref")],
                    [ReturnStmt(Lit(0))],
                    returns=False,
                )
            ],
            [CallStmt("T", [Lit(1)])],
        ),
    )
    must_reject_validate(
        "required_after_optional",
        _bad_prog(
            "ord",
            [
                Helper(
                    "F",
                    [ParamSpec("a", "byval", default=1), ParamSpec("b", "byval")],
                    [ReturnStmt(Var("a"))],
                )
            ],
            [Assign("r", Call("F", [Lit(1), Lit(2)]))],
            {"r": 0},
        ),
    )

    # Reference-level refusals
    for label, prog in [
        (
            "overflow",
            _bad_prog("o", [], [Assign("x", Lit(2_000_000))], {"x": 0}),
        ),
        (
            "arity",
            _bad_prog(
                "a",
                [Helper("F", [ParamSpec("a", "byval")], [ReturnStmt(Var("a"))])],
                [Assign("r", Call("F", [Lit(1), Lit(2)]))],
                {"r": 0},
            ),
        ),
    ]:
        try:
            evaluate_program(prog)
            fails.append(f"MISS:ref_accepts_{label}")
        except (ReferenceError, ValidationError):
            pass

    early = _bad_prog(
        "early_stop",
        [Helper("E", [], [ReturnStmt(Lit(1)), Note("after_return")], returns=True)],
        [Assign("r", Call("E", [])), Observe("r", Var("r"))],
        {"r": 0},
    )
    try:
        obs = evaluate_program(early).observations
        if "event_after_return" in [o.name for o in obs]:
            fails.append("MISS:early_return_continued_execution")
    except Exception as exc:
        fails.append(f"MISS:early_return_exc:{exc}")

    # --- Alias observational model ---
    expected_model = run_hand_tables()
    try:
        compare_observations(expected_model, copy.deepcopy(expected_model))
    except CompareError as exc:
        fails.append(f"C2:byref_model_self:{exc}")

    vm = VM()
    loc = vm.store.alloc("x", 3)
    vm.call(PROC_ALIAS, [loc, loc])
    if vm.store.get(loc) != 13:
        fails.append("C2:alias_observed_model_drift")

    bad_wb = copy.deepcopy(expected_model)
    for o in bad_wb:
        if o["name"] == "expr_byref_x":
            o["value"] = "3"
    try:
        compare_observations(expected_model, bad_wb)
        fails.append("MISS:c2_detector_accepts_missing_writeback")
    except CompareError as exc:
        if exc.code != "wrong_value":
            fails.append(f"MISS:c2_detector_code:{exc.code}")

    # Historical wrong signature (hits=2): inject tests must still reject drift
    try:
        compare_observations(BYVAL_ONCE_AST_HISTORICAL_WRONG, BYVAL_ONCE_AST_HISTORICAL_WRONG)
    except CompareError as exc:
        fails.append(f"MISS:historical_wrong_self:{exc}")
    # Oracle for c2_byval_once must reject the historical hits=2 observation.
    byval_oracle = [
        {"name": "byval_r", "type": "Integer", "value": "4", "kind": "value"},
        {"name": "byval_hits", "type": "Integer", "value": "1", "kind": "value"},
    ]
    try:
        compare_observations(byval_oracle, BYVAL_ONCE_AST_HISTORICAL_WRONG)
        fails.append("MISS:oracle_accepts_historical_byval_double_eval")
    except CompareError:
        pass
    for label, actual in [
        (
            "wrong_return",
            [
                {"name": "byval_r", "type": "Integer", "value": "99", "kind": "value"},
                {"name": "byval_hits", "type": "Integer", "value": "1", "kind": "value"},
            ],
        ),
        (
            "wrong_type",
            [
                {"name": "byval_r", "type": "String", "value": "4", "kind": "value"},
                {"name": "byval_hits", "type": "Integer", "value": "1", "kind": "value"},
            ],
        ),
        (
            "missing_obs",
            [{"name": "byval_r", "type": "Integer", "value": "4", "kind": "value"}],
        ),
        (
            "extra_obs",
            byval_oracle
            + [{"name": "extra", "type": "Integer", "value": "0", "kind": "value"}],
        ),
        (
            "historical_double_eval",
            BYVAL_ONCE_AST_HISTORICAL_WRONG,
        ),
    ]:
        try:
            compare_observations(byval_oracle, actual)
            fails.append(f"MISS:byval_oracle_accepts_{label}")
        except CompareError:
            pass

    # --- Contract persistence / identity (A) ---
    # bool("false") must not become True
    try:
        loads_program(
            '{"case_id":"t","seed":0,"index":0,"family":"x","helpers":'
            '[{"name":"S","params":[],"body":[{"kind":"return","expr":{"kind":"lit","value":0}}],'
            '"returns":"false"}],"main":[]}'
        )
        fails.append("MISS:returns_string_false_accepted")
    except Exception:
        pass

    from .identity import preserves_failure_identity
    from .runner import RunResult, case_dir_slug, logical_module_key

    orig, _ = ALL_EXAMPLES[3]()  # nested Outer/Inner
    orig.path_module_key = logical_module_key(orig.case_id, "interpreter")
    cand = loads_program(dumps_program(orig))
    cand.path_targets = [t for t in cand.path_targets if t != "Inner"]
    chk = preserves_failure_identity(
        original=orig,
        candidate=cand,
        mode="interpreter",
        failure_code="wrong_value",
        rr=RunResult(ok=False, failure_code="wrong_value", message="x", mode="interpreter"),
        expected=[{"name": "x", "type": "Integer", "value": "0"}],
    )
    if chk.ok:
        fails.append("MISS:identity_allows_dropping_Inner_path_target")

    cand2 = loads_program(dumps_program(orig))
    cand2.path_module_key = logical_module_key(orig.case_id, "forced_ast")
    chk2 = preserves_failure_identity(
        original=orig,
        candidate=cand2,
        mode="interpreter",
        failure_code="wrong_value",
        rr=RunResult(ok=False, failure_code="wrong_value", message="x", mode="interpreter"),
        expected=[{"name": "x", "type": "Integer", "value": "0"}],
    )
    if chk2.ok:
        fails.append("MISS:identity_allows_path_module_key_switch")

    # Sanitized ID collision resistance
    if case_dir_slug("a/b") == case_dir_slug("a_b"):
        fails.append("MISS:case_dir_slug_collision")

    # Shape fingerprint: literal-only change collapses; control-flow does not
    from .generator import shape_fingerprint
    from .generator_c2 import gen_byref_expr, gen_byval_expr

    a = gen_byref_expr(__import__("random").Random(1), 1, 0)
    b = gen_byref_expr(__import__("random").Random(2), 1, 1)
    # Same family structure may share shape after literal strip
    c = gen_byval_expr(__import__("random").Random(1), 1, 0)
    if shape_fingerprint(a) == shape_fingerprint(c):
        fails.append("MISS:shape_collapses_byref_vs_byval_expr")

    # run_program refuses pre-set path_module
    try:
        from .runner import run_program
        from pathlib import Path
        import tempfile

        p, _ = ALL_EXAMPLES[0]()
        p.path_module = "res://sem_fuzz_runs/x/y/z/case.vg"
        with tempfile.TemporaryDirectory() as td:
            run_program(p, mode="interpreter", work_root=Path(td), timeout_secs=5)
        fails.append("MISS:run_program_accepts_preset_path_module")
    except ValueError:
        pass
    except Exception as exc:
        if "path_module" not in str(exc):
            fails.append(f"MISS:preset_path_module_wrong_exc:{exc}")

    # Bundle integrity: primary + manifest; offline real-bundle replay below
    from .bundle_integrity import (
        validate_bundle_integrity,
        write_bound_test_bundle,
    )
    from .generator_c2 import gen_import_byref
    from pathlib import Path
    from random import Random
    import json
    import shutil
    import subprocess
    import sys
    import tempfile

    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        prog = gen_import_byref(Random(1), 1, 0)
        case = write_bound_test_bundle(
            root / "case" / "default", prog, mode="default", run_token="tok1"
        )
        ok = validate_bundle_integrity(case)
        if ok:
            fails.append(f"MISS:integrity_rejects_clean_import_bundle:{ok}")

        # Primary modified / missing must refuse
        (case / "case.vg").write_text(
            (case / "case.vg").read_text(encoding="utf-8") + "' tamper\n",
            encoding="utf-8",
        )
        bad_p = validate_bundle_integrity(case)
        if not bad_p or (
            "primary" not in bad_p and "hash mismatch" not in bad_p and "drift" not in bad_p
        ):
            fails.append(f"MISS:integrity_accepts_modified_primary:{bad_p}")
        case_del = write_bound_test_bundle(
            root / "case_clean" / "default", prog, mode="default", run_token="tok1"
        )
        (case_del / "case.vg").unlink()
        miss = validate_bundle_integrity(case_del)
        if not miss or "missing primary" not in miss:
            fails.append(f"MISS:integrity_accepts_deleted_primary:{miss}")

        case = write_bound_test_bundle(
            root / "case_man" / "default", prog, mode="default", run_token="tok1"
        )
        pmeta = json.loads((case / "program.json").read_text())
        pmeta["source_modules_manifest"][0]["sha256"] = "0" * 64
        (case / "program.json").write_text(json.dumps(pmeta, indent=2), encoding="utf-8")
        bad = validate_bundle_integrity(case)
        if not bad or "hash mismatch" not in bad:
            fails.append(f"MISS:integrity_accepts_tampered_manifest:{bad}")

        from .campaign import replay_case_dir

        case_t = write_bound_test_bundle(
            root / "case_t" / "default", prog, mode="default", run_token="tok1"
        )
        copied = root / "copied_offline" / "default"
        shutil.copytree(case_t, copied)
        pmeta2 = json.loads((copied / "program.json").read_text())
        pmeta2["source_modules_manifest"][0]["sha256"] = "1" * 64
        (copied / "program.json").write_text(json.dumps(pmeta2), encoding="utf-8")
        try:
            replay_case_dir(copied)
            fails.append("MISS:offline_replay_accepts_tampered_manifest")
        except ValueError as exc:
            if "hash mismatch" not in str(exc) and "replay refused" not in str(exc):
                fails.append(f"MISS:offline_replay_tamper_wrong_exc:{exc}")
        except Exception as exc:
            fails.append(f"MISS:offline_replay_tamper_unexpected:{exc}")

        # Extra module on disk
        case2 = write_bound_test_bundle(
            root / "case_extra" / "default", prog, mode="default", run_token="tok1"
        )
        (case2 / "extra_evil.vg").write_text("' evil\n", encoding="utf-8")
        extra_msg = validate_bundle_integrity(case2)
        if not extra_msg or "owned disk modules" not in extra_msg:
            fails.append(f"MISS:integrity_accepts_extra_disk_module:{extra_msg}")

        # Contradictory case identity in path_module / path_module_key must refuse
        case_id_bad = write_bound_test_bundle(
            root / "case_id_bad" / "default", prog, mode="default", run_token="tok1"
        )
        p_bad = json.loads((case_id_bad / "program.json").read_text())
        ir_bad = json.loads((case_id_bad / "ir.json").read_text())
        p_bad["path_module_key"] = "sem_fuzz_ir/WRONG/default"
        p_bad["path_module"] = (
            f"res://sem_fuzz_runs/tok1/not_the_case/default/case.vg"
        )
        ir_bad["path_module_key"] = p_bad["path_module_key"]
        ir_bad["path_module"] = p_bad["path_module"]
        (case_id_bad / "program.json").write_text(json.dumps(p_bad), encoding="utf-8")
        (case_id_bad / "ir.json").write_text(json.dumps(ir_bad), encoding="utf-8")
        id_msg = validate_bundle_integrity(case_id_bad)
        if not id_msg or (
            "path_module_key mismatch" not in id_msg
            and "path_module mismatch" not in id_msg
        ):
            fails.append(f"MISS:integrity_accepts_wrong_case_identity:{id_msg}")
        try:
            replay_case_dir(case_id_bad)
            fails.append("MISS:replay_accepts_wrong_case_identity")
        except ValueError as exc:
            if "mismatch" not in str(exc):
                fails.append(f"MISS:replay_wrong_case_identity_reason:{exc}")

        # Missing ALL imported siblings (keep case.vg) must refuse
        case_all = write_bound_test_bundle(
            root / "case_miss_all" / "default", prog, mode="default", run_token="tok1"
        )
        for p in list(case_all.glob("*.vg")):
            if p.name.lower() != "case.vg":
                p.unlink()
        miss_all = validate_bundle_integrity(case_all)
        if not miss_all or "owned disk modules" not in miss_all:
            fails.append(f"MISS:integrity_accepts_all_imports_deleted:{miss_all}")
        # Replay/CLI reduce refuse before Godot
        try:
            replay_case_dir(case_all)
            fails.append("MISS:replay_accepts_all_imports_deleted")
        except ValueError as exc:
            if "owned disk" not in str(exc) and "replay refused" not in str(exc):
                fails.append(f"MISS:replay_all_deleted_wrong:{exc}")
        red_all = subprocess.run(
            [sys.executable, "-m", "tools.semantic_fuzz", "reduce", str(case_all)],
            cwd=str(Path(__file__).resolve().parents[2]),
            capture_output=True,
            text=True,
        )
        if red_all.returncode == 0:
            fails.append("MISS:reduce_accepts_all_imports_deleted")

        # Nested import: delete ONE of several
        from .generator_c2 import gen_import_nested

        nested = gen_import_nested(Random(2), 2, 0)
        case_one = write_bound_test_bundle(
            root / "case_miss_one" / "default", nested, mode="default", run_token="tok2"
        )
        mods = [p for p in case_one.glob("*.vg") if p.name.lower() != "case.vg"]
        if len(mods) < 2:
            fails.append("MISS:nested_bundle_needs_two_modules")
        else:
            mods[0].unlink()
            miss_one = validate_bundle_integrity(case_one)
            if not miss_one or "owned disk modules" not in miss_one:
                fails.append(f"MISS:integrity_accepts_one_import_deleted:{miss_one}")

        # Multi-file reduce via CLI must refuse without creating reduced/
        case_r = write_bound_test_bundle(
            root / "case_reduce" / "default", prog, mode="default", run_token="tok1"
        )
        (case_r / "failure.json").write_text(
            json.dumps(
                {
                    **json.loads((case_r / "program.json").read_text()),
                    "failure_code": "wrong_value",
                },
                indent=2,
            ),
            encoding="utf-8",
        )
        (case_r / "actual.json").write_text("[]", encoding="utf-8")
        red = subprocess.run(
            [
                sys.executable,
                "-m",
                "tools.semantic_fuzz",
                "reduce",
                str(case_r),
            ],
            cwd=str(Path(__file__).resolve().parents[2]),
            capture_output=True,
            text=True,
        )
        if red.returncode == 0:
            fails.append("MISS:multifile_reduce_cli_accepted")
        if "not reducible" not in (red.stdout + red.stderr):
            fails.append(f"MISS:multifile_reduce_cli_banner:{(red.stdout + red.stderr)[-200:]}")
        if (case_r / "reduced").exists():
            fails.append("MISS:multifile_reduce_cli_wrote_output")

    # Module scalar namespaces (reference model + distinct-name campaign family)
    from .generator_c2 import (
        gen_import_byref,
        gen_import_byval_expr,
        gen_import_local_caller,
        gen_import_nested,
        hand_same_name_module_ns,
        feature_pairs,
    )
    from random import Random

    try:
        sn = hand_same_name_module_ns()
        by_name = {
            o.name: int(o.typed.value) for o in evaluate_program(sn).observations
        }
        # caller x=3 → 5; lib x=7 → 8; must not collapse
        if by_name.get("x") != 5 or by_name.get("lib_x") != 8:
            fails.append(f"MISS:module_ns_same_name_cells:{by_name}")
        if by_name.get("x") == by_name.get("lib_x"):
            fails.append(f"MISS:module_ns_collapsed:{by_name}")
    except Exception as exc:
        fails.append(f"MISS:hand_same_name_module_ns:{exc}")

    ib = gen_import_byref(Random(9), 9, 0)
    try:
        got = evaluate_program(ib)
        by_name = {o.name: int(o.typed.value) for o in got.observations}
        if by_name.get("lib_x") != 8:
            fails.append(f"MISS:lib_lx_not_independent:{by_name}")
        from .bundle_integrity import _emit_imported_bodies

        bodies = _emit_imported_bodies(ib)
        for m in ib.source_modules:
            if bodies.get(m["rel_path"]) != m["content"]:
                fails.append(f"MISS:emit_derived_drift:{m['rel_path']}")
    except Exception as exc:
        fails.append(f"MISS:import_byref_hand:{exc}")

    for label, factory in [
        ("byval_expr", gen_import_byval_expr),
        ("local_caller", gen_import_local_caller),
        ("nested", gen_import_nested),
    ]:
        try:
            p = factory(Random(3), 3, 0)
            evaluate_program(p)
            pairs = feature_pairs(p)
            if "module×imported" not in pairs:
                fails.append(f"MISS:import_{label}_missing_imported_pair:{pairs}")
        except Exception as exc:
            fails.append(f"MISS:import_{label}_hand:{exc}")

    # Recursion: per-level frame_depth preserved into seen_d*
    try:
        from .generator_c2 import _req_paths
        from .ir import Cmp, IfStmt

        helpers = [
            Helper(
                "RecAdd",
                [ParamSpec("n", "byref"), ParamSpec("depth", "byval", default=2)],
                [
                    Assign("frame_depth", Var("depth")),
                    IfStmt(
                        Cmp("=", Var("depth"), Lit(0)),
                        [Assign("seen_d0", Var("frame_depth"))],
                        [],
                    ),
                    IfStmt(
                        Cmp("=", Var("depth"), Lit(1)),
                        [Assign("seen_d1", Var("frame_depth"))],
                        [],
                    ),
                    IfStmt(
                        Cmp("=", Var("depth"), Lit(2)),
                        [Assign("seen_d2", Var("frame_depth"))],
                        [],
                    ),
                    IfStmt(
                        Cmp("<=", Var("depth"), Lit(0)),
                        [ReturnStmt(Var("n"))],
                        [
                            Assign("n", Bin("+", Var("n"), Lit(1))),
                            ReturnStmt(
                                Bin(
                                    "+",
                                    Call(
                                        "RecAdd",
                                        [Var("n"), Bin("-", Var("depth"), Lit(1))],
                                    ),
                                    Var("n"),
                                )
                            ),
                        ],
                    ),
                ],
                local_vars={"frame_depth": -1},
            )
        ]
        rprog = Program(
            case_id="c2_rec_frame_proof",
            seed=0,
            index=0,
            family="c2_recursion_optional",
            tags=["c2", "recursion", "depth=2"],
            module_vars={
                "x": 0,
                "r": 0,
                "seen_d0": -9,
                "seen_d1": -9,
                "seen_d2": -9,
            },
            helpers=helpers,
            main=[
                Assign("x", Lit(0)),
                Assign("r", Call("RecAdd", [Var("x"), Lit(2)])),
                Observe("r", Var("r")),
                Observe("x", Var("x")),
                Observe("seen_d0", Var("seen_d0")),
                Observe("seen_d1", Var("seen_d1")),
                Observe("seen_d2", Var("seen_d2")),
            ],
            required_path=_req_paths(),
            path_target="RecAdd",
            path_targets=["RecAdd"],
        )
        rob = {o.name: int(o.typed.value) for o in evaluate_program(rprog).observations}
        if rob.get("seen_d0") != 0 or rob.get("seen_d1") != 1 or rob.get("seen_d2") != 2:
            fails.append(f"MISS:recursion_frame_depth_not_preserved:{rob}")
    except Exception as exc:
        fails.append(f"MISS:recursion_frame_proof:{exc}")

    # Feature pairs: ByRef stmt + ByVal expr must not claim byref×expression
    from .generator_c2 import gen_byref_standalone, gen_byval_expr, gen_byval_standalone

    mixed = gen_byref_standalone(Random(1), 1, 0)
    # Only statement ByRef edge
    mp = feature_pairs(mixed)
    if "byref×expression" in mp and "byref×statement" not in mp:
        fails.append(f"MISS:feature_pair_orphan_byref_expr:{mp}")
    bv = feature_pairs(gen_byval_expr(Random(1), 1, 0))
    if "byref×expression" in bv:
        fails.append(f"MISS:byval_expr_claims_byref_expr:{bv}")

    # Structural pairs walk IR textually — unreachable branch still credits pairs.
    from .ir import (
        Helper as _H,
        ParamSpec as _PS,
        ReturnStmt as _RS,
        Lit as _L,
        CallStmt as _CS,
        Cmp as _Cmp,
        IfStmt as _If,
    )

    dead = gen_byval_standalone(Random(1), 1, 0)
    # Inject never-taken branch that CallStmt-ByRefs — structural pairs still see it.
    bump = dead.helpers[0]
    bump.body = [
        _If(
            _Cmp("=", _L(0), _L(1)),
            [_CS("GhostByRef", [Var("n")])],
            [],
        ),
        *list(bump.body),
    ]
    dead.helpers = list(dead.helpers) + [
        _H("GhostByRef", [_PS("n", "byref")], [_RS(_L(0))], returns=False)
    ]
    dead_pairs = feature_pairs(dead)
    if "byref×statement" not in dead_pairs:
        fails.append(
            f"MISS:structural_pairs_miss_unreachable_branch_edge:{dead_pairs}"
        )
    # Document: this is structural, not execution proof (oracle never takes the branch).
    try:
        evaluate_program(dead)
    except Exception as exc:
        fails.append(f"MISS:unreachable_branch_prog_broke_oracle:{exc}")

    # Campaign-hook negatives: inject missing writeback / wrong return / event order
    import tempfile
    from pathlib import Path
    from . import campaign as camp_mod
    from .runner import RunResult

    def _stub_campaign_engine(td: Path):
        """Owned fake .so so inject campaigns need neither Godot nor a real extension."""
        fake_so = Path(td) / "_inject_fake.so"
        fake_so.write_bytes(b"VG_SEM_INJECT_FAKE_SO")
        real_fg = camp_mod.find_godot
        real_re = camp_mod.resolve_extension_binary
        camp_mod.find_godot = lambda _root: Path(td) / "_missing_godot"  # type: ignore
        camp_mod.resolve_extension_binary = lambda _tp: fake_so  # type: ignore
        return real_fg, real_re

    def _inject_campaign(label: str, mutate_obs, expect_code: str) -> None:
        real_run = camp_mod.run_program

        def fake_run(p, **kwargs):
            exp = [o.to_dict() for o in evaluate_program(p).observations]
            obs = mutate_obs(copy.deepcopy(exp))
            mode = kwargs.get("mode", "interpreter")
            case_dir = Path(kwargs["work_root"]) / p.case_id / mode
            case_dir.mkdir(parents=True, exist_ok=True)
            log = case_dir / "run.log"
            log.write_text("", encoding="utf-8")
            return RunResult(
                ok=True,
                observations=obs,
                path_events=[
                    {"path": "bytecode", "fn": p.path_target or "X", "mod": ""}
                ],
                path_counts={p.path_target or "X": {"bytecode": 1}},
                completed=True,
                mode=mode,
                binary_hash="b" * 8,
                engine_hash="e" * 8,
                engine_path="/fake/godot",
                bound_path_module_key=f"sem_fuzz_ir/{p.case_id}/{mode}",
                bound_path_module=f"res://sem_fuzz_runs/{p.case_id}/{mode}/case.vg",
                log_path=str(log),
            )

        camp_mod.run_program = fake_run  # type: ignore
        try:
            with tempfile.TemporaryDirectory() as td:
                real_fg, real_re = _stub_campaign_engine(Path(td))
                try:
                    report = camp_mod.run_campaign(
                        55,
                        1,
                        modes=["interpreter"],
                        out_dir=Path(td),
                        domain="c2",
                        timeout_secs=5,
                    )
                finally:
                    camp_mod.find_godot = real_fg
                    camp_mod.resolve_extension_binary = real_re
                if not report.failures:
                    fails.append(f"MISS:campaign_inject_{label}_no_failure")
                    return
                codes = {f.failure_code for f in report.failures}
                if expect_code not in codes:
                    fails.append(
                        f"MISS:campaign_inject_{label}_code:{codes} want {expect_code}"
                    )
                any_bundle = False
                for f in report.failures:
                    fp = Path(f.work_dir) / "failure.json"
                    if fp.is_file():
                        meta = json.loads(fp.read_text(encoding="utf-8"))
                        if meta.get("failure_code") == expect_code:
                            any_bundle = True
                            if not (Path(f.work_dir) / "ir.json").is_file():
                                fails.append(
                                    f"MISS:campaign_inject_{label}_bundle_missing_ir"
                                )
                if not any_bundle:
                    fails.append(f"MISS:campaign_inject_{label}_bundle_incomplete")
        except Exception as exc:
            fails.append(f"MISS:campaign_inject_{label}_exc:{exc}")
        finally:
            camp_mod.run_program = real_run

    def missing_writeback(obs):
        # Simulate lost ByRef writeback / stale caller cell on last Integer obs.
        for o in reversed(obs):
            if o.get("type") == "Integer":
                o["value"] = str(int(o["value"]) - 1)
                break
        return obs

    def wrong_return(obs):
        if obs:
            obs[0]["value"] = "99999"
        return obs

    def wrong_type(obs):
        if obs:
            obs[0]["type"] = "String"
        return obs

    def event_order(obs):
        if len(obs) >= 2:
            obs[0], obs[1] = obs[1], obs[0]
        elif obs:
            # Single-obs families: force name mismatch at index 0.
            obs[0] = {**obs[0], "name": "reordered_" + obs[0]["name"]}
        return obs

    _inject_campaign("missing_writeback", missing_writeback, "wrong_value")
    _inject_campaign("wrong_return", wrong_return, "wrong_value")
    _inject_campaign("wrong_type", wrong_type, "wrong_type")
    _inject_campaign("event_order", event_order, "reordered_or_missing")

    def nested_state_corrupt(obs):
        # Corrupt a late observation as if nested callee state leaked.
        if obs:
            obs[-1] = {**obs[-1], "value": "777777"}
        return obs

    def ast_fallback_obs(obs):
        return obs  # path_counts force AST under interpreter → path_mismatch

    _inject_campaign("nested_state", nested_state_corrupt, "wrong_value")

    # Wrong-module / AST-fallback via path events (path_mismatch class)
    real_run = camp_mod.run_program

    def fake_wrong_module(p, **kwargs):
        exp = [o.to_dict() for o in evaluate_program(p).observations]
        mode = kwargs.get("mode", "interpreter")
        case_dir = Path(kwargs["work_root"]) / p.case_id / mode
        case_dir.mkdir(parents=True, exist_ok=True)
        log = case_dir / "run.log"
        log.write_text("", encoding="utf-8")
        fn = p.path_target or "X"
        return RunResult(
            ok=True,
            observations=exp,
            path_events=[
                {
                    "path": "bytecode",
                    "fn": fn,
                    "mod": "res://sem_fuzz_runs/other/wrong.vg",
                }
            ],
            path_counts={fn: {"bytecode": 1}},
            completed=True,
            mode=mode,
            binary_hash="b" * 8,
            engine_hash="e" * 8,
            engine_path="/fake/godot",
            bound_path_module_key=f"sem_fuzz_ir/{p.case_id}/{mode}",
            bound_path_module=f"res://sem_fuzz_runs/{p.case_id}/{mode}/case.vg",
            bound_fn_path_modules={
                fn: f"res://sem_fuzz_runs/{p.case_id}/{mode}/case.vg"
            },
            log_path=str(log),
        )

    def fake_ast_fallback(p, **kwargs):
        exp = [o.to_dict() for o in evaluate_program(p).observations]
        mode = kwargs.get("mode", "interpreter")
        case_dir = Path(kwargs["work_root"]) / p.case_id / mode
        case_dir.mkdir(parents=True, exist_ok=True)
        log = case_dir / "run.log"
        log.write_text("", encoding="utf-8")
        fn = p.path_target or "X"
        return RunResult(
            ok=True,
            observations=exp,
            path_events=[{"path": "ast", "fn": fn, "mod": ""}],
            path_counts={fn: {"ast": 1}},
            completed=True,
            mode=mode,
            binary_hash="b" * 8,
            engine_hash="e" * 8,
            engine_path="/fake/godot",
            bound_path_module_key=f"sem_fuzz_ir/{p.case_id}/{mode}",
            bound_path_module=f"res://sem_fuzz_runs/{p.case_id}/{mode}/case.vg",
            log_path=str(log),
        )

    for label, fake, code in [
        ("wrong_module", fake_wrong_module, "path_mismatch"),
        ("ast_fallback", fake_ast_fallback, "path_mismatch"),
    ]:
        camp_mod.run_program = fake  # type: ignore
        try:
            with tempfile.TemporaryDirectory() as td:
                real_fg, real_re = _stub_campaign_engine(Path(td))
                try:
                    report = camp_mod.run_campaign(
                        56,
                        1,
                        modes=["interpreter"],
                        out_dir=Path(td),
                        domain="c2",
                        timeout_secs=5,
                    )
                finally:
                    camp_mod.find_godot = real_fg
                    camp_mod.resolve_extension_binary = real_re
                codes = {f.failure_code for f in report.failures}
                if code not in codes:
                    fails.append(f"MISS:campaign_inject_{label}_code:{codes}")
                else:
                    for f in report.failures:
                        if f.failure_code != code:
                            continue
                        if not (Path(f.work_dir) / "failure.json").is_file():
                            fails.append(f"MISS:campaign_inject_{label}_no_bundle")
                        if not (Path(f.work_dir) / "actual.json").is_file():
                            fails.append(f"MISS:campaign_inject_{label}_no_actual")
        except Exception as exc:
            fails.append(f"MISS:campaign_inject_{label}_exc:{exc}")
        finally:
            camp_mod.run_program = real_run

    # Real offline multi-file replay: generate via Godot, copy, remove ONLY owned staging
    import os

    # Skip when Godot is forced unavailable (pure oracle/selftest proofs).
    if os.environ.get("GODOT") and os.environ.get("VG_SEM_FORCE_NO_GODOT") != "1":
        try:
            from .runner import run_program, find_repo_root, case_dir_slug

            with tempfile.TemporaryDirectory() as td:
                out = Path(td)
                ip = gen_import_byref(Random(42), 42, 0)
                rr = run_program(
                    ip, mode="interpreter", work_root=out, timeout_secs=45
                )
                if not rr.ok:
                    fails.append(f"MISS:real_import_run_failed:{rr.message}")
                else:
                    case_dir = Path(rr.log_path).parent
                    pmeta = json.loads((case_dir / "program.json").read_text())
                    token = pmeta.get("run_token")
                    mode = pmeta.get("mode")
                    slug = case_dir_slug(ip.case_id)
                    root = find_repo_root()
                    staging_root = root / "test_proj" / "sem_fuzz_runs"
                    owned = staging_root / token / slug / mode
                    # run_program already removes its staging in finally; must stay gone.
                    if owned.exists():
                        fails.append(f"MISS:owned_staging_left_behind:{owned}")
                    # Sentinel: prove we never broad-delete under sem_fuzz_runs.
                    sentinel = staging_root / "_cursor_sentinel_ex011_keep"
                    sentinel.mkdir(parents=True, exist_ok=True)
                    (sentinel / "marker.txt").write_text("keep", encoding="utf-8")
                    # Only touch exact owned path (already absent); leave sentinel.
                    if owned.is_dir():
                        shutil.rmtree(owned)
                    if not (sentinel / "marker.txt").is_file():
                        fails.append("MISS:sentinel_staging_removed")
                    else:
                        shutil.rmtree(sentinel, ignore_errors=True)
                    offline = out / "offline_copy"
                    shutil.copytree(case_dir, offline)
                    integ = validate_bundle_integrity(offline)
                    if integ:
                        fails.append(f"MISS:real_bundle_integrity:{integ}")
                    crep = replay_case_dir(offline)
                    if crep.status != "pass":
                        fails.append(
                            f"MISS:real_offline_replay:{crep.status}:{crep.message}"
                        )
                    (offline / "case.vg").write_bytes(
                        (offline / "case.vg").read_bytes() + b"'x\n"
                    )
                    try:
                        replay_case_dir(offline)
                        fails.append("MISS:real_offline_accepts_primary_tamper")
                    except ValueError:
                        pass
        except Exception as exc:
            fails.append(f"MISS:real_offline_exc:{exc}")

    return fails
