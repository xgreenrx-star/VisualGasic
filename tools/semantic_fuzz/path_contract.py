"""Shared execution-path contract checks (Phase 1 + C2 module-qualified)."""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Dict, FrozenSet, List, Optional, Set


KNOWN_TIERS = frozenset({"ast", "bytecode", "native_t2", "native_t3"})
KNOWN_MODES = frozenset({"forced_ast", "interpreter", "default", "tier3"})
KNOWN_WANTS = frozenset(
    {
        "ast",
        "bytecode",
        "native_t2",
        "native_t3",
        "native_t3_or_native_t2",
        "bytecode_or_native",
    }
)


@dataclass(frozen=True)
class PathRequirement:
    fn: str
    mod: str
    mode_paths: Dict[str, str]


def encode_mod(mod: str) -> str:
    """Match C++ vgsem::encode_mod (%, quote, LF, CR)."""
    out = []
    for ch in mod:
        if ch == "%":
            out.append("%25")
        elif ch == '"':
            out.append("%22")
        elif ch == "\n":
            out.append("%0A")
        elif ch == "\r":
            out.append("%0D")
        else:
            out.append(ch)
    return "".join(out)


def decode_mod(encoded: str) -> str:
    """Left-to-right %XX decode; reject malformed sequences."""
    out = []
    i = 0
    while i < len(encoded):
        if encoded[i] == "%":
            if i + 2 >= len(encoded):
                raise ValueError(f"malformed_mod_encoding:truncated %{encoded[i:]!r}")
            hx = encoded[i + 1 : i + 3]
            if not re.fullmatch(r"[0-9A-Fa-f]{2}", hx):
                raise ValueError(f"malformed_mod_encoding:bad hex %{hx}")
            out.append(chr(int(hx, 16)))
            i += 3
        else:
            out.append(encoded[i])
            i += 1
    return "".join(out)


def parse_path_event_line(line: str) -> Optional[Dict[str, str]]:
    s = line.rstrip("\r\n")
    if not s.startswith("VG_SEM_PATH"):
        return None
    m = re.fullmatch(
        r'VG_SEM_PATH path=(?P<path>\S+) fn=(?P<fn>\S+)'
        r'(?: mod="(?P<mod>[^"]*)")?\s*',
        s,
    )
    if not m:
        raise ValueError(f"malformed path line: {s}")
    path = m.group("path")
    if path not in KNOWN_TIERS:
        raise ValueError(f"unknown path tier: {path}")
    out = {"path": path, "fn": m.group("fn")}
    if m.group("mod") is not None:
        out["mod"] = decode_mod(m.group("mod"))
    return out


def path_counts(
    events: List[Dict[str, str]],
    *,
    required_mod: Optional[str] = None,
) -> Dict[str, Dict[str, int]]:
    counts: Dict[str, Dict[str, int]] = {}
    for e in events:
        if required_mod is not None and e.get("mod") != required_mod:
            continue
        fn = e["fn"]
        path = e["path"]
        counts.setdefault(fn, {})
        counts[fn][path] = counts[fn].get(path, 0) + 1
    return counts


def module_path_counts(
    events: List[Dict[str, str]],
) -> Dict[str, Dict[str, Dict[str, int]]]:
    out: Dict[str, Dict[str, Dict[str, int]]] = {}
    for e in events:
        mod = e.get("mod", "")
        fn = e["fn"]
        path = e["path"]
        out.setdefault(mod, {}).setdefault(fn, {})
        out[mod][fn][path] = out[mod][fn].get(path, 0) + 1
    return out


def allowed_tiers_for(want: str) -> FrozenSet[str]:
    if want == "ast":
        return frozenset({"ast"})
    if want == "bytecode":
        return frozenset({"bytecode"})
    if want == "native_t2":
        return frozenset({"native_t2", "bytecode"})  # warmup allowed
    if want == "native_t3":
        return frozenset({"native_t3", "bytecode"})
    if want == "native_t3_or_native_t2":
        return frozenset({"native_t2", "native_t3", "bytecode"})
    if want == "bytecode_or_native":
        return frozenset({"bytecode", "native_t2", "native_t3"})
    raise ValueError(f"unknown want: {want}")


def check_target_path(
    *,
    mode: str,
    target: str,
    want: str,
    counts: Dict[str, int],
    fallback_contract: Optional[str] = None,
) -> Optional[str]:
    """Strict allowed-set check + mode/fallback conflict rules."""
    if mode not in KNOWN_MODES:
        return f"unknown_mode:{mode}"
    if want not in KNOWN_WANTS:
        return f"unknown_required_path:{want}"

    observed: Set[str] = {t for t, n in counts.items() if n > 0}
    unknown = observed - KNOWN_TIERS
    if unknown:
        return f"{target} unknown path tiers={sorted(unknown)}"

    try:
        allowed = set(allowed_tiers_for(want))
    except ValueError as exc:
        return str(exc)

    # Mode hard constraints (before presence).
    if mode == "interpreter" and (
        counts.get("native_t2", 0) > 0 or counts.get("native_t3", 0) > 0
    ):
        return f"{target} executed native under interpreter mode"
    if mode == "forced_ast" and (
        counts.get("bytecode", 0) > 0
        or counts.get("native_t2", 0) > 0
        or counts.get("native_t3", 0) > 0
    ):
        return f"{target} executed non-AST under forced_ast"
    if fallback_contract and mode in ("default", "tier3"):
        if counts.get("native_t2", 0) > 0 or counts.get("native_t3", 0) > 0:
            return f"{target} entered native despite fallback_contract={fallback_contract}"

    # Strict: any observed tier outside the allowed set is a failure.
    disallowed = observed - allowed
    if disallowed:
        # Keep "AST" substring for Phase 1 harness negative probes.
        label = "AST" if disallowed == {"ast"} else sorted(disallowed)
        return (
            f"{target} executed {label} incompatible with required {want} "
            f"(allowed={sorted(allowed)} observed={sorted(observed)})"
        )

    # Presence of required tier(s).
    if want == "ast":
        if counts.get("ast", 0) <= 0:
            return f"required path ast not observed for path_target={target} (counts={counts})"
        return None
    if want == "bytecode":
        if counts.get("bytecode", 0) <= 0:
            return f"required path bytecode not observed for path_target={target} (counts={counts})"
        return None
    if want == "native_t2":
        if counts.get("native_t2", 0) <= 0:
            return f"required path native_t2 not observed for path_target={target} (counts={counts})"
        return None
    if want == "native_t3":
        if counts.get("native_t3", 0) <= 0:
            return f"required path native_t3 not observed for path_target={target} (counts={counts})"
        return None
    if want == "native_t3_or_native_t2":
        if counts.get("native_t2", 0) + counts.get("native_t3", 0) <= 0:
            return f"required native path never entered for path_target={target}"
        return None
    if want == "bytecode_or_native":
        if (
            counts.get("bytecode", 0)
            + counts.get("native_t2", 0)
            + counts.get("native_t3", 0)
            <= 0
        ):
            return (
                f"required bytecode_or_native not observed for path_target={target} "
                f"(counts={counts})"
            )
        return None
    return f"unhandled want:{want}"


def check_required_path_events(
    *,
    mode: str,
    target: str,
    want: Optional[str],
    events: List[Dict[str, str]],
    required_mod: Optional[str] = None,
    fallback_contract: Optional[str] = None,
) -> Optional[str]:
    if not want:
        return None
    if not events:
        return "no VG_SEM_PATH events (rebuild with instrumentation?)"
    if required_mod is not None:
        matched = [
            e
            for e in events
            if e.get("fn") == target and e.get("mod") == required_mod
        ]
        if not matched:
            same_fn = [e for e in events if e.get("fn") == target]
            if same_fn and all(not e.get("mod") for e in same_fn):
                return f"missing module field for path_target={target} (module-qualified contract)"
            wrong = [
                e.get("mod")
                for e in same_fn
                if e.get("mod") and e.get("mod") != required_mod
            ]
            if wrong:
                return (
                    f"wrong module for path_target={target}: "
                    f"got={wrong[0]!r} want={required_mod!r}"
                )
            return (
                f"no module-qualified events for path_target={target} "
                f"mod={required_mod!r}"
            )
        c = path_counts(matched).get(target, {})
    else:
        c = path_counts(events).get(target, {})
    return check_target_path(
        mode=mode,
        target=target,
        want=want,
        counts=c,
        fallback_contract=fallback_contract,
    )


def check_c2_path_requirements(
    events: List[Dict[str, str]],
    *,
    mode: str,
    requirements: List[PathRequirement],
) -> List[str]:
    reasons: List[str] = []
    for req in requirements:
        want = req.mode_paths.get(mode)
        if not want:
            continue
        err = check_required_path_events(
            mode=mode,
            target=req.fn,
            want=want,
            events=events,
            required_mod=req.mod,
        )
        if err:
            reasons.append(f"path_contract:{req.fn}@{req.mod}:{err}")
    return reasons
