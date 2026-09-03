#!/usr/bin/env python3
"""Verify relative markdown links and common doc path references."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[1]

SKIP_DIR_PARTS = {
    ".git",
    "node_modules",
    "demo/addons",
    ".gradle",
    "obj",
    "bin",
}

MD_LINK = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
HTML_HREF = re.compile(r"""href=["']([^"']+)["']""", re.I)
CORPUS_TABLE = re.compile(r"^\|\s+([0-9a-z_/]+)\s+\|", re.I)
GITHUB_BLOB = re.compile(
    r"github\.com/xgreenrx-star/VisualGasic/blob/[^/]+/(.+?)(?:\)|\"|'|\s|$)"
)


def should_skip(path: Path) -> bool:
    parts = set(path.parts)
    if parts & SKIP_DIR_PARTS:
        return True
    return any(part.startswith(".") and part not in {".github"} for part in path.parts)


def resolve_href(source: Path, href: str) -> Path | None:
    href = href.strip()
    if not href or href.startswith("#"):
        return None
    if href.startswith(("http://", "https://", "mailto:", "data:")):
        return None
    href = unquote(href.split("#", 1)[0].split("?", 1)[0])
    if not href:
        return None
    if href.startswith("/"):
        return ROOT / href.lstrip("/")
    return (source.parent / href).resolve()


def check_exists(target: Path) -> bool:
    if target.exists():
        return True
    # Allow corpus table prefix rows.
    if target.suffix == "" and list(target.parent.glob(f"{target.name}*.vg")):
        return True
    return False


def iter_markdown_files() -> list[Path]:
    files: list[Path] = []
    for path in ROOT.rglob("*.md"):
        if should_skip(path.relative_to(ROOT)):
            continue
        files.append(path)
    return sorted(files)


def main() -> int:
    broken: list[str] = []
    checked = 0

    for md in iter_markdown_files():
        text = md.read_text(encoding="utf-8", errors="replace")
        rel = md.relative_to(ROOT)
        for pattern in (MD_LINK, HTML_HREF):
            for href in pattern.findall(text):
                target = resolve_href(md, href)
                if target is None:
                    continue
                checked += 1
                try:
                    rel_target = target.relative_to(ROOT)
                except ValueError:
                    rel_target = target
                if not check_exists(target):
                    broken.append(f"{rel}: ]{href}[ -> missing {rel_target}")

        for match in GITHUB_BLOB.finditer(text):
            repo_path = unquote(match.group(1).rstrip(".)"))
            target = ROOT / repo_path
            checked += 1
            if not check_exists(target):
                broken.append(f"{rel}: github blob -> missing {repo_path}")

    corpus_readme = ROOT / "corpus/README.md"
    if corpus_readme.exists():
        for line in corpus_readme.read_text(encoding="utf-8").splitlines():
            m = CORPUS_TABLE.match(line)
            if not m:
                continue
            path_text = m.group(1).strip()
            if not re.match(r"[0-9]{2}_", path_text):
                continue
            if path_text.endswith("(all)"):
                continue
            if not path_text.endswith(".vg"):
                matches = list((ROOT / "corpus").glob(f"**/{Path(path_text).name}*.vg"))
                if not matches:
                    checked += 1
                    broken.append(f"corpus/README.md: table path unresolved: {path_text}")
                continue
            target = ROOT / "corpus" / path_text.split("/", 1)[-1]
            checked += 1
            if not target.exists():
                broken.append(f"corpus/README.md: table path missing: {path_text}")

    # README corpus quick links (explicit list).
    readme = ROOT / "README.md"
    if readme.exists():
        for href in MD_LINK.findall(readme.read_text(encoding="utf-8")):
            if href.startswith("corpus/"):
                checked += 1
                if not (ROOT / href).exists():
                    broken.append(f"README.md: corpus link missing: {href}")

    print(f"Checked {checked} link references.")
    if broken:
        print(f"\n{len(broken)} broken link(s):\n")
        for item in broken:
            print(f"  - {item}")
        return 1

    print("All checked links resolve.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
