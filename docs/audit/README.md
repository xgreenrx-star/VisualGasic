# Reference audit

Tier 0 static checks that Programmer's Reference claims match engine dispatch sites.

## Run locally

```bash
# Full report (exit 1 if any missing dispatch)
python3 scripts/audit_reference_dispatch.py --write-report

# Full release gate (static + parse harness)
./scripts/run_command_reference_gate.sh
```

Output: `docs/audit/reference_dispatch_report.md`

## What it checks

| Source | Contents |
|--------|----------|
| `docs/VisualGasic_Language_Reference.md` | Part II commands with **Syntax** blocks |
| `docs/reference/GODOT_FUNCTIONS_REFERENCE.md` | Godot builtin headings |
| `addons/visual_gasic/vg_command_help.gd` | In-IDE help entries |

Dispatch index: all `src/**/*.cpp` and `src/**/*.inc` (`METHOD_IS`, `expr_compat`, bytecode special-call list).

## Status meanings

- **missing** — documented callable with no dispatch site (fix engine or remove doc)
- **known** — allowlisted gap (Interface, Using, Sprite Data, …)
- **mismatch** — in `GODOT_FUNCTIONS_REFERENCE` but not Language Reference / command_help
- **skip** — parameter docs (`delta`), types, lifecycle subs, Godot singleton docs

## Tier 1 runtime smoke

Input APIs: `test_proj/test_suite/test_reference_input_smoke.vg`

```bash
./run_test_suite.sh "test_reference_input*"
```

## Remaining work (see ROADMAP.md § Reference dispatch — remaining TODO)

| ID | Item | Status |
|----|------|--------|
| R1 | `Interface … End Interface` parser | Open |
| R2 | `Using … End Using` parser + RAII | Open |
| R3 | `Disconnect()` regression test | Open |
| R4 | Narcea / copilot known limitations | Open |
| R5 | Graven root duplicate cleanup | Open |
| R6 | Audit PascalCase ↔ snake_case aliasing | Open |
| R7 | Promote GODOT_FUNCTIONS_REFERENCE → Part II | Open |
| R8 | Track 17 allowlisted doc gaps | Ongoing |
