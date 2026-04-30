#!/usr/bin/env python3
"""VisualGasic first-time bootstrap — the "kid-friendly" installer core.

Goal: take a user who has nothing installed and drop them straight into the
VG IDE (Godot editor with the VG addon active on a scaffolded project) in
a single run. This is the shared engine behind the native installers
(AppImage on Linux, NSIS .exe on Windows, .app/.dmg on macOS).

What it does:
    1. Install the VisualGasic addon (bundled with this script, or downloaded
       from the matching GitHub release if run standalone).
    2. Install Godot editor 4.6.1 (download + verify SHA-512, or use a
       bundled offline copy with --offline).
    3. Scaffold a "MyFirstGame" project with the VG plugin pre-enabled.
    4. Create a "VisualGasic IDE" launcher/shortcut that opens Godot
       pointing at the user's project — the closest thing to "VG as the
       default UI" without forking the engine.
    5. Optionally register the .vg file type with the launcher.

Usage:
    python3 bootstrap_vg.py                     # online, interactive defaults
    python3 bootstrap_vg.py --offline <dir>     # use a bundled offline stash
    python3 bootstrap_vg.py --project-dir PATH  # scaffold there instead of ~/VisualGasic
    python3 bootstrap_vg.py --no-launcher       # skip desktop shortcut creation
    python3 bootstrap_vg.py --no-file-assoc     # skip .vg file association
    python3 bootstrap_vg.py --godot-version X   # default 4.6.1-stable

Exit codes:
    0 success   1 user abort   2 download/network error   3 disk/permission error
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import shutil
import ssl
import stat
import subprocess
import sys
import tempfile
import textwrap
import zipfile
from pathlib import Path
from typing import Optional
from urllib.request import Request, urlopen, urlretrieve


# ── Config ──────────────────────────────────────────────────────────────────

GODOT_VERSION_DEFAULT = "4.6.1-stable"
GODOT_MIN_VERSION = (4, 6, 1)  # Oldest supported by this installer
GODOT_RELEASE_BASE = "https://github.com/godotengine/godot/releases/download"
GODOT_RELEASES_API = "https://api.github.com/repos/godotengine/godot/releases"
VG_REPO_API = "https://api.github.com/repos/xgreenrx-star/VisualGasic/releases"

# Known-good SHA-512 sums for the supported Godot builds. If the upstream
# publishes new builds we haven't recorded, --skip-checksum lets the user
# bypass verification (with a warning).
GODOT_SHA512: dict[tuple[str, str], str] = {
    # Populate via scripts/update_godot_sums.sh. Empty => skip (warn).
}


# ── Colour output ───────────────────────────────────────────────────────────

def _supports_color() -> bool:
    return sys.stdout.isatty() and os.environ.get("NO_COLOR") is None


C_RESET = "\033[0m" if _supports_color() else ""
C_CYAN = "\033[0;36m" if _supports_color() else ""
C_GREEN = "\033[0;32m" if _supports_color() else ""
C_YELLOW = "\033[1;33m" if _supports_color() else ""
C_RED = "\033[0;31m" if _supports_color() else ""
C_BOLD = "\033[1m" if _supports_color() else ""


def info(msg: str) -> None:
    print(f"{C_CYAN}ℹ{C_RESET}  {msg}")


def ok(msg: str) -> None:
    print(f"{C_GREEN}✅{C_RESET} {msg}")


def warn(msg: str) -> None:
    print(f"{C_YELLOW}⚠{C_RESET}  {msg}")


def die(msg: str, code: int = 1) -> None:
    print(f"{C_RED}✗{C_RESET}  {msg}", file=sys.stderr)
    sys.exit(code)


def banner() -> None:
    print()
    print(f"{C_BOLD}{C_CYAN}  ╔══════════════════════════════════════╗{C_RESET}")
    print(f"{C_BOLD}{C_CYAN}  ║   VisualGasic First-Run Bootstrap     ║{C_RESET}")
    print(f"{C_BOLD}{C_CYAN}  ║   Godot + VG + a ready-to-run project ║{C_RESET}")
    print(f"{C_BOLD}{C_CYAN}  ╚══════════════════════════════════════╝{C_RESET}")
    print()


# ── Platform paths ──────────────────────────────────────────────────────────

def app_data_dir() -> Path:
    system = platform.system()
    if system == "Darwin":
        return Path.home() / "Library" / "Application Support" / "VisualGasic"
    if system == "Windows":
        base = os.environ.get("LOCALAPPDATA") or os.environ.get("APPDATA")
        return Path(base or Path.home() / "AppData" / "Local") / "VisualGasic"
    return Path.home() / ".local" / "share" / "visual_gasic"


def default_project_parent() -> Path:
    return Path.home() / "VisualGasic"


def godot_install_dir() -> Path:
    return app_data_dir() / "godot"


def vg_addon_install_dir() -> Path:
    return app_data_dir() / "addons" / "visual_gasic"


def bin_dir() -> Path:
    if platform.system() == "Windows":
        return Path.home() / "AppData" / "Local" / "VisualGasic" / "bin"
    return Path.home() / ".local" / "bin"


def godot_user_data_dir(project_name: str) -> Path:
    """Where Godot maps `user://` for a given project name. Godot sanitizes
    the project name by replacing path-unsafe characters with underscores,
    but common names (letters, digits, spaces, hyphens) are passed through."""
    safe = "".join(c if c not in '<>:"/\\|?*' else "_" for c in project_name).strip()
    system = platform.system()
    if system == "Darwin":
        return Path.home() / "Library" / "Application Support" / "Godot" / "app_userdata" / safe
    if system == "Windows":
        appdata = os.environ.get("APPDATA") or str(Path.home() / "AppData" / "Roaming")
        return Path(appdata) / "Godot" / "app_userdata" / safe
    xdg = os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local" / "share")
    return Path(xdg) / "godot" / "app_userdata" / safe


# ── Godot download metadata ────────────────────────────────────────────────

def godot_asset_name(version: str) -> str:
    """Return the Godot release zip filename for this platform."""
    system = platform.system()
    if system == "Linux":
        return f"Godot_v{version}_linux.x86_64.zip"
    if system == "Windows":
        return f"Godot_v{version}_win64.exe.zip"
    if system == "Darwin":
        return f"Godot_v{version}_macos.universal.zip"
    die(f"Unsupported platform: {system}", code=3)
    return ""  # unreachable


def godot_binary_name_in_zip(version: str) -> str:
    """Name of the executable inside the Godot release zip."""
    system = platform.system()
    if system == "Linux":
        return f"Godot_v{version}_linux.x86_64"
    if system == "Windows":
        return f"Godot_v{version}_win64.exe"
    if system == "Darwin":
        return "Godot.app"
    return ""


# ── Godot version discovery ────────────────────────────────────────────────

import re as _re

_VERSION_RE = _re.compile(r"^(\d+)\.(\d+)(?:\.(\d+))?-(stable|rc\d+|beta\d+|dev\d+)$")


def parse_godot_version(tag: str) -> Optional[tuple[tuple[int, int, int], str]]:
    """Parse a Godot tag like '4.6.1-stable' into ((4, 6, 1), 'stable').
    Returns None if the tag doesn't match the expected shape."""
    m = _VERSION_RE.match(tag)
    if not m:
        return None
    major, minor, patch, channel = m.group(1), m.group(2), m.group(3), m.group(4)
    return ((int(major), int(minor), int(patch or 0)), channel)


def _channel_rank(channel: str) -> int:
    """'stable' > 'rc' > 'beta' > 'dev' for sort purposes."""
    if channel == "stable":
        return 3
    if channel.startswith("rc"):
        return 2
    if channel.startswith("beta"):
        return 1
    return 0


def list_supported_godot_versions(include_prereleases: bool = False) -> list[str]:
    """Query the Godot GitHub releases API and return tag strings >= 4.6.1.

    Stable releases come first, newest to oldest. If include_prereleases is
    True, beta/rc tags are also included (after the stable ones).
    """
    try:
        req = Request(GODOT_RELEASES_API,
                      headers={"Accept": "application/vnd.github+json",
                               "User-Agent": "VisualGasic-Bootstrap/1.0"})
        with urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        warn(f"Could not query Godot releases ({e}); falling back to default {GODOT_VERSION_DEFAULT}.")
        return [GODOT_VERSION_DEFAULT]

    candidates: list[tuple[tuple[int, int, int], str, str]] = []
    for entry in data:
        if not isinstance(entry, dict):
            continue
        tag = entry.get("tag_name") or ""
        parsed = parse_godot_version(tag)
        if not parsed:
            continue
        triplet, channel = parsed
        if triplet < GODOT_MIN_VERSION:
            continue
        if channel != "stable" and not include_prereleases:
            continue
        candidates.append((triplet, channel, tag))

    # Sort: newest version first; within the same version, stable beats rc
    # beats beta beats dev.
    candidates.sort(key=lambda c: (c[0], _channel_rank(c[1])), reverse=True)

    # De-duplicate (GitHub sometimes serves duplicate tags via redirects).
    seen: set[str] = set()
    ordered: list[str] = []
    for _, _, tag in candidates:
        if tag in seen:
            continue
        seen.add(tag)
        ordered.append(tag)

    if GODOT_VERSION_DEFAULT not in ordered:
        # Guarantee the default is always offered even if the API response
        # is missing it for some reason.
        ordered.append(GODOT_VERSION_DEFAULT)
    return ordered


def pick_godot_version_interactive(include_prereleases: bool) -> str:
    """Show a numbered menu of Godot versions and return the user's choice.
    Falls back to the default on non-TTY or empty input."""
    if not sys.stdin.isatty():
        return GODOT_VERSION_DEFAULT

    versions = list_supported_godot_versions(include_prereleases=include_prereleases)
    if not versions:
        return GODOT_VERSION_DEFAULT

    print()
    print(f"{C_BOLD}  Choose a Godot version to install{C_RESET}")
    print(f"  (must be >= {'.'.join(map(str, GODOT_MIN_VERSION))}, default is "
          f"{GODOT_VERSION_DEFAULT} — press Enter to accept)")
    print()
    for i, tag in enumerate(versions[:15], start=1):
        marker = " (default)" if tag == GODOT_VERSION_DEFAULT else ""
        print(f"    {i:>2}. {tag}{marker}")
    if len(versions) > 15:
        print(f"    ...and {len(versions) - 15} more (pass --godot-version to pick)")
    print()
    try:
        raw = input("  Your choice [Enter = default]: ").strip()
    except EOFError:
        raw = ""
    if not raw:
        return GODOT_VERSION_DEFAULT
    if raw.isdigit():
        idx = int(raw) - 1
        if 0 <= idx < len(versions):
            return versions[idx]
        warn(f"Invalid choice; using {GODOT_VERSION_DEFAULT}.")
        return GODOT_VERSION_DEFAULT
    # Allow typing a tag directly (e.g. "4.7.0-stable" or just "4.7.0")
    if parse_godot_version(raw):
        return raw
    if _re.match(r"^\d+\.\d+(\.\d+)?$", raw):
        return f"{raw}-stable"
    warn(f"Unrecognised version '{raw}'; using {GODOT_VERSION_DEFAULT}.")
    return GODOT_VERSION_DEFAULT


def validate_godot_version(tag: str) -> str:
    """Ensure `tag` is a recognisable Godot version >= GODOT_MIN_VERSION.
    Accepts bare '4.7.0' and upgrades it to '4.7.0-stable'. Exits on failure."""
    # Allow shorthand like "4.7" or "4.7.0" → "-stable"
    if _re.match(r"^\d+\.\d+(\.\d+)?$", tag):
        tag = f"{tag}-stable"
    parsed = parse_godot_version(tag)
    if not parsed:
        die(f"Unrecognised Godot version tag: {tag!r}. "
            f"Expected something like '4.6.1-stable' or '4.7.0-stable'.", code=1)
    triplet, _channel = parsed
    if triplet < GODOT_MIN_VERSION:
        die(f"Godot {tag} is not supported by this installer. "
            f"Minimum supported version is "
            f"{'.'.join(map(str, GODOT_MIN_VERSION))}-stable.", code=1)
    return tag


# ── Download helpers ────────────────────────────────────────────────────────

def _urlopen(url: str, timeout: int = 30):
    ctx = ssl.create_default_context()
    req = Request(url, headers={"User-Agent": "VisualGasic-Bootstrap/1.0"})
    return urlopen(req, timeout=timeout, context=ctx)


def download_with_progress(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)

    def _reporthook(block_num: int, block_size: int, total_size: int) -> None:
        if total_size <= 0:
            return
        downloaded = block_num * block_size
        pct = min(downloaded / total_size * 100.0, 100.0)
        bar_width = 32
        filled = int(bar_width * pct / 100.0)
        bar = "█" * filled + "░" * (bar_width - filled)
        mb = downloaded / (1024 * 1024)
        total_mb = total_size / (1024 * 1024)
        sys.stdout.write(f"\r    [{bar}] {pct:5.1f}%  {mb:6.1f} / {total_mb:.1f} MB")
        sys.stdout.flush()

    try:
        urlretrieve(url, str(dest), reporthook=_reporthook)
    except Exception as e:
        die(f"Download failed: {e}", code=2)
    sys.stdout.write("\n")


def sha512_file(path: Path) -> str:
    h = hashlib.sha512()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


# ── Installers ──────────────────────────────────────────────────────────────

def install_godot(version: str, offline_dir: Optional[Path], skip_checksum: bool) -> Path:
    """Download + unpack Godot. Return path to the executable."""
    target_dir = godot_install_dir() / version
    asset = godot_asset_name(version)
    binary_name = godot_binary_name_in_zip(version)
    binary_path = target_dir / binary_name

    if binary_path.exists():
        info(f"Godot {version} already installed at {target_dir}")
        return binary_path

    target_dir.mkdir(parents=True, exist_ok=True)

    zip_path = target_dir / asset
    if offline_dir and (offline_dir / asset).exists():
        info(f"Using offline Godot zip: {offline_dir / asset}")
        shutil.copy2(offline_dir / asset, zip_path)
    else:
        url = f"{GODOT_RELEASE_BASE}/{version}/{asset}"
        info(f"Downloading Godot {version}...")
        info(f"    {url}")
        download_with_progress(url, zip_path)

    # Verify checksum if we know it
    expected = GODOT_SHA512.get((version, platform.system()))
    if expected:
        info("Verifying checksum...")
        got = sha512_file(zip_path)
        if got != expected:
            die(
                f"Checksum mismatch for {asset}!\n    expected {expected}\n"
                f"    got      {got}\nRefusing to install untrusted binary.",
                code=2,
            )
        ok("Checksum verified")
    elif not skip_checksum:
        warn(f"No recorded SHA-512 for Godot {version} on {platform.system()}; "
             "skipping verification. Pass --skip-checksum to silence this.")

    info("Extracting...")
    with zipfile.ZipFile(zip_path, "r") as zf:
        zf.extractall(target_dir)

    # Clean up zip to save disk
    try:
        zip_path.unlink()
    except OSError:
        pass

    # On Linux/macOS make the binary executable
    if platform.system() != "Windows" and binary_path.exists() and binary_path.is_file():
        binary_path.chmod(binary_path.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)

    if not binary_path.exists():
        die(f"Godot binary not found after extract: {binary_path}", code=3)

    ok(f"Godot installed to {target_dir}")
    return binary_path


def _locate_bundled_addon_source(script_dir: Path) -> Optional[Path]:
    """Look for addons/visual_gasic/ either next to this script, or in the
    repo root if the script is at scripts/bootstrap_vg.py. Installers should
    bundle the addon alongside the script."""
    for candidate in (
        script_dir / "addons" / "visual_gasic",
        script_dir.parent / "addons" / "visual_gasic",
        Path.cwd() / "addons" / "visual_gasic",
    ):
        if (candidate / "plugin.cfg").exists():
            return candidate
    return None


def _download_vg_release(temp_dir: Path, tag: Optional[str]) -> Path:
    """Download the latest (or specified) VisualGasic release zip and return
    the extracted source directory containing addons/visual_gasic/."""
    info("Looking up VisualGasic release...")
    try:
        with _urlopen(VG_REPO_API, timeout=20) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        die(f"Could not query GitHub API: {e}", code=2)
    resolved = tag or (data[0]["tag_name"] if data else None)
    if not resolved:
        die("No VisualGasic releases found on GitHub.", code=2)

    url = f"https://github.com/xgreenrx-star/VisualGasic/archive/refs/tags/{resolved}.zip"
    info(f"Downloading VisualGasic {resolved}...")
    zip_path = temp_dir / "vg.zip"
    download_with_progress(url, zip_path)

    info("Extracting...")
    with zipfile.ZipFile(zip_path, "r") as zf:
        zf.extractall(temp_dir)
    children = [p for p in temp_dir.iterdir() if p.is_dir()]
    if not children:
        die("VisualGasic zip was empty.", code=2)
    return children[0]


def install_vg_addon(offline_dir: Optional[Path], vg_tag: Optional[str]) -> tuple[Path, Path]:
    """Install the VG addon into the shared AppData location. Returns
    (addon_dir, vg_cli_source_if_any)."""
    addon_dir = vg_addon_install_dir()
    addon_dir.parent.mkdir(parents=True, exist_ok=True)

    script_dir = Path(__file__).resolve().parent
    source_root: Optional[Path] = None

    # Priority 1: offline bundle
    if offline_dir and (offline_dir / "addons" / "visual_gasic" / "plugin.cfg").exists():
        source_root = offline_dir
        info(f"Using offline VisualGasic source: {offline_dir}")
    # Priority 2: bundled next to script or in repo
    else:
        bundled = _locate_bundled_addon_source(script_dir)
        if bundled:
            source_root = bundled.parent.parent
            info(f"Using bundled VisualGasic addon: {bundled}")

    # Priority 3: download from GitHub
    temp_dir: Optional[Path] = None
    if source_root is None:
        temp_dir = Path(tempfile.mkdtemp(prefix="vg_boot_"))
        source_root = _download_vg_release(temp_dir, vg_tag)

    src_addon = source_root / "addons" / "visual_gasic"
    if not (src_addon / "plugin.cfg").exists():
        die(f"Addon not found at {src_addon}", code=3)

    if addon_dir.exists():
        shutil.rmtree(addon_dir)
    shutil.copytree(src_addon, addon_dir)

    # Strip .uid files (regenerated per-project by Godot)
    for uid in addon_dir.rglob("*.uid"):
        try:
            uid.unlink()
        except OSError:
            pass

    version_src = source_root / "VERSION"
    if version_src.exists():
        shutil.copy2(version_src, app_data_dir() / "VERSION")

    vg_cli = source_root / "vg"
    ok(f"VisualGasic addon installed to {addon_dir}")

    # Keep the temp dir around until after project scaffold — caller cleans up.
    if temp_dir is not None:
        # Leave the temp dir; main() cleans at the end.
        pass

    return addon_dir, (vg_cli if vg_cli.exists() else None)


# ── Project scaffolding ────────────────────────────────────────────────────

PROJECT_GODOT_TEMPLATE = textwrap.dedent("""\
    ; Godot project scaffolded by VisualGasic bootstrap.
    config_version=5

    [application]

    config/name="{display_name}"
    config/features=PackedStringArray("4.6", "Forward Plus")
    config/icon="res://icon.svg"

    [autoload]

    VGDebugHandler="*res://addons/visual_gasic/vg_debug_handler.gd"

    [editor_plugins]

    enabled=PackedStringArray("res://addons/visual_gasic/plugin.cfg")

    [visual_gasic]

    ; Activate the VG IDE layout (toolbox + project explorer + properties
    ; inspector docked, code editor as main screen) on first open. The user
    ; can toggle this via Project > Tools > Toggle VG IDE Layout.
    layout/vb6_mode=true
    """)

FORM1_TEMPLATE = textwrap.dedent('''\
    \' Form1.vg — Your first VisualGasic form
    \' Press F5 in the Godot editor to preview this form.

    Option Explicit

    Private Sub Form_Load()
        MsgBox "Welcome to VisualGasic!"
    End Sub
    ''')

DEFAULT_ICON_SVG = textwrap.dedent("""\
    <svg height="128" width="128" xmlns="http://www.w3.org/2000/svg">
      <rect width="128" height="128" rx="16" fill="#3d5a80"/>
      <text x="64" y="78" font-size="48" font-family="monospace" font-weight="bold"
            text-anchor="middle" fill="#e0e1dd">VG</text>
    </svg>
    """)


def scaffold_project(project_dir: Path, display_name: str, addon_source: Path) -> Path:
    """Create project_dir with a VG-enabled Godot project. Return project_dir."""
    reused_existing = project_dir.exists() and any(project_dir.iterdir())
    if reused_existing:
        info(f"Project directory {project_dir} already exists; refreshing "
             "project.godot, addon link, and Form1.vg in place.")
    project_dir.mkdir(parents=True, exist_ok=True)

    info(f"Scaffolding project at {project_dir}...")
    (project_dir / "addons").mkdir(exist_ok=True)

    # Link (or copy) the addon into the project. Symlink on POSIX so updates
    # to the shared install propagate; copy on Windows.
    proj_addon = project_dir / "addons" / "visual_gasic"
    if proj_addon.exists() or proj_addon.is_symlink():
        if proj_addon.is_symlink() or proj_addon.is_dir():
            try:
                if proj_addon.is_symlink():
                    proj_addon.unlink()
                else:
                    shutil.rmtree(proj_addon)
            except OSError:
                pass

    if platform.system() == "Windows":
        shutil.copytree(addon_source, proj_addon)
    else:
        try:
            proj_addon.symlink_to(addon_source, target_is_directory=True)
        except OSError:
            shutil.copytree(addon_source, proj_addon)

    (project_dir / "project.godot").write_text(
        PROJECT_GODOT_TEMPLATE.format(display_name=display_name)
    )

    icon_src = addon_source / "icon.svg"
    icon_dst = project_dir / "icon.svg"
    if icon_src.exists():
        shutil.copy2(icon_src, icon_dst)
    else:
        icon_dst.write_text(DEFAULT_ICON_SVG)

    (project_dir / "Form1.vg").write_text(FORM1_TEMPLATE)
    ok(f"Project ready: {project_dir}")
    return project_dir


# ── Launchers / desktop integration ────────────────────────────────────────


def prime_project_imports(godot_bin: Path, project_dir: Path) -> None:
    """Run Godot once headlessly to import resources and activate plugins.

    On a freshly-scaffolded project, Godot's first interactive open does an
    import scan *before* activating editor plugins, which means the VG
    plugin can appear inactive on the very first launch even though
    [editor_plugins] enabled lists it. Doing a headless pass here primes
    the project so the next interactive open lands the user directly in a
    working VG IDE.

    Errors are non-fatal — if something goes wrong, the user can still
    enable the plugin manually from Project > Project Settings > Plugins.
    """
    info("Priming project (importing resources, enabling VG plugin)…")
    try:
        # `--import` runs the editor, waits for all resources to be imported
        # (which activates EditorPlugins listed in project.godot along the
        # way), and then quits cleanly. Without this pass, the very first
        # interactive `--editor` open imports resources *before* activating
        # plugins, and the user has to toggle the VG plugin off and on to
        # see the IDE.
        result = subprocess.run(
            [str(godot_bin), "--path", str(project_dir),
             "--headless", "--import"],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            timeout=180, check=False,
        )
        if result.returncode != 0:
            warn(f"Godot import pass returned exit {result.returncode}; "
                 "the IDE should still open, but if the VG toolbox doesn't "
                 "appear, toggle the VisualGasic plugin off and on under "
                 "Project Settings → Plugins.")
        else:
            ok("Project primed; VG plugin pre-activated.")
    except subprocess.TimeoutExpired:
        warn("Godot import pass took longer than 3 minutes; skipping. "
             "First IDE launch may need a moment to finish importing.")
    except (FileNotFoundError, OSError) as e:
        warn(f"Could not run Godot import pass: {e}")


def launcher_script_path() -> Path:
    if platform.system() == "Windows":
        return bin_dir() / "visualgasic-ide.cmd"
    return bin_dir() / "visualgasic-ide"


def write_launcher(godot_bin: Path, project_dir: Path) -> Path:
    """Write a launcher script that opens the VG IDE on the user's project."""
    bin_dir().mkdir(parents=True, exist_ok=True)
    launcher = launcher_script_path()

    if platform.system() == "Windows":
        # %1 lets the launcher accept a .vg file path to open
        launcher.write_text(
            "@echo off\r\n"
            f'set GODOT="{godot_bin}"\r\n'
            f'set PROJECT="{project_dir}"\r\n'
            "if \"%~1\"==\"\" (\r\n"
            "  %GODOT% --path %PROJECT% --editor\r\n"
            ") else (\r\n"
            "  %GODOT% --path %PROJECT% --editor \"%~1\"\r\n"
            ")\r\n"
        )
    else:
        script = textwrap.dedent(f"""\
            #!/bin/sh
            # VisualGasic IDE launcher — opens Godot with the VG addon on the
            # scaffolded project. Pass a .vg file path to open it in the IDE.
            GODOT={shellquote(str(godot_bin))}
            PROJECT={shellquote(str(project_dir))}
            if [ "$#" -eq 0 ]; then
                exec "$GODOT" --path "$PROJECT" --editor
            else
                exec "$GODOT" --path "$PROJECT" --editor "$@"
            fi
            """)
        launcher.write_text(script)
        launcher.chmod(0o755)

    ok(f"Launcher: {launcher}")
    return launcher


def shellquote(s: str) -> str:
    # Simple POSIX single-quote escape — good enough for paths.
    return "'" + s.replace("'", "'\\''") + "'"


def write_linux_desktop_entry(launcher: Path, project_dir: Path, register_mime: bool) -> Optional[Path]:
    """Create a .desktop file so the launcher appears in the Apps menu."""
    if platform.system() != "Linux":
        return None
    apps_dir = Path.home() / ".local" / "share" / "applications"
    apps_dir.mkdir(parents=True, exist_ok=True)
    desktop = apps_dir / "visualgasic-ide.desktop"

    icon_src = project_dir / "icon.svg"
    icon_line = f"Icon={icon_src}" if icon_src.exists() else "Icon=godot"
    mime_line = "MimeType=text/x-visualgasic;\n" if register_mime else ""

    desktop.write_text(textwrap.dedent(f"""\
        [Desktop Entry]
        Type=Application
        Name=VisualGasic IDE
        Comment=VB6-style language for Godot 4 — opens your VG project
        Exec={launcher} %f
        {icon_line}
        Terminal=false
        Categories=Development;IDE;
        {mime_line}"""))
    desktop.chmod(0o755)
    ok(f"Desktop entry: {desktop}")

    if register_mime:
        mime_pkgs = Path.home() / ".local" / "share" / "mime" / "packages"
        mime_pkgs.mkdir(parents=True, exist_ok=True)
        mime_xml = mime_pkgs / "visualgasic.xml"
        mime_xml.write_text(textwrap.dedent("""\
            <?xml version="1.0" encoding="UTF-8"?>
            <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
              <mime-type type="text/x-visualgasic">
                <comment>VisualGasic source file</comment>
                <glob pattern="*.vg"/>
                <icon name="text-x-generic"/>
              </mime-type>
            </mime-info>
            """))
        # Best-effort DB refresh
        for cmd in (
            ["update-mime-database", str(Path.home() / ".local" / "share" / "mime")],
            ["update-desktop-database", str(apps_dir)],
            ["xdg-mime", "default", "visualgasic-ide.desktop", "text/x-visualgasic"],
        ):
            try:
                subprocess.run(cmd, check=False, stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL, timeout=10)
            except (FileNotFoundError, subprocess.TimeoutExpired):
                pass
        ok(f"Registered .vg MIME type")

    return desktop


def write_windows_shortcut(launcher: Path, project_dir: Path) -> None:
    """Create a Start Menu + Desktop shortcut via PowerShell's WScript.Shell."""
    if platform.system() != "Windows":
        return
    start_menu = Path(os.environ.get("APPDATA", "")) / "Microsoft" / "Windows" / "Start Menu" / "Programs"
    desktop_dir = Path.home() / "Desktop"
    icon = project_dir / "icon.svg"

    ps_script = textwrap.dedent(f"""\
        $wsh = New-Object -ComObject WScript.Shell
        foreach ($dir in @({json.dumps(str(start_menu))}, {json.dumps(str(desktop_dir))})) {{
            if (-not (Test-Path $dir)) {{ continue }}
            $lnk = $wsh.CreateShortcut((Join-Path $dir 'VisualGasic IDE.lnk'))
            $lnk.TargetPath = {json.dumps(str(launcher))}
            $lnk.WorkingDirectory = {json.dumps(str(project_dir))}
            $lnk.Description = 'VisualGasic IDE — VB6-style language for Godot 4'
            $lnk.Save()
        }}
        """)
    try:
        subprocess.run(
            ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps_script],
            check=False, timeout=30,
        )
        ok("Created Start Menu + Desktop shortcuts")
    except (FileNotFoundError, subprocess.TimeoutExpired):
        warn("Could not create Windows shortcuts (PowerShell unavailable).")


def register_windows_file_association(launcher: Path) -> None:
    """Register .vg → VisualGasic IDE launcher using HKCU (no admin needed)."""
    if platform.system() != "Windows":
        return
    # HKCU\Software\Classes\.vg → VisualGasic.File
    # HKCU\Software\Classes\VisualGasic.File\shell\open\command → launcher "%1"
    cmd = f'"{launcher}" "%1"'
    reg_commands = [
        ["reg", "add", r"HKCU\Software\Classes\.vg", "/ve", "/d", "VisualGasic.File", "/f"],
        ["reg", "add", r"HKCU\Software\Classes\VisualGasic.File", "/ve",
         "/d", "VisualGasic Source File", "/f"],
        ["reg", "add", r"HKCU\Software\Classes\VisualGasic.File\shell\open\command",
         "/ve", "/d", cmd, "/f"],
    ]
    for rc in reg_commands:
        try:
            subprocess.run(rc, check=False, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, timeout=10)
        except (FileNotFoundError, subprocess.TimeoutExpired):
            warn("reg.exe unavailable; skipping .vg association.")
            return
    ok("Registered .vg file association")


# ── Optional AI key configuration ──────────────────────────────────────────

AI_PROVIDERS = [
    # (id, display_name, help_url)
    ("openai", "OpenAI",        "https://platform.openai.com/api-keys"),
    ("claude", "Anthropic Claude", "https://console.anthropic.com/settings/keys"),
    ("gemini", "Google Gemini", "https://aistudio.google.com/apikey"),
]


def _cfg_escape(value: str) -> str:
    """Minimal Godot ConfigFile string escaping — matches what ConfigFile.save
    produces for plain ASCII keys. Good enough for API tokens (which are
    base64/hex-ish) and blank values."""
    return value.replace("\\", "\\\\").replace('"', '\\"')


def write_godot_ai_keys(project_name: str, keys: dict[str, str]) -> Optional[Path]:
    """Write a Godot-compatible ConfigFile at the project's user:// path
    containing the provided AI keys. Returns the cfg path (or None if no
    non-empty keys were given)."""
    keys = {k: v for k, v in keys.items() if v}
    if not keys:
        return None
    user_dir = godot_user_data_dir(project_name)
    user_dir.mkdir(parents=True, exist_ok=True)
    cfg = user_dir / "vg_ai_keys.cfg"

    lines: list[str] = []
    lines.append("; Engine configuration file.")
    lines.append("; It's best edited using the editor UI and not directly,")
    lines.append("; since the parameters that go here are not all obvious.")
    lines.append(";")
    lines.append("; Format:")
    lines.append(";   [section] ; section goes between []")
    lines.append(";   param=value ; assign values to parameters")
    lines.append("")
    lines.append("[api_keys]")
    lines.append("")
    for pid, val in keys.items():
        lines.append(f'{pid}="{_cfg_escape(val)}"')
    lines.append("")
    cfg.write_text("\n".join(lines))
    # Plain-text secrets — restrict permissions on POSIX.
    if platform.system() != "Windows":
        try:
            cfg.chmod(0o600)
        except OSError:
            pass
    return cfg


def prompt_for_ai_keys(cli_defaults: dict[str, str]) -> dict[str, str]:
    """Interactively collect AI keys. Anything non-empty in cli_defaults
    bypasses the prompt for that provider. Enter on a blank line skips."""
    if not sys.stdin.isatty():
        # Non-interactive — just use whatever was passed on the command line.
        return cli_defaults

    print()
    print(f"{C_BOLD}  Optional: configure AI provider keys{C_RESET}")
    print("  Leave blank to skip a provider (you can set keys later in the IDE).")
    print()
    keys: dict[str, str] = {}
    for pid, name, url in AI_PROVIDERS:
        preset = cli_defaults.get(pid, "").strip()
        if preset:
            keys[pid] = preset
            info(f"{name}: using key from --{pid}-key")
            continue
        print(f"    {C_CYAN}{name}{C_RESET}  ({url})")
        try:
            val = input(f"    {pid} key (blank to skip): ").strip()
        except EOFError:
            val = ""
        if val:
            keys[pid] = val
    return keys


def configure_ai_keys(args, project_display_name: str) -> None:
    """Handle --with-ai-keys and/or the per-provider --*-key flags."""
    cli_keys = {
        "openai": (args.openai_key or "").strip(),
        "claude": (args.claude_key or "").strip(),
        "gemini": (args.gemini_key or "").strip(),
    }
    any_cli = any(cli_keys.values())

    if not args.with_ai_keys and not any_cli:
        return  # default path: skip entirely

    keys = prompt_for_ai_keys(cli_keys) if args.with_ai_keys else cli_keys
    path = write_godot_ai_keys(project_display_name, keys)
    if path:
        ok(f"AI keys written to {path}")
        print(f"    Edit or clear them later from the ⚙️  button in the VG AI Help panel.")
    else:
        info("No AI keys provided — skipping. You can set them from the IDE anytime.")


# ── Optional Ollama (free local AI) installation ──────────────────────────

# Curated catalog of Ollama models suitable for VG / GDScript / VB-style
# coding assistance. Each entry is (id, label, download_size_gb,
# min_ram_gb, blurb).  download_size is the on-disk size after `ollama
# pull`; min_ram_gb is roughly what's needed to load + run the model
# comfortably (with a small context). These are conservative defaults —
# users with GPUs can comfortably run one tier higher than the RAM
# recommendation suggests.
OLLAMA_MODELS = [
    ("tinyllama",
     "TinyLlama 1.1B (tiny, smoke-test)",
     0.7, 2,
     "Smallest option. Useful only to verify the integration; coding "
     "answers are weak."),
    ("qwen2.5-coder:1.5b",
     "Qwen2.5-Coder 1.5B (lightweight)",
     1.0, 4,
     "Good basic code completion; runs on almost any laptop."),
    ("llama3.2:3b",
     "Llama 3.2 3B (general)",
     2.0, 6,
     "General-purpose chat; OK for explanations, weaker on code."),
    ("qwen2.5-coder:7b",
     "Qwen2.5-Coder 7B (recommended)",
     4.7, 10,
     "Strong coding model; the sweet spot for most modern laptops."),
    ("qwen2.5-coder:14b",
     "Qwen2.5-Coder 14B (powerful)",
     9.0, 16,
     "Excellent code quality; needs a beefy laptop or a GPU."),
    ("qwen2.5-coder:32b",
     "Qwen2.5-Coder 32B (workstation)",
     20.0, 32,
     "Near-frontier code quality. Best with a 16GB+ GPU."),
]

OLLAMA_MODEL_DEFAULT = "qwen2.5-coder:1.5b"  # safe fallback if detection fails


def detect_hardware() -> dict:
    """Best-effort hardware probe (stdlib + nvidia-smi). Returns a dict
    with keys ram_gb (float), cpu_cores (int), gpu_vendor (str|None),
    gpu_vram_gb (float|None). Never raises."""
    info_d: dict = {"ram_gb": 0.0, "cpu_cores": os.cpu_count() or 1,
                    "gpu_vendor": None, "gpu_vram_gb": None}

    # RAM
    try:
        if hasattr(os, "sysconf") and "SC_PHYS_PAGES" in os.sysconf_names:
            pages = os.sysconf("SC_PHYS_PAGES")
            page_size = os.sysconf("SC_PAGE_SIZE")
            info_d["ram_gb"] = round((pages * page_size) / (1024 ** 3), 1)
        elif platform.system() == "Windows":
            import ctypes

            class MEMORYSTATUSEX(ctypes.Structure):
                _fields_ = [("dwLength", ctypes.c_ulong),
                            ("dwMemoryLoad", ctypes.c_ulong),
                            ("ullTotalPhys", ctypes.c_ulonglong),
                            ("ullAvailPhys", ctypes.c_ulonglong),
                            ("ullTotalPageFile", ctypes.c_ulonglong),
                            ("ullAvailPageFile", ctypes.c_ulonglong),
                            ("ullTotalVirtual", ctypes.c_ulonglong),
                            ("ullAvailVirtual", ctypes.c_ulonglong),
                            ("ullAvailExtendedVirtual", ctypes.c_ulonglong)]
            stat = MEMORYSTATUSEX()
            stat.dwLength = ctypes.sizeof(MEMORYSTATUSEX)
            ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(stat))
            info_d["ram_gb"] = round(stat.ullTotalPhys / (1024 ** 3), 1)
    except Exception:
        pass

    # NVIDIA GPU + VRAM
    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,memory.total",
             "--format=csv,noheader,nounits"],
            check=True, capture_output=True, text=True, timeout=4)
        first = (out.stdout.strip().splitlines() or [""])[0]
        if first:
            name, vram_mb = [p.strip() for p in first.split(",", 1)]
            info_d["gpu_vendor"] = "nvidia"
            info_d["gpu_vram_gb"] = round(float(vram_mb) / 1024, 1)
    except (FileNotFoundError, subprocess.CalledProcessError,
            subprocess.TimeoutExpired, ValueError):
        pass

    # AMD/Intel GPU detection (Linux only, very best-effort)
    if info_d["gpu_vendor"] is None and platform.system() == "Linux":
        try:
            out = subprocess.run(["lspci"], check=True, capture_output=True,
                                 text=True, timeout=4)
            for line in out.stdout.splitlines():
                low = line.lower()
                if " vga " in low or " 3d " in low or "display controller" in low:
                    if "amd" in low or "ati" in low or "radeon" in low:
                        info_d["gpu_vendor"] = "amd"
                    elif "intel" in low:
                        info_d["gpu_vendor"] = "intel"
                    break
        except (FileNotFoundError, subprocess.CalledProcessError,
                subprocess.TimeoutExpired):
            pass

    return info_d


def recommend_ollama_model(hw: dict) -> tuple[str, str]:
    """Pick a sensible default model id from OLLAMA_MODELS based on hw.
    Returns (model_id, reasoning)."""
    ram = hw.get("ram_gb") or 0.0
    vram = hw.get("gpu_vram_gb") or 0.0

    # GPU-first: a fast NVIDIA card beats a low-RAM CPU pick.
    if vram >= 20:
        return "qwen2.5-coder:32b", f"GPU has {vram:g}GB VRAM."
    if vram >= 10:
        return "qwen2.5-coder:14b", f"GPU has {vram:g}GB VRAM."
    if vram >= 5:
        return "qwen2.5-coder:7b", f"GPU has {vram:g}GB VRAM."

    if ram >= 32:
        return "qwen2.5-coder:14b", f"{ram:g}GB system RAM."
    if ram >= 12:
        return "qwen2.5-coder:7b", f"{ram:g}GB system RAM."
    if ram >= 6:
        return "qwen2.5-coder:1.5b", f"{ram:g}GB system RAM."
    if ram >= 2:
        return "tinyllama", f"{ram:g}GB system RAM is on the low side."
    return OLLAMA_MODEL_DEFAULT, "could not detect RAM; picking a safe default."


def ollama_path() -> Optional[str]:
    """Return the path to the `ollama` executable if it's already on PATH,
    else None."""
    return shutil.which("ollama")


def install_ollama_linux() -> bool:
    """Run the official Ollama install script. Returns True on success.
    Requires curl + sudo (the upstream script uses sudo internally to drop
    files in /usr/local). On a desktop Linux this typically pops a sudo
    prompt or succeeds via a polkit dialog."""
    if not shutil.which("curl"):
        warn("curl is required to install Ollama. Install curl and re-run, "
             "or download Ollama from https://ollama.com/download.")
        return False
    info("Running the official Ollama installer (you may be asked for your sudo password)…")
    try:
        # The upstream installer is `curl -fsSL https://ollama.com/install.sh | sh`.
        rc = subprocess.run(
            ["sh", "-c", "curl -fsSL https://ollama.com/install.sh | sh"],
            check=False, timeout=600,
        )
        return rc.returncode == 0
    except subprocess.TimeoutExpired:
        warn("Ollama install timed out. Try installing manually from https://ollama.com/download.")
        return False
    except Exception as e:
        warn(f"Ollama install failed: {e}. Install it manually from https://ollama.com/download.")
        return False


def open_ollama_download_page() -> None:
    """Open the user's browser at ollama.com/download. Used on Windows /
    macOS where we don't auto-install."""
    import webbrowser
    try:
        webbrowser.open("https://ollama.com/download")
    except Exception:
        pass


def pull_ollama_model(model_id: str) -> bool:
    """Run `ollama pull <model>` streaming output to the user. Returns True
    on success."""
    exe = ollama_path()
    if not exe:
        warn("ollama is not on PATH after install; skipping model download.")
        return False
    info(f"Downloading Ollama model: {model_id}")
    info("(This may take several minutes depending on your connection.)")
    try:
        rc = subprocess.run([exe, "pull", model_id], check=False, timeout=3600)
        if rc.returncode == 0:
            ok(f"Ollama model {model_id} ready.")
            return True
        warn(f"`ollama pull {model_id}` exited with code {rc.returncode}. "
             "You can re-run it later from a terminal.")
        return False
    except subprocess.TimeoutExpired:
        warn(f"`ollama pull {model_id}` timed out. Re-run it later from a terminal.")
        return False
    except Exception as e:
        warn(f"`ollama pull` failed: {e}")
        return False


def configure_ollama(args) -> None:
    """Handle the optional Ollama install + model pull. No-op unless the
    user opts in via --with-ollama (or the GUI checkbox)."""
    if not getattr(args, "with_ollama", False):
        return

    model_id = (getattr(args, "ollama_model", "") or "").strip()
    if not model_id:
        hw = detect_hardware()
        model_id, why = recommend_ollama_model(hw)
        info(f"Recommended Ollama model based on hardware: {model_id}  ({why})")

    if model_id not in {m[0] for m in OLLAMA_MODELS}:
        warn(f"Unknown Ollama model id '{model_id}' — falling back to {OLLAMA_MODEL_DEFAULT}.")
        model_id = OLLAMA_MODEL_DEFAULT

    if ollama_path() is None:
        info("Ollama is not installed yet.")
        if platform.system() == "Linux":
            if not install_ollama_linux():
                return
        else:
            info("Opening https://ollama.com/download in your browser. "
                 "Run this installer again after installing Ollama to "
                 "auto-download the model, or run "
                 f"`ollama pull {model_id}` from a terminal.")
            open_ollama_download_page()
            return

    pull_ollama_model(model_id)


# ── Main flow ──────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(
        description="VisualGasic bootstrap installer",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--offline", type=Path, metavar="DIR",
                        help="Path to an offline bundle containing Godot zip + addons/")
    parser.add_argument("--project-dir", type=Path, default=default_project_parent() / "MyFirstGame",
                        help="Where to scaffold the starter project (default: ~/VisualGasic/MyFirstGame)")
    parser.add_argument("--display-name", default="My First Game",
                        help="Human-friendly project name")
    parser.add_argument("--godot-version", default=GODOT_VERSION_DEFAULT,
                        help=f"Godot version tag (default: {GODOT_VERSION_DEFAULT}). "
                             f"Must be >= {'.'.join(map(str, GODOT_MIN_VERSION))}-stable. "
                             f"Accepts shorthand like '4.7.0' (→ '-stable').")
    parser.add_argument("--pick-godot", action="store_true",
                        help="Show an interactive menu of supported Godot versions")
    parser.add_argument("--list-godot-versions", action="store_true",
                        help="Print supported Godot versions and exit")
    parser.add_argument("--include-prereleases", action="store_true",
                        help="Include beta/rc Godot builds in --pick-godot / --list-godot-versions")
    parser.add_argument("--vg-tag", default=None,
                        help="Pin a specific VisualGasic release tag (default: latest)")
    parser.add_argument("--no-launcher", action="store_true",
                        help="Skip creating desktop/Start Menu shortcuts")
    parser.add_argument("--no-file-assoc", action="store_true",
                        help="Skip registering .vg file association")
    parser.add_argument("--skip-checksum", action="store_true",
                        help="Skip Godot SHA-512 verification")
    parser.add_argument("--launch", action="store_true",
                        help="Launch the VG IDE immediately after install")
    ai = parser.add_argument_group(
        "AI keys (optional)",
        "By default AI keys are not configured. Pass --with-ai-keys to be "
        "prompted, or pass individual --<provider>-key flags to set them "
        "non-interactively. Keys are stored in the scaffolded project's "
        "user:// directory and can be cleared later from the IDE.",
    )
    ai.add_argument("--with-ai-keys", action="store_true",
                    help="Interactively prompt for OpenAI/Claude/Gemini keys")
    ai.add_argument("--openai-key", default="",
                    help="OpenAI API key (https://platform.openai.com/api-keys)")
    ai.add_argument("--claude-key", default="",
                    help="Anthropic Claude API key")
    ai.add_argument("--gemini-key", default="",
                    help="Google Gemini API key")

    ollama_group = parser.add_argument_group(
        "Ollama (free local AI, optional)",
        "Ollama runs a local LLM on your own machine — no API keys, no "
        "data leaves your computer. Pass --with-ollama to install it and "
        "pull a model. The default model is auto-picked from your "
        "hardware; override with --ollama-model.",
    )
    ollama_group.add_argument("--with-ollama", action="store_true",
                              help="Install Ollama and pull a model after the main install.")
    ollama_group.add_argument(
        "--ollama-model", default="",
        help="Ollama model id (e.g. qwen2.5-coder:7b). "
             "Default: auto-recommend based on detected RAM/VRAM.")
    ollama_group.add_argument("--list-ollama-models", action="store_true",
                              help="Print the curated Ollama model catalog and exit.")

    gui_group = parser.add_argument_group("Graphical installer")
    gui_group.add_argument("--gui", action="store_true",
                           help="Show the graphical wizard (default when "
                                "double-clicked — no TTY detected).")
    gui_group.add_argument("--no-gui", action="store_true",
                           help="Force the text-mode installer even when no "
                                "CLI flags were provided.")
    args = parser.parse_args()

    # Auto-GUI: if the user gave us nothing (or only --offline, as the AppImage
    # shim does) and stdin isn't a terminal, open the wizard instead of a
    # non-interactive default install. Power users can force text mode with
    # --no-gui.
    _wrapper_flags = ("--offline", "--launch", "--gui", "--no-gui")
    _cli_provided = any(a.startswith("-") and a not in _wrapper_flags
                        for a in sys.argv[1:])
    _tty = sys.stdin.isatty() and sys.stdout.isatty()
    if args.gui or (not args.no_gui and not _tty and not _cli_provided):
        try:
            import bootstrap_gui
        except Exception as e:
            warn(f"Graphical installer unavailable ({e}); falling back to text mode.")
        else:
            return bootstrap_gui.run(offline=args.offline)

    # Handle version-listing short-circuit before doing anything else.
    if args.list_godot_versions:
        versions = list_supported_godot_versions(include_prereleases=args.include_prereleases)
        for tag in versions:
            marker = "  (default)" if tag == GODOT_VERSION_DEFAULT else ""
            print(f"{tag}{marker}")
        return 0

    if args.list_ollama_models:
        hw = detect_hardware()
        rec, why = recommend_ollama_model(hw)
        print(f"Detected: {hw['ram_gb']:g}GB RAM, "
              f"{hw['cpu_cores']} CPU cores, "
              f"GPU={hw['gpu_vendor'] or 'none'}"
              + (f" ({hw['gpu_vram_gb']:g}GB VRAM)" if hw["gpu_vram_gb"] else ""))
        print(f"Recommended: {rec}  ({why})")
        print()
        for mid, label, size_gb, ram_gb, blurb in OLLAMA_MODELS:
            marker = "  (recommended)" if mid == rec else ""
            print(f"  {mid}{marker}")
            print(f"    {label}")
            print(f"    download: ~{size_gb:g}GB · needs ~{ram_gb}GB RAM")
            print(f"    {blurb}")
            print()
        return 0

    banner()

    # Resolve Godot version: --pick-godot takes priority, else validate whatever
    # was passed via --godot-version (or the default).
    if args.pick_godot:
        args.godot_version = pick_godot_version_interactive(args.include_prereleases)
    args.godot_version = validate_godot_version(args.godot_version)

    info(f"Platform:        {platform.system()} {platform.machine()}")
    info(f"Shared data dir: {app_data_dir()}")
    info(f"Godot version:   {args.godot_version}")
    info(f"Project dir:     {args.project_dir}")
    print()

    # Step 1 — VG addon
    addon_dir, _vg_cli = install_vg_addon(args.offline, args.vg_tag)

    # Step 2 — Godot
    godot_bin = install_godot(args.godot_version, args.offline, args.skip_checksum)

    # Step 3 — Scaffold starter project
    project_dir = scaffold_project(args.project_dir, args.display_name, addon_dir)

    # Step 4 — Launcher + shortcuts
    launcher = write_launcher(godot_bin, project_dir)
    if not args.no_launcher:
        if platform.system() == "Linux":
            write_linux_desktop_entry(launcher, project_dir, register_mime=not args.no_file_assoc)
        elif platform.system() == "Windows":
            write_windows_shortcut(launcher, project_dir)
            if not args.no_file_assoc:
                register_windows_file_association(launcher)
        elif platform.system() == "Darwin":
            # macOS app-bundle creation is handled by the .dmg installer; the
            # shell launcher is still useful from Terminal.
            info(f"macOS: launcher installed at {launcher}. The .app bundle "
                 "is created by the packaged installer.")

    # Step 5 — Optional AI key configuration (off by default)
    configure_ai_keys(args, args.display_name)

    # Step 5b — Optional Ollama install + model pull (off by default)
    configure_ollama(args)

    # Step 6 — Prime the project: run Godot once headlessly so it imports
    # all .vg / .gd / .tscn files. This is what lets the VG editor plugin
    # activate cleanly on the very first interactive launch — without it,
    # Godot opens the editor before resources are imported and the plugin
    # appears "not enabled" until the user toggles it manually.
    prime_project_imports(godot_bin, project_dir)

    # Summary
    print()
    print(f"{C_GREEN}{C_BOLD}  ╔══════════════════════════════════════╗{C_RESET}")
    print(f"{C_GREEN}{C_BOLD}  ║   ✅ VisualGasic is ready to go       ║{C_RESET}")
    print(f"{C_GREEN}{C_BOLD}  ╚══════════════════════════════════════╝{C_RESET}")
    print()
    print(f"  Open the IDE:")
    print(f"    {C_BOLD}{launcher}{C_RESET}")
    if platform.system() == "Linux":
        print(f"    {C_BOLD}(or search 'VisualGasic IDE' in your Apps menu){C_RESET}")
    elif platform.system() == "Windows":
        print(f"    {C_BOLD}(or use the 'VisualGasic IDE' Start Menu / Desktop shortcut){C_RESET}")
    print()

    if args.launch:
        info("Launching VisualGasic IDE...")
        try:
            # Open Form1.vg if it exists, so the user lands directly in the
            # script editor. Falls back to opening the project root.
            form1 = project_dir / "Form1.vg"
            # Launch Godot directly (skip the .cmd shim) so the child is a
            # real GUI process. On Windows, detach via creationflags so the
            # child survives this process exiting (e.g. when the NSIS
            # installer's nsExec wait completes).
            cmd = [str(godot_bin), "--path", str(project_dir), "--editor"]
            if form1.exists():
                cmd.append(str(form1))
            popen_kwargs = {"close_fds": True}
            if platform.system() == "Windows":
                # DETACHED_PROCESS (0x00000008) + CREATE_NEW_PROCESS_GROUP (0x00000200)
                popen_kwargs["creationflags"] = 0x00000008 | 0x00000200
                popen_kwargs["stdin"] = subprocess.DEVNULL
                popen_kwargs["stdout"] = subprocess.DEVNULL
                popen_kwargs["stderr"] = subprocess.DEVNULL
            else:
                popen_kwargs["start_new_session"] = True
            subprocess.Popen(cmd, **popen_kwargs)
        except Exception as e:
            warn(f"Could not auto-launch: {e}")

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print()
        warn("Aborted by user.")
        sys.exit(1)
