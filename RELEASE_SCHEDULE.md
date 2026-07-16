# VisualGasic Release Schedule

**Last Updated:** July 15, 2026  
**Target:** Stable v6.0 on January 1, 2027

---

## Release Timeline

| Release | Status | ETA | Milestones | Key Features |
|---|---|---|---|---|
| **5.3-beta** | 🔴 PENDING | **Jul 15, 2026** | M1–M4 | Language stability, Python bridge int/float decode fix, Godot IDE integration (Code Navigator M3, UI Forms M4) |
| **5.4-beta** | — | Oct 15, 2026 | M5 | Narcea AI pair, async queue, structured error handling |
| **6.0-rc1** | — | Dec 1, 2026 | M6–M8 | Language parity (Try/Catch/Lambda/AndAlso/OrElse), C++ FFI interop, `Let` keyword, Causal Chain (text mode) |
| **6.0-rc2** | — | Dec 15, 2026 | M9 | Release readiness, Godot Asset Library submission, installer validation |
| **🎉 6.0 stable** | — | Jan 1, 2027 | All M1–M9 | Production release, public announcement |

---

## 5.3-beta (Due Now: Jul 15, 2026)

**Status:** Ready to ship

**Milestones included:**
- ✅ M1 — Bug fixes (4/4 critical bugs fixed)
- ✅ M2 — Corpus validation (44/44 examples passing)
- ✅ M3 — Code Navigator upgrade
- ✅ M4 — UI Forms experimental plugin

**Python bridge improvements:**
- ✅ Integer/float decode bug FIXED (Godot JSON parser → custom `vg_json_parse_typed()`)
- 🔴 Known issue: Outgoing literal typing (VG Array(0,5) sends float → breaks numpy.range). Documented in ROADMAP.md, v6.1 candidate.

**Testing:**
- Run `run_test_suite.sh` before shipping
- `demo/test_python_int_float.vg` validates decode path (Tests 1,4,5,6 pass)
- No regressions from M1 critical fixes

**Checklist before shipping:**
- [ ] Run full regression test suite (763/763 assertions target)
- [ ] Build both editor + template_debug binaries
- [ ] Verify installer (`install.sh`/`install.ps1`) on clean VM
- [ ] Generate CHANGELOG.md entry summarizing M1–M4
- [ ] Tag release as `v5.3.0-beta`
- [ ] Push to GitHub Releases with installer artifacts
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

**Next Release Alert:** 5.3-beta (DUE NOW, Jul 15)  
**Next Major Checkpoint:** 5.4-beta (Oct 15, 2026 — 3 months)

See `/memories/repo/release_schedule.md` for in-code reminders and past release notes.
