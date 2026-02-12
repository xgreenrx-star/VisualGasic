extends SceneTree

func _init():
	print("=== Galactic Defender Load Test ===")
	
	# Load the VG source file directly
	var path = "/home/Commodore/Documents/VisualGasic/demos/2D_Games/Galactic_Defender/galactic_defender.vg"
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("[FAIL] Could not open file: " + path)
		quit()
		return
	
	var source = file.get_as_text()
	file.close()
	print("Source loaded: " + str(source.length()) + " chars, " + str(source.count("\n")) + " lines")
	
	# Create VisualGasicScript and parse
	var vgs = VisualGasicScript.new()
	vgs.source_code = source
	vgs.reload()
	
	# Validate
	var result = vgs._validate("", source)
	var valid = result.get("valid", false)
	var errors = result.get("errors", [])
	var warnings = result.get("warnings", [])
	var functions = result.get("functions", [])
	
	print("")
	if valid:
		print("[PASS] Script is VALID")
	else:
		print("[FAIL] Script has errors:")
		for err in errors:
			print("  ERROR: " + str(err))
	
	if warnings.size() > 0:
		print("Warnings: " + str(warnings.size()))
		for w in warnings:
			print("  WARN: " + str(w))
	
	print("Functions found: " + str(functions.size()))
	for f in functions:
		print("  - " + str(f))
	
	print("")
	print("=== Load Test Complete ===")
	quit()
