🎉 **VisualGasic 5.3.0-Beta6** fixes the standalone **`End`** command (Exit buttons work again), adds VB6 **`""` string escape** support, hardens conversion builtins, and ships a **Programmer's Reference runtime gate** in CI.

**856/856 regression · 332/332 reference examples parse · End/DoEvents/Throw runtime-verified**

### Screenshots

![Narcea menu form — End and ChangeScene](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/screenshots/beta6_narcea_menu_form_end_command.png?raw=true)

![AI Provider API Keys](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/screenshots/beta6_narcea_ai_provider_keys.png?raw=true)

![Command Help panel](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/screenshots/ide_command_help.png?raw=true)

### 🛠 Fixed: `End` and Critical Builtins

Standalone `End` now calls `SceneTree.quit()`. Also: `DoEvents`, `Throw`, `LoadForm`, `ChangeScene`, VB6 `""` string escapes, conversion builtins, `Deg2Rad`/`Rad2Deg`, Godot 4.6 OptionButton popup compatibility.

### ✅ Added: Reference Quality Gates

CI parse gate, Asset Library smoke script, nightly full example run (non-blocking).

Full details: [RELEASE_NOTES_5.3.0-Beta6.md](https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_5.3.0-Beta6.md)

📚 **Documentation:** [Docs Hub](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/DOCS.md) · [Getting Started](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/guides/GET_STARTED.md) · [Installation](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/guides/INSTALLATION.md) · [Language Reference](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/VisualGasic_Language_Reference.md) · [Built-in Functions](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/reference/BUILTIN_FUNCTIONS_REFERENCE.md)

---

### 📦 Downloads

| Platform | Package |
|---|---|
| **Linux** | `VisualGasic-Installer-v5.3.0-Beta6-x86_64.AppImage` (recommended) or `VisualGasic_v5.3.0-Beta6_linux_x86_64.zip` |
| **Windows** | `VisualGasic-Installer-v5.3.0-Beta6-x86_64.exe` (recommended) or `VisualGasic_v5.3.0-Beta6_windows_x86_64.zip` |
| **Offline** | `VisualGasic-Installer-Offline-v5.3.0-Beta6-linux-x86_64.zip` · `VisualGasic-Installer-Offline-v5.3.0-Beta6-windows-x86_64.zip` (Godot 4.6.1 bundled) |
| **Asset Library** | `VisualGasic_AssetLibrary_v5.3.0-Beta6.zip` |

Manual install: extract zip into `addons/`, enable plugin, restart Godot.

### 🧪 Testing

```bash
./scripts/run_command_reference_gate.sh
./scripts/run_asset_library_smoke.sh
```
