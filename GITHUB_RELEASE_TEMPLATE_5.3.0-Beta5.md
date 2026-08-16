# GitHub Release Template (v5.3.0-Beta5)

## Release Title
**VisualGasic v5.3.0-Beta5 — Native Editor Crash Fixed, VB6 Enter/Keyword Auto-Correct**

## Tag
`v5.3.0-Beta5`

## Release Body (copy everything below into the GitHub Release description)

---

🎉 **VisualGasic 5.3.0-Beta5** is an IDE stability release: the native Godot Script editor no longer crashes when you press Enter in a `.vg` tab, Enter now inserts VB6-style indentation and `Next`/block closers, and lowercase keywords auto-correct to proper casing on both native and embedded editors. All Beta4 performance wins (81.8% faster calls, native 6502 core, miscompilation fixes) carry forward.

**856/856 regression assertions · 54 corpus examples · native editor segfault fixed · keyword auto-correct on all editor surfaces**

### 🛠 Fixed: Native Script Editor Crash on `.vg` Tabs

Pressing Enter after `For i = 1 To 10` in Godot's built-in Script editor previously segfaulted (signal 11) inside the GDScript completion overlay. The overlay is disabled on native `.vg` tabs; the dedicated VG embedded editor retains full completion.

### ⌨️ VB6 Enter / Block Closing on Native Tabs

Enter on native Script tabs now matches the embedded VG editor: correct indent, auto-insert `Next` after `For`, and matching closers (`End If`, `Wend`, `End Sub`, …) for block openers.

### ✏️ Keyword Auto-Correct (`for` → `For`)

Shared `vg_keyword_autocorrect.gd` capitalizes the full VB6 keyword set on line leave — native Script tabs and embedded `VGCodeEdit` both.

### 🔜 Coming Next (M5)

| Area | Target |
|---|---|
| **Buffer Type** | Zero-overhead byte access for emulation/I/O |
| **Optimizer Hints** | `@fast_loop`, `@accumulator`, `@simd_candidate` |
| **Speed improvements** | Unboxed operand stack (3–4× call overhead target) |
| **Narcea AI Pair** | Agent-loop fixes, end-to-end demo hardening |

Full details, GDScript comparison, and complete changelog: [RELEASE_NOTES_5.3.0-Beta5.md](https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_5.3.0-Beta5.md)

📚 **Documentation:** [Docs Hub](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/DOCS.md) · [Getting Started](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/guides/GET_STARTED.md) · [Installation](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/guides/INSTALLATION.md) · [Language Reference](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/VisualGasic_Language_Reference.md) · [Built-in Functions](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/reference/BUILTIN_FUNCTIONS_REFERENCE.md)

---

### 📦 Downloads

| Platform | Package |
|---|---|
| **Linux** | `VisualGasic-Installer-v5.3.0-Beta5-x86_64.AppImage` (recommended) or `VisualGasic_v5.3.0-Beta5_linux_x86_64.zip` |
| **Windows** | `VisualGasic-Installer-v5.3.0-Beta5-x86_64.exe` (recommended) or `VisualGasic_v5.3.0-Beta5_windows_x86_64.zip` |
| **Offline** | `VisualGasic-Installer-Offline-v5.3.0-Beta5-linux-x86_64.zip` · `VisualGasic-Installer-Offline-v5.3.0-Beta5-windows-x86_64.zip` (Godot 4.6.1 bundled) |

Manual install: extract a platform zip into your project's `addons/` folder, enable in **Project → Project Settings → Plugins**.

### 🧪 Testing

```bash
./run_test_suite.sh   # === ALL TESTS PASSED === (856/856)
```

### 🚀 What's Next

| Release | Target | Scope |
|---|---|---|
| 5.4-beta | Oct 15, 2026 | M5: Buffer Type, Optimizer Hints, Narcea AI pair (full) |
| 6.0-rc1 | Dec 1, 2026 | M6–M8: Causal Chain, language parity, C++ FFI |
| 6.0 stable | Jan 1, 2027 | 🎉 Production release |

Full timeline: [RELEASE_SCHEDULE.md](https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_SCHEDULE.md)

---

## Release Settings

- ⬜ Mark as **pre-release** (leave UNCHECKED — this release becomes "Latest")
- Target branch: `main`
- Attach: Linux/Windows zips, AppImage, Windows exe, offline bundles (see build output for exact filenames)

## Post-Release Checklist

- [ ] Verify both zip downloads extract and load in a fresh Godot 4.6.1 project
- [ ] Update README.md "Current Release" badge/section to v5.3.0-Beta5
- [ ] Update Godot Asset Library listing to v5.3.0-beta5 / tag v5.3.0-Beta5
- [ ] Post Facebook release message (see FACEBOOK_RELEASE_MESSAGE.md)
- [ ] Post to Discord #announcements
- [ ] Create GitHub Discussion "5.3.0-Beta5 Feedback Thread"
