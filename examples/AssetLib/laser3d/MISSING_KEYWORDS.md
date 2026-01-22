Laser3D demo — Missing / noteworthy keywords and limitations

Notes:
- The laser node exposes runtime firing and visual adjustments; we provide `LaserBridge` to call into these functions from VisualGasic.
- VisualGasic cannot currently create and attach custom collision shapes in a single-line; prepare nodes in the scene or use a bridge helper to spawn and attach pre-made projectiles.
