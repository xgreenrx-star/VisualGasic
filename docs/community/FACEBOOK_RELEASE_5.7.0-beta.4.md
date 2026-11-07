# VisualGasic 5.7.0 Beta 4

VisualGasic 5.7.0 Beta 4 is a bug-fix release.

This update repairs dictionary returns and indexed reads, array-append
optimization mistakes, mixed integer/float storage in the JIT, scaled vector
accumulation, explicit calls between VG lifecycle procedures, enum-name
shadowing, null-object checks, and AABB/Plane constructors.
It also fixes optimized lambda calls, numeric dictionary key identity,
packed Vector3 subtraction/append, and VG namespace calls such as Array.RemoveAt.
Optimized error-handler targets, Rect/array component writeback, Basis columns
and Projection member access are repaired as well.

New native binaries are required. Back up your project, close Godot and replace
the entire addon folder when upgrading.

Downloads include the Godot Asset Library addon ZIP, Linux and Windows
installers, universal Mac setup for Intel and Apple Silicon, offline bundles
with Godot, and examples/documentation. Mac setup remains unsigned and is not
a notarized DMG. The Godot store listing needs its separate update/approval.

This is still a public beta, not stable VG6. Godot 4.6.1 remains the
cross-platform baseline. Bug reports with a small reproduction are welcome.

Release notes and downloads:
https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.7.0-beta.4

Website:
https://xgreenrx-star.github.io/VisualGasic/
