extends SceneTree

func _init():
	print("=== Galactic Defender Load Test ===")
	
	# Create the VG script
	var vg = load("res://galactic_defender.vg")
	if vg == null:
		# Try VisualGasicScript directly
		vg = VisualGasicScript.new()
		vg.source_code = FileAccess.open("res://galactic_defender.vg", FileAccess.READ).get_as_text()
		vg.reload()
	
	if vg:
		print("[OK] Script loaded successfully")
		print("Source length: " + str(vg.source_code.length()) + " chars")
	else:
		print("[FAIL] Could not load script")
	
	quit()
