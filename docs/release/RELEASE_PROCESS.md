# Release Process & Versioning

VisualGasic follows [Semantic Versioning 2.0.0](https://semver.org/) with a
pre-release suffix for any build that isn't yet considered stable.

## TL;DR — pick a tag

| Situation                                           | Tag                  |
| --------------------------------------------------- | -------------------- |
| First public preview of a coming release            | `vX.Y.Z-beta.1`      |
| Subsequent previews, fixing bugs in the preview     | `vX.Y.Z-beta.2`, …   |
| Feature-frozen, fixing only release blockers        | `vX.Y.Z-rc.1`, …     |
| Public stable release                               | `vX.Y.Z`             |
| Bugfix on the latest stable                         | `vX.Y.Z+1`           |
| New backward-compatible features                    | `vX.Y+1.0`           |
| Breaking change to public API / save format / CLI   | `vX+1.0.0`           |

> **Examples:** `v5.1.0-beta.1` → `v5.1.0-beta.2` → `v5.1.0-rc.1` → `v5.1.0`
> → (bugfix) `v5.1.1` → (next feature batch) `v5.2.0-beta.1` → `v5.2.0`

## The numbers

`MAJOR.MINOR.PATCH`

- **MAJOR** — incompatible API or behavioural changes the user will notice
  (e.g. `.vg` save format break, plugin entry point rename, removal of a
  CLI flag). Bumping MAJOR resets MINOR and PATCH to `0`.
- **MINOR** — new backward-compatible functionality, or a substantial
  internal refactor with no user-visible regression. Resets PATCH to `0`.
- **PATCH** — bug fixes only. No new features, no API additions, no
  behavioural changes outside the fix.

> **Common misconception:** the patch digit is **not** "the beta number".
> A beta of `5.1.0` is `v5.1.0-beta.1`, not `v5.1.0` where the trailing
> `0` somehow signals beta. Pre-release information always lives in the
> suffix after the dash.

## Pre-release suffixes

For any build that isn't yet considered stable, append one of:

- `-alpha.N` — early, expect breakage. Rare in this project; we usually
  start at `-beta`.
- `-beta.N` — feature work is mostly done, looking for early-adopter
  feedback. Multiple betas are normal.
- `-rc.N` — release candidate; feature-frozen, fixing only release
  blockers. The next tag after a green RC is the bare `vX.Y.Z`.

`N` starts at `1` and is dot-separated so SemVer-aware tooling sorts
correctly: `beta.10` > `beta.2` works only with the dot, not as `beta10`
vs `beta2`. **Always use the dotted form** (`-beta.1`, not `-Beta1` or
`-beta1`).

A pre-release version is treated as *less than* the bare release, so
`v5.1.0-beta.1` < `v5.1.0-rc.1` < `v5.1.0` — exactly what we want.

## What gets a pre-release?

Anything that:

- introduces a new MINOR or MAJOR feature set,
- changes the editor or runtime ABI,
- changes the `.vg` file format,
- ships a new GDExtension build.

A pure bugfix on a stable line goes straight to the next PATCH (e.g.
`v5.1.1` after `v5.1.0`); we don't typically beta those unless the fix
is risky.

## Tagging & creating the GitHub release

1. Update `VERSION` to the bare version *without* the leading `v`:
   ```
   5.1.0-beta.1
   ```
2. Update `CHANGELOG.md` with the new entry.
3. Commit:
   ```
   git commit -am "release: v5.1.0-beta.1"
   ```
4. Tag and push:
   ```
   git tag -a v5.1.0-beta.1 -m "v5.1.0-beta.1"
   git push origin main --tags
   ```
5. Build the artifacts:
   ```bash
   bash scripts/build_appimage.sh 5.1.0-beta.1
   bash scripts/build_windows_installer.sh 5.1.0-beta.1
   bash scripts/build_offline_bundle.sh 5.1.0-beta.1
   ```
6. Create the GitHub release. Pre-releases must be marked as such:
   ```bash
   gh release create v5.1.0-beta.1 \
     release/v5.1.0-beta.1/VisualGasic-Installer-v5.1.0-beta.1-x86_64.AppImage \
     release/v5.1.0-beta.1/VisualGasic-Installer-v5.1.0-beta.1-x86_64.exe \
     release/v5.1.0-beta.1/VisualGasic-Installer-Offline-v5.1.0-beta.1-linux-x86_64.zip \
     release/v5.1.0-beta.1/VisualGasic-Installer-Offline-v5.1.0-beta.1-windows-x86_64.zip \
     --title "VisualGasic v5.1.0 Beta 1" \
     --notes-file RELEASE_NOTES_v5.1.0-beta.1.md \
     --prerelease
   ```

   For a stable release, drop `--prerelease` and tag without a suffix.

## Updating an existing release

If you need to re-upload artifacts after a fix:

```bash
gh release upload vX.Y.Z-beta.N <files…> --clobber
```

If you only need to refresh the body (e.g. embed screenshots that landed
on `main` after the tag was created), edit it from a sed-substituted
copy so relative paths in the file resolve to absolute `raw.githubusercontent.com`
URLs:

```bash
sed 's|docs/screenshots/|https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/docs/screenshots/|g' \
    RELEASE_NOTES_vX.Y.Z-beta.N.md > /tmp/release_body.md
gh release edit vX.Y.Z-beta.N --notes-file /tmp/release_body.md
```

## Archiving / removing old releases

Old releases that pre-date this policy (e.g. `v4.4.0-rc1`…`v4.4.0-rc6`,
`v3.5.0-beta2`, `v2.3.0`) have had their **binaries removed** but the
release pages remain so existing changelog links keep working. Each
archived page carries the standard archived-binaries notice at the top.

If you want to do this for a future release:

```bash
# Remove every asset from a tag…
for asset in $(gh release view vX.Y.Z --json assets --jq '.assets[].name'); do
    gh release delete-asset vX.Y.Z "$asset" -y
done
# …then prepend the archived notice to the body.
```

Do **not** delete the GitHub release itself unless you also delete the
git tag — orphaned tags on `main` confuse `git describe`.

## v6 release gates

Feature-freeze release candidates. Accept correctness fixes, regression tests,
packaging fixes and documentation corrections; defer unrelated new capabilities.
If "SR1" denotes the first bugfix service release after v6.0.0, use the SemVer
tag `v6.0.1` and "SR1" as a display label. Do not change that release's public
API or project format outside a documented compatibility-preserving fix.

A release is blocked by a reproducible VG-owned crash, data loss, or incorrect
execution of a supported feature. Known engine-side diagnostics require a
minimal independent reproduction and a documented affected scope; do not
suppress diagnostics or relabel unresolved crashes as engine bugs.

### Automated gates

Run all required workflows against the **same candidate commit**. A passing
older commit, build-only job, or skipped platform test is not sign-off.

| Gate | Required evidence |
| --- | --- |
| Runtime regression | Existing VG suite, builtin and smoke checks pass; platform-specific exclusions remain explicit. |
| Execution parity | Full AST/default differential suite has no divergence, failing assertions, incomplete execution or unexplained assertion-free fixture. Default execution can fall back to AST; this does not prove every fixture compiles or executes in JIT. |
| Instructional corpus | Every corpus example completes and matches expected output in both modes; zero skips. |
| Malformed source | Deterministic mutations finish without crashes, timeouts or incomplete host execution; parser/runtime rejection is allowed. Retain seed, original source, operation, generated source and logs. |
| Editor ownership | Component and complete-plugin lifecycle checks pass, including enabled-at-quit shutdown, without leak/error diagnostics. |
| Cold import/reload | Fresh tracked-input Brotato snapshots finish imports, exercise reload and load deferred themes in game startup. Retained editor diagnostics are not clean-shutdown certification. |
| Platform build/bridge | Required Linux, Windows and macOS build jobs and native FFI/Python smoke checks pass. Web build/export smoke passes if Web is advertised. |
| Packaging/reference/performance | Existing Asset Library, reference and benchmark gates pass; intentional bytecode-baseline changes are reviewed, not blindly refreshed. |

The Linux CI job builds both editor and template_debug libraries from the
candidate source, then runs the existing suite and
[`run_release_hardening.sh`](../../scripts/run_release_hardening.sh) sequentially.
The hardening runner combines mutation-harness acceptance tests, headless
unhandled-error reporting, full differential, two corpus, two 40-case
mutation (seed 42), component/full-plugin headless lifecycle and cold-import
checks. It retains per-gate logs, generated mutants, results and provenance:
commit, dirty-worktree status, engine version and engine/extension SHA-256 hashes.
CI uploads that evidence even on failure.

Reproduce locally after building/preparing both Linux editor and debug libraries:

```sh
GODOT=/absolute/path/to/Godot bash run_test_suite.sh --vg-only
GODOT=/absolute/path/to/Godot bash scripts/run_release_hardening.sh
```

`OUT_DIR` is optional and must be fresh. Do not run suites concurrently: some
fixtures use fixed filesystem paths and full-plugin probes use a fixed MCP port.
Use `PYTHON=/absolute/path/to/python` to select the mutation generator interpreter.
The mutation corpus currently selects the first 80 sorted corpus/suite sources;
this bounded gate is not an exhaustive fuzzer campaign. Increase count and vary
seeds using `run_parser_mutation_stress.sh count seed` for additional campaigns.
Linux 4.7.2 checks must be run separately; this runner does not certify Windows,
macOS, graphical gameplay, hardware input or JIT coverage.

Editor fixtures copy addon source into their isolated projects and reuse the
built core library. On Linux, if the optional GDSiON library is absent, the
fixture omits only its extension manifest and prints `NOT TESTED`. That is an
explicit core-only scope exclusion, not validation of music packaging.
Lifecycle fixtures finish asset import with the test plugin disabled, then
enable it for the assertions; a cold reimport must not cancel the test coroutine.
The native nine-check probe deliberately exercises reload-all. Fresh sample
imports need not print a reload-all message if no live scripts existed yet;
they must finish editor loading, register VG resources and start the games.

### Required manual sign-off

Record **pass / fail / not tested**, candidate commit, package checksums, engine
version, OS/architecture, exact procedure and evidence for each advertised target:

- Clean installation using the actual published installer or Asset Library
  package, with no source-checkout dependencies.
- Upgrade an existing project; verify script content, scenes, settings and saved
  editor state remain intact. Keep a backup and exercise rollback.
- Export a representative project in debug and release modes and launch the
  exported game outside the editor.
- Edit/run/debug repeatedly: navigation, autocomplete, indentation, breakpoints,
  stepping, locals and Immediate-window evaluation. Test invalid/incomplete code
  and plugin enable/disable without losing unsaved edits.
- Graphical lifecycle, input/focus, audio start/stop and interactive gameplay.
  Headless audio queueing and bounded sample startup do not establish these.
- Optional interop failure paths: unavailable dependencies, worker death,
  timeout/cancellation, failed files and invalid API arguments. Confirm actionable
  errors, cleanup, and recovery rather than silent success.

Keep experimental UI Forms and the legacy IDE/Form Designer explicitly opt-in;
their Alpha functionality is not a stable-release gate. Advertise only verified
platform/version combinations and document exclusions alongside the release.
Before tagging, all required rows must pass or the affected feature/platform
must be explicitly removed from the supported release scope.

The folder regression validates that `SendToTrash`'s return value agrees with
whether the file remains. If the OS rejects the operation it emits an
`UNVERIFIED` diagnostic, not a successful trash-operation claim. Positive trash
integration still requires a supported desktop environment. Timer-based Await
tests establish order with explicit completion state, not assumed expiration
ordering when two timers become due during the same engine frame.

### Current evidence and remaining work

As of 2026-10-08, commit `cf804a95` completed the main CI and macOS universal
workflows successfully, including Windows and macOS Python bridge smoke.
The earlier Web workflow passed on `1e003890`; that older result is **not**
same-commit Web sign-off for `cf804a95`.

The [compatibility report](../compatibility/GODOT_4_7_2.md) records restored
samples, behavioral probes and lifecycle investigations. Remaining work includes
the historical Brotato heap-corruption classification, audio playback shutdown
diagnostics, clean-machine package/upgrade/export tests and interactive validation.
Passing the automated hardening runner does not close those items or certify
that VG is bug-free.

### 2026-10-08 hardening checkpoint

Local source changes and rebuilt Linux editor/debug libraries passed all ten
hardening gates on both Godot 4.6.1 and 4.7.2:

| Check | Result per engine |
| --- | --- |
| Differential | 223 matched fixtures; zero divergences/failures; eight documented exclusions |
| Corpus | 80/80 in default mode and 80/80 in forced AST; zero skips |
| Mutations | 40/40 completed in each mode, seed 42; zero crashes, timeouts or incomplete hosts |
| Harness acceptance | 13 checks, including rejection of hangs, incomplete runs and reused output |
| Headless event errors | Both modes preserve error reporting and continue without a modal dialog |
| Headless lifecycle | 50 component checks and 24 full-plugin enabled-at-quit checks |
| Cold import/reload | Nine native reload checks plus both Brotato imports and themed startups |

The first campaign failed rather than hiding a package-registry timeout and a
headless runtime error that opened a desktop dialog. The package fixture now
removes registry configuration before testing offline operations. VG's automatic
unhandled-event dialog is disabled only for headless display servers; stderr
and `_OnError` dispatch remain intact. A later run exposed same-frame timer
ordering and differing OS trash availability; the affected fixtures were
corrected and passed three consecutive focused differential runs.

A subsequent tracked-source-only check, without ignored optional music
libraries, exposed the fixture's cold-reimport cancellation. After fixing fixture
setup, core/full headless lifecycle and both Brotato imports/startups passed
with the explicit GDSiON exclusion. The changed harness paths were retested
separately after the two complete ten-gate campaigns.

**Release blocker discovered by additional graphical testing:** the copied-addon
component lifecycle reports 64 successful assertions but then crashes during
editor shutdown on both engines. Godot 4.6.1 reproduced it on two repeat launches
and with the previously committed editor binary; the headless dialog fix is
therefore not required to reproduce it. Full-plugin graphical enabled-at-quit
checks passed 24/24 on both engines. Subsequent isolation reproduced the exact
crash on both engines in a GDScript-only project with no VG addon or extension.
Its filesystem traversal matches Godot's script-documentation regeneration
worker. A session-only documentation-cache control prevents the crash in both
no-VG projects and in the original 4.6.1 component fixture (64/64).
The failure is therefore independently reproducible in Godot, but remains
unfixed; no cache workaround or sleep is shipped. The strict graphical runner
still returns failure, and the release is not certified.
See the [compatibility follow-up](../compatibility/GODOT_4_7_2.md#release-hardening-graphical-shutdown-follow-up).

The same checkpoint's remote Windows, macOS and Web jobs passed, but Linux
hardening failed its tenth gate during a cold 3D Brotato font reimport, with
signal 11 and heap-corruption diagnostics. Optional GDSiON was absent. This
keeps the historical import-corruption investigation open independently of the
classified graphical documentation teardown crash. See the
[CI failure evidence](../compatibility/GODOT_4_7_2.md#release-hardening-ci-font-import-failure).
Failure-only fresh-import diagnostics run under GDB and are retained with the
hardening artifact. They never turn a failed hardening run into a passing job.
