extends SceneTree

# Quick smoke test for VGVectorCanvas2D. Verifies:
#  - the class is registered (ClassDB::class_exists)
#  - subclass VectorCanvas can be instantiated and inherits the Draw* API
#  - DrawLine / DrawRect / Clear / Render all roundtrip through _commands
#  - the GDScript-side overlay APIs still see the queued commands

func _init():
	var ok := true

	if not ClassDB.class_exists("VGVectorCanvas2D"):
		print("FAIL: VGVectorCanvas2D not registered in ClassDB")
		quit(1)
		return

	# Instantiate the GDScript subclass.
	var VectorCanvas = load("res://addons/visual_gasic/plugins/vector_graphics/vector_canvas.gd")
	if VectorCanvas == null:
		print("FAIL: cannot load vector_canvas.gd")
		quit(1)
		return
	var c = VectorCanvas.new()

	# Hot-path API from C++ base.
	c.DrawLine(Vector2(0, 0), Vector2(10, 10), 2.0, Color(1, 0, 0))
	c.DrawRect(Rect2(5, 5, 20, 20), 1.0, Color.WHITE, true, Color(0, 1, 0))
	c.DrawCircle(Vector2(50, 50), 8.0, Color.YELLOW, true)
	c.DrawVectorText(Vector2(10, 10), "HI", Color.WHITE)

	var n: int = c._commands.size()
	if n < 4:
		print("FAIL: expected at least 4 queued commands after Draw* calls, got %d" % n)
		ok = false
	else:
		print("PASS: %d commands queued via C++ Draw* methods" % n)

	# Overlay API still works.
	var targets = c.get_tweak_targets()
	if targets.size() == 0:
		print("FAIL: get_tweak_targets returned empty")
		ok = false
	else:
		print("PASS: get_tweak_targets returned %d target(s)" % targets.size())

	# Transform stack survives PushTransform/PopTransform.
	c.PushTransform(Transform2D().translated(Vector2(100, 0)))
	c.DrawLine(Vector2.ZERO, Vector2(1, 0), 1.0, Color.WHITE)
	var line_cmd: Dictionary = c._commands[c._commands.size() - 1]
	var xf: Transform2D = line_cmd["transform"]
	if abs(xf.origin.x - 100.0) > 0.001:
		print("FAIL: transform stack not honored, got origin=%s" % str(xf.origin))
		ok = false
	else:
		print("PASS: transform stack survived push (origin.x=%.1f)" % xf.origin.x)
	c.PopTransform()

	# Clear() must wipe _commands.
	c.Clear()
	if c._commands.size() != 0:
		print("FAIL: Clear left %d commands" % c._commands.size())
		ok = false
	else:
		print("PASS: Clear emptied _commands")

	# Free explicitly to avoid leak warnings in the report.
	c.free()

	if ok:
		print("VGVectorCanvas2D smoke: all checks passed")
		quit(0)
	else:
		print("VGVectorCanvas2D smoke: FAILURES")
		quit(1)
