extends SceneTree

# Headless Zork command tester
# Loads the Zork scene, sends commands via text_submitted, captures errors

var errors := []
var output_lines := []
var cmd_input  # untyped to avoid headless type mismatch
var zork_root  # untyped - may be Node or Control in headless
var output_label  # RichTextLabel for capturing game output
var command_queue := []
var current_cmd_idx := 0
var frames_waited := 0
var last_output_text := ""

func _init():
	# We need to manually load the Zork scene since -s replaces the main scene
	# Comprehensive list of Zork commands to test
	command_queue = [
		# Basic movement
		"look",
		"north",
		"south",
		"east",
		"west",
		"up",
		"down",
		"northeast",
		"northwest",
		"southeast",
		"southwest",
		# Basic interactions at West of House
		"look",
		"examine mailbox",
		"open mailbox",
		"look",
		"get leaflet",
		"read leaflet",
		"inventory",
		"drop leaflet",
		"examine house",
		"examine door",
		"examine window",
		# Movement exploration
		"north",
		"look",
		"south",
		"south",
		"look",
		"north",
		"west",
		"look",
		"east",
		"east",
		"look",
		"open window",
		# Try entering
		"enter",
		"in",
		"west",
		# If inside, explore
		"look",
		"get all",
		"take lamp",
		"take sword",
		"examine lamp",
		"turn on lamp",
		"turn off lamp",
		"turn on lamp",
		# More movement
		"up",
		"look",
		"down",
		"down",
		"look",
		# More commands
		"close mailbox",
		"open mailbox",
		"get leaflet",
		# Combat-related
		"attack troll",
		"attack troll with sword",
		# Preposition commands
		"put sword in mailbox",
		"put leaflet in mailbox",
		# Verb tests
		"eat",
		"eat leaflet",
		"drink",
		"drink water",
		"climb tree",
		"swim",
		"dig",
		"pray",
		"wave",
		"wave sword",
		"say hello",
		"say odysseus",
		"say echo",
		# Score/status
		"score",
		"diagnose",
		"verbose",
		"brief",
		"help",
		"wait",
		# Multi-word commands
		"look at mailbox",
		"look in mailbox",
		"pick up leaflet",
		"turn on lamp",
		"turn off lamp",
		# Edge cases
		"",
		"xyzzy",
		"plugh",
		"north north",
		"get the leaflet",
		"open the mailbox",
		# Save/restore
		"save",
		"restore",
		# Give/throw
		"give sword",
		"throw lamp",
		# Move
		"move rug",
		# Ring
		"ring bell",
		# Tie
		"tie rope to railing",
		# Lock/Unlock
		"lock door",
		"unlock door",
		# Inflate
		"inflate boat",
		# TTS toggle
		"tts",
		# Quit
		"quit",
	]

func _process(delta):
	frames_waited += 1
	
	# Wait 10 frames for scene + VG script to fully initialize
	if frames_waited < 10:
		return
	
	# First frame after init: load scene and find controls
	if frames_waited == 10:
		var root_win = get_root()
		
		# Manually load and instantiate the Zork scene
		var scene = load("res://main.tscn")
		if scene == null:
			printerr("[TEST] ERROR: Could not load res://main.tscn")
			print_results()
			quit(1)
			return
		
		zork_root = scene.instantiate()
		if zork_root == null:
			printerr("[TEST] ERROR: Could not instantiate main.tscn")
			print_results()
			quit(1)
			return
		
		root_win.add_child(zork_root)
		print("[TEST] Scene loaded: %s (%s)" % [zork_root.name, zork_root.get_class()])
		
		# Wait more frames for Form_Load to run
		return
	
	# Wait for Form_Load to complete (a few more frames)
	if frames_waited < 15:
		return
	
	# Frame 15: find controls
	if frames_waited == 15:
		
		# List all children for debugging
		for i in range(zork_root.get_child_count()):
			var c = zork_root.get_child(i)
			print("[TEST]   child[%d]: %s (%s)" % [i, c.name, c.get_class()])
		
		cmd_input = zork_root.find_child("CmdInput", true, false)
		output_label = zork_root.find_child("Output", true, false)
		
		if cmd_input == null:
			printerr("[TEST] ERROR: CmdInput not found in scene tree!")
			# Try to dump entire tree
			_dump_tree(zork_root, "  ")
			print_results()
			quit(1)
			return
		
		print("[TEST] CmdInput found: %s (class: %s)" % [cmd_input.name, cmd_input.get_class()])
		if output_label:
			print("[TEST] Output found: %s (class: %s)" % [output_label.name, output_label.get_class()])
			last_output_text = output_label.text if output_label.has_method("get_text") or "text" in output_label else ""
		
		print("[TEST] Running %d commands..." % command_queue.size())
		print("")
		return
	
	# Send one command per frame (with spacing for processing)
	if current_cmd_idx < command_queue.size():
		# Wait an extra frame between commands for processing
		if (frames_waited - 10) % 2 == 0:
			return
		
		var cmd = command_queue[current_cmd_idx]
		current_cmd_idx += 1
		
		if cmd.is_empty():
			return
		
		# Capture output before command
		var pre_output = ""
		if output_label and output_label.get("text") != null:
			pre_output = output_label.text
		
		print("[CMD %d] > %s" % [current_cmd_idx, cmd])
		
		# Simulate text_submitted signal (same as pressing Enter on LineEdit)
		if cmd_input.has_method("set"):
			cmd_input.set("text", cmd)
		cmd_input.emit_signal("text_submitted", cmd)
		
		# Capture output after command (may need next frame for full output)
		if output_label and output_label.get("text") != null:
			var post_output = output_label.text
			if post_output != pre_output:
				var new_text = post_output.substr(pre_output.length())
				if new_text.length() > 0:
					# Print just the new game output
					for line in new_text.split("\n"):
						if line.strip_edges().length() > 0:
							print("  [OUT] %s" % line.strip_edges())
		
		return
	
	# All commands sent, wait a few more frames for final output then print results
	if current_cmd_idx >= command_queue.size():
		if frames_waited > (command_queue.size() * 2) + 30:
			# Print final game output
			if output_label and output_label.get("text") != null:
				print("\n[TEST] === FINAL GAME OUTPUT ===")
				var full_text = output_label.text
				var lines = full_text.split("\n")
				for line in lines:
					print("  %s" % line)
			print_results()
			quit(0)

func _dump_tree(node, indent):
	print("[TEST] %s%s (%s)" % [indent, node.name, node.get_class()])
	for i in range(node.get_child_count()):
		_dump_tree(node.get_child(i), indent + "  ")

func print_results():
	print("\n" + "=".repeat(60))
	print("ZORK HEADLESS TEST RESULTS")
	print("=".repeat(60))
	print("Commands tested: %d" % command_queue.size())
	
	# Check Godot error log for runtime errors
	print("\nTest completed. Check output above for [VG] errors and Runtime Errors.")
	print("=".repeat(60))
