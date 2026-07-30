# VisualGasic — Copilot Instructions

## Model selection (check before starting)

| Task | Model to use |
|---|---|
| C++ parser / runtime bugs (M1) | **Claude Opus 4.8** — max mode |
| GDScript plugin architecture (M4 UI Forms) | **Claude Opus 4.8** — max mode |
| AST walker / algorithm design (M6) | **Claude Opus 4.8** — standard mode |
| Extending existing GDScript files (M3) | **Claude Sonnet 4.6** — standard mode |
| Examples audit / mechanical fixes (M2) | **Claude Sonnet 4.6** — standard mode |
| Narcea prompt engineering (M5) | **Claude Sonnet 4.6** — standard mode |
| README / docs / issue bodies | **Claude Sonnet 4.6** — standard mode |
| Quick questions / one-liners | **Claude Haiku** |

Switch the model in the Copilot chat dropdown before pasting a large prompt.

---

## Project context

- **Language:** VB6-style BASIC (`VisualGasic` / `.vg` files), tokenizer/parser/AST/VM in C++
- **Runtime:** Godot 4.6.1 plugin via GDExtension (`.gdextension`)
- **Primary IDE:** Godot's native Script editor — VG extends it with autocomplete, Code Navigator, dot-completion
- **VG custom IDE shell:** standalone IDE window/layout, Form Designer, embedded code editor — **MOTHBALLED until post-v6.0 stable**; only active when `vg/enable_experimental_plugins = true`
- **Godot IDE integration (active scope):** Toolbox panel, Properties window, Immediate window, Narcea AI Pair, Code Navigator, autocomplete, dot-completion — these are docked inside Godot's editor and are **in scope for all milestones**
- **Focus until v6.0:** VG Script language quality + Godot IDE integration. Do NOT expand the VG standalone IDE shell.
- **AI providers:** `addons/visual_gasic/vg_ai_providers.gd` — Ollama, OpenAI, Claude, Gemini
- **Canonical Claude models (Anthropic direct API):** `claude-opus-4-8`, `claude-sonnet-4-6`, `claude-haiku-4-5` (verified 2026-06-29)
- **GitHub Copilot model dropdown:** also exposes `claude-opus-4-6`, `claude-opus-4-7` — these are Copilot-specific variants not on the direct API

## Milestone schedule

| Milestone | Due | Status | Focus |
|---|---|---|---|
| M1 | Jul 31 | ✅ DONE (Jun 29) | 4 critical bugs — all fixed |
| M2 | Aug 15 | ✅ DONE (Jun 30) | 44/44 corpus examples passing |
| M3 | Aug 31 | ✅ DONE (Jul 1) | Code Navigator upgrade (#7) |
| M4 | Sep 30 | ✅ DONE (Jul 1) | UI Forms experimental (#8–12) |
| M5 | Oct 15 | 🔄 NEXT | Narcea AI pair (#13) |
| M6 | Oct 31 | — | Causal Chain text-mode (#14) |
| M7 | Nov 15 | — | Python Library Integration (PyImport, PyCallAsync, numpy/opencv) |
| M8 | Nov 22 | — | Language parity (Try/Catch/Lambda/`?.` tests), `Let` keyword, C++ interop |
| M9 | Nov 28 | — | Asset Library submission, installer smoke test, 50+ corpus, docs |
| Stable v6.0 | Jan 1 2027 | — | — |

## Code conventions

- GDScript: `snake_case` for functions and variables, `PascalCase` for classes
- VG language: VB6-style — `Sub`, `Function`, `End Sub`, `Dim x As String`, `If ... Then ... End If`
- C++: follow existing style in `src/` — no trailing whitespace, tabs not spaces
- C++ memory: strict manual management within GDExtension bounds; verify zero leaks on node destruction
- C++ errors: no generic panics — use clean, actionable error messages with exact line numbers
- Do not add docstrings, comments, or type annotations to code you didn't change
- Do not refactor or rename symbols outside the scope of the current task

## Documentation tone

- Technical, precise, highly instructional — no marketing language

## Known open bugs

- **C64 Emulator VIC render bug (OPEN, found Jul 29 2026)** — `demos/C64_Emulator` screen stays solid black indefinitely even after multiple virtual PAL frames have demonstrably completed (confirmed via headless PERF counters + windowed screenshot test). Border/background registers (`$D020`/`$D021`) are set to blue before CPU reset, but no color ever renders. Separate from the (also confirmed, but expected/non-bug) slow KERNAL boot throughput (~275-500 steps/sec). No root cause found yet — not investigated past confirming it's real. Full details, repro steps, and next-step plan: `/memories/repo/c64_vic_render_bug.md`.

## Recent fixes (Jul 15, 2026)

- `IsNot` operator — IMPLEMENTED. Parser (`parse_comparison`), bytecode compiler (constant-fold, class type-check negation via `OP_IS_CLASS`+`OP_NOT`, `OP_NOT_EQUAL` emission), and both evaluator paths (tree-walk `evaluate_expression` + `VisualGasicExpressionEvaluator`) all handle it as the negation of `Is`. Verified via `test_isnot_operator.vg` / `test_isnot_simple.vg` / `test_isnot_simple2.vg` (7/7 assertions).
- **ByRef write-back bug in expression-level function calls — FOUND & FIXED.** Distinct from the Jun 29 recursion fix (`b130dd8e`). When a `ByRef` function was called as part of an expression (e.g. `result = DoubleAndReturn(val)`) rather than as a standalone `Call` statement, the caller's variable was never updated — `call_internal()` erases the callee's parameter slots from `variables[]` after the call (stashing the real post-call value in `_last_byref_captures`), but the expression-evaluator write-back path in `visual_gasic_instance_evaluate.inc` was reading the already-erased `variables[param.name]` instead of `_last_byref_captures`. Fixed to match the working `STMT_CALL` path in `visual_gasic_instance_execute.inc`. Full regression suite: 763/763 assertions pass (was 762/763 before fix).

## Recent fixes (Jun 30, 2026)

- `dict.Count` / `dict.Keys` / `dict.Items` without parens — FIXED (commit 9d37ddd8)
- `arr.Count` / `arr.Length` without parens — FIXED (commit 4dca1b16)
- `Join()` integer formatting (no `.0` suffix) — FIXED (commit 5612c339)
- ByRef default parameters in recursive calls — FIXED (commit b130dd8e)
