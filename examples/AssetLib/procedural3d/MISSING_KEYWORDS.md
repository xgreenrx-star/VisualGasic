Procedural 3D demo — Missing / noteworthy keywords and limitations

Notes:
- The upstream project is a full C# project that relies on custom nodes and exporters. VisualGasic cannot directly run or instantiate C# classes without a bridge.
- A bridge `examples/AssetLib/procedural3d/upstream/bridges/procedural_bridge.gd` is provided to toggle high-level parameters and request a regeneration.
- Complex features (water/day-night/weather) remain in upstream; the demo triggers simple parameter changes only.
