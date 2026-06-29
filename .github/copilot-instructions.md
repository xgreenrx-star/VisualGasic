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
- **IDE plugin:** GDScript — `addons/visual_gasic/visual_gasic_plugin.gd`
- **AI providers:** `addons/visual_gasic/vg_ai_providers.gd` — Ollama, OpenAI, Claude, Gemini
- **Canonical Claude models:** `claude-opus-4-8`, `claude-sonnet-4-6`, `claude-haiku-4-5` (verified 2026-06-29 at docs.anthropic.com/en/docs/about-claude/models)

## Milestone schedule

| Milestone | Due | Focus |
|---|---|---|
| M1 | Jul 31 | 4 critical bugs (#2–#5) |
| M2 | Aug 15 | 20 proven examples (#6) |
| M3 | Aug 31 | Code Navigator upgrade (#7) |
| M4 | Sep 30 | UI Forms experimental (#8–#12) |
| M5 | Oct 15 | Narcea AI pair (#13) |
| M6 | Oct 31 | Causal Chain text-mode (#14) |
| Stable v6.0 | Nov 1 | — |

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

## Known active bugs (M1 — fix these first)

1. `Boolean Or` throws `Err 35` in inline `If` conditions — `src/visual_gasic_parser.cpp`
2. Unhandled runtime errors corrupt app state (WorkerBusy stuck) — `src/visual_gasic_instance_call.inc`
3. `Proc.RunAndCapture()` causes phantom button double-press — `src/visual_gasic_instance_call.inc`
4. Double-click ignores existing `.tscn` signal connections — `visual_gasic_plugin.gd` ~line 7780
