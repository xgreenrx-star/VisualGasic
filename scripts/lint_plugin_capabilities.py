#!/usr/bin/env python3
"""
lint_plugin_capabilities.py — VisualGasic CI lint for plugin.cfg files.

Scans every `addons/visual_gasic/plugins/*/plugin.cfg` (canonical only,
not symlinked copies) and reports issues with the [capabilities] block:

  - capabilities outside the documented namespaces:
        asset_editor.*, asset_generator.*, game_builder.*,
        panel.*, command.*, form_designer.*, ui_forms.*,
        ai.*, vector.*
  - extensions with leading dots ("png" is right, ".png" is wrong)
  - extensions that aren't lowercase
  - priority outside the recommended 1..100 range
  - missing or empty `provides`
  - duplicate plugin_id across the registry (folder name collision)

Exit code:
  0  no issues
  1  warnings
  2  errors

Usage:
  scripts/lint_plugin_capabilities.py
  scripts/lint_plugin_capabilities.py --strict   (warnings → errors)
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# ─── Configuration ─────────────────────────────────────────

KNOWN_NAMESPACES = {
    "asset_editor",
    "asset_generator",
    "game_builder",
    "panel",
    "command",
    "form_designer",
    "ui_forms",
    "ai",
    "vector",
}

# Plugin.cfg paths to check. Only scan the canonical addons/ tree —
# every other game_projects/.../addons/visual_gasic is a symlink to it.
ROOT = Path(__file__).resolve().parent.parent
PLUGINS_DIR = ROOT / "addons" / "visual_gasic" / "plugins"

# ─── Tiny .cfg parser ─────────────────────────────────────
# Godot's config format is similar to INI but values are GDScript
# literals. We only need to read strings, string-arrays, and ints.

def parse_godot_cfg(path: Path) -> dict[str, dict[str, object]]:
    sections: dict[str, dict[str, object]] = {}
    current: str | None = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith(";") or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1].strip()
            sections.setdefault(current, {})
            continue
        if "=" not in line or current is None:
            continue
        key, _, val = line.partition("=")
        sections[current][key.strip()] = _parse_value(val.strip())
    return sections


def _parse_value(val: str) -> object:
    if val.startswith('"') and val.endswith('"'):
        return val[1:-1]
    if val.startswith("[") and val.endswith("]"):
        inner = val[1:-1].strip()
        if not inner:
            return []
        out: list[object] = []
        # naive comma split — adequate for string-arrays and int-arrays.
        depth = 0
        cur: list[str] = []
        for ch in inner:
            if ch == "," and depth == 0:
                out.append(_parse_value("".join(cur).strip()))
                cur = []
            else:
                if ch in "([{":
                    depth += 1
                elif ch in ")]}":
                    depth -= 1
                cur.append(ch)
        if cur:
            out.append(_parse_value("".join(cur).strip()))
        return out
    if val in ("true", "false"):
        return val == "true"
    try:
        return int(val)
    except ValueError:
        try:
            return float(val)
        except ValueError:
            return val  # leave as raw string (rare)


# ─── Lint rules ───────────────────────────────────────────

class LintMessage:
    __slots__ = ("path", "level", "msg")

    def __init__(self, path: Path, level: str, msg: str) -> None:
        self.path = path
        self.level = level
        self.msg = msg

    def __str__(self) -> str:
        rel = self.path.relative_to(ROOT)
        return f"{rel}: {self.level}: {self.msg}"


def lint_one(cfg_path: Path, plugin_ids: dict[str, Path]) -> list[LintMessage]:
    msgs: list[LintMessage] = []
    sections = parse_godot_cfg(cfg_path)
    plugin_id = cfg_path.parent.name

    if plugin_id in plugin_ids and plugin_ids[plugin_id] != cfg_path:
        msgs.append(LintMessage(cfg_path, "error",
            f"duplicate plugin_id '{plugin_id}' (also at {plugin_ids[plugin_id]})"))
    plugin_ids[plugin_id] = cfg_path

    caps_section = sections.get("capabilities")
    if caps_section is None:
        msgs.append(LintMessage(cfg_path, "warning",
            "no [capabilities] block — plugin won't appear in registry routing"))
        return msgs

    provides = caps_section.get("provides", [])
    if not isinstance(provides, list) or not provides:
        msgs.append(LintMessage(cfg_path, "warning",
            "[capabilities].provides is empty or missing"))
    else:
        for cap in provides:
            if not isinstance(cap, str):
                msgs.append(LintMessage(cfg_path, "error",
                    f"non-string capability: {cap!r}"))
                continue
            ns = cap.split(".", 1)[0] if "." in cap else cap
            if ns not in KNOWN_NAMESPACES:
                msgs.append(LintMessage(cfg_path, "warning",
                    f"capability '{cap}' uses unknown namespace '{ns}' "
                    f"(known: {sorted(KNOWN_NAMESPACES)}). "
                    f"It will work but won't be auto-labelled in the UI."))

    exts = caps_section.get("handles_extensions", [])
    if isinstance(exts, list):
        for e in exts:
            if not isinstance(e, str):
                msgs.append(LintMessage(cfg_path, "error",
                    f"non-string extension: {e!r}"))
                continue
            if e.startswith("."):
                msgs.append(LintMessage(cfg_path, "error",
                    f"extension '{e}' has leading dot (use '{e[1:]}')"))
            if e != e.lower():
                msgs.append(LintMessage(cfg_path, "error",
                    f"extension '{e}' is not lowercase"))

    prio = caps_section.get("priority")
    if prio is not None:
        if not isinstance(prio, int):
            msgs.append(LintMessage(cfg_path, "error",
                f"priority must be int, got {type(prio).__name__}"))
        elif prio < 1 or prio > 100:
            msgs.append(LintMessage(cfg_path, "warning",
                f"priority {prio} outside recommended 1..100 range "
                "(built-ins use 1..10, plugins use 50)"))

    return msgs


# ─── Main ─────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--strict", action="store_true",
                        help="treat warnings as errors")
    args = parser.parse_args()

    if not PLUGINS_DIR.exists():
        print(f"plugins dir not found: {PLUGINS_DIR}", file=sys.stderr)
        return 2

    cfg_paths = sorted(PLUGINS_DIR.glob("*/plugin.cfg"))
    if not cfg_paths:
        print(f"no plugin.cfg files under {PLUGINS_DIR}", file=sys.stderr)
        return 0

    all_msgs: list[LintMessage] = []
    plugin_ids: dict[str, Path] = {}
    for cfg in cfg_paths:
        all_msgs.extend(lint_one(cfg, plugin_ids))

    errors = sum(1 for m in all_msgs if m.level == "error")
    warnings = sum(1 for m in all_msgs if m.level == "warning")

    for m in all_msgs:
        print(m)

    print(f"\nScanned {len(cfg_paths)} plugin.cfg file(s) — "
          f"{errors} error(s), {warnings} warning(s).")

    if errors > 0:
        return 2
    if warnings > 0 and args.strict:
        return 2
    if warnings > 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
