#!/usr/bin/env python3
"""Patch a Godot HTML5 export folder for GitHub Pages (no COOP/COEP on the host).

GDExtension WASM needs cross-origin isolation. GitHub Pages cannot set those headers;
ship coi-serviceworker (see godotengine/godot-docs#7084) and strip the Godot logo splash.
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
COI_QUIET = '<script>window.coi = Object.assign({ quiet: true }, window.coi || {});</script>'

SPLASH_IMG_RE = re.compile(
    r"\s*<img id=\"status-splash\"[^>]*>\s*",
    re.MULTILINE,
)
LOADING_HINT_HTML = (
    "Loading Climatist... About 45&nbsp;MB of engine + VM WASM on first visit. "
    "On a slow connection this can take several minutes; watch the progress bar below. "
    "Later visits use the browser cache and start much faster."
)
SPLASH_HINT = (
    f'\n\t\t<p id="status-hint" style="margin:0 1.5rem;font:14px/1.4 sans-serif;color:#aaa;text-align:center">'
    f"{LOADING_HINT_HTML}</p>\n"
)
STATUS_HINT_RE = re.compile(
    r'<p id="status-hint"[^>]*>.*?</p>',
    re.DOTALL,
)

EXTRA_CSS = """
#status-splash { display: none !important; }
#status-hint { max-width: 32rem; }
#status { background-color: #000; }
"""


def fetch_coi(dest: Path) -> None:
    if dest.is_file() and dest.stat().st_size > 100:
        return
    print(f"Fetching {COI_URL} -> {dest}", file=sys.stderr)
    with urllib.request.urlopen(COI_URL, timeout=60) as resp:
        dest.write_bytes(resp.read())


def _inject_css(text: str) -> tuple[str, bool]:
    if "#status-splash { display: none" in text:
        return text, False
    marker = "</style>"
    if marker not in text:
        return text, False
    return text.replace(marker, EXTRA_CSS + marker, 1), True


def _strip_splash_img(text: str) -> tuple[str, bool]:
    if SPLASH_IMG_RE.search(text):
        text = SPLASH_IMG_RE.sub(SPLASH_HINT, text, count=1)
        return text, True
    if 'id="status-hint"' in text:
        return text, False
    # Fallback: force hide via class Godot already understands
    if 'id="status-splash"' in text and "show-image--false" not in text:
        text = text.replace("show-image--true", "show-image--false", 1)
        return text, True
    return text, False


def _inject_coi(text: str) -> tuple[str, bool]:
    changed = False
    if COI_QUIET not in text:
        m = re.search(r"(\s*<script src=\"coi-serviceworker\.js\"></script>)", text)
        if m:
            insert = f"\n\t\t{COI_QUIET}\n"
            text = text[: m.start(1)] + insert + text[m.start(1) :]
            changed = True
        elif COI_NAME not in text:
            m = re.search(r"(\s*<script src=\"index\.js\"></script>)", text)
            if not m:
                print("error: could not find index.js script tag", file=sys.stderr)
                return text, False
            block = f"\n\t\t{COI_QUIET}\n\t\t{COI_SCRIPT}\n"
            text = text[: m.start(1)] + block + text[m.start(1) :]
            changed = True
    return text, changed


def _update_loading_hint(text: str) -> tuple[str, bool]:
    new_p = (
        f'<p id="status-hint" style="margin:0 1.5rem;font:14px/1.4 sans-serif;color:#aaa;text-align:center">'
        f"{LOADING_HINT_HTML}</p>"
    )
    if STATUS_HINT_RE.search(text):
        updated, n = STATUS_HINT_RE.subn(new_p, text, count=1)
        return updated, n > 0 and updated != text
    return text, False


def patch_index(html_path: Path) -> bool:
    text = html_path.read_text(encoding="utf-8")
    any_changed = False
    text, c = _inject_css(text)
    any_changed |= c
    text, c = _strip_splash_img(text)
    any_changed |= c
    text, c = _update_loading_hint(text)
    any_changed |= c
    text, c = _inject_coi(text)
    any_changed |= c
    if any_changed:
        html_path.write_text(text, encoding="utf-8")
    return any_changed


def main() -> int:
    parser = argparse.ArgumentParser(description="Patch Godot web export for GitHub Pages")
    parser.add_argument("export_dir", type=Path, help="Folder containing index.html")
    args = parser.parse_args()
    root = args.export_dir.resolve()
    index = root / "index.html"
    if not index.is_file():
        print(f"error: missing {index}", file=sys.stderr)
        return 1
    fetch_coi(root / COI_NAME)
    changed = patch_index(index)
    print("GitHub Pages web patch OK" + (" (index.html updated)" if changed else " (already patched)"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
