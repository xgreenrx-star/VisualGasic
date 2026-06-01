extends SceneTree

# Runtime test: instantiate enemies and check groups + movement
# Run with: godot --headless --path . -s test_enemy_spawn2.gd

var _frame := 0
var _results := []

func _initialize():
	print("=== ENEMY SPAWN RUNTIME TEST v2 ===")
	print("Engine.is_editor_hint() = ", Engine.is_editor_hint())
	
	var overflow_path = "res://build/BLUE_SCREEN/actors/Actor_Overflow.tscn"
	var datebug_path  = "res://build/BLUE_SCREEN/actors/Actor_DateBug.tscn"
	
	# Add a root Node2D for the enemies to live in
	var level = Node2D.new()
	level.name = "Level"
	get_root().add_child(level)
	
	for path in [overflow_path, datebug_path]:
		print("\n--- Testing: ", path.get_file(), " ---")
		var scn = load(path)
		if scn == null:
			print("FAIL: load returned null")
			continue
		
		var inst = scn.instantiate()
		if inst == null:
			print("FAIL: instantiate returned null")
			continue
		
		inst.position = Vector2(300, 240)
		level.add_child(inst)
		
		# Give it a moment — but _ready() should be synchronous
		# Check groups immediately
		print("  Immediately after add_child:")
		print("  is_in_group('enemies') = ", inst.is_in_group("enemies"))
		
		_results.append({"inst": inst, "path": path})
	
	# Advance 3 frames to let _ready() callbacks settle
	_frame = 0

func _process(_delta):
	_frame += 1
	if _frame < 3:
		return
	
	print("\n=== After 3 frames ===")
	for r in _results:
		var inst = r["inst"]
		var path = r["path"]
		print("\n[", path.get_file(), "]")
		
		if not is_instance_valid(inst):
			print("  FAIL: instance was freed (died immediately?)")
			continue
		
		if inst.is_in_group("enemies"):
			print("  OK: is_in_group('enemies')")
		else:
			print("  FAIL: NOT in group 'enemies'")
		
		if inst.visible:
			print("  OK: visible=true")
		else:
			print("  FAIL: visible=false")
		
		print("  position = ", inst.position)
		print("  velocity = ", inst.velocity)
	
	print("\n=== DONE ===")
	quit()
