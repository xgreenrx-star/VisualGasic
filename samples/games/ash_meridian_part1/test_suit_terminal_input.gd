extends SceneTree

var game: Node
var ring: Node
var failures := 0

func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok:
		failures += 1

func frames(count: int) -> void:
	for index in range(count):
		await process_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func tap(code: Key) -> void:
	key(code, true)
	await frames(2)
	key(code, false)
	await frames(2)

func type_text(text: String) -> void:
	for character in text:
		var event := InputEventKey.new()
		event.unicode = character.unicode_at(0)
		event.keycode = character.to_upper().unicode_at(0)
		event.pressed = true
		Input.parse_input_event(event)
		event = event.duplicate()
		event.pressed = false
		Input.parse_input_event(event)
	await frames(2)

func command(text: String) -> void:
	await type_text(text)
	check(ring.get("loader_text") == text, "keyboard_echo_" + text)
	await tap(KEY_ENTER)

func capture(name: String) -> void:
	var directory := OS.get_environment("ASH_TERMINAL_CAPTURE_DIR")
	if not directory.is_empty():
		root.get_texture().get_image().save_png(directory.path_join(name + ".png"))

func changed_pixels(first: Image, second: Image, logical_rect: Rect2) -> int:
	var scale_factor := Vector2(first.get_size()) / Vector2(960, 540)
	var area := Rect2i(logical_rect.position * scale_factor, logical_rect.size * scale_factor)
	var count := 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if first.get_pixel(x, y) != second.get_pixel(x, y):
				count += 1
	return count

func render_checks(editor: LineEdit, feedback: Node2D) -> void:
	game.set_process(false)
	editor.set_process(false)
	feedback.set_process(false)
	ring.set("reduced_motion", false)
	ring.set("display_time", 1.0)
	ring.call("update_display")
	editor.set("blink_time", 0.1)
	ring.queue_redraw()
	await frames(3)
	var cursor_on := root.get_texture().get_image()
	editor.set("blink_time", 0.7)
	ring.queue_redraw()
	await frames(3)
	var cursor_off := root.get_texture().get_image()
	check(changed_pixels(cursor_on, cursor_off, Rect2(288, 30, 384, 339)) > 100, "blinking_block_has_visible_pixel_change_inside_crt")
	check(changed_pixels(cursor_on, cursor_off, Rect2(700, 50, 250, 400)) == 0, "block_blink_does_not_change_right_panel")
	ring.set("reduced_motion", true)
	ring.call("update_display")
	editor.set("blink_time", 0.1)
	ring.queue_redraw()
	await frames(3)
	var reduced_on := root.get_texture().get_image()
	editor.set("blink_time", 0.7)
	ring.queue_redraw()
	await frames(3)
	check(changed_pixels(reduced_on, root.get_texture().get_image(), Rect2(288, 30, 384, 339)) == 0, "reduced_motion_keeps_block_cursor_steady")
	feedback.set("clock", 1.0)
	feedback.call("update_displays")
	feedback.queue_redraw()
	await frames(3)
	var core_first := root.get_texture().get_image()
	feedback.set("clock", 2.0)
	feedback.call("update_displays")
	feedback.queue_redraw()
	await frames(3)
	check(changed_pixels(core_first, root.get_texture().get_image(), Rect2(721, 75, 218, 350)) == 0, "reduced_motion_stops_core_animation")
	ring.set("reduced_motion", false)
	feedback.set("clock", 1.0)
	feedback.call("update_displays")
	feedback.queue_redraw()
	await frames(3)
	core_first = root.get_texture().get_image()
	feedback.set("clock", 2.0)
	feedback.call("update_displays")
	feedback.queue_redraw()
	await frames(3)
	check(changed_pixels(core_first, root.get_texture().get_image(), Rect2(721, 75, 218, 350)) > 100, "orac_core_pulses_visibly_without_moving_crt")
	game.set_process(true)
	editor.set_process(true)
	feedback.set_process(true)
	await frames(3)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	game.call("ReleaseBootTerminal")
	game.set("phase", 5)
	await tap(KEY_ESCAPE)
	check(game.get("menu_on"), "pause_works_before_terminal_is_created")
	await tap(KEY_ESCAPE)
	game.set("opt_orac_voice", true)
	var speech: Object = game.get("speech")
	speech.set("capture_only", true)
	speech.call("configure", true)
	game.set("dev_i", 21)
	game.call("WarpDev")
	ring = game.get("ownership_ring")
	await frames(4)
	var terminal: Object = ring.get("terminal")
	check(speech.get("spoken_count") > 0, "orac_uses_existing_speech_pipeline")
	check(str(ring.get("orac_message")).contains("only you"), "orac_advice_remains_suit_overlay")
	var editor: LineEdit = ring.get("loader_entry")
	var feedback: Node2D = ring.get("terminal_feedback")
	check(editor.call("row_index") == terminal.get("transcript").size() and editor.caret_column == 0, "block_cursor_starts_on_row_directly_below_ready")
	check(feedback.get("mode") == "ORAC", "right_panel_shows_orac_during_terminal_use")
	var orac: SubViewport = feedback.get("orac_view")
	check(orac.get("indicator_materials").size() == 6 and orac.get("internal_lights").size() == 3, "orac_contains_six_indicator_bulbs_and_three_internal_lights")
	orac.call("animate", 1.0, 0.0, false)
	var first_light: float = orac.get("internal_lights")[0].light_energy
	orac.call("animate", 2.0, 0.0, false)
	check(absf(orac.get("internal_lights")[0].light_energy - first_light) > 0.01, "orac_internal_lights_actually_pulse")
	orac.call("animate", 1.0, 0.0, true)
	first_light = orac.get("internal_lights")[0].light_energy
	orac.call("animate", 2.0, 1.0, true)
	check(orac.get("internal_lights")[0].light_energy == first_light, "reduced_motion_keeps_internal_lights_steady")
	await render_checks(editor, feedback)
	await tap(KEY_UP)
	check(editor.text == "READY." and editor.caret_column == 0, "up_moves_screen_cursor_into_ready_line")
	await tap(KEY_DOWN)
	check(editor.text == "" and editor.call("row_index") == terminal.get("transcript").size(), "down_returns_to_blank_input_row")
	await tap(KEY_RIGHT)
	check(editor.caret_column == 1 and editor.text == " ", "right_moves_into_blank_screen_cell")
	await tap(KEY_LEFT)
	check(editor.caret_column == 0, "left_moves_back_one_cell")
	editor.call("reset_screen_cursor")
	await type_text('PRINT "OLD"')
	await tap(KEY_ENTER)
	await tap(KEY_UP)
	await tap(KEY_UP)
	await tap(KEY_UP)
	check(editor.text == 'PRINT "OLD"', "up_can_revisit_previous_command_not_just_current_input")
	for index in range(7):
		await tap(KEY_RIGHT)
	await type_text("NEW")
	check(editor.text == 'PRINT "NEW"', "typing_overwrites_characters_at_screen_cursor")
	await tap(KEY_ENTER)
	check(terminal.get("transcript").has("NEW"), "return_executes_edited_screen_line")
	await tap(KEY_DOWN)
	check(editor.call("row_index") == terminal.get("transcript").size() and editor.text == "", "down_moves_to_additional_blank_screen_row")
	editor.call("reset_screen_cursor")
	key(KEY_A, true)
	await frames(2)
	check(feedback.get("flashes").has(KEY_A), "physical_key_press_drives_depressed_key_animation")
	capture("terminal-key-down")
	var key_down := root.get_texture().get_image()
	key(KEY_A, false)
	editor.call("reset_screen_cursor")
	await create_timer(0.25).timeout
	check(feedback.get("flashes")[KEY_A] == 0, "key_depression_releases_after_key_up")
	check(changed_pixels(key_down, root.get_texture().get_image(), Rect2(289, 449, 29, 17)) > 50, "key_press_changes_pixels_on_actual_a_key")
	var chirps: int = feedback.get("chatter_count")
	feedback.set("last_chirp", -10.0)
	feedback.call("chirp")
	check(feedback.get("chatter_count") == chirps + 1 and ring.get("last_sound") == "drone_chirp", "orac_chatter_uses_original_electronic_sfx")
	await frames(2)
	capture("terminal-boot-orac")
	await command('LOAD "$",8')
	await create_timer(1.7).timeout
	await command("LIST")
	check(terminal.get("directory_loaded"), "keyboard_loads_virtual_directory")
	check(terminal.get("transcript").has('24 "FAST HACK\'EM" PRG'), "keyboard_list_shows_disk_directory")
	capture("terminal-directory")
	await command("NEW")
	await command("10 FOR I=1 TO 5")
	await command('20 PRINT "HELLO ";I')
	await command("30 NEXT I")
	await command("RUN")
	await frames(6)
	check(terminal.get("transcript").has("HELLO 5"), "keyboard_runs_numbered_basic_program")
	await command("POKE 53280,2:POKE 53281,0")
	check(terminal.get("border_index") == 2 and terminal.get("background_index") == 0, "keyboard_pokes_screen_colours")
	capture("terminal-basic-colours")
	await command("NEW")
	await command("10 GOTO 10")
	await command("RUN")
	await tap(KEY_ESCAPE)
	check(not terminal.get("running") and not game.get("menu_on"), "escape_breaks_basic_without_opening_pause")
	await tap(KEY_ESCAPE)
	check(game.get("menu_on"), "escape_normally_opens_pause")
	await tap(KEY_ESCAPE)
	await command('PRINT "RESUMED"')
	check(terminal.get("transcript").has("RESUMED"), "terminal_recovers_keyboard_focus_after_pause")
	await command('LOAD "FAST HACK\'EM",8,1')
	await create_timer(1.7).timeout
	await command("SYS 49152")
	check(ring.get("loader_step") == 0 and ring.get("help_open"), "keyboard_sys_launches_hack_guide")
	check(ring.get("orac_message") == "", "launch_removes_orac_overlay")
	await frames(2)
	check(feedback.get("mode") == "DEFENDER", "right_panel_switches_to_alien_defender_during_hack")
	var existing_face: Node = feedback.get("defender")
	check(existing_face.get("data").get("format") == "ash_meridian_ai_face" and existing_face.get("nfeat") == 30, "defender_uses_existing_full_detail_narcean_face_asset")
	check(existing_face.get("data").verts.size() == 335 and existing_face.get("data").tris.size() == 571 and existing_face.get("data").edges.size() == 908, "defender_retains_all_full_detail_vertices_triangles_and_edges")
	check(existing_face.get("triangle_indices").size() == 1713, "full_face_triangles_use_one_indexed_render_batch")
	existing_face.call("set_reduced_motion", false)
	existing_face.call("set_time", 0.1)
	check(existing_face.call("blink_amount") > 0.99, "existing_face_closes_eyelids_for_blink")
	existing_face.call("set_time", 0.3)
	check(existing_face.call("blink_amount") == 0, "existing_face_reopens_same_eyes")
	existing_face.call("set_reduced_motion", true)
	existing_face.call("set_time", 0.1)
	check(existing_face.call("blink_amount") == 0, "reduced_motion_disables_alien_blink")
	capture("terminal-alien-defender")
	await tap(KEY_F2)
	check(ring.get("loader_step") == 3, "f2_returns_from_game_to_terminal")
	var emulator: Object = ring.get("emulator")
	var rom_dir := OS.get_environment("ASH_C64_ROM_DIR")
	if not rom_dir.is_empty():
		emulator.set("rom_root", rom_dir.trim_suffix("/") + "/")
		await command("C64")
		check(emulator.get("active"), "keyboard_c64_starts_optional_emulator")
		# Accelerate ROM boot without bypassing the keyboard integration.
		if emulator.get("active"):
			for index in range(500):
				emulator.call("tick", 0.02)
			await frames(3)
			capture("terminal-real-c64")
			await command("POKE 53281,5")
			for index in range(100):
				emulator.call("tick", 0.02)
			check(emulator.get("machine").call("ReadByte", 53281) == 5, "keyboard_command_executes_in_real_rom")
		await tap(KEY_F2)
		check(not emulator.get("active") and ring.get("loader_step") == 3, "f2_releases_emulator_and_restores_shell")
	await command('PRINT "BACK"')
	check(terminal.get("transcript").has("BACK"), "shell_survives_emulator_round_trip")
	game.set("phase", 5)
	await frames(3)
	check(ring.get("loader_step") == 0 and not ring.get("loader_entry").visible and ring.get("orac_message") == "", "scene_exit_clears_terminal_input_and_orac_guidance")
	game.queue_free()
	await frames(2)
	print("SUIT_TERMINAL_INPUT_COMPLETED: ", failures, " failures")
	quit(failures)
