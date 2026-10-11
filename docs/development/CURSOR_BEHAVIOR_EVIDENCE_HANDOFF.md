# Cursor handoff: behavior evidence pilot, Phase 1

## Assignment and stop boundary

Implement **source-located static Whenever chains and precise formatter/save
scenarios only**. This is the first step toward helping users understand and
verify AI-written VG programs. Do not implement the whole roadmap.

Inspect the existing implementation, write failing tests, implement, validate,
and return a scoped diff plus exact test results. Stop before runtime tracing,
new panels, Narcea approval changes, or release packaging. Do not commit or push
unless the user separately requests it.

The motivating workflow is:

1. Understand what opens the exit in Crystal Caverns.
2. Make a small change.
3. Verify whether the behavior still matches the user-owned expectation.

Static analysis describes **possible behavior**, not proof that it ran.
AI explanations, compiler facts, runtime observations, and user expectations
must remain distinguishable.

## Baseline and user work

Handoff baseline: `fa26003d` on main, recorded October 11, 2026.
Inspect current HEAD and worktree again before editing.

At handoff these files contain user edits:

- `.github/copilot-instructions.md`
- `samples/showcases/crystal_caverns/Caverns.vg`
- `samples/showcases/crystal_caverns/VisualEffects.vg`
- `samples/showcases/crystal_caverns/main.tscn`

Do not revert, stage, rewrite, or include these edits in a patch without explicit
permission. Prefer clean, short test fixtures rather than modifying the game.
The local game has a top-left player spawn; the committed gameplay test expects
the bottom-left spawn. This known fixture mismatch is not a new runtime failure.

The save-formatter repair is already shipped in commit `980e5196`. The refreshed
beta packages include it. Do not redo that repair or move the release tag.

## Read first

- [GDScript causal-chain entry point and fallback](../../addons/visual_gasic/vg_causal_chain.gd)
- [C++ causal graph implementation](../../src/visual_gasic_causal_graph.cpp)
- [C++ causal graph declaration](../../src/visual_gasic_causal_graph.h)
- [Language API binding](../../src/visual_gasic_language.cpp)
- [Existing causal fixtures](../../tests/test_vg_causal_chain.gd)
- [Additional causal smoke](../../test_proj/test_causal_chain.gd)
- [Formatter](../../addons/visual_gasic/vg_formatter.gd)
- [Embedded editor save path](../../addons/visual_gasic/vg_embedded_code_editor.gd)
- [Actual-save/editor regressions](../../samples/showcases/crystal_caverns/editor_regression.gd)
- [Crystal Caverns source](../../samples/showcases/crystal_caverns/Caverns.vg)
- [Live Debug Capture foundation](NARCEA_LIVE_DEBUG_CAPTURE.md)
- [Narcea agent design, historical context rather than verified current status](TIER3_NARCEA_AGENT_DESIGN.md)

`VGCausalChain.generate(text, roots)` currently prefers
`VisualGasicLanguage.vg_analyze_causal_graph(code, roots)` when available, then
uses a regex fallback when the extension is unavailable or its report is
unusable. Inspect both paths before choosing where to implement. Do not add
unnecessary duplicate parsing. Preserve current call sites and return shapes;
an additive structured API is preferable to breaking `generate()`.

## Deliverable A: static Whenever chain

Use the declaration below as an automatically discoverable entry point:

```vb
Whenever Section UnlockExit crystals Becomes GEM_TARGET OnUnlockExit
```

The source-linked report must identify:

- Section name: `UnlockExit`.
- Watched variable: `crystals`.
- Condition: `Becomes GEM_TARGET`.
- Handler: `OnUnlockExit`.
- Relevant handler guard and early return.
- State write: `exitOpen = True`.
- Local calls and unresolved target calls, distinguished explicitly.

### Important correction to the proposed plan

In the real game, `Sub PlayCue(cue As Integer)` is in **Caverns.vg itself**.
It delegates to `soundRenderer.PlayCue(cue)`.

Therefore:

```text
OnUnlockExit
  -> guard: gameState <> "playing" Or exitOpen
  -> exitOpen = True
  -> Call PlayCue(SFX_UNLOCK) [local target resolved]
    -> soundRenderer.PlayCue(cue) [target unresolved unless actually resolved]
```

A fixture that omits PlayCue may deliberately test an unresolved local call.
Do not describe that fixture as the real game's file structure.

### Structured evidence contract

Provide machine-readable data from which the text report can be rendered.
Choose exact field names after inspecting existing return structures.
At minimum include:

- Schema version.
- Caller-supplied source identity/path, without pretending an in-memory snippet
  has a disk path.
- Content hash of the analyzed source; specify what exact text is hashed.
- Analysis provenance: AST or fallback.
- Root/declaration, guard, state-write, and call information.
- Source locations with a documented line convention.
- Resolution status and optional target location.
- Explicit limitations, including dynamic/external targets and truncated walks.

Each source-backed step must have a source identity and line. An unresolved
call still has a **call-site** location; its target location is unknown.
Do not invent locations for synthetic headings or truncate without disclosure.
Source changes must invalidate identity; future runtime evidence will use this
to avoid matching an old successful run to new code.

Risk annotations are reasons to inspect: `state write`, `early-return guard`,
`external effect`, `unresolved target`. They are not a safety score.
An unmarked line is not certified safe.

### Acceptance tests

Extend the existing causal fixtures and retain all eight existing cases.
Assert structured fields and locations, not merely substring presence.

Include:

1. Becomes watcher root with the expected variable, condition, handler and write.
2. Multiple independent Whenever roots, with no spurious nesting.
3. Guard/Exit Sub represented as possible control flow, not unconditional output.
4. Local PlayCue resolution and separately unresolved object-method target.
5. Missing handler/local-call target: explicit unresolved result and call site.
6. Comments and strings containing Whenever do not create roots.
7. Equivalent source with different indentation has equivalent relationships,
   but correct locations/content hashes for its own text.
8. Changed source changes the hash; unchanged source produces stable output.
9. Recursive or depth-limited traversal terminates and reports limits.
10. Existing event roots and explicitly selected roots still work.

Exercise the extension-backed path and the fallback intentionally; do not let
a passing fallback conceal an AST defect. Clearly state any unavailable path.
Do not represent fallback parsing as equivalent in completeness to the AST.

## Deliverable B: user-owned save scenario

Reuse or strengthen the actual-save assertions in
[editor_regression.gd](../../samples/showcases/crystal_caverns/editor_regression.gd).
They already exercise a temporary `user://` save rather than overwriting the
game. The current baseline has 215 passing checks on Godot 4.6.1 and 4.7.2.

Use a clean fixture containing:

- `<>`, `>=`, and `<=` compound comparisons.
- Unary negative numbers and based numeric literals.
- Quoted repeated spaces and operator-like text.
- Comments containing apparent keywords/operators.
- Multiple inline Whenever declarations.
- A padded sprite DATA header and rows.

Require:

- Meaning-bearing tokens/literals remain unchanged except intentional keyword
  case normalization.
- String and comment contents stay unchanged.
- DATA values **and column padding** stay unchanged.
- Procedures/watchers retain correct structural indentation.
- The actual saved output parses.
- A second actual save leaves the bytes unchanged.
- Tests do not alter user source or leave temporary files.

Keep expectations fixed while implementing. If an expectation is incorrect,
explain it and seek separate user approval rather than silently weakening it.
Agent-enforced protection of scenario files and runner machinery is a later
phase, not part of this implementation.

## Validation and reporting

Use existing build/test tooling. Inspect repository instructions and runners
before selecting commands; do not install tooling just to run this task.
If C++ changes, rebuild the extension using the repository's supported build
route before claiming the AST path is tested.

Local engines available at handoff:

- `/home/Commodore/Documents/VisualGasic/Godot_v4.6.1-stable_linux.x86_64`
- `/home/Commodore/Downloads/Godot_v4.7.2-stable_linux.x86_64`

Run the smallest relevant causal and save suites, then affected consumers as
needed. Fail on parser/runtime errors, missing result markers, timeouts, and
incomplete runs, not just the process exit code. Cold-import isolated projects
before running if the extension has not been registered there.

Return:

1. Files changed and why.
2. Structured result schema and compatibility decisions.
3. Exact commands, test counts and outcomes, separated by AST/fallback.
4. Known unresolved cases and explicit analysis limits.
5. Confirmation that user edits and release assets were untouched.

## Later phases: context only, do not implement

### Runtime evidence ring

Opt-in, bounded, local and purged on stop. Trace selected variables (`crystals`,
`exitOpen`, `health`) in both AST and bytecode without changing semantics.
Distinguish watched-value change, watcher trigger, handler entry, and handler
completion/failure. Record old/new values, source locations and correlation IDs
where runtime causation is actually known. Bound serialized values and overhead.

Identity includes run ID, source hash, execution mode, engine/runtime version,
scenario/expectation version, event sequence and capture completeness. Report
dropped/overwritten events. Statuses distinguish observed, not observed during a
complete scenario, unknown/incomplete, stale, and unresolved static target.
No inference of causation from timing alone.

### Exit scenario

Start with `gameState = "playing"`, `exitOpen = False`, crystals below threshold.
Reach the threshold through real gameplay or normal assignment, never a direct
OnUnlockExit call. Verify state transition and one actual handler invocation,
not only an application-owned counter. Include below-threshold, repeated-value,
guard, restart, capture-off and ring-overflow cases.

### Protected expectations, panel and change card

Protect scenario files, runner, assertions, selection/configuration and result
interpretation from Narcea mutations unless separately approved. This is a
workflow boundary, not protection against every external editor.

One Godot-integrated panel compares static possibilities with observed events.
Keep model text, compiler facts, observed results and user expectations separate.
Show pass/fail/not-run/incomplete/stale, not success-shaped empty evidence.
No new persona or standalone IDE expansion.

Rollback tracks all touched/created/deleted files, scenes and binary assets.
Detect subsequent user edits and report conflicts rather than overwriting them.
It does not reverse external side effects.

### Pilot measurement

Task A: understand what opens the exit. Task B: evaluate a small change.
Compare baseline editor with evidence workflow using equivalent variants or
counterbalanced order to reduce learning effects. Measure time, correctness and
ability to distinguish observation from explanation. One outside user provides
a usability smoke test, not general productivity proof.

## Explicitly excluded

Door-sprite selection (the exit is a tile, not a node), project-wide behavior
maps, natural-language death explanations, instruction replay, screenshot
comparison infrastructure, new security systems, autonomous agent orchestration,
release rebuilding, and broad unrelated formatter/runtime cleanup.
