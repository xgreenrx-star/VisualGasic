## validate_bluescreen.gd
## Loads all BLUE SCREEN VG scripts to check for parse errors.
## Usage: ./Godot_v4.6.1-stable_linux.x86_64 --headless --path game_projects/AGCK_Tests -s validate_bluescreen.gd
extends SceneTree

func _init() -> void:
	print("=== BLUE SCREEN — Script Validation ===")
	var scripts = [
		"res://build/BLUE_SCREEN/Main.vg",
		"res://build/BLUE_SCREEN/actors/Actor_Hero.vg",
		"res://build/BLUE_SCREEN/actors/Actor_Overflow.vg",
		"res://build/BLUE_SCREEN/actors/Actor_DateBug.vg",
		"res://build/BLUE_SCREEN/actors/Actor_XPOrb.vg",
		"res://build/BLUE_SCREEN/actors/Actor_Bullet.vg",
	]
	var ok = true
	for path in scripts:
		var s = load(path)
		if s == null:
			printerr("FAIL: Could not load " + path)
			ok = false
		else:
			print("OK:   " + path)
	if ok:
		print("=== ALL OK ===")
	else:
		print("=== ERRORS DETECTED ===")
	quit(0 if ok else 1)
