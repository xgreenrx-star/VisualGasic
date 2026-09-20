#!/usr/bin/env python3
"""Remove dev-only tweak/debug hooks before HTML5 export (smaller, fewer editor deps)."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


def strip_plugin_line(text: str, plugin_path: str) -> str:
    pattern = re.compile(
        r'^\s*[^#\n]*preload\s*\(\s*"[^"]*' + re.escape(plugin_path) + r'"[^)]*\).*$',
        re.MULTILINE,
    )
    return pattern.sub("", text)


def main() -> int:
    parser = argparse.ArgumentParser(description="Strip tweak overlay for web export")
    parser.add_argument(
        "--project",
        type=Path,
        default=Path("."),
        help="Godot project root (contains project.godot)",
    )
    args = parser.parse_args()
    project = args.project.resolve()
    plugin_gd = project / "addons" / "visual_gasic" / "visual_gasic_plugin.gd"
    if not plugin_gd.is_file():
        print(f"skip: no {plugin_gd}", file=sys.stderr)
        return 0

    original = plugin_gd.read_text(encoding="utf-8")
    updated = original
    for frag in ("vg_tweak_overlay.gd", "vg_debug_handler.gd"):
        updated = strip_plugin_line(updated, frag)

    if updated != original:
        plugin_gd.write_text(updated, encoding="utf-8")
        print(f"stripped dev hooks in {plugin_gd}")
    else:
        print("no tweak/debug preload lines found (unchanged)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
