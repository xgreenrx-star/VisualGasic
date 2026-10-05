# Installation

VisualGasic is distributed as a **GDExtension** — native C++ code that extends Godot without requiring an engine recompile. Installation takes under 2 minutes.

## Prerequisites

- **Godot Engine 4.6.1 or newer**
- A created Godot project (or use `vg new` to create one — see below)

---

## Method 1: One-Line Install Scripts (Recommended)

The fastest way to get started. These scripts install VisualGasic globally and set up the `vg` CLI tool so you can create new projects instantly.

### Linux / macOS

```bash
curl -sSL https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/install.ps1 | iex
```

### Cross-Platform (Python)

```bash
python3 install.py            # Install from local source (run from repo root)
python3 install.py --github   # Download and install from GitHub
```

After installation, create a new VG-ready project:

```bash
vg new MyGame
cd MyGame && godot . --editor
```

From an already-open VG project you can also use **Project → VGasic Tools → New VG Project…** (does not close the current project; see the full [Installation Guide](../guides/INSTALLATION.md#method-3-new-project-from-inside-godot)).

The `vg` CLI tool supports (see **`vg help`** for the authoritative list):

| Command | Description |
|---------|-------------|
| `vg new <name>` | Create a new Godot project with VisualGasic pre-installed |
| `vg new <name> --no-open` | Same, without auto-launching Godot |
| `vg install` | Install the VG addon into the current Godot project |
| `vg update` | Update the global VG installation from source |
| `vg version` | Show version info |
| `vg help` | Show all commands |
| `vg pkg install <name>[@ver]` | Install a package from the registry |
| `vg pkg remove <name>` | Remove an installed package |
| `vg pkg search <query>` | Search the package registry |
| `vg pkg list` | List installed packages |
| `vg pkg info <name>` | Show package details |
| `vg pkg init [name]` | Create a `vg.json` manifest |
| `vg pkg update [name]` | Update all packages or one by name |

---

## Method 2: Manual Install (GitHub Release ZIP)

1. Download the latest release ZIP from [GitHub Releases](https://github.com/xgreenrx-star/VisualGasic/releases).
2. **Extract the ZIP**. You should see an `addons` folder.
3. **Copy** the `addons/visual_gasic` folder into your Godot project's root directory.
   - If you already have an `addons` folder, merge them.
4. **Restart Godot**. GDExtensions are loaded when the editor starts.
5. **Verify**. In the FileSystem dock, confirm that `addons/visual_gasic/` exists. You can now create a VisualGasic script by right-clicking in the FileSystem dock.

---

## Method 3: Install Into an Existing Project

If you already have a Godot project and VisualGasic installed globally (via Method 1):

```bash
cd /path/to/your/project
vg install
```

This copies the addon into your project's `addons/visual_gasic/` directory.

---

## Enable the plugin

In every project that uses VisualGasic:

1. **Project → Project Settings → Plugins**
2. Enable **visual_gasic**
3. Restart the editor if the GDExtension was just copied in

## Verifying the Installation

After installation, open your project in Godot. You should see:

- **VisualGasic** available as a script language when attaching scripts to nodes
- **VGasic workspace** panels (Code Navigator, Properties, Toolbox, Vibe Code) on Godot’s Script/2D/3D editors; legacy Form Designer is **experimental Alpha** — [VG IDE Alpha](../manual/VG_IDE_ALPHA.md)
- `addons/visual_gasic/` present in the FileSystem dock
- Toolbox includes standard controls plus **ScreenBox** (classic BASIC `SCREEN` host) when the addon is current

---

## Troubleshooting

### "Unable to load GDExtension"
- Ensure you downloaded the correct build for your operating system (Windows, Linux, or macOS).
- Make sure you are running **Godot 4.6.1 or newer**.
- Check that the `.gdextension` file and the shared library (`.so`, `.dll`, or `.dylib`) are both present in `addons/visual_gasic/bin/`.

### "VisualGasic resource not found"
- Restart the Godot editor. GDExtensions are detected on startup, so a restart is required after installing.

### `vg` command not found
- Make sure `~/.local/bin` is in your `PATH`. Add this to your shell config (`.bashrc`, `.zshrc`, etc.):
  ```bash
  export PATH="$HOME/.local/bin:$PATH"
  ```
- On Windows, ensure `%USERPROFILE%\.local\bin` is in your system PATH.
