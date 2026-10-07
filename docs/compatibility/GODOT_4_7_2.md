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
58 examples reviewed. The 15 sample projects remain parked. The follow-up
section below describes the revised corpus; subsequent original-audit sections
retain the historical counts, paths and evidence.

## Follow-up corpus review

All **58 corpus examples pass, with zero failures and zero skips**, on Linux
in both default and forced-AST execution modes on **Godot 4.7.2 and 4.6.1**.
See the [corpus guide](../../corpus/README.md) for the four-run matrix,
review conventions and exact validation commands.

After rebuilding Linux editor and template_debug extensions, the complete
4.7.2 AST/bytecode differential rerun passed **212 matched fixtures**, with
zero failures/divergences and eight explicit exclusions. The audit harness's
12 acceptance/rejection checks also passed. An earlier concurrent run hit one
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

The corpus host now exercises actual auto-connected button, timer and keyboard
signals and checks resulting control state. Timer timeouts are synthetic;
physical focus, native InputBox dialogs, visual layout and gameplay remain
interactive validation tasks. This does not certify the quarantined projects
or resolve the editor-import/shutdown concerns documented below.

## Conclusion

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
- **Debugger shutdown:** several 4.7.2 editor imports report
  `Plugin is not attached to debugger` from
  `editor_debugger_plugin.cpp:102`. An old-engine hex-editor import did not
  emit that diagnostic. Registration/session teardown needs investigation;
  no cause or safe fix has been established.
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
