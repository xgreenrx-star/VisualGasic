@tool
extends EditorPlugin

const OUT := "/tmp/vg_ui_probe/out"
var log_lines: Array = []

func _enter_tree() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_go.call_deferred()

func note(s: String) -> void:
	print("PROBE: " + s)
	log_lines.append(s)

func wait_s(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func shot(name: String, nav: Control) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_editor_interface().get_base_control().get_viewport().get_texture().get_image()
	img.save_png(OUT.path_join(name + "_full.png"))
	if nav != null and nav.is_visible_in_tree():
		var r := Rect2i(nav.get_global_rect())
		r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if r.size.x > 4 and r.size.y > 4:
			img.get_region(r).save_png(OUT.path_join(name + "_nav.png"))
	note("shot " + name)

func _go() -> void:
	await wait_s(12.0)
	var base := get_editor_interface().get_base_control()
	note("window size %s" % str(base.get_viewport().get_visible_rect().size))
	var vg = base.get_meta("visual_gasic_plugin_instance") if base.has_meta("visual_gasic_plugin_instance") else null
	if vg == null:
		note("FAIL no VG plugin instance"); _finish(); return
	var nav = vg.get("_code_navigator")
	if nav == null:
		note("FAIL no code navigator"); _finish(); return
	note("navigator parent=%s visible=%s" % [str(nav.get_parent()), str(nav.visible)])
	get_editor_interface().set_main_screen_editor("Script")
	var scr = load("res://Caverns.vg")
	get_editor_interface().edit_script(scr, 71)
	await wait_s(2.0)
	nav.visible = true
	var p = nav.get_parent()
	while p != null and p is Control:
		if not p.visible:
			note("parent hidden: %s" % str(p)); p.visible = true
		p = p.get_parent()
	await wait_s(1.0)
	await shot("01_navigator_default", nav)
	# Phase 4 panel with a real 6-crystal snapshot
	var snap = JSON.parse_string(FileAccess.get_file_as_string("/tmp/vg_ui_probe/snapshot.json"))
	nav._evidence_toggle.button_pressed = true
	await wait_s(0.5)
	nav.set_evidence_source(str(scr.source_code), 71, "res://Caverns.vg")
	nav.set_evidence_run(snap, "ended")
	await wait_s(1.0)
	note("evidence header: " + nav.evidence_header_text())
	note("evidence banner: " + nav.evidence_banner_text())
	note("evidence prompt: " + nav.evidence_prompt_text())
	note("evidence rows: " + str(nav.evidence_row_statuses()))
	await shot("02_evidence_panel", nav)
	# Phase 5 change card: Narcea-style change through SafeWrite
	var CS = load("res://addons/visual_gasic/vg_change_set.gd")
	var Safe = load("res://addons/visual_gasic/vg_ai_safe_write.gd").new()
	Safe.set_root("res://")
	var before := FileAccess.get_file_as_bytes("res://Caverns.vg")
	var text := before.get_string_from_utf8()
	var changed := text.replace("crystals Becomes GEM_TARGET OnUnlockExit", "crystals Becomes 5 OnUnlockExit")
	note("edit applies: %s" % str(changed != text))
	CS.begin("Probe patch", "make_patch", "I changed the exit so it opens after 5 crystals instead of 6. Everything else is unchanged and the game is safe to run.")
	note("write: " + str(Safe.write("res://Caverns.vg", changed)))
	CS.end()
	nav._evidence_toggle.button_pressed = false
	nav.show_last_change()
	await wait_s(1.0)
	note("CARD BEFORE CHECKS:\n" + str(nav._change_text))
	await shot("03_change_card", nav)
	nav._on_change_run_checks()
	var t0 := Time.get_ticks_msec()
	while (str(nav._change_running) != "" or not nav._change_queue.is_empty()) and Time.get_ticks_msec() - t0 < 400000:
		await wait_s(1.0)
	note("checks took %d ms" % (Time.get_ticks_msec() - t0))
	note("CARD AFTER CHECKS:\n" + str(nav._change_text))
	await shot("04_after_checks", nav)
	nav._on_change_rollback_pressed()
	await wait_s(1.0)
	note("confirm dialog: " + str(nav._change_confirm.dialog_text))
	await shot("05_rollback_confirm", null)
	nav._change_confirm.hide()
	nav._on_change_rollback_confirmed()
	await wait_s(1.5)
	var after := FileAccess.get_file_as_bytes("res://Caverns.vg")
	note("byte-identical after rollback: %s" % str(after == before))
	note("CARD AFTER ROLLBACK:\n" + str(nav._change_text))
	await shot("06_after_rollback", nav)
	# Conflict case
	CS.begin("Probe patch 2", "make_patch", "Second change.")
	Safe.write("res://Caverns.vg", changed)
	CS.end()
	var f := FileAccess.open("res://Caverns.vg", FileAccess.WRITE)
	f.store_string(changed + "\n' user edit\n")
	f.close()
	nav.show_last_change()
	nav._on_change_rollback_confirmed()
	await wait_s(1.0)
	note("CARD CONFLICT:\n" + str(nav._change_text))
	await shot("07_conflict", nav)
	var f2 := FileAccess.open("res://Caverns.vg", FileAccess.WRITE)
	f2.store_buffer(before)
	f2.close()
	_finish()

func _finish() -> void:
	var f := FileAccess.open(OUT.path_join("probe_log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(log_lines))
	f.close()
	get_tree().quit()
