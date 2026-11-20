"""Bounded IR-aware reducer that preserves failure class and path when possible."""

from __future__ import annotations

import copy
import time
from dataclasses import dataclass
from typing import Callable, Optional

from .compare import CompareError, compare_observations
from .ir import (
    Assign,
    ForStmt,
    IfStmt,
    Observe,
    Program,
    SelectStmt,
    dumps_program,
)
from .reference import evaluate_program


@dataclass
class ReduceResult:
    original: Program
    minimized: Program
    shrunk: bool
    attempts: int
    message: str


def _strip_trailing_observes(prog: Program) -> Optional[Program]:
    if len(prog.main) < 2:
        return None
    if not isinstance(prog.main[-1], Observe):
        return None
    # Keep at least one observe.
    observes = [s for s in prog.main if isinstance(s, Observe)]
    if len(observes) <= 1:
        return None
    cand = copy.deepcopy(prog)
    cand.main = list(cand.main[:-1])
    return cand


def _drop_assign_before_observe(prog: Program) -> Optional[Program]:
    if len(prog.main) < 3:
        return None
    cand = copy.deepcopy(prog)
    # Drop first assign if later observes still make sense under reference.
    if isinstance(cand.main[0], Assign):
        cand.main = cand.main[1:]
        return cand
    return None


def _shrink_for_bounds(prog: Program) -> Optional[Program]:
    cand = copy.deepcopy(prog)
    changed = False
    for st in cand.main:
        if isinstance(st, ForStmt) and hasattr(st.hi, "value") and hasattr(st.lo, "value"):
            if st.hi.value - st.lo.value > 1:
                st.hi.value = st.lo.value + 1
                changed = True
    return cand if changed else None


def _drop_select_case(prog: Program) -> Optional[Program]:
    cand = copy.deepcopy(prog)
    for st in cand.main:
        if isinstance(st, SelectStmt) and len(st.cases) > 1:
            st.cases = st.cases[:1]
            return cand
    return None


def _simplify_if(prog: Program) -> Optional[Program]:
    cand = copy.deepcopy(prog)
    for i, st in enumerate(cand.main):
        if isinstance(st, IfStmt) and st.else_body:
            st.else_body = []
            return cand
        if isinstance(st, ForStmt):
            for j, b in enumerate(st.body):
                if isinstance(b, IfStmt) and b.else_body:
                    b.else_body = []
                    return cand
    return None


TRANSFORMS = (
    _strip_trailing_observes,
    _drop_assign_before_observe,
    _shrink_for_bounds,
    _drop_select_case,
    _simplify_if,
)


def reduce_failure(
    prog: Program,
    *,
    still_fails: Callable[[Program], bool],
    max_attempts: int = 40,
    time_limit_secs: float = 60.0,
) -> ReduceResult:
    """Shrink prog while still_fails(candidate) remains true."""
    if getattr(prog, "source_modules", None):
        raise ValueError(
            "reduce refused: multi-file source_modules not reducible yet; "
            "retain the original bound failure bundle"
        )
    # Optional case_dir integrity when reducing from a saved bundle path via CLI.
    current = copy.deepcopy(prog)
    attempts = 0
    t0 = time.time()
    shrunk = False
    while attempts < max_attempts and (time.time() - t0) < time_limit_secs:
        progressed = False
        for transform in TRANSFORMS:
            attempts += 1
            cand = transform(current)
            if cand is None:
                continue
            try:
                evaluate_program(cand)
            except Exception:
                continue
            if still_fails(cand):
                current = cand
                shrunk = True
                progressed = True
                break
            if attempts >= max_attempts:
                break
        if not progressed:
            break
    return ReduceResult(
        original=prog,
        minimized=current,
        shrunk=shrunk,
        attempts=attempts,
        message="shrunk" if shrunk else "could not shrink; retained original",
    )


def synthetic_wrong_value_oracle(prog: Program) -> bool:
    """Test-only predicate: fail when observation count >= 1 (always), used with corrupted compare."""
    res = evaluate_program(prog)
    return len(res.observations) >= 1
