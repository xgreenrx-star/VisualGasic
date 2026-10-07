## build_bluescreen.gd
## Run headlessly to generate the BlueScreen AGCK game scaffold.
## Usage:
##   ./Godot_v4.6.1-stable_linux.x86_64 --headless --path samples/internal/AGCK_Tests -s res://build_bluescreen.gd
extends SceneTree

func _init() -> void:
	print("=== BLUE SCREEN — AGCK Build Script ===")

	# Load the backend
	var BackendClass = load("res://addons/visual_gasic/plugins/agck/agck_builder_backend.gd")
	if BackendClass == null:
		printerr("ERROR: Could not load agck_builder_backend.gd")
		quit(1)
		return
	var backend = BackendClass.new()

	# Load the .agck project file
	var agck_path = "res://blue_screen.agck"
	var f = FileAccess.open(agck_path, FileAccess.READ)
	if f == null:
		printerr("ERROR: Could not open " + agck_path)
		quit(1)
		return
	var json_text = f.get_as_text()
	f.close()

	var game_data = JSON.parse_string(json_text)
	if game_data == null:
		printerr("ERROR: JSON parse failed for " + agck_path)
		quit(1)
		return

	print("Game: ", game_data.get("settings", {}).get("game_title", "?"))
	print("Actors: ", game_data.get("actors", []).size())
	print("Levels: ", game_data.get("levels", []).size())
	print("Building...")

	var TileLibraryClass = load("res://addons/visual_gasic/plugins/agck/agck_tile_library.gd")
	if TileLibraryClass == null:
		printerr("ERROR: Could not load AGCK tile library")
		quit(1)
		return
	var tile_library = TileLibraryClass.new()
	tile_library.set_data(game_data.get("tile_library", {}))
	tile_library.tile_render_size = int(game_data.get("settings", {}).get("tile_size", 32))
	tile_library.actor_frame_size = int(game_data.get("settings", {}).get("actor_frame_size", 32))
	backend.tile_library = tile_library
	var result = backend.build(game_data)

	if result.get("ok", false):
		print("=== BUILD OK ===")
		print("Output dir: ", result.get("output_dir", "?"))
		print("Files generated: ", result.get("files", []).size())
		for fpath in result.get("files", []):
			if not FileAccess.file_exists(fpath):
				printerr("ERROR: Builder reported a missing output: " + str(fpath))
				quit(1)
				return
			print("  ", fpath)
		var repair_tool = load("res://repair_generated_build.gd")
		if repair_tool == null or not repair_tool.repair(str(result["output_dir"])):
			printerr("Generated build repair failed.")
			quit(1)
			return
	else:
		printerr("=== BUILD FAILED ===")
		print("Result: ", result)
		quit(1)
		return

	quit(0)
