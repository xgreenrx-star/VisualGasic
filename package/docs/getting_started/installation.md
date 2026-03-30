# Installation

VisualGasic is distributed as a **GDExtension** — native C++ code that extends Godot without requiring an engine recompile. Installation takes under 2 minutes.

## Prerequisites

- **Godot Engine 4.5 or newer** (4.6+ recommended)
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
cd MyGame && godot .
```

The `vg` CLI tool supports additional commands:

| Command | Description |
|---------|-------------|
| `vg new <name>` | Create a new Godot project with VisualGasic pre-installed |
| `vg install` | Install the VG addon into the current Godot project |
| `vg update` | Update the global VG installation |
| `vg version` | Show version info |
| `vg pkg install <name>` | Install a VG package from the registry |
| `vg pkg search <query>` | Search the package registry |
| `vg help` | Show all commands |

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

## Verifying the Installation

After installation, open your project in Godot. You should see:

- **VisualGasic** available as a script language when attaching scripts to nodes
- The **VG IDE** accessible from the editor (Form Designer, Properties panel, Toolbox, Immediate Window)
- `addons/visual_gasic/` present in the FileSystem dock

---

## Troubleshooting

### "Unable to load GDExtension"
- Ensure you downloaded the correct build for your operating system (Windows, Linux, or macOS).
- Make sure you are running **Godot 4.5 or newer**.
- Check that the `.gdextension` file and the shared library (`.so`, `.dll`, or `.dylib`) are both present in `addons/visual_gasic/bin/`.

### "VisualGasic resource not found"
- Restart the Godot editor. GDExtensions are detected on startup, so a restart is required after installing.

### `vg` command not found
- Make sure `~/.local/bin` is in your `PATH`. Add this to your shell config (`.bashrc`, `.zshrc`, etc.):
  ```bash
  export PATH="$HOME/.local/bin:$PATH"
  ```
- On Windows, ensure `%USERPROFILE%\.local\bin` is in your system PATH.
