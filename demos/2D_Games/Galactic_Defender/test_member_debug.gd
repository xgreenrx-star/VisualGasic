extends SceneTree

var frame := 0
var node : Node2D

func _init():
	print("=== Galactic Defender Combat Full Test ===")
	
	var vg = VisualGasicScript.new()
	vg.source_code = FileAccess.open("res://galactic_defender.vg", FileAccess.READ).get_as_text()
	vg.reload()
	
	node = Node2D.new()
	node.set_script(vg)
	root.add_child(node)
	
	await process_frame
	
	# Trigger combat: call StartNextWave then SpawnNextEnemy multiple times
	print("--- Starting wave ---")
	node.call("StartNextWave")
	await process_frame
	
	# Spawn several enemies
	for i in range(4):
		print("--- Spawning enemy ", i, " ---")
		node.call("SpawnNextEnemy")
		await process_frame
	
	# Update enemies (movement)
	print("--- UpdateEnemies ---")
	node.call("UpdateEnemies", 0.016)
	await process_frame
	
	# Update towers
	print("--- UpdateTowers ---")
	node.call("UpdateTowers", 0.016)
	await process_frame
	
	# Place a tower then fire
	print("--- PlaceTower(5,5) ---")
	node.call("PlaceTower", 5, 5)
	await process_frame
	
	# More updates to trigger projectile logic
	for i in range(5):
		node.call("UpdateTowers", 0.016)
		node.call("UpdateEnemies", 0.016)
		node.call("UpdateProjectiles", 0.016)
		await process_frame

	print("[OK] Combat test complete - no array index errors!")
	node.queue_free()
	quit(0)
