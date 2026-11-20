"""Exact failure-class and execution-path identity for reduction / replay."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

from .compare import CompareError, compare_observations
from .ir import Program
from .reference import evaluate_program
from .runner import RunResult, check_required_path, run_program


@dataclass
class IdentityCheck:
    ok: bool
    reason: str = ""


def path_contract_error(prog: Program, mode: str, result: RunResult) -> Optional[str]:
    """Same contract as campaign path validation (including interpreter≠AST)."""
    return check_required_path(prog, mode, result)


def classify_run_failure(
    prog: Program,
    mode: str,
    rr: RunResult,
    expected: list[dict],
) -> tuple[Optional[str], str]:
    """Return (failure_code, message) for a completed run attempt.

    Compare failures and path mismatches are classified even when rr.ok.
    """
    if not rr.ok:
        return rr.failure_code, rr.message
    try:
        compare_observations(expected, rr.observations)
    except CompareError as exc:
        return exc.code, str(exc)
    path_err = path_contract_error(prog, mode, rr)
    if path_err:
        return "path_mismatch", path_err
    return None, "ok"


def preserves_failure_identity(
    *,
    original: Program,
    candidate: Program,
    mode: str,
    failure_code: str,
    rr: RunResult,
    expected: Optional[list[dict]] = None,
) -> IdentityCheck:
    """True only when candidate fails with the *exact* same failure_code and
    still satisfies the original path_target execution-path contract for mode.

    Rejects:
      - wrong_value → wrong_type (or any other class drift)
      - bytecode/native requirement satisfied by unintended AST fallback
      - missing/changed path_target path evidence
    """
    if not failure_code:
        return IdentityCheck(False, "missing original failure_code")

    # path_mismatch cannot both preserve the mismatch and satisfy the path contract.
    # Mark non-reducible: retain the original failure bundle.
    if failure_code == "path_mismatch":
        return IdentityCheck(False, "path_mismatch is non-reducible; retain original bundle")

    # Candidate must keep the full canonical path contract (do not drop Inner/Side
    # targets or switch module identity while keeping function names).
    if candidate.path_target != original.path_target:
        return IdentityCheck(False, "path_target changed")
    if list(candidate.path_targets or []) != list(original.path_targets or []):
        return IdentityCheck(False, "path_targets changed")
    if candidate.required_path != original.required_path:
        return IdentityCheck(False, "required_path changed")
    if candidate.fallback_contract != original.fallback_contract:
        return IdentityCheck(False, "fallback_contract changed")
    orig_key = original.path_module_key or original.path_module
    cand_key = candidate.path_module_key or candidate.path_module
    if orig_key != cand_key:
        return IdentityCheck(False, "path_module_key changed")

    exp = expected
    if exp is None:
        exp = [o.to_dict() for o in evaluate_program(candidate).observations]

    code, msg = classify_run_failure(candidate, mode, rr, exp)
    if code is None:
        return IdentityCheck(False, "candidate no longer fails")
    if code != failure_code:
        return IdentityCheck(
            False,
            f"failure class drifted: want {failure_code} got {code} ({msg})",
        )

    # Even for observation failures, the relevant target path contract must hold.
    # A wrong-value on AST when the original required bytecode is not the same bug.
    path_err = path_contract_error(candidate, mode, rr)
    if path_err:
        return IdentityCheck(False, f"path contract broken: {path_err}")

    return IdentityCheck(True, "identity preserved")


def make_reduce_predicate(
    *,
    original: Program,
    mode: str,
    failure_code: str,
    work_root,
    timeout_secs: float = 20.0,
):
    """Callable for reduce_failure that enforces exact class + path contract."""

    def still_fails(cand: Program) -> bool:
        expected = [o.to_dict() for o in evaluate_program(cand).observations]
        rr = run_program(cand, mode=mode, work_root=work_root, timeout_secs=timeout_secs)
        check = preserves_failure_identity(
            original=original,
            candidate=cand,
            mode=mode,
            failure_code=failure_code,
            rr=rr,
            expected=expected,
        )
        return check.ok

    return still_fails
