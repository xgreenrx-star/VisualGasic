# Godot 4.7.2 compatibility audit

## Local review quarantine

After this audit, the 14 failing corpus fixtures and 15 projects in the
confirmed-failure table were initially moved locally to
`scratch/failing_examples_godot_4_7_2_2026-10-06/`, preserving their original
`corpus/` and `samples/` paths and available sidecars. The associated legacy
project aliases were parked there too; canonical addon links were adjusted.
Scratch is Git-ignored: this is a local review archive, not a published move.
The two Brotato projects and shutdown-only cases remain in the active tree.

The 14 corpus fixtures and their UID sidecars have since been restored and all
58 examples reviewed, followed by 22 additional lessons. All 15 sample projects
and five legacy aliases have now been restored. The follow-up
section below describes the revised corpus; subsequent original-audit sections
retain the historical counts, paths and evidence.

## Follow-up corpus review

All **80 corpus examples pass, with zero failures and zero skips**, on Linux
in both default and forced-AST execution modes on **Godot 4.7.2 and 4.6.1**.
See the [corpus guide](../../corpus/README.md) for the four-run matrix,
review conventions and exact validation commands.

After rebuilding Linux editor and template_debug extensions, the complete
4.7.2 AST/bytecode differential rerun passed **215 matched fixtures**, with
zero failures/divergences and eight explicit exclusions. The audit harness's
16 acceptance/rejection checks also passed. An earlier concurrent run hit one
overlapping-Await order assertion; an isolated retry and the full isolated
rerun passed. No Await source or expectation was changed for this review.

The examples now use supported declarations, exception handling, VG event and
property conventions, and explicit input validation. Fixed scenario data uses
`Data` where appropriate; arrays and `If` remain where indexing, mutation,
guards or the lesson itself make them clearer.

This review also required native correctness fixes, not an ABI migration:

- Date-literal scanning no longer pairs file-number `#` markers across lines
  and swallows intervening file-processing statements.
- A VM error propagated to a caller's `Catch` no longer prematurely prints an
  unhandled-exception diagnostic. Genuinely unhandled errors remain reported.
- Builtin arguments and extracted statement expressions use the full AST
  evaluator, preserving floating `/` and VG property-alias semantics.
- AST array `Count` / `Length` properties return sizes instead of Godot
  method Callables or null.
- Local array indexing takes precedence over same-named builtins such as
  `Keys()` / `Values()`, including case-insensitive references.
- `Put` is recognized by the tokenizer. `Open For Binary/Random` accepts
  contextual mode names and reports missing path/mode/file-number syntax rather
  than leaving a null operand for the compiler.
- Record `Get` / `Put` deliberately falls back to AST execution. Its current
  contract is fixed 128-byte string records, not full VB6 typed serialization.
- Bytecode `Value` aliases apply to Range controls, not unrelated resources such
  as `VGRegExMatch` with their own `Value` property.
- Reusable VM local frames release objects and resource-owning containers on
  exit. A dedicated awaited-resource test verifies release on owner destruction.

Twenty-two commented lessons were added in six batches. Async hosts wait for
completion with a watchdog, physics checks a real collision, Tween checks its
endpoint, and interop uses an ephemeral loopback server and Python's standard
library. Python initialization failures are explicit, not skips. Headless audio
checks silent frame queueing only; rendering and audible output remain untested.

The corpus host now exercises actual auto-connected button, timer and keyboard
signals and checks resulting control state. Timer timeouts are synthetic;
physical focus, native InputBox dialogs, visual layout and gameplay remain
interactive validation tasks. This does not fully certify the sample projects
or resolve the editor-import/shutdown concerns documented below.

## Follow-up sample restoration

All 15 previously quarantined projects are back in their original locations.
They passed **60 bounded startup combinations**: 15 projects, two engines and
default/forced-AST execution. No parser, runtime or shader failure occurred in
those startup runs. Climatist's startup weather request was explicitly disabled
for offline testing; a separate loopback HTTP check verified status and body.

Ten focused probes in [`run_sample_regression.gd`](../../test_proj/run_sample_regression.gd)
passed **40 engine/mode combinations**. These check HighScores data preservation,
Snake food/power-up placement and full-board termination, Platformer pause
fades/resume/reopen races, vector hit-testing and persistence, paint pixels,
movie controls, dashboard initialization, DocGen utility results, Climatist
imports, and AGCK's active glitch/shatter rendering. AGCK used OpenGL
Compatibility under Xvfb, not the dummy headless renderer.

The restoration exposed four native root causes:

- Indexed ByRef write-back could store an entire array in its own element
  when a builtin shadowed a user function. Indexed fallbacks now read the
  element, and each call clears stale captures. Non-pure computed indices
  retain the established AST fallback so index calls cannot erase captures.
- Imported modules' dependencies were not loaded recursively, and the compiler
  did not recognize transitive qualified module calls.
- Computed-goto opcode exits bypassed C++ scope destructors. Dispatch now leaves
  the opcode scope through a direct jump before indirect dispatch. A regression
  verifies that repeated GDScript static calls do not grow script references.
- AST execution incorrectly treated an explicit Tween object's `TweenProperty`
  method as the legacy global shortcut, leaving the receiver Tween empty.

At the sample-restoration checkpoint, the full differential suite passed **220
matched fixtures on each engine**, with zero failures/divergences and eight
explicit exclusions. All four final corpus runs passed **80/80**, without
failures or skips.

Sample fixes include supported draw transforms, path-based autoloads, corrected
declarations, bounded Snake placement, pause-menu race handling, standalone
mobile console hosts, and DocGen's Include-based module host. The API snapshots
were regenerated with the actual documentation generator.

AGCK's augmented game and media remain ignored/local by explicit choice.
Its [tracked build and repair workflow](../../samples/internal/AGCK_Tests/README.md)
preserves the shader, widget and music-teardown corrections without committing
generated assets. Clean scaffold generation also required loading the tile
library, supporting serialized numeric death actions, and completing the
behavior-template `.vgt` migration. The base scaffold is not the augmented game.
Repair/generation acceptance tests pass on both engines, including idempotence,
helper-return preservation, explicit rejection of unknown shader patterns,
persisted widget/music repairs, and numeric/string death actions.

**Remaining limits:** cold editor imports can still report debugger attachment
and RID/font/viewport teardown diagnostics. Abrupt frame-limited shutdown can
warn about autoplay audio resources; the orderly behavioral host stops audio
and waits before quitting. The historical Brotato heap-corruption crash classification,
interactive gameplay, hardware input, mobile permissions and exports remain
separate work. This campaign does not claim that all possible VG defects have
been eliminated.

### Dictionary frame follow-up

Focused reproductions confirmed three bytecode-only fast-dictionary defects:

- `Dim … As New Dictionary` and `Dim … As Dictionary = New Dictionary`
  initialized a Godot Dictionary while subsequent indexed operations expected
  an active fast-dictionary slot.
- Fast-dictionary slots lived on the script instance instead of the invocation,
  so a nested call could overwrite and clear its caller's slots.
- `Await` saved ordinary locals but not fast-dictionary contents or active-slot
  state. Resumption therefore accessed invalid slots.

The compiler now initializes eligible declarations with the fast-dictionary
opcode. A declaration that aliases an existing dictionary revokes fast-dictionary
eligibility, preserving shared Godot Dictionary behavior. The VM owns a lazily
allocated pool per invocation; each continuation saves active dictionaries and
reconstructs its own pool when resumed. Empty active dictionaries are saved too.

Regression fixtures cover both declaration forms, aliasing, nested calls,
recursion, and overlapping continuations with repeated suspension. A resource
probe also checks that a dictionary keeps its resource alive across suspension
and releases it after the completed continuation.

That probe exposed a related scope-cleanup defect: the VM publishes named
locals at exit, but call cleanup had assumed that disabled per-opcode variable
synchronization meant nothing was published. Named locals are now saved,
restored and removed regardless of that synchronization setting. Fast-call
parameters/return slots and unpublished compiler scratch retain their existing
fast paths.

Both Linux targets were rebuilt. The final full differential runs passed **223
matched fixtures per engine**, with zero failures/divergences and eight explicit
exclusions. All four corpus runs passed **80/80**, and the 40 sample behavior
combinations passed again. The three new fixtures provide 16 matched assertions,
including resource retention/release. Bytecode inspection confirmed that
eligible declarations and recursive/awaited dictionary accesses still use
compiled fast-dictionary operations rather than a new AST fallback.

### Cold editor-import deadlock follow-up

A symbolized native stack from a pristine 2D Brotato import identified the
timeout: `_reload_all_scripts()` held `live_scripts_mutex`, called
`VisualGasicScript::_reload()`, and blocked when `register_script()` tried to
lock that same non-recursive mutex. The queued `_frame()` reload path had the
same lock/reload ordering. The suspended preview-capture warnings occurred
before the stall; they were not its cause.

Both paths now take a retained script snapshot while holding the registry lock
and perform file access and reloads after releasing it. Retained references keep
scripts alive during reload and are released outside the lock. Pending work is
drained under the lock, without discarding new work queued during a reload.

The opt-in [native regression probe](../../src/visual_gasic_hot_reload_selftest.cpp)
checks initial parsing, reload-all reparsing, deferred/duplicate queued reloads,
unchanged source, snapshot-reference release, and destruction of queued scripts.
It removes its own process-specific fixture and reports **9 passed, 0 failed**
on both Godot versions, under both headless and graphical launch.

The persistent [editor regression runner](../../scripts/run_editor_reload_regression.sh)
creates fresh tracked-input snapshots, never imports the user's working sample
projects, and retains all diagnostics. Both Brotato projects completed cold
imports on **4.6.1 and 4.7.2**, with both the headless renderer and software
OpenGL Compatibility under Xvfb: **eight completed import combinations**.
Headless logs explicitly confirm editor-layout completion and reload-all;
graphical runs verify VG resource recognition in the persisted editor cache.
Both main scenes also passed **eight 120-frame startup combinations** across
the two engines and default/forced-AST modes.

Both Linux libraries were rebuilt. Final differential suites passed **223
matched fixtures per engine**, with zero failures/divergences and eight explicit
exclusions; all four corpus runs passed **80/80**. Full suites were run
sequentially because database/folder fixtures use fixed `/tmp` paths and collide
under concurrent engine runs. The coverage evidence was refreshed, and its
14 acceptance checks passed. Compute, gameplay and draw wrappers also completed
with comparable checksums, including MovingFilledRects checksum **257901** and
**120 frames**. These completion checks do not establish new speed comparisons.

Reproduce the bounded import checks with:

```sh
GODOT=/path/to/Godot scripts/run_editor_reload_regression.sh
GODOT=/path/to/Godot RENDER_MODE=graphical LIBGL_ALWAYS_SOFTWARE=1 \
  xvfb-run --auto-servernum --server-args='-screen 0 1280x800x24' \
  scripts/run_editor_reload_regression.sh
```

`TIMEOUT_SECS` defaults to 120 per launch. An optional `OUT_DIR` must have no
existing regression-project directories. The native probe runs only when
`VG_HOT_RELOAD_SELFTEST=1`; the runner checks its exact completion summary and
rejects probe errors/leaks, engine failures, timeouts, and script/fatal errors.
The sample import checks deliberately retain and display cold font/theme
bootstrap errors and shutdown diagnostics rather than calling imports clean.

**Still unresolved:** editor RID/font/viewport/ObjectDB teardown leaks,
suspended live-preview cancellation warnings, debugger-session detachment
diagnostics, and the earlier heap-corruption crash. No heap-corruption crash
occurred in these eight imports, but that does not classify or resolve the
historical crash. This fix is not an ABI change or an interactive gameplay
certification.

### Debugger and live-preview lifecycle follow-up

An isolated real editor plugin reproduced a VG-owned lifecycle defect:
after `remove_debugger_plugin()`, VG still retained its session and polling
timer. Calling `is_session_alive()` or the poll callback then produced
`Plugin is not attached to debugger`; late `debug_break()` also requested
session zero from an empty native session list.

The debugger now has idempotent shutdown before the main plugin unregisters it
or destroys panels. Shutdown stops, disconnects and frees the polling timer,
disconnects retained session signals, releases session/parent references, and
completes pending evaluation callbacks with an explicit failure. Remote-command
and liveness paths check current native session membership before accessing a
retained session. Late callbacks cannot reacquire sessions after shutdown.
Ordinary game stop does **not** shut the plugin down: a subsequent game launch
can reconnect normally.

Live preview first captures no longer suspend a GDScript coroutine across
script reimports. They are scheduled after two rendered frames and canceled on
unregistration or shutdown. Headless imports allocate neither preview viewports
nor capture timers, since their dummy renderer cannot provide preview pixels.
Graphical preview capture, freeze and re-registration remain supported.

The [lifecycle runner](../../scripts/run_editor_lifecycle_regression.sh) enables
only its test plugin in a new isolated project. It passes **50 headless checks
and 64 graphical checks on each engine**, with no errors or shutdown leaks in
these isolated harnesses. Checks cover three registration/removal cycles,
explicit and engine-first removal, retained-session signal disconnection,
timer/reference release, pending and late evaluations, and late remote commands.
Graphical checks verify actual **200 × 150 red-control pixels**, freeze behavior
and cancellation, plus native VG instance requests and Immediate-window
evaluation across two real game launches. Child games run headlessly to avoid
Xvfb embedded-window races; this is debugger transport validation, not a visual
gameplay test.

```sh
GODOT=/path/to/Godot scripts/run_editor_lifecycle_regression.sh
GODOT=/path/to/Godot RENDER_MODE=graphical LIBGL_ALWAYS_SOFTWARE=1 \
  xvfb-run --auto-servernum --server-args='-screen 0 1280x800x24' \
  scripts/run_editor_lifecycle_regression.sh
```

The runner rejects an absent or incomplete exact check summary, engine failures,
timeouts, script/runtime errors, and teardown leak diagnostics. It refuses to
reuse a project directory. All eight pristine Brotato import combinations
completed again without canceled preview executions or debugger-detachment
diagnostics. No native source or binary changed in this follow-up.

**Remaining limits:** the full VG editor still leaks UI/font/viewport/ObjectDB
resources, unlike the extension-loaded baseline with the VG editor plugin
disabled. A fresh Platformer import still produces **one stackless native
`Plugin is not attached to debugger` diagnostic**, despite the VG callback
regression being fixed. A native write catchpoint captured tree-teardown frames,
not a GDScript backtrace; its remaining calling path is not yet classified.
The earlier heap-corruption crash also remains unresolved. The clean isolated
lifecycle checks do not establish clean shutdown of the complete editor.

### Complete-editor UI ownership follow-up

Complete-plugin disable probes identified four VG-owned allocation leaks:

- The directly injected Project menu popup was detached but never freed.
  Direct injection now frees the popup; the Project > Tools fallback uses
  Godot's submenu-removal ownership instead. Deferred injection stops during
  shutdown.
- The embedded editor allocated an unused, unparented `ProcNavBar` container.
  That unused allocation was removed without changing the visible navigation bar.
- Narcea's hidden programmatic Build form button was never parented. It is now
  owned by its existing advanced toolbar and remains hidden.
- Each graphical Code Navigator ComboBox allocated a hidden inline ItemList
  without owning it until Simple style was selected. The inline list is now an
  internal child in all three styles, preserving later style switches.

The [lifecycle runner](../../scripts/run_editor_lifecycle_regression.sh) now
supports `FULL_PLUGIN=1`. **23 checks pass on each engine in both headless and
graphical modes**: all ComboBox styles and transitions retain items/selection
and release their lists; two complete VG enable/disable cycles release menus,
panels, debugger and main plugin; both direct Project and Tools-fallback paths
are exercised; no new orphan roots remain. Adding `EXIT_ENABLED=1` runs **24
checks**, leaving VG enabled for normal editor quit. All four enabled-at-quit
engine/renderer combinations completed without error or RID/ObjectDB leak
diagnostics. The original 50-headless/64-graphical component checks also pass
on both engines.

```sh
GODOT=/path/to/Godot FULL_PLUGIN=1 EXIT_ENABLED=1 \
  scripts/run_editor_lifecycle_regression.sh
GODOT=/path/to/Godot FULL_PLUGIN=1 EXIT_ENABLED=1 RENDER_MODE=graphical \
  LIBGL_ALWAYS_SOFTWARE=1 xvfb-run --auto-servernum \
  --server-args='-screen 0 1280x800x24' \
  scripts/run_editor_lifecycle_regression.sh
```

Full-plugin runs are sequential because VG's local MCP server uses a fixed
port. No native source or binary changed. These checks establish clean
complete-plugin ownership in the tested minimal editor projects, not every
interactive workflow or optional plugin combination.

**Still open:** the Platformer editor shutdown retains one stackless native
debugger-detachment diagnostic, even though the tested UI leaks are gone.
A separate snapshot with VG's editor plugin disabled does not emit it.
The historical heap-corruption crash remains unclassified. Earlier unresolved
leak observations above are retained as historical evidence; the verified
ownership follow-up supersedes them for the tested minimal editor lifecycle.

### Native popup-focus shutdown diagnostic classification

The remaining Platformer diagnostic was traced further, without changing VG's
session guards or suppressing engine errors. Its Godot 4.7.2 native caller is
`GameView::_notification` forwarding a window-focus notification to
`GameViewDebugger::report_window_focused`, which calls
`EditorDebuggerSession::is_active` after that engine-owned session was detached.
The stripped executable's direct call and message string
`scene:report_window_focused` were mapped to the matching engine source. This
is not a VG debugger callback.

The [standalone probe](../../scripts/run_editor_focus_teardown_probe.sh)
creates a fresh project containing only a minimal EditorPlugin and a visible
Window parented to Godot's editor base control. It loads **no VG extension,
VG editor plugin, or custom debugger**. Quitting reproduces the exact
`Plugin is not attached to debugger` / `is_active` diagnostic on **Godot 4.7.2
headless**. Godot 4.6.1 headless and graphical runs on both versions were clean.
Parenting the Window to the test plugin instead was also clean headlessly on
both versions, as was hiding the base-owned popup before quitting. Thus the
observed headless shutdown warning has an independent
engine-side reproduction; its absence with VG disabled does not establish
that VG owns the detached session.

```sh
# Expected to fail with the native diagnostic on 4.7.2 headless.
GODOT=/path/to/Godot scripts/run_editor_focus_teardown_probe.sh
# Ownership control: release the popup with its EditorPlugin subtree.
GODOT=/path/to/Godot WINDOW_OWNER=plugin \
  scripts/run_editor_focus_teardown_probe.sh
# Focus control: hide the popup before initiating quit.
GODOT=/path/to/Godot CLOSE_BEFORE_QUIT=1 \
  scripts/run_editor_focus_teardown_probe.sh
# Graphical comparison; clean in the tested Xvfb runs.
GODOT=/path/to/Godot RENDER_MODE=graphical LIBGL_ALWAYS_SOFTWARE=1 \
  xvfb-run --auto-servernum --server-args='-screen 0 1280x800x24' \
  scripts/run_editor_focus_teardown_probe.sh
```

The runner returns failure for any shutdown error, even when Godot exits with
status zero. It preserves the full log and never treats this known diagnostic
as a passing regression test. No engine internals are patched and no general
VG UI shutdown workaround is claimed. The historical heap-corruption crash
remains separate and unclassified.

### Latest performance checks after dictionary fixes

The compute wrapper and three sequential gameplay/draw runs passed on Godot
4.7.2 with comparable checksums and required completion markers. Median paired
GDScript/VG speed ratios were **5.26x FrameSlice**, **4.13x EntityThink**,
**6.06x DictionaryScan**, and **approximately 1.00x CallChain** (parity).

Corrected MovingFilledRects again matched checksum **257901** and **120 frames**.
Median reported timings were **163 us VG**, **229 us GDScript**, and **44 us C++**;
the ratio of median timings is **1.40x in VG's favor**. Individual gameplay runs
varied substantially on this shared host: for example, EntityThink ratios ranged
from 1.31x to 6.58x. These smoke measurements do not establish a performance
improvement or regression versus the earlier campaign. They are not whole-game
FPS or GPU-rendering claims.

### Sample-restoration performance checkpoint

After correctness testing, the final Linux editor build passed the compute
wrapper and three isolated gameplay and draw runs on Godot 4.7.2. Required
completion markers and comparable checksums were verified.

Three-run median paired GDScript/VG speed ratios were **4.85x** for FrameSlice,
**2.83x** for EntityThink and **1.15x** for CallChain. These are individual
microbenchmark results, not whole-game FPS claims.

The corrected MovingFilledRects workload retained checksum **257901** and
**120 frames** for all three implementations in every run. Median reported
`elapsed_us` values were **144 VG**, **236 GDScript** and **39 C++**.
The ratio of those median timings is **1.64x in VG's favor**; C++ remains faster.
This headless draw/queue benchmark does not measure displayed frame rate or
GPU rendering. It is a follow-up smoke measurement, not a replacement for the
earlier published benchmark campaign.

## Original audit conclusion (historical)

**The tested Linux VG runtime works on Godot 4.7.2 with the existing binaries.**
This audit does **not** establish that every example works or that the complete
editor migration is safe. Keep a backup and retain Godot 4.6.1 until the
unclassified editor-import crash and debugger-shutdown diagnostic are resolved.

- Engine: `4.7.2.stable.official.ed1daf0bf`.
- Baseline engine: `4.6.1.stable.official.14d19694e`.
- Platform: Linux x86_64, Intel Core i7-1255U.
- Source baseline: `b1aeeaa8`, plus the compatibility changes in this commit.
- Existing editor and template_debug `.so` files loaded without rebuilding.
- GDExtension minimum remains `4.5`; bindings remain based on the 4.5 API.
- No ABI-related C++ change or binding regeneration was demonstrated necessary.
- Windows/macOS/Web/mobile exports, release binaries, graphical rendering and
  complete gameplay were not validated here.

## Source changes required and made

Godot 4.7.2 rejects the missing return values in several GDScript
`SceneTree._process()` overrides. Updated 23 callbacks in the language runners,
engine harness and sample diagnostic scripts to explicitly return `bool`,
including early returns. Returning `false` preserves their existing execution
and explicit `quit()` behavior. All 23 scripts parse on both engine versions.

The corpus harness previously swallowed process status, could stop on an empty
filtered output, and did not reliably distinguish completion from failure.
It now requires a completion marker, checks process status and diagnostics, and
counts examples without expected output as skips without executing them.
These checks expose existing failures rather than changing VG language behavior.

No speculative native fix was applied for the import crash. A native-stack or
sanitizer reproduction is needed before deciding whether that defect belongs
to VG, Godot, or their editor/resource-import interaction.

## Test results

| Check | Godot 4.7.2 result |
|---|---|
| AST/bytecode differential suite | 210 matched passing fixtures, 0 failures, 0 divergences; 8 explicitly excluded |
| Changed GDScript callbacks | 23 parse successfully on each engine |
| Custom AI providers, runtime | 74 checks passed |
| Custom AI providers, isolated editor | 123 checks passed; shutdown leak diagnostics remain |
| Narcea existing smoke tests | 118 checks passed; shutdown resource warning remains |
| Vector tests | 50 checks passed |
| Sprite tests | 35 checks passed |
| Parser diagnostics | 5 checks passed; intentional malformed-source diagnostics |
| Debugger stepping/preview | 3 checks passed |
| Socket regression checks | 2 checks passed |
| Scaled integer-offset draw regression | 25 checks passed in default execution mode |
| Compute and draw benchmark wrappers | Completed with matching required outputs/checksums |
| Strict corpus audit | 36 pass, 14 fail, 8 skipped; identical results on 4.6.1 |

The first differential run had 209 matches and an AST array-stress timeout with
a 20-second allowance while other audits ran. The targeted stress retry passed
5 assertions per execution mode. The final complete run used a 60-second
allowance and passed all 210 compared fixtures; the timeout is not hidden as
a pass.

The debugger step trace was `[11,12,13,5,6,7,8,14,15,16,17]`. The saturated
socket-backlog check timed out in 24 ms as expected.

Benchmark runs here are compatibility smoke checks, not a new performance
campaign. The single moving-rectangle run measured VG 107 us, GDScript 154 us
and C++ 126 us, with checksum 257901 and 120 frames. Do not replace the
[published three-run benchmark medians](../benchmarks/BUG_CAMPAIGN_OCT2026.md)
with this single run.

## Sample-project audit

An isolated copy of **56 sample projects plus `engine_lab`** was audited.
Each project received a cold headless editor import with a 90-second allowance.
Each configured main scene received a headless startup of 180 frames with a
45-second allowance. Caches and editor settings were separate from the working
projects; imports could not migrate or autosave the user's original scenes.

The complete initial matrix is [results.tsv](godot-4.7.2/results.tsv).
It records process exit codes, diagnostic counts and configured main scenes.
An empty main-scene field means runtime testing was not performed. A zero
exit code or zero counted errors is **not a pass**: VG can report parser
errors without failing the process, and the initial numeric error counts do
not include raw `Parser Error` lines. Those lines were inspected separately.
Common resource/RID shutdown leaks also prevent calling imports clean.

Initial imports exited normally for 55 projects; the two Brotato imports
exceeded the 90-second allowance. Of 56 attempted main-scene startups, 51
exited normally, two timed out and three lacked their configured main scene.
These are completion counts, not successful-example counts.

### Import retries and unresolved editor concerns

- **Brotato3D:** a 240-second import retry completed, followed by a successful
  startup with shutdown-only resource diagnostics. The initial missing imported
  assets were a consequence of the short import budget, not a proven game bug.
- **2D Brotato:** an import retry on 4.7.2 aborted with heap-corruption
  (`malloc(): unaligned tcache chunk detected`) and signal-11 diagnostics.
  A subsequent 4.6.1 import completed; a warm 4.7.2 import and startup then
  completed with shutdown leaks. Separate pristine cold-import attempts timed
  out at 240 seconds on **both** engines, reporting canceled
  `_do_deferred_first_capture` executions during script reload.
  Thus the cold-import timeout is not exclusive to 4.7.2, but the observed
  crash is **unclassified and unresolved**, not cleared by the warm success.
  The [cold-import follow-up](#cold-editor-import-deadlock-follow-up) subsequently
  identifies and fixes a native reload deadlock on both engines; the historical
  heap-corruption crash remains unresolved.
- **Debugger shutdown:** several 4.7.2 editor imports report
  `Plugin is not attached to debugger` from
  `editor_debugger_plugin.cpp:102`. An old-engine hex-editor import did not
  emit that diagnostic. Registration/session teardown needs investigation;
  no cause or safe fix has been established.
  The [lifecycle follow-up](#debugger-and-live-preview-lifecycle-follow-up)
  subsequently fixes VG-owned retained-session/timer callbacks, but one native
  Platformer shutdown diagnostic and general editor leaks remain unresolved.
- **`engine_lab`:** cold import cannot resolve a UID-only music autoload
  (`uid://bc7hq8fpdwr7s`). There is no configured main-scene startup result.

### Existing failures confirmed on both engines

| Project | Observed problem |
|---|---|
| `apps/climatist_poc` | Undefined `HttpFetch` in `HttpGetWithHeaders`, WeatherApi line 102 |
| `apps/vector_dashboard` | Parser errors and undefined `_ResolveAsteroidCollisions` |
| `demos/2D_Games/Platformer_Godot` | `Tween` variable conflicts with statement keyword; sprite frame 42 exceeds 8 available frames |
| `demos/2D_Games/Snake` | Out-of-range access in `GetLevelTarget`, line 129; startup timeout |
| `demos/Data_and_Files/HighScores` | Repeated `Maximum array recursion reached!`; startup timeout |
| `demos/Graphics/VGMovie` | Missing `Loop` parser error |
| `demos/Graphics/VGPaint` | Unexpected comma, parser line 681 |
| `demos/Graphics/VGVector` | Unexpected comma, line 403, and missing `Next` parser error |
| `demos/Mobile/Pedometer` and `TiltMaze` | Configured `res://main.tscn` missing |
| `demos/Utilities/DocGen_Example` | Configured `res://main.tscn` missing |
| `games/pong_ultimate` | Undefined `PushTransform` in `_Draw`, line 439 |
| `games/racing_3d` | UID-only autoload `uid://b1rh8wxduem4j` does not resolve in cold checkout |
| `internal/vgai_demo` | Requests missing `vg/gdai/*` project settings |
| `internal/AGCK_Tests` | Shader compilation fails under the headless dummy renderer on both engines; graphical behavior untested |

Vector Crypt, Elite Wire Slice, Vector Storm, Squash the Creeps and Sky Shaders
had shutdown-only RID/resource diagnostics in their startup logs, rather than
the functional failures above. That distinction does not establish visual
correctness or leak-free operation.

## Corpus failures

All 14 failing filenames are identical on 4.6.1 and 4.7.2:

```text
01_basics/05_type_conversions.vg
01_basics/06_optional_types.vg
01_basics/07_exception_patterns.vg
03_strings/06_join_numeric.vg
04_arrays/02_array_sum_average.vg
04_arrays/03_array_max_min.vg
04_arrays/04_linear_search.vg
04_arrays/05_bubble_sort.vg
06_classes/06_class_generics.vg
07_file_io/02_read_text_file.vg
07_file_io/04_read_csv.vg
07_file_io/05_count_lines.vg
08_math/04_statistics_mean_stdev.vg
10_godot_integration/04_signal_connect.vg
```

Failures include expected-output differences and genuine parser/runtime issues.
The file-read fixture times out after a missing-`Loop` parser error. The eight
skipped fixtures have no expected-output block and are not certified by this
audit. Historical blanket claims that every corpus example works have been
corrected in the corpus and repository README files.

## Next steps before full upgrade certification

1. Investigate the 2D Brotato import crash with a useful native backtrace and
   a controlled cold-import reproduction; compare both engines.
2. Verify debugger-plugin shutdown/session ownership on 4.7.2 and fix only
   after establishing the lifecycle cause.
3. Repair the baseline sample and corpus defects above in a separate bug
   campaign, then rerun the strict corpus and startup checks.
4. Exercise representative samples interactively, including audio, input,
   rendering, networking and editor tool workflows.
5. Validate exports and shipped binaries independently on each supported
   platform. This Linux audit does not certify those targets.

## Evidence and reproduction

Concise raw logs and the initial matrix are preserved in
[godot-4.7.2/](godot-4.7.2/). The enormous repeated HighScores error log is not
committed; bounded first-error excerpts preserve the failure on both engines.
Retry logs supersede initial missing-resource results only where stated above.

From the repository root, using the downloaded engine's actual absolute path:

```bash
GODOT=/absolute/path/to/Godot_v4.7.2-stable_linux.x86_64 \
  TIMEOUT_SECS=60 scripts/run_ast_bytecode_diff.sh --all

GODOT=/absolute/path/to/Godot_v4.7.2-stable_linux.x86_64 \
  scripts/audit_corpus.sh
```

The differential command should pass. The corpus command currently exits
nonzero because of the documented 14 failures; do not suppress that status.
