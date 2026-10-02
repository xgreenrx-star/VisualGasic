# VisualGasic 5.6.0-beta1 Release Notes

**Release date:** October 2, 2026  
**Status:** Public beta  
**Previous:** [5.5.0-beta3](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.5.0-beta3)  
**Requires:** Godot **4.6.1+** (Mono not required)

---

## What’s new (in plain terms)

**Headline: Windows x64 ships the native JIT for the first time.** Linux already had Tier 2 / Tier 3; Windows desktop builds now use the same hot-path compiler (`VirtualAlloc` / CFG). We want real-machine feedback — FPS, correctness, and any `VG_JIT=0` workarounds you still need. Benchmarks on Windows are **not** in CI yet; do not treat Linux numbers as Win64 proof.

Also in this beta:

1. **C++ GDExtension / engine core** — Windows JIT path, QB screen/LINE/PAINT speed + fidelity, **vector canvas depth mesh** (`AddWireTri3D`, `BuildDepthMesh` + depth cache) for SubViewport / MeshInstance3D procedural 3D, JIT+ByRef float slots, Python bridge large-array lane. **New binaries required.**
2. **Language** — `Interface` / `Implements`.
3. **Showcase — Vector Crypt** — Procedural neon 3D facility built on that depth-mesh API — [video](https://youtu.be/ntpOTNflE_M).
4. **IDE** — Faster step-into, tooltips/Data Tips, Go to Definition across imports, plugin load fix.

Full changelog: [CHANGELOG.md](CHANGELOG.md#560-beta1---2026-10-02)

### Install in a minute

1. Download **`VisualGasic_AssetLibrary_v5.6.0-beta1.zip`** from [Releases](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.6.0-beta1).
2. Unzip into your project’s `addons/visual_gasic/` (merge/replace the folder).
3. **Project → Project Settings → Plugins** → enable **VisualGasic**.

Or use the one-click **AppImage** / **Windows installer** / offline bundles on the same release page.

**Quick demos**

| Try | Open in Godot → F5 |
|-----|---------------------|
| Procedural neon 3D | `samples/apps/vector_crypt/` |
| Retro pack menu | `samples/showcases/qb_abc_showcase/` |
| Wireframe space | `samples/games/elite_wire_slice/` |

**Video:** [Vector Crypt — procedural neon 3D](https://youtu.be/ntpOTNflE_M)

---

## Windows JIT — please try this and report back

- **Default on x86-64 desktop:** hot numeric subs compile to native code after warmup.
- **Disable anytime:** `VG_JIT=0` (interpreter / fusion-only).
- **Docs:** [performance.md](docs/manual/performance.md) · fast-call path (`ByVal` + scalar `As`).
- **Ask:** On Windows, run a heavy `.vg` game or compute loop and tell us whether it feels right, crashes, or needs `VG_JIT=0`. Issues and Discussions on GitHub are fine.

Suggested one-liner for posts:

> Visual Gasic 5.6.0-beta1 ships the **Windows x64 native JIT** for the first time (same Tier 2/3 path as Linux). We need Windows feedback before we quote speed numbers.

---

## Highlights

### C++ engine / GDExtension (VG core)

This is not “sample-only” work — the shipping `.so` / `.dll` / `.wasm` changed:

| Area | What landed in `src/` |
|------|------------------------|
| **Windows JIT** | Tier 2 + Tier 3 native codegen on Win64 (`VirtualAlloc` / CFG / `install_executable_code`) |
| **Vector canvas** | `AddWireTri3D`, `BuildDepthMesh`, depth-cache slots, neon edge ribbons + fill bias for depth-tested procedural 3D (`visual_gasic_vector_canvas.*`) |
| **QB / classic** | Faster 32-bit screen path; quarter-pixel LINE; PAINT / LINE color; opaque fade washes |
| **Runtime** | JIT ByRef/ByVal float local slots; Linux Python bridge large-array lane |
| **Language** | `Interface` / `Implements` parser + same-file checks |

### Vector Crypt (showcase on top of the engine)

- **`samples/apps/vector_crypt/`** — 100% procedural neon facility (corridors, pistons/lightning, garden, waterfall, sky platforms, FPS gun). Uses `BuildDepthMesh` + `DepthView` SubViewport.
- Last rooftop/lattice area is still rough — shipped as “good enough for showcase,” not a finished game.

### Classic / QB (user-visible)

- Faster 32-bit screen path; B256 gallery stays responsive.
- LINE / PAINT fidelity fixes (same C++ QB screen work as above).

### Language & runtime (user-visible)

- `Interface … End Interface` + same-file `Implements` checks.
- JIT ByRef/ByVal float slot typing (`test_byref_project.vg`).
- Tier 3 install path on Windows.
- Linux Python bridge large-array binary lane.

### IDE

- Step-into performance; editor focus on pause.
- Shared tooltip / Data Tips chrome.
- Go to Definition for imported procedures.
- Param popup typing fix so the plugin loads reliably.

---

## Upgrade notes

- **From 5.5.0-beta3:** Replace entire `addons/visual_gasic/` — **GDExtension binaries changed** (Linux / Windows / Web). Do not mix old `.so` / `.dll` / `.wasm` with new GDScript.
- **Windows users:** first build where editor/template DLLs are expected to JIT like Linux. If something regresses, set `VG_JIT=0` and file a report.
- **Asset Library:** submit text from [ASSET_LIBRARY_CHANGELOG_5.6.0-beta1.md](ASSET_LIBRARY_CHANGELOG_5.6.0-beta1.md).

---

## Known issues

- **Vector Crypt:** final level/layout still weak; DemoVideo capture folders are local-only (not in the zip).
- **Windows JIT:** no published Win64 benchmark table in CI yet — feedback requested.
- **Elite Wire Slice / Gorillas:** same caveats as beta3 (WIP demo / GPU quirks).
