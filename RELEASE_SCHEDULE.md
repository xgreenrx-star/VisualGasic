# VisualGasic Release Schedule

**Last Updated:** August 16, 2026  
**Target:** Stable v6.0 on January 1, 2027

---

## Release Timeline

| Release | Status | ETA | Milestones | Key Features |
|---|---|---|---|---|
| **5.3-beta** | 🟢 SHIPPED (Beta5) | Jul 15 → **Aug 16, 2026** | M1–M4 (+ M5 progress) | Language stability, Python bridge int/float decode fix, Godot IDE integration (Code Navigator M3, UI Forms M4); Beta3 adds C64/GBA emulator demos, cross-module bytecode compilation, Buffer Type, `Global` keyword; Beta4 adds native 6502 CPU core, −81.8% call overhead, 3 miscompilation bugs fixed; Beta5 fixes native Script editor crash, VB6 Enter/block closing, keyword auto-correct |
| **5.4-beta** | — | Oct 15, 2026 | M5 | Narcea AI pair, async queue, structured error handling |
| **6.0-rc1** | — | Dec 1, 2026 | M6–M8 | Language parity (Try/Catch/Lambda/AndAlso/OrElse), C++ FFI interop, `Let` keyword, Causal Chain (text mode) |
| **6.0-rc2** | — | Dec 15, 2026 | M9 | Release readiness, Godot Asset Library submission, installer validation |
| **🎉 6.0 stable** | — | Jan 1, 2027 | All M1–M9 | Production release, public announcement |

---

## 5.3-beta (Shipped Beta1 Jul 3, Beta2 Jul 15, Beta3 Jul 31, Beta4 Aug 7, Beta5 Aug 16, 2026)

**Status:** Beta5 shipped

**Milestones included:**
- ✅ M1 — Bug fixes (4/4 critical bugs fixed)
- ✅ M2 — Corpus validation (54/54 examples passing, up from 44)
- ✅ M3 — Code Navigator upgrade
- ✅ M4 — UI Forms experimental plugin
- 🔄 M5 — Narcea AI pair (in progress; DeepSeek provider + agent scaffolding landed in Beta3, agent-loop bug fixes landed in Beta4; Buffer Type + Optimizer Hints + speed improvements targeted for 5.4-beta)

**Beta5 highlights (Aug 16, 2026):**
- ✅ Native Godot Script editor crash fixed (segfault on Enter in `.vg` tabs) — see [RELEASE_NOTES_5.3.0-Beta5.md](RELEASE_NOTES_5.3.0-Beta5.md)
- ✅ VB6 Enter / block closing on native Script tabs (`Next`, `End If`, etc.)
- ✅ Shared keyword auto-correct (`for` → `For`) on native + embedded editors
- ✅ All platform zips, AppImage, Windows installer, and offline bundles rebuilt for Beta5

**Beta4 highlights (Aug 7, 2026):**
- ✅ Call-performance campaign: −81.8% instruction overhead per call (45,785 → 8,323 instr/call), 5.50× faster — see [RELEASE_NOTES_5.3.0-Beta4.md](RELEASE_NOTES_5.3.0-Beta4.md)
- ✅ Native VGCpu6502 engine primitive — C64 Emulator Turbo Mode boots to `READY.` at ~2.9× real hardware speed
- ✅ 3 silent-miscompilation bugs fixed: `OP_JUMP_TABLE` sizing, `CONST + VAR`/`CONST * VAR` arithmetic codegen, `ByRef` write-back vs. shadowed builtin
- ✅ Native JIT hang bug fixed (missing `restore_vm()` on JIT return)
- ✅ Regression suite: 856/856 assertions (up from 777/777)

**Beta3 highlights (Jul 31, 2026):**
- ✅ C64 Emulator + GBA Emulator demos (real KERNAL/BASIC ROMs, ARM7TDMI) — see [RELEASE_NOTES_5.3.0-Beta3.md](RELEASE_NOTES_5.3.0-Beta3.md)
- ✅ Cross-module bytecode compilation for imported Subs + `MemoryBuffer` global support
- ✅ Buffer Type + Optimizer Hints (#4, #5), `Global` keyword, cross-file class `Import`, `Exit While`
- ✅ ~21–40% reduction in call/hot-path overhead
- ✅ Regression suite: 777/777 assertions (up from 763/763)

**Python bridge improvements (Beta2):**
- ✅ Integer/float decode bug FIXED (Godot JSON parser → custom `vg_json_parse_typed()`)
- 🔴 Known issue: Outgoing literal typing (VG Array(0,5) sends float → breaks numpy.range). Documented in ROADMAP.md, v6.1 candidate.

**Testing:**
- Run `run_test_suite.sh` before shipping
- `demo/test_python_int_float.vg` validates decode path (Tests 1,4,5,6 pass)
- No regressions from M1 critical fixes

**Checklist before shipping Beta4:**
- [x] Run full regression test suite (856/856 assertions)
- [x] Build both editor + template_debug binaries (+ template_release, Linux + Windows)
- [ ] Verify installer (`install.sh`/`install.ps1`) on clean VM
- [x] Generate CHANGELOG.md entry summarizing Beta4 changes
- [ ] Tag release as `v5.3.0-Beta4`
- [ ] Push to GitHub Releases with installer artifacts (mark as Latest, not pre-release)
- [ ] Update README.md "Current Release" section

---

## 5.4-beta (Estimated: Oct 15, 2026)

**Milestones:**
- M5 — Narcea AI pair

**Expected features:**
- Real-time AI code suggestions in IDE
- Async queue + structured error handling
- Prompt engineering improvements

**Release criteria:**
- 50+ corpus examples pass
- No regressions from 5.3
- Narcea integration tests green

---

## 6.0-rc1 (Estimated: Dec 1, 2026)

**Milestones:**
- M6 — Causal Chain text-mode teaser
- M7 — Python Library Integration (numpy, opencv basic support)
- M8 — Language parity (Try/Catch/Lambda, AndAlso/OrElse short-circuit, `Let` keyword, C++ FFI)

**Expected features:**
- Full Python bridge type-fidelity (int/float fixed both directions)
- Try/Catch/Finally working end-to-end
- AndAlso/OrElse short-circuit behavior
- Named arguments at call sites
- C++ library interop documentation

**Testing:**
- 60+ corpus examples
- Python bridge fuzzing (stdlib + numpy modules)
- C++ FFI cross-platform validation (Linux, Windows, macOS)

---

## 6.0-rc2 (Estimated: Dec 15, 2026)

**Milestones:**
- M9 — Release readiness

**Final push:**
- Godot Asset Library submission prepared
- Installer smoke test on clean Linux + Windows VMs
- All documentation finalized (Language Reference, API docs, tutorials)
- README and CHANGELOG reflect v6.0 accurately

---

## 6.0 Stable (Target: Jan 1, 2027)

🎉 **All M1–M9 complete. Production release.**

---

## Release Procedures

### Building and Testing

```bash
# Full test suite (should pass 763/763 assertions)
./run_test_suite.sh

# Build editor binary
scons target=editor -j$(nproc)

# Build template_debug binary
scons -j$(nproc)

# Verify binaries
file demo/bin/libvisualgasic.linux.editor.x86_64.so
file demo/bin/libvisualgasic.linux.template_debug.x86_64.so
```

### Release Notes Template

```markdown
## vX.Y.Z-beta / vX.Y.Z

**Release Date:** YYYY-MM-DD

### Features
- [M#] Feature description

### Bug Fixes
- [Critical] Bug title + commit hash

### Known Issues
- Title + workaround link

### Installation
Download `install.sh` / `install.ps1` and follow CONTRIBUTING.md § "Developer Setup".

### Compatibility
- Godot 4.6.1 (tested)
- Linux x86_64, Windows x86_64 (desktop)
- Python 3.10+ (for Python bridge)
```

### GitHub Release Checklist

- [ ] Create tag: `git tag -a v5.3.0-beta -m "..."`
- [ ] Push tag: `git push origin v5.3.0-beta`
- [ ] Upload installer binaries to GitHub Releases
- [ ] Write release notes from CHANGELOG.md
- [ ] Mark as "Pre-release" if beta/rc
- [ ] Announce on Discord / forums

---

## Reminder System

**Next Release Alert:** 5.4-beta (Oct 15, 2026)  
**Next Major Checkpoint:** 5.4-beta (Oct 15, 2026 — ~2 months)

See `/memories/repo/release_schedule.md` for in-code reminders and past release notes.
