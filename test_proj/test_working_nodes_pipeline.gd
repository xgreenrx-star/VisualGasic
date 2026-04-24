extends SceneTree
# Headless test for the Working Nodes codegen + runtime pipeline.
# Synthesizes a small graph (1 event → 2 actions in 1 group), runs both
# generators, writes outputs to res://_wn_run/, then validates them by:
#   1. Loading the .tscn as a PackedScene and instantiating it.
#   2. Confirming the runtime .vg parses (the VG plugin would normally
#      handle this; here we just check the file is non-empty + readable).
# Exits with code 0 on success, 1 on failure.

const RUN_DIR := "res://_wn_run"
const RUNTIME_SRC := "res://addons/visual_gasic/plugins/working_nodes/wn_runtime.vg"

func _init() -> void:
	var failures: PackedStringArray = []

	# ── Synthetic graph data ──────────────────────────────────────────
	var data := {
		"version": 1,
		"next_node_id": 4,
		"next_group_id": 2,
		"groups": [
			{"id": 1, "name": "Players"},
		],
		"nodes": [
			{
				"name": "ev0", "title": "OnStart",
				"kind": "event", "type": "event",
				"event_type": "ready",
				"position": [0, 0],
				"group": 1,
			},
			{
				"name": "act1", "title": "MovePlayer",
				"kind": "move", "type": "action",
				"position": [200, 0], "group": 1,
				"node_color": "4a90e0",
				"params": {"dx": 100.0, "dy": 0.0, "duration": 0.5},
			},
			{
				"name": "act2", "title": "ColorIt",
				"kind": "color trigger", "type": "action",
				"position": [200, 80], "group": 1,
				"node_color": "e04a90",
				"params": {"r": 255, "g": 100, "b": 50, "duration": 0.3},
			},
		],
		"connections": [
			{"from": "ev0", "from_port": 0, "to": "act1", "to_port": 0},
			{"from": "act1", "from_port": 0, "to": "act2", "to_port": 0},
		],
	}

	# ── Prepare run dir ──────────────────────────────────────────────
	DirAccess.make_dir_recursive_absolute(RUN_DIR)

	# ── Load codegen ─────────────────────────────────────────────────
	var codegen_script: GDScript = load(
		"res://addons/visual_gasic/plugins/working_nodes/working_nodes_codegen.gd"
	)
	if codegen_script == null:
		failures.append("Could not load working_nodes_codegen.gd")
		_finish(failures)
		return

	# ── Generate VG ───────────────────────────────────────────────────
	var vg_code: String = codegen_script.generate_vg_code(data)
	var vg_path := RUN_DIR + "/wn_scene_2d.vg"
	var f_vg := FileAccess.open(vg_path, FileAccess.WRITE)
	if f_vg == null:
		failures.append("Cannot write " + vg_path)
		_finish(failures); return
	f_vg.store_string(vg_code); f_vg.close()
	print("[OK] Wrote ", vg_path, " (", vg_code.length(), " chars)")

	# Sanity: VG output should reference at least one WN_ Sub call.
	if not vg_code.contains("WN_"):
		failures.append("Generated VG does not reference any WN_ runtime Sub")

	# ── Generate scene ────────────────────────────────────────────────
	var tscn: String = codegen_script.generate_scene_2d_tscn(data, vg_path, "Node2D")
	var tscn_path := RUN_DIR + "/wn_scene_2d.tscn"
	var f_tscn := FileAccess.open(tscn_path, FileAccess.WRITE)
	if f_tscn == null:
		failures.append("Cannot write " + tscn_path)
		_finish(failures); return
	f_tscn.store_string(tscn); f_tscn.close()
	print("[OK] Wrote ", tscn_path, " (", tscn.length(), " chars)")

	# Sanity: tscn must include scene-group tag and visible node type.
	if not tscn.contains("wn_group_1"):
		failures.append("Scene .tscn missing 'wn_group_1' group tag")
	if not tscn.contains("ColorRect"):
		failures.append("Scene .tscn missing visible ColorRect nodes")
	if not tscn.contains("Camera2D"):
		failures.append("Scene .tscn missing Camera2D")

	# ── Copy runtime ──────────────────────────────────────────────────
	var f_in := FileAccess.open(RUNTIME_SRC, FileAccess.READ)
	if f_in == null:
		failures.append("Cannot read runtime: " + RUNTIME_SRC)
		_finish(failures); return
	var rt_bytes := f_in.get_buffer(f_in.get_length()); f_in.close()
	var rt_dst := RUN_DIR + "/wn_runtime.vg"
	var f_out := FileAccess.open(rt_dst, FileAccess.WRITE)
	if f_out == null:
		failures.append("Cannot write runtime to " + rt_dst)
		_finish(failures); return
	f_out.store_buffer(rt_bytes); f_out.close()
	print("[OK] Copied runtime → ", rt_dst, " (", rt_bytes.size(), " bytes)")

	# ── Validate scene loads as PackedScene ──────────────────────────
	# The script ExtResource points to a .vg file; without the VG plugin
	# loaded, that resource won't resolve to a Script. We strip the
	# script line for validation purposes only — the original written
	# scene still has it for in-editor playback.
	var tscn_no_script := _strip_script_resource(tscn)
	var validate_path := RUN_DIR + "/wn_scene_2d_validate.tscn"
	var f_v := FileAccess.open(validate_path, FileAccess.WRITE)
	if f_v == null:
		failures.append("Cannot write validation scene")
		_finish(failures); return
	f_v.store_string(tscn_no_script); f_v.close()

	var packed: PackedScene = ResourceLoader.load(validate_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	if packed == null:
		failures.append("PackedScene failed to load: " + validate_path)
	else:
		var inst := packed.instantiate()
		if inst == null:
			failures.append("PackedScene failed to instantiate")
		else:
			# Recursively walk the instantiated subtree using get_groups()
			# which DOES reflect scene-baked groups even before the node
			# enters the live SceneTree.
			var n_in_group := _gather_group(inst, "wn_group_1")
			if n_in_group < 2:
				failures.append("Expected >=2 nodes in wn_group_1, got %d (groups walk)" % n_in_group)
			else:
				print("[OK] Scene has ", n_in_group, " nodes tagged wn_group_1")
			inst.free()

	_finish(failures)


func _gather_group(node: Node, group: String) -> int:
	var n := 1 if (group in node.get_groups()) else 0
	for c in node.get_children():
		n += _gather_group(c, group)
	return n


func _count_group(_node: Node, _group: String, _acc: int) -> void:
	pass


func _strip_script_resource(tscn: String) -> String:
	# Remove the [ext_resource ... .vg ...] line and the "script = ExtResource(...)"
	# assignment so PackedScene loads without needing the VG plugin.
	var out: PackedStringArray = []
	for line in tscn.split("\n"):
		if line.begins_with("[ext_resource") and line.contains(".vg"):
			continue
		if line.strip_edges().begins_with("script = ExtResource"):
			continue
		out.append(line)
	return "\n".join(Array(out))


func _finish(failures: PackedStringArray) -> void:
	print("")
	print("══════════════════════════════════════════════════════════════")
	if failures.is_empty():
		print("✓ ALL CHECKS PASSED")
		quit(0)
	else:
		print("✗ FAILURES:")
		for f in failures:
			print("  - ", f)
		quit(1)
