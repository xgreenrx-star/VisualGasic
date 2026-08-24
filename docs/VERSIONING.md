# VisualGasic Versioning

**Last updated:** August 23, 2026

VisualGasic uses **milestone-driven releases** with **semver-style public tags**. Internal milestone IDs (M1–M9) are **not** embedded in version strings.

See [RELEASE_SCHEDULE.md](../RELEASE_SCHEDULE.md) for dates and feature scope.

---

## Public version format

| Stage | Tag example | Meaning |
|-------|-------------|---------|
| **Beta** | `v5.4.0-beta1` | Public preview; features may move |
| **Release candidate** | `v6.0.0-rc1` | Feature-complete; bug-fix and docs only |
| **Stable** | `v6.0.0` | M1–M9 exit criteria met (target: Jan 1, 2027) |

**Rules:**

- Use **`MAJOR.MINOR.PATCH`** for the base version.
- Pre-release suffix: **`-betaN`** or **`-rcN`** (lowercase, no dot — e.g. `beta1`, not `Beta1`).
- Do **not** put milestone IDs in tags (no `5.4.0M5-beta2`). Document milestones in release notes instead.
- Installer and Asset Library zips use the same version as the Git tag.

**Legacy (5.3 line):** tags `v5.3.0-Beta3` … `v5.3.0-Beta7` use capital `Beta`. New tags from **5.4.0** onward use lowercase **`beta`**.

---

## What each number means

| Part | Role |
|------|------|
| **5.x** | Pre-stable development train (language + Godot IDE integration) |
| **6.0** | First production-stable milestone release (all M1–M9 complete) |
| **Minor bump (5.4 → 5.5)** | New beta cycle / major feature batch (see schedule) |
| **Beta counter** | Iteration within that minor line (`beta1`, `beta2`, …) |

This is **not** strict SemVer for breaking changes. The jump **5.x → 6.0** marks **milestone completion**, not a breaking-API event.

---

## Milestones vs. versions

Milestones are tracked in [ROADMAP.md](../ROADMAP.md) and mapped to releases in [RELEASE_SCHEDULE.md](../RELEASE_SCHEDULE.md).

| Version (planned) | Milestone | Focus |
|-------------------|-----------|---------|
| `5.4.0-beta1` | M4+ / pre-M5 | Context rail, literal convert, IDE sidecar |
| `5.4.0-beta2` | M5 | Narcea AI pair, Buffer type, optimizer hints |
| `5.5.0-beta1` | M6–M7 | Causal chain teaser, Python bridge hardening |
| `6.0.0-rc1` | M6–M8 | Language parity, C++ FFI, `Let` keyword |
| `6.0.0-rc2` | M9 | Release readiness, installer smoke, docs |
| `6.0.0` | M1–M9 | Stable production release |

If a milestone slips, **update the schedule and release notes** — do not rename shipped tags.

---

## GitHub release naming

**Tag:** `v5.4.0-beta1`  
**Release title:** `VisualGasic 5.4.0-beta1 — Context Rail (pre-M5)`  
**Release notes:** include a **Milestone:** line and link to `CHANGELOG.md`.

Mark betas and release candidates as **Pre-release** on GitHub. Mark **6.0.0** stable as Latest.

---

## Where to update on each release

1. `CHANGELOG.md` — user-facing changes
2. `RELEASE_NOTES_vX.Y.Z-….md` — highlights and screenshots
3. `RELEASE_SCHEDULE.md` — status column and “next release” reminder
4. `docs/guides/GET_STARTED.md` — “Current version” line
5. `README.md` — release badge / download links (when promoting Latest)

---

## v6.1 and beyond

Post-stable work uses normal minor bumps: **6.1.0**, **6.2.0**, etc. See ROADMAP “v6.1 Roadmap” for performance and language polish deferred past 6.0 stable.
