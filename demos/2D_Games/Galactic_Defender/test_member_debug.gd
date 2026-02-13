extends SceneTree

var frame := 0
var node : Node2D

func _init():
	print("=== Galactic Defender Combat Member Test ===")
	
	var vg = VisualGasicScript.new()
	vg.source_code = FileAccess.open("res://galactic_defender.vg", FileAccess.READ).get_as_text()
	vg.reload()
	
	node = Node2D.new()
	node.set_script(vg)
	root.add_child(node)
	
	await process_frame
	
	# Trigger combat: call StartNextWave then SpawnNextEnemy manually
	print("--- Starting wave ---")
	node.call("StartNextWave")
	
	await process_frame
	
	# Now spawner should be active, call SpawnNextEnemy directly
	print("--- Spawning enemy ---")
	node.call("SpawnNextEnemy")
	
	await process_frame
	
	print("[OK] No member assignment errors!")
	quit(0)
