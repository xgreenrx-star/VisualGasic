# vg_live_preview_manager.gd
# Live animation preview system for custom controls in the Form Designer.
# Instead of static one-shot SubViewport captures, this manager keeps a
# persistent SubViewport per custom control type and periodically recaptures
# frames, so animated controls (spinners, progress bars, particle effects)
# show live animation on the design canvas.
#
# Usage from visual_gasic_plugin.gd:
#   _live_preview_mgr = VGLivePreviewManager.new(self, _form_designer)
#   _live_preview_mgr.register_control("MySpinner", "res://custom_widgets/MySpinner.tscn")
#   _live_preview_mgr.set_frozen(true)   # pause all captures
#   _live_preview_mgr.set_focused(false) # throttle when Form Designer tab not active
@tool
extends Node

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
## Capture rate when form designer is focused (frames per second)
const FOCUSED_FPS := 15.0
## Capture rate when form designer tab is NOT focused
const UNFOCUSED_FPS := 4.0
## SubViewport size for captures
const VIEWPORT_SIZE := Vector2i(200, 150)
## Minimum interval between captures of the SAME control (seconds)
const MIN_CAPTURE_INTERVAL := 0.03

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
## Reference to the C++ form designer node
var _form_designer: Node = null
## Reference to the plugin (parent)
var _plugin: Node = null
## Whether previews are frozen (paused)
var _frozen := false
## Whether the form designer tab is currently focused
var _is_focused := true

## Per-type live viewport data: {type_name -> ViewportData}
## ViewportData = {viewport: SubViewport, instance: Node, texture: ImageTexture, last_capture: float}
var _viewports: Dictionary = {}

## Capture timer
var _capture_timer: Timer = null

## Round-robin index — captures one viewport per tick for performance
var _capture_index := 0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _init(plugin: Node = null, form_designer: Node = null) -> void:
	_plugin = plugin
	_form_designer = form_designer
	name = "LivePreviewManager"

func _ready() -> void:
	_capture_timer = Timer.new()
	_capture_timer.name = "CaptureTimer"
	_capture_timer.one_shot = false
	_capture_timer.autostart = true
	_capture_timer.wait_time = 1.0 / FOCUSED_FPS
	add_child(_capture_timer)
	_capture_timer.timeout.connect(_on_capture_tick)

func _exit_tree() -> void:
	_clear_all()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Register a custom control type for live preview rendering.
## Creates a persistent SubViewport with the control's .tscn instantiated.
## @param ctrl_name: Control type name (e.g. "MySpinner")
## @param scene_path: Path to the .tscn file
func register_control(ctrl_name: String, scene_path: String) -> void:
	if _viewports.has(ctrl_name):
		# Already registered — skip
		return
	if not FileAccess.file_exists(scene_path):
		return

	var packed = load(scene_path)
	if not packed or not packed is PackedScene:
		return

	var instance = packed.instantiate()
	if not instance or not instance is Control:
		if instance:
			instance.queue_free()
		return

	# Create persistent SubViewport
	var vp := SubViewport.new()
	vp.name = "LiveVP_%s" % ctrl_name
	vp.size = VIEWPORT_SIZE
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = true  # No input needed for preview

	# Fill the viewport
	if instance is Control:
		instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(instance)

	# Add to scene tree (hidden, just for rendering)
	add_child(vp)

	# Create initial texture
	var tex := ImageTexture.new()

	_viewports[ctrl_name] = {
		"viewport": vp,
		"instance": instance,
		"texture": tex,
		"last_capture": 0.0,
		"scene_path": scene_path,
	}

	# Do an immediate first capture after 2 frames (viewport needs to render)
	_do_deferred_first_capture(ctrl_name)

## Unregister a control type and clean up its SubViewport.
func unregister_control(ctrl_name: String) -> void:
	if not _viewports.has(ctrl_name):
		return
	var data: Dictionary = _viewports[ctrl_name]
	var vp: SubViewport = data["viewport"]
	var instance: Node = data["instance"]

	vp.remove_child(instance)
	instance.queue_free()
	remove_child(vp)
	vp.queue_free()
	_viewports.erase(ctrl_name)

## Register all enabled custom components for live preview.
func register_all_enabled() -> void:
	var ComponentsDialog = load("res://addons/visual_gasic/components_dialog.gd")
	if not ComponentsDialog:
		return
	var enabled = ComponentsDialog.load_enabled_components()
	for comp in enabled:
		var cname: String = comp["name"]
		var scene: String = comp.get("scene", "")
		if not comp.get("builtin", false) and not scene.is_empty():
			register_control(cname, scene)

## Freeze/unfreeze all live previews.
## When frozen, no new captures are taken (saves CPU/GPU).
func set_frozen(frozen: bool) -> void:
	_frozen = frozen
	for ctrl_name in _viewports:
		var data: Dictionary = _viewports[ctrl_name]
		var vp: SubViewport = data["viewport"]
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED if frozen else SubViewport.UPDATE_ALWAYS

## @return Whether previews are currently frozen
func is_frozen() -> bool:
	return _frozen

## Notify the manager whether the form designer tab is focused.
## When unfocused, capture rate drops to save resources.
func set_focused(focused: bool) -> void:
	_is_focused = focused
	if _capture_timer:
		var fps := FOCUSED_FPS if focused else UNFOCUSED_FPS
		_capture_timer.wait_time = 1.0 / fps

## Force a single capture of all viewports right now.
func capture_all_now() -> void:
	for ctrl_name in _viewports:
		_capture_one(ctrl_name)

## Set the form designer reference (if it changes after init).
func set_form_designer(fd: Node) -> void:
	_form_designer = fd

# ---------------------------------------------------------------------------
# Internal — round-robin capture
# ---------------------------------------------------------------------------

## Timer callback — captures one viewport per tick in round-robin fashion.
## This spreads the GPU readback cost across frames instead of doing all at once.
func _on_capture_tick() -> void:
	if _frozen:
		return
	if _viewports.is_empty():
		return

	var keys := _viewports.keys()
	if _capture_index >= keys.size():
		_capture_index = 0

	var ctrl_name: String = keys[_capture_index]
	_capture_one(ctrl_name)
	_capture_index = (_capture_index + 1) % keys.size()

## Capture a single viewport and update the form designer texture.
func _capture_one(ctrl_name: String) -> void:
	if not _viewports.has(ctrl_name):
		return
	var data: Dictionary = _viewports[ctrl_name]
	var vp: SubViewport = data["viewport"]

	if not is_instance_valid(vp):
		return

	# Rate-limit per control
	var now := Time.get_ticks_msec() / 1000.0
	if now - data["last_capture"] < MIN_CAPTURE_INTERVAL:
		return

	var img: Image = vp.get_texture().get_image()
	if img == null or img.is_empty():
		return

	# Update the existing ImageTexture in-place (avoids allocation churn)
	var tex: ImageTexture = data["texture"]
	tex.set_image(img)
	data["last_capture"] = now

	# Push to C++ form designer
	if _form_designer and _form_designer.has_method("set_control_preview_texture"):
		_form_designer.set_control_preview_texture(ctrl_name, tex)

## Deferred first capture — waits 2 frames for the viewport to render.
func _do_deferred_first_capture(ctrl_name: String) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_one(ctrl_name)

## Clean up all viewports.
func _clear_all() -> void:
	for ctrl_name in _viewports.keys():
		unregister_control(ctrl_name)
	_viewports.clear()
