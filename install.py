#!/usr/bin/env python3
"""VisualGasic Installer — Cross-platform Python installer.

Installs the VisualGasic addon globally and the `vg` CLI tool.

Usage:
    python3 install.py           # Install from local source (run from repo root)
    python3 install.py --github  # Download and install from GitHub

After installation:
    vg new MyGame
    cd MyGame && godot .
"""

import os
import sys
import shutil
import platform
import tempfile
import zipfile
from pathlib import Path

try:
    from urllib.request import urlretrieve
    HAS_URLLIB = True
except ImportError:
    HAS_URLLIB = False


# ── Platform-specific paths ─────────────────────────────────────────────────

def get_global_dir():
    """Get the global VG installation directory."""
    system = platform.system()
    if system == "Darwin":
        return Path.home() / "Library" / "Application Support" / "VisualGasic"
    elif system == "Windows":
        appdata = os.environ.get("APPDATA", str(Path.home() / "AppData" / "Roaming"))
        return Path(appdata) / "VisualGasic"
    else:
        return Path.home() / ".local" / "share" / "visual_gasic"


def get_bin_dir():
    """Get the directory for the vg CLI tool."""
    system = platform.system()
    if system == "Windows":
        return Path.home() / ".local" / "bin"  # User can add to PATH
    else:
        return Path.home() / ".local" / "bin"


# ── Installer ───────────────────────────────────────────────────────────────

def find_source_dir():
    """Find the VisualGasic source directory."""
    # Check current directory
    cwd = Path.cwd()
    if (cwd / "addons" / "visual_gasic" / "plugin.cfg").exists() and (cwd / "SConstruct").exists():
        return cwd

    # Check common locations
    for candidate in [
        Path.home() / "Documents" / "VisualGasic",
        Path.home() / "VisualGasic",
    ]:
        if (candidate / "addons" / "visual_gasic" / "plugin.cfg").exists():
            return candidate

    return None


def download_from_github(temp_dir):
    """Download VisualGasic from GitHub and return the source directory."""
    if not HAS_URLLIB:
        print("Error: urllib not available. Cannot download from GitHub.")
        sys.exit(1)

    url = "https://github.com/xgreenrx-star/VisualGasic/archive/refs/heads/main.zip"
    zip_path = os.path.join(temp_dir, "visualgasic.zip")

    print("  Downloading from GitHub...")
    urlretrieve(url, zip_path)

    print("  Extracting...")
    with zipfile.ZipFile(zip_path, "r") as zf:
        zf.extractall(temp_dir)

    return Path(temp_dir) / "VisualGasic-main"


def install(source_dir):
    """Install VG addon and CLI tool from a source directory."""
    global_dir = get_global_dir()
    bin_dir = get_bin_dir()
    addon_dir = global_dir / "addons" / "visual_gasic"

    print(f"  Source:  {source_dir}")
    print(f"  Target:  {global_dir}")
    print(f"  CLI:     {bin_dir / 'vg'}")
    print()

    # Create directories
    addon_dir.parent.mkdir(parents=True, exist_ok=True)
    bin_dir.mkdir(parents=True, exist_ok=True)

    # Remove old addon install
    if addon_dir.exists():
        shutil.rmtree(addon_dir)

    # Copy addon
    print("  Copying addon files...")
    src_addon = source_dir / "addons" / "visual_gasic"
    shutil.copytree(src_addon, addon_dir)

    # Remove .uid files (regenerated per-project)
    for uid_file in addon_dir.rglob("*.uid"):
        uid_file.unlink()

    # Copy VERSION
    version_src = source_dir / "VERSION"
    if version_src.exists():
        shutil.copy2(version_src, global_dir / "VERSION")

    # Install vg CLI tool
    vg_src = source_dir / "vg"
    if vg_src.exists():
        print("  Installing 'vg' CLI tool...")
        vg_dst = bin_dir / "vg"
        shutil.copy2(vg_src, vg_dst)
        # Make executable on Unix
        if platform.system() != "Windows":
            os.chmod(vg_dst, 0o755)

    # On Windows, also create vg.cmd wrapper
    if platform.system() == "Windows" and vg_src.exists():
        vg_cmd = bin_dir / "vg.cmd"
        with open(vg_cmd, "w") as f:
            f.write('@echo off\n')
            f.write(f'bash "%~dp0vg" %*\n')
        print(f"  Created Windows wrapper: {vg_cmd}")

    return global_dir, addon_dir, bin_dir


def print_summary(global_dir, addon_dir, bin_dir):
    """Print installation summary."""
    version = "unknown"
    ver_file = global_dir / "VERSION"
    if ver_file.exists():
        version = ver_file.read_text().strip()

    file_count = sum(1 for _ in addon_dir.rglob("*") if _.is_file())

    # Calculate size
    total_size = sum(f.stat().st_size for f in addon_dir.rglob("*") if f.is_file())
    if total_size > 1024 * 1024 * 1024:
        size_str = f"{total_size / (1024*1024*1024):.1f}G"
    elif total_size > 1024 * 1024:
        size_str = f"{total_size / (1024*1024):.0f}M"
    else:
        size_str = f"{total_size / 1024:.0f}K"

    print()
    print("  ╔══════════════════════════════════════╗")
    print("  ║     ✅ Installation Complete!         ║")
    print("  ╚══════════════════════════════════════╝")
    print()
    print(f"  Version:  {version}")
    print(f"  Files:    {file_count} files ({size_str})")
    print(f"  Addon:    {global_dir}")
    print(f"  CLI:      {bin_dir / 'vg'}")
    print()
    print("  Quick Start:")
    print("    vg new MyGame        # Create a new VG project")
    print("    cd MyGame && godot . # Open in Godot")
    print()
    print("  Add VG to an existing project:")
    print("    cd /path/to/project")
    print("    vg install")
    print()

    # Check PATH
    path_dirs = os.environ.get("PATH", "").split(os.pathsep)
    if str(bin_dir) not in path_dirs:
        print(f"  ⚠  {bin_dir} is not in your PATH.")
        if platform.system() == "Windows":
            print(f'    Add it: setx PATH "%PATH%;{bin_dir}"')
        elif os.path.exists(os.path.expanduser("~/.zshrc")):
            print(f'    Add it: echo \'export PATH="$HOME/.local/bin:$PATH"\' >> ~/.zshrc')
        else:
            print(f'    Add it: echo \'export PATH="$HOME/.local/bin:$PATH"\' >> ~/.bashrc')
        print()


# ── Main ────────────────────────────────────────────────────────────────────

def main():
    print()
    print("  ╔══════════════════════════════════════╗")
    print("  ║     VisualGasic Installer             ║")
    print("  ║    VB6-style language for Godot 4     ║")
    print("  ╚══════════════════════════════════════╝")
    print()

    use_github = "--github" in sys.argv

    temp_dir = None

    if use_github:
        temp_dir = tempfile.mkdtemp()
        try:
            source_dir = download_from_github(temp_dir)
        except Exception as e:
            print(f"  Error downloading: {e}")
            sys.exit(1)
    else:
        source_dir = find_source_dir()
        if source_dir is None:
            print("  Could not find VisualGasic source directory.")
            print("  Run this script from the repo root, or use --github to download.")
            sys.exit(1)

    try:
        global_dir, addon_dir, bin_dir = install(source_dir)
        print_summary(global_dir, addon_dir, bin_dir)
    finally:
        if temp_dir:
            shutil.rmtree(temp_dir, ignore_errors=True)


if __name__ == "__main__":
    main()
