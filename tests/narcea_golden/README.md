# Narcea Golden Path Harness

Deterministic and (future) live tests for the M5 exit criterion:

> Describe a form in English → Narcea generates working VG code.

## Tiers

| Tier | Command | Network | What it proves |
|------|---------|---------|----------------|
| **A** | `bash scripts/run_narcea_golden.sh --tier A` | No | Spec extract → rubric → safe_write → lint + **chat-first form smoke** |
| **B** | `bash scripts/run_narcea_golden.sh --tier B` | No | Replay manifest scenarios in `recorded/manifest.json` (+ optional paired `.ndjson`) |
| **C** | `bash scripts/run_narcea_golden.sh --tier C` | Optional | Live Gemini + **multi-scenario suite** (`scenarios.json`) |

## Multi-scenario live suite (all providers)

[`scenarios.json`](scenarios.json) lists prompts + rubrics. Run offline (fixture replay) or live:

```bash
# CI-safe — replays fixture responses, no HTTP
NARCEA_LIVE=1 NARCEA_LIVE_SKIP_API=1 bash scripts/run_narcea_live_suite.sh

# Live Gemini
NARCEA_LIVE=1 NARCEA_PROVIDER=gemini NARCEA_GEMINI_KEY=... bash scripts/run_narcea_live_suite.sh

# Live Ollama (local)
NARCEA_LIVE=1 NARCEA_PROVIDER=ollama NARCEA_MODEL=qwen2.5-coder:7b bash scripts/run_narcea_live_suite.sh

# Live OpenAI / Claude
NARCEA_LIVE=1 NARCEA_PROVIDER=openai NARCEA_OPENAI_KEY=... NARCEA_MODEL=gpt-4o bash scripts/run_narcea_live_suite.sh
NARCEA_LIVE=1 NARCEA_PROVIDER=claude NARCEA_CLAUDE_KEY=... bash scripts/run_narcea_live_suite.sh

# Single scenario
NARCEA_SCENARIO=counter_form ...
NARCEA_SCENARIO=asteroids_2d ...    # video demo turn 1 (live)
NARCEA_SCENARIO=asteroids_iterate ... # video demo both turns (live, no fixtures yet)
```

**Video demo script:** [`DEMO_ASTEROIDS.md`](DEMO_ASTEROIDS.md) — copy-paste prompts, shot list, test commands.

Chat-first form synthesis smoke (no network):

```bash
bash scripts/run_narcea_form_smoke.sh
```

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

## Tier B — recorded replay

Replays every `tests/narcea_golden/recorded/*_response.txt` through the same pipeline as Tier A (spec extract → apply → rubric → lint). If a paired `*.ndjson` exists (same basename without `_response`), validates transcript shape for CI.

**CI fixture (no live API):**

- `recorded/fixture_counter_response.txt`
- `recorded/fixture_counter.ndjson`

**Run:**

```bash
bash scripts/run_narcea_golden.sh --tier B
```

### Recording a live agent run

1. Open `projects/vg_narcea_test` in the editor with Narcea agent mode enabled.
2. Paste the prompt from [`prompt.txt`](prompt.txt) and send.
3. After the run completes, copy the transcript:

```bash
bash scripts/copy_narcea_transcript.sh "VG Narcea Test" ollama_qwen_counter
```

This copies the latest NDJSON from Godot user data (`user://vg_agent_runs/`) and, when present, extracts `assistant_response.response` to `recorded/<scenario>_response.txt`.

4. Re-run Tier B to verify the capture.

**Transcript events** (written by `vg_ai_help.gd`):

| Event | Purpose |
|-------|---------|
| `session_start` | Provider, model, max hops |
| `user_prompt` | Full user text per hop |
| `assistant_response` | Full reply + `has_project_spec` flags |
| `tool_plan` | Read/mutating/blocked tool counts + `tools[]` detail (for agent graph replay) |
| `session_end` | Reason, hop/token totals |

## Files

```
tests/narcea_golden/
  prompt.txt
  rubric.json
  fixtures/
    golden_counter_project_spec.json
    golden_counter_response.txt
  recorded/
    manifest.json
    fixture_counter_response.txt   # Tier B CI fixture
    fixture_counter.ndjson
tests/test_narcea_golden_spec.gd
scripts/run_narcea_golden.sh
scripts/copy_narcea_transcript.sh
```

## Adding scenarios

1. Add `recorded/<provider>_<name>_response.txt` (and optional `.ndjson`).
2. Extend `rubric.json` or add scenario-specific rubric fields.
3. Document the scenario in `recorded/manifest.json`.

## Related

- [`tests/test_narcea_agent_loop.gd`](../test_narcea_agent_loop.gd) — provider/FC smoke (no apply)
- [`scripts/smoke_ai_specs.gd`](../../scripts/smoke_ai_specs.gd) — code/project spec round-trip
- [`docs/development/TIER3_NARCEA_AGENT_DESIGN.md`](../../docs/development/TIER3_NARCEA_AGENT_DESIGN.md)
