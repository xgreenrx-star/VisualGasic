#!/usr/bin/env python3
"""
Aggregate per-attempt JSON files in results/ into a summary Markdown table.

Usage:
    python aggregate.py results/                    # all model dirs
    python aggregate.py results/gpt-4o/             # one model
"""
from __future__ import annotations

import json
import sys
from collections import defaultdict
from pathlib import Path


def load_attempts(root: Path) -> list[dict]:
    out = []
    for p in root.rglob("*.json"):
        if p.name.startswith("_"):
            continue
        try:
            r = json.loads(p.read_text())
        except json.JSONDecodeError:
            continue
        if "parse_ok" in r and "language" in r:
            out.append(r)
    return out


def main(argv: list[str]) -> int:
    if len(argv) < 1:
        print("usage: aggregate.py <results-dir>", file=sys.stderr)
        return 2

    root = Path(argv[0])
    attempts = load_attempts(root)
    if not attempts:
        print("# AI Correctness Benchmark — no results found", flush=True)
        return 1

    # Group: model -> language -> [results]
    grouped: dict[str, dict[str, list[dict]]] = defaultdict(lambda: defaultdict(list))
    for a in attempts:
        grouped[a["model"]][a["language"]].append(a)

    print("# AI Correctness Benchmark — Results")
    print()
    print("First-attempt parse-success rate, by model and language.")
    print()

    languages = ["vg", "gdscript", "python", "typescript"]
    header = "| Model | " + " | ".join(languages) + " | N |"
    sep    = "|---|" + "|".join(["---:"] * len(languages)) + "|---:|"
    print(header)
    print(sep)
    for model in sorted(grouped):
        cells = [model]
        n_total = 0
        for lang in languages:
            rs = grouped[model].get(lang, [])
            if not rs:
                cells.append("—")
                continue
            ok = sum(1 for r in rs if r["parse_ok"])
            n_total = max(n_total, len(rs))
            cells.append(f"{ok}/{len(rs)}  ({100*ok/len(rs):.0f}%)")
        cells.append(str(n_total))
        print("| " + " | ".join(cells) + " |")

    # By-category breakdown for the first model only (illustrative)
    first_model = sorted(grouped)[0]
    print()
    print(f"## Per-category breakdown ({first_model})")
    print()
    by_cat: dict[str, dict[str, list[dict]]] = defaultdict(lambda: defaultdict(list))
    for a in attempts:
        if a["model"] != first_model:
            continue
        by_cat[a["category"]][a["language"]].append(a)

    header = "| Category | " + " | ".join(languages) + " |"
    sep    = "|---|" + "|".join(["---:"] * len(languages)) + "|"
    print(header)
    print(sep)
    for cat in sorted(by_cat):
        cells = [cat]
        for lang in languages:
            rs = by_cat[cat].get(lang, [])
            if not rs:
                cells.append("—")
                continue
            ok = sum(1 for r in rs if r["parse_ok"])
            cells.append(f"{ok}/{len(rs)}")
        print("| " + " | ".join(cells) + " |")

    # Failed attempts list (truncated)
    print()
    print("## Failed attempts (sample)")
    print()
    fails = [a for a in attempts if not a["parse_ok"]][:20]
    if not fails:
        print("_(none)_")
    else:
        for a in fails:
            msg = (a.get("checker_msg") or "").splitlines()[0][:120]
            print(f"- **{a['model']}** / {a['language']} / {a['id']} ({a['category']}): `{msg}`")

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
