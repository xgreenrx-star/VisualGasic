# GitHub Release Template (v5.3.0-Beta2)

## Release Title
**VisualGasic v5.3.0-Beta2 — Python Bridge Fix, IsNot Operator, ByRef Write-Back**

## Tag
`v5.3.0-Beta2`

## Release Body (copy everything below into the GitHub Release description)

---

🎉 **VisualGasic 5.3.0-Beta2** closes out Milestones M1–M4 with a critical Python bridge fix, the `IsNot` operator, a ByRef write-back bug fix, two new AI providers, and Python/FFI interop demos.

**763/763 regression assertions · 44/44 corpus examples · 6/6 new Python bridge tests · 0 known critical bugs**

### 🔧 Critical Fix: Python Bridge Int/Float Decode

Godot's `JSON::parse_string()` collapses every JSON number to `float`, silently destroying Python integers returned from `PyCall`. Fixed with a custom decoder (`vg_json_typed.h/.cpp`) that preserves int vs float type, matching Python's own `json.loads()` semantics.

```vg
result = PyCall(math, "floor", Array(5.7))
' Before: 5.0 (Double) — wrong
' After:  5   (Integer) — correct ✅
```

**Known limitation (v6.1 candidate):** outgoing PyCall arguments still send VG literals as float (`Array(0, 5)` → Python sees `0.0, 5.0`). Workaround: `Array(CInt(0), CInt(5))`.

### ✨ IsNot Operator

```vg
If obj IsNot Nothing Then
    obj.DoSomething()
End If
```

### 🐛 ByRef Write-Back Fix

Fixed a bug where `result = DoubleAndReturn(val)` (expression-level ByRef call) never wrote back to `val`, while the equivalent `Call` statement worked correctly. 763/763 now pass (was 762/763).

### 🤖 New AI Providers

Codeium (Windsurf) and Amazon Q Developer added to the Narcea AI Pair / AI Help panel.

### 🐍 New Demos

- Python bridge round-trip demo (`demos/Utilities/PythonBridge/`)
- C++ FFI custom library demo (`demos/Utilities/FFI/`) — Vec2 math class via C ABI, 7/7 sections pass

### 🎮 New Thrust Tribute Demo

A VG tribute to the 1986 classic *Thrust* — procedural `_Draw` rendering, tether physics, 3-level progression, BBC Micro–style visuals.

### 📚 GDScript Differences

New/updated docs for developers coming from GDScript:
- [GDScript ↔ VisualGasic Quick Reference](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/GODOT_PROGRAMMING_MANUAL.md#gdscript-vs-vg)
- [19 Advantages Over GDScript](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/guides/VG_ADVANTAGES_OVER_GDSCRIPT.md)

Full details, GDScript comparison, and complete changelog: [RELEASE_NOTES_5.3.0-Beta2.md](https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_5.3.0-Beta2.md)

---

### 📦 Downloads

| Platform | Package |
|---|---|
| **Windows** | `VisualGasic_v5.3.0-Beta2_windows_x86_64.zip` (or the `.exe` installer) |
| **Linux** | `VisualGasic_v5.3.0-Beta2_linux_x86_64.zip` |

Manual install: extract into your project's `addons/` folder, enable in **Project → Project Settings → Plugins**.

### 🧪 Testing

```bash
./run_test_suite.sh   # === ALL TESTS PASSED === (763/763)
```

### 🚀 What's Next

| Release | Target | Scope |
|---|---|---|
| 5.4-beta | Oct 15, 2026 | M5: Narcea AI pair (full), async queue |
| 6.0-rc1 | Dec 1, 2026 | M6–M8: Causal Chain, language parity, C++ FFI |
| 6.0 stable | Jan 1, 2027 | 🎉 Production release |

Full timeline: [RELEASE_SCHEDULE.md](https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_SCHEDULE.md)

---

## Release Settings

- ☑️ Mark as **pre-release**
- Target branch: `main`
- Attach: Windows zip/installer, Linux zip (see build output for exact filenames)

## Post-Release Checklist

- [ ] Verify both zip downloads extract and load in a fresh Godot 4.6.1 project
- [ ] Update README.md "Current Release" badge/section to v5.3.0-Beta2
- [ ] Update website "Latest Release" section/download links
- [ ] Post Facebook release message (see FACEBOOK_RELEASE_MESSAGE.md)
- [ ] Post to Discord #announcements
- [ ] Create GitHub Discussion "5.3.0-Beta2 Feedback Thread"
