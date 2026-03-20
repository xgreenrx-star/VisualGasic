# VisualGasic Installation Guide

Choose your preferred installation method:

## 🚀 Quick Install — `vg` CLI (Recommended)

The `vg` command-line tool installs VisualGasic globally and lets you create new projects instantly.

### Linux / macOS
```bash
curl -sSL https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/install.sh | bash
```

### Windows (PowerShell)
```powershell
iwr -useb https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/install.ps1 | iex
```

### Cross-Platform (Python)
```bash
python3 install.py          # From the repo root
python3 install.py --github # Or download from GitHub automatically
```

### Using the `vg` CLI

After installation, the `vg` command is available:

```bash
# Create a new Godot project with VG pre-installed and enabled
vg new MyGame
cd MyGame && godot .

# Add VG to an existing Godot project
cd /path/to/existing/project
vg install

# Update your global VG installation (from the repo)
cd /path/to/VisualGasic
vg update

# Show version and help
vg version
vg help
```

The `vg new` command creates:
- `project.godot` with the VG plugin already enabled
- `addons/visual_gasic/` with all binaries
- A starter `Form1.vg` file
- `.gitignore` configured for Godot

> **Note:** The `vg` tool is installed to `~/.local/bin/`. If it's not in your PATH, add it:
> ```bash
> echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
> ```

---

## 🎨 From the VG IDE (Inside Godot)

If you already have a VG project open in Godot:

1. Switch to the **Visual Gasic IDE** main screen
2. Go to **File → New Project...**
3. Enter a project name and choose a folder
4. Click **Create** — a new VG-ready project is created and opened in a new Godot instance

This is the easiest way to start a new project without leaving the editor.

---

## 📦 Manual Installation

### Method 1: From GitHub Releases

1. Download the latest release from [Releases](https://github.com/xgreenrx-star/VisualGasic/releases)
2. Extract the archive
3. Copy the `addons/visual_gasic/` folder to your Godot project's `addons/` directory
4. Enable the plugin in Project → Project Settings → Plugins

### Method 2: From Asset Library (Coming Soon)

1. Open Godot
2. Click on the AssetLib tab
3. Search for "VisualGasic"
4. Click Download → Install
5. Enable the plugin in Project Settings → Plugins

### Method 3: Git Clone

```bash
cd YourGodotProject
git clone https://github.com/xgreenrx-star/VisualGasic.git temp_visualgasic
mkdir -p addons
cp -r temp_visualgasic/addons/visual_gasic addons/
rm -rf temp_visualgasic
```

Then enable the plugin in Godot.

---

## 🎯 Global Installation Details

The installer scripts store the VG addon at a global location so `vg new` can create projects without downloading every time:

| Platform | Global Location |
|----------|----------------|
| **Linux** | `~/.local/share/visual_gasic/` |
| **macOS** | `~/Library/Application Support/VisualGasic/` |
| **Windows** | `%APPDATA%\VisualGasic\` |

To update the global installation from source:
```bash
cd /path/to/VisualGasic
vg update
```

---

## 🔧 Building from Source

### Prerequisites
- Godot 4.5+ source or binary
- SCons build system
- Git with submodules
- Modern C++ compiler (GCC 9+, Clang 10+, MSVC 2019+)

### Build Steps

```bash
# Clone with submodules
git clone --recursive https://github.com/xgreenrx-star/VisualGasic.git
cd VisualGasic

# Build the extension
scons platform=linux target=template_debug    # Linux
scons platform=windows target=template_debug  # Windows
scons platform=macos target=template_debug    # macOS

# The compiled extension will be in bin/
```

### Install Built Extension

Copy the compiled extension to your project:
```bash
mkdir -p YourProject/addons/visual_gasic/bin/
cp -r addons/visual_gasic/* YourProject/addons/visual_gasic/
cp bin/* YourProject/addons/visual_gasic/bin/
```

---

## ✅ Verification

After installation, verify VisualGasic is working:

1. Create a new `.vg` file in your project:
   ```vb
   ' hello.vg
   Sub Main()
       Print "Hello from VisualGasic!"
   End Sub
   ```

2. Attach it to a node as a script
3. Run the project
4. You should see the output in the console

---

## 🆘 Troubleshooting

### Plugin Not Showing Up
- Restart Godot after installation
- Check that `addons/visual_gasic/plugin.cfg` exists
- Verify the extension binary is in `addons/visual_gasic/bin/`

### Extension Failed to Load
- Ensure you downloaded the correct platform version
- Check Godot console for error messages
- Verify Godot version is 4.5 or newer

### Template Not Available
- Verify template is in the correct directory
- Check that `.template.cfg` exists in the template folder
- Restart Godot to refresh template list

### Build Issues
- Update godot-cpp submodule: `git submodule update --init --recursive`
- Install SCons: `pip install scons`
- Check compiler version meets requirements

---

## 📚 Next Steps

- Read the [Getting Started Guide](GET_STARTED.md)
- Check out [Examples](examples/)
- Join our [Community](COMMUNITY_HUB.md)
- Read the [Documentation](docs/)

---

## 🔗 Links

- **GitHub**: https://github.com/xgreenrx-star/VisualGasic
- **Issues**: https://github.com/xgreenrx-star/VisualGasic/issues
- **Documentation**: [docs/](docs/)
- **License**: GPL v3
