#!/usr/bin/env python3
"""Append a bytecode baseline refresh entry to the changelog."""
from __future__ import annotations

import argparse
import json
from datetime import date
from pathlib import Path
from typing import List

HEADING = "### Bytecode Baseline Updates"


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dump",
        default="bytecode_dump.json",
        help="Path to the JSON dump that seeded the new baseline",
    )
    parser.add_argument(
        "--changelog",
        default="README_UPDATES.md",
        help="Markdown file to update",
    )
    return parser.parse_args()


def _load_entries(dump_path: Path) -> List[str]:
    with dump_path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    entries = payload.get("entries", [])
    names: List[str] = []
    for entry in entries:
        name = entry.get("entry_point")
        if isinstance(name, str) and name:
            names.append(name)
    if not names:
        names.append("(no entry points detected)")
    return names


def _ensure_heading(text: str) -> str:
    if HEADING in text:
        return text
    if not text.endswith("\n"):
        text += "\n"
    return f"{text}\n{HEADING}\n"


def _append_entry(changelog: Path, names: List[str]) -> None:
    today = date.today().isoformat()
    summary = ", ".join(names)
    line = f"- {today}: Refreshed bytecode baseline for entries: {summary}.\n"

    existing = changelog.read_text(encoding="utf-8") if changelog.exists() else ""
    updated = _ensure_heading(existing)

    if not updated.endswith("\n"):
        updated += "\n"

    updated = f"{updated}{line}"
    changelog.write_text(updated, encoding="utf-8")


def main() -> int:
    args = _parse_args()
    dump_path = Path(args.dump)
    changelog = Path(args.changelog)

    if not dump_path.exists():
        raise SystemExit(f"Dump file not found: {dump_path}")

    names = _load_entries(dump_path)
    _append_entry(changelog, names)
    print(f"Recorded bytecode baseline refresh in {changelog}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
