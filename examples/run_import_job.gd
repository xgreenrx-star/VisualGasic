
extends SceneTree

func _init():
	print("Running headless import job...")
	
	# Load Importer
	var importer = load("res://addons/visual_gasic/vb6_importer.gd")
	if not importer:
		print("Error: Could not load importer script")
		quit(1)
		return
		
	# Target File
	var project_path = "/home/Commodore/Documents/VisualGasic/Calculator-vb6-main/calculate.vbp"
	
	if not FileAccess.file_exists(project_path):
		print("Error: Missing target project file: " + project_path)
		quit(1)
		return

	# Run Import
	print("Starting import of: " + project_path)
	importer.import_project(project_path)
	
	print("Import Job Finished.")
	quit(0)
