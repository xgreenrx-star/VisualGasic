@tool
extends EditorPlugin

## In-editor check for the Behavior evidence panel and the Last change card.
## Paths come from res://zz_ui_probe.json in the temp project. Assertions read
## widget text and state. Screenshots are saved for a person to look at.

var log_lines: Array = []
var failures := 0
var cfg: Dictionary = {}

const CLAIM := "I changed the exit so it opens after 5 crystals instead of 6. Everything else is unchanged and the game is safe to run."


func _enter_tree() -> void:
	_go.call_deferred()


func note(s: String) -> void:
	print("PROBE: " + s)
	log_lines.append(s)


func fail(step: String, saw: String) -> void:
	failures += 1
	note("FAIL %s saw: %s" % [step, saw])


func expect(step: String, ok: bool, saw: String) -> void:
	if ok:
		note("ok " + step)
	else:
		fail(step, saw)


func wait_s(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func load_config() -> bool:
	if not FileAccess.file_exists("res://zz_ui_probe.json"):
		fail("config", "res://zz_ui_probe.json missing")
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://zz_ui_probe.json"))
	if typeof(parsed) != TYPE_DICTIONARY:
		fail("config", "zz_ui_probe.json is not an object")
		return false
	cfg = parsed
	if str(cfg.get("out", "")).is_empty() or str(cfg.get("snapshot", "")).is_empty():
		fail("config", JSON.stringify(cfg))
		return false
	DirAccess.make_dir_recursive_absolute(str(cfg.get("out", "")))
	return true


func shot(name: String, nav: Control) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_editor_interface().get_base_control().get_viewport().get_texture().get_image()
	var out := str(cfg.get("out", ""))
	img.save_png(out.path_join(name + "_full.png"))
	if nav != null and nav.is_visible_in_tree():
		var r := Rect2i(nav.get_global_rect())
		r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if r.size.x > 4 and r.size.y > 4:
			img.get_region(r).save_png(out.path_join(name + "_nav.png"))
	note("shot " + name)


func shot_dialog(nav) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var dialog: ConfirmationDialog = nav._change_confirm
	var out := str(cfg.get("out", ""))
	# The confirm dialog is its own Window, so the editor viewport shot does not
	# include it. Window extends Viewport; grab that viewport's texture.
	var tex: ViewportTexture = dialog.get_texture()
	if tex == null:
		fail("rollback dialog texture", "null")
		return
	var img := tex.get_image()
	if img == null or img.get_width() < 4:
		fail("rollback dialog image", "empty")
		return
	img.save_png(out.path_join("05_rollback_dialog.png"))
	note("shot dialog %dx%d" % [img.get_width(), img.get_height()])


func row_pairs(nav) -> Array:
	var pairs: Array = []
	var left: Array = nav._evidence_left.get_children()
	var right: Array = nav._evidence_right.get_children()
	var count: int = mini(left.size(), right.size())
	for i in count:
		pairs.append([str(left[i].text), str(right[i].text)])
	return pairs


func has_row(pairs: Array, left_needle: String, right_prefix: String) -> bool:
	for pair in pairs:
		var left := str(pair[0])
		var right := str(pair[1])
		if left.contains(left_needle) and right.begins_with(right_prefix):
			return true
	return false


func card_without_claim(text: String) -> String:
	return text.replace(CLAIM, "")


func assert_panel(nav, recording_on: bool) -> void:
	var header := str(nav.evidence_header_text())
	var banner := str(nav.evidence_banner_text())
	expect("panel header starts with UnlockExit", header.begins_with("UnlockExit"), header)
	expect("panel header observed", header.contains("  observed  "), header)
	expect("panel header fires 1", header.contains("fires 1  "), header)
	expect("panel header dropped 0", header.contains("dropped 0/"), header)
	var pairs: Array = row_pairs(nav)
	expect("UnlockExit root observed", has_row(pairs, "UnlockExit", "observed"), JSON.stringify(pairs))
	expect("exitOpen write observed", has_row(pairs, "exitOpen = True", "observed"), JSON.stringify(pairs))
	expect("guard not_recorded", has_row(pairs, "If ", "not_recorded"), JSON.stringify(pairs))
	expect("Exit Sub not_recorded", has_row(pairs, "Exit Sub", "not_recorded"), JSON.stringify(pairs))
	var setting_on := false
	if ProjectSettings.has_setting("vg/evidence/runtime_ring"):
		setting_on = bool(ProjectSettings.get_setting("vg/evidence/runtime_ring"))
	expect("banner matches recorder setting", setting_on == recording_on, "setting=%s want_on=%s banner=%s" % [str(setting_on), str(recording_on), banner])
	if recording_on:
		expect("banner empty while recording", banner.is_empty(), banner)
	else:
		expect("banner recording off with a run", banner == "Recording off. Showing the last captured run; new runs are not recorded.", banner)


func assert_card_before(text: String) -> void:
	expect("claim label", text.contains("Narcea says (not verified)"), text)
	expect("files modified", text.contains("| modified |"), text)
	expect("line delta 0", text.contains("line delta 0"), text)
	expect("static trigger", text.contains("UnlockExit | trigger changed | target GEM_TARGET -> 5"), text)
	expect("observed not run", text.contains("not run since change"), text)
	expect("exit expectation not run", text.contains("evidence_exit_scenario.gd | not run"), text)
	expect("save expectation not run", text.contains("save_format_scenario.gd | not run"), text)
	expect("rollback available", text.contains("status: available"), text)
	assert_no_safe_success("card before checks", text)


func assert_no_safe_success(step: String, text: String) -> void:
	var body := card_without_claim(text)
	expect(step + " no safe", body.find("safe") < 0, body)
	expect(step + " no success", body.find("success") < 0, body)


func _go() -> void:
	if not load_config():
		_finish()
		return
	var base := get_editor_interface().get_base_control()
	var waited := 0.0
	while waited < 45.0:
		if base.has_meta("visual_gasic_plugin_instance"):
			break
		await wait_s(1.0)
		waited += 1.0
	note("plugin wait %.0f s" % waited)
	var fs := get_editor_interface().get_resource_filesystem()
	var scan_wait := 0.0
	while fs.is_scanning() and scan_wait < 120.0:
		await wait_s(1.0)
		scan_wait += 1.0
	# Godot's startup progress dialogs (docs update, layout load) close shortly after the scan.
	await wait_s(5.0)
	note("scan wait %.0f s" % scan_wait)
	note("window size %s" % str(base.get_viewport().get_visible_rect().size))
	var vg = base.get_meta("visual_gasic_plugin_instance") if base.has_meta("visual_gasic_plugin_instance") else null
	if vg == null:
		fail("plugin", "no visual_gasic_plugin_instance")
		_finish()
		return
	var nav = vg.get("_code_navigator")
	if nav == null:
		fail("navigator", "null")
		_finish()
		return
	get_editor_interface().set_main_screen_editor("Script")
	var scr = load("res://Caverns.vg")
	get_editor_interface().edit_script(scr, 71)
	await wait_s(1.0)
	nav.visible = true
	var parent = nav.get_parent()
	while parent != null and parent is Control:
		if not parent.visible:
			parent.visible = true
		parent = parent.get_parent()
	await wait_s(0.5)
	await shot("01_navigator_default", nav)

	var snap = JSON.parse_string(FileAccess.get_file_as_string(str(cfg.get("snapshot", ""))))
	if typeof(snap) != TYPE_DICTIONARY:
		fail("snapshot", "not an object")
		_finish()
		return
	nav._evidence_toggle.button_pressed = true
	await wait_s(0.3)
	nav.set_evidence_source(str(scr.source_code), 71, "res://Caverns.vg")
	nav.set_evidence_run(snap, "ended")
	await wait_s(0.5)
	assert_panel(nav, false)
	await shot("02_evidence_recording_off", nav)

	ProjectSettings.set_setting("vg/evidence/runtime_ring", true)
	nav.set_evidence_run(snap, "ended")
	await wait_s(0.3)
	assert_panel(nav, true)
	await shot("02b_evidence_recording_on", nav)
	ProjectSettings.set_setting("vg/evidence/runtime_ring", false)
	nav.set_evidence_run(snap, "ended")

	var CS = load("res://addons/visual_gasic/vg_change_set.gd")
	var Safe = load("res://addons/visual_gasic/vg_ai_safe_write.gd").new()
	Safe.set_root("res://")
	var before := FileAccess.get_file_as_bytes("res://Caverns.vg")
	var text := before.get_string_from_utf8()
	var changed := text.replace("crystals Becomes GEM_TARGET OnUnlockExit", "crystals Becomes 5 OnUnlockExit")
	expect("edit applies", changed != text, "replacement missed")
	CS.begin("Probe patch", "make_patch", CLAIM)
	var wrote: Array = Safe.write("res://Caverns.vg", changed)
	expect("safe write", bool(wrote[0]), str(wrote))
	CS.end()
	nav._evidence_toggle.button_pressed = false
	nav.show_last_change()
	await wait_s(0.5)
	var card_before := str(nav._change_text)
	note("CARD BEFORE CHECKS:\n" + card_before)
	assert_card_before(card_before)
	await shot("03_change_card", nav)

	nav._on_change_run_checks()
	var t0 := Time.get_ticks_msec()
	while (str(nav._change_running) != "" or not nav._change_queue.is_empty()) and Time.get_ticks_msec() - t0 < 180000:
		await wait_s(1.0)
	var elapsed := Time.get_ticks_msec() - t0
	note("checks took %d ms" % elapsed)
	var card_after := str(nav._change_text)
	note("CARD AFTER CHECKS:\n" + card_after)
	expect("exit expectation fail", card_after.contains("evidence_exit_scenario.gd | fail"), card_after)
	expect("save expectation pass", card_after.contains("save_format_scenario.gd | pass"), card_after)
	expect("checks finished", str(nav._change_running).is_empty(), str(nav._change_running))
	assert_no_safe_success("card after checks", card_after)
	await shot("04_after_checks", nav)

	nav._on_change_rollback_pressed()
	await wait_s(0.4)
	var dialog_text := str(nav._change_confirm.dialog_text)
	note("confirm dialog: " + dialog_text)
	expect("dialog lists Caverns.vg", dialog_text.contains("Caverns.vg"), dialog_text)
	await shot("05_rollback_confirm", null)
	await shot_dialog(nav)
	nav._change_confirm.hide()
	nav._on_change_rollback_confirmed()
	await wait_s(0.8)
	var restored := FileAccess.get_file_as_bytes("res://Caverns.vg")
	expect("byte-identical after rollback", restored == before, "size %d vs %d" % [restored.size(), before.size()])
	var card_back := str(nav._change_text)
	note("CARD AFTER ROLLBACK:\n" + card_back)
	expect("rollback rolled_back", card_back.contains("status: rolled_back"), card_back)
	expect("observed still not run", card_back.contains("not run since change"), card_back)
	expect("static no longer matches", card_back.contains("file no longer matches this change"), card_back)
	expect("no removed row", card_back.find("removed") < 0, card_back)
	expect("no line delta after rollback", card_back.find("line delta") < 0, card_back)
	assert_no_safe_success("card after rollback", card_back)
	await shot("06_after_rollback", nav)

	CS.begin("Probe patch 2", "make_patch", "Second change.")
	var wrote2: Array = Safe.write("res://Caverns.vg", changed)
	expect("second write", bool(wrote2[0]), str(wrote2))
	CS.end()
	var edited := changed + "\n' user edit\n"
	var edited_file := FileAccess.open("res://Caverns.vg", FileAccess.WRITE)
	edited_file.store_string(edited)
	edited_file.close()
	nav.show_last_change()
	nav._on_change_rollback_confirmed()
	await wait_s(0.5)
	var card_conflict := str(nav._change_text)
	note("CARD CONFLICT:\n" + card_conflict)
	expect("conflict status", card_conflict.contains("status: conflict"), card_conflict)
	expect("edited after change", card_conflict.contains("edited after change"), card_conflict)
	var left := FileAccess.get_file_as_bytes("res://Caverns.vg")
	expect("conflict leaves the user edit", left == edited.to_utf8_buffer(), "size %d" % left.size())
	assert_no_safe_success("card conflict", card_conflict)
	await shot("07_conflict", nav)
	_finish()


func _finish() -> void:
	if failures == 0:
		note("[PASS] editor_ui_probe")
	else:
		note("[FAIL] editor_ui_probe failures=%d" % failures)
	var out := str(cfg.get("out", ""))
	if not out.is_empty():
		var f := FileAccess.open(out.path_join("probe_log.txt"), FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(log_lines))
			f.close()
	if failures == 0:
		get_tree().quit(0)
	else:
		get_tree().quit(1)
