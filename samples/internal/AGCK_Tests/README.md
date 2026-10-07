# AGCK developer test project

This internal project contains AGCK project data and several editor/runtime
fixtures. Its configured main scene is the **generated**
`build/BLUE_SCREEN/Main.tscn`, not a tracked sample scene. `build/` and generated
media remain Git-ignored.

## Generate the scaffold

From the repository root, with the canonical addon symlink installed:

```bash
./Godot_v4.6.1-stable_linux.x86_64 --headless \
  --path samples/internal/AGCK_Tests --script res://build_bluescreen.gd
```

The builder reads `blue_screen.agck` and automatically runs the compatibility
repair step. It initializes the saved/default tile library, checks that
reported output files exist, and uses the `.vgt` behavior templates.
Clean scaffold generation, resource import and bounded startup were checked in
an isolated project on Godot 4.7.2; this is not full gameplay certification.
Import the generated resources in Godot before running the scene.
AGCK's editor UI is experimental and requires
`vg/enable_experimental_plugins`; the headless builder does not require that UI.

The locally augmented Blue Screen game can contain additional scripts, shader
effects, fonts, and music that are **not** recreated by the base scaffold.
Keep those assets locally and only use media you have permission to use.
Do not overwrite an augmented build with the scaffold generator unless that is
intentional.

## Repair an existing augmented build

After local generation or customization, run:

```bash
./Godot_v4.6.1-stable_linux.x86_64 --headless \
  --path samples/internal/AGCK_Tests --script res://repair_generated_build.gd
```

The repair is idempotent. It fixes the known legacy glitch/shatter shader
`fragment()` returns, adds a music teardown hook when applicable, and converts
the incomplete InfectionBar scene fragment to a standalone ProgressBar.
Returns in shader helper functions are left intact. Unrecognized legacy shader
patterns fail with an explicit diagnostic instead of guessing at a rewrite.

The repair does not add missing media or certify exports. The augmented local
game was tested with Godot 4.6.1 and 4.7.2 using OpenGL Compatibility under Xvfb,
including active glitch/shatter effects. Headless import alone is not a
rendering test.

## Repair regression checks

From the repository root, run against the AGCK project:

```bash
./Godot_v4.6.1-stable_linux.x86_64 --headless \
  --path samples/internal/AGCK_Tests \
  --script "$PWD/test_proj/run_generated_shader_repair_tests.gd"
```

The runner creates and removes isolated `user://` fixtures. It checks legacy
shader rewrites, helper returns, unsupported patterns, persisted widget/music
repairs, idempotence, and numeric/string death-action generation. It requires
`VG_GENERATED_REPAIR_TESTS_COMPLETED failures=0` and a zero process exit status.
