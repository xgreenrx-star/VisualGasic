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
- **VG custom IDE:** `addons/visual_gasic/visual_gasic_plugin.gd` — **MOTHBALLED until post-v6.0 stable**; only active when `vg/enable_experimental_plugins = true`
- **Focus until v6.0:** VG Script language quality + Godot IDE integration. Do NOT expand the VG custom IDE.
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

None. All tracked bugs resolved as of Jun 30, 2026.

## Recent fixes (Jun 30, 2026)

- `dict.Count` / `dict.Keys` / `dict.Items` without parens — FIXED (commit 9d37ddd8)
- `arr.Count` / `arr.Length` without parens — FIXED (commit 4dca1b16)
- `Join()` integer formatting (no `.0` suffix) — FIXED (commit 5612c339)
- ByRef default parameters in recursive calls — FIXED (commit b130dd8e)
