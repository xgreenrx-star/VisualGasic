# Narcea Golden Path Harness

Deterministic and (future) live tests for the M5 exit criterion:

> Describe a form in English → Narcea generates working VG code.

## Tiers

| Tier | Command | Network | What it proves |
|------|---------|---------|----------------|
| **A** | `bash scripts/run_narcea_golden.sh --tier A` | No | Spec extract → rubric → safe_write → lint (golden fixture) |
| **B** | `--tier B` *(planned)* | No | Replay recorded NDJSON agent transcript |
| **C** | `--tier C` *(planned)* | Yes | Live Claude / Ollama against golden prompt |

## Tier A — golden counter form

**Prompt:** [`prompt.txt`](prompt.txt)

**Fixture:** [`fixtures/golden_counter_response.txt`](fixtures/golden_counter_response.txt) — simulated LLM reply with a `vg-project-spec` block.

**Rubric:** [`rubric.json`](rubric.json) — machine-checkable control names, handler subs, VG patterns, lint severity.

**Run:**

```bash
bash scripts/run_narcea_golden.sh --tier A
```

Also invoked from `./run_test_suite.sh` (GDScript phase).

### What Tier A does *not* cover (yet)

- Form Designer `.tscn` materialisation (headless: `designer=null`, forms skipped by design)
- Live LLM adherence
- `play.run_main` agent loop

Those are Tier B/C and Phase 4.1 (headless tscn stub) on the roadmap.

## Files

```
tests/narcea_golden/
  prompt.txt
  rubric.json
  fixtures/
    golden_counter_project_spec.json
    golden_counter_response.txt
  recorded/          # Tier B — add NDJSON captures here (optional git LFS)
tests/test_narcea_golden_spec.gd
scripts/run_narcea_golden.sh
```

## Adding scenarios

1. Copy `fixtures/golden_counter_*` with a new name.
2. Extend `rubric.json` or add `rubric_<scenario>.json`.
3. Add a test section in `test_narcea_golden_spec.gd` or parameterise by env `NARCEA_GOLDEN_SCENARIO`.

## Related

- [`tests/test_narcea_agent_loop.gd`](../test_narcea_agent_loop.gd) — provider/FC smoke (no apply)
- [`scripts/smoke_ai_specs.gd`](../../scripts/smoke_ai_specs.gd) — code/project spec round-trip
- [`docs/development/TIER3_NARCEA_AGENT_DESIGN.md`](../../docs/development/TIER3_NARCEA_AGENT_DESIGN.md)
