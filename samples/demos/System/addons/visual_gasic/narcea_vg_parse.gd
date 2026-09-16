extends RefCounted
class_name NarceaVgParse
## Shared VG parse + optional scene smoke checks for Narcea harnesses.
## Mirrors bench/ai_correctness/checkers/check_vg.sh in-process.


static func check_parse(vg_path: String) -> Dictionary:
	if vg_path.is_empty():
		return {"ok": false, "error": "empty path"}
	if not FileAccess.file_exists(vg_path):
		return {"ok": false, "error": "missing: %s" % vg_path}
	var script: Variant = load(vg_path)
	if script == null:
		return {"ok": false, "error": "load() returned null for %s" % vg_path}
	return {"ok": true, "error": ""}


static func smoke_run_scene(tree: SceneTree, scene_path: String, hold_ms: int = 2000) -> Dictionary:
	if scene_path.is_empty() or not FileAccess.file_exists(scene_path):
		return {"ok": false, "error": "scene missing: %s" % scene_path}
	var packed: Variant = load(scene_path)
	if packed == null:
		return {"ok": false, "error": "scene load failed: %s" % scene_path}
	var inst: Node = packed.instantiate()
	if inst == null:
		return {"ok": false, "error": "instantiate failed: %s" % scene_path}
	tree.root.add_child(inst)
	var deadline := Time.get_ticks_msec() + hold_ms
	while Time.get_ticks_msec() < deadline:
		OS.delay_msec(16)
		if not is_instance_valid(inst):
			return {"ok": false, "error": "scene freed early: %s" % scene_path}
	inst.queue_free()
	return {"ok": true, "error": ""}


static func primary_vg_in_written(written: Array, root: String) -> String:
	for w in written:
		var p := str(w)
		if p.ends_with(".vg"):
			return p
	if root.ends_with("/"):
		return root + "Game.vg"
	return root + "/Game.vg"
