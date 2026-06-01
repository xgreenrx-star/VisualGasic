@tool
extends Node
class_name VGTweakSystem

# Autoload: install once per project (Project > AutoLoad). Listens for the
# universal toggle hotkey (Ctrl+Shift+T) and spawns/destroys the overlay.

signal overlay_opened()
signal overlay_closed()
signal ai_edit_requested(request: Dictionary)

const OVERLAY_SCRIPT_PATH := "res://addons/visual_gasic/vg_tweak_overlay.gd"
const HOTKEY_KEYCODE := KEY_T
const HOTKEY_REQUIRES_CTRL := true
const HOTKEY_REQUIRES_SHIFT := true

var _overlay: Control = null
var _was_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == HOTKEY_KEYCODE \
				and event.ctrl_pressed == HOTKEY_REQUIRES_CTRL \
				and event.shift_pressed == HOTKEY_REQUIRES_SHIFT:
			toggle()

func toggle() -> void:
	if is_open():
		close()
	else:
		open()

func is_open() -> bool:
	return _overlay != null and is_instance_valid(_overlay)

func open() -> void:
	if is_open():
		return
	if not ResourceLoader.exists(OVERLAY_SCRIPT_PATH):
		push_warning("[VGTweakSystem] overlay script missing: %s" % OVERLAY_SCRIPT_PATH)
		return
	var script: Script = load(OVERLAY_SCRIPT_PATH)
	_overlay = script.new()
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	# The overlay handles its own pause toggle button; we leave game state alone here.
	get_tree().root.add_child(_overlay)
	if _overlay.has_signal("overlay_closed"):
		_overlay.overlay_closed.connect(_on_overlay_closed)
	if _overlay.has_signal("ai_edit_requested"):
		_overlay.ai_edit_requested.connect(func(req): emit_signal("ai_edit_requested", req))
	emit_signal("overlay_opened")

func close() -> void:
	if not is_open():
		return
	_overlay.queue_free()
	_overlay = null
	if get_tree().paused and not _was_paused:
		get_tree().paused = false
	emit_signal("overlay_closed")

func _on_overlay_closed() -> void:
	_overlay = null
	if get_tree().paused and not _was_paused:
		get_tree().paused = false
	emit_signal("overlay_closed")
