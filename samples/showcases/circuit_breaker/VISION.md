# Circuit Breaker — where we are vs where we wanted to be

## What you originally asked for (Sep 2026)

From the thread that spawned this project:

- **Addictive, modern** game — not another QB port.
- **No custom graphics** from you; procedural / vector / code-drawn only.
- **Showcase** for VG 6.0 stable — something that could ship as a **Steam demo** and draw attention.
- **Portal-scale ambition** in *feel* (one clear verb, depth from rules) — not necessarily a clone.
- **Eye candy** — neon, glow, motion, “WOW” in a trailer frame.
- **Pure `.vg`** gameplay; Godot is shell + HDR/glow environment only.
- **Time-boxed** — you keep working on the engine; the game cannot eat months.

You also pasted a full **Circuit Breaker** spec (procgen PCB, components, enemies on wires, HDR bloom). We scoped a **vertical slice** to “see something” fast: one hand-made level, signal drain, flow combo, one moving short, resistor pickup.

Repo-wide, **`docs/showcase/plan.md`** already described a different flagship trio: **Vector Storm** (twin-stick), **Demoscene Intro**, **Vector Elite** — tuned for viral clips and engine limits.

## What exists today (honest)

| Intended | Today |
|----------|--------|
| Procgen runs | Single fixed `Grid.vg` layout |
| Multiple component types | One optional resistor |
| Enemies on traces | One environmental hazard (SHORT), no AI roster |
| HDR overdriven neon | Glow env yes; colors mostly 0–255, not “over 1.0” bloom push |
| Addictive loop | Core loop works but **teaching/readability** was weak; juice is thin |
| WOW trailer | Reads as **competent prototype**, not a Steam headliner |

**Circuit Breaker is a gameplay prototype and debugger stress test**, not the finished showcase. That is OK — we got stepping, canvas, JIT, and input fixed on it — but it is not the marketing asset yet.

## What “showcase” should mean (aligned with you)

1. **First 3 seconds** — unmistakable look (glow, motion, sound).
2. **First 30 seconds** — player understands the verb and wants one more run.
3. **First 5 minutes** — “this was made in Visual Gasic” is believable from IDE + `.vg` structure.
4. **Engine proof** — vector canvas, optional 3D lines, SoundGen, web export, tweak overlay — not all in one game, but the *hero* title hits several.

## Strategic fork (pick one hero for 6.0)

### Option A — **Vector Storm** (recommended hero for “WOW + addictive”)

From `docs/showcase/plan.md` Phase A.

- Twin-stick, 60 fps, particles + warping grid + chiptune reactive audio.
- Instant readability; clip-friendly; web-deployable.
- **Best match** for “modern arcade” and eye candy without art pipeline.
- Circuit Breaker ideas (trace-only movement, signal pressure) can become a **mode** or enemy theme later, not the whole product.

### Option B — **Demoscene Intro + playable Storm**

Phase B + trimmed A: 90s intro (torus, tunnel, plasma, 3D text) → “press space to play” → Vector Storm arena.

- Maximum **WOW** for launch video; less depth as a “game.”
- Good if Steam demo is secondary to YouTube / HN.

### Option C — **Evolve Circuit Breaker into the hero** (higher risk, more months)

Only if you want the **PCB fantasy** as the brand:

| Milestone | Content |
|-----------|---------|
| **C1 — Juice pass** (1–2 wk) | Overdriven colors, bus pulse shader via env, trail bloom, kill/win micro-shake, SoundGen tick + fuse sting |
| **C2 — One-minute loop** (1 wk) | Procgen small boards, 3 pickup types, 2 hazard types, clear win card |
| **C3 — Meta** (2 wk) | Run summary, unlocks, daily seed — roguelite stickiness |
| **C4 — Demo polish** (1 wk) | Title, pause, Steam capsule screenshots |

Needs procgen + content design; engine time stays bounded if C1–C2 are strict.

### Option D — **Vector Fathom lane** (already started in `samples/apps/vector_fathom`)

Pseudo-3D wire highway — closer to **OutRun / Elite** eye candy. Different vibe from grid PCB; strong if the wow is **depth and speed**, not puzzle roguelite.

## Recommendation

For **VG 6.0 stable + Steam demo + addictive + eye candy + your time**:

1. **Primary showcase:** **Vector Storm** (or Storm + 60s demoscene stinger).
2. **Keep Circuit Breaker** as **`samples/showcases/circuit_breaker/`** — secondary demo of grid logic, imports, roguelite tension; merge juice patterns from Storm (particles, warp grid, audio).
3. **Do not** try to make Circuit Breaker both the debugger harness and the Portal-tier hero without a dedicated **C1–C4** sprint.

## Next concrete step (when you say go)

1. You choose **A, B, C, or D** (or A + keep CB as side demo).
2. One **milestone checklist** with exit criteria (fps, clip, headless smoke, web build).
3. Implementation order: **input feel → one spectacle system (glow/particles/audio) → loop → menu/restart** — no new engine detours unless filed as bugs.

Labels removed from in-game board; win/lose copy on `FUSED` / `PIN LOCKED` stays.
