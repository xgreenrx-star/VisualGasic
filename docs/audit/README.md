# Reference audit

Tier 0 static checks that Programmer's Reference claims match engine dispatch sites.

## Run locally

```bash
# Full report (exit 1 if any missing dispatch)
python3 scripts/audit_reference_dispatch.py --write-report

# CI / gate mode (writes report, does not fail the build yet)
python3 scripts/audit_reference_dispatch.py --write-report --warn-only

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

## Enabling strict CI

When missing dispatch count reaches zero, remove `--warn-only` from `scripts/run_command_reference_gate.sh`.
