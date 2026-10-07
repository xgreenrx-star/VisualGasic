# VGMusic plugin

Music tracker / chiptune maker for VisualGasic.

## Credits

- **Bosca Ceoil Blue** by Yuri Sizov & contributors — MIT
  <https://github.com/YuriSizov/boscaceoil-blue>
  Vendored under [`bosca/`](bosca/).
- **GDSiON** synthesizer by Yuri Sizov & contributors — MIT
  <https://github.com/YuriSizov/gdsion>
  Built from local source under `vendor/gdsion/`; binaries placed in [`bin/`](bin/).

Both projects are MIT licensed; see `LICENSE` files inside the respective
vendor folders. Their license texts are reproduced in
[`bosca/LICENSE`](bosca/LICENSE) (Bosca) and [`bin/LICENSE`](bin/LICENSE) (GDSiON).

## How it loads

VG plugins cannot write to `project.godot`, so this plugin emulates Bosca's
`Controller` autoload at runtime: when you switch to the VGMusic tab, the
plugin instantiates `bosca/globals/Controller.gd` and adds it to the
`SceneTree.root` as a node named `Controller`. This makes every
`Controller.foo` reference inside Bosca's scripts resolve correctly.

When the plugin is deactivated the embedded scene is hidden but kept in the
tree, so your in-progress song is preserved.

## Building GDSiON

```
cd vendor/gdsion
scons platform=linux target=template_release -j$(nproc)
# repeat with target=template_debug and target=editor for full coverage
cp bin/libgdsion.linux.template_release.x86_64.so \
   ../../addons/visual_gasic/plugins/vgmusic/bin/
```

A helper script is provided at
`addons/visual_gasic/plugins/vgmusic/build_gdsion.sh` — see
[`build_gdsion.sh`](build_gdsion.sh).

## Current platform support

Only Linux x86_64 binaries are currently built locally in [`bin/`](bin/).
That directory and `vendor/gdsion/` are ignored, not shipped by a Git checkout.
`libgdsion.gdextension` only lists Linux entries to match — it does
**not** reference macOS/Windows/Web/Android binaries that aren't shipped.
Godot simply skips loading this GDExtension on platforms with no matching
entry (no error, the VGMusic tab just won't have GDSiON playback). Add
platform entries back to `libgdsion.gdextension` only once you've built and
packaged the corresponding binary using the steps above (cross-compiled or
built natively on that platform).

## Pool lifetime repair

Use [`build_gdsion.sh`](build_gdsion.sh) rather than the raw build commands
above. It applies [`gdsion_pool_lifetime.patch`](gdsion_pool_lifetime.patch)
before building either variant and refuses conflicting source trees.
The patch was verified against GDSiON revision
`4460364ea6dfdd625f4e15f1ec95e06e417bf2b7`.

GDSiON's original teardown freed the integer/double element pools before
track and singleton cleanup returned their elements to those pools. This
produced a native use-after-free during allocator-perturbed editor shutdown.
The patch finalizes the pools last, clears their static pointers, deletes
elements when no pool exists, and drains lists without losing their next
element when it is unlinked.

```sh
JOBS=4 addons/visual_gasic/plugins/vgmusic/build_gdsion.sh \
  template_debug template_release
GODOT=/path/to/Godot scripts/run_gdsion_pool_regression.sh
GODOT=/path/to/Godot ITERATIONS=3 scripts/run_editor_import_heap_stress.sh
```

The native pool runner requires Linux x86_64, a C++ compiler and the built
vendored godot-cpp debug archive. It runs 14 checks for both numeric types:
ring/list drainage and reuse, cleanup without a pool, cleanup after pool
finalization, repeated finalization and pool restart. The import stress runner
uses fresh 2D/3D Brotato copies each iteration and allocator perturbation.
Import completion does not imply clean bootstrap: existing font-import
diagnostics are preserved by the reload runner.
