# Cursor model selection

Check this before starting a large Cursor chat. Pin the model in the picker. Auto can change models between turns, and a long engine task then gets a faster model that fixes one path and stops.

Picker names below are the ones offered in this account on 15 Oct 2026. Re-check the dropdown when Cursor adds or renames models.

| Task | Model |
|---|---|
| C++ parser, VM, bytecode, AST, and JIT must agree | **Claude Fable 5.1 Thinking High** |
| GDScript plugin architecture, new IDE structure | **Claude Opus 5.5** |
| AST / algorithm design inside one subsystem | **Claude Opus 5.5** |
| Extending existing GDScript, Narcea prompts, docs, issue bodies | **Claude Sonnet 5.5 High** |
| Mechanical edits, fixtures, and follow-ups after the fix is already known | **Composer 2.5 Fast** |
| Quick questions | **Composer 2.5 Fast** |
| City and showcase art | **GitHub Copilot**, not a Cursor model |

## How to apply it

- Turn **Auto off** for every row except quick questions and mechanical edits.
- Keep the same model selected until the regression run finishes. A "small" follow-up on a VM bug is still the VM bug. Bytecode, the AST walker, and the tier-2 JIT each have their own call path. Fixing one of them is not a fix.
- Game and engine work is done when the headless suite and the rendered check both pass. Do not switch to a fast model to "just re-run and tidy."
- Gemini 4 Argon, GPT 5.6 Sol, Grok 4.7 High Fast, Cursor Grok 4.6 High Fast, and Muse Spark 1.3 High are in the picker. They are not the default for this repo. Grok 4.7 High Fast can stand in for Composer 2.5 Fast when you want a second fast pass.

## What went wrong under Auto

The Ash Meridian port (`07ac892a`, then the follow-up in `b4d1d3de`) was run on Auto. The first pass fixed bytecode compares and left AST comparisons, AST constructors, dictionary method keys, detached `GetNode`, shader resources, and JIT `queue_redraw()` wrong. Copilot remains the author of the Bleed City 2, City 3, and Backlight art. Cursor's job on that game is the engine and the Visual Gasic wiring.
