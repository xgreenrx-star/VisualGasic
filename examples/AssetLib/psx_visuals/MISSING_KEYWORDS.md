PSX Visuals demo — Missing / noteworthy keywords and limitations

Notes about porting PSX Visuals plugin into VisualGasic demos:

- Global shader parameters & plugin autoloads: The PSX Visuals plugin usually exposes global shader parameters and autoloaded helpers. VisualGasic doesn't have a built-in keyword to set global shader uniforms directly; instead, access via the autowired node (named `PSXVisuals`) or use a small GDScript bridge.

- Runtime plugin enable/disable: There is no single-line `EnablePlugin` keyword in VisualGasic; toggling plugin features typically requires calling methods on the plugin node instance.

- Shader compilation / resource creation: If you need to compile or dynamically create resources (ShaderMaterial, Shader), VisualGasic lacks a direct shorthand — pre-create them in the scene or use GDScript helpers.

- Boolean type: For consistency across demos, some examples use Integer (0/1) for flags — adapt to a boolean type if present in your target environment.

Bridge helper added: `examples/AssetLib/psx_visuals/upstream/bridges/psx_bridge.gd`. Add the node (e.g., `PSXBridge`) to your scene and configure `target_node_path` if the plugin node is named differently. The demo prefers the bridge if present and falls back to direct property access when the bridge is missing.
