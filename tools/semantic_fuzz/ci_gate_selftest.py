"""Prove semantic CI gate failure propagation (fake runners / corrupted output)."""

from __future__ import annotations

import copy
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


def run_ci_gate_selftests() -> list[str]:
    fails: list[str] = []
    root = Path(__file__).resolve().parents[2]

    # --- self-test failure stops the gate entrypoint ---
    # Patch harness only; skip nested CI probes via env to avoid recursion.
    probe = subprocess.run(
        [
            sys.executable,
            "-c",
            "import os, sys\n"
            "os.environ['VG_SEM_SKIP_CI_GATE_SELFTEST'] = '1'\n"
            "import tools.semantic_fuzz.harness_selftest as h\n"
            "h.run_harness_selftests = lambda: ['INJECTED']\n"
            "from tools.semantic_fuzz.cli import cmd_selftest\n"
            "class A: pass\n"
            "sys.exit(cmd_selftest(A()))\n",
        ],
        cwd=str(root),
        capture_output=True,
        text=True,
    )
    if probe.returncode == 0:
        fails.append("MISS:selftest_failure_does_not_stop_gate")
    combined = probe.stdout + probe.stderr
    if "SELFTEST FAIL" not in combined and "INJECTED" not in combined:
        fails.append("MISS:selftest_fail_banner")

    # --- wrong output / path mismatch → nonzero campaign exit (no Godot) ---
    from .campaign import run_campaign
    from .reference import evaluate_program
    from .runner import RunResult
    import tools.semantic_fuzz.campaign as camp_mod

    real_run = camp_mod.run_program
    real_fg = camp_mod.find_godot
    real_re = camp_mod.resolve_extension_binary

    def _stub_engine(td: Path):
        fake_so = Path(td) / "_ci_fake.so"
        fake_so.write_bytes(b"VG_SEM_CI_FAKE_SO")
        camp_mod.find_godot = lambda _root: Path(td) / "_missing_godot"  # type: ignore
        camp_mod.resolve_extension_binary = lambda _tp: fake_so  # type: ignore

    def _restore_engine():
        camp_mod.find_godot = real_fg
        camp_mod.resolve_extension_binary = real_re
        camp_mod.run_program = real_run

    def _path_for(prog, mode: str) -> tuple[list, dict]:
        want = prog.required_path.get(mode) or "bytecode"
        if want == "native_t3_or_native_t2":
            want = "native_t2"
        target = prog.path_target or "SemMain"
        events = [{"path": want, "fn": target}]
        counts = {target: {want: 1}}
        return events, counts

    def corrupt_obs(prog, **kwargs):
        mode = kwargs.get("mode") or "interpreter"
        exp = [o.to_dict() for o in evaluate_program(prog).observations]
        obs = copy.deepcopy(exp)
        if obs:
            try:
                obs[0]["value"] = str(int(obs[0]["value"]) + 999)
            except (TypeError, ValueError):
                obs[0]["value"] = "999999"
        events, counts = _path_for(prog, mode)
        return RunResult(
            ok=True,
            observations=obs,
            path_events=events,
            path_counts=counts,
            exit_code=0,
            timed_out=False,
            completed=True,
            mode=mode,
            binary_hash="deadbeef",
            engine_path="/fake/godot",
        )

    with tempfile.TemporaryDirectory() as td:
        camp_mod.run_program = corrupt_obs  # type: ignore
        _stub_engine(Path(td))
        try:
            report = run_campaign(4242, 1, modes=["interpreter"], out_dir=Path(td) / "wrong")
            if report.ok or len(report.failures) < 1:
                fails.append("MISS:wrong_output_campaign_not_failed")
            if not (Path(td) / "wrong" / "campaign_report.json").is_file():
                fails.append("MISS:failure_evidence_not_written")
            bundles = list((Path(td) / "wrong").rglob("failure.json"))
            if not bundles:
                fails.append("MISS:failure_bundle_missing")
            else:
                meta = json.loads(bundles[0].read_text(encoding="utf-8"))
                if meta.get("failure_code") not in ("wrong_value", "wrong_type", "count_mismatch"):
                    fails.append(f"MISS:unexpected_failure_code:{meta.get('failure_code')}")
        finally:
            _restore_engine()

    def drop_paths(prog, **kwargs):
        mode = kwargs.get("mode") or "default"
        exp = [o.to_dict() for o in evaluate_program(prog).observations]
        return RunResult(
            ok=True,
            observations=exp,
            path_events=[],
            path_counts={},
            exit_code=0,
            timed_out=False,
            completed=True,
            mode=mode,
            binary_hash="deadbeef",
            engine_path="/fake/godot",
        )

    with tempfile.TemporaryDirectory() as td:
        camp_mod.run_program = drop_paths  # type: ignore
        _stub_engine(Path(td))
        # Force a warmup case that requires native_t2 under default (path events mandatory).
        from .generator import gen_module_local_warmup
        from random import Random as _Rnd

        warm = gen_module_local_warmup(_Rnd(3), 3, 0)
        real_batch = camp_mod.generate_batch
        camp_mod.generate_batch = lambda _s, _c: [warm]  # type: ignore
        try:
            report = run_campaign(4243, 1, modes=["default"], out_dir=Path(td) / "path")
            if report.ok:
                fails.append("MISS:path_mismatch_campaign_ok")
            codes = {f.failure_code for f in report.failures}
            if "path_mismatch" not in codes:
                fails.append(f"MISS:path_mismatch_not_classified:{codes}")
            if not list((Path(td) / "path").rglob("failure.json")):
                fails.append("MISS:path_mismatch_bundle_missing")
        finally:
            camp_mod.generate_batch = real_batch
            _restore_engine()

    # --- missing extension/instrumentation cannot go green ---
    from .runner import check_required_path
    from .generator import gen_module_local_warmup, generate_case
    from random import Random

    warm = gen_module_local_warmup(Random(3), 3, 0)
    err = check_required_path(
        warm,
        "default",
        RunResult(ok=True, path_events=[], path_counts={}, mode="default"),
    )
    if not err:
        fails.append("MISS:missing_instrumentation_green")

    # C2 fixture gate rejects false passes (script error + done + exit 17)
    from .c2_fixture_gate import run_c2_gate_selftests
    from .c2_fixture_shell_selftest import run_c2_shell_selftests
    from .c2_known_defect_gate import run_known_defect_gate_selftests
    from .c2_known_defect_shell_selftest import run_c2_known_defect_shell_selftests

    fails.extend(run_c2_gate_selftests())
    fails.extend(run_c2_shell_selftests())
    fails.extend(run_known_defect_gate_selftests())
    fails.extend(run_c2_known_defect_shell_selftests())

    # Smoke script refuses missing GODOT
    script = root / "scripts" / "run_semantic_ci_smoke.sh"
    if script.is_file():
        env = os.environ.copy()
        env.pop("GODOT", None)
        r = subprocess.run(
            ["bash", str(script)],
            cwd=str(root),
            env=env,
            capture_output=True,
            text=True,
        )
        if r.returncode == 0:
            fails.append("MISS:smoke_without_godot_green")
        if "GODOT must be set" not in (r.stdout + r.stderr):
            fails.append("MISS:smoke_godot_error_message")

        text = script.read_text(encoding="utf-8")
        if "forced_ast,interpreter,default,tier3" not in text:
            fails.append("MISS:smoke_modes_not_explicit")
        if "unset VG_FORCE_AST" not in text:
            fails.append("MISS:smoke_does_not_clear_ambient_modes")
    else:
        fails.append("MISS:smoke_script_missing")

    # path_mismatch non-reducible
    from .identity import preserves_failure_identity

    p = generate_case(1, 0)
    chk = preserves_failure_identity(
        original=p,
        candidate=copy.deepcopy(p),
        mode="interpreter",
        failure_code="path_mismatch",
        rr=RunResult(ok=False, failure_code="path_mismatch", mode="interpreter"),
    )
    if chk.ok:
        fails.append("MISS:path_mismatch_reducible")

    # Shared schema/model refuse for replay *and* reduction
    from . import GENERATOR_VERSION, SCHEMA_VERSION
    from .campaign import _check_replay_provenance
    from .provenance import (
        ENV_LABEL_PREFIX,
        check_bundle_provenance,
        check_schema_model,
        compare_runtime_hashes,
    )

    with tempfile.TemporaryDirectory() as td:
        d = Path(td)
        (d / "program.json").write_text(
            json.dumps({"schema_version": SCHEMA_VERSION + 99, "mode": "interpreter"}),
            encoding="utf-8",
        )
        msg = _check_replay_provenance(d)
        if not msg or "schema_version" not in msg:
            fails.append("MISS:replay_accepts_bad_schema")
        shared = check_bundle_provenance(d, compare_runtime=False).refuse
        if shared != msg:
            fails.append(f"MISS:replay_reduce_schema_check_diverged:{msg!r} vs {shared!r}")

    # Reduction refuses incompatible generator_version (same helper as replay)
    bad_gen = {
        "schema_version": SCHEMA_VERSION,
        "generator_version": GENERATOR_VERSION + 7,
        "mode": "interpreter",
        "failure_code": "wrong_value",
    }
    refuse_gen = check_schema_model(bad_gen)
    if not refuse_gen or "generator_version" not in refuse_gen:
        fails.append("MISS:reduce_accepts_bad_generator_version")

    # Incompatible reduction bundle: cmd_reduce exits nonzero without shrinking
    with tempfile.TemporaryDirectory() as td:
        d = Path(td) / "case" / "interpreter"
        d.mkdir(parents=True)
        prog = generate_case(9, 0)
        from .ir import dumps_program

        (d / "ir.json").write_text(dumps_program(prog), encoding="utf-8")
        (d / "program.json").write_text(
            json.dumps(
                {
                    "schema_version": SCHEMA_VERSION + 50,
                    "mode": "interpreter",
                    "case_id": prog.case_id,
                }
            ),
            encoding="utf-8",
        )
        (d / "failure.json").write_text(
            json.dumps({"failure_code": "wrong_value", "mode": "interpreter"}),
            encoding="utf-8",
        )
        red = subprocess.run(
            [sys.executable, "-m", "tools.semantic_fuzz", "reduce", str(d)],
            cwd=str(root),
            capture_output=True,
            text=True,
        )
        if red.returncode == 0:
            fails.append("MISS:reduce_accepts_incompatible_schema")
        if "reduce refused" not in (red.stdout + red.stderr):
            fails.append("MISS:reduce_refuse_banner")
        if (d / "reduced").is_dir():
            fails.append("MISS:reduce_wrote_output_despite_refuse")

    # Engine replaced at the same pathname → explicit changed_environment label
    same_path = "/tmp/vg-fake-godot-same-path"
    notes = compare_runtime_hashes(
        {
            "binary_hash": "aaaa",
            "engine_hash": "engine_old",
            "engine_path": same_path,
        },
        binary_hash="aaaa",
        engine_hash="engine_new",
        engine_path=same_path,
    )
    if "engine_hash_changed" not in notes or "engine_replaced_same_path" not in notes:
        fails.append(f"MISS:same_path_engine_replace_not_labeled:{notes}")
    if "binary_hash_changed" in notes:
        fails.append("MISS:false_binary_change_on_engine_only")

    # Replay labels binary + engine path changes with ENV_LABEL_PREFIX
    with tempfile.TemporaryDirectory() as td:
        from .bundle_integrity import write_bound_test_bundle

        prog = generate_case(7, 0)
        d = write_bound_test_bundle(
            Path(td) / "case" / "interpreter",
            prog,
            mode="interpreter",
            run_token="envprobe",
        )
        (d / "failure.json").write_text(
            json.dumps(
                {
                    **json.loads((d / "program.json").read_text(encoding="utf-8")),
                    "binary_hash": "aaaaaaaa",
                    "engine_hash": "eeeeeeee",
                    "engine_path": "/old/godot",
                    "failure_code": "wrong_value",
                }
            ),
            encoding="utf-8",
        )
        (d / "actual.json").write_text("[]", encoding="utf-8")

        def fake_replay_run(p, **kwargs):
            exp = [o.to_dict() for o in evaluate_program(p).observations]
            events, counts = _path_for(p, "interpreter")
            return RunResult(
                ok=True,
                observations=exp,
                path_events=events,
                path_counts=counts,
                completed=True,
                mode="interpreter",
                binary_hash="bbbbbbbb",
                engine_hash="ffffffff",
                engine_path="/new/godot",
            )

        camp_mod.run_program = fake_replay_run  # type: ignore
        try:
            from .campaign import replay_case_dir

            crep = replay_case_dir(d)
            msg = crep.message or ""
            if not msg.startswith(ENV_LABEL_PREFIX):
                fails.append(f"MISS:changed_environment_prefix:{msg!r}")
            if "binary_hash_changed" not in msg:
                fails.append(f"MISS:binary_hash_not_noted:{msg!r}")
            if "engine_hash_changed" not in msg and "engine_path_changed" not in msg:
                fails.append(f"MISS:engine_change_not_noted:{msg!r}")
        except Exception as exc:  # noqa: BLE001 — probe must not raise green
            fails.append(f"MISS:replay_new_env_raised:{exc}")
        finally:
            camp_mod.run_program = real_run

    # Failure bundles persist engine_hash alongside binary_hash
    from .campaign import _write_failure_bundle

    with tempfile.TemporaryDirectory() as td:
        case_out = Path(td) / "case" / "interpreter"
        prog = generate_case(11, 0)
        rr = RunResult(
            ok=False,
            failure_code="wrong_value",
            mode="interpreter",
            binary_hash="binhash",
            engine_hash="enghash",
            engine_path="/e/godot",
            observations=[],
            bound_path_module="res://sem_fuzz_runs/test/case/interpreter/case.vg",
            bound_path_module_key="sem_fuzz_ir/case/interpreter",
        )
        _write_failure_bundle(case_out, prog, [], rr, failure_code="wrong_value")
        meta = json.loads((case_out / "failure.json").read_text(encoding="utf-8"))
        prog_meta = json.loads((case_out / "program.json").read_text(encoding="utf-8"))
        if meta.get("engine_hash") != "enghash" or meta.get("binary_hash") != "binhash":
            fails.append(f"MISS:failure_bundle_missing_hashes:{meta}")
        if prog_meta.get("engine_hash") != "enghash":
            fails.append("MISS:program_json_missing_engine_hash")

    return fails
