# GitHub Release Template (v5.3.0-beta)

## Release Title
**VisualGasic v5.3.0-beta — Language Stability & Python Bridge Fix**

## Release Description

<details open>
<summary><b>🎉 VisualGasic 5.3.0-beta is here!</b></summary>

**4 critical bugs fixed. 763/763 tests passing. Python bridge int/float bug fixed.**

---

### ✨ What's New

**M1–M4 Milestones Complete (Jun 29 – Jul 1)**

- ✅ **M1:** 4 critical bugs fixed (`IsNot` operator, ByRef parameter write-back in expressions, short-circuit operators, integer preservation)
- ✅ **M2:** 44/44 corpus examples validated — all educational materials work end-to-end
- ✅ **M3:** Code Navigator upgrade — faster symbol resolution, better IDE integration
- ✅ **M4:** Experimental UI Forms plugin (opt-in, feedback welcome)

**🔧 Critical: Python Bridge Int/Float Decode Fix (Jul 15)**

- **The Bug:** Python worker returns correct integers (e.g., `math.floor(5.7)` → `5`), but Godot's `JSON::parse_string()` silently collapsed all numbers to float. Broke numpy workflows.
- **The Fix:** Custom recursive-descent JSON decoder (`vg_json_typed.h/.cpp`) that preserves int vs float semantics. Validates type on parse; correctly handles nested structures.
- **Testing:** 6/6 decode tests pass. Scalar int, negative int, float, nested dict/array — all types preserved correctly.
- **Example:**
  ```vg
  result = PyCall(math, "floor", Array(5.7))
  ' Before fix: result = 5.0 (type Double)
  ' After fix:  result = 5   (type Integer) ✅
  ```

---

### ⚠️ Known Limitations

**VG Outgoing Argument Literal Typing (v6.1 candidate)**

VG bare numeric literals in `Array()` sent as PyCall arguments arrive in Python as `float` instead of `int`.

```vg
' This fails:
result = PyCall(builtins, "range", Array(0, 5))  ' Passes 0.0, 5.0 → range() expects int → TypeError

' Workaround:
Dim args As Array
args = Array(CInt(0), CInt(5))  ' Explicitly cast to Integer
result = PyCall(builtins, "range", args)  ' ✅ Works
```

**Root Cause:** VG's literal tokenizer defaults to `Double`. **Planned Fix:** Literal type annotation syntax (`0i` for int) or change default to `Integer` for literals without decimal point.

See `/memories/repo/v6.0_blockers.md` section 6 for full analysis.

---

### 📦 Downloads

| Platform | Binary | Installer |
|---|---|---|
| **Linux x86_64** | [libvisualgasic.linux.editor.x86_64.so](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.3.0-beta/libvisualgasic.linux.editor.x86_64.so) | [install.sh](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.3.0-beta/install.sh) |
| **Linux template_debug** | [libvisualgasic.linux.template_debug.x86_64.so](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.3.0-beta/libvisualgasic.linux.template_debug.x86_64.so) | — |
| **Windows x86_64** | [libvisualgasic.windows.editor.x86_64.dll](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.3.0-beta/libvisualgasic.windows.editor.x86_64.dll) | [install.ps1](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.3.0-beta/install.ps1) |
| **Windows template_debug** | [libvisualgasic.windows.template_debug.x86_64.dll](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.3.0-beta/libvisualgasic.windows.template_debug.x86_64.dll) | — |

**Installation:** See [RELEASE_NOTES_5.3.0.md](RELEASE_NOTES_5.3.0.md) § Installation for detailed steps.

---

### 🧪 Testing & Validation

| Test | Result | Status |
|---|---|---|
| Regression Suite | 763/763 assertions | ✅ PASS |
| Corpus Examples | 44/44 examples | ✅ PASS |
| Python Bridge Decode | 6/6 int/float tests | ✅ PASS |
| Platform Validation | Linux, Windows | ✅ PASS |

**Run Your Own Tests:**
```bash
cd /path/to/VisualGasic
./run_test_suite.sh  # Expect: === ALL TESTS PASSED === (763/763)
```

---

### 📖 Documentation

- **Release Notes:** [RELEASE_NOTES_5.3.0.md](RELEASE_NOTES_5.3.0.md) (comprehensive feature list, migration guide, known issues)
- **Release Schedule:** [RELEASE_SCHEDULE.md](RELEASE_SCHEDULE.md) (upcoming 5.4-beta Oct 15, 6.0 stable Jan 1, 2027)
- **Language Reference:** [docs/VisualGasic_Language_Reference.md](docs/VisualGasic_Language_Reference.md)
- **Roadmap:** [ROADMAP.md](ROADMAP.md) (v6.0+ features, Python bridge phases, performance improvements)

---

### 🚀 What's Next

| Release | Target | Scope |
|---|---|---|
| **5.4-beta** | Oct 15, 2026 | M5: Narcea AI pair, async queue, structured error handling |
| **6.0-rc1** | Dec 1, 2026 | M6–M8: Causal Chain, language parity (Try/Catch/Lambda), C++ FFI |
| **6.0-rc2** | Dec 15, 2026 | M9: Release readiness, Asset Library submission |
| **6.0 stable** | Jan 1, 2027 | 🎉 Production release, public announcement |

Full timeline: [RELEASE_SCHEDULE.md](RELEASE_SCHEDULE.md)

---

### 💬 Feedback & Support

- **Discord/Community:** [Join discussion](https://discord.gg/yourserver)
- **Report Bugs:** [GitHub Issues](https://github.com/xgreenrx-star/VisualGasic/issues)
- **Feature Requests:** [Discussions](https://github.com/xgreenrx-star/VisualGasic/discussions)

**For beta testing:** Try the Python bridge with your own projects. Feedback on performance, edge cases, and usability deeply appreciated.

---

### 📋 Checksums (SHA-256)

```
[Checksums will be generated during GitHub release creation]
libvisualgasic.linux.editor.x86_64.so:        [SHA256]
libvisualgasic.linux.template_debug.x86_64.so: [SHA256]
libvisualgasic.windows.editor.x86_64.dll:     [SHA256]
libvisualgasic.windows.template_debug.x86_64.dll: [SHA256]
```

---

### 🙏 Thanks

Special thanks to:
- **Beta testers** — Early feedback on M1–M4 work
- **DeepSeek** — Initial int/float decoder implementation (completed by core team)
- **Godot community** — Engine, docs, GDExtension examples

**Ready to try VisualGasic? Download above and let us know what you think! 🎮**

</details>

---

## Release Settings

- ✅ **This is a pre-release** (check "Pre-release" checkbox on GitHub)
- ✅ **Tag:** `v5.3.0-beta`
- ✅ **Target:** `main`
- ✅ **Upload Binaries:**
  - `demo/bin/libvisualgasic.linux.editor.x86_64.so`
  - `demo/bin/libvisualgasic.linux.template_debug.x86_64.so`
  - Windows binaries (if built)
- ✅ **Upload Installers:**
  - `install.sh` (Linux)
  - `install.ps1` (Windows)
- ✅ **Auto-generate Release Notes:** No (use custom description above)

---

## Post-Release Checklist

After publishing to GitHub Releases:

- [ ] Verify all binaries download correctly
- [ ] Test `install.sh` on clean Linux VM
- [ ] Test `install.ps1` on clean Windows VM
- [ ] Update README.md "Current Release" section to v5.3.0-beta
- [ ] Post Facebook message ([FACEBOOK_RELEASE_MESSAGE.md](FACEBOOK_RELEASE_MESSAGE.md))
- [ ] Post to Discord #announcements
- [ ] Update website (if applicable)
- [ ] Create GitHub discussion post "5.3.0-beta Feedback Thread"
- [ ] Announce on Twitter/X (if applicable)

