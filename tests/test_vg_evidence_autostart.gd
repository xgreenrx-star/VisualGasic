extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, what: String) -> void:
	checks += 1
	if ok:
		return
	failures += 1
	push_error("FAIL: " + what)

func _run() -> void:
	if not ClassDB.class_exists("VisualGasicLanguage"):
		push_error("FAIL: VisualGasicLanguage is not loaded")
		quit(1)
		return
	check(VisualGasicLanguage.vg_evidence_autostart_decision(false, true) == false, "setting off does not autostart")
	check(VisualGasicLanguage.vg_evidence_autostart_decision(true, false) == false, "no debugger does not autostart")
	check(VisualGasicLanguage.vg_evidence_autostart_decision(false, false) == false, "both off does not autostart")
	check(VisualGasicLanguage.vg_evidence_autostart_decision(true, true) == true, "setting and debugger autostart")
	ProjectSettings.set_setting("vg/evidence/runtime_ring", false)
	_assert_instance_does_not_record("setting false")
	ProjectSettings.set_setting("vg/evidence/runtime_ring", true)
	_assert_instance_does_not_record("setting true without a debugger")
	ProjectSettings.set_setting("vg/evidence/runtime_ring", false)
	for sample in [[128, 128], [8, 64], [9000, 4096]]:
		ProjectSettings.set_setting("vg/evidence/runtime_ring_capacity", sample[0])
		VisualGasicLanguage.vg_evidence_stop()
		VisualGasicLanguage.vg_evidence_start({})
		var snap: Dictionary = VisualGasicLanguage.vg_evidence_snapshot()
		check(int(snap.get("capacity", 0)) == sample[1], "capacity %s clamps to %s, got %s" % [str(sample[0]), str(sample[1]), str(snap.get("capacity", 0))])
		VisualGasicLanguage.vg_evidence_stop()
	ProjectSettings.set_setting("vg/evidence/runtime_ring_capacity", 512)
	if failures == 0:
		print("EVIDENCE AUTOSTART: %d passed" % checks)
		quit(0)
	else:
		print("EVIDENCE AUTOSTART: %d failed / %d" % [failures, checks])
		quit(1)

func _assert_instance_does_not_record(label: String) -> void:
	VisualGasicLanguage.vg_evidence_stop()
	var scr := VisualGasicScript.new()
	scr.source_code = "Dim n As Integer\nn = 1\n"
	var err: Error = scr.reload()
	check(err == OK, label + " reload")
	var node := Node.new()
	root.add_child(node)
	node.set_script(scr)
	var snap: Dictionary = VisualGasicLanguage.vg_evidence_snapshot()
	check(bool(snap.get("recording", true)) == false, label + " instance did not start recording")
	check(str(snap.get("run_id", "")) == "", label + " instance did not open a run")
	node.free()
	VisualGasicLanguage.vg_evidence_stop()
