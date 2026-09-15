# Brotato 3D — Port Status

Parent: frozen 2D OG [`projects/brotato_vg`](../brotato_vg/PORT_STATUS.md) (v1.0 complete).

Legend: **done** | **in progress** | **not started** | **blocked**

## Milestones

| Phase | Scope | Status |
|-------|--------|--------|
| **0** | Project scaffold, Node3D arena, Player3D movement, smoke | done |
| **1** | Kenney blocky GLTF player + walk `AnimationPlayer` | done |
| **2** | Enemies (4 skins), WaveManager3D, spawn ring | done |
| **3** | Area3D bullets, combat, drops, juice (port from OG) | done |
| **4** | HUD + shop + title/game-over (reuse GameManager API) | done |
| **5** | Polish — shadows, sfx, bullet visibility | in progress |

## Reused from brotato_vg (logic)

| File | Status |
|------|--------|
| `GameManager.vg` | copied — autoload stats/weapons/waves |
| `AudioBus.vg` | copied — copy `assets/audio/` from OG when needed |

## New 3D scripts

| Script | Status | Notes |
|--------|--------|-------|
| `Main.vg` | Phase 0 | `Node3D` root, boot fight slice |
| `Player3D.vg` | done | Kenney GLTF, walk/idle, auto-fire |
| `Enemy3D.vg` | done | Seek player, 4 skins + bosses, contact dmg |
| `WaveManager3D.vg` | done | Offscreen XZ spawn, boss waves |
| `Bullet3D.vg` | done | `Area3D` distance hits |
| `SpawnWarning3D.vg` | done | Ground ring pulse |
| `Drop3D.vg` | done | Magnetize + collect on XZ |
| `VfxHelpers3D.vg` | done | Muzzle, hit pop, pickup burst |
| `HitParticle3D.vg` | done | Death burst |
| `FloatText3D.vg` | done | `Label3D` damage numbers |
| `EnemyBullet3D.vg` | done | Boss triple-shot |

## VG 3D issues to watch

Track bugs here as we hit them (fix in `src/` + regression test):

- [x] `Animation.Play` on imported GLTF `AnimationPlayer` — walk/idle OK (character-a)
- [x] `global_position` / `Vector3` arithmetic in hot paths
- [x] `GetTree().get_nodes_in_group` with 3D nodes
- [x] `Load` + `instantiate` on `.gltf` / `.scn` character scenes
- [x] Mixed 2D HUD (`CanvasLayer`) + 3D world
- [x] `Label3D` + `lerp` on Vector3 (boss dash)

Reference demo: `demos/3D_Games/Squash_The_Creeps/`
