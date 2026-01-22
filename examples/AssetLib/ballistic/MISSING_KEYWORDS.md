Ballistic demo — Missing / noteworthy keywords and limitations

Notes:
- The upstream library provides advanced ballistic math in GDScript/C#; we bridge to it with `BallisticBridge`.
- VisualGasic lacks native vector math helpers; the bridge returns Vector3 results or prints approximations if upstream helpers are missing.
