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
	if not ClassDB.can_instantiate("EditorDebuggerPlugin"):
		push_error("FAIL: EditorDebuggerPlugin is not instantiable in this process")
		quit(1)
		return
	var plugin_script = load("res://addons/visual_gasic/vg_debugger_plugin.gd")
	var plugin = plugin_script.new()
	if plugin == null:
		push_error("FAIL: debugger plugin did not instantiate")
		quit(1)
		return
	var box: Array = [{}]
	plugin.evidence_data_received.connect(func(snapshot: Dictionary) -> void:
		box[0] = snapshot
	)
	var snap := {
		"schema": "behavior-run/1",
		"run_id": "run-9",
		"recording": true,
		"dropped": 0,
		"capacity": 512,
		"events": [{"seq": 1, "kind": "whenever_fired"}],
	}
	var captured: bool = plugin._capture("visualgasic:evidence_data", [snap], 0)
	check(captured, "capture accepts evidence_data")
	var received: Dictionary = box[0]
	check(received == snap, "signal carries the same snapshot, got %s" % str(received))
	check(str(plugin.get_evidence_snapshot().get("run_id", "")) == "run-9", "memory keeps the snapshot")
	plugin.note_debug_session_started()
	check(plugin.get_evidence_snapshot().is_empty(), "session start clears the snapshot")
	check(plugin.get_evidence_run_state() == "running", "session start marks running")
	plugin._capture("visualgasic:evidence_data", [snap], 0)
	plugin.note_debug_session_stopped()
	check(plugin.get_evidence_run_state() == "ended", "session stop marks ended")
	check(str(plugin.get_evidence_snapshot().get("run_id", "")) == "run-9", "session stop keeps the snapshot")
	plugin.clear_evidence_memory()
	check(plugin.get_evidence_snapshot().is_empty(), "clear drops the snapshot")
	check(plugin.get_evidence_run_state() == "none", "clear marks none")
	if failures == 0:
		print("EVIDENCE TRANSPORT: %d passed" % checks)
		quit(0)
	else:
		print("EVIDENCE TRANSPORT: %d failed / %d" % [failures, checks])
		quit(1)
