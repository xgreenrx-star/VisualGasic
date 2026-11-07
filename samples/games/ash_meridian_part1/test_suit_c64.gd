extends SceneTree

var failures := 0

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok:
		failures += 1

func screen_text(machine: Object) -> String:
	var text := ""
	for index in range(1000):
		var code: int = machine.call("PeekRAM", 1024 + index) & 127
		if code >= 1 and code <= 26:
			text += String.chr(code + 64)
		elif code >= 32 and code <= 63:
			text += String.chr(code)
		else:
			text += " "
	return text

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set("dev_i", 21)
	game.call("WarpDev")
	var ring: Object = game.get("ownership_ring")
	var emulator: Object = ring.get("emulator")
	emulator.set("rom_root", "user://missing-c64-roms/")
	check(not emulator.call("start_emulator"), "missing_roms_rejected")
	check(str(emulator.get("last_error")).contains("ROMS MISSING"), "missing_roms_explained")
	var rom_dir := OS.get_environment("ASH_C64_ROM_DIR")
	if not rom_dir.is_empty():
		emulator.set("rom_root", rom_dir.trim_suffix("/") + "/")
		check(emulator.call("start_emulator"), "user_roms_boot_optional_native_core")
		if emulator.get("active"):
			for index in range(500):
				emulator.call("tick", 0.02)
			var machine: Object = emulator.get("machine")
			print("C64_BOOT_SCREEN: ", screen_text(machine))
			check(screen_text(machine).contains("READY."), "real_rom_reaches_ready")
			var cursor_row: int = machine.call("PeekRAM", 214)
			var cursor_column: int = machine.call("PeekRAM", 211)
			for pair in [[17, 214, cursor_row + 1], [145, 214, cursor_row], [29, 211, cursor_column + 1], [157, 211, cursor_column]]:
				check(emulator.call("queue_key", pair[0]), "real_rom_accepts_cursor_control_" + str(pair[0]))
				for index in range(25):
					emulator.call("tick", 0.02)
				check(machine.call("PeekRAM", pair[1]) == pair[2], "real_rom_moves_screen_cursor_" + str(pair[0]))
			check(emulator.call("submit", "POKE 53281,2"), "real_basic_accepts_typed_command")
			for index in range(100):
				emulator.call("tick", 0.02)
			check(machine.call("ReadByte", 53281) == 2, "real_rom_executes_colour_poke")
			for line in ['10 FOR I=1 TO 3', '20 PRINT "ROM TEST";I', "30 NEXT I", "RUN"]:
				check(emulator.call("submit", line), "real_basic_accepts_" + line)
				for index in range(100):
					emulator.call("tick", 0.02)
			check(screen_text(machine).contains("ROM TEST 3"), "real_rom_runs_numbered_for_program")
			var image: Image = emulator.get("texture").get_image()
			check(image.get_size() == Vector2i(384, 272), "native_framebuffer_available_to_suit_screen")
			ring.call("tick", game.get("presentation"), 0.0)
			emulator.call("stop_emulator")
			check(not emulator.get("active") and emulator.get("machine") == null, "exit_releases_native_machine")
	else:
		print("SKIP: optional real-ROM checks; set ASH_C64_ROM_DIR to your own ROM directory")
	game.queue_free()
	await process_frame
	print("SUIT_C64_COMPLETED: ", failures, " failures")
	quit(failures)
