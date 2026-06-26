# Examples & Demos Cleanup Manifest — Jun 22 2026

**Scope**: Audit all examples, demos, tutorials, game projects, and learning corpus. Keep only proven/current. Delete everything unproven/untested/out-of-date.

**Decision**: After VG Core is split (July 1), examples move to the VG Core repo as a fresh, verified set. Current examples are archived and cleaned before inclusion.

---

## By Directory

### `corpus/` (Learning corpus)
**Status**: KEEP — org/verified on May 1 2026
- 10 directories: `01_basics` through `10_godot_integration`
- Structured, documented, recent dates
- **Verdict**: KEEP all. This is the learning foundation. Verify one sample compiles on day 1.

### `tutorials/` (Tutorial examples)
**Status**: KEEP — recent, dated May 11 2026
- 12 `.vg` tutorial files covering Godot features (animation, physics, crypto, etc.)
- All recent dates (May 2026)
- Each has a README explaining purpose
- **Verdict**: KEEP all. Spot-check 2-3 that they compile before move to VG Core repo.

### `demos/` (Feature demonstrations)
**Status**: AUDIT NEEDED — 104 VG files + 3031 directories = massive bloat
- Contains: `working_nodes/`, `Mobile/`, `Threading/`, subdirectories by feature
- Many files appear to be untracked/unversioned experiments
- **Verdict**: 
  - KEEP: `demos/working_nodes/` (actively maintained, has README)
  - KEEP: `demos/Mobile/` (Sensor/GPS demos, recent, tested)
  - KEEP: `demos/Threading/` if it has a `.vg` file
  - DELETE: Everything else (unvetted)
  - **Action**: Day 1: manually review `demos/` directories, keep only above 3, delete rest

### `examples/` (Nested project structure)
**Status**: UNKNOWN — mixed content, various dates
- Contains: Jupyter notebooks, test scenes, custom widgets, asset libraries
- Subdirectories: `addons/`, `assetlibs/`, `bin/`, `custom_widgets/`, `docs/`, `dodge/`, `examples/`
- **Verdict**:
  - Requires manual spot-check (is this documentation or runnable example?)
  - DELETE unless proven to compile/run
  - **Action**: Day 1: audit `examples/examples/` subdirectory structure manually

### `game_projects/` (Full game templates)
**Status**: MIXED — some active, some stale
- KEEP: `AGCK_Tests/` (active, tested, in use)
- KEEP: `vgai_demo/` (recent, May 29 2026)
- KEEP: `demoscene_intro/` (recent, active)
- KEEP: `vector_dashboard/` and `vector_storm/` (recent vector graphics demos)
- DELETE: `asteroids/`, `defender/`, `platformer_2d/`, `racing_3d/`, `zork/` (old, may be out of date)
- **Verdict**: Keep 5 active projects, delete 5 stale. 50% reduction.

### `ai_projects/` (AI project sandbox)
**Status**: MINIMAL — only `Smoke/` subdirectory
- Single project, small scope
- **Verdict**: KEEP if documented. DELETE if undocumented.

### `demo/` (nested under workspace root)
**Status**: APPEARS DUPLICATE — mixed docs, tests, examples
- Overlaps with both `demos/` and `examples/`
- May be legacy
- **Verdict**: AUDIT on day 1 — merge unique content into `demos/`, delete rest

---

## Action Items

| Directory | Decision | Day 1 Action |
|---|---|---|
| `corpus/` | KEEP | Spot-check 1 file compiles |
| `tutorials/` | KEEP | Spot-check 2 files compile |
| `demos/` | AUDIT | Keep working_nodes/, Mobile/, Threading/; delete others |
| `examples/` | DELETE MOST | Audit `examples/examples/` subdirectory, delete unproven |
| `game_projects/` | KEEP 5/10 | Keep AGCK_Tests, vgai_demo, demoscene_intro, vector_*, delete 5 old ones |
| `ai_projects/` | AUDIT | Keep only if documented |
| `demo/` | AUDIT | Merge unique content, delete duplicate |

---

## Expected Outcome

- Current examples: ~200 files (conservative estimate)
- Post-cleanup: ~80 files (60% reduction)
- Post-rebuild for VG Core: ~50 fresh, proven-working examples (clean slate)

**Execution**: Do NOT delete during planning phase. On July 1, run the day-1 audit, verify compiles, then copy only KEEP items into VG Core repo. Delete originals after move is confirmed.

