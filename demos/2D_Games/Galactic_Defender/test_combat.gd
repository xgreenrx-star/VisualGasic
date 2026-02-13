extends Node2D

var vg_script : VisualGasicScript
var frame_count := 0
var wave_started := false

func _ready():
	print("=== Galactic Defender Combat Test ===")

func _process(delta):
	frame_count += 1
	
	# After 5 frames, set the gameState variable directly to trigger combat
	if frame_count == 5 and not wave_started:
		print("Force-starting wave via variable injection...")
		# Call StartNextWave 
		call("StartNextWave")
		wave_started = true
	
	if frame_count >= 120:
		print("[OK] Combat test complete after ", frame_count, " frames")
		get_tree().quit()
