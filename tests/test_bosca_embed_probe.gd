extends Node

var total := 0
var passed := 0
var failed := 0
var fail_details: Array = []

func _ready() -> void:
	print("============================================================")
	print("BOSCA EMBED PROBE")
	print("============================================================")
	run_all_tests()
	print("\n============================================================")
	print("RESULTS: %d/%d passed, %d failed" % [passed, total, failed])
	if fail_details.size() > 0:
		print("\nFAILURES:")
		for d in fail_details:
			print("  ✗ " + d)
	print("============================================================")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

func assert_true(cond: bool, label: String) -> void:
	total += 1
	if cond:
		passed += 1
		print("  ✓ " + label)
	else:
		failed += 1
		fail_details.append(label + ": expected true")
		print("  ✗ " + label + ": expected true")

func assert_gt(actual: int, minimum: int, label: String) -> void:
	total += 1
	if actual > minimum:
		passed += 1
		print("  ✓ " + label)
	else:
		failed += 1
		var msg := "%s: expected > %d but got %d" % [label, minimum, actual]
		fail_details.append(msg)
		print("  ✗ " + msg)

func run_all_tests() -> void:
	test_embedded_bosca_boots_with_live_notemap()

func test_embedded_bosca_boots_with_live_notemap() -> void:
	print("\n--- Embedded Bosca boot probe ---")
	var plugin_script := load("res://addons/visual_gasic/plugins/vgmusic/vg_vgmusic_plugin.gd")
	var plugin = plugin_script.new()
	add_child(plugin)

	if plugin.has_method("_build_ui"):
		plugin._build_ui()
	if plugin.has_method("_on_activated"):
		plugin._on_activated()

	await get_tree().process_frame
	await get_tree().process_frame

	var loop := Engine.get_main_loop() as SceneTree
	var ctrl := loop.root.get_node_or_null("Controller")
	assert_true(ctrl != null, "controller created during activation")
	assert_true(ctrl != null and ctrl.current_song != null, "current song initialized")
	assert_gt(ctrl.current_song.patterns.size() if ctrl and ctrl.current_song else -1, 0, "default song has patterns")

	var main_scene := plugin.get("_main_scene_instance")
	assert_true(main_scene != null, "main scene instantiated")

	var note_map: Control = main_scene.get_node_or_null("Main/PatternEditor/NoteMap")
	assert_true(note_map != null, "note map exists")
	assert_gt(note_map.get_theme_constant("note_height", "NoteMap") if note_map else 0, 0, "note height theme constant available")
	assert_gt(note_map.get_theme_constant("border_width", "NoteMap") if note_map else 0, 0, "border width theme constant available")
