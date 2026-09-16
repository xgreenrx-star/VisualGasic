extends SceneTree

func dump(script: Script, name: String) -> void:
	var info: Dictionary = script.call("debug_dump_bytecode", name)
	print("=== ", name, " ===")
	if info.has("error"):
		print("  error: ", info["error"])
		return
	print("  local_count=", info.get("local_count", -1),
		" local_names=", info.get("local_names", []),
		" local_types=", info.get("local_types", []))
	print("  constants=", info.get("constants", []))
	var instrs: Array = info.get("instructions", [])
	for inst in instrs:
		print("  [", inst.get("offset", -1), "] ", inst.get("name", "?"),
			"  ops=", inst.get("operands", []), "  ; ", inst.get("detail", ""))

func _init():
	var script: Script = load("res://bench.vg")
	if script == null:
		push_error("Failed to load bench.vg")
		quit(65)
		return
	# Instantiate so the compiler builds chunks.
	var node := Node.new()
	node.set_script(script)
	root.add_child(node)
	dump(script, "BenchCallHelper")
	dump(script, "BenchCall")
	root.remove_child(node)
	node.queue_free()
	quit(0)
