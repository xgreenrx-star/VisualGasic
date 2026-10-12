extends SceneTree

## Phase 5: a copied Crystal Caverns gets one Whenever edit, a change card,
## a headless check, and a rollback. The showcase originals are not modified.
const OLD_LINE := "Whenever Section UnlockExit crystals Becomes GEM_TARGET OnUnlockExit"
const NEW_LINE := "Whenever Section UnlockExit crystals Becomes 5 OnUnlockExit"
const ADDON := "/home/Commodore/Documents/VisualGasic/addons/visual_gasic"

var failures := 0
var checks := 0
var _copy := ""


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if ok:
		return
	failures += 1
	push_error("FAIL: " + what)


func _run() -> void:
	var CS = load("res://addons/visual_gasic/vg_change_set.gd")
	var Card = load("res://addons/visual_gasic/vg_change_card.gd")
	var Safe = load("res://addons/visual_gasic/vg_ai_safe_write.gd")
	var Runner = load("res://addons/visual_gasic/vg_change_runner.gd")
	if CS == null or Card == null or Safe == null or Runner == null:
		push_error("FAIL: change card scripts are not loaded")
		quit(1)
		return
	var src := ProjectSettings.globalize_path("res://")
	_copy = "/tmp/vg-cc-card-%d" % Time.get_ticks_msec()
	var copied: Array = []
	var err := OS.execute("rsync", ["-a", "--exclude", ".godot", src, _copy], copied, true)
	check(err == OK, "copy the showcase, err %s" % str(err))
	var link := _copy.path_join("addons/visual_gasic")
	OS.execute("rm", ["-rf", link], [], true)
	var linked: Array = []
	var lerr := OS.execute("ln", ["-sfn", ADDON, link], linked, true)
	check(lerr == OK, "retarget the addon link")
	DirAccess.make_dir_recursive_absolute(_copy.path_join(".godot"))
	var ext := FileAccess.open(_copy.path_join(".godot/extension_list.cfg"), FileAccess.WRITE)
	ext.store_string("res://addons/visual_gasic/plugins/vgmusic/libgdsion.gdextension\nres://addons/visual_gasic/visual_gasic.gdextension\n")
	ext.close()
	var caverns := _copy.path_join("Caverns.vg")
	var original := FileAccess.get_file_as_bytes(caverns)
	var original_text := original.get_string_from_utf8()
	check(original_text.find(OLD_LINE) >= 0, "copied Caverns.vg still has the GEM_TARGET trigger")
	CS.set_store_root(ProjectSettings.globalize_path("user://vg_cc_change_sets"))
	CS.set_rollback_root(_copy)
	CS.drop_memory()
	var safe = Safe.new()
	safe.set_root(_copy)
	var updated := original_text.replace(OLD_LINE, NEW_LINE)
	var id: String = CS.begin("UnlockExit target", "make_code", "Change UnlockExit to 5")
	var wrote: Array = safe.write(caverns, updated)
	check(bool(wrote[0]), "SafeWrite applies the copied trigger edit")
	CS.end()
	var pending := _card_text(CS, Card, id, original_text, updated, "not run", {})
	check(pending.find("trigger changed") >= 0, "card reports trigger changed")
	check(pending.find("GEM_TARGET") >= 0 and pending.find("5") >= 0, "card shows GEM_TARGET and 5")
	check(pending.find("not run since change") >= 0, "card says not run since change")
	var first: Dictionary = await _run_exit(Runner)
	print("COPIED EXIT AFTER EDIT: %s" % str(first.get("status", "")))
	var shown := "fail" if str(first.get("status", "")) == "fail" else str(first.get("status", "incomplete"))
	var before_card := _card_text(CS, Card, id, original_text, updated, shown, first)
	print("----- CARD BEFORE ROLLBACK -----")
	print(before_card)
	print("----- END CARD -----")
	if str(first.get("status", "")) == "pass":
		print("REPORT: copied exit scenario still passes after Becomes 5")
	else:
		check(str(first.get("status", "")) == "fail", "copied exit scenario fails after the edit, got %s" % str(first))
	var rolled: Dictionary = CS.rollback(id)
	check(str(rolled.get("status", "")) == "rolled_back", "rollback of the copied edit, got %s" % str(rolled))
	var restored := FileAccess.get_file_as_bytes(caverns)
	check(_sha(restored) == _sha(original), "rolled-back Caverns.vg matches the copy's original bytes")
	var again: Dictionary = await _run_exit(Runner)
	check(str(again.get("status", "")) == "pass", "copied exit scenario passes after rollback, got %s" % str(again))
	var after_status := str(again.get("status", "incomplete"))
	var after_card := _card_text(CS, Card, id, original_text, restored.get_string_from_utf8(), after_status, again)
	print("----- CARD AFTER ROLLBACK -----")
	print(after_card)
	print("----- END CARD -----")
	check(after_card.find("rolled_back") >= 0, "card shows rolled_back")
	var edited := updated + "\n' user edit after the change\n"
	var id2: String = CS.begin("UnlockExit again", "make_code", "Change UnlockExit to 5")
	check(bool(safe.write(caverns, updated)[0]), "second copied edit")
	CS.end()
	var user := FileAccess.open(caverns, FileAccess.WRITE)
	user.store_string(edited)
	user.close()
	var conflict: Dictionary = CS.rollback(id2)
	check(str(conflict.get("status", "")) == "conflict", "user edit after the change is a conflict, got %s" % str(conflict))
	check(FileAccess.get_file_as_string(caverns) == edited, "conflict leaves the user edit in place")
	if failures == 0:
		print("[PASS] change_card_scenario.gd (%d/%d)" % [checks, checks])
		quit(0)
	else:
		print("[FAIL] change_card_scenario.gd (%d failures / %d checks)" % [failures, checks])
		quit(1)


func _card_text(CS, Card, id: String, before_text: String, after_text: String, expectation_status: String, run: Dictionary) -> String:
	var manifest: Dictionary = CS.read_set(id)
	var caverns := _copy.path_join("Caverns.vg")
	var finished := 0
	if not run.is_empty():
		finished = int(Time.get_unix_time_from_system())
	var card: Dictionary = Card.build_card(manifest, {
		"reply": str(manifest.get("reply", "")),
		"before": {caverns: before_text},
		"after": {caverns: after_text},
		"snapshot": {},
		"expectations": {
			"present": true,
			"rows": [{
				"name": "evidence_exit_scenario.gd",
				"status": expectation_status,
				"note": "exit opens at 6 crystals",
				"finished_unix": finished,
			}],
		},
		"rollback_state": CS.preview(id),
	})
	return Card.to_text(card)


func _run_exit(Runner) -> Dictionary:
	Runner.timeout_sec = 120.0
	var script := _copy.path_join("evidence_exit_scenario.gd")
	if not Runner.start(_copy, script, ""):
		return {"status": "incomplete", "name": "evidence_exit_scenario.gd"}
	while true:
		var result: Dictionary = Runner.poll()
		if bool(result.get("done", false)):
			return result
		await process_frame
	return {}


func _sha(data: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish().hex_encode()
