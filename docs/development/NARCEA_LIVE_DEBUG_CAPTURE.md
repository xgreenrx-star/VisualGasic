# Narcea Live Debug Capture — design spec (Phase A)

**Status:** Implemented (Phases A–D baseline)  
**Target:** **5.5.0-beta3** / current main  
**Owner:** Visual Gasic editor + debugger + Narcea  
**Related:** [TIER3_NARCEA_AGENT_DESIGN.md](TIER3_NARCEA_AGENT_DESIGN.md), [TODO_VG_DEBUGGING.md](TODO_VG_DEBUGGING.md), [ide_tools.md](../manual/ide_tools.md#ai-help-panel)

---

## Summary

Give **Narcea** (in-editor AI Pair) **read-only “eyes”** on a **locally running** VG game: viewport snapshots plus structured debug data over the existing **`visualgasic:`** debugger channel. Data stays **on the machine**, is **opt-in per debug session**, and is **wiped when the game stops** unless the user explicitly sends content to a cloud LLM via chat.

**Out of scope for Phase A:** synthetic click/type, continuous video, audio capture, cloud upload pipelines, OS-level automation.

---

## Goals

| Goal | Phase |
|------|--------|
| On breakpoint / exception / user action, attach **PNG snapshot** + **debug JSON** to Narcea context | A |
| **Explicit consent** UI + persistent in-session banner while capture is active | A |
| **Delete all session artifacts** on debug stop, game exit, plugin disable | A |
| Optional **MCP tools** on loopback (`8766`) mirroring read-only snapshot API | A (stretch) |
| UI tree + control geometry (VG property names) | B |
| Paused-only **inject pointer/key** for VG controls | C |
| Audio / video stream | D (defer) |

---

## Non-goals

- Recording the **Godot editor** chrome (only the **game viewport** unless user opts into “include editor” later).
- Capturing **other applications** or the desktop.
- Silent background capture while the game runs **without** a visible indicator.
- Storing captures in `res://` or committing them to git.
- Replacing the existing debugger UI (Immediate, Data Tips, tweak overlay).

---

## Privacy and consent (required for Phase A)

### Principles

1. **Opt-in per run** — default **off** at project and session level.
2. **Obvious indicator** — while capture is enabled and a game is running (or paused), show a **non-dismissible banner** in the Narcea / debugger area:  
   *“Narcea live capture: viewport snapshots and debug variables are stored locally for this session.”*
3. **Local-only storage** — ring buffer in **editor RAM**; optional spill to `user://vg_narcea_live_session/` (never `res://`).
4. **Automatic purge** on:
   - `debug_session_stopped`
   - game process exit / stop button
   - user **Clear capture data**
   - editor plugin disable / project close (best effort)
5. **Cloud models** — if the user sends a message to Claude/OpenAI/etc., the **provider’s** privacy policy applies to whatever the prompt includes; the UI must say: *“Sending to [provider] may include the latest snapshot if referenced in your message.”*
6. **No training claim** — we do not claim Narcea providers won’t log; we only control **local** retention.

### Settings (project)

| Key | Type | Default | Meaning |
|-----|------|---------|---------|
| `vg/narcea/live_debug_capture` | `bool` | `false` | Master enable: allows session opt-in UI. |
| `vg/narcea/live_debug_capture_max_frames` | `int` | `32` | Ring buffer size (PNG + metadata entries). |
| `vg/narcea/live_debug_capture_max_png_width` | `int` | `960` | Downscale width before encode (height proportional). |
| `vg/narcea/live_debug_capture_while_running` | `bool` | `false` | If false, capture only when **debugger paused** (recommended v1). |

### Session UI (editor)

- **Narcea panel:** checkbox **“Live debug capture (this run)”** — enabled only if project setting is on.
- **Debug toolbar / Immediate:** status chip **Capture: ON | OFF** + **Clear** button.
- First enable each session: small **AcceptDialog** with bullet list of what is collected and purge behavior; **Don’t ask again this project** optional (store `vg/narcea/live_debug_capture_consent` bool).

---

## Architecture

```
┌──────────────── Godot Editor ─────────────────┐
│  Narcea (vg_ai_help / vg_ai_narcea)          │
│       ↑ inject "live_debug_block" in prompt   │
│  VGNarceaLiveSession (new) — ring buffer    │
│       ↑ snapshots + JSON                    │
│  vg_debugger_plugin.gd                      │
│       │ visualgasic:capture_frame           │
│       │ visualgasic:ui_snapshot (phase B)   │
└───────┼─────────────────────────────────────┘
        │ EngineDebugger (existing)
┌───────▼──────── Running game ─────────────────┐
│  VGDebugHandler (autoload)                    │
│    - render viewport → PNG bytes              │
│    - reply on debug channel                   │
└───────────────────────────────────────────────┘
```

### Phase A — debugger messages (game → editor)

Extend **`VGDebugHandler`** (`addons/visual_gasic/vg_debug_handler.gd`) and **`vg_debugger_plugin.gd`**:

| Message | Direction | Payload | Notes |
|---------|-----------|---------|--------|
| `capture_frame` | Editor → game | `[quality_hint: int]` | Game renders main viewport to `Image`, PNG-encode, return. |
| `capture_frame_reply` | Game → editor | `[{ "png_b64": str, "w": int, "h": int, "ms": int }]` | Editor decodes to `Image`, stores in session. |
| `debug_context_bundle` | Editor (local) | N/A | Assembled in editor: file, line, stack, locals (reuse Data Tips / debugger plugin). |

**Trigger points (editor):**

- Existing: `_on_debug_break_navigate`, `_on_error_break_received` → enqueue snapshot if session capture ON.
- New: Narcea button **“Refresh snapshot”**.
- Optional: single shot on **Continue** (off by default).

**Rate limit:** max **1 capture per 500 ms** while paused; burst max **4** per break event.

### Phase A — `VGNarceaLiveSession` (new GDScript)

Suggested path: `addons/visual_gasic/vg_narcea_live_session.gd` (RefCounted or Node child of plugin).

Responsibilities:

- Ring buffer of `{ id, ts, png: Image, meta: Dictionary }`.
- `purge_all()`, `delete_older_than(seconds)`, `get_latest()`, `format_for_narcea(max_entries)`.
- Emit `session_purged` for UI.
- Spill to `user://vg_narcea_live_session/` **only if** PNG too large for RAM; delete tree on purge.

### Phase A — Narcea prompt integration

In `vg_ai_narcea.gd` / `vg_ai_help.gd`:

- If live session has entries and user enabled capture, append a **Live debug** section:
  - Latest frame: describe dimensions + **attach image only if provider supports vision** (Claude/Gemini/OpenAI vision models); otherwise OCR-free summary from `meta` only.
  - Stack + locals text from debugger (no secrets scrubbing v1 — user responsibility; document in consent).

New Narcea quick action: **“Explain what’s on screen at break”** → uses latest snapshot + top of stack.

### Phase A — MCP (stretch)

Add to `vg_mcp_server.gd` (loopback only):

| Tool | Args | Returns |
|------|------|---------|
| `narcea_live_list_snapshots` | `{}` | `[{ id, ts, file, line }]` |
| `narcea_live_get_snapshot` | `{ "id": int, "include_png_b64": bool }` | metadata + optional PNG |

Same session object as Narcea; no write tools.

---

## Phase B — structured UI (read-only)

- Reuse **tweak overlay** adapter scan (`vg_tweak_adapters.gd`) or add `visualgasic:ui_tree` returning flat list: `{ name, type, caption, left, top, width, height, visible }`.
- Attach to snapshot metadata; no PNG required for pure layout questions.

---

## Phase C — bidirectional input (future)

**Only while debugger paused** or explicit **“Narcea drive mode”** (hold-to-enable).

| Message | Risk | Mitigation |
|---------|------|------------|
| `inject_pointer_down/up` at viewport coords | Wrong target | Hit-test Control tree; VG forms only v1 |
| `inject_unicode` | Text injection | Require focused `LineEdit`/`TextEdit`; max length |

Not available for raw 3D viewport picking without VG control mapping.

---

## Phase D — audio / video (defer)

- Audio: bus tap → short WAV chunks → optional STT; separate privacy review.
- Video: not recommended for LLM cost; use **snapshot series** at events instead.

---

## Acceptance criteria — Phase A (ship gate)

1. With `vg/narcea/live_debug_capture = false`, no new UI and **zero** capture traffic.
2. With project setting **true**, user must still enable **this run**; banner visible while game running and capture ON.
3. Break on `.vg` line → within **2 s**, session contains ≥1 PNG + file/line + ≥1 stack frame in metadata.
4. **Stop game** → buffer empty; `user://vg_narcea_live_session/` removed if created.
5. **Clear** button empties buffer without stopping game.
6. Snapshot PNG width ≤ `live_debug_capture_max_png_width`; failure to capture does not break debugger.
7. No capture when game window is closed or debugger inactive.
8. Documented in [ide_tools.md](../manual/ide_tools.md#ai-help-panel) and this file.

---

## Implementation checklist (engineering)

- [x] Register project settings in `visual_gasic_plugin.gd` (`_register_project_setting`).
- [x] `VGNarceaLiveSession` + wire to `debugger_plugin.debug_session_stopped`.
- [x] `visualgasic:capture_frame` in `vg_debug_handler.gd` (game viewport).
- [x] Handler in `vg_debugger_plugin.gd` + call from break navigate / error paths.
- [x] Narcea UI: consent, banner, checkbox, **Refresh snapshot**, prompt block.
- [x] Vision gating: `AIProviders.provider_supports_vision()` in `vg_ai_providers.gd`.
- [x] Tests: `tests/test_vg_narcea_live_session.gd`; manual QA in `tests/manual/narcea_live_capture.md`.
- [x] MCP tools `narcea_live_list_snapshots` / `narcea_live_get_snapshot`.
- [x] Phase B: `visualgasic:ui_tree` flat control list.
- [x] Phase C: `inject_pointer` / `inject_unicode` (paused + drive mode).
- [x] Phase D: optional `capture_audio_chunk` via `AudioEffectRecord` (setting-gated).

---

## Manual QA script (abbreviated)

1. Enable project setting; start hex editor sample; F5 run.
2. Enable **Live capture this run**; confirm banner.
3. F9 breakpoint → break → Narcea **Explain screen** includes layout/vars reference.
4. Stop game → confirm buffer cleared (debug log or UI “0 frames”).
5. Cloud provider off → confirm no PNG in outbound request (network log / debug flag).

---

## Release notes blurb (for when Phase A ships)

> **Narcea Live Debug Capture (opt-in):** While debugging, Narcea can use **local viewport snapshots** and **debugger variables** to help explain UI and runtime state. Data is stored **only on your machine** and is **removed when the game stops**. Enable under Project Settings → Vg → Narcea and per-run in the AI Pair panel.

---

## Version note

Next public beta is **5.5.0-beta2** (VGasic workspace, debugger routing, IDE polish). **Narcea Live Debug Capture Phase A** is **not** required for that tag.
