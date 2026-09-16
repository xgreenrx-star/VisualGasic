extends Node2D

const GDAI = preload("res://addons/visual_gasic/gdai.gd")

func _ready() -> void:
	var status = $Status
	var query_button = $QueryButton
	query_button.pressed.connect(Callable(self, "_on_query_pressed"))

	status.text = "Loading VGAI..."
	GDAI.initialize_from_project_settings()

	if not GDAI.is_enabled():
		status.text = "VGAI not configured. Set vg/gdai values in project settings."
		query_button.disabled = true
		return

	status.text = "VGAI is ready. Press Ask VGAI."
	query_button.disabled = false

func _on_query_pressed() -> void:
	var status = $Status
	if not GDAI.is_enabled():
		status.text = "VGAI unavailable. Check settings."
		return

	status.text = "Querying VGAI..."
	await _send_vgai_request()

func _send_vgai_request() -> void:
	var prompt = "Write a short one-line arcade game pitch for a retro space shooter called VGAI Demo."
	var response = await GDAI.complete(prompt)

	if GDAI.has_error():
		$Status.text = "Error: %s" % GDAI.get_last_error()
	else:
		$Status.text = "VGAI: %s" % response
