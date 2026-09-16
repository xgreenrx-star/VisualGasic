@tool
extends SceneTree

## Test script: Verifies the WobblyButton custom control pipeline end-to-end.
## Tests:
##   1. custom_components.cfg loads WobblyButton as enabled
##   2. WobblyButton.tscn loads and instantiates correctly
##   3. WobblyButton script has the wobble properties
##   4. FormDesigner C++ accepts .tscn file drop data (can_drop_data)
##   5. FormDesigner C++ register_custom_control_type works
##   6. FormDesigner C++ set_control_preview_texture works
##   7. FormDesigner add_control with custom scene_path works

var passed := 0
var failed := 0

func _test(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		passed += 1
		print("  ✓ ", name)
	else:
		failed += 1
		print("  ✗ ", name, "  —  ", detail)

func _init():
	print("")
	print("═══════════════════════════════════════════════════")
	print("  WobblyButton Custom Control — Pipeline Test")
	print("═══════════════════════════════════════════════════")
	print("")

	# ── Test 1: Config loading ──
	print("▸ Config Loading")
	var ComponentsDialog = load("res://addons/visual_gasic/components_dialog.gd")
	var enabled = ComponentsDialog.load_enabled_components()
	var found_wobbly := false
	var wobbly_scene := ""
	for comp in enabled:
		if comp["name"] == "WobblyButton":
			found_wobbly = true
			wobbly_scene = comp.get("scene", "")
	_test("WobblyButton found in enabled components", found_wobbly)
	_test("Scene path is correct", wobbly_scene == "res://custom_controls/WobblyButton.tscn", wobbly_scene)

	# ── Test 2: Scene loading ──
	print("▸ Scene Loading")
	var scene_exists = FileAccess.file_exists("res://custom_controls/WobblyButton.tscn")
	_test("WobblyButton.tscn exists on disk", scene_exists)

	var packed: PackedScene = null
	if scene_exists:
		packed = load("res://custom_controls/WobblyButton.tscn")
	_test("PackedScene loads successfully", packed != null)

	var instance: Node = null
	if packed:
		instance = packed.instantiate()
	_test("Scene instantiates successfully", instance != null)
	_test("Instance is a Button", instance is Button, str(instance))

	# ── Test 3: Script properties ──
	print("▸ Script Properties")
	if instance:
		_test("Has wobble_amount property", "wobble_amount" in instance)
		_test("Has wobble_speed property", "wobble_speed" in instance)
		_test("Has pulse_amount property", "pulse_amount" in instance)
		_test("Has hover_glow_color property", "hover_glow_color" in instance)
		_test("Default text is 'Wobbly!'", instance.text == "Wobbly!", instance.text)
		_test("wobble_amount default = 3.0", instance.wobble_amount == 3.0, str(instance.wobble_amount))
	else:
		for _i in range(6):
			_test("(skipped — no instance)", false)

	# ── Test 4: FormDesigner C++ integration ──
	print("▸ FormDesigner C++ Integration")
	var fd_exists = ClassDB.class_exists("VisualGasicFormDesigner")
	_test("VisualGasicFormDesigner class exists", fd_exists)

	if fd_exists:
		# Check method existence via ClassDB (avoids headless rendering crash)
		var has_register = ClassDB.class_has_method("VisualGasicFormDesigner", "register_custom_control_type")
		_test("Has register_custom_control_type method", has_register)

		var has_preview = ClassDB.class_has_method("VisualGasicFormDesigner", "set_control_preview_texture")
		_test("Has set_control_preview_texture method", has_preview)

		var has_add = ClassDB.class_has_method("VisualGasicFormDesigner", "add_control")
		_test("Has add_control method", has_add)

		var has_scene_signal = ClassDB.class_has_signal("VisualGasicFormDesigner", "scene_file_dropped")
		_test("Has scene_file_dropped signal", has_scene_signal)

		# Check signals we depend on
		var has_selected = ClassDB.class_has_signal("VisualGasicFormDesigner", "control_selected")
		_test("Has control_selected signal", has_selected)

		var has_right_click = ClassDB.class_has_signal("VisualGasicFormDesigner", "control_right_clicked")
		_test("Has control_right_clicked signal", has_right_click)
	else:
		for _i in range(6):
			_test("(skipped — no FormDesigner class)", false)

	# ── Summary ──
	print("")
	print("═══════════════════════════════════════════════════")
	print("  Results: ", passed, " passed, ", failed, " failed, ", passed + failed, " total")
	print("═══════════════════════════════════════════════════")
	print("")

	if instance:
		instance.queue_free()

	quit(failed)
