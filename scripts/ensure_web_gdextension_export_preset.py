#!/usr/bin/env python3
"""Ensure Web export preset has GDExtension support enabled (required for VG WASM)."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


def enable_web_extensions(text: str) -> tuple[str, bool]:
    if 'platform="Web"' not in text:
        return text, False
    if "variant/extensions_support=true" in text:
        return text, False
    updated, n = re.subn(
        r"(platform=\"Web\"[\s\S]*?\[preset\.\d+\.options\][\s\S]*?)variant/extensions_support=false",
        r"\1variant/extensions_support=true",
        text,
        count=1,
    )
    if n:
        return updated, True
    # Option line missing — insert after Web preset's [preset.N.options] header
    updated, n = re.subn(
        r"(platform=\"Web\"[\s\S]*?(\[preset\.\d+\.options\])\s*\n)",
        r"\1variant/extensions_support=true\n",
        text,
        count=1,
    )
    return updated, n > 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, help="Project directory (contains export_presets.cfg)")
    args = parser.parse_args()
    cfg = Path(args.project).resolve() / "export_presets.cfg"
    if not cfg.is_file():
        print(f"no export_presets.cfg in {args.project} (unchanged)", file=sys.stderr)
        return 0

    text = cfg.read_text(encoding="utf-8")
    updated, changed = enable_web_extensions(text)
    if not changed:
        print("Web GDExtension export preset OK (unchanged)", file=sys.stderr)
        return 0
    cfg.write_text(updated, encoding="utf-8")
    print(f"enabled variant/extensions_support for Web -> {cfg}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
