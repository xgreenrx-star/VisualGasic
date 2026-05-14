#!/usr/bin/env python3
"""VisualGasic Installer — Cross-platform Python installer.

Installs the VisualGasic addon globally and the `vg` CLI tool.

Usage:
    python3 install.py                       # Install from local source (run from repo root)
    python3 install.py --github              # Download latest release from GitHub
    python3 install.py --github --tag vX.Y.Z # Download a specific release tag
    python3 install.py --github --main       # Download bleeding-edge main branch (legacy)

After installation:
    vg new MyGame
    cd MyGame && godot .
"""

import os
import sys
import json
import shutil
import platform
import tempfile
import zipfile
from pathlib import Path

try:
    from urllib.request import urlretrieve, urlopen, Request
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


def _github_latest_release_tag():
    """Query the GitHub API for the latest release tag.

    Returns the newest release including pre-releases, since Beta tags are
    marked as pre-release on GitHub and /releases/latest skips those.
    """
    api = "https://api.github.com/repos/xgreenrx-star/VisualGasic/releases"
    req = Request(api, headers={"Accept": "application/vnd.github+json"})
    with urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    if not isinstance(data, list) or not data:
        return None
    # data is ordered newest-first by GitHub
    return data[0].get("tag_name")


def download_from_github(temp_dir, tag=None, use_main=False):
    """Download VisualGasic from GitHub and return the source directory.

    Priority: explicit `tag` → latest release tag (incl. pre-releases) → main.
    Falls back to main.zip if the release lookup fails or `use_main` is set.
    """
    if not HAS_URLLIB:
        print("Error: urllib not available. Cannot download from GitHub.")
        sys.exit(1)

    repo = "https://github.com/xgreenrx-star/VisualGasic"

    resolved_tag = None
    if not use_main:
        if tag:
            resolved_tag = tag
        else:
            try:
                resolved_tag = _github_latest_release_tag()
            except Exception as e:
                print(f"  ⚠  Could not query latest release ({e}); falling back to main.")

    if resolved_tag:
        url = f"{repo}/archive/refs/tags/{resolved_tag}.zip"
        extracted_name = f"VisualGasic-{resolved_tag.lstrip('v')}"
        print(f"  Downloading release {resolved_tag}...")
    else:
        url = f"{repo}/archive/refs/heads/main.zip"
        extracted_name = "VisualGasic-main"
        print("  Downloading main branch...")

    zip_path = os.path.join(temp_dir, "visualgasic.zip")
    urlretrieve(url, zip_path)

    print("  Extracting...")
    with zipfile.ZipFile(zip_path, "r") as zf:
        zf.extractall(temp_dir)

    extracted = Path(temp_dir) / extracted_name
    # Tag zips may use a slightly different top-level dir name; fall back to
    # the single top-level directory inside the archive.
    if not extracted.exists():
        children = [p for p in Path(temp_dir).iterdir() if p.is_dir()]
        if len(children) == 1:
            extracted = children[0]
    return extracted


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

    # Create conflict-proof 'visualgasic' alias
    if platform.system() != "Windows":
        vg_alias = bin_dir / "visualgasic"
        try:
            if vg_alias.exists() or vg_alias.is_symlink():
                vg_alias.unlink()
            vg_alias.symlink_to(bin_dir / "vg")
        except OSError:
            pass

    return global_dir, addon_dir, bin_dir


def print_summary(global_dir, addon_dir, bin_dir, godot_bin=None):
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
    print(f"  CLI:      {bin_dir / 'vg'}  (also available as 'visualgasic')")
    print()
    print("  Quick Start:")
    print("    vg new MyGame        # Create a new VG project")
    if godot_bin:
        print(f"    cd MyGame && godot . # Open in Godot  (using: {godot_bin})")
    else:
        print("    cd MyGame && godot . # Open in Godot  ← install Godot first!")
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

    # Detect naming conflict with system vg (cgvg package)
    if platform.system() != "Windows":
        system_vg = None
        for p in ["/usr/bin/vg", "/bin/vg", "/usr/local/bin/vg"]:
            if os.path.isfile(p) and os.access(p, os.X_OK) and p != str(bin_dir / "vg"):
                try:
                    with open(p, "r") as f:
                        first_line = f.readline()
                    if "perl" in first_line:
                        system_vg = p
                        break
                except (OSError, UnicodeDecodeError):
                    pass

        if system_vg:
            print(f"  ⚠  Name conflict: {system_vg} (from the 'cgvg' package)")
            print()
            print("  Your shell may run the wrong 'vg'. To fix:")
            print("    hash -r              # Refresh shell cache, then: vg version")
            print("    sudo apt remove cgvg # Or remove the conflicting package")
            print(f"    {bin_dir / 'vg'}     # Or use the full path")
            print("    visualgasic new MyGame  # Or use the alias")
            print()


# ── Main ────────────────────────────────────────────────────────────────────

def check_or_install_godot(global_dir, bin_dir):
    """Detect Godot on PATH or in the VG-managed dir; offer to download if missing.
    Returns the path to the godot binary string, or None if not installed."""
    import shutil as _shutil
    import zipfile
    import urllib.request

    GODOT_VERSION = "4.6.1"
    GODOT_TAG = "4.6.1-stable"

    # 1. Already on PATH?
    godot_on_path = _shutil.which("godot")
    if godot_on_path:
        print(f"  ✅ Godot found: {godot_on_path}")
        return godot_on_path

    # 2. VG-managed canonical symlink / binary?
    vg_godot = global_dir / "godot"
    if vg_godot.exists() or vg_godot.is_symlink():
        print(f"  ✅ Godot found (VG-managed): {vg_godot}")
        return str(vg_godot)

    # 3. Not found — prompt
    print()
    print(f"  ⚠  Godot {GODOT_VERSION} not found on PATH.")
    print(f"     Godot is required to run VisualGasic projects.")
    print()

    skip = False
    if sys.stdin.isatty() and sys.stdout.isatty() and os.environ.get("VG_INSTALL_GODOT", "1") != "0":
        ans = input(f"  Download Godot {GODOT_VERSION} now? (~80 MB) [Y/n] ").strip().lower()
        if ans in ("n", "no"):
            skip = True
    elif os.environ.get("VG_INSTALL_GODOT", "1") == "0":
        skip = True
        print("  Skipping Godot download (VG_INSTALL_GODOT=0).")

    if skip:
        print(f"  Skipped. Download Godot from: https://godotengine.org/download/")
        print(f"  ⚠  Make sure 'godot' is on your PATH before running VG projects.")
        return None

    # 4. Download
    system = platform.system()
    machine = platform.machine().lower()
    if system == "Darwin":
        zip_url = f"https://github.com/godotengine/godot/releases/download/{GODOT_TAG}/Godot_v{GODOT_TAG}_macos.universal.zip"
        bin_inside = "Godot.app/Contents/MacOS/Godot"
    elif "arm" in machine or "aarch64" in machine:
        zip_url = f"https://github.com/godotengine/godot/releases/download/{GODOT_TAG}/Godot_v{GODOT_TAG}_linux.arm64.zip"
        bin_inside = f"Godot_v{GODOT_TAG}_linux.arm64"
    else:
        zip_url = f"https://github.com/godotengine/godot/releases/download/{GODOT_TAG}/Godot_v{GODOT_TAG}_linux.x86_64.zip"
        bin_inside = f"Godot_v{GODOT_TAG}_linux.x86_64"

    print(f"  Downloading Godot {GODOT_VERSION}...")
    godot_bin_dir = global_dir / "bin"
    godot_bin_dir.mkdir(parents=True, exist_ok=True)
    zip_path = godot_bin_dir / "godot.zip"

    try:
        def _progress(block, block_size, total):
            if total > 0:
                pct = min(100, block * block_size * 100 // total)
                print(f"\r    {pct}%", end="", flush=True)
        urllib.request.urlretrieve(zip_url, zip_path, reporthook=_progress)
        print()

        with zipfile.ZipFile(zip_path) as z:
            z.extractall(godot_bin_dir)
        zip_path.unlink(missing_ok=True)

        if system == "Darwin":
            godot_real = godot_bin_dir / "Godot.app" / "Contents" / "MacOS" / "Godot"
        else:
            godot_real = godot_bin_dir / bin_inside
        godot_real.chmod(0o755)

        # Canonical VG symlink (picked up by `vg` CLI without PATH changes)
        vg_godot.unlink(missing_ok=True)
        vg_godot.symlink_to(godot_real)
        # Also symlink into ~/.local/bin so `godot .` works in the shell
        shell_godot = bin_dir / "godot"
        shell_godot.unlink(missing_ok=True)
        shell_godot.symlink_to(godot_real)

        print(f"  ✅ Godot {GODOT_VERSION} installed to {godot_bin_dir}")
        return str(shell_godot)

    except Exception as e:
        print(f"\n  ⚠  Godot download failed: {e}")
        print(f"     Install manually from: https://godotengine.org/download/")
        return None


def main():
    print()
    print("  ╔══════════════════════════════════════╗")
    print("  ║     VisualGasic Installer             ║")
    print("  ║    VB6-style language for Godot 4     ║")
    print("  ╚══════════════════════════════════════╝")
    print()

    use_github = "--github" in sys.argv
    use_main = "--main" in sys.argv
    tag = None
    if "--tag" in sys.argv:
        i = sys.argv.index("--tag")
        if i + 1 < len(sys.argv):
            tag = sys.argv[i + 1]

    temp_dir = None

    if use_github:
        temp_dir = tempfile.mkdtemp()
        try:
            source_dir = download_from_github(temp_dir, tag=tag, use_main=use_main)
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
        godot_bin = check_or_install_godot(global_dir, bin_dir)
        print_summary(global_dir, addon_dir, bin_dir, godot_bin=godot_bin)
    finally:
        if temp_dir:
            shutil.rmtree(temp_dir, ignore_errors=True)


if __name__ == "__main__":
    main()
