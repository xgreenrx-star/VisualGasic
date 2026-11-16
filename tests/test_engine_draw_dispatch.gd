extends SceneTree

const RELOADED_SOURCE := """
Sub Replacement()
End Sub
Function NativeIdentity() As Integer
	Return get_instance_id()
End Function
Function get_instance_id() As Integer
	Return 77
End Function
Function Revision() As Integer
	Return 2
End Function
"""

class ReferenceCanvas extends Node2D:
	var line_count := 1000
	var line_style := 0
	var elapsed_us := 0
	var checksum := 0

	func _draw() -> void:
		var started := Time.get_ticks_usec()
		checksum = 0
		var ink := Color(0.3, 0.8, 1)
		for i in range(line_count):
			var a := Vector2(i % 64, floori(float(i) / 64))
			var b := a + Vector2(1, 1)
			if line_style == 1:
				draw_line(a, b, ink)
			elif line_style == 2:
				draw_line(a, b, ink, 2, true)
			else:
				draw_line(a, b, ink, 1)
			checksum += i
		elapsed_us = Time.get_ticks_usec() - started

var failures := 0
var reference_image: Image

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: ", message)
		failures += 1

func measure(canvas: Node2D, label: String) -> int:
	root.add_child(canvas)
	var samples: Array[int] = []
	for frame in range(7):
		canvas.queue_redraw()
		await process_frame
		await process_frame
		check(int(canvas.get("checksum")) == 499500, label + " checksum")
		if frame >= 2:
			samples.append(int(canvas.get("elapsed_us")))
	samples.sort()
	print("DRAW_DISPATCH ", label, " median_us=", samples[2])
	if DisplayServer.get_name() != "headless":
		var image := root.get_texture().get_image()
		check(image != null and not image.is_empty(), label + " rendered image")
		if reference_image == null:
			reference_image = image
			var changed := false
			for y in range(16):
				for x in range(64):
					if image.get_pixel(x, y).g > 0.7 and image.get_pixel(x, y).b > 0.9:
						changed = true
			check(changed, "drawing produces visible pixels")
		else:
			check(image.get_data() == reference_image.get_data(), label + " matches rendered reference")
	canvas.queue_free()
	await process_frame
	return samples[2]

func run() -> void:
	Engine.max_fps = 0
	if not ClassDB.class_exists("VisualGasicScript"):
		printerr("FAIL: run this harness in a project with the VG extension loaded")
		quit(1)
		return
	var fixture_path: String = get_script().resource_path.get_base_dir().path_join("fixtures/engine_draw_dispatch.vg")
	var source := FileAccess.get_file_as_string(fixture_path)
	for extra_methods in [0, 200]:
		var script: Script = ClassDB.instantiate("VisualGasicScript")
		script.resource_path = fixture_path + str(extra_methods)
		var expanded := source
		for i in range(extra_methods):
			expanded += "\nSub Filler%d()\nEnd Sub\n" % i
		script.source_code = expanded
		check(script.reload() == OK, "fixture compiles")
		var probe := Node2D.new()
		probe.set_script(script)
		for name in ["RollShopWeapons", "rollshopweapons", "ROLLSHOPWEAPONS", "roll_shop_weapons", "_unhandled_input"]:
			check(probe.has_method(name), "method alias " + name)
		check(not probe.has_method("AbsentProcedure"), "missing method")
		var started := Time.get_ticks_usec()
		var unexpected := 0
		for i in range(1000):
			if probe.has_method("AbsentProcedure"):
				unexpected += 1
		print("METHOD_LOOKUP extra_methods=", extra_methods, " elapsed_us=", Time.get_ticks_usec() - started)
		check(unexpected == 0, "script missing method")
		probe.free()
		var native_us := 0
		var canonical_us := 0
		for native_spelling in [true, false]:
			var canvas := Node2D.new()
			canvas.set_script(script)
			canvas.set("native_spelling", native_spelling)
			var median_us: int = await measure(canvas, "VG methods=%d native=%s" % [extra_methods, native_spelling])
			if native_spelling:
				native_us = median_us
			else:
				canonical_us = median_us
		if not "--baseline" in OS.get_cmdline_user_args():
			check(native_us <= maxi(4 * canonical_us, 2000), "native spelling avoids deep dispatch overhead")
		probe = Node2D.new()
		probe.set_script(script)
		probe.add_child(Node.new())
		probe.add_child(Node.new())
		probe.add_child(Node.new(), false, Node.INTERNAL_MODE_FRONT)
		for i in range(3):
			check(probe.call("ChildCounts") == 5, "native overload defaults and cached arities")
		var first_identity: Variant = probe.call("NativeIdentity")
		var second_identity: Variant = probe.call("NativeIdentity")
		print("OWNER_IDENTITY first=", first_identity, " second=", second_identity, " expected=", probe.get_instance_id())
		check(first_identity == probe.get_instance_id(), "native owner call resolves")
		check(second_identity == probe.get_instance_id(), "cached native owner call resolves")
		for i in range(4):
			check(probe.call("Revision") == 1, "numeric function warms up correctly")
		script.source_code = RELOADED_SOURCE
		check(script.reload(true) == OK, "reload succeeds")
		check(not probe.has_method("RollShopWeapons"), "reload removes cached method")
		check(probe.has_method("Replacement"), "reload adds method")
		check(probe.call("NativeIdentity") == 77, "reload invalidates native owner-call memo")
		for i in range(4):
			check(probe.call("Revision") == 2, "reload invalidates compiled numeric function")
		probe.free()
	await measure(ReferenceCanvas.new(), "GDScript")
	for style in [1, 2]:
		reference_image = null
		var script: Script = load(fixture_path)
		var canvas := Node2D.new()
		canvas.set_script(script)
		canvas.set("line_style", style)
		await measure(canvas, "VG native style=%d" % style)
		var reference := ReferenceCanvas.new()
		reference.line_style = style
		await measure(reference, "GDScript style=%d" % style)
	print("DRAW_DISPATCH_COMPLETED failures=", failures)
	quit(1 if failures else 0)
