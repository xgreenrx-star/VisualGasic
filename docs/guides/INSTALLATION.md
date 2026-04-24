# VisualGasic Installation Guide

**Version**: 5.1.0-Beta1  
**Requires**: Godot 4.6.1+ (handled automatically by the one-click installer)

Choose your preferred installation method. **Method 1 (one-click installer) is the fastest and easiest way to get started** — no terminal, no Godot setup, no file editing required.

---

## ✨ Method 1: One-Click Installer (Recommended for new users & kids)

A single download that installs Godot, installs VisualGasic, creates a starter project, and registers `.vg` files so double-clicking them opens the IDE. No terminal required.

### Linux

1. Download `VisualGasic-Installer-v5.1.0-Beta1-x86_64.AppImage` from the [latest release](https://github.com/xgreenrx-star/VisualGasic/releases/latest).
2. Right-click → **Properties → Permissions → Allow executing as a program** (or `chmod +x` it).
3. Double-click it.

### Windows

1. Download `VisualGasic-Installer-v5.1.0-Beta1-x86_64.exe` from the [latest release](https://github.com/xgreenrx-star/VisualGasic/releases/latest).
2. Double-click. Click **Install**. Done.

### What the one-click installer does

- Downloads a matching Godot 4.6.1+ and stores it in a private, user-scoped location (no admin needed).
- Installs the VisualGasic editor plugin.
- Creates a **MyFirstGame** project in `~/VisualGasic/` (`%USERPROFILE%\VisualGasic\` on Windows) with VG pre-enabled and a starter `Form1.vg`.
- Adds a **VisualGasic IDE** entry to your Applications menu / Start Menu / Desktop.
- Registers `.vg` files so double-clicking one launches the IDE on that file.

### Choosing a Godot version

You can pick any supported Godot version at install time:

```bash
# Linux: see what's available
./VisualGasic-Installer-v5.1.0-Beta1-x86_64.AppImage --list-godot-versions

# Pick interactively
./VisualGasic-Installer-v5.1.0-Beta1-x86_64.AppImage --pick-godot

# Install a specific version
./VisualGasic-Installer-v5.1.0-Beta1-x86_64.AppImage --godot-version 4.6.2-stable
```

Only **Godot 4.6.1-stable and newer** is supported (the default is `4.6.1-stable`). Pre-release builds can be shown with `--include-prereleases`.

### Optional: set up AI keys during install

VisualGasic's AI Coding Assistant (AGCK plugin) supports OpenAI, Claude, Gemini, and Ollama. You can seed the keys at install time (they're stored in Godot's per-user config with `0600` permissions on POSIX):

```bash
./VisualGasic-Installer-v5.1.0-Beta1-x86_64.AppImage \
    --with-ai-keys \
    --openai-key "sk-..." \
    --claude-key "sk-ant-..." \
    --gemini-key "AIza..."
```

All of these flags are **opt-in**. Without them, the installer writes no keys and the AI assistant stays disabled until you configure it from inside the IDE.

### Offline install (no internet)

Download the appropriate offline bundle instead (`VisualGasic-Installer-Offline-v5.1.0-Beta1-linux-x86_64.zip` or `-windows-x86_64.zip`) — it includes a pre-downloaded Godot. Unzip and follow the `README.txt` inside.

---

## 🚀 Method 2: One-Line Install with `vg` CLI

The `vg` command-line tool installs VisualGasic globally and lets you create new projects instantly.

### Linux / macOS
```bash
curl -sSL https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/install.sh | bash
```

### Windows (PowerShell — run as Administrator or normal user)
```powershell
irm https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/install.ps1 | iex
```

### Cross-Platform (Python 3)
```bash
python3 install.py          # From the repo root (local install)
python3 install.py --github # Download from GitHub automatically
```

### What the Installer Does

1. Downloads the latest VisualGasic release from GitHub
2. Installs the addon to a global location:

   | Platform | Global Location |
   |----------|----------------|
   | **Linux** | `~/.local/share/visual_gasic/` |
   | **macOS** | `~/Library/Application Support/VisualGasic/` |
   | **Windows** | `%APPDATA%\VisualGasic\` |

3. Installs the `vg` CLI tool to `~/.local/bin/` (or `%USERPROFILE%\.local\bin\vg.cmd` on Windows)

### Using the `vg` CLI

After installation, the `vg` command is available from any terminal:

```bash
# Create a new Godot project with VG pre-installed and enabled
vg new MyGame
cd MyGame && godot .

# Add VG to an existing Godot project
cd /path/to/existing/project
vg install

# Update your global VG installation (from the source repo)
cd /path/to/VisualGasic
vg update

# Package management
vg pkg install MathLibrary@^2.1.0
vg pkg search "physics"
vg pkg list

# Show version and help
vg version
vg help
```

**What `vg new` creates:**
```
MyGame/
├── project.godot          # Plugin already enabled, autoloads configured
├── addons/visual_gasic/   # Complete addon with binaries
├── Form1.vg               # Starter form with Form_Load and Form_Click
├── icon.svg               # Project icon
└── .gitignore             # Configured for Godot
```

> **Note:** If `~/.local/bin` is not in your PATH, add it:
> ```bash
> echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
> ```

---

## 🎨 Method 3: From the VG IDE (Inside Godot)

If you already have a VG project open in Godot, you can create new projects without leaving the editor:

### Step-by-Step Walkthrough

1. **Open an existing VG project** in Godot (or create one with `vg new` first)

2. **Switch to the Visual Gasic IDE** main screen tab (top of the editor, between "2D", "3D", "Script", etc.)

3. **Go to File → New Project...** in the VG IDE menu bar

4. **Enter a project name** — only letters, digits, hyphens, and underscores allowed

5. **Choose a folder** — a file browser opens to select the parent directory

6. **Click Create** — the new project is generated with:
   - `project.godot` with the VG plugin already enabled
   - `addons/visual_gasic/` copied from your current project
   - A starter `Form1.vg` file ready to edit
   - The project opens in a new Godot instance

### Also Available from the Tools Menu

The VG plugin registers a **Tools → New VG Project...** menu item, so you can also create projects from the main Godot menu without switching to the VG IDE screen.

### Creating New Forms and Modules

Within an existing project, use the VG IDE's File menu:
- **File → New Form** — creates a new `.vg` form file with Form_Load stub
- **File → New Module** — creates a new `.vg` module file
- **File → Open** — opens an existing `.vg` file

---

## 📥 Method 4: Manual Installation (From GitHub Release)

### Download

1. Go to [Releases](https://github.com/xgreenrx-star/VisualGasic/releases/latest)
2. Download the platform zip for your OS:
   - Linux: `VisualGasic_v5.1.0-Beta1_linux_x86_64.zip`
   - Windows: `VisualGasic_v5.1.0-Beta1_windows_x86_64.zip`

### Install into a New Project

```bash
# Create a Godot project first (or use an existing one)
mkdir MyGame && cd MyGame
# Initialize a minimal project.godot if needed:
echo 'config_version=5
[application]
config/name="MyGame"' > project.godot

# Extract the addon
unzip VisualGasic_v5.1.0-Beta1_linux_x86_64.zip
cp -r addons/ .

# Open in Godot
godot .
```

Then enable the plugin: **Project → Project Settings → Plugins → VisualGasic ✓**

### Install into an Existing Project

```bash
cd /path/to/your/godot/project
unzip VisualGasic_v5.1.0-Beta1_linux_x86_64.zip -d /tmp/vg_temp
cp -r /tmp/vg_temp/addons/visual_gasic addons/
rm -rf /tmp/vg_temp
```

Restart Godot and enable the plugin in Project Settings.

### Pre-Built Binaries (Included)

The release zip contains pre-compiled binaries for all platforms:

| Platform | Binary Files |
|----------|-------------|
| **Linux** x86_64 | `libvisualgasic.linux.editor.x86_64.so`, `...template_debug...`, `...template_release...` |
| **Windows** x86_64 | `libvisualgasic.windows.editor.x86_64.dll`, `...template_debug...`, `...template_release...` |
| **macOS** Universal | `libvisualgasic.macos.editor.framework/`, `...template_debug...`, `...template_release...` |

---

## 🔧 Method 5: Build from Source

### Prerequisites
- **Godot 4.6.1+** binary
- **SCons** build system (`pip install scons`)
- **Git** with submodules
- **C++ compiler**: GCC 9+, Clang 10+, or MSVC 2019+
- **MinGW** (optional, for Windows cross-compilation): `sudo apt install g++-mingw-w64-x86-64`

### Build Steps

```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/xgreenrx-star/VisualGasic.git
cd VisualGasic

# Build for your platform
scons platform=linux target=editor -j$(nproc)        # Linux
scons platform=windows target=editor -j$(nproc)       # Windows (MinGW cross-compile)
scons platform=macos target=editor -j$(sysctl -n hw.logicalcpu)  # macOS

# The compiled extension appears in demo/bin/
```

### Install into Your Project

```bash
mkdir -p YourProject/addons/visual_gasic/bin/
cp -r addons/visual_gasic/* YourProject/addons/visual_gasic/
cp demo/bin/libvisualgasic.* YourProject/addons/visual_gasic/bin/
```

### Build All Platforms (Release Script)

For building distributable release packages:

```bash
# Build Linux + Windows (from Linux with MinGW), creates release zips
./scripts/build_release.sh

# Or on macOS (builds all three including universal binary)
./scripts/build_release.sh
```

Output goes to `release/v<version>/`.

---

## ✅ Verification

After installation, verify VisualGasic is working:

1. **Check the plugin is enabled**: Project → Project Settings → Plugins → VisualGasic should show ✓
2. **Switch to the Visual Gasic IDE** main screen — you should see the Form Designer with Toolbox, Canvas, and Properties Panel
3. **Create a test file** — create `hello.vg`:
   ```vb
   Sub Main()
       Print "Hello from VisualGasic!"
   End Sub
   ```
4. **Attach to a node** and run — you should see the output in the console
5. **Try the Immediate Window** — click the "Immediate" tab in the bottom panel, type `2 + 2` and press Enter

---

## 🆘 Troubleshooting

### Plugin Not Showing Up
- Restart Godot after installation
- Check that `addons/visual_gasic/plugin.cfg` exists
- Verify the extension binary is in `addons/visual_gasic/bin/`

### Extension Failed to Load
- Ensure you downloaded the correct platform version
- Check Godot console (Output tab) for error messages
- Verify Godot version is 4.6.1 or newer
- On macOS: right-click the Godot app → Open (bypasses Gatekeeper on first run)

### `vg` Command Not Found
- Ensure `~/.local/bin` is in your PATH
- On Windows: ensure `%USERPROFILE%\.local\bin` is in your system PATH
- Try running the installer again

### Build Issues
- Update godot-cpp submodule: `git submodule update --init --recursive`
- Install SCons: `pip install scons`
- On Linux: `sudo apt install build-essential libffi-dev`
- On macOS: `xcode-select --install`

---

## 📚 Next Steps

After installation:

1. **[Getting Started Guide](GET_STARTED.md)** — beginner-friendly walkthrough
2. **[Built-in Functions Reference](../reference/BUILTIN_FUNCTIONS_REFERENCE.md)** — all 108 functions
3. **[VB6 Features](../reference/VB6_FEATURES_IMPLEMENTATION.md)** — VB6 compatibility reference
4. **[Examples](../../examples/)** — example programs
5. **[Demo Projects](../../demos/)** — 14 playable game demos
6. **[Community](../../COMMUNITY_HUB.md)** — get help, share projects

---

*Installation help: [GitHub Issues](https://github.com/xgreenrx-star/VisualGasic/issues) · [Community Hub](../../COMMUNITY_HUB.md)*
