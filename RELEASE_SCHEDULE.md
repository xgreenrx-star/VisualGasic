# VisualGasic Release Schedule

**Last Updated:** September 5, 2026  
**Target:** Stable **v6.0.0** on January 1, 2027  
**Version policy:** [docs/VERSIONING.md](docs/VERSIONING.md)

---

## Release Timeline

| Version | Status | ETA | Milestone | Key features |
|---------|--------|-----|-----------|--------------|
| **5.3.0-Beta7** | 🟢 SHIPPED | Aug 21, 2026 | M1–M4 (+ M5 progress) | Bracket indexing, CI `.vg` gate, Narcea reference offers — [notes](RELEASE_NOTES_5.3.0-Beta7.md) |
| **5.4.0-beta1** | 🟢 SHIPPED | Aug 30, 2026 | pre-M5 | **12/12 compute + 9/9 draw**, draw fusion, FunctionCall inlining, CI benchmark gate, **Beta Showcase** — [notes](RELEASE_NOTES_v5.4.0-beta1.md) |
| **5.4.0-beta2** | 🟢 SHIPPED | Sep 5, 2026 | M5 (+ M6/M7/M8 prep) | Buffer type, optimizer hints, Narcea Tier A/B, causal-chain teaser, msgpack C2, `Await`/`PyAsyncTask`, `Let`, AST Godot ctors — [notes](RELEASE_NOTES_v5.4.0-beta2.md) |
| **5.4.0-beta1 showcase** | 🟢 SHIPPED | Aug 30, 2026 | pre-M5 | `projects/vg_beta_showcase/` — full tour + Movie Maker script ([README](projects/vg_beta_showcase/README.md)) |
| **5.5.0-beta1** | — | Nov 2026 | M7–M8 | Python bridge close-out (Windows e2e, numpy Phase 2), FFI `Declare`/`DllImport`, language stress corpus |
| **6.0.0-rc1** | — | Dec 1, 2026 | M8–M9 | Try/Catch/Lambda/`?.` hardening, installer smoke, docs/corpus gate |
| **6.0.0-rc2** | — | Dec 15, 2026 | M9 | Final docs, 57+ corpus, release checklist |
| **6.0.0** | — | Jan 1, 2027 | M1–M9 | 🎉 Production stable |

**Buffer month:** October. M5 shipped on `main`; remaining prerelease work is **M7 close-out → M8 → M9**, not re-expanding M5/M6 scope.

---

## Version ↔ milestone map

Milestone IDs appear in **release notes and GitHub titles**, not in tags. Full policy: [docs/VERSIONING.md](docs/VERSIONING.md).

| Milestone | Status (Sep 2026) | Notes |
|-----------|-------------------|-------|
| M0–M4 | ✅ Done | Bugs, corpus, Code Navigator, UI Forms |
| M5 | ✅ Done | Buffer, optimizer hints, Narcea Tier A/B |
| M6 | ✅ Teaser | Text causal chain; visual panel → v6.1 |
| M7 | 🔄 Close-out | Core async/sync Python ✅; Windows e2e, Phase 2 numpy ecosystem pending |
| M8 | 🔄 Partial | `Let` ✅; FFI syntax + stress tests pending |
| M9 | 🔄 Pending | Installer smoke; Asset Library ✅ live |

---

## 5.3 line — shipped (Jul–Aug 2026)

**Latest public beta tag:** `v5.4.0-beta2` (Sep 5, 2026). **Current `main`:** v5.4.0-beta2 (M5 complete).

**Milestones included:**
- ✅ M1 — Critical bug fixes
- ✅ M2 — Corpus validation (57 examples as of Sep 2026)
- ✅ M3 — Code Navigator upgrade
- ✅ M4 — UI Forms experimental plugin
- ✅ M5 — Narcea AI pair + Buffer + optimizer hints (on `main`)
- ✅ M6 — Causal chain teaser (on `main`)
- 🔄 M7 — Python bridge close-out
- 🔄 M8 — Language parity (`Let` done; FFI pending)

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

**Python int encode:** mitigated by opt-in msgpack C2 (`vg/python/use_typed_protocol`); JSON-default users use `CInt()`. Literal `0i` syntax → v6.1.

---

## 5.4.0-beta1 — shipped (Aug 30, 2026)

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

## 5.4.0-beta2 — M5 (+ prep tracks) (Sep 5, 2026)

**Milestone:** M5 complete; M6/M7/M8 prep landed on `main` (Sep 2026)

**Shipped:**
- Buffer type (`Dim mem As Buffer`) + `OP_BUF_*` opcodes
- Optimizer hints (`@fast_loop`, `@accumulator`, `@simd_candidate`, `@pure`)
- Narcea Tier A/B golden-path validation
- Causal chain teaser (C++ API + Code Navigator)
- Python msgpack C2 + `PyCallAsync`/`Await` + demo suite
- `Let` block scope; AST Godot type constructors
- **916/916** regression assertions; **57** corpus examples

**Release criteria:**
- [x] M5 features on `main` with regression tests
- [x] No regressions from 5.4.0-beta1 baseline
- [x] README, website, docs, `.assetlib.json` updated for beta2
- [ ] Git tag `v5.4.0-beta2` + GitHub Pre-release with installer zips
- [ ] Asset Library version update submitted

---

## 5.5.0-beta1 — M7–M8 (Nov 2026)

**Milestones:**
- M7 — Python bridge **close-out** (not core path — that's done)
- M8 — `Declare`/`DllImport`, Try/Catch/Lambda/`?.`/`:=` stress corpus

**Expected features:**
- Windows e2e: `PyCallAsync` + `Await` on clean VM
- numpy/opencv (or pandas) Phase 2 demo + tests
- Worker hardening: venv detection, `PYTHONPATH`, timeout recovery
- C++ FFI syntax + packaging docs
- Optional: large-array binary lane (>100×100) or defer to v6.1

**Explicitly not in 5.5 scope:** M6 visual graph panel (v6.1), tagged stack VM (not pursued).

---

## 6.0.0-rc1 (Dec 1, 2026)

**Milestones:** M8–M9

**Expected features:**
- Try/Catch/Finally, Lambda, `?.`, AndAlso/OrElse stress corpus
- C++ FFI Windows validation + docs
- Installer smoke on clean Linux + Windows VMs

**Testing:**
- 57+ corpus examples (current baseline)
- Python bridge fuzzing (stdlib + numpy)
- C++ FFI validation (Linux + Windows)

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

# CI smoke (GDScript addon parse + load)
scripts/ci_smoke.sh projects/vg_narcea_test

# Python bridge demos
scripts/run_python_bridge_demo.sh
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full pre-release checklist.
