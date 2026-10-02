🚀 **VisualGasic 5.6.0-beta1** — **Windows x64 native JIT ships for the first time** (Tier 2 / Tier 3, same path as Linux). We need your feedback on real Windows machines. **C++ GDExtension core** also grew a vector **depth mesh** path (`BuildDepthMesh` / `AddWireTri3D`) powering the **Vector Crypt** procedural neon 3D showcase, plus QB/classic speedups and `Interface`/`Implements`.

### ⚡ Windows JIT (first inclusion — feedback wanted)

- Hot numeric `.vg` code can compile to native x64 on **Windows** after warmup (disable with `VG_JIT=0`).
- Tier 3 fused call-graphs no longer bail with “platform not supported” on Win64.
- **Not in CI yet:** published Windows-vs-Linux JIT benchmark tables. Please report FPS, correctness, and any need for `VG_JIT=0`.
- Docs: [performance.md](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/manual/performance.md)

### 🧱 C++ engine / GDExtension (VG core)

- **Vector canvas depth mesh** — `AddWireTri3D`, `BuildDepthMesh` + depth-cache slots for SubViewport / MeshInstance3D (neon fill + edge coats with correct occlusion)
- **QB / classic** — faster 32-bit screen path; quarter-pixel LINE; PAINT / LINE color fixes
- **Runtime** — JIT ByRef/ByVal float slots; Linux Python bridge large-array lane; rebuilt Linux/Windows/Web binaries
- **Language** — `Interface` / `Implements`; M8 parity (named args, optional chains, block lambdas, cross-module exceptions, `Declare`/`DllImport` Alias)

### Showcase — Vector Crypt + BASIC-256

- `samples/apps/vector_crypt/` — 100% procedural 3D neon facility on the new depth-mesh API.
- **Video:** [Vector Crypt on YouTube](https://youtu.be/ntpOTNflE_M)
- BASIC-256 gallery ports in `qb_abc_showcase` (`,` menu)

### Also in this beta

- IDE: fast step-into, tooltips/Data Tips, Go to Definition across imports, plugin load fix, panel/dock polish

Full notes: [RELEASE_NOTES_v5.6.0-beta1.md](https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_v5.6.0-beta1.md) · [CHANGELOG](https://github.com/xgreenrx-star/VisualGasic/blob/main/CHANGELOG.md#560-beta1---2026-10-02)

### Documentation

- [Documentation Hub](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/DOCS.md)
- [Getting Started](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/guides/GET_STARTED.md)
- [Installation Guide](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/guides/INSTALLATION.md)
- [Performance / JIT](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/manual/performance.md)
- [Language Reference](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/VisualGasic_Language_Reference.md)
- [Godot Programming Manual](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/GODOT_PROGRAMMING_MANUAL.md)

### Downloads

> Install **Godot 4.6.1+**, then use a one-click installer, offline bundle, or **Asset Library zip**.

| Platform | Asset |
|----------|-------|
| **Linux** | `VisualGasic-Installer-v5.6.0-beta1-x86_64.AppImage` |
| **Windows** | `VisualGasic-Installer-v5.6.0-beta1-x86_64.exe` |
| **Offline** | `VisualGasic-Installer-Offline-v5.6.0-beta1-linux-x86_64.zip` · `VisualGasic-Installer-Offline-v5.6.0-beta1-windows-x86_64.zip` |
| **Asset Library** | `VisualGasic_AssetLibrary_v5.6.0-beta1.zip` · [store listing](https://store.godotengine.org/asset/visual-gasic/visual-gasic/) |
| **Manual (BYO Godot)** | `VisualGasic-v5.6.0-beta1.zip` — extract `addons/visual_gasic/` into your project |

**Requires Godot 4.6.1+** · Latest release

**Try Vector Crypt:** clone → open `samples/apps/vector_crypt/project.godot` → **F5**

### What's Fixed / faster (engine + IDE)

- ✅ Windows Tier 2 + Tier 3 JIT install path
- ✅ Vector canvas `BuildDepthMesh` / `AddWireTri3D` + depth cache
- ✅ M8 language parity (named args, optional chains, block lambdas, cross-module Try, FFI Alias)
- ✅ `Interface` / `Implements`
- ✅ JIT ByRef/ByVal float local slots (`test_byref_project.vg`)
- ✅ QB 32-bit draw speed · LINE quarter-pixel · PAINT / LINE color
- ✅ Debugger step-into without rebuilding the editor each F11
- ✅ Plugin param-popup typing (addon loads in editor)
- ✅ Go to Definition for imported procedures

### Known Notes

- Windows JIT benchmarks forthcoming — **please send feedback**
- Vector Crypt last level still rough
- Elite Wire Slice / classic showcase caveats unchanged from beta3
