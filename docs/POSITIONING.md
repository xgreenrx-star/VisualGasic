# Visual Gasic — public positioning (v6.0)

This doc is the **source of truth** for how we describe VG outside the repo. It supersedes older hero copy that led with “AI auditing” or “BASIC for the AI era” alone.

## Hero (one sentence)

**Visual Gasic is a second language for Godot: game rules, UI, and tools—with power GDScript doesn’t ship, on plain `Sub` / `If` / `Dim` control flow.**

## Who it’s for

- Godot developers who keep **GDScript for glue** and want **structure + performance + IDE depth** for gameplay, UI, and companion tools.
- Teams shipping **games plus in-engine tools** (editors, dashboards, HTTP-backed panels) without splitting to C#.
- People who **vibe code** with Narcea or external assistants—but **verify** against docs, tests, and the running game.

We do **not** claim VG is the easiest first language vs GDScript for the median YouTube-tutorial learner. We claim **measurable wins on specific tasks** (see [Proof](#proof-we-owe-the-audience)).

## Pillars (order matters)

1. **Game systems on Godot** — AGCK, Working Nodes, demos, benchmarks, 2D/3D pipeline. Games are the flagship proof.
2. **Power layer** — Features Godot rejected for GDScript (Try/Catch, overloading, packages, threading story, ECS, JIT path). See [COMPETITIVE_ADVANTAGES.md](COMPETITIVE_ADVANTAGES.md).
3. **Plain control flow** — Not “retro BASIC”; **explicit blocks and handler names** for logic you can review and test. VB6 *compatibility* is a migration path, not the brand.
4. **Vibe Code (in-editor)** — Narcea + providers + Cursor handoff. **Accelerator**, not the product name. Panel tab: **Vibe Code** (`Ctrl+Shift+N`).

## Words to use / avoid

| Prefer | Avoid as hero |
|--------|----------------|
| Game systems, Godot, tools + games | “Another scripting language” |
| Second language alongside GDScript | “Replace GDScript” |
| Plain / explicit control flow | “Readable” (subjective) |
| Vibe Code, Narcea | “AI Pair” (old name; renamed) |
| Proof, benchmarks, test suite | “AI era needs BASIC” alone |
| Future-facing (web beta, packages) | Retro nostalgia |

## Proof we owe the audience

Ship and link:

- Side-by-side **GDScript vs VG** mini-projects (UI click → handler, HTTP fetch, simple loop game).
- Published **benchmarks** (already: 12/12 compute, 9/9 draw).
- **Regression tests** (`.vg` suite) as quality signal.
- **Two demos minimum on every landing refresh:** one game, one tool (e.g. hex editor, Climatist POC).

## Related docs

- [PLATFORM_SUPPORT.md](manual/PLATFORM_SUPPORT.md) — desktop vs web
- [manifesto.md](manifesto.md) — optional deep essay on auditing (not the storefront hero)
- [VG_ADVANTAGES_OVER_GDSCRIPT.md](guides/VG_ADVANTAGES_OVER_GDSCRIPT.md) — feature inventory
