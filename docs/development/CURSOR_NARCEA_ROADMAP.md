# Cursor + Narcea integration roadmap

Plan for pairing Visual Gasic AI Pair (Narcea) with [Cursor](https://cursor.com) Composer.
Tracks what shipped, what is next, and suggested priority.

**Status key:** ✅ Done · 🔄 In progress · 📋 Planned

---

## Architecture (three tiers)

| Tier | Feature | Status | When to use |
|------|---------|--------|-------------|
| **0** | Narcea + Ollama / Gemini / DeepSeek | ✅ | Default; free/local; full VG prompt |
| **1** | **↗ Cursor** handoff | ✅ | Full Cursor IDE + Composer; multi-file refactors |
| **2** | **⬡ Cursor (Composer)** provider | ✅ | Composer inside Godot AI Pair panel |

---

## Phase 1 — Foundation ✅ (Aug 2026)

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1.1 | Tier 1 handoff (`vg_cursor_handoff.gd`) | ✅ | `.vg/cursor_handoff.md`, clipboard, `cursor` CLI |
| 1.2 | Tier 2 SDK provider | ✅ | `vg_cursor_agent.py`, `vg_ai_cursor_session.gd` |
| 1.3 | Project rules (`.cursor/rules/visual-gasic-godot.mdc`) | ✅ | Godot/GDScript/VG conventions |
| 1.4 | Godot headless validation rule | ✅ | `godot-gdscript-validation.mdc` |
| 1.5 | **MCP auto-config** | ✅ | `vg_cursor_mcp_config.gd` → `.cursor/mcp.json` |
| 1.6 | **Slim Cursor prompt** | ✅ | `build_slim_context_block()` — skips tutorial index |

---

## Phase 2 — UX polish ✅ (Aug 2026)

| # | Item | Status | Notes |
|---|------|--------|-------|
| 2.1 | **Provider health panel** in ⚙️ API keys dialog | ✅ | python3, cursor-sdk, API key, MCP, CLI |
| 2.2 | **↗ Continue in Cursor** after Tier 2 long replies | ✅ | Tip + button highlight after long Composer reply |
| 2.3 | **Smarter handoff clipboard** (task type, file list, last reply excerpt) | ✅ | Mode inference + last assistant excerpt |
| 2.4 | **`.vg/cursor_handoff.md` in `.gitignore`** | ✅ | Session scratch; avoid accidental commits |
| 2.5 | **Model tooltips** (`composer-2.5` vs `-fast` billing) | ✅ | Clarify SDK fast-tier default |
| 2.6 | **Two-tier docs table** in `docs/manual/ide_tools.md` | ✅ | When to use Narcea vs Tier 1 vs Tier 2 |

---

## Phase 3 — Agent loop safety ✅ (Aug 2026)

| # | Item | Status | Notes |
|---|------|--------|-------|
| 3.1 | **Disable auto vg-tool hops** when Cursor provider active | ✅ | Skips dispatch unless opt-in setting enabled |
| 3.2 | Project setting `vg/ai/cursor_allow_vg_tools` | ✅ | Default false — opt-in to Narcea tools with Cursor |
| 3.3 | **Validate** button → headless Godot parse check | ✅ | `vg_ai_validate.gd` — same filters as `ci_smoke.sh` |

---

## Phase 4 — Deeper Cursor integration 📋

| # | Item | Effort | Value |
|---|------|--------|-------|
| 4.1 | **`Agent.resume()` session** — continue last Cursor run in-panel | ~2 d | True multi-turn Composer without resending history |
| 4.2 | **`scripts/install_cursor_sdk.sh`** | ~0.25 d | Mirror `install_whisper.sh` pattern |
| 4.3 | Welcome shell: Cursor in provider list (not default) | ~0.5 d | Opt-in at project creation |
| 4.4 | Cursor CLI `--add-mcp` fallback when `mcp.json` merge fails | ~0.25 d | Secondary path for MCP registration |
| 4.5 | Image attach for Cursor provider | ~1 d | When SDK supports vision for Composer |

---

## Phase 5 — Optional / later 📋

| # | Item | Notes |
|---|------|-------|
| 5.1 | Narcea default → Cursor for power users only | EditorSettings toggle, never global default |
| 5.2 | Team-shared `.cursor/mcp.json` in template projects | Commit MCP entry; document Godot must run |
| 5.3 | MCP health ping in status bar | GET `/health` on :8766 when plugin active |

---

## MCP setup (reference)

Auto-config writes:

```json
{
  "mcpServers": {
    "visual-gasic": {
      "url": "http://127.0.0.1:8766/mcp"
    }
  }
}
```

**User steps after auto-config:**

1. Godot running with Visual Gasic enabled (MCP listens on loopback).
2. Cursor → **Settings → Tools & MCP** → enable **visual-gasic**.
3. Confirm tools: `read_file`, `write_file`, `list_dir`, `find_in_files`, `apply_diff`.

Triggered when:

- Clicking **↗ Cursor** (Tier 1 handoff)
- First successful activation of **⬡ Cursor (Composer)** provider

---

## Slim vs full Narcea prompt

| Block | Full (Ollama, etc.) | Slim (Cursor provider + handoff) |
|-------|---------------------|----------------------------------|
| Active file / panel | ✅ | ✅ |
| Pinned files / user notes | ✅ | ✅ |
| Full KNOWLEDGE + AGCK catalog | ✅ | ❌ |
| Tutorial index | ✅ | ❌ |
| `.cursor/rules` pointer | — | ✅ |

Composer already has repo context; slim mode cuts tokens and cost.

---

## Suggested implementation order

1. ~~Phase 2 + 3~~ ✅ (Aug 2026)
2. Phase 4.1 session resume
3. Phase 4.2 install script + welcome shell Cursor option
4. Phase 5 optional items

---

## Files (reference)

| File | Role |
|------|------|
| `addons/visual_gasic/vg_cursor_handoff.gd` | Tier 1 |
| `addons/visual_gasic/vg_cursor_mcp_config.gd` | MCP `.cursor/mcp.json` |
| `addons/visual_gasic/vg_ai_cursor_session.gd` | Tier 2 subprocess |
| `addons/visual_gasic/scripts/vg_cursor_agent.py` | cursor-sdk bridge |
| `addons/visual_gasic/vg_ai_narcea.gd` | `build_slim_context_block()` |
| `addons/visual_gasic/vg_ai_validate.gd` | Headless parse check (Validate button) |
| `addons/visual_gasic/vg_ai_provider_health.gd` | Cursor readiness in ⚙️ dialog |
