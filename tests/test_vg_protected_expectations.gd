extends SceneTree

## Phase 3: Narcea cannot make a failing check pass by editing the check.
var failures := 0
var checks := 0
var _root := ""


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if ok:
		return
	failures += 1
	push_error("FAIL: " + what)


func _run() -> void:
	var Exp = load("res://addons/visual_gasic/vg_expectations.gd")
	var Safe = load("res://addons/visual_gasic/vg_ai_safe_write.gd")
	var Tools = load("res://addons/visual_gasic/vg_ai_tools.gd")
	var Patch = load("res://addons/visual_gasic/vg_ai_patch_spec.gd")
	var Code = load("res://addons/visual_gasic/vg_ai_code_spec.gd")
	var FC = load("res://addons/visual_gasic/vg_ai_function_calling.gd")
	var Synth = load("res://addons/visual_gasic/vg_ai_project_synth.gd")
	var Repair = load("res://addons/visual_gasic/vg_ai_repair.gd")
	var Dlg = load("res://addons/visual_gasic/vg_ai_diff_dialog.gd")
	if Exp == null or Safe == null or Tools == null:
		push_error("FAIL: expectation scripts are not loaded")
		quit(1)
		return
	_root = "/tmp/vg-expect-%d" % Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(_root)
	var exp = Exp.new()
	exp.load_manifest(_root)
	_write_rel("open.gd", "Dim n As Integer\n")
	_write_rel("locked/a.gd", "Dim a As Integer\n")
	var open_hash := _sha_file(_abs("open.gd"))
	_write_manifest([
		{"path": "res://guard.gd", "sha256": _sha_text("original\n"), "accepted_at": "2026-01-01T00:00:00", "note": "guard"},
		{"path": "res://missing.gd", "sha256": _sha_text("gone\n"), "accepted_at": "2026-01-01T00:00:00", "note": "missing"},
		{"path": "res://locked/", "sha256": "", "accepted_at": "2026-01-01T00:00:00", "note": "directory"},
	], false)
	_write_rel("guard.gd", "original\n")
	exp.load_manifest(_root)

	check(exp.status("res://open.gd") == "unprotected", "unlisted file is unprotected")
	check(exp.status("res://guard.gd") == "accepted", "matching hash is accepted, got %s" % exp.status("res://guard.gd"))
	_write_rel("guard.gd", "tampered\n")
	exp.load_manifest(_root)
	check(exp.status("res://guard.gd") == "modified", "changed bytes are modified, got %s" % exp.status("res://guard.gd"))
	check(exp.status("res://missing.gd") == "missing", "listed missing file is missing, got %s" % exp.status("res://missing.gd"))
	var cur: Array = exp.accept_current("res://guard.gd")
	check(bool(cur[0]) and exp.status("res://guard.gd") == "accepted", "accept_current restores accepted")

	var safe = Safe.new()
	safe.set_root(_root)
	var created: Array = safe.write(_abs("guard.gd"), "nope\n")
	check(not bool(created[0]) and str(created[1]).find("protected expectation:") >= 0, "overwrite refused: %s" % str(created[1]))
	check(FileAccess.get_file_as_string(_abs("guard.gd")) == "tampered\n", "refused overwrite left the file")
	var made: Array = safe.write(_abs("missing.gd"), "new\n")
	check(not bool(made[0]) and not FileAccess.file_exists(_abs("missing.gd")), "create of a listed missing file is refused")
	var open_write: Array = safe.write(_abs("open.gd"), "Dim n As Integer\nDim m As Integer\n")
	check(bool(open_write[0]), "unprotected file still writes: %s" % str(open_write[1]))
	var nested: Array = safe.write(_abs("locked/a.gd"), "nope\n")
	check(not bool(nested[0]), "file inside a protected directory is refused: %s" % str(nested[1]))

	check(exp.is_protected(_abs("guard.gd")), "absolute path is protected")
	check(exp.is_protected("res://./guard.gd"), "dot segment is protected")
	check(exp.is_protected("res://locked//a.gd"), "doubled slash is protected")
	check(exp.is_protected(_root + "/./guard.gd"), "relative dot path is protected")
	var link := _root + "/alias.gd"
	OS.execute("ln", PackedStringArray(["-s", _abs("guard.gd"), link]))
	if FileAccess.file_exists(link):
		check(exp.is_protected(link), "symlink into a protected file is protected")
	else:
		check(true, "symlink not supported on this OS")
	var manifest_only = Exp.new()
	_write_manifest([
		{"path": "res://guard.gd", "sha256": exp.status("res://guard.gd"), "accepted_at": "2026-01-01T00:00:00", "note": "guard"},
	], false)
	manifest_only.load_manifest(_root)
	check(manifest_only.is_protected(_abs("vg_expectations.json")), "manifest is protected even when it does not list itself")
	var manifest_write: Array = safe.write(_abs("vg_expectations.json"), "{}\n")
	check(not bool(manifest_write[0]), "writing the manifest is refused")

	var removed: Array = safe.remove(_abs("guard.gd"))
	check(not bool(removed[0]) and FileAccess.file_exists(_abs("guard.gd")), "delete is refused")
	var renamed: Array = safe.rename_path(_abs("guard.gd"), _abs("guard-renamed.gd"))
	check(not bool(renamed[0]) and FileAccess.file_exists(_abs("guard.gd")), "rename is refused")
	var copied: Array = safe.copy_onto(_abs("open.gd"), _abs("guard.gd"))
	check(not bool(copied[0]), "copy onto a protected path is refused")

	var tools = Tools.new()
	tools._get_safe().set_root(_root)
	var snap_res: String = tools._apply_snapshot({
		"kind": "file",
		"path": _abs("guard.gd"),
		"existed": false,
		"prev": {"text": ""},
		"label": "undo",
	})
	check(snap_res.find("REFUSED") >= 0 or snap_res.find("protected expectation:") >= 0, "undo delete is refused: %s" % snap_res)
	check(FileAccess.file_exists(_abs("guard.gd")), "undo did not delete the protected file")

	tools.set_test_buffer_path(_abs("guard.gd"))
	for tool_name in ["insert_text", "replace_range", "replace_in_buffer", "set_buffer_text"]:
		var refusal: String = tools.protected_buffer_refusal(tool_name, _abs("guard.gd"))
		check(refusal == "[%s] REFUSED: protected expectation: %s. The expectation can only be changed with propose_expectation_change." % [tool_name, _abs("guard.gd")] or refusal.find("[%s] REFUSED: protected expectation:" % tool_name) == 0, "%s buffer refusal: %s" % [tool_name, refusal])
	var inserted: String = tools._do_insert_text({"line": 1, "text": "Dim z As Integer\n"})
	check(inserted.find("REFUSED") >= 0, "insert_text refuses a protected buffer: %s" % inserted)

	var patch = Patch.new()
	var spec := {
		"edits": [
			{"path": _abs("guard.gd"), "op": "replace", "find": "tampered", "with": "hacked"},
			{"path": _abs("open.gd"), "op": "replace", "find": "Dim", "with": "Dim"},
		]
	}
	var before_open := FileAccess.get_file_as_string(_abs("open.gd"))
	var applied: Dictionary = patch.apply(spec, safe, false)
	check(applied.get("written", []).is_empty(), "patch wrote nothing: %s" % str(applied))
	check(str(applied.get("summary", "")).find("guard.gd") >= 0, "patch names the protected path: %s" % str(applied.get("summary", "")))
	check(FileAccess.get_file_as_string(_abs("open.gd")) == before_open, "unprotected half of the patch was not written")

	var code = Code.new()
	var code_applied: Dictionary = code.apply({
		"files": [
			{"path": _abs("guard.gd"), "source": "nope\n"},
			{"path": _abs("open.gd"), "source": "still\n"},
		]
	}, safe, false)
	check(code_applied.get("written", []).is_empty() and FileAccess.get_file_as_string(_abs("open.gd")) == before_open, "code spec writes neither file")

	var proposal_id: String = exp.propose_change("res://guard.gd", "accepted-edit\n", "the check was wrong")
	check(not proposal_id.is_empty() and FileAccess.get_file_as_string(_abs("guard.gd")) != "accepted-edit\n", "propose writes nothing")
	check(exp.pending().size() == 1, "one pending proposal")
	var proposed: String = tools.execute_tool({
		"tool": "propose_expectation_change",
		"path": "res://guard.gd",
		"contents": "from-tool\n",
		"reason": "tool path",
	})
	check(proposed.find("proposal") >= 0 and FileAccess.get_file_as_string(_abs("guard.gd")).find("from-tool") < 0, "tool propose writes nothing: %s" % proposed)
	var pending: Array = exp.pending()
	var tool_id := ""
	for row in pending:
		if str(row.get("reason", "")) == "tool path":
			tool_id = str(row.get("id", ""))
	exp.reject(tool_id)
	var accepted: Array = exp.accept(proposal_id)
	check(bool(accepted[0]) and FileAccess.get_file_as_string(_abs("guard.gd")) == "accepted-edit\n", "accept writes the proposal: %s" % str(accepted))
	check(exp.status("res://guard.gd") == "accepted", "accept updates the hash")
	var again: String = exp.propose_change("res://guard.gd", "rejected\n", "no")
	exp.reject(again)
	check(FileAccess.get_file_as_string(_abs("guard.gd")) == "accepted-edit\n", "reject leaves the file")

	var names: Array = []
	for def in FC._get_tool_defs():
		names.append(str(def.get("name", "")))
	check(names.has("propose_expectation_change"), "schema exposes propose_expectation_change")
	check(not names.has("accept") and not names.has("accept_current") and not names.has("reject"), "schema has no accept route")
	var unknown: String = tools.execute_tool({"tool": "accept", "proposal_id": proposal_id})
	check(unknown.find("unknown tool") >= 0, "dispatcher has no accept route: %s" % unknown)
	var unknown_current: String = tools.execute_tool({"tool": "accept_current", "path": "res://guard.gd"})
	check(unknown_current.find("unknown tool") >= 0, "dispatcher has no accept_current route")
	var unknown_reject: String = tools.execute_tool({"tool": "reject", "proposal_id": "nope"})
	check(unknown_reject.find("unknown tool") >= 0, "dispatcher has no reject route")

	var parked: String = exp.propose_change("res://guard.gd", "auto\n", "should stay pending")
	var auto_plan: Dictionary = tools.plan_response("```vg-tool\n{\"tool\":\"propose_expectation_change\",\"path\":\"res://guard.gd\",\"contents\":\"auto\\n\",\"reason\":\"bypass\"}\n```\n```vg-tool\n{\"tool\":\"write_file\",\"path\":\"res://open.gd\",\"contents\":\"zzz\\n\"}\n```\n")
	check((auto_plan.get("mutating", []) as Array).size() == 1, "code change stays in the mutation batch")
	check((auto_plan.get("expectations", []) as Array).size() == 1, "expectation change is not in the code batch")
	check(FileAccess.get_file_as_string(_abs("guard.gd")) != "auto\n", "planning a proposal does not accept it")
	exp.reject(parked)

	var dlg = Dlg.new()
	dlg.configure_expectation(exp.pending()[0] if not exp.pending().is_empty() else {"id": "", "path": "res://guard.gd", "reason": "why", "contents": "x\n"}, exp)
	check(dlg.title == "Change a protected expectation", "expectation dialog title")
	check(dlg.get_ok_button().text.find("Accept") >= 0 and dlg.get_cancel_button().text.find("Reject") >= 0, "expectation dialog buttons")
	check(dlg.title != "Apply spec — review changes", "expectation dialog is not the code dialog")

	var synth_ok: bool = Synth._write_file(_abs("guard.gd"), "synth\n")
	check(not synth_ok and FileAccess.get_file_as_string(_abs("guard.gd")) != "synth\n", "project synth write is refused")
	var repaired: Array = Repair.write_patched_file(_abs("guard.gd"), "repair\n")
	check(not bool(repaired[0]), "repair write is refused: %s" % str(repaired))

	var live = Safe.new()
	live.allow_addon_writes(false)
	var chain: Array = live.is_safe("res://addons/visual_gasic/vg_causal_chain.gd")
	check(not bool(chain[0]), "locked addon refuses vg_causal_chain.gd")
	tools._get_safe().set_root("res://")
	var chain_buf: String = tools.protected_buffer_refusal("replace_in_buffer", "res://addons/visual_gasic/vg_causal_chain.gd")
	check(chain_buf.find("REFUSED") >= 0, "locked addon buffer refuses vg_causal_chain.gd: %s" % chain_buf)
	live.allow_addon_writes(true)
	var chain_open: Array = live.is_safe("res://addons/visual_gasic/vg_causal_chain.gd")
	check(bool(chain_open[0]), "unlocked addon allows other addon files")
	var guard_exp: Array = live.is_safe("res://addons/visual_gasic/vg_expectations.gd")
	var guard_safe: Array = live.is_safe("res://addons/visual_gasic/vg_ai_safe_write.gd")
	check(not bool(guard_exp[0]) and not bool(guard_safe[0]), "unlock does not open the guard files: %s | %s" % [str(guard_exp[1]), str(guard_safe[1])])
	live.allow_addon_writes(false)

	var narrow_id: String = exp.propose_change("res://guard.gd", "narrow-root\n", "survives a narrowed write root")
	safe.set_root("res://ai_projects/x")
	check(exp.blocks_ai_write("res://guard.gd"), "narrowed write root still blocks the protected scenario")
	check(exp.status("res://guard.gd") == "accepted", "narrowed write root leaves status accepted, got %s" % exp.status("res://guard.gd"))
	var still_pending := false
	for row in exp.pending():
		if str(row.get("id", "")) == narrow_id:
			still_pending = true
	check(still_pending, "proposal stays pending after the write root changes")
	var narrow_safe: Array = safe.is_safe(_abs("guard.gd"))
	check(not bool(narrow_safe[0]) and str(narrow_safe[1]).begins_with("protected expectation:"), "narrowed root still returns protected expectation: %s" % str(narrow_safe[1]))
	var narrow_accepted: Array = exp.accept(narrow_id)
	check(bool(narrow_accepted[0]) and FileAccess.get_file_as_string(_abs("guard.gd")) == "narrow-root\n", "pending proposal can still be accepted: %s" % str(narrow_accepted))

	var guard_script := ProjectSettings.globalize_path("res://addons/visual_gasic/vg_ai_safe_write.gd")
	var guard_before := FileAccess.get_file_as_bytes(guard_script)
	var zip_path := _abs("guard_restore.zip")
	var packer := ZIPPacker.new()
	var zip_err := packer.open(zip_path)
	check(zip_err == OK, "restore zip opens")
	if zip_err == OK:
		packer.start_file("addons/visual_gasic/vg_ai_safe_write.gd")
		packer.write_file("hacked guard\n".to_utf8_buffer())
		packer.close_file()
		packer.close()
		tools._get_safe().allow_addon_writes(true)
		var restored: String = tools._do_restore_addon({"path": zip_path})
		var guard_after := FileAccess.get_file_as_bytes(guard_script)
		if guard_after != guard_before:
			var restore_f := FileAccess.open(guard_script, FileAccess.WRITE)
			if restore_f != null:
				restore_f.store_buffer(guard_before)
				restore_f.close()
		check(restored.find("REFUSED") >= 0 and guard_after == guard_before, "restore of the guard script is refused: %s" % restored)
		tools._get_safe().allow_addon_writes(false)

	var audit := FileAccess.get_file_as_string("user://vg_ai_audit.log")
	check(audit.find("BLOCK_EXPECTATION") >= 0, "audit contains BLOCK_EXPECTATION")
	check(audit.find("EXPECTATION_ACCEPTED") >= 0, "audit contains EXPECTATION_ACCEPTED")

	if failures == 0:
		print("[PASS] test_vg_protected_expectations.gd (%d/%d)" % [checks, checks])
		quit(0)
	else:
		print("[FAIL] test_vg_protected_expectations.gd (%d failures / %d checks)" % [failures, checks])
		quit(1)


func _abs(rel: String) -> String:
	return _root.rstrip("/") + "/" + rel.trim_prefix("/")


func _write_rel(rel: String, text: String) -> void:
	var path := _abs(rel)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _write_manifest(entries: Array, seal: bool) -> void:
	var body := {"schema": "vg-expectations/1", "protected": entries}
	var f := FileAccess.open(_abs("vg_expectations.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(body, "\t"))
	f.close()
	if seal:
		pass


func _sha_text(text: String) -> String:
	return _sha_bytes(text.to_utf8_buffer())


func _sha_file(path: String) -> String:
	return _sha_bytes(FileAccess.get_file_as_bytes(path))


func _sha_bytes(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()
