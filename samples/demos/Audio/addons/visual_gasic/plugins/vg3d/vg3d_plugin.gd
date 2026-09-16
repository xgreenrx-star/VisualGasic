@tool
## VG3D — 3D Game Kit Technology Preview
##
## A minimal voxel block editor to demonstrate what a future 3D game kit
## could look like inside the VisualGasic IDE.
##
## Features:
##   • 16×16 grid with click-to-place / right-click-to-erase colored blocks
##   • Orbit camera (drag to rotate, scroll to zoom)
##   • Color palette (8 colors)
##   • Stack blocks up to 8 high
##   • Clear All button
##   • Play Mode: first-person WASD walk-around inside the scene
extends "res://addons/visual_gasic/vg_plugin_base.gd"

# ─── Constants ───────────────────────────────────────────────
const GRID_SIZE := 16
const MAX_HEIGHT := 8
const BLOCK_SIZE := 1.0

const BG_COLOR      := Color(0.10, 0.10, 0.14)
const PANEL_COLOR   := Color(0.14, 0.14, 0.18)
const SIDEBAR_BG    := Color(0.11, 0.11, 0.15)
const ACCENT        := Color(0.45, 0.75, 1.0)
const WHITE         := Color(1.0, 1.0, 1.0)
const DIM           := Color(0.55, 0.55, 0.60)
const GRID_LINE_COL := Color(0.3, 0.3, 0.35, 0.5)

const PALETTE := [
	Color(0.85, 0.25, 0.25),  # Red
	Color(0.25, 0.70, 0.30),  # Green
	Color(0.30, 0.50, 0.90),  # Blue
	Color(0.90, 0.80, 0.20),  # Yellow
	Color(0.70, 0.35, 0.85),  # Purple
	Color(0.90, 0.55, 0.15),  # Orange
	Color(0.20, 0.75, 0.75),  # Cyan
	Color(0.85, 0.85, 0.85),  # White/Light
]

const PALETTE_NAMES := [
	"Red", "Green", "Blue", "Yellow", "Purple", "Orange", "Cyan", "White"
]

# ─── State ───────────────────────────────────────────────────
var _blocks: Dictionary = {}        # Vector3i -> color_index
var _selected_color: int = 0
var _block_count_label: Label = null
var _status_label: Label = null

# 3D viewport
var _sub_viewport: SubViewport = null
var _camera_3d: Camera3D = null
var _world_root: Node3D = null        # holds blocks + grid floor
var _block_parent: Node3D = null      # holds placed blocks

# Camera orbit state
var _cam_distance: float = 18.0
var _cam_yaw: float = -45.0
var _cam_pitch: float = -35.0
var _cam_target: Vector3 = Vector3(GRID_SIZE / 2.0, 0, GRID_SIZE / 2.0)
var _cam_dragging: bool = false
var _cam_drag_start: Vector2 = Vector2.ZERO

# Interaction
var _viewport_rect: SubViewportContainer = null
var _color_btns: Array = []
var _play_mode: bool = false

# Play mode
var _player_body: CharacterBody3D = null
var _player_cam: Camera3D = null
var _player_yaw: float = 0.0
var _player_pitch: float = 0.0
var _fps_mouse_captured: bool = false

# ─── Plugin Identity ─────────────────────────────────────────

func get_plugin_name() -> String:
	return "VG3D"

func get_toolbar_icon() -> String:
	return "🧊"

func get_toolbar_color() -> Color:
	return Color(0.3, 0.55, 0.85)

func get_toolbar_tooltip() -> String:
	return "3D Game Kit — Technology Preview"

# ─── Label helper ────────────────────────────────────────────
func _ls(size: int, color: Color) -> LabelSettings:
	var s := LabelSettings.new()
	s.font_size = size
	s.font_color = color
	return s

# ─── Build UI ────────────────────────────────────────────────

func _build_ui() -> void:
	# Root background
	var bg := PanelContainer.new()
	var bg_s := StyleBoxFlat.new()
	bg_s.bg_color = BG_COLOR
	bg.add_theme_stylebox_override("panel", bg_s)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.add_child(bg)

	var root_h := HBoxContainer.new()
	root_h.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(root_h)

	# ─── Left sidebar: palette + tools ───────────────────────
	var sidebar := PanelContainer.new()
	var sb_s := StyleBoxFlat.new()
	sb_s.bg_color = SIDEBAR_BG
	sb_s.content_margin_left = 10
	sb_s.content_margin_right = 10
	sb_s.content_margin_top = 10
	sb_s.content_margin_bottom = 10
	sidebar.add_theme_stylebox_override("panel", sb_s)
	sidebar.custom_minimum_size.x = 180
	root_h.add_child(sidebar)

	var side_vbox := VBoxContainer.new()
	side_vbox.add_theme_constant_override("separation", 8)
	sidebar.add_child(side_vbox)

	# Title
	var title := Label.new()
	title.text = "🧊 VG3D Preview"
	title.label_settings = _ls(16, ACCENT)
	side_vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Technology Preview"
	subtitle.label_settings = _ls(11, DIM)
	side_vbox.add_child(subtitle)

	# Separator
	side_vbox.add_child(HSeparator.new())

	# Palette header
	var pal_lbl := Label.new()
	pal_lbl.text = "Block Palette"
	pal_lbl.label_settings = _ls(13, WHITE)
	side_vbox.add_child(pal_lbl)

	# Color grid (2 columns)
	var pal_grid := GridContainer.new()
	pal_grid.columns = 2
	pal_grid.add_theme_constant_override("h_separation", 4)
	pal_grid.add_theme_constant_override("v_separation", 4)
	side_vbox.add_child(pal_grid)

	for i in PALETTE.size():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(75, 36)
		btn.text = PALETTE_NAMES[i]
		var btn_s := StyleBoxFlat.new()
		btn_s.bg_color = PALETTE[i]
		btn_s.corner_radius_top_left = 4
		btn_s.corner_radius_top_right = 4
		btn_s.corner_radius_bottom_left = 4
		btn_s.corner_radius_bottom_right = 4
		btn_s.content_margin_left = 6
		btn_s.content_margin_right = 6
		btn.add_theme_stylebox_override("normal", btn_s)

		var hover_s := btn_s.duplicate()
		hover_s.bg_color = PALETTE[i].lightened(0.2)
		btn.add_theme_stylebox_override("hover", hover_s)

		var pressed_s := btn_s.duplicate()
		pressed_s.bg_color = PALETTE[i].darkened(0.2)
		pressed_s.border_width_bottom = 3
		pressed_s.border_width_top = 3
		pressed_s.border_width_left = 3
		pressed_s.border_width_right = 3
		pressed_s.border_color = WHITE
		btn.add_theme_stylebox_override("pressed", pressed_s)

		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		btn.button_group = _get_or_create_palette_group()
		var idx := i
		btn.pressed.connect(func(): _on_color_selected(idx))
		pal_grid.add_child(btn)
		_color_btns.append(btn)

	# Separator
	side_vbox.add_child(HSeparator.new())

	# Tools header
	var tools_lbl := Label.new()
	tools_lbl.text = "Tools"
	tools_lbl.label_settings = _ls(13, WHITE)
	side_vbox.add_child(tools_lbl)

	# Current layer
	var layer_h := HBoxContainer.new()
	layer_h.add_theme_constant_override("separation", 6)
	side_vbox.add_child(layer_h)
	var layer_lbl := Label.new()
	layer_lbl.text = "Layer (Y):"
	layer_lbl.label_settings = _ls(12, DIM)
	layer_h.add_child(layer_lbl)
	var layer_spin := SpinBox.new()
	layer_spin.min_value = 0
	layer_spin.max_value = MAX_HEIGHT - 1
	layer_spin.value = 0
	layer_spin.custom_minimum_size.x = 70
	layer_spin.value_changed.connect(_on_layer_changed)
	layer_h.add_child(layer_spin)

	# Clear button
	var clear_btn := Button.new()
	clear_btn.text = "🗑️ Clear All"
	clear_btn.custom_minimum_size = Vector2(0, 32)
	clear_btn.pressed.connect(_on_clear_all)
	side_vbox.add_child(clear_btn)

	# Play/Edit toggle
	var play_btn := Button.new()
	play_btn.text = "▶ Play Mode"
	play_btn.custom_minimum_size = Vector2(0, 36)
	var play_s := StyleBoxFlat.new()
	play_s.bg_color = Color(0.2, 0.6, 0.3)
	play_s.corner_radius_top_left = 4
	play_s.corner_radius_top_right = 4
	play_s.corner_radius_bottom_left = 4
	play_s.corner_radius_bottom_right = 4
	play_btn.add_theme_stylebox_override("normal", play_s)
	play_btn.pressed.connect(_on_play_toggle)
	side_vbox.add_child(play_btn)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_vbox.add_child(spacer)

	# Status
	_block_count_label = Label.new()
	_block_count_label.text = "Blocks: 0"
	_block_count_label.label_settings = _ls(11, DIM)
	side_vbox.add_child(_block_count_label)

	_status_label = Label.new()
	_status_label.text = "Click to place • Right-click to erase"
	_status_label.label_settings = _ls(10, DIM)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	side_vbox.add_child(_status_label)

	var ver_lbl := Label.new()
	ver_lbl.text = "v0.1 — Preview"
	ver_lbl.label_settings = _ls(10, Color(0.4, 0.4, 0.5))
	side_vbox.add_child(ver_lbl)

	# ─── Right side: 3D viewport ─────────────────────────────
	var vp_panel := PanelContainer.new()
	vp_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vp_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var vp_s := StyleBoxFlat.new()
	vp_s.bg_color = Color(0.08, 0.08, 0.10)
	vp_panel.add_theme_stylebox_override("panel", vp_s)
	root_h.add_child(vp_panel)

	# SubViewportContainer + SubViewport
	_viewport_rect = SubViewportContainer.new()
	_viewport_rect.stretch = true
	_viewport_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vp_panel.add_child(_viewport_rect)

	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(800, 600)
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub_viewport.own_world_3d = true
	_sub_viewport.transparent_bg = false
	_viewport_rect.add_child(_sub_viewport)

	# 3D scene inside viewport
	_world_root = Node3D.new()
	_world_root.name = "VG3DWorld"
	_sub_viewport.add_child(_world_root)

	# Camera
	_camera_3d = Camera3D.new()
	_camera_3d.name = "OrbitCamera"
	_camera_3d.fov = 50.0
	_camera_3d.near = 0.1
	_camera_3d.far = 200.0
	_world_root.add_child(_camera_3d)
	_update_orbit_camera()

	# Environment + light
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.15, 0.18, 0.25)
	env.ambient_light_color = Color(0.6, 0.65, 0.75)
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	_world_root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	_world_root.add_child(sun)

	# Grid floor
	_build_grid_floor()

	# Block container
	_block_parent = Node3D.new()
	_block_parent.name = "Blocks"
	_world_root.add_child(_block_parent)

	# Connect viewport input
	_viewport_rect.gui_input.connect(_on_viewport_input)

	# Place a few starter blocks so it's not empty
	_place_starter_blocks()

# ─── State ───────────────────────────────────────────────────
var _current_layer: int = 0
var _palette_group: ButtonGroup = null

func _get_or_create_palette_group() -> ButtonGroup:
	if _palette_group == null:
		_palette_group = ButtonGroup.new()
	return _palette_group

# ─── Grid Floor ──────────────────────────────────────────────

func _build_grid_floor() -> void:
	# A flat plane as the floor
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(GRID_SIZE, GRID_SIZE)
	var floor_inst := MeshInstance3D.new()
	floor_inst.mesh = floor_mesh
	floor_inst.position = Vector3(GRID_SIZE / 2.0, -0.01, GRID_SIZE / 2.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.20, 0.25)
	mat.roughness = 0.9
	floor_inst.material_override = mat
	_world_root.add_child(floor_inst)

	# Grid lines using ImmediateMesh
	var im := ImmediateMesh.new()
	var grid_inst := MeshInstance3D.new()
	grid_inst.name = "GridLines"

	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = GRID_LINE_COL
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	im.surface_begin(Mesh.PRIMITIVE_LINES, line_mat)
	for i in range(GRID_SIZE + 1):
		# X lines
		im.surface_add_vertex(Vector3(float(i), 0.0, 0.0))
		im.surface_add_vertex(Vector3(float(i), 0.0, float(GRID_SIZE)))
		# Z lines
		im.surface_add_vertex(Vector3(0.0, 0.0, float(i)))
		im.surface_add_vertex(Vector3(float(GRID_SIZE), 0.0, float(i)))
	im.surface_end()

	grid_inst.mesh = im
	_world_root.add_child(grid_inst)

# ─── Starter blocks ─────────────────────────────────────────

func _place_starter_blocks() -> void:
	# Place a small L-shaped wall so the user sees something immediately
	var pattern := [
		Vector3i(3, 0, 3), Vector3i(4, 0, 3), Vector3i(5, 0, 3),
		Vector3i(3, 0, 4), Vector3i(3, 0, 5),
		Vector3i(3, 1, 3), Vector3i(4, 1, 3), Vector3i(5, 1, 3),
		Vector3i(3, 1, 4),
		Vector3i(3, 2, 3), Vector3i(4, 2, 3),
		# A tower
		Vector3i(8, 0, 8), Vector3i(8, 1, 8), Vector3i(8, 2, 8),
		Vector3i(8, 3, 8), Vector3i(8, 4, 8),
		# Some colored floor
		Vector3i(6, 0, 6), Vector3i(7, 0, 6), Vector3i(6, 0, 7), Vector3i(7, 0, 7),
	]
	var colors := [
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		2, 2, 2, 2, 2,
		3, 3, 3, 3,
	]
	for i in pattern.size():
		var pos: Vector3i = pattern[i]
		var ci: int = colors[i] if i < colors.size() else 0
		_blocks[pos] = ci
		_spawn_block_mesh(pos, ci)
	_update_block_count()

# ─── Block mesh management ──────────────────────────────────

func _spawn_block_mesh(pos: Vector3i, color_idx: int) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3(BLOCK_SIZE * 0.96, BLOCK_SIZE * 0.96, BLOCK_SIZE * 0.96)

	var inst := MeshInstance3D.new()
	inst.mesh = box
	inst.position = Vector3(pos.x + 0.5, pos.y + 0.5, pos.z + 0.5)
	inst.name = "Block_%d_%d_%d" % [pos.x, pos.y, pos.z]

	var mat := StandardMaterial3D.new()
	mat.albedo_color = PALETTE[color_idx]
	mat.roughness = 0.7
	mat.metallic = 0.1
	inst.material_override = mat

	_block_parent.add_child(inst)
	return inst

func _remove_block_mesh(pos: Vector3i) -> void:
	var n := "Block_%d_%d_%d" % [pos.x, pos.y, pos.z]
	var child := _block_parent.get_node_or_null(n)
	if child:
		child.queue_free()

func _update_block_count() -> void:
	if _block_count_label:
		_block_count_label.text = "Blocks: %d" % _blocks.size()


# ─── AI / persistence helpers ────────────────────────────────

## Returns the current block layout as a serialisable dictionary.
## Schema: { "blocks": [[x,y,z,color_index], ...], "palette": ["#rrggbb", ...] }
func get_project_data() -> Dictionary:
	var blocks_arr: Array = []
	for pos in _blocks:
		blocks_arr.append([pos.x, pos.y, pos.z, _blocks[pos]])
	var palette_arr: Array = []
	for c in PALETTE:
		palette_arr.append(c.to_html(false))
	return {"blocks": blocks_arr, "palette": palette_arr}


## Replaces the current block layout from a dictionary produced by get_project_data().
func set_project_data(data: Dictionary) -> void:
	# Clear existing meshes.
	_blocks.clear()
	if is_instance_valid(_block_parent):
		for child in _block_parent.get_children():
			child.queue_free()
	# Rebuild from data.
	for item in data.get("blocks", []):
		if not (item is Array) or item.size() < 4:
			continue
		var pos := Vector3i(int(item[0]), int(item[1]), int(item[2]))
		var ci := clamp(int(item[3]), 0, PALETTE.size() - 1)
		_blocks[pos] = ci
		_spawn_block_mesh(pos, ci)
	_update_block_count()


# ─── Camera ──────────────────────────────────────────────────

func _update_orbit_camera() -> void:
	if not _camera_3d:
		return
	var yaw_rad := deg_to_rad(_cam_yaw)
	var pitch_rad := deg_to_rad(_cam_pitch)

	var offset := Vector3.ZERO
	offset.x = _cam_distance * cos(pitch_rad) * sin(yaw_rad)
	offset.y = _cam_distance * -sin(pitch_rad)
	offset.z = _cam_distance * cos(pitch_rad) * cos(yaw_rad)

	_camera_3d.position = _cam_target + offset
	_camera_3d.look_at(_cam_target, Vector3.UP)

# ─── Input handling ──────────────────────────────────────────

func _on_viewport_input(event: InputEvent) -> void:
	if _play_mode:
		_handle_play_input(event)
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		# Orbit drag
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_cam_dragging = mb.pressed
			_cam_drag_start = mb.position
			_viewport_rect.accept_event()
			return
		# Zoom
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_distance = max(5.0, _cam_distance - 1.5)
			_update_orbit_camera()
			_viewport_rect.accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_distance = min(50.0, _cam_distance + 1.5)
			_update_orbit_camera()
			_viewport_rect.accept_event()
			return
		# Place / erase blocks
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_try_place_block(mb.position)
				_viewport_rect.accept_event()
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				_try_erase_block(mb.position)
				_viewport_rect.accept_event()

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _cam_dragging:
			_cam_yaw += mm.relative.x * 0.4
			_cam_pitch = clampf(_cam_pitch + mm.relative.y * 0.4, -80.0, -5.0)
			_update_orbit_camera()
			_viewport_rect.accept_event()

# ─── Raycasting ──────────────────────────────────────────────

func _screen_to_grid(screen_pos: Vector2) -> Vector3i:
	## Cast a ray from the camera and find where it hits Y = _current_layer plane
	if not _camera_3d or not _sub_viewport:
		return Vector3i(-1, -1, -1)

	# Normalize screen position to viewport size
	var vp_size := Vector2(_sub_viewport.size)
	var container_size := _viewport_rect.size
	var norm := screen_pos / container_size

	var from := _camera_3d.project_ray_origin(norm * vp_size)
	var dir := _camera_3d.project_ray_normal(norm * vp_size)

	# Intersect with Y = _current_layer plane
	if abs(dir.y) < 0.001:
		return Vector3i(-1, -1, -1)

	var t := (float(_current_layer) - from.y) / dir.y
	if t < 0:
		return Vector3i(-1, -1, -1)

	var hit := from + dir * t
	var gx := int(floor(hit.x))
	var gz := int(floor(hit.z))

	if gx < 0 or gx >= GRID_SIZE or gz < 0 or gz >= GRID_SIZE:
		return Vector3i(-1, -1, -1)

	return Vector3i(gx, _current_layer, gz)

func _try_place_block(screen_pos: Vector2) -> void:
	var pos := _screen_to_grid(screen_pos)
	if pos.x < 0:
		return
	if _blocks.has(pos):
		return  # already occupied
	_blocks[pos] = _selected_color
	_spawn_block_mesh(pos, _selected_color)
	_update_block_count()

func _try_erase_block(screen_pos: Vector2) -> void:
	var pos := _screen_to_grid(screen_pos)
	if pos.x < 0:
		return
	if not _blocks.has(pos):
		return
	_blocks.erase(pos)
	_remove_block_mesh(pos)
	_update_block_count()

# ─── Callbacks ───────────────────────────────────────────────

func _on_color_selected(idx: int) -> void:
	_selected_color = idx

func _on_layer_changed(val: float) -> void:
	_current_layer = int(val)
	if _status_label:
		_status_label.text = "Layer: %d  •  Click to place" % _current_layer

func _on_clear_all() -> void:
	_blocks.clear()
	for child in _block_parent.get_children():
		child.queue_free()
	_update_block_count()

# ─── Play Mode ───────────────────────────────────────────────

func _on_play_toggle() -> void:
	_play_mode = not _play_mode
	if _play_mode:
		_enter_play_mode()
	else:
		_exit_play_mode()

func _enter_play_mode() -> void:
	if _status_label:
		_status_label.text = "WASD to move • Mouse to look\nClick ▶ again to stop"

	# Hide orbit camera, create player
	_camera_3d.current = false

	# Player body
	_player_body = CharacterBody3D.new()
	_player_body.name = "Player"
	# Start near center, one block up
	_player_body.position = Vector3(GRID_SIZE / 2.0, 2.0, GRID_SIZE / 2.0)
	_world_root.add_child(_player_body)

	# Collision capsule
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	col.shape = capsule
	_player_body.add_child(col)

	# Visual capsule
	var vis_mesh := MeshInstance3D.new()
	var cap_mesh := CapsuleMesh.new()
	cap_mesh.radius = 0.3
	cap_mesh.height = 1.6
	vis_mesh.mesh = cap_mesh
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.2, 0.8, 0.4)
	vis_mesh.material_override = pmat
	_player_body.add_child(vis_mesh)

	# FPS camera
	_player_cam = Camera3D.new()
	_player_cam.name = "FPSCamera"
	_player_cam.position = Vector3(0, 0.6, 0)
	_player_cam.fov = 70.0
	_player_body.add_child(_player_cam)
	_player_cam.current = true

	_player_yaw = 0.0
	_player_pitch = 0.0

	# Add collision boxes for all placed blocks
	_build_play_collision()

func _build_play_collision() -> void:
	# Add StaticBody3D for each block so player can't walk through them
	for pos in _blocks.keys():
		var sb := StaticBody3D.new()
		sb.name = "Col_%d_%d_%d" % [pos.x, pos.y, pos.z]
		sb.position = Vector3(pos.x + 0.5, pos.y + 0.5, pos.z + 0.5)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE)
		cs.shape = box
		sb.add_child(cs)
		_block_parent.add_child(sb)

	# Floor collision
	var floor_body := StaticBody3D.new()
	floor_body.name = "FloorCol"
	floor_body.position = Vector3(GRID_SIZE / 2.0, -0.5, GRID_SIZE / 2.0)
	var floor_cs := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(GRID_SIZE, 1.0, GRID_SIZE)
	floor_cs.shape = floor_box
	floor_body.add_child(floor_cs)
	_block_parent.add_child(floor_body)

func _exit_play_mode() -> void:
	if _status_label:
		_status_label.text = "Click to place • Right-click to erase"

	# Remove player
	if _player_body and is_instance_valid(_player_body):
		_player_body.queue_free()
		_player_body = null
		_player_cam = null

	# Remove collision bodies
	for child in _block_parent.get_children():
		if child is StaticBody3D:
			child.queue_free()

	# Restore orbit camera
	_camera_3d.current = true
	_play_mode = false

func _handle_play_input(event: InputEvent) -> void:
	# Note: In an editor plugin, full FPS controls are limited.
	# This provides basic mouse-look when dragging.
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_player_yaw -= mm.relative.x * 0.3
			_player_pitch = clampf(_player_pitch - mm.relative.y * 0.3, -80.0, 80.0)
			if _player_body and is_instance_valid(_player_body):
				_player_body.rotation_degrees.y = _player_yaw
			if _player_cam and is_instance_valid(_player_cam):
				_player_cam.rotation_degrees.x = _player_pitch
			_viewport_rect.accept_event()

	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		# Scroll to move forward/back as a simple substitute for WASD in editor
		if _player_body and is_instance_valid(_player_body):
			var fwd := -_player_body.global_transform.basis.z
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_player_body.position += fwd * 0.5
				_viewport_rect.accept_event()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_player_body.position -= fwd * 0.5
				_viewport_rect.accept_event()
			elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				# Strafe right on right-click
				var right := _player_body.global_transform.basis.x
				_player_body.position += right * 0.5
				_viewport_rect.accept_event()
