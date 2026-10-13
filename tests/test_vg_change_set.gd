extends SceneTree

## Phase 5: a change set records bytes and rolls back completely, or not at all.
var failures := 0
var checks := 0
var _root := ""
var _store := ""


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
	var Safe = load("res://addons/visual_gasic/vg_ai_safe_write.gd")
	var Tools = load("res://addons/visual_gasic/vg_ai_tools.gd")
	var Help = load("res://addons/visual_gasic/vg_ai_help.gd")
	if CS == null or Safe == null or Tools == null or Help == null:
		push_error("FAIL: change-set scripts are not loaded")
		quit(1)
		return
	_root = ProjectSettings.globalize_path("user://vg_change_set_work")
	_store = ProjectSettings.globalize_path("user://vg_change_set_store")
	_wipe(_root)
	_wipe(_store)
	DirAccess.make_dir_recursive_absolute(_root)
	CS.set_store_root(_store)
	CS.set_rollback_root(_root)
	CS.drop_memory()
	var safe = Safe.new()
	safe.set_root(_root)

	_outside_set_is_not_recorded(CS, safe)
	_text_and_binary_roundtrip(CS, safe)
	_rename_copy_delete_dirs(CS, safe)
	_empty_existing_file(CS, safe)
	_conflicts(CS, safe)
	_unsaved_conflict(CS, safe)
	_second_rollback_refused(CS, safe)
	_reload_from_disk(CS, safe)
	_prune_keeps_ten(CS, safe)
	_protected_path_is_reported(CS, safe)
	_guard_script_refused(safe)
	await _legacy_undo_refusals(CS, safe, Tools, Help)
	_user_summary_roundtrip(CS)
	_audit_note_is_optional(CS)

	if failures == 0:
		print("[PASS] test_vg_change_set.gd (%d/%d)" % [checks, checks])
		quit(0)
	else:
		print("[FAIL] test_vg_change_set.gd (%d failures / %d checks)" % [failures, checks])
		quit(1)


func _outside_set_is_not_recorded(CS, safe) -> void:
	var path := _abs("outside.txt")
	var wrote: Array = safe.write(path, "outside")
	check(bool(wrote[0]), "write outside a set still writes")
	check(CS.list_ids().is_empty(), "a write outside an open set creates no change set")
	check(_bytes(path).get_string_from_utf8() == "outside", "outside write kept its bytes")


func _text_and_binary_roundtrip(CS, safe) -> void:
	var text_path := _abs("notes.txt")
	_put(text_path, "alpha")
	var bin_path := _abs("blob.bin")
	var original := PackedByteArray([1, 2, 3])
	_put_bytes(bin_path, original)
	var binary := PackedByteArray([0, 255, 0, 1, 0x80])
	var id: String = CS.begin("Text and binary", "make_code", "reply")
	check(not id.is_empty(), "begin returns an id")
	var text_wrote: Array = safe.write(text_path, "beta")
	var bin_wrote: Array = safe.write_bytes(bin_path, binary)
	check(bool(text_wrote[0]) and bool(bin_wrote[0]), "text and binary writes succeed")
	var frozen: Dictionary = CS.end()
	check(str(frozen.get("status", "")) == "frozen", "end freezes the set")
	check(_bytes(text_path).get_string_from_utf8() == "beta", "text post-state is beta")
	check(_bytes(bin_path) == binary, "binary post-state keeps null and non-utf8 bytes")
	var result: Dictionary = CS.rollback(id)
	check(str(result.get("status", "")) == "rolled_back", "rollback status is rolled_back, got %s" % str(result))
	check(_sha(_bytes(text_path)) == _sha("alpha".to_utf8_buffer()), "text rollback matches the pre-image hash")
	check(_sha(_bytes(bin_path)) == _sha(original), "binary rollback matches the pre-image hash")


func _rename_copy_delete_dirs(CS, safe) -> void:
	var src := _abs("move_src.txt")
	var dest := _abs("move_dest.txt")
	var occupied := _abs("occupied.txt")
	var copy_from := _abs("copy_from.txt")
	var copy_to := _abs("copy_to.txt")
	var doomed := _abs("doomed.txt")
	_put(src, "moved")
	_put(occupied, "old-occupied")
	_put(copy_from, "copied")
	_put(doomed, "gone")
	var id: String = CS.begin("Layout", "make_patch", "")
	check(bool(safe.rename_path(src, dest)[0]), "rename")
	check(bool(safe.rename_path(dest, occupied)[0]), "rename overwrites the target")
	check(bool(safe.copy_onto(copy_from, copy_to)[0]), "copy_onto creates the target")
	check(bool(safe.remove(doomed)[0]), "delete")
	var created := _abs("new_dir/leaf.txt")
	var kept := _abs("kept_dir/leaf.txt")
	check(bool(safe.write(created, "leaf")[0]), "write creates a directory")
	check(bool(safe.write(kept, "leaf")[0]), "write creates the directory that will stay")
	CS.end()
	_put(kept.get_base_dir().path_join("extra.txt"), "keep-me")
	var result: Dictionary = CS.rollback(id)
	check(str(result.get("status", "")) == "rolled_back", "layout rollback, got %s" % str(result))
	check(_bytes(src).get_string_from_utf8() == "moved", "rename source is restored")
	check(not FileAccess.file_exists(dest), "intermediate rename target is gone")
	check(_bytes(occupied).get_string_from_utf8() == "old-occupied", "overwritten rename target is restored")
	check(not FileAccess.file_exists(copy_to), "copy_onto target is removed")
	check(_bytes(doomed).get_string_from_utf8() == "gone", "deleted file is restored")
	check(not DirAccess.dir_exists_absolute(created.get_base_dir()), "empty created directory is removed")
	check(DirAccess.dir_exists_absolute(kept.get_base_dir()), "non-empty created directory is kept")
	check(_bytes(kept.get_base_dir().path_join("extra.txt")).get_string_from_utf8() == "keep-me", "file added after the change stays")


func _empty_existing_file(CS, safe) -> void:
	var path := _abs("empty.txt")
	_put_bytes(path, PackedByteArray())
	var id: String = CS.begin("Empty", "make_code", "")
	check(bool(safe.write(path, "filled")[0]), "fill an empty file")
	CS.end()
	var result: Dictionary = CS.rollback(id)
	check(str(result.get("status", "")) == "rolled_back", "empty-file rollback")
	check(FileAccess.file_exists(path), "an empty file that existed is not deleted")
	check(_bytes(path).is_empty(), "the restored file is empty")


func _conflicts(CS, safe) -> void:
	var a := _abs("conflict_a.txt")
	var b := _abs("conflict_b.txt")
	_put(a, "a0")
	_put(b, "b0")
	var edited: String = CS.begin("Edit", "make_code", "")
	safe.write(a, "a1")
	safe.write(b, "b1")
	CS.end()
	_put(a, "a-user")
	var edit_result: Dictionary = CS.rollback(edited)
	check(str(edit_result.get("status", "")) == "conflict", "edited-after is a conflict")
	check(_reason_has(edit_result, a, "edited after change"), "edited-after names the path and reason")
	check(_bytes(a).get_string_from_utf8() == "a-user", "conflict leaves the edited file untouched")
	check(_bytes(b).get_string_from_utf8() == "b1", "conflict leaves the other file untouched")

	var removed: String = CS.begin("Delete after", "make_code", "")
	safe.write(a, "a2")
	safe.write(b, "b2")
	CS.end()
	DirAccess.remove_absolute(a)
	var del_result: Dictionary = CS.rollback(removed)
	check(str(del_result.get("status", "")) == "conflict", "deleted-after is a conflict")
	check(_reason_has(del_result, a, "deleted after change"), "deleted-after names the path")
	check(not FileAccess.file_exists(a), "deleted-after does not recreate the file")
	check(_bytes(b).get_string_from_utf8() == "b2", "deleted-after leaves the other file")

	var born := _abs("recreated.txt")
	_put(born, "was")
	var recreated: String = CS.begin("Recreate", "make_code", "")
	safe.remove(born)
	safe.write(b, "b3")
	CS.end()
	_put(born, "back")
	var rec_result: Dictionary = CS.rollback(recreated)
	check(str(rec_result.get("status", "")) == "conflict", "recreated-after is a conflict")
	check(_reason_has(rec_result, born, "recreated after change"), "recreated-after names the path")
	check(_bytes(born).get_string_from_utf8() == "back", "recreated-after leaves the new file")
	check(_bytes(b).get_string_from_utf8() == "b3", "recreated-after leaves the other file")


func _unsaved_conflict(CS, safe) -> void:
	var path := _abs("unsaved.txt")
	_put(path, "disk")
	var id: String = CS.begin("Unsaved", "make_code", "")
	safe.write(path, "disk-2")
	CS.end()
	CS.set_unsaved_paths([path])
	var result: Dictionary = CS.rollback(id)
	CS.set_unsaved_paths([])
	check(str(result.get("status", "")) == "conflict", "unsaved editor buffer is a conflict")
	check(_reason_has(result, path, "unsaved editor changes"), "unsaved reason")
	check(_bytes(path).get_string_from_utf8() == "disk-2", "unsaved conflict writes nothing")


func _second_rollback_refused(CS, safe) -> void:
	var path := _abs("twice.txt")
	_put(path, "one")
	var id: String = CS.begin("Twice", "make_code", "")
	safe.write(path, "two")
	CS.end()
	var first: Dictionary = CS.rollback(id)
	var second: Dictionary = CS.rollback(id)
	check(str(first.get("status", "")) == "rolled_back", "first rollback works")
	check(str(second.get("status", "")) == "refused", "second rollback is refused, got %s" % str(second))
	check(_bytes(path).get_string_from_utf8() == "one", "second rollback does not change the file")


func _reload_from_disk(CS, safe) -> void:
	var path := _abs("persist.txt")
	_put(path, "before")
	var id: String = CS.begin("Persist", "make_test", "")
	safe.write(path, "after")
	CS.end()
	CS.drop_memory()
	var loaded: Dictionary = CS.read_set(id)
	check(str(loaded.get("id", "")) == id, "manifest reloads from disk")
	check(str(loaded.get("status", "")) == "frozen", "reloaded set is frozen")
	var result: Dictionary = CS.rollback(id)
	check(str(result.get("status", "")) == "rolled_back", "rollback uses the reloaded manifest")
	check(_bytes(path).get_string_from_utf8() == "before", "reloaded rollback restores bytes")


func _prune_keeps_ten(CS, safe) -> void:
	var oldest := ""
	for i in 11:
		var path := _abs("prune_%d.txt" % i)
		var id: String = CS.begin("Prune %d" % i, "make_code", "")
		if oldest.is_empty():
			oldest = id
		safe.write(path, "p%d" % i)
		CS.end()
	var ids: Array = CS.list_ids()
	check(ids.size() == 10, "prune keeps 10 sets, got %d" % ids.size())
	check(not ids.has(oldest), "the oldest set is pruned")
	check(not DirAccess.dir_exists_absolute(_store.path_join(oldest)), "the pruned set directory is gone")
	var missing: Dictionary = CS.rollback(oldest)
	check(str(missing.get("status", "")) == "unavailable", "a pruned set cannot roll back")
	var before_restart: String = CS.latest_id()
	CS._seq = 0
	var fresh: String = CS.begin("After restart", "make_code", "")
	safe.write(_abs("prune_restart.txt"), "r")
	CS.end()
	check(fresh != before_restart and not CS.read_set(fresh).is_empty(), "a set made after an editor restart is kept")
	check(CS.latest_id() == fresh, "a set made after an editor restart is the latest")


func _protected_path_is_reported(CS, safe) -> void:
	var guard := _abs("addons/visual_gasic/vg_change_set.gd")
	var normal := _abs("beside.txt")
	_put(guard, "guard-bytes")
	_put(normal, "before")
	var guard_hash := _sha(_bytes(guard))
	var id: String = CS.begin("Protected", "make_code", "")
	safe.write(normal, "after")
	CS.end()
	var manifest: Dictionary = CS.read_set(id)
	var entries: Array = manifest.get("entries", [])
	var pre_rel := "pre/guard.bin"
	_put_bytes(_store.path_join(id).path_join(pre_rel), "other".to_utf8_buffer())
	entries.append({
		"op": "write",
		"path": guard,
		"existed": true,
		"binary": false,
		"pre_hash": _sha("other".to_utf8_buffer()),
		"post_hash": guard_hash,
		"pre_size": 5,
		"post_size": _bytes(guard).size(),
		"pre_file": pre_rel,
	})
	manifest["entries"] = entries
	CS.write_set(manifest)
	var result: Dictionary = CS.rollback(id)
	check(str(result.get("status", "")) == "refused", "protected path refuses rollback, got %s" % str(result))
	check(_bytes(normal).get_string_from_utf8() == "after", "protected refusal changes nothing else")
	check(_sha(_bytes(guard)) == guard_hash, "protected file bytes stay")


func _guard_script_refused(safe) -> void:
	safe.allow_addon_writes(true)
	var safety: Array = safe.is_safe("res://addons/visual_gasic/vg_change_set.gd")
	safe.allow_addon_writes(false)
	check(not bool(safety[0]), "vg_change_set.gd is refused with addon writes unlocked")
	check(str(safety[1]).begins_with("protected expectation:"), "guard refusal uses the expectation reason")


func _legacy_undo_refusals(CS, safe, Tools, Help) -> void:
	var path := _abs("legacy.txt")
	_put(path, "original")
	var id: String = CS.begin("Legacy", "tool_approval", "")
	safe.write(path, "from-ai")
	CS.end()
	_put(path, "user-later")
	var tools = Tools.new()
	tools._safe = safe
	tools._undo_stack.append({
		"kind": "file",
		"path": path,
		"existed": true,
		"prev": {"text": "original"},
		"label": "write",
	})
	var tool_msg: String = tools.undo_last()
	check(tool_msg == "Refused: %s was edited after the change. Use Roll back in Code Navigator to see conflicts." % path, "tool undo refusal text, got %s" % tool_msg)
	check(_bytes(path).get_string_from_utf8() == "user-later", "tool undo does not overwrite the later edit")

	var help = Help.new()
	var label := RichTextLabel.new()
	root.add_child(label)
	help._output = label
	help._safe_writer = safe
	help._undo_stack.append({
		"label": "Make code",
		"files": [{"path": path, "old": "original"}],
	})
	help._on_undo_last_edit()
	await process_frame
	var shown := label.get_parsed_text() if label.has_method("get_parsed_text") else label.get_text()
	check(shown.find("Refused: %s was edited after the change. Use Roll back in Code Navigator to see conflicts." % path) >= 0, "help undo refusal text, got %s" % shown)
	check(_bytes(path).get_string_from_utf8() == "user-later", "help undo does not overwrite the later edit")
	var left: Dictionary = CS.rollback(id)
	check(str(left.get("status", "")) == "conflict", "legacy refusal left the change set able to report the conflict")


func _reason_has(result: Dictionary, path: String, reason: String) -> bool:
	for row in result.get("conflicts", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		if str(row.get("path", "")) == path and str(row.get("reason", "")) == reason:
			return true
	return false


func _user_summary_roundtrip(CS) -> void:
	var id: String = CS.begin("Summary", "make_patch", "Narcea claim")
	CS.end()
	CS.record_user_summary(id, "The exit opens at 5 crystals.")
	CS.drop_memory()
	var loaded: Dictionary = CS.read_set(id)
	var summary: Dictionary = loaded.get("user_summary", {})
	check(str(summary.get("source", "")) == "user", "user summary source is user")
	check(str(summary.get("text", "")) == "The exit opens at 5 crystals.", "user summary text is stored")
	check(str(loaded.get("reply", "")) == "Narcea claim", "the model claim stays separate")
	check(int(summary.get("timestamp", 0)) > 0, "user summary has a timestamp")


func _audit_note_is_optional(CS) -> void:
	var Expectations = load("res://addons/visual_gasic/vg_expectations.gd")
	var missing_root := _root.rstrip("/") + "/no-manifest"
	DirAccess.make_dir_recursive_absolute(missing_root)
	var exp = Expectations.new()
	exp.load_manifest(missing_root)
	var skipped: Dictionary = exp.append_audit_note("opens at 5", "res://Caverns.vg", "UnlockExit")
	check(skipped.is_empty(), "a missing expectations file is left untouched")
	check(not FileAccess.file_exists(missing_root.path_join("vg_expectations.json")), "no expectations file is created")
	var present_root := _root.rstrip("/") + "/with-manifest"
	DirAccess.make_dir_recursive_absolute(present_root)
	var manifest := {"schema": "vg-expectations/1", "protected": [{"path": "res://evidence_exit_scenario.gd", "sha256": "abc", "accepted_at": "t", "note": "exit"}]}
	var mf := FileAccess.open(present_root.path_join("vg_expectations.json"), FileAccess.WRITE)
	mf.store_string(JSON.stringify(manifest, "\t"))
	mf.close()
	var exp2 = Expectations.new()
	exp2.load_manifest(present_root)
	var saved: Dictionary = exp2.append_audit_note("opens at 5", "res://Caverns.vg", "UnlockExit")
	check(str(saved.get("status", "")) == "pending", "audit note starts pending")
	check(str(saved.get("note", "")) == "opens at 5", "audit note stores the sentence")
	check(str(saved.get("section", "")) == "UnlockExit", "audit note stores the section")
	var raw = JSON.parse_string(FileAccess.get_file_as_string(present_root.path_join("vg_expectations.json")))
	var protected_rows: Array = raw.get("protected", [])
	check(protected_rows.size() == 1 and str(protected_rows[0].get("note", "")) == "exit", "protected entries stay as they were")
	var audit_rows: Array = raw.get("audit", [])
	check(audit_rows.size() == 1 and str(audit_rows[0].get("file", "")) == "res://Caverns.vg", "audit note is stored beside protected entries")


func _abs(rel: String) -> String:
	return _root.rstrip("/") + "/" + rel.trim_prefix("/")


func _put(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _put_bytes(path: String, data: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(data)
	f.close()


func _bytes(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)


func _sha(data: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish().hex_encode()


func _wipe(path: String) -> void:
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		return
	var da := DirAccess.open(path)
	if da == null:
		return
	for file_name in da.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	for dir_name in da.get_directories():
		_wipe(path.path_join(dir_name))
	DirAccess.remove_absolute(path)
