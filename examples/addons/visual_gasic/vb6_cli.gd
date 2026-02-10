extends SceneTree

func _init():
	var args = OS.get_cmdline_args()
	var vbp_path = ""
	
	for i in range(args.size()):
		if args[i] == "--import-vbp" and i + 1 < args.size():
			vbp_path = args[i+1]
			break
			
	if vbp_path == "":
		print("Usage: godot --headless -s addons/visual_gasic/vb6_cli.gd --import-vbp <path_to_vbp>")
		quit()
		return
		
	print("Starting CLI Import for: " + vbp_path)
	
	var importer = load("res://addons/visual_gasic/vb6_importer.gd")
	if !importer:
		print("Error: Could not load vb6_importer.gd")
		quit()
		return
		
	# Create directories if they don't exist
	DirAccess.make_dir_recursive_absolute("res://start_forms")
	DirAccess.make_dir_recursive_absolute("res://mixed")
	
	importer.import_project(vbp_path)
	
	print("Import Finished successfully.")
	quit()
