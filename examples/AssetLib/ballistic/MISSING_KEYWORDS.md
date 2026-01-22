Ballistic demo — Missing / noteworthy keywords and limitations

Notes:
- The upstream library provides advanced ballistic math in GDScript/C#; we bridge to it with `BallisticBridge`.
- VisualGasic lacked native vector math helpers; added convenience functions: `VAdd`, `VSub`, `VDot`, `VCross`, `VLen`, `VNormalize`, and `Vec3(x,y,z)`.
- The bridge still provides domain-specific ballistic utilities; the demo will prefer `BallisticBridge` if present but can use the new vector helpers for simple math.
