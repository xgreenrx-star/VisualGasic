extends SceneTree

var game_node: Node2D
var frame := 0

func _init():
	print("=== Galactic Defender Automated Test ===")
	
	# Load and instance the main scene
	var scene = load("res://main.tscn")
	if scene == null:
		print("[FAIL] Could not load main.tscn")
		quit()
		return
	
	game_node = scene.instantiate()
	root.add_child(game_node)
	print("[OK] Scene instantiated, _Ready should have run")

func _process(delta):
	frame += 1
	
	if frame == 3:
		# By now _Ready has run, game should be initialized
		# Check variables
		var gs = game_node.get("gameState")
		var w = game_node.get("wave")
		var ec = game_node.get("enemyCount")
		var g = game_node.get("gold")
		var l = game_node.get("lives")
		print("[Frame 3] gameState=%s wave=%s enemyCount=%s gold=%s lives=%s" % [gs, w, ec, g, l])
		
		# Force start wave by calling StartNextWave
		print("[Frame 3] Calling StartNextWave...")
		game_node.call("StartNextWave")
		
		gs = game_node.get("gameState")
		w = game_node.get("wave")
		ec = game_node.get("enemyCount")
		var tspawn = game_node.get("totalSpawnThisWave")
		print("[Frame 3 after StartNextWave] gameState=%s wave=%s enemyCount=%s totalSpawn=%s" % [gs, w, ec, tspawn])
		
		# If gameState is still building, force it to combat
		if gs != "combat":
			print("[WARNING] gameState was not 'combat'! Forcing it...")
			game_node.set("gameState", "combat")
			gs = game_node.get("gameState")
			print("[Frame 3 forced] gameState=%s" % [gs])
	
	if frame >= 5 and frame <= 60:
		# Run _Process to let enemies spawn and move
		var ec = game_node.get("enemyCount")
		var si = game_node.get("spawnIndex")
		var gs = game_node.get("gameState")
		var w = game_node.get("wave")
		if frame % 10 == 0:
			print("[Frame %d] gameState=%s wave=%s enemyCount=%s spawnIndex=%s" % [frame, gs, w, ec, si])
	
	if frame == 80:
		# Check final state
		var gs = game_node.get("gameState")
		var w = game_node.get("wave")
		var ec = game_node.get("enemyCount")
		var l = game_node.get("lives")
		print("[Frame 80 FINAL] gameState=%s wave=%s enemyCount=%s lives=%s" % [gs, w, ec, l])
		print("=== Test Complete ===")
		quit()
