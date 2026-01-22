Horror Survival demo — Missing / noteworthy keywords and limitations

Notes:
- Marching cubes and greedy meshing are complex GPU/C++ features; VisualGasic cannot replicate them directly.
- A bridge `examples/AssetLib/horror_survival/upstream/bridges/horror_bridge.gd` is included to call into the upstream scene which does the heavy lifting; the demo triggers parameter changes and regeneration only.
- For full visual parity run the upstream project; the demo provides a lightweight control surface.
