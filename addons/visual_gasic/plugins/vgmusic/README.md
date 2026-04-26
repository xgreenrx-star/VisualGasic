# VGMusic plugin

Music tracker / chiptune maker for VisualGasic.

## Credits

- **Bosca Ceoil Blue** by Yuri Sizov & contributors — MIT
  <https://github.com/YuriSizov/boscaceoil-blue>
  Vendored under [`bosca/`](bosca/).
- **GDSiON** synthesizer by Yuri Sizov & contributors — MIT
  <https://github.com/YuriSizov/gdsion>
  Built from source under `vendor/gdsion/`; binaries placed in [`bin/`](bin/).

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
