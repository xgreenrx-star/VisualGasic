# VisualGasic Release Schedule

**Last Updated:** August 25, 2026  
**Target:** Stable **v6.0.0** on January 1, 2027  
**Version policy:** [docs/VERSIONING.md](docs/VERSIONING.md)

---

## Release Timeline

| Version | Status | ETA | Milestone | Key features |
|---------|--------|-----|-----------|--------------|
| **5.3.0-Beta7** | 🟢 SHIPPED | Aug 21, 2026 | M1–M4 (+ M5 progress) | Bracket indexing, CI `.vg` gate, Narcea reference offers — [notes](RELEASE_NOTES_5.3.0-Beta7.md) |
| **5.4.0-beta1** | 🟢 SHIPPED | Aug 30, 2026 | pre-M5 | **12/12 compute + 9/9 draw**, draw fusion, FunctionCall inlining, CI benchmark gate, **Beta Showcase** — [notes](RELEASE_NOTES_v5.4.0-beta1.md) |
| **5.4.0-beta1 showcase** | 🟢 SHIPPED | Aug 30, 2026 | pre-M5 | `projects/vg_beta_showcase/` — full tour + Movie Maker script ([README](projects/vg_beta_showcase/README.md)) |
| **5.4.0-beta2** | — | Oct 15, 2026 | M5 | Narcea AI pair, Buffer type, optimizer hints |
| **5.5.0-beta1** | — | Nov 2026 | M6–M7 | Causal chain (text), Python bridge hardening |
| **6.0.0-rc1** | — | Dec 1, 2026 | M6–M8 | Try/Catch, `Let`, C++ FFI, language parity |
| **6.0.0-rc2** | — | Dec 15, 2026 | M9 | Installer smoke, docs, corpus 50+ |
| **6.0.0** | — | Jan 1, 2027 | M1–M9 | 🎉 Production stable |

**Buffer month:** October. If M5 slips, compress M6/M7 scope — not the Jan 1 stable target unless explicitly re-planned.

---

## Version ↔ milestone map

Milestone IDs appear in **release notes and GitHub titles**, not in tags. Full policy: [docs/VERSIONING.md](docs/VERSIONING.md).

---

## 5.3 line — shipped (Jul–Aug 2026)

**Latest public beta:** `v5.4.0-beta1` (Aug 30, 2026) — on the **5.x** train toward stable **`v6.0.0` (VG6)**, target Jan 1, 2027.

**Milestones included:**
- ✅ M1 — Critical bug fixes
- ✅ M2 — Corpus validation (54+ examples)
- ✅ M3 — Code Navigator upgrade
- ✅ M4 — UI Forms experimental plugin
- 🔄 M5 — Narcea AI pair (partial; continues in 5.4)

### Beta7 highlights (Aug 21, 2026)

- ✅ Bracket array indexing `arr[i]` — [RELEASE_NOTES_5.3.0-Beta7.md](RELEASE_NOTES_5.3.0-Beta7.md)
- ✅ ByRef array slot write-back
- ✅ CI `.vg` regression suite on every PR (`run_test_suite.sh --vg-only`)
- ✅ Narcea reference offers, web-assisted scaffolds, Cursor SDK fixes
- ✅ 871/871 regression assertions

### Beta6 highlights (Aug 18, 2026)

- ✅ `End`, `DoEvents`, `Throw`, `LoadForm`, `ChangeScene`
- ✅ VB6 `""` string escapes; conversion builtins
- ✅ Programmer's Reference runtime gate in CI
- ✅ 856/856 regression assertions

### Earlier 5.3 betas

| Tag | Date | Highlights |
|-----|------|------------|
| Beta5 | Aug 16 | Native Script editor crash fix, VB6 Enter/block closing, keyword auto-correct |
| Beta4 | Aug 7 | −81.8% call overhead, native 6502 core, 3 miscompilation fixes |
| Beta3 | Jul 31 | C64/GBA emulator demos, cross-module bytecode, Buffer type groundwork |
| Beta2 | Jul 15 | Python int/float decode fix, `IsNot`, ByRef write-back |
| Beta1 | Jul 3 | Narcea floating window, Thrust demo |

**Known issue (carried forward):** VG numeric literals sent to Python via `Array(0, 5)` arrive as float — [ROADMAP.md](ROADMAP.md), v6.1 candidate.

---

## 5.4.0-beta1 — shipping (Aug 30, 2026)

**Milestone:** pre-M5 (performance + IDE sidecar)

**Scope shipped:**
- **12/12 compute + 9/9 draw** — full published benchmark suite faster than GDScript
- Draw grid-loop fusion, F64 draw opcodes, batch recorder
- FunctionCall compiler inlining + nested-loop fusion
- CI benchmark regression gate (`scripts/benchmark_regression_check.sh`)
- Context rail sidecar, literal convert, sprite Data editor, Track D groundwork (`.vgd` / Tiled)

**Release criteria:**
- [x] `scripts/ci_smoke.sh` passes on `projects/vg_narcea_test`
- [x] `./run_test_suite.sh` green (891 assertions)
- [x] `CHANGELOG.md` + `RELEASE_NOTES_v5.4.0-beta1.md`
- [x] Tag `v5.4.0-beta1`; GitHub Pre-release
- [x] Update `docs/guides/GET_STARTED.md` current version
- [x] `projects/vg_beta_showcase/` committed; Movie Maker script

---

## 5.4.0-beta2 — M5 (Oct 15, 2026)

**Milestone:** M5 — Narcea AI pair

**Expected features:**
- End-to-end “describe form → working VG code” on Claude + Ollama
- Buffer type (`Dim mem As Buffer`) + BufRead/BufWrite opcodes
- Optimizer hints (`@fast_loop`, `@accumulator`, `@simd_candidate`)
- Provider polish (DeepSeek, Qwen, Codeium, Amazon Q)

**Release criteria:**
- 50+ corpus examples pass
- No regressions from 5.4.0-beta1
- Narcea integration / agent-loop tests green

---

## 5.5.0-beta1 — M6–M7 (Nov 2026)

**Milestones:**
- M6 — Causal Chain text-mode report
- M7 — Python library integration close-out (numpy Phase 1, Windows async validation)
- Track D follow-ups — image `.vgd` sections, CSV bulk export, Narcea data-file prompts

**Expected features:**
- Static AST call-chain report for forms
- `PyImport` / `PyCallAsync` / `Await` hardened on Linux + Windows
- numpy/opencv basic demos updated
- Track D follow-ups — image `.vgd` sections, CSV bulk export from sidecar

---

## 6.0.0-rc1 (Dec 1, 2026)

**Milestones:** M6–M8

**Expected features:**
- Try/Catch/Finally, Lambda, `?.`, AndAlso/OrElse corpus tests
- `Let` block-scoped variables
- C++ FFI (`Declare` / `DllImport`) documentation and packaging
- Python encode-path literal typing mitigations where feasible

**Testing:**
- 60+ corpus examples
- Python bridge fuzzing (stdlib + numpy)
- C++ FFI validation (Linux, Windows, macOS)

---

## 6.0.0-rc2 (Dec 15, 2026)

**Milestone:** M9 — Release readiness

**Final push:**
- ✅ Godot Asset Library — live ([store listing](https://store.godotengine.org/asset/visual-gasic/visual-gasic/))
- [ ] Installer smoke test on clean Linux + Windows VMs
- [ ] Language Reference and tutorials reflect v6.0 accurately
- [ ] README and CHANGELOG finalized for stable

---

## 6.0.0 stable (Jan 1, 2027)

🎉 **All M1–M9 complete.** Tag `v6.0.0` (no pre-release suffix). Public announcement.

**What stable means:** language core reliable, examples and installer work first try, docs honest. Not every v7.0 aspirational item ships in 6.0.

---

## Release Procedures

### Building and Testing

```bash
# Full regression suite
./run_test_suite.sh

# CI-style VG-only gate
./run_test_suite.sh --vg-only

# Editor smoke (after GDScript plugin changes)
scripts/ci_smoke.sh projects/vg_narcea_test

# Build editor binary
scons target=editor -j$(nproc)

# Build template_debug binary
scons -j$(nproc)
```

### Release Notes Template

```markdown
## vX.Y.Z-betaN / vX.Y.Z

**Release Date:** YYYY-MM-DD
**Milestone:** M# — short name

### Features
- Feature description

### Bug Fixes
- Bug title + commit hash

### Known Issues
- Title + workaround link

### Installation
See docs/guides/GET_STARTED.md and GitHub Releases assets.

### Compatibility
- Godot 4.6.1+
- Linux x86_64, Windows x86_64 (desktop)
- Python 3.10+ (Python bridge)
```

### GitHub Release Checklist

- [x] Tag: `git tag -a v5.4.0-beta1 -m "…"`
- [ ] Push: `git push origin main && git push origin v5.4.0-beta1`
- [ ] Upload installer + Asset Library zip
- [x] Release notes from CHANGELOG; title includes milestone name (not tag)
- [ ] Mark **Pre-release** for beta/rc; **Latest** only for 6.0.0 stable
- [x] Update GET_STARTED.md and README release section
- [x] Update ROADMAP, DOCS hub, Asset Library submission doc
- [ ] Deploy GitHub Pages (`website/temporary-placeholder-site/`)

---

## Reminder

**Current release:** `v5.4.0-beta1` (Aug 30, 2026) — full benchmark wins + Beta Showcase · road to **VG6** (`v6.0.0` stable, Jan 2027)  
**Next milestone gate:** M5 → `v5.4.0-beta2` (Oct 15, 2026)
