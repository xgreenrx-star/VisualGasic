#!/usr/bin/env bash
# Source after ROOT is set. Keep benchmark resources separate from demo autoloads.
DEMO="$(mktemp -d "${TMPDIR:-/tmp}/vg-benchmark-host.XXXXXXXX")"
trap 'rm -rf -- "$DEMO"' EXIT
cp "$ROOT/scripts/benchmark_project.godot" "$DEMO/project.godot"
for resource in addons benchmarks test_suites bench.vg; do
	ln -s "$ROOT/engine_lab/$resource" "$DEMO/$resource"
done
mkdir -p "$DEMO/.godot"
printf '%s\n' 'res://addons/visual_gasic/visual_gasic.gdextension' >"$DEMO/.godot/extension_list.cfg"
