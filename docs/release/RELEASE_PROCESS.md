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

### 2026-10-08 release direction and implementation handoff

The proposed next milestone is **`v5.7.0-beta1`**, rather than another 5.6 beta:
55 commits since `v5.6.0-beta1` include runtime correctness, editor lifecycle,
cross-platform bridge/build repairs, restored samples and stronger release gates.
Position it as a hardening and feature-completion milestone, not stability
certification. This is recorded planning direction, not authorization to tag,
publish, or expand the language's feature scope.

Use **`v6.0.0-rc.1`** for the first v6 release candidate and **`v6.0.0`** for
stable. `v6.0.1` / "SR1" applies only after stable v6. Mark beta and RC releases
as GitHub prereleases; `v5.6.0-beta1` was observed to lack that flag.

#### 5.7 showcase: Crystal Caverns (October 9 direction)

The maintainer chose an original Boulder Dash-style digging game to demonstrate
sprite/cave `Data` and `Whenever`, superseding the Circuit Breaker polish proposal.
[Crystal Caverns](../../samples/showcases/crystal_caverns/README.md) now provides
the bounded first playable, since extended at the maintainer's request to three
authored caves, twelve original inline Data
sprites, six crystals, falling/pushable rocks, timer, exit, pause and restart.
No classic game's artwork or cave layout is copied.

Six watchers drive visible counters, exit unlocking, low-time warning and defeat.
The fixed-step simulation remains explicit, not a network of reactive callbacks.
The game is offline and independent of AI credentials, optional music libraries
and the experimental standalone IDE. Rolling rocks, enemies, explosions,
scrolling, campaigns, save files and audio are intentionally outside this scope.

The [regression runner](../../scripts/run_crystal_caverns_regression.sh) exercises
both execution modes in an isolated project. Behavioral checks include real held
input, pushing/falling/crushing, watcher threshold/restart behavior, a bounded
frame accumulator and two deterministic complete cave playthroughs. Graphical
mode separately checks sprite and HUD pixels. Publication still requires
interactive review and validation of the packaged candidate; a playable sample
is not release certification.

October 9 verification: Linux Godot 4.6.1 and 4.7.2 both passed default/forced-AST
headless (79 checks each) and graphical OpenGL Compatibility/Xvfb (87 checks each)
runs: eight engine/mode/render combinations, with no error/crash/leak diagnostics.
Actual input-event dispatch, held input and complete authored-cave playthroughs
are covered; physical keyboard ergonomics and manual polish remain review tasks.
CI now runs the isolated headless sample checks; remote results and shipped
platform exports must still be verified on the final candidate.
The three-cave extension includes victory-gated next-cave navigation, current-cave
restart and a fullscreen button/F11 toggle. Tests complete and replay every cave,
verify both button and key navigation, and exercise actual fullscreen/windowed
transitions. The project enables the VG editor plugin and does not depend on
which editor view is used. The replacement editor now includes `(Sprites)` and
`(Whenever)` source-navigation groups. Its 169-check sample regression verifies
all twelve sprite previews/thumbnails, all six watcher entries, navigation,
refresh preservation and removal of stale entries. The reported unexpected-NUL
errors were reproduced by moving through line 73: the literal conversion helper
constructed `String.chr(0)` on every character-constant lookup. It now compares
integer character codes without creating NUL strings. The same caret test
exposed an invalid signature-popup StyleBox property, now corrected to use its
setter. The editor regression rejects Unicode diagnostics as well as script
errors and exercises every caret column on that line. Final checks passed:
57 editor checks on Linux Godot 4.6.1 headless and 4.7.2 graphical, the existing
179-check sprite/context/literal suite, and unchanged gameplay checks in both
default and forced-AST modes (79 headless / 87 graphical).

Follow-up screenshot reproduction exposed two missing editor test surfaces:
folded source-line ranges incorrectly used a count of visible rows, skipping
visible sprite labels after folded Data blocks, and the hover popup assigned a
Control-only `mouse_filter` property to a Window. The visible range now follows
actual source lines and mouse filtering is applied to the popup's Controls.
All twelve actual thumbnail draw hits and hover textures are checked, along
with the actual `(General)` menu entries and workspace control-list refresh.
The sprite-edit gutter previously overlapped Godot's fold gutter, so a click
intended to expand a Data block could open the full Sprite Editor and hide the
floating code buffer. A separate sprite gutter now keeps these actions apart.
The sample regression dispatches real pointer motion/press/release events to
expand and collapse all twelve blocks, rejecting editor-open requests, hidden
buffers and source changes. Native Script editor diagnostics identify its
current VG highlighter as `EditorPlainTextSyntaxHighlighter`; the monochrome
minimap is distinct from the floating editor visibility defect.
Verification passed on Godot 4.6.1 headless and 4.7.2 graphical (169 editor
checks each, plus unchanged gameplay matrices). An isolated full Godot editor
launch with the actual VG plugin also expanded all twelve sprite blocks through
real gutter clicks without hiding the code window or switching to Sprite view;
a post-click screenshot confirmed that the source buffer remained visible.

Rendering comparison during development also exposed a separate primitive-path
discrepancy: the initial `DrawString`/string-color HUD was absent in default mode
but visible in forced AST; native labels with string colors subsequently rendered
black in default mode. The final sample uses native Label controls with numeric
RGB colors and separately checks actual HUD pixels, excluding the cave region.
The underlying drawing/string-color parity issue was not repaired by this sample;
retain it for focused runtime investigation rather than claiming it fixed.

The Sprite panel now explains the selected Data header (width, height,
transparent palette index, palette ID) and the left-to-right, top-to-bottom
pixel layout. **Align Data grid** explicitly space-pads the selected pixel rows,
preserves numeric values, the header and intervening comments, and supports
one-step Undo. Painting, new sprite generation and full-editor write-back use
the same spacing. All twelve showcase grids are aligned without changing pixels.
Caret navigation does not automatically format source. Clicking an assist tab
preserves the user's Help/Sprite/Vector selection across later caret updates;
explicit Sprite actions remain available.

Latest targeted validation: 179 editor checks on Godot 4.6.1 headless and 4.7.2
graphical, including a real Help-tab click and grid-edit/Undo checks; 79 headless
and 87 graphical gameplay checks in each default/forced-AST mode. The seven-stage
sprite/vector/context/literal suite passes 208 checks, including 66 sprite tests
for exact spacing, value roundtrips, comment preservation and idempotence.

The October 9 screenshot follow-up fixed inherited white Sprite-help text on
cream, supplied matching themes to all floating workspace panels, corrected
light-toolbar disabled/hover-pressed states and OptionButton dropdown styling,
and made both native and embedded stale-buffer warning labels/icons readable.
New Sprite/Vector dialog hints now inherit the native dialog text theme instead
of forcing dark text onto Godot's dark dialog background.

Stale-buffer polling no longer creates automatic refresh dialogs. This avoids
interrupting typing and no longer misclassifies the floating code editor using
the legacy `_showing_code_view` flag. Nonmodal warnings and explicit Refresh
remain in both editors; no automatic peer overwrite occurs. Dismissal survives
same-side keystrokes and rearms after equality or an authority switch.

`scripts/run_editor_workspace_regression.sh` adds 118 actual-editor checks on
Godot 4.6.1 and 4.7.2, including real key input, retained focus, explicit
bidirectional refresh, dismissal and a minimum 4.5:1 contrast ratio for tested
panel text and toolbar states. The showcase editor regression prepares its
foldable fixture indentation only in memory, tolerating subsequent user source
formatting without rewriting the showcase file.

The later October 9 Sprite-actions report was reproduced in the actual editor:
the New Sprite dialog grew to 1,272 pixels tall during initial autowrap layout,
and full Sprite Editor launch hid code while its legacy mount remained hidden.
The dialog now establishes its wrapping width before display and opens at
420x320 (also applied to the equivalent New Vector layout). The full Sprite
Editor is reparented into a visible floating panel outside the legacy shell,
preserves the code view, and supports Save Data, back/close and repeated opening.
Its dark chrome remains separate from cream workspace chrome, and the pixel
canvas explicitly uses nearest-neighbor filtering.

Indent migration now compares row depth with label depth rather than accepting
any leading whitespace. Equal-depth indented labels/rows become foldable without
changing labels or numeric values; the repair is idempotent and one-step undoable.
**Indent Data** repairs and collapses blocks; a separate **Collapse Data / Expand
Data** control toggles view state without accumulating indentation. Default
auto-folding remains subject to the existing fold-policy setting and caret guard.
Tests preserve the maintainer's subsequently reformatted showcase source.

The workspace probe checks creation/validation, a bounded dialog height, painted
pixel save, back/close/reopen and fold toggles in addition to the earlier contrast
and typing coverage. Its cold-run budget is 300 seconds: several 90-second runs
timed out during startup/typing, and a GDB sample located the main thread in
Fontconfig substitution. No font or documentation cache is seeded and no errors
are suppressed; failed-run evidence is retained. Final 4.6.1/4.7.2 runs pass all
118 checks.

#### Crystal Caverns shader presentation

The showcase now includes seven original Compatibility canvas shaders: a miner
swirl entrance, cave-completion wave followed by swirl sink, DATA-colored death
fragments, unlocked-exit vortex, subtle CRT/miner pulse, rock wobble, and crystal
shimmer/pickup ring with a short event-driven glitch. No linked GodotShaders
implementation is copied. F8 or the Effects switch selects plain DATA-art
rendering. Effects are clipped to the cave, freeze on pause, reset on each cave
restart and never change gameplay rules, timer, collision or Whenever callbacks.
The presentation child is `VisualEffects.vg`; gameplay, DATA decoding and all
game-specific CPU scripting are VG. It loads Godot shader resources, creates
ShaderMaterials and updates their uniforms using `Shader.Param`. The GPU code
remains standard `.gdshader` resources; the sample's GDScript files are tests only.
Completion animations do not delay the existing next-cave/restart controls.

The isolated showcase runner now includes an effects regression: 277 headless
checks or 302 graphical checks per default/forced-AST run. Linux Godot 4.6.1 and
4.7.2 pass both execution modes in headless and OpenGL Compatibility rendering,
alongside the existing 179 editor and 79/87 gameplay checks. GPU evidence covers
entrance, pickup, rotating portal, death-pixel motion, wave/sink, plain DATA
colors, undistorted HUD, resized windows and fullscreen. The actual editor
workspace probe passes 118 checks on both engines with the new dependencies.
Tests also assert both attached scripts are VG and verify real F8 input reaches
the VG effects controller. All 24 deterministic 4.6.1 capture files (twelve per
execution mode) match the previous GDScript controller byte-for-byte.
During migration, a handwritten conditional clamp
helper returned 1 for input 0.5 in default execution versus 0.5 in forced AST.
The controller reuses the existing `Clamp` builtin instead of duplicating it;
this does not fix or certify that independent compiler discrepancy. The first
isolated VG-effects project and numeric probe output are retained in session
evidence (`files/crystal-vg-effects-first/`) for a separate native investigation.
An additional AST discrepancy converted a Vector2 divided by 4.0 into scalar
zero, suppressing explosion velocities. Scaling by 0.25 with vector
multiplication preserves the intended shader output in both modes. This sample
change does not fix the runtime division behavior. Evidence is retained under
`files/crystal-vg-final-headless461/burst-*-before.log` alongside its isolated
source. The strengthened regression verifies the type and radial values of all
64 velocities, plus actual pixel motion near the miner instead of a whole-cave
difference that could pass on unrelated crystal shimmer.
An asynchronous window-manager mode change exposed an existing single-frame
fullscreen-test race; the test now waits for the requested windowed mode with
a two-second deadline rather than sleeping or skipping the assertion.
These shader checks do not certify Windows/macOS, other rendering backends,
low-end GPU performance, exports or resolution of the independent native bugs.

#### Crystal Caverns sound and instructional source

The game now synthesizes ten original sound effects entirely in
`SoundEffects.vg`, using DATA recipes and `VGMemoryBuffer` to create cached
16-bit mono AudioStreamWAV resources. Cues cover entrance, steps, digging,
pushing, rock landing, pickups, unlock, victory, defeat and the low-time warning.
No external audio assets or optional audio plugin are required. Four bounded
AudioStreamPlayers use -12 dB volume. F9/the Sound switch mutes independently of
F8/visual effects; pause freezes ongoing playback, and restart stops old cues.
Godot's VG `Form_Unload` callback stops players and detaches streams on exit.

Beginner-oriented source comments explain each gameplay procedure, grid/DATA
indexing, watcher callbacks, fixed-step gravity, input, sprite roles, shader
coordinates/uniforms, PCM synthesis, voice reuse and shutdown. The showcase
README supplies a reading order and explains editable sound recipes.

Linux 4.6.1 and 4.7.2 pass default/forced-AST headless and graphical matrices:
95 sound checks, 80/88 gameplay checks, 278/303 effects checks, and 179 editor
checks. Both actual-editor workspace probes pass 118 checks. Sound tests verify
actual non-silent AudioServer mixer output using the Dummy driver, exact DATA
durations, signed PCM format, bounded levels, fades and sample-level
frequency/noise/envelope calculations (within one PCM unit), action/watcher
events, independent mute, pause/resume, bounded voices and resource retirement.
All ten 4.6.1 default/AST WAV evidence files match byte-for-byte.
Speaker output and subjective listening balance remain manual playtest items.

An initial `MemoryBlock.EncodeS16` packed-array attempt produced silent,
all-zero PCM in default execution and a "Method call base is not an Object"
error in forced AST execution. The sample instead uses the existing native
`VGMemoryBuffer.PokeInt16`/`ToByteArray` API, verified by the waveform assertions.
The packed-array method-dispatch discrepancy remains a separate runtime
investigation; this sample does not claim to fix it.

The gameplay held-input probe now waits for an observed tick and player move
with a two-second deadline instead of relying on a 0.3-second timer that could
fire before process notifications under parallel graphical load. Audio cleanup
tests similarly observe weak-reference retirement with a bounded deadline,
because stopped playback retires on the mixer thread. No diagnostics are
suppressed. Sample lifecycle code uses the supported VG unload callback, not
an assumed GDScript `_ExitTree` callback.

#### 6.0 showcase: Circuit Breaker: Signal Lab

The earlier, unapproved flagship proposal would evolve Circuit Breaker, pairing a complete
playable experience with a short "build, inspect, play" development walkthrough:

| Part | Intended demonstration |
| --- | --- |
| Play | Several authored boards and a bounded progression with polished gameplay |
| Inspect | Readable VG gameplay code in Godot, procedure navigation and state inspection |
| Change | A small hazard, pickup or board-rule edit using a verified supported reload workflow |
| Explain | Existing causal-chain tooling on a relationship it actually supports |
| Optional AI | A recorded Narcea-assisted change that is reviewed and tested |

The October 9 Crystal Caverns choice applies to the bounded 5.7 showcase, not
automatic approval of a larger 6.0 game. Revisit the 6.0 flagship after reviewing
the playable sample; do not build both larger games on speculation.
These are targets, not claims of implemented or validated capabilities. The game
must run independently of the development tools. Narcea is optional, never a
launch or completion dependency. Do not make the experimental standalone IDE,
legacy Form Designer or experimental UI Forms part of stable support promises.
Deliver the complete showcase with RC1; between RC1 and stable, allow defect
fixes and presentation polish, not major showcase systems.

#### Next steps for Cursor or another maintainer

1. Continue the two distinct native investigations before declaring release
   readiness: the independently reproduced Godot documentation-worker teardown
   crash, and the unresolved intermittent cold font-import corruption.
   Preserve failing tests; do not seed documentation caches, add arbitrary sleeps,
   exclude fonts or suppress diagnostics to obtain a passing gate.
2. Review the latest evidence. Commit `204cb5c8` passed
   [CI run 37858498510](https://github.com/xgreenrx-star/VisualGasic/actions/runs/37858498510),
   including Linux hardening and both Windows jobs. The failure-only GDB step was
   skipped because hardening passed. This does not erase the earlier import
   crash on `31e59b84`. macOS and Web passed on that earlier commit, not yet on
   the same final candidate.
3. Review and playtest Crystal Caverns, validate the Data/Whenever editing
   walkthrough, and address sample defects without expanding its first-playable
   scope or the experimental IDE. Choose the 6.0 flagship separately.
4. Build every shipped platform/target binary from the same candidate source.
   The October 8 native fixes were tested with locally rebuilt Linux binaries,
   but those build outputs were not republished as tracked release binaries.
   Source commits alone do not make the existing downloads current.
5. Run required workflows against that exact candidate, then validate actual
   release archives/installers: clean installation, upgrade, editor/game startup
   and supported exports. Record optional dependencies and untested platforms.
6. Update version metadata, changelog and release notes for `v5.7.0-beta1`;
   disclose unresolved affected scope explicitly. Do not tag or publish until
   the maintainer approves the candidate and its artifact validation.

Native investigation logs, independent no-VG reproductions, CI artifacts and
local controls are retained outside Git in the current Copilot session's
`files/release-doc-teardown-20261008/`, `files/ci-37855421142-evidence/`,
`files/ci-font-import-local-20261008-2/` and
`files/ci-import-gdb-validation-20261008/` directories under
`/home/Commodore/.copilot/session-state/cf88c33e-98ba-4080-a9de-a8fd9e85de16/`.
The persistent reproducer, diagnostic runners and compatibility report are in
the repository; do not make release tooling depend on session-only artifacts.
