extends SceneTree

func _init():
	var script = load("res://test_buf_minimal.vg")
	if script == null:
		push_error("Failed to load script")
		quit()
		return
	
	# Dump bytecode to see what opcodes were emitted
	var info = script.debug_dump_bytecode("TestBuf")
	if info.has("error"):
		print("Bytecode error: ", info["error"])
		quit()
		return
	
	var code: PackedByteArray = info["code"]
	print("Bytecode for TestBuf (", code.size(), " bytes):")
	var hex = ""
	for i in range(min(code.size(), 60)):
		hex += "%02x " % code[i]
	print(hex)
	
	# Print constants
	if info.has("constants"):
		print("Constants: ", info["constants"])
	if info.has("local_names"):
		print("Locals: ", info["local_names"])
	
	# OP_BUF_ALLOC should be present if buffer fast-path is used
	# Check the opcode enum values
	# Also try running it
	var node = Node.new()
	node.set_script(script)
	var result = node.call("TestBuf")
	print("TestBuf result: ", result)
	quit()
