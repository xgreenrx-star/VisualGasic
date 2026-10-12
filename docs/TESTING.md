# Testing

## In-editor UI check

`scripts/run_editor_ui_probe.sh` opens the Godot editor on a virtual display, drives the Behavior evidence panel and the Last change card on a temp copy of Crystal Caverns, and exits non-zero if the widget text does not match. It is a manual or pre-release check. It is not part of `run_test_suite.sh`.

Requirements: `xvfb-run`, and a Godot binary that can render with Mesa `opengl3`.

```bash
scripts/run_editor_ui_probe.sh
scripts/run_editor_ui_probe.sh /path/to/Godot
```

The first argument is the Godot binary. The default is `./Godot_v4.6.1-stable_linux.x86_64` at the repo root.

Screenshots, `probe_log.txt`, `editor.log`, and the behavior-run snapshot are written to `build/editor_ui_probe/<godot-version>/`. `build/` is gitignored. The script deletes its temp project and `~/.local/share/godot/app_userdata/VG UI Probe` when it finishes.
