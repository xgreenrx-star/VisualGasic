extends SceneTree

func _init():
	var controller_script: GDScript = load("res://addons/visual_gasic/plugins/vgmusic/bosca/globals/Controller.gd")
	var controller := Node.new()
	controller.set_script(controller_script)
	controller.name = "Controller"
	root.add_child(controller)
	controller.vgmusic_boot()

	var scene: PackedScene = load("res://addons/visual_gasic/plugins/vgmusic/bosca/Main.tscn")
	var main = scene.instantiate()
	root.add_child(main)

	await root.process_frame
	await root.process_frame

	var note_map: Control = main.get_node("Main/PatternEditor/NoteMap")
	print("current_song=", controller.current_song != null)
	print("current_pattern_index=", controller.current_pattern_index)
	print("patterns=", controller.current_song.patterns.size() if controller.current_song else -1)
	print("note_height=", note_map.get_theme_constant("note_height", "NoteMap"))
	print("border_width=", note_map.get_theme_constant("border_width", "NoteMap"))
	print("gutter_color=", note_map.get_theme_color("gutter_color", "NoteMap"))
	print("theme_path=", note_map.theme.resource_path if note_map.theme else "<null>")
	quit()
