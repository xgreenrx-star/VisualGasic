"""Explicit C3 Godot integration tests (not part of pure oracle).

Requires GODOT and a selected project with a loadable extension binary
(``VG_SEM_TEST_PROJ`` or default ``test_proj``). Failures are loud — never
silently skipped when dependencies are missing.
"""

from __future__ import annotations

import argparse
import io
import json
import os
import shutil
import tempfile
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from typing import List, Optional, Tuple

from .bundle_integrity import write_bound_test_bundle
from .cli import cmd_reduce, cmd_replay
from .compare import CompareError, compare_observations
from .phase2_c3_selftest import _hand_dict_miss
from .provenance import check_bundle_provenance
from .reference import evaluate_program
from .runner import (
    file_sha256,
    find_godot,
    find_repo_root,
    resolve_extension_binary,
    resolve_test_proj,
)


def _require_godot_and_binary() -> Tuple[Path, Path, Path]:
    root = find_repo_root()
    try:
        godot = find_godot(root)
    except FileNotFoundError as exc:
        raise RuntimeError(f"C3_INTEGRATION missing Godot: {exc}") from exc
    test_proj = resolve_test_proj(root)
    try:
        binary = resolve_extension_binary(test_proj)
    except FileNotFoundError as exc:
        raise RuntimeError(f"C3_INTEGRATION missing extension binary: {exc}") from exc
    return root, Path(godot), binary


def run_c3_injected_err_integration() -> List[str]:
    """Emitter→runner→compare: injected nonzero captured Err must yield wrong_value."""
    fails: List[str] = []
    try:
        _require_godot_and_binary()
    except RuntimeError as exc:
        return [str(exc)]

    from . import emitter as emitter_mod
    from . import runner as runner_mod

    prog = _hand_dict_miss()
    expected = [o.to_dict() for o in evaluate_program(prog).observations]
    real_emit = emitter_mod.emit_program

    def bad_emit(p, *, warmup_calls: int = 0):
        src = real_emit(p, warmup_calls=warmup_calls)
        needle = "_c3_err = Err.Number"
        if needle not in src:
            raise RuntimeError("emit missing _c3_err capture")
        return src.replace(needle, "_c3_err = 9", 1)

    runner_mod.emit_program = bad_emit
    try:
        with tempfile.TemporaryDirectory(prefix="vg-c3-inj-") as td:
            rr = runner_mod.run_program(
                prog,
                mode="interpreter",
                work_root=Path(td),
                timeout_secs=30.0,
            )
    finally:
        runner_mod.emit_program = real_emit

    if rr.failure_code == "missing_extension_binary":
        fails.append(f"injected_err: missing binary after require: {rr.message}")
        return fails
    if not rr.observations:
        fails.append(
            f"injected_err: no observations ok={rr.ok} code={rr.failure_code} msg={rr.message}"
        )
        return fails
    try:
        compare_observations(expected, rr.observations)
        fails.append("injected_err: nonzero captured Err accepted by compare")
    except CompareError as exc:
        if exc.code != "wrong_value":
            fails.append(f"injected_err: expected wrong_value got {exc.code}: {exc}")
        if "miss_err" not in str(exc):
            fails.append(f"injected_err: mismatch not on miss_err: {exc}")
    return fails


def _make_fake_project(parent: Path, tag: bytes) -> Tuple[Path, str]:
    proj = parent / "test_proj"
    so_dir = proj / "addons" / "visual_gasic" / "bin"
    so_dir.mkdir(parents=True)
    so = so_dir / "libvisualgasic.linux.editor.x86_64.so"
    so.write_bytes(tag)
    so.chmod(0o755)
    (proj / "run_suite.gd").write_text("' fake\n", encoding="utf-8")
    return proj, file_sha256(so)


def run_c3_provenance_entry_selftests() -> List[str]:
    """Replay/reduce entry points use resolve_extension_binary — not main addons."""
    fails: List[str] = []
    root = find_repo_root()
    main_so = root / "addons" / "visual_gasic" / "bin" / "libvisualgasic.linux.editor.x86_64.so"
    main_hash = file_sha256(main_so) if main_so.is_file() else None

    with tempfile.TemporaryDirectory(prefix="vg-c3-prov-") as td:
        td_path = Path(td)
        proj_a, hash_a = _make_fake_project(td_path / "A", b"FAKE_SO_AAA")
        proj_b, hash_b = _make_fake_project(td_path / "B", b"FAKE_SO_BBB")
        if hash_a == hash_b:
            fails.append("prov: fake A/B hashes collided")
        if main_hash and hash_a == main_hash:
            fails.append("prov: fake A hash collided with main checkout")

        prog = _hand_dict_miss()
        case = write_bound_test_bundle(
            td_path / "bundle",
            prog,
            mode="interpreter",
            run_token="c3prov",
        )
        # Reducible failure code (not path_mismatch).
        pmeta = json.loads((case / "program.json").read_text(encoding="utf-8"))
        pmeta["binary_hash"] = hash_a
        pmeta["failure_code"] = "wrong_value"
        (case / "program.json").write_text(json.dumps(pmeta, indent=2) + "\n", encoding="utf-8")
        (case / "failure.json").write_text(json.dumps(pmeta, indent=2) + "\n", encoding="utf-8")
        # Corrupt actual so a real reduce would still see wrong_value if predicate ran.
        good = [o.to_dict() for o in evaluate_program(prog).observations]
        bad = [{**good[0], "value": "999"}, *good[1:]] if good else []
        (case / "actual.json").write_text(json.dumps(bad) + "\n", encoding="utf-8")

        old_proj = os.environ.get("VG_SEM_TEST_PROJ")
        try:
            os.environ["VG_SEM_TEST_PROJ"] = str(proj_a)
            so = resolve_extension_binary(resolve_test_proj(root))
            if main_hash and so.resolve() == main_so.resolve():
                fails.append("prov: resolve A returned main checkout binary")
            if file_sha256(so) != hash_a:
                fails.append("prov: resolve A hash mismatch")
            v_match = check_bundle_provenance(
                case, binary_hash=hash_a, compare_runtime=True
            )
            if v_match.refuse:
                fails.append(f"prov: match refused: {v_match.refuse}")
            if "binary_hash_changed" in (v_match.environment_label or ""):
                fails.append("prov: match labeled drift")

            os.environ["VG_SEM_TEST_PROJ"] = str(proj_b)
            so_b = resolve_extension_binary(resolve_test_proj(root))
            if file_sha256(so_b) != hash_b:
                fails.append("prov: resolve B hash mismatch")
            v_drift = check_bundle_provenance(
                case, binary_hash=hash_b, compare_runtime=True
            )
            if "binary_hash_changed" not in (v_drift.environment_label or ""):
                fails.append(f"prov: drift missing label: {v_drift.environment_label}")

            empty = td_path / "empty_proj"
            (empty / "addons" / "visual_gasic" / "bin").mkdir(parents=True)
            os.environ["VG_SEM_TEST_PROJ"] = str(empty)
            try:
                resolve_extension_binary(resolve_test_proj(root))
                fails.append("prov: missing binary accepted")
            except FileNotFoundError as exc:
                if "missing selected-project binary" not in str(exc):
                    fails.append(f"prov: unexpected missing msg {exc}")

            os.environ["VG_SEM_TEST_PROJ"] = str(empty)
            buf = io.StringIO()
            with redirect_stdout(buf), redirect_stderr(buf):
                rc = cmd_reduce(
                    argparse.Namespace(
                        case_dir=str(case),
                        max_attempts=1,
                        time_limit=5.0,
                        timeout=5.0,
                    )
                )
            out_miss = buf.getvalue()
            if rc == 0:
                fails.append("prov: reduce accepted missing binary")
            if "missing selected-project binary" not in out_miss:
                fails.append(f"prov: reduce missing-binary msg absent: {out_miss[:240]}")
            if "path_mismatch is non-reducible" in out_miss:
                fails.append("prov: reduce took path_mismatch early return")

            from . import identity as identity_mod
            from . import runner as runner_mod

            fake_godot = td_path / "fake_godot"
            fake_godot.write_bytes(b"#!/bin/sh\nexit 1\n")
            fake_godot.chmod(0o755)
            real_fg = runner_mod.find_godot
            real_pred_factory = identity_mod.make_reduce_predicate

            def _never_fails(**_kwargs):
                return lambda _p: False

            try:
                runner_mod.find_godot = lambda _r: fake_godot  # type: ignore
                identity_mod.make_reduce_predicate = _never_fails  # type: ignore

                os.environ["VG_SEM_TEST_PROJ"] = str(proj_b)
                buf_b = io.StringIO()
                with redirect_stdout(buf_b), redirect_stderr(buf_b):
                    rc_b = cmd_reduce(
                        argparse.Namespace(
                            case_dir=str(case),
                            max_attempts=1,
                            time_limit=2.0,
                            timeout=2.0,
                        )
                    )
                out_b = buf_b.getvalue()
                if "binary_hash_changed" not in out_b:
                    fails.append(f"prov: reduce B missing drift note: {out_b[:240]}")
                del rc_b

                os.environ["VG_SEM_TEST_PROJ"] = str(proj_a)
                buf_a = io.StringIO()
                with redirect_stdout(buf_a), redirect_stderr(buf_a):
                    rc_a = cmd_reduce(
                        argparse.Namespace(
                            case_dir=str(case),
                            max_attempts=1,
                            time_limit=2.0,
                            timeout=2.0,
                        )
                    )
                out_a = buf_a.getvalue()
                if "binary_hash_changed" in out_a:
                    fails.append(f"prov: reduce A falsely labeled drift: {out_a[:240]}")
                if main_hash and main_hash[:16] in out_a:
                    fails.append("prov: reduce A output mentioned main binary hash")
                so_a = resolve_extension_binary(resolve_test_proj(root))
                if main_so.is_file() and so_a.resolve() == main_so.resolve():
                    fails.append("prov: reduce A resolved main checkout binary")
                if file_sha256(so_a) != hash_a:
                    fails.append("prov: reduce A resolve hash != owned fake A")
                del rc_a
            finally:
                runner_mod.find_godot = real_fg
                identity_mod.make_reduce_predicate = real_pred_factory

            # Replay refuses reference_version=4 (checkpoint-7 incompatible).
            v4 = td_path / "v4_bundle"
            shutil.copytree(case, v4)
            for name in ("program.json", "failure.json"):
                p = v4 / name
                if not p.is_file():
                    continue
                meta4 = json.loads(p.read_text(encoding="utf-8"))
                meta4["reference_version"] = 4
                p.write_text(json.dumps(meta4, indent=2) + "\n", encoding="utf-8")
            try:
                from .campaign import replay_case_dir

                replay_case_dir(v4)
                fails.append("prov: replay accepted reference_version=4")
            except ValueError as exc:
                if "reference_version incompatible" not in str(exc):
                    fails.append(f"prov: replay v4 wrong refuse: {exc}")
            except Exception as exc:
                fails.append(f"prov: replay v4 unexpected {type(exc).__name__}: {exc}")

            try:
                rc_r = cmd_replay(argparse.Namespace(case_dir=str(v4)))
            except ValueError as exc:
                rc_r = 2
                if "reference_version incompatible" not in str(exc):
                    fails.append(f"prov: cmd_replay v4 wrong: {exc}")
            if rc_r == 0:
                fails.append("prov: cmd_replay accepted v4")
        finally:
            if old_proj is None:
                os.environ.pop("VG_SEM_TEST_PROJ", None)
            else:
                os.environ["VG_SEM_TEST_PROJ"] = old_proj

    return fails


def run_phase2_c3_integration_selftests() -> List[str]:
    """All explicit C3 integration checks. Loud on missing deps."""
    fails: List[str] = []
    fails.extend(run_c3_injected_err_integration())
    fails.extend(run_c3_provenance_entry_selftests())
    return fails


def main(argv: Optional[List[str]] = None) -> int:
    del argv
    fails = run_phase2_c3_integration_selftests()
    if fails:
        print("C3_INTEGRATION FAIL")
        for f in fails:
            print(" ", f)
        return 1
    print("C3_INTEGRATION PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
