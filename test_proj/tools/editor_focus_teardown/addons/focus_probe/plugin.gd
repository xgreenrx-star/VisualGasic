@tool
extends EditorPlugin

var _window: Window

func _enter_tree() -> void:
	call_deferred("_run")

func _run() -> void:
	for frame in range(10):
		await get_tree().process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	if ClassDB.class_exists(&"VisualGasicLanguage"):
		push_error("WINDOW-FOCUS FAIL: probe must not load the VG extension")
		get_tree().quit(1)
		return
	_window = Window.new()
	_window.title = "Focus teardown probe"
	_window.size = Vector2i(200, 100)
	var window_owner := str(ProjectSettings.get_setting("probe/window_owner", "base"))
	if window_owner == "base":
		EditorInterface.get_base_control().add_child(_window)
	elif window_owner == "plugin":
		add_child(_window)
	else:
		push_error("WINDOW-FOCUS FAIL: invalid window owner")
		get_tree().quit(1)
		return
	_window.popup_centered()
	for frame in range(10):
		await get_tree().process_frame
	if not _window.visible:
		push_error("WINDOW-FOCUS FAIL: popup is not visible")
		get_tree().quit(1)
		return
	if ProjectSettings.get_setting("probe/close_before_quit", false):
		_window.hide()
		for frame in range(2):
			await get_tree().process_frame
	print("WINDOW-FOCUS READY: no VG extension or custom debugger loaded")
	get_tree().quit()
