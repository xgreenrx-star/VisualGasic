"""Judge C2 Godot fixture logs — reject silent false passes."""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional, Tuple

from .c2_fixture_manifest import (
    FixtureExpect,
    expect_for,
    resolve_resource,
)
from .path_contract import (
    check_c2_path_requirements,
    module_path_counts,
    parse_path_event_line,
)


PASS_LINE_RE = re.compile(r"^PASS:\s*(.+?)\s*$")
FAIL_LINE_RE = re.compile(r"^FAIL:\s*(.+?)\s*$")
KNOWN_INDEX_EXACT_RE = re.compile(
    r"^C2_KNOWN_FAIL index_evals=(\d+) want=1\s*$"
)
C2_SUMMARY_RE = re.compile(r"^C2_SUMMARY passed=(\d+) failed=(\d+)\s*$")

# Structured positive verdict — full string match, no trailing junk / reasons=.
# Optional known= only when the fixture contract requires it.
VERDICT_FIELD_RE = re.compile(
    r"^OK (?P<base>\S+) mode=(?P<mode>\S+) "
    r"exit=(?P<exit>\d+) pass_lines=(?P<pass_lines>\d+) "
    r"fail_lines=(?P<fail_lines>\d+) done=(?P<done>\d+)"
    r"(?: known=\[(?P<known>[^\]]*)\])?$"
)

ERROR_MARKERS = (
    "SCRIPT ERROR",
    "Parser Error",
    "VG Runtime Error",
    "handle_crash:",
    "Invalid call",
)
ERROR_LINE_RE = re.compile(r"(?m)^ERROR: ")
# Note: do not require \\b after "PASS:" — ":" is non-word, so "PASS: x" has no \\b there.
POST_DONE_RESULT_RE = re.compile(
    r"(?m)^(PASS:|FAIL:|C2_SUMMARY(?:\s|$)|C2_KNOWN_FAIL(?:\s|$))"
)

ALLOWED_MODES = frozenset({"forced_ast", "interpreter", "default", "tier3"})


@dataclass
class GateVerdict:
    ok: bool
    reasons: list = field(default_factory=list)
    pass_count: int = 0
    fail_count: int = 0
    known_failures: list = field(default_factory=list)
    done_count: int = 0
    exit_code: int = 0
    path_events: list = field(default_factory=list)
    module_path_counts: dict = field(default_factory=dict)


@dataclass(frozen=True)
class VerdictContract:
    """What a positive shell-accepted verdict must claim."""

    base: str
    mode: str
    child_exit: int
    expect: FixtureExpect
    resource: str


def _split_pre_post_done(text: str) -> Tuple[str, str, int, list]:
    reasons = []
    lines = text.splitlines(keepends=True)
    done_idxs = [
        i
        for i, ln in enumerate(lines)
        if ln.rstrip("\r\n") == "VG_SUITE_COMPLETED"
    ]
    for ln in lines:
        stripped = ln.rstrip("\r\n")
        if "VG_SUITE_COMPLETED" in stripped and stripped != "VG_SUITE_COMPLETED":
            reasons.append("malformed_completion")
            break
    if not done_idxs:
        return text, "", 0, reasons
    if len(done_idxs) > 1:
        reasons.append(f"duplicate_completion:{len(done_idxs)}")
    first = done_idxs[0]
    pre = "".join(lines[:first])
    post = "".join(lines[first + 1 :])
    return pre, post, len(done_idxs), reasons


def _pass_label_matches(observed: str, expected: str) -> bool:
    if observed == expected:
        return True
    if observed.startswith(expected + " type="):
        return True
    return False


def _check_well_formed_result_lines(pre: str) -> list:
    """Every result-bearing line must match its exact grammar."""
    reasons = []
    for ln in pre.splitlines():
        s = ln.rstrip("\r\n")
        if not s:
            continue
        if s.startswith("PASS:"):
            if PASS_LINE_RE.match(s) is None:
                reasons.append(f"malformed_pass:{s!r}")
        elif s.startswith("FAIL:"):
            if FAIL_LINE_RE.match(s) is None:
                reasons.append(f"malformed_fail:{s!r}")
        elif s.startswith("C2_SUMMARY"):
            if C2_SUMMARY_RE.match(s) is None:
                reasons.append(f"malformed_c2_summary:{s!r}")
        elif s.startswith("C2_KNOWN_FAIL"):
            if KNOWN_INDEX_EXACT_RE.match(s) is None:
                reasons.append(f"malformed_known_fail:{s!r}")
    return reasons


def _check_expected_passes(
    pre: str, expect: FixtureExpect, v: GateVerdict
) -> list:
    reasons = []
    observed = []
    fails = []
    for ln in pre.splitlines():
        s = ln.rstrip("\r\n")
        m = PASS_LINE_RE.match(s)
        if m:
            observed.append(m.group(1))
            continue
        m = FAIL_LINE_RE.match(s)
        if m:
            fails.append(m.group(1))
    v.pass_count = len(observed)
    v.fail_count = len(fails)

    if fails:
        reasons.append(f"fail_assertions:{len(fails)}")

    summary_label = expect.summary_pass
    individual = list(expect.pass_labels)
    expected_total = expect.expected_pass_line_count()

    oi = 0
    for label in individual:
        if oi >= len(observed):
            reasons.append(f"missing_pass:{label}")
            continue
        if not _pass_label_matches(observed[oi], label):
            reasons.append(
                f"pass_mismatch:want={label!r} got={observed[oi]!r}"
            )
        oi += 1

    if summary_label is not None:
        if oi >= len(observed):
            reasons.append(f"missing_summary_pass:{summary_label}")
        else:
            if observed[oi] != summary_label:
                reasons.append(
                    f"summary_pass_mismatch:want={summary_label!r} got={observed[oi]!r}"
                )
            oi += 1

    if oi < len(observed):
        reasons.append(f"unexpected_pass_extra:{observed[oi:]!r}")

    if len(observed) != expected_total and not any(
        r.startswith("missing_") or r.startswith("pass_mismatch") for r in reasons
    ):
        reasons.append(
            f"pass_count_mismatch:got={len(observed)} want={expected_total}"
        )

    if expect.require_c2_summary:
        sums = [ln for ln in pre.splitlines() if ln.startswith("C2_SUMMARY")]
        well = [C2_SUMMARY_RE.match(ln.rstrip("\r\n")) for ln in sums]
        well = [m for m in well if m]
        # Malformed already flagged by _check_well_formed_result_lines.
        if len(well) == 0:
            reasons.append("missing_c2_summary")
        elif len(well) > 1:
            reasons.append(f"duplicate_c2_summary:{len(well)}")
        else:
            passed_n = int(well[0].group(1))
            failed_n = int(well[0].group(2))
            if passed_n != len(individual):
                reasons.append(
                    f"c2_summary_passed_mismatch:got={passed_n} want={len(individual)}"
                )
            if failed_n != len(fails):
                reasons.append(
                    f"c2_summary_failed_mismatch:got={failed_n} want={len(fails)}"
                )

    return reasons


def _check_known_index(
    pre: str, expect: FixtureExpect, v: GateVerdict
) -> list:
    reasons = []
    known_lines = [
        ln.rstrip("\r\n")
        for ln in pre.splitlines()
        if ln.startswith("C2_KNOWN_FAIL")
    ]
    exact = []
    for ln in known_lines:
        m = KNOWN_INDEX_EXACT_RE.match(ln)
        if m:
            exact.append(m)

    required = expect.require_known_index_evals

    if required is None:
        if known_lines:
            reasons.append("unexpected_known_fail_record")
        return reasons

    if len(known_lines) != len(exact):
        # malformed already noted; still mark contract miss
        reasons.append("malformed_or_unknown_known_fail")

    if len(exact) == 0:
        reasons.append("missing_known_fail_index_evals")
        return reasons
    if len(exact) > 1:
        reasons.append(f"duplicate_known_fail_index:{len(exact)}")

    got = int(exact[0].group(1))
    v.known_failures.append(f"index_evals={got} want=1")
    if got == 1:
        reasons.append("index_once_unexpectedly_fixed_update_contracts")
    elif got != required:
        reasons.append(
            f"known_index_evals_mismatch:got={got} want={required}"
        )
    return reasons


def _collect_path_events(text: str, v: GateVerdict) -> list:
    events = []
    for ln in text.splitlines():
        try:
            ev = parse_path_event_line(ln.strip())
        except ValueError as exc:
            v.reasons.append(f"malformed_path_line:{exc}")
            continue
        if ev is not None:
            events.append(ev)
    v.path_events = events
    v.module_path_counts = module_path_counts(events)
    return events


def judge_c2_log(
    text: str,
    *,
    exit_code: int = 0,
    base: str = "",
    resource: str = "",
    mode: str = "default",
    expect: Optional[FixtureExpect] = None,
    allow_legacy_unknown: bool = False,
    min_pass: Optional[int] = None,
    require_known_index_fail: bool = False,
) -> GateVerdict:
    """Return ok=False unless the run is a clean, assertion-bearing success.

    Production C2 lane: pass resource= (full res://…) or a known base with
    expect from the manifest. Unknown fixtures are rejected unless
    allow_legacy_unknown=True (test-only).
    """
    v = GateVerdict(ok=True, exit_code=exit_code)

    if resource:
        resolved = resolve_resource(resource)
        if resolved is None:
            v.ok = False
            v.reasons.append(f"unknown_resource:{resource}")
            return v
        res_base, res_expect = resolved
        if base and base != res_base:
            v.ok = False
            v.reasons.append(
                f"resource_base_mismatch:resource={res_base} base={base}"
            )
            return v
        base = res_base
        if expect is None:
            expect = res_expect

    if expect is None and base:
        expect = expect_for(base)

    if expect is None and require_known_index_fail and not allow_legacy_unknown:
        expect = expect_for("test_sem_c2_calls_byref")

    if expect is None and not allow_legacy_unknown:
        v.ok = False
        label = base or resource or "<unset>"
        v.reasons.append(f"unknown_fixture:{label}")
        return v

    pre, post, done_count, struct = _split_pre_post_done(text)
    v.done_count = done_count
    v.reasons.extend(struct)

    if exit_code == 124:
        v.ok = False
        v.reasons.append("timeout")
        return v
    if exit_code != 0:
        v.ok = False
        v.reasons.append(f"nonzero_exit:{exit_code}")

    for marker in ERROR_MARKERS:
        if marker in text:
            v.ok = False
            v.reasons.append(f"runtime_or_script_error:{marker.strip()}")
    if ERROR_LINE_RE.search(text):
        v.ok = False
        v.reasons.append("runtime_or_script_error:ERROR:")

    if done_count == 0:
        v.ok = False
        v.reasons.append("missing_completion")
    elif done_count > 1:
        if not any(r.startswith("duplicate_completion") for r in v.reasons):
            v.ok = False
            v.reasons.append(f"duplicate_completion:{done_count}")

    if post.strip() and POST_DONE_RESULT_RE.search(post):
        v.ok = False
        v.reasons.append("records_after_completion")

    body = pre if done_count else text
    v.reasons.extend(_check_well_formed_result_lines(body))

    path_events = _collect_path_events(text, v)

    if expect is not None:
        v.reasons.extend(_check_expected_passes(body, expect, v))
        v.reasons.extend(_check_known_index(body, expect, v))
        if expect.path_requirements:
            v.reasons.extend(
                check_c2_path_requirements(
                    path_events, mode=mode, requirements=list(expect.path_requirements)
                )
            )
    else:
        # Explicit legacy/test-only path.
        v.pass_count = len(
            [ln for ln in body.splitlines() if PASS_LINE_RE.match(ln.rstrip("\r\n"))]
        )
        v.fail_count = len(
            [ln for ln in body.splitlines() if FAIL_LINE_RE.match(ln.rstrip("\r\n"))]
        )
        if v.fail_count > 0:
            v.reasons.append(f"fail_assertions:{v.fail_count}")
        need = 1 if min_pass is None else min_pass
        if v.pass_count < need:
            v.reasons.append(
                f"missing_assertions:pass_count={v.pass_count}<{need}"
            )

    if v.reasons:
        v.ok = False
    return v


def format_verdict(base: str, mode: str, v: GateVerdict) -> str:
    status = "OK" if v.ok else "FAIL"
    parts = [
        f"{status} {base} mode={mode}",
        f"exit={v.exit_code}",
        f"pass_lines={v.pass_count}",
        f"fail_lines={v.fail_count}",
        f"done={v.done_count}",
    ]
    if v.known_failures:
        parts.append("known=[" + ",".join(v.known_failures) + "]")
    if v.reasons:
        parts.append("reasons=[" + ",".join(v.reasons) + "]")
    return " ".join(parts)


def validate_positive_verdict(
    line: str, contract: VerdictContract
) -> Tuple[bool, str]:
    """Full-match structured check bound to fixture/mode/child exit/manifest."""
    s = (line or "").strip()
    if not s:
        return False, "empty_judge_stdout"
    if "\n" in (line or ""):
        return False, "multiline_judge_stdout"
    if s.startswith("FAIL "):
        return False, "judge_reported_fail"
    if "reasons=" in s:
        return False, "positive_verdict_has_reasons"

    m = VERDICT_FIELD_RE.fullmatch(s)
    if m is None:
        return False, "malformed_verdict"

    if m.group("base") != contract.base:
        return False, f"verdict_base_mismatch:got={m.group('base')}"
    if m.group("mode") != contract.mode:
        return False, f"verdict_mode_mismatch:got={m.group('mode')}"
    if contract.mode not in ALLOWED_MODES:
        return False, f"unknown_mode:{contract.mode}"

    reported_exit = int(m.group("exit"))
    if reported_exit != contract.child_exit:
        return False, (
            f"verdict_exit_mismatch:reported={reported_exit}"
            f" child={contract.child_exit}"
        )
    if contract.child_exit != 0 or reported_exit != 0:
        return False, f"positive_requires_child_exit_0:got={contract.child_exit}"

    if int(m.group("fail_lines")) != 0:
        return False, "positive_requires_fail_lines_0"
    if int(m.group("done")) != 1:
        return False, "positive_requires_done_1"

    want_pass = contract.expect.expected_pass_line_count()
    got_pass = int(m.group("pass_lines"))
    if got_pass != want_pass:
        return False, f"verdict_pass_lines_mismatch:got={got_pass} want={want_pass}"

    known_raw = m.group("known")
    req = contract.expect.require_known_index_evals
    if req is None:
        if known_raw is not None:
            return False, "unexpected_known_on_verdict"
    else:
        if known_raw is None:
            return False, "missing_known_on_verdict"
        if known_raw != f"index_evals={req} want=1":
            return False, f"known_mismatch:got={known_raw!r}"

    # Resource must resolve to the same fixture.
    resolved = resolve_resource(contract.resource)
    if resolved is None or resolved[0] != contract.base:
        return False, f"resource_not_bound:{contract.resource}"

    return True, "ok"


def parse_verdict_line(
    line: str,
    *,
    contract: Optional[VerdictContract] = None,
) -> Tuple[bool, str]:
    """Shell helper. Without contract, only rejects obviously bad shapes."""
    if contract is not None:
        return validate_positive_verdict(line, contract)
    s = (line or "").strip()
    if not s:
        return False, "empty_judge_stdout"
    if "\n" in (line or ""):
        return False, "multiline_judge_stdout"
    if s.startswith("FAIL "):
        return False, "judge_reported_fail"
    if VERDICT_FIELD_RE.fullmatch(s) is None:
        return False, "malformed_verdict"
    if "reasons=" in s:
        return False, "positive_verdict_has_reasons"
    # Unbound parse must not accept positives — require contract in production.
    return False, "verdict_requires_contract"


def run_c2_gate_selftests() -> list:
    fails = []
    primary = expect_for("test_sem_c2_calls_byref")
    assert primary is not None
    primary_res = "res://test_suite/test_sem_c2_calls_byref.vg"

    def primary_path_lines(tier="bytecode"):
        from .c2_fixture_manifest import PRIMARY_MOD

        out = []
        for fn in ("StandaloneByRef", "ExprByRef", "NestedOuter", "RecAdd"):
            out.append(f'VG_SEM_PATH path={tier} fn={fn} mod="{PRIMARY_MOD}"')
        return out

    def body_from_labels(
        labels,
        *,
        known="C2_KNOWN_FAIL index_evals=2 want=1",
        summary="PASS: sem_c2_calls_byref",
        c2sum="C2_SUMMARY passed=15 failed=0",
        typed=True,
        extra_lines=None,
        path_tier="bytecode",
        with_paths=True,
    ):
        lines = []
        if with_paths:
            lines.extend(primary_path_lines(path_tier))
        for lab in labels:
            if typed and lab != "nested event order":
                lines.append(f"PASS: {lab} type=Integer")
            elif typed and lab == "nested event order":
                lines.append(f"PASS: {lab} type=String")
            else:
                lines.append(f"PASS: {lab}")
        if c2sum:
            lines.append(c2sum)
        if extra_lines:
            lines.extend(extra_lines)
        if known:
            lines.append(known)
        if summary:
            lines.append(summary)
        lines.append("VG_SUITE_COMPLETED")
        return "\n".join(lines) + "\n"

    def must_reject(label, text, exit_code=0, mode="default", **kwargs):
        v = judge_c2_log(
            text,
            exit_code=exit_code,
            resource=primary_res,
            mode=mode,
            **kwargs,
        )
        if v.ok:
            fails.append(f"MISS:c2_gate_accepts_{label}")

    def must_accept(label, text, exit_code=0, mode="default", **kwargs):
        v = judge_c2_log(
            text,
            exit_code=exit_code,
            resource=primary_res,
            mode=mode,
            **kwargs,
        )
        if not v.ok:
            fails.append(f"MISS:c2_gate_rejects_{label}:{v.reasons}")

    clean = body_from_labels(list(primary.pass_labels))
    must_accept("clean_primary", clean)
    must_accept(
        "clean_primary_forced_ast",
        body_from_labels(list(primary.pass_labels), path_tier="ast"),
        mode="forced_ast",
    )

    must_reject(
        "script_error_zero_pass",
        "SCRIPT ERROR: Invalid call. Nonexistent function.\nVG_SUITE_COMPLETED\n",
        exit_code=17,
    )
    must_reject("nonzero_only", clean, exit_code=17)
    must_reject("no_completion", clean.replace("VG_SUITE_COMPLETED\n", ""))
    must_reject(
        "duplicate_done",
        clean.replace(
            "VG_SUITE_COMPLETED\n", "VG_SUITE_COMPLETED\nVG_SUITE_COMPLETED\n"
        ),
    )
    must_reject(
        "malformed_completion",
        clean.replace("VG_SUITE_COMPLETED\n", "VG_SUITE_COMPLETED \n"),
    )
    must_reject(
        "records_after_completion",
        clean.replace("VG_SUITE_COMPLETED\n", "VG_SUITE_COMPLETED\nPASS: late\n"),
    )
    must_reject(
        "fail_line",
        body_from_labels(list(primary.pass_labels)).replace(
            "PASS: indexed ByRef write-back slot type=Integer\n"
            "C2_SUMMARY passed=15 failed=0",
            "FAIL: indexed ByRef write-back slot\n"
            "C2_SUMMARY passed=14 failed=1",
        ),
    )
    for bad in (0, 1, 3, 999):
        must_reject(
            f"index_evals_{bad}",
            body_from_labels(
                list(primary.pass_labels),
                known=f"C2_KNOWN_FAIL index_evals={bad} want=1",
            ),
        )
    must_reject(
        "duplicate_known_index",
        body_from_labels(list(primary.pass_labels)).replace(
            "C2_KNOWN_FAIL index_evals=2 want=1\n",
            "C2_KNOWN_FAIL index_evals=2 want=1\n"
            "C2_KNOWN_FAIL index_evals=2 want=1\n",
        ),
    )
    must_reject(
        "malformed_known_fail",
        body_from_labels(
            list(primary.pass_labels),
            known="C2_KNOWN_FAIL index_evals=two want=1",
        ),
    )
    must_reject(
        "missing_known_index",
        body_from_labels(list(primary.pass_labels), known=None),
    )
    must_reject(
        "malformed_extra_summary",
        body_from_labels(
            list(primary.pass_labels),
            extra_lines=["C2_SUMMARY garbage"],
        ),
    )

    dropped = list(primary.pass_labels)
    dropped.pop(3)
    must_reject(
        "dropped_assertion",
        body_from_labels(dropped, c2sum="C2_SUMMARY passed=14 failed=0"),
    )
    must_reject(
        "inconsistent_summary",
        body_from_labels(
            list(primary.pass_labels), c2sum="C2_SUMMARY passed=14 failed=0"
        ),
    )
    must_reject(
        "missing_summary_pass",
        body_from_labels(list(primary.pass_labels), summary=""),
    )
    must_reject(
        "missing_c2_summary",
        body_from_labels(list(primary.pass_labels), c2sum=""),
    )

    # Unknown fixture / same-basename alternate path
    v = judge_c2_log(
        "PASS: arbitrary\nVG_SUITE_COMPLETED\n",
        base="unknown_fixture",
    )
    if v.ok:
        fails.append("MISS:c2_gate_accepts_unknown_fixture")
    v = judge_c2_log(
        clean,
        resource="res://other_suite/test_sem_c2_calls_byref.vg",
    )
    if v.ok:
        fails.append("MISS:c2_gate_accepts_same_basename_other_dir")

    # Path contracts: wrong module / missing mod / forged caller identity
    from .c2_fixture_manifest import PRIMARY_MOD

    wrong_mod = body_from_labels(
        list(primary.pass_labels),
        with_paths=False,
        extra_lines=[
            f'VG_SEM_PATH path=bytecode fn=StandaloneByRef mod="res://test_suite/c2_path_mod_a.vg"',
            f'VG_SEM_PATH path=bytecode fn=ExprByRef mod="{PRIMARY_MOD}"',
            f'VG_SEM_PATH path=bytecode fn=NestedOuter mod="{PRIMARY_MOD}"',
            f'VG_SEM_PATH path=bytecode fn=RecAdd mod="{PRIMARY_MOD}"',
        ],
    )
    must_reject("wrong_module_same_fn", wrong_mod)

    missing_mod = body_from_labels(
        list(primary.pass_labels),
        with_paths=False,
        extra_lines=[
            "VG_SEM_PATH path=bytecode fn=StandaloneByRef",
            f'VG_SEM_PATH path=bytecode fn=ExprByRef mod="{PRIMARY_MOD}"',
            f'VG_SEM_PATH path=bytecode fn=NestedOuter mod="{PRIMARY_MOD}"',
            f'VG_SEM_PATH path=bytecode fn=RecAdd mod="{PRIMARY_MOD}"',
        ],
    )
    must_reject("missing_module_field", missing_mod)

    # Native+AST conflict rejected before success
    conflict = body_from_labels(
        list(primary.pass_labels),
        with_paths=False,
        extra_lines=[
            f'VG_SEM_PATH path=native_t2 fn=StandaloneByRef mod="{PRIMARY_MOD}"',
            f'VG_SEM_PATH path=ast fn=StandaloneByRef mod="{PRIMARY_MOD}"',
            f'VG_SEM_PATH path=bytecode fn=ExprByRef mod="{PRIMARY_MOD}"',
            f'VG_SEM_PATH path=bytecode fn=NestedOuter mod="{PRIMARY_MOD}"',
            f'VG_SEM_PATH path=bytecode fn=RecAdd mod="{PRIMARY_MOD}"',
        ],
    )
    must_reject("native_ast_conflict", conflict)

    # Interpreter rejects native on target
    nat_interp = body_from_labels(
        list(primary.pass_labels),
        with_paths=False,
        extra_lines=[
            f'VG_SEM_PATH path=native_t2 fn=StandaloneByRef mod="{PRIMARY_MOD}"',
            f'VG_SEM_PATH path=bytecode fn=ExprByRef mod="{PRIMARY_MOD}"',
            f'VG_SEM_PATH path=bytecode fn=NestedOuter mod="{PRIMARY_MOD}"',
            f'VG_SEM_PATH path=bytecode fn=RecAdd mod="{PRIMARY_MOD}"',
        ],
    )
    must_reject("interpreter_native", nat_interp, mode="interpreter")

    # Warmup bytecode then native accepted on default
    warm = body_from_labels(
        list(primary.pass_labels),
        with_paths=False,
        extra_lines=[
            f'VG_SEM_PATH path=bytecode fn=StandaloneByRef mod="{PRIMARY_MOD}"',
            f'VG_SEM_PATH path=native_t2 fn=StandaloneByRef mod="{PRIMARY_MOD}"',
            f'VG_SEM_PATH path=bytecode fn=ExprByRef mod="{PRIMARY_MOD}"',
            f'VG_SEM_PATH path=bytecode fn=NestedOuter mod="{PRIMARY_MOD}"',
            f'VG_SEM_PATH path=bytecode fn=RecAdd mod="{PRIMARY_MOD}"',
        ],
    )
    must_accept("warmup_bc_then_native", warm, mode="default")

    # Strict allowed sets: AST-only must reject extra bytecode
    from .path_contract import check_required_path_events

    err = check_required_path_events(
        mode="default",
        target="_Ready",
        want="ast",
        events=[
            {"path": "ast", "fn": "_Ready", "mod": "res://test_suite/test_byref_ast_import.vg"},
            {"path": "bytecode", "fn": "_Ready", "mod": "res://test_suite/test_byref_ast_import.vg"},
        ],
        required_mod="res://test_suite/test_byref_ast_import.vg",
    )
    if err is None:
        fails.append("MISS:ast_only_accepts_extra_bytecode")

    err = check_required_path_events(
        mode="default",
        target="X",
        want="bytecode",
        events=[
            {"path": "bytecode", "fn": "X"},
            {"path": "ast", "fn": "X"},
        ],
    )
    if err is None:
        fails.append("MISS:bytecode_only_accepts_extra_ast")

    err = check_required_path_events(
        mode="interpreter",
        target="X",
        want="ast",
        events=[{"path": "ast", "fn": "X"}, {"path": "bytecode", "fn": "X"}],
    )
    if err is None:
        fails.append("MISS:interpreter_ast_accepts_bytecode")

    # Encoding round-trip / rejection
    from .path_contract import decode_mod, encode_mod

    for sample in (
        'res://has space/x.vg',
        'res://has%22quote.vg',
        'res://a%b.vg',
        'res://q"uote.vg',
    ):
        enc = encode_mod(sample)
        try:
            dec = decode_mod(enc)
        except ValueError as exc:
            fails.append(f"MISS:encode_roundtrip_error:{sample}:{exc}")
            continue
        if dec != sample:
            fails.append(f"MISS:encode_roundtrip:{sample!r}->{dec!r}")
    try:
        decode_mod("%ZZ")
        fails.append("MISS:decode_accepts_bad_hex")
    except ValueError:
        pass
    try:
        decode_mod("%1")
        fails.append("MISS:decode_accepts_truncated_percent")
    except ValueError:
        pass

    # AST-only imported caller: otherwise clean + incompatible extra bytecode
    from .c2_fixture_manifest import AST_IMPORT_HELPER as _AH

    ast_caller = "res://test_suite/test_byref_ast_import.vg"
    ast_fix = expect_for("test_byref_ast_import")
    assert ast_fix is not None
    lines = [
        f'VG_SEM_PATH path=ast fn=_Ready mod="{ast_caller}"',
        f'VG_SEM_PATH path=bytecode fn=_Ready mod="{ast_caller}"',
        f'VG_SEM_PATH path=bytecode fn=FillBox mod="{_AH}"',
    ]
    for lab in ast_fix.pass_labels:
        lines.append(f"PASS: {lab}")
    lines.append("VG_SUITE_COMPLETED")
    v = judge_c2_log(
        "\n".join(lines) + "\n",
        resource="res://test_suite/test_byref_ast_import.vg",
        mode="default",
    )
    if v.ok:
        fails.append("MISS:gate_accepts_ast_only_with_bytecode_extra")

    # Legacy opt-in still works when asked
    v = judge_c2_log(
        "PASS: arbitrary\nVG_SUITE_COMPLETED\n",
        base="unknown_fixture",
        allow_legacy_unknown=True,
    )
    if not v.ok:
        fails.append(f"MISS:legacy_unknown_rejected:{v.reasons}")

    byval = expect_for("test_byref_byval")
    assert byval is not None
    byval_res = "res://test_suite/test_byref_byval.vg"
    trunc = "PASS: byref_modifies_caller\nVG_SUITE_COMPLETED\n"
    v = judge_c2_log(trunc, exit_code=0, resource=byval_res)
    if v.ok:
        fails.append("MISS:c2_gate_accepts_truncated_prior_art")
    full_byval = "\n".join(f"PASS: {x}" for x in byval.pass_labels)
    full_byval += "\nVG_SUITE_COMPLETED\n"
    v = judge_c2_log(full_byval, exit_code=0, resource=byval_res)
    if not v.ok:
        fails.append(f"MISS:c2_gate_rejects_full_prior_art:{v.reasons}")

    # Structured verdict contract
    contract = VerdictContract(
        base="test_sem_c2_calls_byref",
        mode="default",
        child_exit=0,
        expect=primary,
        resource=primary_res,
    )
    good = (
        "OK test_sem_c2_calls_byref mode=default exit=0 "
        "pass_lines=16 fail_lines=0 done=1 known=[index_evals=2 want=1]"
    )
    ok, detail = validate_positive_verdict(good, contract)
    if not ok:
        fails.append(f"MISS:verdict_rejects_good:{detail}")

    for label, bad in (
        (
            "wrong_fixture_mode_exit",
            "OK wrong_fixture mode=wrong exit=17 pass_lines=0 fail_lines=99 done=0",
        ),
        (
            "trailing_garbage",
            "OK test_sem_c2_calls_byref mode=default exit=0 "
            "pass_lines=16 fail_lines=0 done=1TRAILING_GARBAGE",
        ),
        (
            "hide_nonzero_child",
            "OK test_sem_c2_calls_byref mode=default exit=0 "
            "pass_lines=16 fail_lines=0 done=1 known=[index_evals=2 want=1]",
        ),
        (
            "reasons_on_ok",
            good + " reasons=[x]",
        ),
    ):
        c = contract
        if label == "hide_nonzero_child":
            c = VerdictContract(
                base=contract.base,
                mode=contract.mode,
                child_exit=17,
                expect=primary,
                resource=primary_res,
            )
        ok, _ = validate_positive_verdict(bad, c)
        if ok:
            fails.append(f"MISS:verdict_accepts_{label}")

    # Unbound parse_verdict_line must not accept
    ok, _ = parse_verdict_line(good)
    if ok:
        fails.append("MISS:unbound_parse_accepts_ok")

    return fails


def main(argv: Optional[list] = None) -> int:
    import argparse

    p = argparse.ArgumentParser(description="Judge a C2 fixture Godot log")
    p.add_argument("--log", type=Path, required=True)
    p.add_argument("--exit-code", type=int, default=0)
    p.add_argument("--base", default="")
    p.add_argument("--resource", default="")
    p.add_argument("--mode", default="default")
    p.add_argument("--min-pass", type=int, default=None)
    p.add_argument("--require-known-index-fail", action="store_true")
    p.add_argument("--allow-legacy-unknown", action="store_true")
    p.add_argument("--summary-line", action="store_true")
    args = p.parse_args(argv)
    text = args.log.read_text(encoding="utf-8", errors="replace")
    base = args.base
    if not base and args.resource:
        resolved = resolve_resource(args.resource)
        if resolved:
            base = resolved[0]
    if not base:
        base = "unknown"
    v = judge_c2_log(
        text,
        exit_code=args.exit_code,
        base=args.base,
        resource=args.resource,
        mode=args.mode,
        min_pass=args.min_pass,
        require_known_index_fail=args.require_known_index_fail,
        allow_legacy_unknown=args.allow_legacy_unknown,
    )
    print(format_verdict(base, args.mode, v))
    if not args.summary_line:
        for r in v.reasons:
            print(" ", r)
    # Machine-readable per-module/function/path counts beside the log when asked.
    if args.resource and v.module_path_counts:
        import json

        side = args.log.with_suffix(args.log.suffix + ".path_counts.json")
        if str(args.log).endswith(".log"):
            side = Path(str(args.log)[: -len(".log")] + ".path_counts.json")
        try:
            side.write_text(
                json.dumps(v.module_path_counts, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )
        except OSError:
            pass
    return 0 if v.ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
