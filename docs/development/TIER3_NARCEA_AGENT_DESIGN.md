# Tier-3 Narcea Agent Mode — Design Pass

**Status:** Design / scoping document (no code changes yet).
**Author:** Copilot agent session, May 12, 2026.
**Target release window:** v5.3.x → v6.0.

---

## 1 · TL;DR

Tier-3 ("Narcea writes code + builds form + runs & iterates") is **already
~80 % implemented**.  The original roadmap entry in
[/memories/repo/visualgasic_todo.md](../../memories/repo/visualgasic_todo.md)
estimated ~2.5–3 weeks of greenfield work, but most of the plumbing landed
incidentally while shipping the lean-v1 spec builders and the Tier-2
Fix-with-AI dialog.  What remains is **polish, hardening, and one
genuinely new subsystem** — a model-native function-calling adapter.

This doc audits what's shipped, lists the concrete gaps, and proposes a
phased plan so the remaining work is closed in landable increments rather
than a single multi-week branch.

---

## 2 · Current state audit

| Sub-component (original spec) | File(s) | Status |
|---|---|---|
| Tool-call dispatcher | [addons/visual_gasic/vg_ai_tools.gd](../../addons/visual_gasic/vg_ai_tools.gd) (1123 lines) | ✅ Shipped — 16 tools incl. read/list/find/insert/replace/save/write/canonicalize, fenced ` ```vg-tool``` ` JSON protocol, 32-step undo stack |
| Tool registry / safety whitelist | [vg_ai_action_settings.gd](../../addons/visual_gasic/vg_ai_action_settings.gd), `READ_ONLY_TOOLS` + `MUTATING_TOOLS` in vg_ai_tools.gd | ✅ Shipped — per-action approval bar, file-size + path sandbox via vg_ai_safe_write.gd |
| Multi-step planner / agent loop | `_maybe_continue_agent_turn()` in [vg_ai_help.gd](../../addons/visual_gasic/vg_ai_help.gd#L2763), `_MAX_AGENT_HOPS = 3` | ⚠️ Partial — auto-continues only on pure-read turns; mutation→re-prompt is manual today |
| Test-and-iterate loop | [vg_ai_run_session.gd](../../addons/visual_gasic/vg_ai_run_session.gd) — `OS.execute_with_pipe` + line streaming + ring buffer | ⚠️ Partial — run output reaches the chat, but agent doesn't auto-loop after a run |
| Safety brake | hop cap (3), undo cap (32), file-size cap, path sandbox, action approval UI | ✅ Shipped — but caps are not user-configurable |
| Diff preview / accept-reject | [vg_ai_diff_dialog.gd](../../addons/visual_gasic/vg_ai_diff_dialog.gd) | ✅ Shipped |
| Spec appliers (form / code / project) | `vg_ai_form_spec.gd`, `vg_ai_code_spec.gd`, `vg_ai_project_spec.gd` | ✅ Shipped |
| Context provider | [vg_ai_narcea.gd](../../addons/visual_gasic/vg_ai_narcea.gd) (517 lines) | ✅ Shipped |

### What's actually missing

1. **Provider-native function-calling.**  We send tools as fenced JSON
   blocks in plain text.  This works on every backend (Ollama, OpenAI,
   Claude, Gemini) and is the right *lowest common denominator*, but it
   wastes tokens and the OpenAI/Claude/Gemini-native function-calling
   APIs would give better tool-call adherence on weaker models.  Need an
   adapter layer in [vg_ai_providers.gd](../../addons/visual_gasic/vg_ai_providers.gd).
2. **Mutation→run→inspect→edit loop.**  After a mutation turn the agent
   stops.  A genuine Tier-3 should: write code → invoke `play.run_main`
   → ingest stdout/stderr from `vg_ai_run_session.gd` → propose a patch
   if errors → loop until success or budget exhausted.  Today the user
   has to press Run and re-prompt by hand.
3. **`play.run_main` / `play.stop` tools.**  vg_ai_run_session.gd is
   wired to the "▶ Run" button but is not exposed as a tool the model
   can call.  Adding these two tool entries closes the loop above.
4. **Token / time budget.**  Hop cap = 3 is too low for multi-step
   refactors, and there's no aggregate token or wall-time guard.  Need a
   per-session "agent budget": max hops *or* max cumulative tokens *or*
   max wall-clock seconds.
5. **Agent-session UI.**  Today the agent stream is interleaved with the
   regular chat.  A "Agent run" mode would help: collapsible plan
   header, per-hop expandable details, big red "Abort" button while
   running.  Reuses existing chat panel components.
6. **Telemetry hook for `bench/ai_correctness/`.**  The benchmark already
   measures parse + compile; it should also score "did the agent reach a
   green run within N hops?"  Needs the agent loop to emit a
   machine-readable transcript file.
7. **Persona-gated activation.**  Tier-3 should only auto-run when the
   active persona is Narcea (or explicitly enabled in settings).  Other
   personas should still emit tool blocks but require human approval per
   turn.

---

## 3 · Non-goals

* Shell access, network access, package install — out of scope forever.
  All tool calls stay inside `res://` + `user://` + the per-user XDG AI
  config path, all routed through `vg_ai_safe_write.gd`.
* Multi-agent / swarm orchestration — single-agent only.
* Cloud-only features — Tier-3 must work end-to-end against local Ollama
  (qwen2.5-coder:7b minimum target).

---

## 4 · Phased plan

Each phase is sized so it can ship as one PR / one commit with the
700-test + 289-GD gate green.  No phase depends on the next.

### Phase 6a — Run-loop tool exposure (~1 day)

* Add `play.run_main` and `play.stop` to `vg_ai_tools.gd` (both gated as
  mutating, both require user approval by default).
* On `play.run_main` success, capture stdout/stderr via the existing
  run session and feed the first N lines back into the next-turn
  context (similar to read-result feedback that already exists).
* No new UI; reuses the action approval bar.

**Exit criteria:** Narcea, on request, can press its own Run button and
read the output back. Existing 700/700 gate still passes.

### Phase 6b — Mutation→run→ingest agent loop (~2 days)

* Generalize `_maybe_continue_agent_turn()` so that *after* a successful
  mutation turn the agent may continue if and only if it explicitly
  emitted a `play.run_main` call.  This avoids accidental infinite
  re-edit loops.
* Bump `_MAX_AGENT_HOPS` default to 6 and expose via a new
  `[ai] max_agent_hops` setting in the per-user AI config.
* Add `[ai] max_agent_tokens` (default 30 000) and
  `[ai] max_agent_seconds` (default 120) hard limits — first one to trip
  aborts the loop with a chat notice.

**Exit criteria:** the corpus test "build a counter form that prints
running totals on each click" succeeds end-to-end without manual
intervention against `gpt-4o-mini` or `claude-haiku-4-5`.

### Phase 6c — Provider-native function-calling (~3 days)

* New adapter file `addons/visual_gasic/vg_ai_function_calling.gd` that
  knows three dialects:
    * **OpenAI / Claude:** `tools=[{type:"function", function:{…}}]`
    * **Gemini:** `tools=[{functionDeclarations:[…]}]`
    * **Ollama:** `format="json"` with tool-call schema in system prompt
  * Translates a single shared tool registry into each dialect.
  * On response, normalizes either `tool_calls[]` (OpenAI/Claude),
    `functionCall` (Gemini), or raw fenced blocks (Ollama fallback)
    into the existing internal dispatch format.
* Keep the fenced-JSON path as a **fallback** so weak/unknown models
  still work.  Selection auto: if provider advertises function-calling
  support → use native; else fall back to fenced.
* No UI changes.

**Exit criteria:** `bench/ai_correctness/` shows ≥10 % tool-call
adherence improvement on local qwen2.5-coder:7b and ≥5 % on gpt-4o-mini.

### Phase 6d — Agent-session UI polish (~2 days)

* Collapsible "🤖 Agent plan" header inserted at the top of each agent
  multi-turn block in the chat log.  Per-hop expanders show tool log
  lines.
* Red "Abort agent" button (replaces the normal Send button) visible
  whenever `_agent_hops > 0` and the session is mid-loop.
* Wire abort to set a flag the run-session and tool dispatcher both
  check on entry.

**Exit criteria:** screenshot review; no test regressions.

### Phase 6e — Benchmark integration (~1 day)

* Emit an NDJSON transcript per agent run under
  `user://vg_agent_runs/<timestamp>.ndjson`.
* New harness `bench/ai_correctness/scripts/run_agent_loop.py` runs N
  prompts × M models and scores "green run within budget".
* Add the green-run metric to `bench/ai_correctness/REPORT.md`.

**Exit criteria:** report can be regenerated headlessly via the new
harness.

### Phase 6f — Persona gating + settings UI (~1 day)

* Settings panel: "Agent mode" dropdown (off / Narcea only / all
  personas / always-ask).  Default = Narcea only.
* If gated off, fenced tool blocks still appear in chat but execute
  nothing — the approval bar is the only way to run them.

**Exit criteria:** non-Narcea persona cannot trigger auto-mutation in
the default configuration.

---

## 5 · Risks & mitigations

| Risk | Mitigation |
|---|---|
| Local 7B models hallucinate tool names | Strict JSON-schema validation in `vg_ai_function_calling.gd`; invalid calls degrade to `_invalid` (already read-only) |
| Long agent runs lock the editor | All tool dispatch is already on Godot's main thread via short-lived calls; run sessions are subprocesses; the new `max_agent_seconds` hard cap covers wall-time runaway |
| User abandons a mid-run agent | Abort button + automatic stop on panel close + `vg_ai_run_session.stop()` already kills child via `OS.kill` |
| Quota burn against cloud APIs | Token budget cap + an opt-in "estimated cost" line printed on each agent-turn header |
| Confusing chat UX during multi-turn runs | Phase 6d's collapsible plan block; user can collapse to a one-line summary |

---

## 6 · Success metrics for v6.0 Tier-3 GA

1. **Local-model floor:** qwen2.5-coder:7b completes ≥30 % of the
   Tier-3 corpus tasks without human intervention.
2. **Cloud-model ceiling:** claude-sonnet-4-5 or gpt-4o completes ≥80 %
   of the Tier-3 corpus tasks.
3. **Safety:** zero observed file writes outside the sandbox in a
   100-prompt fuzz run.
4. **Latency:** median agent-turn round-trip ≤8 s against local Ollama
   on the reference workstation (Intel ADL GT2 + RTX-class GPU
   present).
5. **Bench gate:** `bench/ai_correctness/` green-run metric reported
   in the v6.0 release notes.

---

## 7 · Open questions (track these in `visualgasic_todo.md`)

1. Should the run-loop ingest *all* of stdout/stderr or only the last N
   lines?  Long verbose programs will eat the context window.  Tentative
   answer: tail-1024-lines + a "[truncated]" marker.
2. Do we need a per-project tool whitelist (e.g. disable
   `vb6_canonicalize` on .NET-bound projects)?  Defer.
3. Function-calling for Ollama: stay on `format=json`, or move to
   tool-calling-trained models (qwen2.5-coder has it natively)?  Pick
   per-model in `vg_ai_function_calling.gd`.
4. Telemetry opt-in: NDJSON transcripts default to local-only.  No
   network upload unless the user explicitly enables the benchmark
   harness.

---

## 8 · Where this slots into the roadmap

* **v5.3.0** — ship Phase 6a + 6b (close the run/edit loop).
* **v5.4.0** — ship Phase 6c (native function-calling) + Phase 6e (bench
  integration).
* **v6.0** — ship Phase 6d (UI polish) + Phase 6f (persona gating); cut
  GA when the success metrics above are met.

No changes to ROADMAP.md from this design pass — the milestones land
when each phase actually ships.
