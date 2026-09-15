# Brotato 3D — Art Assets

Target: **Kenney Blocky Characters** (CC0) — blocky Minecraft-adjacent look, 27 animations, 18 skins.

## Download

1. [Blocky Characters on OpenGameArt](https://opengameart.org/content/blocky-characters) — `kenney_blocky-characters_2.0.zip`
2. Or [Kenney Mini Characters](https://opengameart.org/content/mini-character-1) — more animations, wheelchair-inclusive cast.

## Import into Godot

1. Unzip into `assets/models/kenney_blocky/` (gitignored large binaries OK).
2. Import a `.gltf` / `.glb` character in Godot — confirm animations in the Import dock.
3. Save as `scenes/characters/PlayerBlocky.tscn` (instanced under `Player.tscn` → `Pivot`).
4. Wire `AnimationPlayer` clip names (typically `Walk`, `Idle`, `Run`) in `Player3D.vg` → `UpdateAnimation`.

## Bundled (Phase 1+)

All 18 `character-*.glb` files live under `assets/models/kenney_blocky/glb/` (CC0, ~113 KB each).

- Player: `character-a.glb` + `textures/texture-a.png`
- Enemies: `character-b` … `character-e` (types), `character-f` … `character-i` (bosses)
- Skins applied at runtime by `CharacterSkins3D.vg` (GLTF embed alone showed white in Forward+)

## License

Kenney assets: **CC0** — credit [Kenney.nl](https://kenney.nl) optional.

Copy audio from `projects/brotato_vg/assets/audio/` when sfx are wired (same upstream brotato-mini license).
