#!/usr/bin/env python3
"""Patch a Godot HTML5 export folder for GitHub Pages (no COOP/COEP on the host).

GDExtension WASM needs cross-origin isolation. GitHub Pages cannot set those headers;
Godot's PWA export helps when enabled, but we also ship coi-serviceworker as a belt-
and-suspenders fix (see godotengine/godot-docs#7084).
"""
from __future__ import annotations

import argparse
import re
import sys
import urllib.request
from pathlib import Path

COI_URL = "https://raw.githubusercontent.com/gzuidhof/coi-serviceworker/master/coi-serviceworker.js"
COI_NAME = "coi-serviceworker.js"
COI_SCRIPT = f'<script src="{COI_NAME}"></script>'


def fetch_coi(dest: Path) -> None:
    if dest.is_file() and dest.stat().st_size > 100:
        return
    print(f"Fetching {COI_URL} -> {dest}", file=sys.stderr)
    with urllib.request.urlopen(COI_URL, timeout=60) as resp:
        dest.write_bytes(resp.read())


def patch_index(html_path: Path) -> bool:
    text = html_path.read_text(encoding="utf-8")
    if COI_NAME in text:
        return False
    # Must run before Godot's index.js (registers SW, may reload once).
    m = re.search(r"(\s*<script src=\"index\.js\"></script>)", text)
    if not m:
        print(f"error: could not find index.js script tag in {html_path}", file=sys.stderr)
        return False
    insert = f"\n\t\t{COI_SCRIPT}\n"
    html_path.write_text(text[: m.start(1)] + insert + text[m.start(1) :], encoding="utf-8")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="Add coi-serviceworker for GitHub Pages Godot web")
    parser.add_argument("export_dir", type=Path, help="Folder containing index.html")
    args = parser.parse_args()
    root = args.export_dir.resolve()
    index = root / "index.html"
    if not index.is_file():
        print(f"error: missing {index}", file=sys.stderr)
        return 1
    fetch_coi(root / COI_NAME)
    changed = patch_index(index)
    print("GitHub Pages COI patch OK" + (" (index.html updated)" if changed else " (already patched)"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
