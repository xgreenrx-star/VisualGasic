## build_bluescreen.gd
## Run headlessly to generate the BlueScreen AGCK game scaffold.
## Usage:
##   ./Godot_v4.6.1-stable_linux.x86_64 --headless --path game_projects/AGCK_Tests -s build_bluescreen.gd
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

	var result = backend.build(game_data)

	if result.get("ok", false):
		print("=== BUILD OK ===")
		print("Output dir: ", result.get("output_dir", "?"))
		print("Files generated: ", result.get("files", []).size())
		for fpath in result.get("files", []):
			print("  ", fpath)
	else:
		printerr("=== BUILD FAILED ===")
		print("Result: ", result)
		quit(1)
		return

	quit(0)
