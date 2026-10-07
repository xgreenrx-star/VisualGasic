extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Expected one sample probe name.")
		quit(1)
		return
	var packed := load(str(ProjectSettings.get_setting("application/run/main_scene"))) as PackedScene
	if packed == null:
		push_error("Cannot load the configured sample scene.")
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	for frame in range(3):
		await process_frame
	match args[0]:
		"highscores":
			check(scene.get("scoreCount") == 10, "ten DATA score rows")
			var names: Variant = scene.get("playerNames")
			check(names is Array and names[0] is String, "drawing preserves string-array elements")
			scene.call("PrintScoresToConsole")
			check(scene.get("playerNames")[0] == "ACE", "formatted scores preserve player name")
		"snake":
			check(scene.get("level") == 1, "Snake finishes first-level initialization")
			check(scene.get("foodType") >= 0, "Snake food initialization finishes")
			scene.set("snakeLength", 0)
			scene.set("wallCount", 0)
			scene.set("foodX", 1)
			scene.set("foodY", 1)
			check(not scene.call("IsOccupied", 1, 1, false), "replacement food does not block itself")
			check(scene.call("IsOccupied", 1, 1, true), "power-up avoids existing food")
			var old_x: Variant = scene.get("snakeX")
			var old_y: Variant = scene.get("snakeY")
			var width := int(scene.get("GRID_WIDTH"))
			var height := int(scene.get("GRID_HEIGHT"))
			check(width > 0 and height > 0, "Snake grid dimensions are available")
			var xs: Array = []
			var ys: Array = []
			for y in range(height):
				for x in range(width):
					xs.append(x)
					ys.append(y)
			scene.set("snakeX", xs)
			scene.set("snakeY", ys)
			scene.set("snakeLength", xs.size())
			check(scene.call("FindFreeCell", false) == -1, "full-board search terminates")
			scene.set("snakeX", old_x)
			scene.set("snakeY", old_y)
			scene.call("StartLevel")
		"platformer":
			var menu := scene.get_node("InterfaceLayer/PauseMenu")
			paused = true
			menu.call("OpenMenu")
			await create_timer(0.4, true).timeout
			check(menu.visible and menu.modulate.a > 0.99, "pause menu fades in while paused")
			menu.call("CloseMenu")
			await create_timer(0.3, true).timeout
			check(not paused and not menu.visible, "close resumes gameplay and hides overlay")
			menu.call("OpenMenu")
			menu.call("CloseMenu")
			await create_timer(0.05, true).timeout
			paused = true
			menu.call("OpenMenu")
			await create_timer(0.4, true).timeout
			check(menu.visible and menu.modulate.a > 0.99, "reopen cancels pending close")
			menu.get_node("ColorRect/CenterContainer/VBoxContainer/ResumeButton").emit_signal("pressed")
			await create_timer(0.3, true).timeout
			check(not paused and not menu.visible, "Resume signal closes menu")
		"vgvector":
			scene.call("mnuFile_New_Click")
			check(scene.call("AddShape", "rect", 100.0, 100.0, 20.0, 30.0) == 0, "add reversed-corner rectangle")
			check(scene.call("HitTestShapes", 50.0, 50.0) == 0, "reversed-corner bounds hit")
			check(scene.call("HitTestShapes", 200.0, 200.0) == -1, "outside bounds miss")
			var path := "user://vg_sample_probe_%s.vgv" % OS.get_process_id()
			scene.call("SaveVGV", path)
			check(FileAccess.file_exists(path), "vector file written")
			scene.call("mnuFile_New_Click")
			scene.call("LoadVGV", path)
			check(scene.call("HitTestShapes", 50.0, 50.0) == 0, "vector file round trip")
			check(DirAccess.remove_absolute(path) == OK, "remove vector probe file")
		"vgpaint":
			scene.call("SetPixel", 2, 3, 10, 20, 30)
			check(scene.call("GetPixelR", 2, 3) == 10, "paint red pixel")
			check(scene.call("GetPixelG", 2, 3) == 20, "paint green pixel")
			check(scene.call("GetPixelB", 2, 3) == 30, "paint blue pixel")
		"vgmovie":
			scene.call("GoToStart")
			var first: Variant = scene.get("currentFrame")
			scene.call("NextFrame")
			check(scene.get("currentFrame") == first + 1, "movie advances frame")
			scene.call("PrevFrame")
			check(scene.get("currentFrame") == first, "movie returns to first frame")
			scene.call("PlayPause")
			scene.call("StopPlayback")
			check(not scene.get("isPlaying"), "movie playback stops")
		"dashboard":
			check(scene.get("ship_lives") == 3, "Asteroids initializes three lives")
			check(scene.get("score") >= 0, "Asteroids score remains nonnegative")
			check(scene.get("canvas_game") is Node, "vector game canvas is attached")
		"docgen":
			check(scene.call("GetTotalValue") == 5625, "DocGen inventory total")
		"climatist":
			check(scene.get("loadState") == "idle", "offline startup remains idle")
			check(str(scene.get("currentLine")).contains("skipped"), "offline mode is explicitly labelled")
		"agck":
			if DisplayServer.get_name() == "headless":
				check(false, "AGCK probe requires a graphical renderer")
			else:
				var glitch := scene.get_node("ShaderFX_Glitch_5/EffectRect").material as ShaderMaterial
				var shatter := scene.get_node("ShaderFX_Shatter_6/EffectRect").material as ShaderMaterial
				glitch.set_shader_parameter("glitch_intensity", 0.4)
				shatter.set_shader_parameter("shatter_progress", 0.3)
				await RenderingServer.frame_post_draw
				var image := root.get_texture().get_image()
				check(not image.is_empty(), "AGCK renders with active glitch and shatter shaders")
				if not image.is_empty():
					var first_color := image.get_pixel(0, 0)
					var varied := false
					for y in range(0, image.get_height(), 16):
						for x in range(0, image.get_width(), 16):
							if image.get_pixel(x, y) != first_color:
								varied = true
					check(varied, "AGCK rendered output contains varied pixels")
				shatter.set_shader_parameter("shatter_progress", 0.0)
				glitch.set_shader_parameter("glitch_intensity", 0.0)
		_:
			check(false, "unknown sample probe: " + args[0])
	paused = false
	scene.free()
	# Autoload music survives the main scene; stop it before quitting the host.
	for player in root.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
	await create_timer(0.1, true).timeout
	for frame in range(3):
		await process_frame
	print("VG_SAMPLE_PROBE_COMPLETED failures=", failures)
	quit(1 if failures else 0)
