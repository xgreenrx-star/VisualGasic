#!/usr/bin/env python3
"""
Generate a 4-level Super-Mario-like AGCK project file with sound effects.

Output: game_projects/AGCK_Tests/super_mario_like.agck

Block-type codes used:
    0 = empty
    1 = barrier (solid ground/brick)
    2 = ladder
    3 = deadly (lava / pit floor)
    5 = teleport
    7 = goal (flagpole)

Actor IDs (must match the order of `actors[]` in the project):
    0 Hero    (Player)
    1 Goomba  (Drone, patrol)
    2 Coin    (Computer pickup)
    3 Mushroom (Computer pickup, power-up)
    4 Flag    (Computer goal marker)
"""
from __future__ import annotations
import json, os, sys

GW, GH = 20, 12          # 20 wide × 12 tall (default AGCK grid)
GROUND = GH - 1          # bottom row index = 11

def empty_grid(w: int = GW, h: int = GH) -> list:
    return [[{"block_type": 0, "tile_index": 0} for _ in range(w)] for _ in range(h)]

def put(grid, x, y, bt, ti=0):
    if 0 <= y < len(grid) and 0 <= x < len(grid[0]):
        grid[y][x] = {"block_type": bt, "tile_index": ti}

def hline(grid, y, x0, x1, bt=1):
    for x in range(x0, x1 + 1):
        put(grid, x, y, bt)

def empty_level(num: int, name: str) -> dict:
    return {
        "name": name,
        "grid": empty_grid(),
        "grid_w": GW,
        "grid_h": GH,
        "actors": [],
        "block_paths": {},
        "material_friction": 60,
        "material_elasticity": 0,
        "death_action": "Restart Level",
        "death_action_target": 1,
    }

# ── Level 1-1: Tutorial flats ──────────────────────────────
def level_1():
    L = empty_level(1, "World 1-1")
    g = L["grid"]
    hline(g, GROUND, 0, GW - 1)            # floor
    hline(g, 8, 6, 9)                       # mid platform
    hline(g, 6, 12, 14)                     # higher platform
    put(g, GW - 2, GROUND - 1, 7)          # goal flag
    L["actors"] = [
        {"actor_id": 0, "x": 1,  "y": GROUND - 1, "path": []},   # Hero
        {"actor_id": 2, "x": 7,  "y": 7, "path": []},            # Coin
        {"actor_id": 2, "x": 8,  "y": 7, "path": []},            # Coin
        {"actor_id": 2, "x": 13, "y": 5, "path": []},            # Coin
        {"actor_id": 1, "x": 11, "y": GROUND - 1, "path": []},   # Goomba
        {"actor_id": 4, "x": GW - 2, "y": GROUND - 2, "path": []},
    ]
    return L

# ── Level 1-2: Pits & two enemies ──────────────────────────
def level_2():
    L = empty_level(2, "World 1-2")
    g = L["grid"]
    # ground with two pits
    for x in range(GW):
        if x in (8, 9, 14, 15):
            put(g, x, GROUND, 3)           # deadly pit
        else:
            put(g, x, GROUND, 1)
    hline(g, 8, 7, 10)                      # bridge over first pit
    hline(g, 6, 13, 16)                     # bridge over second pit (higher)
    hline(g, 4, 2, 4)                       # left ledge w/ coin
    put(g, GW - 1, GROUND - 1, 7)          # goal
    L["actors"] = [
        {"actor_id": 0, "x": 1,  "y": GROUND - 1, "path": []},
        {"actor_id": 2, "x": 3,  "y": 3, "path": []},
        {"actor_id": 2, "x": 8,  "y": 7, "path": []},
        {"actor_id": 2, "x": 9,  "y": 7, "path": []},
        {"actor_id": 2, "x": 14, "y": 5, "path": []},
        {"actor_id": 2, "x": 15, "y": 5, "path": []},
        {"actor_id": 1, "x": 5,  "y": GROUND - 1, "path": []},
        {"actor_id": 1, "x": 17, "y": GROUND - 1, "path": []},
        {"actor_id": 3, "x": 14, "y": 5, "path": []},            # Mushroom
        {"actor_id": 4, "x": GW - 1, "y": GROUND - 2, "path": []},
    ]
    return L

# ── Level 1-3: Climbing & ladders ──────────────────────────
def level_3():
    L = empty_level(3, "World 1-3")
    g = L["grid"]
    hline(g, GROUND, 0, GW - 1)
    # Stair-step platforms going up
    hline(g, 9, 3, 5)
    hline(g, 7, 7, 9)
    hline(g, 5, 11, 13)
    hline(g, 3, 15, GW - 1)
    # Ladder from ground to top platform
    for y in range(4, GROUND):
        put(g, 17, y, 2)                    # ladder column
    # Coins clustered near each platform
    for x, y in [(4, 8), (8, 6), (12, 4), (16, 2), (17, 2), (18, 2)]:
        put(g, x, y, 0)                     # ensure empty above platform
    put(g, GW - 2, 2, 7)                    # goal at top
    L["actors"] = [
        {"actor_id": 0, "x": 1,  "y": GROUND - 1, "path": []},
        {"actor_id": 2, "x": 4,  "y": 8, "path": []},
        {"actor_id": 2, "x": 8,  "y": 6, "path": []},
        {"actor_id": 2, "x": 12, "y": 4, "path": []},
        {"actor_id": 2, "x": 16, "y": 2, "path": []},
        {"actor_id": 1, "x": 4,  "y": 8, "path": []},
        {"actor_id": 1, "x": 12, "y": 4, "path": []},
        {"actor_id": 3, "x": 8,  "y": 6, "path": []},            # Mushroom
        {"actor_id": 4, "x": GW - 2, "y": 1, "path": []},
    ]
    return L

# ── Level 1-4: Castle (lava + goal) ────────────────────────
def level_4():
    L = empty_level(4, "World 1-4 — Castle")
    g = L["grid"]
    # Lava floor
    hline(g, GROUND, 0, GW - 1, 3)
    # Stone islands above lava
    hline(g, GROUND - 1, 0, 2, 1)
    hline(g, GROUND - 1, 5, 7, 1)
    hline(g, GROUND - 1, 10, 12, 1)
    hline(g, GROUND - 1, 15, GW - 1, 1)
    # Floating brick platforms
    hline(g, 7, 3, 4, 1)
    hline(g, 5, 8, 9, 1)
    hline(g, 7, 13, 14, 1)
    # Side walls (castle interior)
    for y in range(0, GH):
        put(g, 0, y, 1)
        put(g, GW - 1, y, 1)
    # Coins on the brick platforms
    # Goal flag on the rightmost island
    put(g, GW - 2, GROUND - 2, 7)
    L["actors"] = [
        {"actor_id": 0, "x": 1,  "y": GROUND - 2, "path": []},
        {"actor_id": 2, "x": 3,  "y": 6, "path": []},
        {"actor_id": 2, "x": 4,  "y": 6, "path": []},
        {"actor_id": 2, "x": 8,  "y": 4, "path": []},
        {"actor_id": 2, "x": 9,  "y": 4, "path": []},
        {"actor_id": 2, "x": 13, "y": 6, "path": []},
        {"actor_id": 1, "x": 6,  "y": GROUND - 2, "path": []},
        {"actor_id": 1, "x": 11, "y": GROUND - 2, "path": []},
        {"actor_id": 1, "x": 16, "y": GROUND - 2, "path": []},
        {"actor_id": 4, "x": GW - 2, "y": GROUND - 3, "path": []},
    ]
    return L

# ── Sounds (the 8 standard presets — full preset payloads) ─
NUM_NOTES = 16

def _empty_notes():
    return [0] * NUM_NOTES

def _make_sound(name, tempo=120, v1_wave=0, v1_vol=0, v1_notes=None,
                v2_enabled=False, v2_wave=0, v2_vol=0, v2_notes=None,
                filt_enabled=False, filt_type=0, filt_q=0, filt_notes=None):
    return {
        "name": name,
        "tempo": tempo,
        "voice1_enabled": True,
        "voice1_wave": v1_wave,
        "voice1_volume": v1_vol,
        "voice1_notes": v1_notes or _empty_notes(),
        "voice2_enabled": v2_enabled,
        "voice2_wave": v2_wave,
        "voice2_volume": v2_vol,
        "voice2_notes": v2_notes or _empty_notes(),
        "filter_enabled": filt_enabled,
        "filter_type": filt_type,
        "filter_q": filt_q,
        "filter_notes": filt_notes or _empty_notes(),
    }

def _notes_from(pairs):
    n = _empty_notes()
    for i, v in pairs:
        if 0 <= i < NUM_NOTES:
            n[i] = v
    return n

SOUNDS = [
    _make_sound("Jump", tempo=240, v1_wave=1, v1_vol=75,
                v1_notes=_notes_from([(0,12),(1,18),(2,24),(3,30),(4,36),(5,40),(6,44),(7,48)])),
    _make_sound("Coin", tempo=280, v1_wave=0, v1_vol=70,
                v1_notes=_notes_from([(0,30),(1,30),(3,42),(4,42)]),
                v2_enabled=True, v2_wave=1, v2_vol=40,
                v2_notes=_notes_from([(0,18),(1,18),(3,30),(4,30)])),
    _make_sound("Hit", tempo=260, v1_wave=3, v1_vol=80,
                v1_notes=_notes_from([(0,36),(1,28),(2,16),(3,8)]),
                filt_enabled=True, filt_type=1, filt_q=40,
                filt_notes=_notes_from([(0,30),(1,20),(2,12),(3,6)])),
    _make_sound("Hero Death", tempo=160, v1_wave=0, v1_vol=80,
                v1_notes=_notes_from([(i, 36-2*i) for i in range(16)]),
                v2_enabled=True, v2_wave=3, v2_vol=30,
                v2_notes=_notes_from([(i, 20-2*i) for i in range(9)])),
    _make_sound("Enemy Death", tempo=280, v1_wave=3, v1_vol=75,
                v1_notes=_notes_from([(0,40),(1,30),(2,18),(3,8),(4,4)]),
                v2_enabled=True, v2_wave=0, v2_vol=50,
                v2_notes=_notes_from([(0,32),(1,24),(2,16),(3,8)])),
    _make_sound("Shoot", tempo=300, v1_wave=0, v1_vol=65,
                v1_notes=_notes_from([(0,38),(1,32),(2,24),(3,16)]),
                v2_enabled=True, v2_wave=3, v2_vol=35,
                v2_notes=_notes_from([(0,24),(1,16),(2,8)])),
    _make_sound("Powerup", tempo=260, v1_wave=1, v1_vol=75,
                v1_notes=_notes_from([(0,12),(1,16),(2,19),(3,24),(4,28),(5,31),(6,36),(7,40),(8,43),(9,48)]),
                v2_enabled=True, v2_wave=0, v2_vol=40,
                v2_notes=_notes_from([(2,12),(3,16),(4,19),(5,24),(6,28),(7,31)])),
    _make_sound("Game Over", tempo=120, v1_wave=0, v1_vol=80,
                v1_notes=_notes_from([(0,24),(1,24),(3,22),(4,22),(6,19),(7,19),(9,17),(10,17),(12,12),(13,12),(14,12),(15,12)]),
                v2_enabled=True, v2_wave=1, v2_vol=50,
                v2_notes=_notes_from([(0,12),(1,12),(3,10),(4,10),(6,7),(7,7),(9,5),(10,5),(12,1),(13,1),(14,1),(15,1)])),
]

# ── Actors (sound effects wired) ───────────────────────────
ACTORS = [
    {
        "name": "Hero", "type": "Player",
        "max_speed": 200.0, "gravity_scale": 1.0,
        "max_hp": 1.0, "damage": 0.0, "score_value": 0.0,
        "collision_mode": "Slide", "death_mode": "Respawn", "rebirth": 2.0,
        "jump_force": 520.0,
        "anim_data": [{"name": "Idle", "speed": 8.0, "loop": True}],
        "jump_sound": "Jump",
        "death_sound": "Hero Death",
        "hit_sound": "Hit",
        "pickup_sound": "Coin",
        "stomp_sound": "Enemy Death",
        "shoot_sound": "(None)",
        "shader_fx": "(None)", "shader_params": {},
    },
    {
        "name": "Goomba", "type": "Drone",
        "max_speed": 60.0, "gravity_scale": 1.0,
        "max_hp": 1.0, "damage": 1.0, "score_value": 100.0,
        "ai_behavior": "Patrol", "ai_patrol_speed": 60.0, "ai_vision_range": 200.0,
        "collision_mode": "Bounce", "death_mode": "Destroy",
        "anim_data": [{"name": "Idle", "speed": 6.0, "loop": True}],
        "death_sound": "Enemy Death",
        "hit_sound": "Hit",
        "jump_sound": "(None)", "shoot_sound": "(None)",
        "pickup_sound": "(None)", "stomp_sound": "(None)",
        "shader_fx": "(None)", "shader_params": {},
    },
    {
        "name": "Coin", "type": "Computer",
        "max_speed": 0.0, "gravity_scale": 0.0,
        "max_hp": 1.0, "damage": 0.0, "score_value": 50.0,
        "collision_mode": "None", "death_mode": "Destroy",
        "anim_data": [{"name": "Idle", "speed": 8.0, "loop": True}],
        "pickup_sound": "Coin",
        "death_sound": "(None)", "hit_sound": "(None)",
        "jump_sound": "(None)", "shoot_sound": "(None)", "stomp_sound": "(None)",
        "shader_fx": "(None)", "shader_params": {},
    },
    {
        "name": "Mushroom", "type": "Computer",
        "max_speed": 0.0, "gravity_scale": 0.0,
        "max_hp": 1.0, "damage": 0.0, "score_value": 200.0,
        "collision_mode": "None", "death_mode": "Destroy",
        "anim_data": [{"name": "Idle", "speed": 6.0, "loop": True}],
        "pickup_sound": "Powerup",
        "death_sound": "(None)", "hit_sound": "(None)",
        "jump_sound": "(None)", "shoot_sound": "(None)", "stomp_sound": "(None)",
        "shader_fx": "(None)", "shader_params": {},
    },
    {
        "name": "Flag", "type": "Computer",
        "max_speed": 0.0, "gravity_scale": 0.0,
        "max_hp": 9999.0, "damage": 0.0, "score_value": 1000.0,
        "collision_mode": "None", "death_mode": "Destroy",
        "anim_data": [{"name": "Idle", "speed": 4.0, "loop": True}],
        "pickup_sound": "Powerup",
        "death_sound": "(None)", "hit_sound": "(None)",
        "jump_sound": "(None)", "shoot_sound": "(None)", "stomp_sound": "(None)",
        "shader_fx": "(None)", "shader_params": {},
    },
]

PROJECT = {
    "settings": {
        "game_title": "Super Gasic Bros.",
        "gravity": 980, "friction": 60, "elasticity": 0,
        "screen_width": 640, "screen_height": 384,
        "lives": 3,
        "show_score": True, "show_lives": True, "show_level": True, "show_coins": True,
        "start_level": 1, "level_order": "Sequential",
        "auto_save": True, "debug": False,
        "agck_run": True,
    },
    "actors": ACTORS,
    "sounds": SOUNDS,
    "shaders": [],
    "build": {},
    "levels": [level_1(), level_2(), level_3(), level_4()],
    "tile_library": {},
}

def main():
    out = os.path.join(os.path.dirname(__file__), "..",
                       "game_projects", "AGCK_Tests", "super_mario_like.agck")
    out = os.path.abspath(out)
    with open(out, "w") as f:
        json.dump(PROJECT, f, indent="\t")
    print(f"Wrote {out}")
    # Sanity-check the JSON parses back
    with open(out) as f:
        json.load(f)
    print("JSON re-parse OK")

if __name__ == "__main__":
    main()
