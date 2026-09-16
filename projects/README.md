# projects/ — compatibility aliases

Sample Godot projects moved to **[`../samples/`](../samples/README.md)** (release layout, Sep 2026).

Each entry here is a symlink, e.g. `projects/brotato3d` → `samples/games/brotato3d`.

| Symlink | New path |
|---------|----------|
| `brotato3d`, `asteroids`, … | `samples/games/<name>` |
| `vg_twinpane`, … | `samples/apps/<name>` |
| `vg_beta_showcase`, … | `samples/showcases/<name>` |
| `vg_narcea_test`, … | `samples/internal/<name>` |

Open samples with:

```bash
# Godot → Import → samples/games/brotato3d/project.godot
scripts/ci_smoke.sh samples/games/brotato3d
```

Old bookmarks and docs that use `projects/…` still work until the next major release.
