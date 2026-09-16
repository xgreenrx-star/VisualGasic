# Brotato VG — Port Status

**Status: v1.0 COMPLETE (2026-09-15)** — 2D OG port frozen. Continuation: [`samples/games/brotato3d`](../brotato3d/) (Plan A, Kenney 3D).

Source: [BLXCKBXXST/brotato-mini](https://github.com/BLXCKBXXST/brotato-mini) (~2,033 LOC GDScript, 14 scripts, 8 scenes).

Legend: **done** | **in progress** | **not started** | **blocked**

## Autoloads

| GDScript | VG file | Status | Notes |
|----------|---------|--------|-------|
| `GameManager.gd` | `scripts/GameManager.vg` | done | Full combat/shop API; English names in weapon defs; shop item set trimmed (5 accessories vs 10) |
| `AudioBus.gd` | `scripts/AudioBus.vg` | done | MP3 load only; no procedural fallback tones |

## Scene scripts

| GDScript | VG file | Status | Notes |
|----------|---------|--------|-------|
| `Main.gd` | `scripts/Main.vg` | done | Title, wave loop, pause, character grid (simplified cards) |
| `Player.gd` | `scripts/Player.vg` | done | Movement, auto-fire, damage |
| `WaveManager.gd` | `scripts/WaveManager.vg` | done | Uses `SpawnWarning.tscn` instead of inline class |
| `HUD.gd` | `scripts/HUD.vg` | done | |
| `Enemy.gd` | `scripts/Enemy.vg` | done | Boss AI; hit-flash + hurt feedback |
| `Bullet.gd` | `scripts/Bullet.vg` | done | |
| `Drop.gd` | `scripts/Drop.vg` | done | |
| `EnemyBullet.gd` | `scripts/EnemyBullet.vg` | done | |
| `FloatText.gd` | `scripts/FloatText.vg` | done | |
| `HitParticle.gd` | `scripts/HitParticle.vg` | done | |
| `SpawnWarning.gd` | `scripts/SpawnWarning.vg` | done | `_Draw` + `RaiseEvent finished` |
| `Shop.gd` | — | done (GDScript) | Functional shop; port to `.vg` deferred to brotato3d era if needed |

## Scenes

| Scene | Status | Script |
|-------|--------|--------|
| `scenes/Main.tscn` | done | Mixed `.vg` + `Shop.gd` |
| `scenes/Bullet.tscn` | done | `Bullet.vg` |
| `scenes/Enemy.tscn` | done | `Enemy.vg` |
| `scenes/Drop.tscn` | done | `Drop.vg` |
| `scenes/EnemyBullet.tscn` | done | `EnemyBullet.vg` |
| `scenes/FloatText.tscn` | done | `FloatText.vg` |
| `scenes/HitParticle.tscn` | done | `HitParticle.vg` |
| `scenes/SpawnWarning.tscn` | done | `SpawnWarning.vg` |

## Boot / combat / shop

| Flow | Status |
|------|--------|
| Boot → title screen | done (VG Main) |
| Character select + Start | done |
| Combat loop (move, auto-shoot, waves, enemies) | done |
| HUD | done |
| Shop between waves | partial — opens via GDScript `Shop.gd`; buy/sell/combine works |
| Combat juice (trails, muzzle, sparkles, shake, spawn ring) | done — juice pass 2 (2026-09-15) |
| Game over / win | done |

## Known gaps (not engine bugs)

- Shop UI still GDScript — port blocked on effort, not VM capability.
- Character cards simplified vs upstream (no weapon/modifier detail labels).
- AudioBus: no procedural sfx when MP3 missing.
- GameManager `SHOP_ITEMS` subset only (full 10 accessories not yet copied).

## VG engine issues

### Dictionary-in-Array subscript — **fixed** (2026-09-14)

Parser now allows chained `(` subscripts on expression results (`WEAPON_DEFS(i)("id")`). Previously misparsed trailing `("key")` and could emit Error 35 on parameter names (e.g. `defId` in `GetWeaponDef`).

Regression: `test_proj/test_suite/test_dict_in_array.vg`.

This port still uses parallel arrays for character cards (simplified UI); can migrate to dict-in-array when convenient.

### Object / dictionary subscript — **fixed** (2026-09-14)

`weapon("def_id")` on `As Object` params (Dictionary-backed instances) raised Error 5. VM/AST now resolve dictionary keys on `Variant::OBJECT` and VG class instance ids.

Regression: `test_proj/test_suite/test_object_dict_access.vg`.

### Module `ReDim` arrays on `Extends Node` autoload

**Repro:** `Public CharIds() As String` + `ReDim` + `CharIds(i) = ...` on autoload script (`GameManager.vg`).

**Observed:** `Unsupported array assignment base` / `CharIds` not resolved as array.

**Workaround:** Use Godot `Array()` + `.append()` for autoload-scoped lists.
