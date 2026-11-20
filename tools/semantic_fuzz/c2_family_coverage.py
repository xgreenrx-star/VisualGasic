"""Fail-closed C2 family coverage gate for bounded CI campaigns."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Iterable, Optional, Sequence

from .generator_c2 import C2_FAMILIES

# Required for CI / bounded gate — all initial generator families.
REQUIRED_C2_FAMILIES: tuple[str, ...] = tuple(C2_FAMILIES)

REQUIRED_IMPORT_FAMILIES: tuple[str, ...] = (
    "c2_import_byref",
    "c2_import_byval_expr",
    "c2_import_local_caller",
    "c2_import_nested",
)


def check_family_coverage(
    families_present: Iterable[str],
    *,
    required: Sequence[str] = REQUIRED_C2_FAMILIES,
) -> Optional[str]:
    """Return refusal message if any required family is missing."""
    have = set(families_present)
    missing = [f for f in required if f not in have]
    if missing:
        return f"c2_family_coverage_missing:{','.join(missing)}"
    return None


def check_campaign_report(report_path: Path) -> Optional[str]:
    report = json.loads(Path(report_path).read_text(encoding="utf-8"))
    fams = report.get("families") or {}
    msg = check_family_coverage(fams.keys())
    if msg:
        return msg
    # Imported helpers must show non-primary module attribution when present.
    pbm = report.get("path_by_mode_module") or report.get("path_by_module") or {}
    # Flatten: look for any mod path containing an imported .vg (not case.vg)
    mods: set[str] = set()
    if report.get("path_by_mode_module"):
        for _mode, by_mod in report["path_by_mode_module"].items():
            mods.update(by_mod.keys())
    else:
        mods.update(pbm.keys())
    import_mods = [
        m
        for m in mods
        if isinstance(m, str)
        and m.endswith(".vg")
        and not m.endswith("/case.vg")
        and "c2_lib_" in m
    ]
    # Only require import-module path hits if import families ran successfully.
    ran_imports = [f for f in REQUIRED_IMPORT_FAMILIES if fams.get(f, 0) > 0]
    if ran_imports and not import_mods:
        return (
            "c2_import_path_attribution_missing:"
            f"families={ran_imports} but no c2_lib_*.vg path mods observed"
        )
    return None


def main(argv: Optional[Sequence[str]] = None) -> int:
    import argparse
    import sys

    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("campaign_report", type=Path)
    args = ap.parse_args(list(argv) if argv is not None else None)
    msg = check_campaign_report(args.campaign_report)
    if msg:
        print(f"FAIL: {msg}", file=sys.stderr)
        return 2
    print("OK: c2 family coverage gate")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
