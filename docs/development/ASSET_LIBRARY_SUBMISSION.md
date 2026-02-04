# Submit to Godot Asset Library

To submit VisualGasic to the Godot Asset Library, follow these steps:

## 1. Prepare the Submission

✅ **Already completed:**
- Plugin metadata in `addons/visual_gasic/plugin.cfg`
- Asset library metadata in `.assetlib.json`
- Installation documentation in `INSTALLATION.md`
- Clean repository structure
- MIT-compatible GPL v3 license

## 2. Create a GitHub Release

```bash
cd /home/Commodore/Documents/VisualGasic
git tag -a v1.0.0 -m "Initial public release - v1.0.0"
git push origin v1.0.0
```

Then on GitHub:
1. Go to https://github.com/xgreenrx-star/VisualGasic/releases
2. Click "Draft a new release"
3. Select tag: v1.0.0
4. Title: "VisualGasic v1.0.0"
5. Description: Copy from README.md or write release notes
6. Attach compiled binaries (optional but recommended):
   - `visualgasic-linux-v1.0.0.zip`
   - `visualgasic-windows-v1.0.0.zip`
   - `visualgasic-macos-v1.0.0.zip`
7. Click "Publish release"

## 3. Submit to Asset Library

1. Visit: https://godotengine.org/asset-library/submit
2. Log in with GitHub account
3. Fill out the submission form:

**Asset Information:**
- **Title**: VisualGasic
- **Description**: Modern programming language for Godot 4 with advanced features including multitasking, pattern matching, GPU computing, and comprehensive development tools.
- **Category**: Scripts
- **Godot Version**: 4.5
- **License**: GPL v3.0
- **Repository URL**: https://github.com/xgreenrx-star/VisualGasic
- **Issues URL**: https://github.com/xgreenrx-star/VisualGasic/issues
- **Download URL**: Use the GitHub release zip URL
- **Version**: 1.0.0
- **Icon URL**: https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/addons/visual_gasic/icon.svg
- **Download Method**: GitHub Release

**Screenshots/Previews:**
Upload screenshots showing:
1. Code editor with .vg file
2. Example project running
3. IDE features (autocomplete, etc.)
4. REPL/debugging interface

4. Submit for review
5. Wait for moderator approval (usually 1-3 days)

## 4. After Approval

Users can install VisualGasic directly from Godot:
1. Open Godot
2. Click AssetLib tab
3. Search "VisualGasic"
4. Click Download → Install

## Installation Methods Summary

✅ **Option 1: One-Click Install (Live Now)**
```bash
curl -sSL https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/install.sh | bash
```

✅ **Option 2: Asset Library (Pending Submission)**
- Search in Godot's AssetLib
- One-click install

✅ **Option 3: Manual**
- Download from GitHub Releases
- Copy to project addons folder

✅ **Option 4: Build from Source**
- Clone and build with SCons
- Full development setup

## Files Created for Auto-Install

1. ✅ `install.sh` - Linux/macOS installer
2. ✅ `install.ps1` - Windows PowerShell installer  
3. ✅ `install.py` - Cross-platform Python installer
4. ✅ `INSTALLATION.md` - Complete installation guide
5. ✅ `.assetlib.json` - Asset Library metadata
6. ✅ Updated `plugin.cfg` - Plugin metadata
7. ✅ Updated `README.md` - Installation instructions

## Testing the Installers

### Linux/macOS:
```bash
./install.sh
```

### Windows:
```powershell
.\install.ps1
```

### Python (all platforms):
```bash
python3 install.py
```

## Next Steps

1. ✅ Commit and push the new files
2. 🔲 Create GitHub release v1.0.0
3. 🔲 Submit to Godot Asset Library
4. 🔲 Announce on Godot forums/Discord
5. 🔲 Add badges to README (AssetLib downloads, etc.)

---

**Installation is ready!** Users can now install VisualGasic with a single command. 🚀
