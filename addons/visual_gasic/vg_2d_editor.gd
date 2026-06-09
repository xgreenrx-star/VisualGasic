@tool
## VG 2D Scene Editor — Full-featured 2D editing surface embedded in the VG IDE.
##
## Features: pan/zoom camera with reset, click-to-select, drag-to-move,
## rotation handle, scale handles, snap-to-grid, undo/redo, duplicate,
## right-click context menus, numeric transform input fields, rubber-band
## multi-select, visibility toggles, inline rename, keyboard shortcuts overlay,
## collision shape visualization, sprite texture loading, and scene load/save.
##
## Architecture: HSplitContainer with a left toolbox/scene-tree/transform panel
## and a right SubViewport + toolbar area.
## All 2D manipulation happens inside a SubViewport with its own Camera2D.
extends HSplitContainer

# ─────────────────────────────────────────────────────────────────────────────
# SIGNALS
# ─────────────────────────────────────────────────────────────────────────────
signal back_to_form_requested
signal node_selected(node: Node)
signal selection_cleared
signal node_double_clicked(node: Node)
signal view_code_requested(node: Node)
signal scene_saved(path: String)  ## Emitted after a successful save (Save or Save As)

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────
const PAN_SPEED := 1.0
const ZOOM_SPEED := 0.1
const MIN_ZOOM := 0.1
const MAX_ZOOM := 10.0
const DEFAULT_ZOOM := 1.0
const GRID_SIZE := 64
const GRID_SUBDIVISIONS := 4
const MAX_UNDO := 50
const HANDLE_SIZE := 6.0
const ROTATION_HANDLE_DIST := 40.0
const RUBBER_BAND_COLOR := Color(0.3, 0.5, 1.0, 0.3)
const RUBBER_BAND_BORDER := Color(0.3, 0.5, 1.0, 0.8)
const SELECTION_COLOR := Color(1.0, 0.6, 0.0, 1.0)
const MULTI_SELECTION_COLOR := Color(0.3, 0.7, 1.0, 1.0)
const GRID_COLOR := Color(0.3, 0.3, 0.3, 0.3)
const GRID_COLOR_MAJOR := Color(0.4, 0.4, 0.4, 0.5)
const ORIGIN_X_COLOR := Color(0.9, 0.2, 0.2, 0.6)
const ORIGIN_Y_COLOR := Color(0.2, 0.9, 0.2, 0.6)
const COLLISION_SHAPE_COLOR := Color(0.0, 0.6, 1.0, 0.4)
const COLLISION_SHAPE_BORDER := Color(0.0, 0.6, 1.0, 0.8)

# ─────────────────────────────────────────────────────────────────────────────
# ENUMS
# ─────────────────────────────────────────────────────────────────────────────
enum ToolMode { SELECT, MOVE, ROTATE, SCALE }
enum InteractMode { NONE, RUBBER_BAND, DRAGGING, ROTATING, SCALING, PANNING, RESIZING_SHAPE }

# ─────────────────────────────────────────────────────────────────────────────
# STATE VARIABLES
# ─────────────────────────────────────────────────────────────────────────────

# Camera
var _cam_offset: Vector2 = Vector2.ZERO
var _cam_zoom: float = DEFAULT_ZOOM
var _panning: bool = false
var _alt_panning: bool = false
var _rmb_panning: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

# Selection
var _selected_nodes: Array[CanvasItem] = []
var _primary_selected: CanvasItem = null

# Tool state
var _tool_mode: ToolMode = ToolMode.SELECT
var _interact_mode: InteractMode = InteractMode.NONE

# Dragging
var _drag_start_screen: Vector2 = Vector2.ZERO
var _drag_start_positions: Array[Vector2] = []  # per-node start pos

# Rotation
var _rotate_start_angle: float = 0.0
var _rotate_node_start: float = 0.0

# Scaling
var _scale_start_screen: Vector2 = Vector2.ZERO
var _scale_start_values: Array[Vector2] = []

# Rubber band
var _rubber_band_start: Vector2 = Vector2.ZERO
var _rubber_band_end: Vector2 = Vector2.ZERO

# Shape resize (collision shape corner-drag)
var _resize_shape_node: Node = null
var _resize_corner: int = -1
var _resize_start_size: Vector2 = Vector2.ZERO
var _resize_start_radius: float = 0.0

# Snap
var _snap_enabled: bool = true
var _snap_value: float = 16.0

# Scene
var _scene_root: Node2D = null
var _loaded_scene_path: String = ""
var _scene_dirty: bool = false
var _save_file_dialog: FileDialog = null
var _import_file_dialog: FileDialog = null

# Undo/Redo
var _undo_stack: Array = []
var _redo_stack: Array = []
var _drag_transforms_before: Array[Dictionary] = []

# Right-click tracking
var _rmb_press_pos: Vector2 = Vector2.ZERO

# UI references
var _viewport: SubViewport = null
var _viewport_container: SubViewportContainer = null
var _camera: Camera2D = null
var _overlay: Control = null

var _toolbox_list: ItemList = null
var _scene_tree: Tree = null
var _tool_btn_select: CheckButton = null
var _tool_btn_move: CheckButton = null
var _tool_btn_rotate: CheckButton = null
var _tool_btn_scale: CheckButton = null
var _snap_toggle: CheckButton = null
var _snap_spin: SpinBox = null
var _status_label: Label = null
var _toolbar_row1: HBoxContainer = null
var _toolbar_row2: HBoxContainer = null
var _show_collisions_btn: CheckButton = null
var _show_grid_btn: CheckButton = null
var _undo_btn: Button = null
var _redo_btn: Button = null
var _help_dialog: AcceptDialog = null
var _popup_backdrop: Control = null  # Custom dark popup overlay (replaces native PopupMenu)
var _h_scrollbar: HScrollBar = null
var _v_scrollbar: VScrollBar = null
var _scrollbar_updating: bool = false  # prevent feedback loop
const SCROLL_WORLD_RANGE := 5000.0  # total scrollable world range

# Transform panel spinboxes
var _pos_x: SpinBox = null
var _pos_y: SpinBox = null
var _rot_z: SpinBox = null
var _scl_x: SpinBox = null
var _scl_y: SpinBox = null
var _node_inspector = null  # VG Node Inspector panel

# Rendering options
var _show_grid: bool = true
var _show_collisions: bool = true

# ─────────────────────────────────────────────────────────────────────────────
# TOOLBOX ITEMS — the 2D object types available for placement
# ─────────────────────────────────────────────────────────────────────────────
var _toolbox_items: Array = [
	{name = "Sprite 2D", type = "Sprite2D", icon = "🖼️"},
	{name = "Animated Sprite", type = "AnimatedSprite2D", icon = "🎞️"},
	{name = "Camera 2D", type = "Camera2D", icon = "📷"},
	{name = "Canvas Layer", type = "CanvasLayer", icon = "🎨"},
	{name = "Char Body 2D", type = "CharacterBody2D", icon = "🏃"},
	{name = "Rigid Body 2D", type = "RigidBody2D", icon = "⚙️"},
	{name = "Static Body 2D", type = "StaticBody2D", icon = "🧱"},
	{name = "Area 2D", type = "Area2D", icon = "📦"},
	{name = "Collision Shape", type = "CollisionShape2D", icon = "🔷"},
	{name = "Collision Poly", type = "CollisionPolygon2D", icon = "🔶"},
	{name = "TileMapLayer", type = "TileMapLayer", icon = "🗺️"},
	{name = "Parallax BG", type = "ParallaxBackground", icon = "🌄"},
	{name = "Parallax Layer", type = "ParallaxLayer", icon = "🏔️"},
	{name = "Path 2D", type = "Path2D", icon = "〰️"},
	{name = "PathFollow 2D", type = "PathFollow2D", icon = "📍"},
	{name = "Light 2D", type = "PointLight2D", icon = "💡"},
	{name = "Dir Light 2D", type = "DirectionalLight2D", icon = "☀️"},
	{name = "Audio 2D", type = "AudioStreamPlayer2D", icon = "🔊"},
	{name = "Navigation 2D", type = "NavigationRegion2D", icon = "🧭"},
	{name = "Ray Cast 2D", type = "RayCast2D", icon = "📏"},
	{name = "Marker 2D", type = "Marker2D", icon = "📌"},
	{name = "Color Rect", type = "ColorRect", icon = "🟧"},
	{name = "Line 2D", type = "Line2D", icon = "📐"},
	{name = "Polygon 2D", type = "Polygon2D", icon = "🔺"},
	{name = "Node2D", type = "Node2D", icon = "⊕"},
	{name = "Visible Notif.", type = "VisibleOnScreenNotifier2D", icon = "👁️"},
	{name = "GPU Particles", type = "GPUParticles2D", icon = "✨"},
	{name = "CPU Particles", type = "CPUParticles2D", icon = "🎆"},
]

# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_ui()
	_build_2d_scene()
	_build_overlay()
	_build_help_dialog()
	_build_context_menus()
	_populate_toolbox()

func _notification(what: int) -> void:
	# When the 2D editor becomes visible and has no scene loaded, try to
	# auto-load the project's main scene.  This acts as a reliable fallback
	# in case the plugin's _auto_load_2d_scene() call didn't succeed.
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible and _loaded_scene_path.is_empty():
		call_deferred("_try_auto_load_scene")

## Self-contained auto-load: find and load the main .tscn for this project.
func _try_auto_load_scene() -> void:
	if not _loaded_scene_path.is_empty():
		return  # already loaded (plugin auto-load may have succeeded first)
	print("[VG2D] _try_auto_load_scene: attempting self-load")
	# 1) ProjectSettings main scene
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	if not main_scene.is_empty() and FileAccess.file_exists(main_scene):
		print("[VG2D] _try_auto_load_scene: found main_scene = '", main_scene, "'")
		load_scene(main_scene)
		return
	# 2) Currently edited scene in Godot editor
	if Engine.is_editor_hint():
		var scene_root: Node = EditorInterface.get_edited_scene_root()
		if scene_root and not scene_root.scene_file_path.is_empty():
			print("[VG2D] _try_auto_load_scene: using edited scene = '", scene_root.scene_file_path, "'")
			load_scene(scene_root.scene_file_path)
			return
	# 3) Scan for any .tscn in the project
	var found := _scan_for_tscn("res://")
	if not found.is_empty():
		print("[VG2D] _try_auto_load_scene: scanned and found = '", found, "'")
		load_scene(found)
		return
	print("[VG2D] _try_auto_load_scene: no .tscn found in project")

## Scan a directory tree for the first .tscn file (prefers paired .vg).
static func _scan_for_tscn(path: String) -> String:
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return ""
	var paired: String = ""
	var any_scene: String = ""
	var subdirs: PackedStringArray = []
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var full_path: String = path.path_join(file_name)
		if dir.current_is_dir():
			if not file_name.begins_with(".") and file_name != "addons" and file_name != ".godot":
				subdirs.append(full_path)
		elif file_name.ends_with(".tscn"):
			if any_scene.is_empty():
				any_scene = full_path
			var vg_path: String = full_path.get_basename() + ".vg"
			if paired.is_empty() and FileAccess.file_exists(vg_path):
				paired = full_path
		file_name = dir.get_next()
	dir.list_dir_end()
	if not paired.is_empty():
		return paired
	if not any_scene.is_empty():
		return any_scene
	for subdir: String in subdirs:
		var result: String = _scan_for_tscn(subdir)
		if not result.is_empty():
			return result
	return ""

# ─────────────────────────────────────────────────────────────────────────────
# BUILD UI
# ─────────────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	split_offset = 250

	# ── LEFT PANEL ──────────────────────────────────────────────────────────
	var left_panel = PanelContainer.new()
	left_panel.custom_minimum_size.x = 240
	var left_panel_style = StyleBoxFlat.new()
	left_panel_style.bg_color = Color(0.16, 0.16, 0.19)
	left_panel_style.set_border_width_all(0)
	left_panel_style.set_corner_radius_all(0)
	left_panel.add_theme_stylebox_override("panel", left_panel_style)

	var left_margin = MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 6)
	left_margin.add_theme_constant_override("margin_right", 6)
	left_margin.add_theme_constant_override("margin_top", 6)
	left_margin.add_theme_constant_override("margin_bottom", 6)
	left_panel.add_child(left_margin)

	var left_scroll = ScrollContainer.new()
	left_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.theme = _build_dark_scrollbar_theme()
	left_margin.add_child(left_scroll)

	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	# Apply dark theme for SpinBoxes, HSeparators, and other left-panel controls
	var left_theme = _build_dark_toolbar_theme()
	# Add HSeparator dark style
	var hsep = StyleBoxFlat.new()
	hsep.bg_color = Color(0.3, 0.3, 0.35)
	hsep.content_margin_top = 1
	hsep.content_margin_bottom = 1
	hsep.content_margin_left = 4
	hsep.content_margin_right = 4
	left_theme.set_stylebox("separator", "HSeparator", hsep)
	left_vbox.theme = left_theme
	left_scroll.add_child(left_vbox)

	# ── Resizable split: 2D Objects on top, Scene Tree on bottom ──
	# The two sections were previously stacked in the VBox with a plain
	# HSeparator between them, which meant the user couldn't rebalance
	# heights when one list outgrew its share. A VSplitContainer gives a
	# live grab handle between the panes.
	var toolbox_tree_split := VSplitContainer.new()
	toolbox_tree_split.size_flags_vertical = SIZE_EXPAND_FILL
	toolbox_tree_split.size_flags_horizontal = SIZE_EXPAND_FILL
	toolbox_tree_split.custom_minimum_size.y = 600
	toolbox_tree_split.split_offset = -240  # give the Scene Tree more room
	# Make the drag handle visible so users can find and resize it.
	var grab_style := StyleBoxFlat.new()
	grab_style.bg_color = Color(0.35, 0.55, 0.85)
	grab_style.set_corner_radius_all(2)
	grab_style.content_margin_top = 1
	grab_style.content_margin_bottom = 1
	toolbox_tree_split.add_theme_stylebox_override("grabber", grab_style)
	toolbox_tree_split.add_theme_constant_override("separation", 6)
	toolbox_tree_split.add_theme_constant_override("autohide", 0)

	var toolbox_pane := VBoxContainer.new()
	toolbox_pane.size_flags_vertical = SIZE_EXPAND_FILL
	toolbox_pane.custom_minimum_size.y = 120
	toolbox_tree_split.add_child(toolbox_pane)

	var scene_pane := VBoxContainer.new()
	scene_pane.size_flags_vertical = SIZE_EXPAND_FILL
	scene_pane.custom_minimum_size.y = 220
	toolbox_tree_split.add_child(scene_pane)

	# ── 2D Toolbox ──
	var toolbox_header_panel = PanelContainer.new()
	var toolbox_header_style = StyleBoxFlat.new()
	toolbox_header_style.bg_color = Color(0.22, 0.26, 0.35)
	toolbox_header_style.set_corner_radius_all(3)
	toolbox_header_style.content_margin_left = 6
	toolbox_header_style.content_margin_right = 6
	toolbox_header_style.content_margin_top = 4
	toolbox_header_style.content_margin_bottom = 4
	toolbox_header_panel.add_theme_stylebox_override("panel", toolbox_header_style)
	var toolbox_header = Label.new()
	toolbox_header.text = "📦 2D Objects"
	toolbox_header.add_theme_font_size_override("font_size", 14)
	toolbox_header.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	toolbox_header_panel.add_child(toolbox_header)
	toolbox_pane.add_child(toolbox_header_panel)

	_toolbox_list = ItemList.new()
	# Height is now driven by its pane in the VSplitContainer so the user's
	# drag actually moves the divider; a fixed custom_minimum_size here
	# would lock the pane to that height and defeat the split.
	_toolbox_list.custom_minimum_size.y = 0
	_toolbox_list.size_flags_vertical = SIZE_EXPAND_FILL
	_toolbox_list.max_columns = 1
	_toolbox_list.same_column_width = true
	_toolbox_list.allow_reselect = true
	# auto_height = true would make the list grow to fit every row, defeating
	# the VSplitContainer above and starving the Scene Tree pane of space.
	_toolbox_list.auto_height = false
	_toolbox_list.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_toolbox_list.add_theme_color_override("font_selected_color", Color(1.0, 1.0, 1.0))
	_toolbox_list.add_theme_color_override("font_hovered_color", Color(0.95, 0.95, 0.95))
	_toolbox_list.add_theme_constant_override("v_separation", 2)
	var item_list_bg = StyleBoxFlat.new()
	item_list_bg.bg_color = Color(0.14, 0.14, 0.17)
	item_list_bg.set_border_width_all(1)
	item_list_bg.border_color = Color(0.25, 0.25, 0.30)
	item_list_bg.set_corner_radius_all(3)
	item_list_bg.set_content_margin_all(4)
	_toolbox_list.add_theme_stylebox_override("panel", item_list_bg)
	var item_sel_style = StyleBoxFlat.new()
	item_sel_style.bg_color = Color(0.24, 0.36, 0.55)
	item_sel_style.set_corner_radius_all(3)
	_toolbox_list.add_theme_stylebox_override("selected", item_sel_style)
	_toolbox_list.add_theme_stylebox_override("selected_focus", item_sel_style)
	var item_hover_style = StyleBoxFlat.new()
	item_hover_style.bg_color = Color(0.22, 0.22, 0.28)
	item_hover_style.set_corner_radius_all(3)
	_toolbox_list.add_theme_stylebox_override("hovered", item_hover_style)
	_toolbox_list.theme = _build_dark_scrollbar_theme()
	_toolbox_list.item_activated.connect(_on_toolbox_item_double_clicked)
	toolbox_pane.add_child(_toolbox_list)

	var add_btn = Button.new()
	add_btn.text = "➕ Add to Scene"
	add_btn.tooltip_text = "Add the selected 2D object to the scene"
	add_btn.add_theme_font_size_override("font_size", 11)
	add_btn.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
	var add_btn_style = StyleBoxFlat.new()
	add_btn_style.bg_color = Color(0.15, 0.5, 0.2)
	add_btn_style.set_corner_radius_all(4)
	add_btn_style.set_content_margin_all(4)
	add_btn.add_theme_stylebox_override("normal", add_btn_style)
	var add_btn_hover = add_btn_style.duplicate()
	add_btn_hover.bg_color = Color(0.2, 0.6, 0.28)
	add_btn.add_theme_stylebox_override("hover", add_btn_hover)
	var add_btn_pressed = add_btn_style.duplicate()
	add_btn_pressed.bg_color = Color(0.12, 0.4, 0.16)
	add_btn.add_theme_stylebox_override("pressed", add_btn_pressed)
	add_btn.pressed.connect(_on_add_object_pressed)
	toolbox_pane.add_child(add_btn)

	# Insert the split into the main left column now that its top pane is
	# populated. The bottom pane (scene_pane) is filled just below.
	left_vbox.add_child(toolbox_tree_split)

	# ── Scene Tree ──
	var tree_header_panel = PanelContainer.new()
	var tree_header_style = StyleBoxFlat.new()
	tree_header_style.bg_color = Color(0.22, 0.26, 0.35)
	tree_header_style.set_corner_radius_all(3)
	tree_header_style.content_margin_left = 6
	tree_header_style.content_margin_right = 6
	tree_header_style.content_margin_top = 4
	tree_header_style.content_margin_bottom = 4
	tree_header_panel.add_theme_stylebox_override("panel", tree_header_style)
	var tree_header = Label.new()
	tree_header.text = "🌳 Scene Tree"
	tree_header.add_theme_font_size_override("font_size", 14)
	tree_header.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	tree_header_panel.add_child(tree_header)
	scene_pane.add_child(tree_header_panel)

	_scene_tree = Tree.new()
	_scene_tree.custom_minimum_size.y = 0
	_scene_tree.size_flags_vertical = SIZE_EXPAND_FILL
	_scene_tree.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_scene_tree.add_theme_color_override("font_selected_color", Color(1.0, 1.0, 1.0))
	_scene_tree.add_theme_color_override("title_button_color", Color(0.85, 0.85, 0.85))
	var tree_bg = StyleBoxFlat.new()
	tree_bg.bg_color = Color(0.14, 0.14, 0.17)
	tree_bg.set_border_width_all(1)
	tree_bg.border_color = Color(0.25, 0.25, 0.30)
	tree_bg.set_corner_radius_all(3)
	tree_bg.set_content_margin_all(4)
	_scene_tree.add_theme_stylebox_override("panel", tree_bg)
	var tree_sel = StyleBoxFlat.new()
	tree_sel.bg_color = Color(0.24, 0.36, 0.55)
	tree_sel.set_corner_radius_all(3)
	_scene_tree.add_theme_stylebox_override("selected", tree_sel)
	_scene_tree.add_theme_stylebox_override("selected_focus", tree_sel)
	_scene_tree.hide_root = false
	_scene_tree.item_selected.connect(_on_scene_tree_selected)
	_scene_tree.item_activated.connect(_on_scene_tree_double_clicked)
	_scene_tree.item_mouse_selected.connect(_on_scene_tree_rmb)
	# Drag-and-drop reparent support.
	_scene_tree.drop_mode_flags = Tree.DROP_MODE_INBETWEEN | Tree.DROP_MODE_ON_ITEM
	_scene_tree.set_drag_forwarding(
		_tree_get_drag_data,
		_tree_can_drop_data,
		_tree_drop_data,
	)
	scene_pane.add_child(_scene_tree)

	# Scene tree action buttons
	var tree_actions = HBoxContainer.new()
	tree_actions.add_theme_constant_override("separation", 4)
	scene_pane.add_child(tree_actions)

	var action_btn_style = StyleBoxFlat.new()
	action_btn_style.bg_color = Color(0.22, 0.22, 0.26)
	action_btn_style.set_corner_radius_all(3)
	action_btn_style.set_content_margin_all(2)
	var action_btn_hover = action_btn_style.duplicate()
	action_btn_hover.bg_color = Color(0.30, 0.30, 0.36)

	var vis_btn = Button.new()
	vis_btn.text = "👁️"
	vis_btn.tooltip_text = "Toggle Visibility"
	vis_btn.add_theme_stylebox_override("normal", action_btn_style)
	vis_btn.add_theme_stylebox_override("hover", action_btn_hover)
	vis_btn.pressed.connect(_toggle_visibility_selected)
	tree_actions.add_child(vis_btn)

	var rename_btn = Button.new()
	rename_btn.text = "✏️"
	rename_btn.tooltip_text = "Rename"
	rename_btn.add_theme_stylebox_override("normal", action_btn_style)
	rename_btn.add_theme_stylebox_override("hover", action_btn_hover)
	rename_btn.pressed.connect(_rename_selected)
	tree_actions.add_child(rename_btn)

	var del_style = StyleBoxFlat.new()
	del_style.bg_color = Color(0.5, 0.15, 0.15)
	del_style.set_corner_radius_all(3)
	del_style.set_content_margin_all(2)
	var del_hover = del_style.duplicate()
	del_hover.bg_color = Color(0.65, 0.2, 0.2)
	var del_btn = Button.new()
	del_btn.text = "🗑️"
	del_btn.tooltip_text = "Delete"
	del_btn.add_theme_stylebox_override("normal", del_style)
	del_btn.add_theme_stylebox_override("hover", del_hover)
	del_btn.pressed.connect(_delete_selected)
	tree_actions.add_child(del_btn)

	var inst_btn = Button.new()
	inst_btn.text = "🔗"
	inst_btn.tooltip_text = "Instance Child Scene (.tscn)"
	inst_btn.add_theme_stylebox_override("normal", action_btn_style)
	inst_btn.add_theme_stylebox_override("hover", action_btn_hover)
	inst_btn.pressed.connect(_on_instance_scene_pressed)
	tree_actions.add_child(inst_btn)

	left_vbox.add_child(HSeparator.new())

	# ── Transform Panel ──
	var xform_header_panel = PanelContainer.new()
	var xform_header_style = StyleBoxFlat.new()
	xform_header_style.bg_color = Color(0.22, 0.26, 0.35)
	xform_header_style.set_corner_radius_all(3)
	xform_header_style.content_margin_left = 6
	xform_header_style.content_margin_right = 6
	xform_header_style.content_margin_top = 4
	xform_header_style.content_margin_bottom = 4
	xform_header_panel.add_theme_stylebox_override("panel", xform_header_style)
	var xform_header = Label.new()
	xform_header.text = "📐 Transform"
	xform_header.add_theme_font_size_override("font_size", 14)
	xform_header.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	xform_header_panel.add_child(xform_header)
	left_vbox.add_child(xform_header_panel)

	var xform_grid = GridContainer.new()
	xform_grid.columns = 2
	xform_grid.add_theme_constant_override("h_separation", 4)
	xform_grid.add_theme_constant_override("v_separation", 2)
	left_vbox.add_child(xform_grid)

	# Position X
	var lbl_px = Label.new()
	lbl_px.text = "Pos X"
	lbl_px.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	lbl_px.add_theme_font_size_override("font_size", 11)
	xform_grid.add_child(lbl_px)
	_pos_x = SpinBox.new()
	_pos_x.min_value = -10000
	_pos_x.max_value = 10000
	_pos_x.step = 0.1
	_pos_x.allow_greater = true
	_pos_x.allow_lesser = true
	_pos_x.size_flags_horizontal = SIZE_EXPAND_FILL
	_pos_x.value_changed.connect(_on_transform_value_changed)
	xform_grid.add_child(_pos_x)

	# Position Y
	var lbl_py = Label.new()
	lbl_py.text = "Pos Y"
	lbl_py.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	lbl_py.add_theme_font_size_override("font_size", 11)
	xform_grid.add_child(lbl_py)
	_pos_y = SpinBox.new()
	_pos_y.min_value = -10000
	_pos_y.max_value = 10000
	_pos_y.step = 0.1
	_pos_y.allow_greater = true
	_pos_y.allow_lesser = true
	_pos_y.size_flags_horizontal = SIZE_EXPAND_FILL
	_pos_y.value_changed.connect(_on_transform_value_changed)
	xform_grid.add_child(_pos_y)

	# Rotation Z
	var lbl_rz = Label.new()
	lbl_rz.text = "Rot"
	lbl_rz.add_theme_color_override("font_color", Color(0.3, 0.5, 1.0))
	lbl_rz.add_theme_font_size_override("font_size", 11)
	xform_grid.add_child(lbl_rz)
	_rot_z = SpinBox.new()
	_rot_z.min_value = -360
	_rot_z.max_value = 360
	_rot_z.step = 0.1
	_rot_z.suffix = "°"
	_rot_z.allow_greater = true
	_rot_z.allow_lesser = true
	_rot_z.size_flags_horizontal = SIZE_EXPAND_FILL
	_rot_z.value_changed.connect(_on_transform_value_changed)
	xform_grid.add_child(_rot_z)

	# Scale X
	var lbl_sx = Label.new()
	lbl_sx.text = "Scl X"
	lbl_sx.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	lbl_sx.add_theme_font_size_override("font_size", 11)
	xform_grid.add_child(lbl_sx)
	_scl_x = SpinBox.new()
	_scl_x.min_value = -100
	_scl_x.max_value = 100
	_scl_x.step = 0.01
	_scl_x.value = 1.0
	_scl_x.allow_greater = true
	_scl_x.allow_lesser = true
	_scl_x.size_flags_horizontal = SIZE_EXPAND_FILL
	_scl_x.value_changed.connect(_on_transform_value_changed)
	xform_grid.add_child(_scl_x)

	# Scale Y
	var lbl_sy = Label.new()
	lbl_sy.text = "Scl Y"
	lbl_sy.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	lbl_sy.add_theme_font_size_override("font_size", 11)
	xform_grid.add_child(lbl_sy)
	_scl_y = SpinBox.new()
	_scl_y.min_value = -100
	_scl_y.max_value = 100
	_scl_y.step = 0.01
	_scl_y.value = 1.0
	_scl_y.allow_greater = true
	_scl_y.allow_lesser = true
	_scl_y.size_flags_horizontal = SIZE_EXPAND_FILL
	_scl_y.value_changed.connect(_on_transform_value_changed)
	xform_grid.add_child(_scl_y)

	# ── Node Inspector (properties, collision, groups, signals) ──
	left_vbox.add_child(HSeparator.new())
	var InspectorScript = load("res://addons/visual_gasic/vg_node_inspector.gd")
	if InspectorScript:
		_node_inspector = InspectorScript.new()
		_node_inspector.signal_connect_requested.connect(func(node_name, sig_name):
			# Emit a signal that the code editor can pick up to generate a Sub stub
			print("[VG2D] Generate Sub: ", node_name, "_", sig_name)
		)
		_node_inspector.property_changed.connect(func(node, prop, old_val, new_val):
			_viewport_container.queue_redraw() if _viewport_container else null
		)
		left_vbox.add_child(_node_inspector)

	add_child(left_panel)

	# ── RIGHT PANEL ─────────────────────────────────────────────────────────
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = SIZE_EXPAND_FILL

	# ── Toolbar Row 1 ──
	_toolbar_row1 = HBoxContainer.new()
	_toolbar_row1.add_theme_constant_override("separation", 4)
	_toolbar_row1.theme = _build_dark_toolbar_theme()
	right_vbox.add_child(_toolbar_row1)

	# "← Form" button
	var back_btn = Button.new()
	back_btn.text = "← Form"
	back_btn.tooltip_text = "Return to Form Designer"
	back_btn.add_theme_font_size_override("font_size", 11)
	back_btn.pressed.connect(func(): back_to_form_requested.emit())
	_toolbar_row1.add_child(back_btn)

	_toolbar_row1.add_child(VSeparator.new())

	# Tool buttons
	_tool_btn_select = CheckButton.new()
	_tool_btn_select.text = "Select"
	_tool_btn_select.tooltip_text = "Select tool (S)"
	_tool_btn_select.button_pressed = true
	_tool_btn_select.add_theme_font_size_override("font_size", 10)
	_tool_btn_select.toggled.connect(func(on): if on: _set_tool_mode(ToolMode.SELECT))
	_toolbar_row1.add_child(_tool_btn_select)

	_tool_btn_move = CheckButton.new()
	_tool_btn_move.text = "Move"
	_tool_btn_move.tooltip_text = "Move tool (W)"
	_tool_btn_move.add_theme_font_size_override("font_size", 10)
	_tool_btn_move.toggled.connect(func(on): if on: _set_tool_mode(ToolMode.MOVE))
	_toolbar_row1.add_child(_tool_btn_move)

	_tool_btn_rotate = CheckButton.new()
	_tool_btn_rotate.text = "Rotate"
	_tool_btn_rotate.tooltip_text = "Rotate tool (E)"
	_tool_btn_rotate.add_theme_font_size_override("font_size", 10)
	_tool_btn_rotate.toggled.connect(func(on): if on: _set_tool_mode(ToolMode.ROTATE))
	_toolbar_row1.add_child(_tool_btn_rotate)

	_tool_btn_scale = CheckButton.new()
	_tool_btn_scale.text = "Scale"
	_tool_btn_scale.tooltip_text = "Scale tool (R)"
	_tool_btn_scale.add_theme_font_size_override("font_size", 10)
	_tool_btn_scale.toggled.connect(func(on): if on: _set_tool_mode(ToolMode.SCALE))
	_toolbar_row1.add_child(_tool_btn_scale)

	_toolbar_row1.add_child(VSeparator.new())

	# Snap
	_snap_toggle = CheckButton.new()
	_snap_toggle.text = "⊞ Snap"
	_snap_toggle.tooltip_text = "Toggle grid snap (G)"
	_snap_toggle.button_pressed = _snap_enabled
	_snap_toggle.add_theme_font_size_override("font_size", 10)
	_snap_toggle.toggled.connect(func(on): _snap_enabled = on)
	_toolbar_row1.add_child(_snap_toggle)

	_snap_spin = SpinBox.new()
	_snap_spin.min_value = 1
	_snap_spin.max_value = 256
	_snap_spin.value = _snap_value
	_snap_spin.step = 1
	_snap_spin.custom_minimum_size.x = 64
	_snap_spin.tooltip_text = "Snap grid size"
	_snap_spin.value_changed.connect(func(v): _snap_value = v)
	_toolbar_row1.add_child(_snap_spin)

	_toolbar_row1.add_child(VSeparator.new())

	# Import texture
	var import_btn = Button.new()
	import_btn.text = "🖼️ Texture"
	import_btn.tooltip_text = "Load texture onto selected Sprite2D"
	import_btn.add_theme_font_size_override("font_size", 10)
	import_btn.pressed.connect(_on_import_texture_pressed)
	_toolbar_row1.add_child(import_btn)

	# Save
	var save_btn = Button.new()
	save_btn.text = "💾 Save"
	save_btn.tooltip_text = "Save scene (Ctrl+S)"
	save_btn.add_theme_font_size_override("font_size", 10)
	save_btn.pressed.connect(_save_scene)
	_toolbar_row1.add_child(save_btn)

	# ── Toolbar Row 2 ──
	_toolbar_row2 = HBoxContainer.new()
	_toolbar_row2.add_theme_constant_override("separation", 4)
	_toolbar_row2.theme = _build_dark_toolbar_theme()
	right_vbox.add_child(_toolbar_row2)

	# Show Grid
	_show_grid_btn = CheckButton.new()
	_show_grid_btn.text = "🔲 Grid"
	_show_grid_btn.tooltip_text = "Show/hide grid"
	_show_grid_btn.button_pressed = _show_grid
	_show_grid_btn.add_theme_font_size_override("font_size", 10)
	_show_grid_btn.toggled.connect(func(on): _show_grid = on; _overlay.queue_redraw())
	_toolbar_row2.add_child(_show_grid_btn)

	# Show Collisions
	_show_collisions_btn = CheckButton.new()
	_show_collisions_btn.text = "🔷 Collisions"
	_show_collisions_btn.tooltip_text = "Show collision shapes"
	_show_collisions_btn.button_pressed = _show_collisions
	_show_collisions_btn.add_theme_font_size_override("font_size", 10)
	_show_collisions_btn.toggled.connect(func(on): _show_collisions = on; _overlay.queue_redraw())
	_toolbar_row2.add_child(_show_collisions_btn)

	_toolbar_row2.add_child(VSeparator.new())

	# Undo/Redo
	_undo_btn = Button.new()
	_undo_btn.text = "↩"
	_undo_btn.tooltip_text = "Undo (Ctrl+Z)"
	_undo_btn.add_theme_font_size_override("font_size", 12)
	_undo_btn.pressed.connect(_undo)
	_toolbar_row2.add_child(_undo_btn)

	_redo_btn = Button.new()
	_redo_btn.text = "↪"
	_redo_btn.tooltip_text = "Redo (Ctrl+Y)"
	_redo_btn.add_theme_font_size_override("font_size", 12)
	_redo_btn.pressed.connect(_redo)
	_toolbar_row2.add_child(_redo_btn)

	_toolbar_row2.add_child(VSeparator.new())

	# Focus
	var focus_btn = Button.new()
	focus_btn.text = "🎯 Focus"
	focus_btn.tooltip_text = "Focus on selected (F)"
	focus_btn.add_theme_font_size_override("font_size", 10)
	focus_btn.pressed.connect(_focus_selected)
	_toolbar_row2.add_child(focus_btn)

	# Reset View
	var reset_btn = Button.new()
	reset_btn.text = "🔄 Reset"
	reset_btn.tooltip_text = "Reset camera to origin"
	reset_btn.add_theme_font_size_override("font_size", 10)
	reset_btn.pressed.connect(_reset_camera)
	_toolbar_row2.add_child(reset_btn)

	# Zoom label
	var zoom_label = Label.new()
	zoom_label.text = "Zoom:"
	zoom_label.add_theme_font_size_override("font_size", 10)
	zoom_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_toolbar_row2.add_child(zoom_label)

	var zoom_100_btn = Button.new()
	zoom_100_btn.text = "100%"
	zoom_100_btn.tooltip_text = "Reset zoom to 100%"
	zoom_100_btn.add_theme_font_size_override("font_size", 10)
	zoom_100_btn.pressed.connect(func(): _cam_zoom = 1.0; _update_camera(); _overlay.queue_redraw())
	_toolbar_row2.add_child(zoom_100_btn)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	_toolbar_row2.add_child(spacer)

	# Help button
	var help_btn = Button.new()
	help_btn.text = "? Help"
	help_btn.tooltip_text = "Keyboard shortcuts (F1)"
	help_btn.add_theme_font_size_override("font_size", 10)
	help_btn.pressed.connect(func(): _help_dialog.popup_centered())
	_toolbar_row2.add_child(help_btn)

	# ── Status Bar ──
	_status_label = Label.new()
	_status_label.text = "2D Scene Editor — No scene loaded"
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	right_vbox.add_child(_status_label)

	# ── Viewport + Scrollbars ──
	# Use a VBoxContainer > [HBoxContainer > [viewport, v_scroll], h_scroll]
	var vp_outer := VBoxContainer.new()
	vp_outer.size_flags_horizontal = SIZE_EXPAND_FILL
	vp_outer.size_flags_vertical = SIZE_EXPAND_FILL
	right_vbox.add_child(vp_outer)

	var vp_row := HBoxContainer.new()
	vp_row.size_flags_horizontal = SIZE_EXPAND_FILL
	vp_row.size_flags_vertical = SIZE_EXPAND_FILL
	vp_outer.add_child(vp_row)

	_viewport_container = SubViewportContainer.new()
	_viewport_container.stretch = true
	_viewport_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_viewport_container.size_flags_vertical = SIZE_EXPAND_FILL
	_viewport_container.focus_mode = Control.FOCUS_ALL
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport_container.gui_input.connect(_on_viewport_input)
	vp_row.add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1024, 768)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	_viewport_container.add_child(_viewport)

	# Vertical scrollbar (right edge)
	_v_scrollbar = VScrollBar.new()
	_v_scrollbar.custom_minimum_size = Vector2(12, 0)
	_v_scrollbar.min_value = -SCROLL_WORLD_RANGE
	_v_scrollbar.max_value = SCROLL_WORLD_RANGE
	_v_scrollbar.page = 800.0
	_v_scrollbar.value = 0.0
	_v_scrollbar.value_changed.connect(_on_v_scroll_changed)
	vp_row.add_child(_v_scrollbar)

	# Horizontal scrollbar (bottom edge)
	_h_scrollbar = HScrollBar.new()
	_h_scrollbar.custom_minimum_size = Vector2(0, 12)
	_h_scrollbar.min_value = -SCROLL_WORLD_RANGE
	_h_scrollbar.max_value = SCROLL_WORLD_RANGE
	_h_scrollbar.page = 1000.0
	_h_scrollbar.value = 0.0
	_h_scrollbar.value_changed.connect(_on_h_scroll_changed)
	vp_outer.add_child(_h_scrollbar)

	add_child(right_vbox)

# ─────────────────────────────────────────────────────────────────────────────
# BUILD 2D SCENE — Camera + scene root inside the SubViewport
# ─────────────────────────────────────────────────────────────────────────────
func _build_2d_scene() -> void:
	# Background fill — dark grey
	var bg = ColorRect.new()
	bg.name = "EditorBackground"
	bg.color = Color(0.12, 0.12, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(bg)

	# Camera
	_camera = Camera2D.new()
	_camera.name = "EditorCamera"
	_camera.zoom = Vector2(DEFAULT_ZOOM, DEFAULT_ZOOM)
	_viewport.add_child(_camera)

	# Scene root — all user objects go here
	_scene_root = Node2D.new()
	_scene_root.name = "SceneRoot"
	_viewport.add_child(_scene_root)

# ─────────────────────────────────────────────────────────────────────────────
# BUILD OVERLAY — Draws grid, selection handles, collision shapes on top
# ─────────────────────────────────────────────────────────────────────────────
func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.name = "EditorOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_on_overlay_draw)
	_viewport_container.add_child(_overlay)

# ─────────────────────────────────────────────────────────────────────────────
# OVERLAY DRAW — Grid, selection highlights, collision shapes, rubber band
# ─────────────────────────────────────────────────────────────────────────────
func _on_overlay_draw() -> void:
	if not is_instance_valid(_overlay):
		return

	var vp_size = _viewport_container.size

	# Draw grid
	if _show_grid:
		_draw_grid(vp_size)

	# Draw origin axes
	_draw_origin_axes(vp_size)

	# Draw collision shapes
	if _show_collisions:
		_draw_collision_shapes(vp_size)

	# Draw selection handles
	for node in _selected_nodes:
		if is_instance_valid(node):
			_draw_selection_handle(node, vp_size)

	# Draw rubber band
	if _interact_mode == InteractMode.RUBBER_BAND:
		var rect = Rect2(_rubber_band_start, _rubber_band_end - _rubber_band_start).abs()
		_overlay.draw_rect(rect, RUBBER_BAND_COLOR)
		_overlay.draw_rect(rect, RUBBER_BAND_BORDER, false, 1.0)

func _draw_grid(vp_size: Vector2) -> void:
	var cell = GRID_SIZE * _cam_zoom
	if cell < 4.0:
		return  # Too zoomed out — skip grid

	# Calculate visible world area
	var half_vp = vp_size * 0.5
	var world_tl = _screen_to_world(Vector2.ZERO, vp_size)
	var world_br = _screen_to_world(vp_size, vp_size)

	# Minor grid lines
	var sub_cell = cell / GRID_SUBDIVISIONS
	if sub_cell >= 4.0:
		var start_x = snappedf(world_tl.x, GRID_SIZE / GRID_SUBDIVISIONS)
		var start_y = snappedf(world_tl.y, GRID_SIZE / GRID_SUBDIVISIONS)
		var x = start_x
		while x <= world_br.x:
			var sx = _world_to_screen(Vector2(x, 0), vp_size).x
			_overlay.draw_line(Vector2(sx, 0), Vector2(sx, vp_size.y), GRID_COLOR, 1.0)
			x += GRID_SIZE / GRID_SUBDIVISIONS
		var y = start_y
		while y <= world_br.y:
			var sy = _world_to_screen(Vector2(0, y), vp_size).y
			_overlay.draw_line(Vector2(0, sy), Vector2(vp_size.x, sy), GRID_COLOR, 1.0)
			y += GRID_SIZE / GRID_SUBDIVISIONS

	# Major grid lines
	var start_x = snappedf(world_tl.x, GRID_SIZE)
	var start_y = snappedf(world_tl.y, GRID_SIZE)
	var x = start_x
	while x <= world_br.x:
		var sx = _world_to_screen(Vector2(x, 0), vp_size).x
		_overlay.draw_line(Vector2(sx, 0), Vector2(sx, vp_size.y), GRID_COLOR_MAJOR, 1.0)
		x += GRID_SIZE
	var y = start_y
	while y <= world_br.y:
		var sy = _world_to_screen(Vector2(0, y), vp_size).y
		_overlay.draw_line(Vector2(0, sy), Vector2(vp_size.x, sy), GRID_COLOR_MAJOR, 1.0)
		y += GRID_SIZE

func _draw_origin_axes(vp_size: Vector2) -> void:
	var origin_screen = _world_to_screen(Vector2.ZERO, vp_size)
	# X axis (red)
	if origin_screen.y >= 0 and origin_screen.y <= vp_size.y:
		_overlay.draw_line(Vector2(0, origin_screen.y), Vector2(vp_size.x, origin_screen.y), ORIGIN_X_COLOR, 2.0)
	# Y axis (green)
	if origin_screen.x >= 0 and origin_screen.x <= vp_size.x:
		_overlay.draw_line(Vector2(origin_screen.x, 0), Vector2(origin_screen.x, vp_size.y), ORIGIN_Y_COLOR, 2.0)

func _draw_selection_handle(node: CanvasItem, vp_size: Vector2) -> void:
	var screen_pos = _world_to_screen(node.global_position, vp_size)
	var color = SELECTION_COLOR if node == _primary_selected else MULTI_SELECTION_COLOR

	# Get visual bounds
	var rect = _get_node_visual_rect(node)
	if rect.size.x > 0 or rect.size.y > 0:
		# Draw bounding box
		var tl = _world_to_screen(rect.position, vp_size)
		var br = _world_to_screen(rect.position + rect.size, vp_size)
		var screen_rect = Rect2(tl, br - tl)
		_overlay.draw_rect(screen_rect, color, false, 2.0)

		# Draw corner handles
		var corners = [tl, Vector2(br.x, tl.y), br, Vector2(tl.x, br.y)]
		for c in corners:
			_overlay.draw_rect(Rect2(c - Vector2(HANDLE_SIZE, HANDLE_SIZE), Vector2(HANDLE_SIZE * 2, HANDLE_SIZE * 2)), color)

		# Rotation handle (circle above)
		if _tool_mode == ToolMode.ROTATE:
			var top_center = Vector2((tl.x + br.x) * 0.5, tl.y - ROTATION_HANDLE_DIST)
			_overlay.draw_line(Vector2((tl.x + br.x) * 0.5, tl.y), top_center, color, 1.0)
			_overlay.draw_circle(top_center, HANDLE_SIZE, color)
	else:
		# No visual bounds — draw crosshair
		_overlay.draw_line(screen_pos + Vector2(-12, 0), screen_pos + Vector2(12, 0), color, 2.0)
		_overlay.draw_line(screen_pos + Vector2(0, -12), screen_pos + Vector2(0, 12), color, 2.0)
		_overlay.draw_circle(screen_pos, 4.0, color)

	# Label
	var label_pos = screen_pos + Vector2(8, -12)
	_overlay.draw_string(ThemeDB.fallback_font, label_pos, node.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)

func _draw_collision_shapes(_vp_size: Vector2) -> void:
	if not is_instance_valid(_scene_root):
		return
	var shapes = _find_all_of_type(_scene_root, "CollisionShape2D")
	for cs in shapes:
		if not cs is CollisionShape2D:
			continue
		if cs.shape == null:
			continue
		var gpos = cs.global_position
		var screen_pos = _world_to_screen(gpos, _vp_size)
		var gs = cs.global_scale.abs()
		if cs.shape is RectangleShape2D:
			var ext = cs.shape.size * 0.5 * gs * _cam_zoom
			var r = Rect2(screen_pos - ext, ext * 2)
			_overlay.draw_rect(r, COLLISION_SHAPE_COLOR)
			_overlay.draw_rect(r, COLLISION_SHAPE_BORDER, false, 1.5)
			# Draw resize corner handles when this shape is selected
			if cs == _primary_selected:
				var handle_col = Color(1.0, 1.0, 1.0, 0.9)
				var corners = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
				for c in corners:
					_overlay.draw_rect(Rect2(c - Vector2(HANDLE_SIZE, HANDLE_SIZE), Vector2(HANDLE_SIZE * 2, HANDLE_SIZE * 2)), handle_col, false, 2.0)
					_overlay.draw_rect(Rect2(c - Vector2(HANDLE_SIZE - 1, HANDLE_SIZE - 1), Vector2((HANDLE_SIZE - 1) * 2, (HANDLE_SIZE - 1) * 2)), COLLISION_SHAPE_BORDER)
		elif cs.shape is CircleShape2D:
			var s = maxf(gs.x, gs.y)
			var rad = cs.shape.radius * s * _cam_zoom
			_overlay.draw_circle(screen_pos, rad, COLLISION_SHAPE_COLOR)
			_overlay.draw_arc(screen_pos, rad, 0, TAU, 32, COLLISION_SHAPE_BORDER, 1.5)
			# Draw resize handles at cardinal points when selected
			if cs == _primary_selected:
				var handle_col = Color(1.0, 1.0, 1.0, 0.9)
				var pts = [screen_pos + Vector2(rad, 0), screen_pos + Vector2(-rad, 0),
						   screen_pos + Vector2(0, rad), screen_pos + Vector2(0, -rad)]
				for p in pts:
					_overlay.draw_rect(Rect2(p - Vector2(HANDLE_SIZE, HANDLE_SIZE), Vector2(HANDLE_SIZE * 2, HANDLE_SIZE * 2)), handle_col, false, 2.0)
					_overlay.draw_rect(Rect2(p - Vector2(HANDLE_SIZE - 1, HANDLE_SIZE - 1), Vector2((HANDLE_SIZE - 1) * 2, (HANDLE_SIZE - 1) * 2)), COLLISION_SHAPE_BORDER)
		elif cs.shape is CapsuleShape2D:
			var rad = cs.shape.radius * gs.x * _cam_zoom
			var h = cs.shape.height * 0.5 * gs.y * _cam_zoom
			var r = Rect2(screen_pos - Vector2(rad, h), Vector2(rad * 2, h * 2))
			_overlay.draw_rect(r, COLLISION_SHAPE_COLOR)
			_overlay.draw_rect(r, COLLISION_SHAPE_BORDER, false, 1.5)
			if cs == _primary_selected:
				var handle_col = Color(1.0, 1.0, 1.0, 0.9)
				var corners = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
				for c in corners:
					_overlay.draw_rect(Rect2(c - Vector2(HANDLE_SIZE, HANDLE_SIZE), Vector2(HANDLE_SIZE * 2, HANDLE_SIZE * 2)), handle_col, false, 2.0)
					_overlay.draw_rect(Rect2(c - Vector2(HANDLE_SIZE - 1, HANDLE_SIZE - 1), Vector2((HANDLE_SIZE - 1) * 2, (HANDLE_SIZE - 1) * 2)), COLLISION_SHAPE_BORDER)

func _find_all_of_type(root: Node, type_name: String) -> Array:
	var result: Array = []
	for child in root.get_children():
		if child.get_class() == type_name:
			result.append(child)
		result.append_array(_find_all_of_type(child, type_name))
	return result

# ─────────────────────────────────────────────────────────────────────────────
# COORDINATE CONVERSION — World ↔ Screen
# ─────────────────────────────────────────────────────────────────────────────
func _screen_to_world(screen_pos: Vector2, vp_size: Vector2) -> Vector2:
	var half = vp_size * 0.5
	return (screen_pos - half) / _cam_zoom + _cam_offset

func _world_to_screen(world_pos: Vector2, vp_size: Vector2) -> Vector2:
	var half = vp_size * 0.5
	return (world_pos - _cam_offset) * _cam_zoom + half

# ─────────────────────────────────────────────────────────────────────────────
# CAMERA
# ─────────────────────────────────────────────────────────────────────────────
func _update_camera() -> void:
	if not is_instance_valid(_camera):
		return
	_camera.position = _cam_offset
	_camera.zoom = Vector2(_cam_zoom, _cam_zoom)
	_update_scrollbars()
	_update_status()

func _reset_camera() -> void:
	if is_instance_valid(_scene_root) and _scene_root.get_child_count() > 0:
		_fit_scene_in_view()
	else:
		_cam_offset = Vector2.ZERO
		_cam_zoom = DEFAULT_ZOOM
		_update_camera()
	if is_instance_valid(_overlay):
		_overlay.queue_redraw()

## Keep scrollbar positions in sync with _cam_offset / _cam_zoom.
func _update_scrollbars() -> void:
	if _scrollbar_updating:
		return
	_scrollbar_updating = true
	if is_instance_valid(_h_scrollbar):
		var vp_w := float(_viewport.size.x) if is_instance_valid(_viewport) else 1024.0
		_h_scrollbar.page = vp_w / _cam_zoom
		_h_scrollbar.value = _cam_offset.x
	if is_instance_valid(_v_scrollbar):
		var vp_h := float(_viewport.size.y) if is_instance_valid(_viewport) else 768.0
		_v_scrollbar.page = vp_h / _cam_zoom
		_v_scrollbar.value = _cam_offset.y
	_scrollbar_updating = false

func _on_h_scroll_changed(value: float) -> void:
	if _scrollbar_updating:
		return
	_cam_offset.x = value
	_update_camera()
	if is_instance_valid(_overlay):
		_overlay.queue_redraw()

func _on_v_scroll_changed(value: float) -> void:
	if _scrollbar_updating:
		return
	_cam_offset.y = value
	_update_camera()
	if is_instance_valid(_overlay):
		_overlay.queue_redraw()

func _focus_selected() -> void:
	if _primary_selected and is_instance_valid(_primary_selected):
		_cam_offset = _primary_selected.global_position
		_update_camera()
		if is_instance_valid(_overlay):
			_overlay.queue_redraw()
	else:
		_fit_scene_in_view()

## Strip ShaderMaterial from all Sprite2D descendants so textures render
## properly in the editor preview (shaders may not bind correctly in SubViewport).
func _strip_shader_materials(root: Node) -> void:
	for child in root.get_children():
		if child is CanvasItem and child.material is ShaderMaterial:
			child.material = null
		_strip_shader_materials(child)

## Compute the bounding rect of all visible nodes and center/zoom the camera
## so everything fits in the viewport with some padding.
var _fit_scene_defer_count := 0
func _fit_scene_in_view() -> void:
	if not is_instance_valid(_scene_root) or _scene_root.get_child_count() == 0:
		_fit_scene_defer_count = 0
		return
	var vp_size := Vector2(_viewport.size)
	# If viewport hasn't been laid out yet, defer until next frame (max 10 retries)
	if vp_size.x < 100.0 or vp_size.y < 100.0:
		_fit_scene_defer_count += 1
		if _fit_scene_defer_count < 10:
			call_deferred("_fit_scene_in_view")
		else:
			push_warning("[VG2D] _fit_scene_in_view: viewport too small after 10 retries, giving up")
			_fit_scene_defer_count = 0
		return
	_fit_scene_defer_count = 0
	# Mimic Godot's default 2D view: 100% zoom, origin in upper-left area.
	# Camera position is the world-space center of the viewport.
	# Place origin ~100px from left, ~50px from top so game content fills
	# the viewport — exactly like Godot's 2D editor.
	_cam_zoom = DEFAULT_ZOOM
	_cam_offset.x = vp_size.x * 0.5 - 100.0
	_cam_offset.y = vp_size.y * 0.5 - 50.0
	_update_camera()
	if is_instance_valid(_overlay):
		_overlay.queue_redraw()
	print("[VG2D] Fit scene in view: vp_size=", vp_size, " offset=", _cam_offset, " zoom=", _cam_zoom)

# ─────────────────────────────────────────────────────────────────────────────
# INPUT HANDLING
# ─────────────────────────────────────────────────────────────────────────────
func _on_viewport_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventKey:
		_handle_key(event)
	elif event is InputEventPanGesture:
		_handle_pan_gesture(event)
	elif event is InputEventMagnifyGesture:
		_handle_magnify_gesture(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	var vp_size = _viewport_container.size

	match event.button_index:
		MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_panning = true
				_last_mouse_pos = event.position
			else:
				_panning = false

		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_cam_zoom = clampf(_cam_zoom * 1.1, MIN_ZOOM, MAX_ZOOM)
				_update_camera()
				_overlay.queue_redraw()

		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_cam_zoom = clampf(_cam_zoom / 1.1, MIN_ZOOM, MAX_ZOOM)
				_update_camera()
				_overlay.queue_redraw()

		MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Alt+LMB → pan (laptop friendly)
				if event.alt_pressed and event.shift_pressed:
					_alt_panning = true
					_last_mouse_pos = event.position
					return
				elif event.alt_pressed:
					_panning = true
					_last_mouse_pos = event.position
					return

				# Check if clicking on a resize handle of a selected CollisionShape2D
				var _resize_check := -1
				if _primary_selected and is_instance_valid(_primary_selected):
					if _primary_selected is CollisionShape2D and _primary_selected.shape:
						_resize_check = _check_shape_resize_handle(event.position, _primary_selected, vp_size)
				if _resize_check >= 0:
					# Start shape resize interaction
					_interact_mode = InteractMode.RESIZING_SHAPE
					_resize_shape_node = _primary_selected
					_resize_corner = _resize_check
					if _primary_selected.shape is RectangleShape2D:
						_resize_start_size = _primary_selected.shape.size
					elif _primary_selected.shape is CircleShape2D:
						_resize_start_radius = _primary_selected.shape.radius
					elif _primary_selected.shape is CapsuleShape2D:
						_resize_start_size = Vector2(_primary_selected.shape.radius, _primary_selected.shape.height)
					_overlay.queue_redraw()
					return

				# Normal click — try to select
				var world_pos = _screen_to_world(event.position, vp_size)
				var hit = _pick_node_at(world_pos)

				if event.double_click and hit:
					node_double_clicked.emit(hit)
					return

				if hit:
					if event.shift_pressed:
						# Shift-click: toggle in multi-selection
						if hit in _selected_nodes:
							_selected_nodes.erase(hit)
							if _primary_selected == hit:
								_primary_selected = _selected_nodes[0] if _selected_nodes.size() > 0 else null
						else:
							_selected_nodes.append(hit)
							_primary_selected = hit
						_on_selection_changed()
					else:
						if hit not in _selected_nodes:
							_select_node(hit)
						# Start interaction based on current tool mode
						_drag_start_screen = event.position
						_drag_start_positions.clear()
						_drag_transforms_before.clear()
						_scale_start_values.clear()
						for n in _selected_nodes:
							_drag_start_positions.append(n.position)
							_drag_transforms_before.append({"node": n, "position": n.position, "rotation": n.rotation, "scale": n.scale})
							_scale_start_values.append(n.scale)
						match _tool_mode:
							ToolMode.ROTATE:
								if _primary_selected and is_instance_valid(_primary_selected):
									_interact_mode = InteractMode.ROTATING
									var center = _world_to_screen(_primary_selected.global_position, vp_size)
									_rotate_start_angle = (event.position - center).angle()
									_rotate_node_start = _primary_selected.rotation
							ToolMode.SCALE:
								_interact_mode = InteractMode.SCALING
								_scale_start_screen = event.position
							_:
								_interact_mode = InteractMode.DRAGGING
				else:
					# Click on empty space
					if not event.shift_pressed:
						_deselect_all()
					# Start rubber band
					_interact_mode = InteractMode.RUBBER_BAND
					_rubber_band_start = event.position
					_rubber_band_end = event.position
				_overlay.queue_redraw()
			else:
				# Release
				if _alt_panning:
					_alt_panning = false
					return

				if _interact_mode == InteractMode.DRAGGING:
					# Push undo for the drag
					if _drag_transforms_before.size() > 0:
						var after: Array[Dictionary] = []
						var moved := false
						for i in range(_selected_nodes.size()):
							var n = _selected_nodes[i]
							after.append({"node": n, "position": n.position, "rotation": n.rotation, "scale": n.scale})
							if i < _drag_transforms_before.size() and n.position != _drag_transforms_before[i]["position"]:
								moved = true
						if moved:
							_push_undo({"type": "transform", "before": _drag_transforms_before.duplicate(), "after": after})
					_interact_mode = InteractMode.NONE
					_scene_dirty = true
				elif _interact_mode == InteractMode.RUBBER_BAND:
					# Select nodes inside rubber band (supports both Node2D and Control)
					var screen_rect = Rect2(_rubber_band_start, _rubber_band_end - _rubber_band_start).abs()
					if not event.shift_pressed:
						_selected_nodes.clear()
					var rb_candidates: Array[Node] = []
					_collect_pickable_nodes(_scene_root, rb_candidates)
					for child in rb_candidates:
						if child is CanvasItem:
							var sp = _world_to_screen(child.global_position, vp_size)
							if screen_rect.has_point(sp):
								if child not in _selected_nodes:
									_selected_nodes.append(child as CanvasItem)
					_primary_selected = _selected_nodes[0] if _selected_nodes.size() > 0 else null
					_interact_mode = InteractMode.NONE
					_on_selection_changed()
				elif _interact_mode == InteractMode.ROTATING:
					if _drag_transforms_before.size() > 0:
						var after: Array[Dictionary] = []
						for n in _selected_nodes:
							after.append({"node": n, "position": n.position, "rotation": n.rotation, "scale": n.scale})
						_push_undo({"type": "transform", "before": _drag_transforms_before.duplicate(), "after": after})
					_interact_mode = InteractMode.NONE
					_scene_dirty = true
				elif _interact_mode == InteractMode.SCALING:
					if _drag_transforms_before.size() > 0:
						var after: Array[Dictionary] = []
						for n in _selected_nodes:
							after.append({"node": n, "position": n.position, "rotation": n.rotation, "scale": n.scale})
						_push_undo({"type": "transform", "before": _drag_transforms_before.duplicate(), "after": after})
					_interact_mode = InteractMode.NONE
					_scene_dirty = true
				elif _interact_mode == InteractMode.RESIZING_SHAPE:
					if _resize_shape_node and is_instance_valid(_resize_shape_node):
						var cs = _resize_shape_node as CollisionShape2D
						if cs and cs.shape:
							var undo_entry: Dictionary = {"type": "shape_resize", "node": cs}
							if cs.shape is RectangleShape2D:
								undo_entry["before_size"] = _resize_start_size
								undo_entry["after_size"] = cs.shape.size
							elif cs.shape is CircleShape2D:
								undo_entry["before_radius"] = _resize_start_radius
								undo_entry["after_radius"] = cs.shape.radius
							elif cs.shape is CapsuleShape2D:
								undo_entry["before_size"] = _resize_start_size
								undo_entry["after_size"] = Vector2(cs.shape.radius, cs.shape.height)
							_push_undo(undo_entry)
					_interact_mode = InteractMode.NONE
					_resize_shape_node = null
					_resize_corner = -1
					_scene_dirty = true
				else:
					_interact_mode = InteractMode.NONE
				_overlay.queue_redraw()

		MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_rmb_press_pos = event.position
				_rmb_panning = true
				_last_mouse_pos = event.position
			else:
				var was_panning := _rmb_panning
				_rmb_panning = false
				# Only show context menu if mouse didn't move much (not a pan drag)
				if event.position.distance_to(_rmb_press_pos) < 5.0:
					var world_pos = _screen_to_world(event.position, vp_size)
					var hit = _pick_node_at(world_pos)
					if hit:
						if hit not in _selected_nodes:
							_select_node(hit)
					_show_context_menu(event.position)

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var vp_size = _viewport_container.size

	if _panning or _alt_panning or _rmb_panning:
		var delta = event.position - _last_mouse_pos
		_cam_offset -= delta / _cam_zoom
		_last_mouse_pos = event.position
		_update_camera()
		_overlay.queue_redraw()
		return

	match _interact_mode:
		InteractMode.DRAGGING:
			var delta_screen = event.position - _drag_start_screen
			var delta_world = delta_screen / _cam_zoom
			for i in range(_selected_nodes.size()):
				if i < _drag_start_positions.size():
					var new_pos = _drag_start_positions[i] + delta_world
					if _snap_enabled:
						new_pos = Vector2(snappedf(new_pos.x, _snap_value), snappedf(new_pos.y, _snap_value))
					_selected_nodes[i].position = new_pos
			_update_transform_panel()
			_overlay.queue_redraw()

		InteractMode.RUBBER_BAND:
			_rubber_band_end = event.position
			_overlay.queue_redraw()

		InteractMode.ROTATING:
			if _primary_selected and is_instance_valid(_primary_selected):
				var center = _world_to_screen(_primary_selected.global_position, vp_size)
				var angle = (event.position - center).angle()
				var delta_angle = angle - _rotate_start_angle
				if _snap_enabled:
					delta_angle = snappedf(delta_angle, deg_to_rad(15.0))
				_primary_selected.rotation = _rotate_node_start + delta_angle
				_update_transform_panel()
				_overlay.queue_redraw()

		InteractMode.SCALING:
			if _primary_selected and is_instance_valid(_primary_selected):
				var delta_screen = event.position - _scale_start_screen
				var scale_factor = 1.0 + delta_screen.x * 0.005
				for i in range(_selected_nodes.size()):
					if i < _scale_start_values.size():
						_selected_nodes[i].scale = _scale_start_values[i] * scale_factor
				_update_transform_panel()
				_overlay.queue_redraw()

		InteractMode.RESIZING_SHAPE:
			if _resize_shape_node and is_instance_valid(_resize_shape_node):
				var cs = _resize_shape_node as CollisionShape2D
				if cs and cs.shape:
					var mouse_world = _screen_to_world(event.position, vp_size)
					var center = cs.global_position
					if cs.shape is RectangleShape2D:
						var half_ext = (mouse_world - center).abs()
						if _snap_enabled:
							half_ext = Vector2(snappedf(half_ext.x, _snap_value), snappedf(half_ext.y, _snap_value))
						var new_size = half_ext * 2.0
						var gs = cs.global_scale.abs()
						if gs.x > 0.001 and gs.y > 0.001:
							new_size /= gs
						new_size = new_size.max(Vector2(2, 2))
						cs.shape.size = new_size
					elif cs.shape is CircleShape2D:
						var dist = (mouse_world - center).length()
						if _snap_enabled:
							dist = snappedf(dist, _snap_value)
						dist = maxf(dist, 2.0)
						var gs_max = maxf(abs(cs.global_scale.x), abs(cs.global_scale.y))
						if gs_max > 0.001:
							dist /= gs_max
						cs.shape.radius = dist
					elif cs.shape is CapsuleShape2D:
						var half_ext = (mouse_world - center).abs()
						if _snap_enabled:
							half_ext = Vector2(snappedf(half_ext.x, _snap_value), snappedf(half_ext.y, _snap_value))
						var new_r = maxf(half_ext.x, 2.0)
						var new_h = maxf(half_ext.y * 2.0, 4.0)
						var gs = cs.global_scale.abs()
						if gs.x > 0.001:
							new_r /= gs.x
						if gs.y > 0.001:
							new_h /= gs.y
						cs.shape.radius = new_r
						cs.shape.height = new_h
					_overlay.queue_redraw()

func _handle_key(event: InputEventKey) -> void:
	if not event.pressed:
		return

	# Tool shortcuts
	if event.keycode == KEY_S and not event.ctrl_pressed:
		_set_tool_mode(ToolMode.SELECT)
		_viewport_container.accept_event()
	elif event.keycode == KEY_W and not event.ctrl_pressed:
		_set_tool_mode(ToolMode.MOVE)
		_viewport_container.accept_event()
	elif event.keycode == KEY_E and not event.ctrl_pressed:
		_set_tool_mode(ToolMode.ROTATE)
		_viewport_container.accept_event()
	elif event.keycode == KEY_R and not event.ctrl_pressed:
		_set_tool_mode(ToolMode.SCALE)
		_viewport_container.accept_event()
	elif event.keycode == KEY_F:
		_focus_selected()
		_viewport_container.accept_event()
	elif event.keycode == KEY_G:
		_snap_enabled = not _snap_enabled
		_snap_toggle.button_pressed = _snap_enabled
		_viewport_container.accept_event()
	elif event.keycode == KEY_DELETE:
		_delete_selected()
		_viewport_container.accept_event()
	elif event.keycode == KEY_F1:
		_help_dialog.popup_centered()
		_viewport_container.accept_event()
	elif event.keycode == KEY_F2:
		_rename_selected()
		_viewport_container.accept_event()
	elif event.keycode == KEY_Z and event.ctrl_pressed:
		_undo()
		_viewport_container.accept_event()
	elif event.keycode == KEY_Y and event.ctrl_pressed:
		_redo()
		_viewport_container.accept_event()
	elif event.keycode == KEY_D and event.ctrl_pressed:
		_duplicate_selected()
		_viewport_container.accept_event()
	elif event.keycode == KEY_S and event.ctrl_pressed:
		_save_scene()
		_viewport_container.accept_event()
	elif event.keycode == KEY_C and event.ctrl_pressed:
		_copy_selected()
		_viewport_container.accept_event()
	elif event.keycode == KEY_V and event.ctrl_pressed:
		_paste()
		_viewport_container.accept_event()
	elif event.keycode == KEY_A and event.ctrl_pressed:
		_select_all()
		_viewport_container.accept_event()
	elif event.keycode == KEY_ESCAPE:
		_deselect_all()
		_viewport_container.accept_event()

func _handle_pan_gesture(event: InputEventPanGesture) -> void:
	# Two-finger swipe → pan
	if event.shift_pressed or event.alt_pressed:
		_cam_offset += event.delta * 4.0 / _cam_zoom
	else:
		_cam_offset += event.delta * 4.0 / _cam_zoom
	_update_camera()
	_overlay.queue_redraw()

func _handle_magnify_gesture(event: InputEventMagnifyGesture) -> void:
	if event.factor < 1.0:
		_cam_zoom = clampf(_cam_zoom / 1.05, MIN_ZOOM, MAX_ZOOM)
	else:
		_cam_zoom = clampf(_cam_zoom * 1.05, MIN_ZOOM, MAX_ZOOM)
	_update_camera()
	_overlay.queue_redraw()

# ─────────────────────────────────────────────────────────────────────────────
# NODE PICKING — 2D hit testing
# ─────────────────────────────────────────────────────────────────────────────
func _check_shape_resize_handle(screen_pos: Vector2, node: Node, vp_size: Vector2) -> int:
	## Returns corner index (0=TL,1=TR,2=BR,3=BL) if screen_pos is near a
	## corner handle of a CollisionShape2D, otherwise -1.
	if not node is CollisionShape2D or node.shape == null:
		return -1
	var rect = _get_node_visual_rect(node)
	if rect.size.x <= 0 and rect.size.y <= 0:
		return -1
	var tl = _world_to_screen(rect.position, vp_size)
	var br = _world_to_screen(rect.position + rect.size, vp_size)
	var corners = [tl, Vector2(br.x, tl.y), br, Vector2(tl.x, br.y)]
	var grab_dist = HANDLE_SIZE + 6.0  # slightly larger for easier grabbing
	for i in range(corners.size()):
		if screen_pos.distance_to(corners[i]) <= grab_dist:
			return i
	return -1

func _pick_node_at(world_pos: Vector2) -> Node:
	if not is_instance_valid(_scene_root):
		return null

	# Iterate children back-to-front (last = on top visually)
	var best: Node = null
	var candidates: Array[Node] = []
	_collect_pickable_nodes(_scene_root, candidates)

	for node in candidates:
		var rect = _get_node_visual_rect(node)
		if rect.size.x > 0 or rect.size.y > 0:
			if rect.has_point(world_pos):
				best = node  # Last hit wins (front-most)
		else:
			# No visual rect — use small proximity check
			if world_pos.distance_to(node.global_position) < 16.0:
				best = node
	return best

func _collect_pickable_nodes(parent: Node, out: Array[Node]) -> void:
	for child in parent.get_children():
		if (child is Node2D or child is Control) and child.name != "EditorCamera" and child.name != "EditorBackground":
			out.append(child)
		_collect_pickable_nodes(child, out)

func _get_node_visual_rect(node) -> Rect2:
	if node is Sprite2D:
		if node.texture:
			var size = node.texture.get_size() * node.scale
			if node.centered:
				return Rect2(node.global_position - size * 0.5, size)
			else:
				return Rect2(node.global_position, size)
	elif node is ColorRect:
		return Rect2(node.global_position, node.size * node.scale)
	elif node is AnimatedSprite2D:
		if node.sprite_frames and node.sprite_frames.get_frame_count("default") > 0:
			var tex = node.sprite_frames.get_frame_texture("default", 0)
			if tex:
				var size = tex.get_size() * node.scale
				return Rect2(node.global_position - size * 0.5, size)
	elif node is CollisionShape2D and node.shape:
		if node.shape is RectangleShape2D:
			var s = node.shape.size * node.global_scale.abs()
			return Rect2(node.global_position - s * 0.5, s)
		elif node.shape is CircleShape2D:
			var r = node.shape.radius * max(abs(node.global_scale.x), abs(node.global_scale.y))
			return Rect2(node.global_position - Vector2(r, r), Vector2(r * 2, r * 2))
		elif node.shape is CapsuleShape2D:
			var gs = node.global_scale.abs()
			var w = node.shape.radius * gs.x * 2.0
			var h = node.shape.height * gs.y
			return Rect2(node.global_position - Vector2(w * 0.5, h * 0.5), Vector2(w, h))

	# Fallback: check if the node has a visible size property
	if "size" in node:
		var s = node.get("size")
		if s is Vector2 and (s.x > 0 or s.y > 0):
			return Rect2(node.global_position, s * node.scale)

	# No visual representation — return zero-size rect
	return Rect2(node.global_position, Vector2.ZERO)

# ─────────────────────────────────────────────────────────────────────────────
# SELECTION MANAGEMENT
# ─────────────────────────────────────────────────────────────────────────────
func _select_node(node: CanvasItem) -> void:
	_selected_nodes.clear()
	_selected_nodes.append(node)
	_primary_selected = node
	_on_selection_changed()

func _deselect_all() -> void:
	_selected_nodes.clear()
	_primary_selected = null
	_on_selection_changed()

func _select_all() -> void:
	_selected_nodes.clear()
	var candidates: Array[Node] = []
	_collect_pickable_nodes(_scene_root, candidates)
	for node in candidates:
		if node is CanvasItem:
			_selected_nodes.append(node as CanvasItem)
	_primary_selected = _selected_nodes[0] if _selected_nodes.size() > 0 else null
	_on_selection_changed()

func _on_selection_changed() -> void:
	_update_transform_panel()
	_update_scene_tree_selection()
	_overlay.queue_redraw()
	if _primary_selected:
		if _node_inspector:
			_node_inspector.inspect(_primary_selected)
		node_selected.emit(_primary_selected)
	else:
		if _node_inspector:
			_node_inspector.clear()
		selection_cleared.emit()
	_update_status()

# ─────────────────────────────────────────────────────────────────────────────
# TOOL MODE
# ─────────────────────────────────────────────────────────────────────────────
func _set_tool_mode(mode: ToolMode) -> void:
	_tool_mode = mode
	_tool_btn_select.set_pressed_no_signal(mode == ToolMode.SELECT)
	_tool_btn_move.set_pressed_no_signal(mode == ToolMode.MOVE)
	_tool_btn_rotate.set_pressed_no_signal(mode == ToolMode.ROTATE)
	_tool_btn_scale.set_pressed_no_signal(mode == ToolMode.SCALE)
	_overlay.queue_redraw()
	_update_status()

# ─────────────────────────────────────────────────────────────────────────────
# TRANSFORM PANEL
# ─────────────────────────────────────────────────────────────────────────────
func _update_transform_panel() -> void:
	if not _primary_selected or not is_instance_valid(_primary_selected):
		_pos_x.set_value_no_signal(0)
		_pos_y.set_value_no_signal(0)
		_rot_z.set_value_no_signal(0)
		_scl_x.set_value_no_signal(1)
		_scl_y.set_value_no_signal(1)
		return

	_pos_x.set_value_no_signal(_primary_selected.position.x)
	_pos_y.set_value_no_signal(_primary_selected.position.y)
	_rot_z.set_value_no_signal(rad_to_deg(_primary_selected.rotation))
	_scl_x.set_value_no_signal(_primary_selected.scale.x)
	_scl_y.set_value_no_signal(_primary_selected.scale.y)

func _on_transform_value_changed(_value: float = 0.0) -> void:
	if not _primary_selected or not is_instance_valid(_primary_selected):
		return

	var before = {"node": _primary_selected, "position": _primary_selected.position,
		"rotation": _primary_selected.rotation, "scale": _primary_selected.scale}

	_primary_selected.position = Vector2(_pos_x.value, _pos_y.value)
	_primary_selected.rotation = deg_to_rad(_rot_z.value)
	_primary_selected.scale = Vector2(_scl_x.value, _scl_y.value)

	var after = {"node": _primary_selected, "position": _primary_selected.position,
		"rotation": _primary_selected.rotation, "scale": _primary_selected.scale}
	_push_undo({"type": "transform", "before": [before], "after": [after]})

	_scene_dirty = true
	_overlay.queue_redraw()

# ─────────────────────────────────────────────────────────────────────────────
# NODE OPERATIONS
# ─────────────────────────────────────────────────────────────────────────────
func _delete_selected() -> void:
	if _selected_nodes.is_empty():
		return

	var deleted: Array = []
	for node in _selected_nodes:
		if is_instance_valid(node):
			var dup = node.duplicate()
			deleted.append({"node_dup": dup, "parent": node.get_parent(), "name": node.name,
				"position": node.position, "rotation": node.rotation, "scale": node.scale,
				"index": node.get_index()})
			node.get_parent().remove_child(node)
			node.queue_free()

	_push_undo({"type": "delete", "nodes": deleted})
	_deselect_all()
	_rebuild_scene_tree()
	_scene_dirty = true

func _duplicate_selected() -> void:
	if _selected_nodes.is_empty():
		return

	var new_nodes: Array[CanvasItem] = []
	for node in _selected_nodes:
		if is_instance_valid(node):
			var dup = node.duplicate()
			dup.name = _unique_name(node.name, _scene_root)
			dup.position += Vector2(32, 32)
			_scene_root.add_child(dup)
			new_nodes.append(dup)

	_selected_nodes = new_nodes
	_primary_selected = new_nodes[0] if new_nodes.size() > 0 else null

	var added: Array = []
	for n in new_nodes:
		added.append({"node": n, "name": n.name})
	_push_undo({"type": "add", "nodes": added})

	_on_selection_changed()
	_rebuild_scene_tree()
	_scene_dirty = true

var _clipboard: Array = []  # stored duplicates

func _copy_selected() -> void:
	_clipboard.clear()
	for node in _selected_nodes:
		if is_instance_valid(node):
			_clipboard.append(node.duplicate())

func _paste() -> void:
	if _clipboard.is_empty():
		return

	var new_nodes: Array[CanvasItem] = []
	for stored in _clipboard:
		var dup = stored.duplicate()
		dup.name = _unique_name(stored.name, _scene_root)
		dup.position += Vector2(16, 16)
		_scene_root.add_child(dup)
		if dup is Node2D:
			new_nodes.append(dup)

	_selected_nodes = new_nodes
	_primary_selected = new_nodes[0] if new_nodes.size() > 0 else null

	var added: Array = []
	for n in new_nodes:
		added.append({"node": n, "name": n.name})
	_push_undo({"type": "add", "nodes": added})

	_on_selection_changed()
	_rebuild_scene_tree()
	_scene_dirty = true

func _rename_selected() -> void:
	if not _primary_selected or not is_instance_valid(_primary_selected):
		return

	var dialog = AcceptDialog.new()
	dialog.title = "Rename Node"
	dialog.dialog_text = ""

	var line_edit = LineEdit.new()
	line_edit.text = _primary_selected.name
	line_edit.select_all()
	dialog.add_child(line_edit)

	var captured_node = _primary_selected
	dialog.confirmed.connect(func():
		if is_instance_valid(captured_node) and not line_edit.text.is_empty():
			captured_node.name = line_edit.text
			_rebuild_scene_tree()
			_overlay.queue_redraw()
			_scene_dirty = true
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())

	add_child(dialog)
	dialog.popup_centered(Vector2(300, 100))
	line_edit.grab_focus()

func _toggle_visibility_selected() -> void:
	if not _primary_selected or not is_instance_valid(_primary_selected):
		return
	_primary_selected.visible = not _primary_selected.visible
	_rebuild_scene_tree()
	_overlay.queue_redraw()

func _reset_transform_selected() -> void:
	if _selected_nodes.is_empty():
		return
	var before: Array[Dictionary] = []
	for n in _selected_nodes:
		before.append({"node": n, "position": n.position, "rotation": n.rotation, "scale": n.scale})
	for n in _selected_nodes:
		n.position = Vector2.ZERO
		n.rotation = 0
		n.scale = Vector2.ONE
	var after: Array[Dictionary] = []
	for n in _selected_nodes:
		after.append({"node": n, "position": n.position, "rotation": n.rotation, "scale": n.scale})
	_push_undo({"type": "transform", "before": before, "after": after})
	_update_transform_panel()
	_overlay.queue_redraw()
	_scene_dirty = true

# ─────────────────────────────────────────────────────────────────────────────
# TOOLBOX
# ─────────────────────────────────────────────────────────────────────────────
func _populate_toolbox() -> void:
	_toolbox_list.clear()
	for item in _toolbox_items:
		_toolbox_list.add_item(item.icon + " " + item.name)

func _on_add_object_pressed() -> void:
	var sel = _toolbox_list.get_selected_items()
	if sel.is_empty():
		return
	var idx = sel[0]
	if idx >= 0 and idx < _toolbox_items.size():
		var item = _toolbox_items[idx]
		_add_2d_object(item.type, item.name)

func _on_toolbox_item_double_clicked(idx: int) -> void:
	if idx >= 0 and idx < _toolbox_items.size():
		var item = _toolbox_items[idx]
		_add_2d_object(item.type, item.name)

func _add_2d_object(type_name: String, display_name: String) -> void:
	var node: Node = null  # Changed from Node2D to Node to support Control nodes

	match type_name:
		"Sprite2D":
			node = Sprite2D.new()
			node.name = _unique_name("Sprite2D", _scene_root)
		"AnimatedSprite2D":
			node = AnimatedSprite2D.new()
			node.name = _unique_name("AnimatedSprite2D", _scene_root)
		"Camera2D":
			node = Camera2D.new()
			node.name = _unique_name("Camera2D", _scene_root)
		"CanvasLayer":
			node = CanvasLayer.new()
			node.name = _unique_name("CanvasLayer", _scene_root)
		"CharacterBody2D":
			var body = CharacterBody2D.new()
			body.name = _unique_name("CharacterBody2D", _scene_root)
			# Add default collision shape
			var shape = CollisionShape2D.new()
			shape.name = "CollisionShape2D"
			var rect_shape = RectangleShape2D.new()
			rect_shape.size = Vector2(32, 32)
			shape.shape = rect_shape
			body.add_child(shape)
			node = body
		"RigidBody2D":
			var body = RigidBody2D.new()
			body.name = _unique_name("RigidBody2D", _scene_root)
			var shape = CollisionShape2D.new()
			shape.name = "CollisionShape2D"
			var rect_shape = RectangleShape2D.new()
			rect_shape.size = Vector2(32, 32)
			shape.shape = rect_shape
			body.add_child(shape)
			node = body
		"StaticBody2D":
			var body = StaticBody2D.new()
			body.name = _unique_name("StaticBody2D", _scene_root)
			var shape = CollisionShape2D.new()
			shape.name = "CollisionShape2D"
			var rect_shape = RectangleShape2D.new()
			rect_shape.size = Vector2(64, 16)
			shape.shape = rect_shape
			body.add_child(shape)
			node = body
		"Area2D":
			var area = Area2D.new()
			area.name = _unique_name("Area2D", _scene_root)
			var shape = CollisionShape2D.new()
			shape.name = "CollisionShape2D"
			var rect_shape = RectangleShape2D.new()
			rect_shape.size = Vector2(32, 32)
			shape.shape = rect_shape
			area.add_child(shape)
			node = area
		"CollisionShape2D":
			node = CollisionShape2D.new()
			node.name = _unique_name("CollisionShape2D", _scene_root)
			var rect_shape = RectangleShape2D.new()
			rect_shape.size = Vector2(32, 32)
			node.shape = rect_shape
		"CollisionPolygon2D":
			node = CollisionPolygon2D.new()
			node.name = _unique_name("CollisionPolygon2D", _scene_root)
		"TileMapLayer":
			node = TileMapLayer.new()
			node.name = _unique_name("TileMapLayer", _scene_root)
		"ParallaxBackground":
			var bg = ParallaxBackground.new()
			bg.name = _unique_name("ParallaxBG", _scene_root)
			node = bg
		"ParallaxLayer":
			var layer = ParallaxLayer.new()
			layer.name = _unique_name("ParallaxLayer", _scene_root)
			node = layer
		"Path2D":
			var path = Path2D.new()
			path.name = _unique_name("Path2D", _scene_root)
			path.curve = Curve2D.new()
			path.curve.add_point(Vector2.ZERO)
			path.curve.add_point(Vector2(100, 0))
			path.curve.add_point(Vector2(100, 100))
			node = path
		"PathFollow2D":
			node = PathFollow2D.new()
			node.name = _unique_name("PathFollow2D", _scene_root)
		"PointLight2D":
			node = PointLight2D.new()
			node.name = _unique_name("PointLight2D", _scene_root)
		"DirectionalLight2D":
			node = DirectionalLight2D.new()
			node.name = _unique_name("DirLight2D", _scene_root)
		"AudioStreamPlayer2D":
			node = AudioStreamPlayer2D.new()
			node.name = _unique_name("Audio2D", _scene_root)
		"NavigationRegion2D":
			node = NavigationRegion2D.new()
			node.name = _unique_name("NavRegion2D", _scene_root)
		"RayCast2D":
			node = RayCast2D.new()
			node.name = _unique_name("RayCast2D", _scene_root)
		"Marker2D":
			node = Marker2D.new()
			node.name = _unique_name("Marker2D", _scene_root)
		"ColorRect":
			# ColorRect is a Control node - needs CanvasLayer parent with Node2D root
			# Since _scene_root is typed as Node2D, always prompt to add CanvasLayer
			_prompt_add_canvas_layer_for_control("ColorRect")
			return
		"Line2D":
			var line = Line2D.new()
			line.name = _unique_name("Line2D", _scene_root)
			line.points = PackedVector2Array([Vector2.ZERO, Vector2(100, 0)])
			line.width = 4.0
			line.default_color = Color(1, 1, 1)
			node = line
		"Polygon2D":
			var poly = Polygon2D.new()
			poly.name = _unique_name("Polygon2D", _scene_root)
			poly.polygon = PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)])
			poly.color = Color(0.6, 0.3, 0.8)
			node = poly
		"Node2D":
			node = Node2D.new()
			node.name = _unique_name("Node2D", _scene_root)
		"VisibleOnScreenNotifier2D":
			node = VisibleOnScreenNotifier2D.new()
			node.name = _unique_name("VisNotifier2D", _scene_root)
		"GPUParticles2D":
			node = GPUParticles2D.new()
			node.name = _unique_name("GPUParticles2D", _scene_root)
		"CPUParticles2D":
			var p = CPUParticles2D.new()
			p.name = _unique_name("CPUParticles2D", _scene_root)
			p.emitting = false
			node = p
		_:
			push_warning("VG 2D Editor: Unknown type: " + type_name)
			return

	if node:
		# Place at camera center (current view center)
		node.position = _cam_offset
		if _snap_enabled:
			node.position = Vector2(snappedf(node.position.x, _snap_value), snappedf(node.position.y, _snap_value))

		_scene_root.add_child(node)
		_push_undo({"type": "add", "nodes": [{"node": node, "name": node.name}]})
		_select_node(node)
		_rebuild_scene_tree()
		_scene_dirty = true
		print("VG 2D Editor: Added ", display_name, " → ", node.name)

# ─────────────────────────────────────────────────────────────────────────────
# SMART CANVASLAYER INSERTION FOR CONTROL NODES
# ─────────────────────────────────────────────────────────────────────────────
func _prompt_add_canvas_layer_for_control(control_type_name: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "CanvasLayer Required"
	dialog.dialog_text = control_type_name + " is a UI Control node and needs a CanvasLayer parent when added to a Node2D scene.\n\nAdd CanvasLayer automatically?"
	dialog.ok_button_text = "Yes, Add CanvasLayer"
	dialog.add_cancel_button("No, Cancel")
	
	# Style the dialog
	_style_dialog_dark(dialog)
	
	dialog.confirmed.connect(func():
		# Create CanvasLayer first
		var canvas_layer = CanvasLayer.new()
		canvas_layer.name = _unique_name("CanvasLayer", _scene_root)
		canvas_layer.position = _cam_offset
		if _snap_enabled:
			canvas_layer.position = Vector2(snappedf(canvas_layer.position.x, _snap_value), snappedf(canvas_layer.position.y, _snap_value))
		
		_scene_root.add_child(canvas_layer)
		_push_undo({"type": "add", "nodes": [{"node": canvas_layer, "name": canvas_layer.name}]})
		print("VG 2D Editor: Added CanvasLayer → ", canvas_layer.name)
		
		# Now create the Control node as child of CanvasLayer
		var control_node: Control = null
		match control_type_name:
			"ColorRect":
				var cr = ColorRect.new()
				cr.name = _unique_name("ColorRect", canvas_layer)
				cr.size = Vector2(64, 64)
				cr.color = Color(0.5, 0.5, 0.8, 1.0)
				control_node = cr
		
		if control_node:
			canvas_layer.add_child(control_node)
			_push_undo({"type": "add", "nodes": [{"node": control_node, "name": control_node.name}]})
			_select_node(control_node)
			print("VG 2D Editor: Added ", control_type_name, " → ", control_node.name)
		
		_rebuild_scene_tree()
		_scene_dirty = true
		dialog.queue_free()
	)
	
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	
	add_child(dialog)
	dialog.popup_centered()

# ─────────────────────────────────────────────────────────────────────────────
# INSTANCE CHILD SCENE
# ─────────────────────────────────────────────────────────────────────────────
var _instance_file_dialog: FileDialog = null

func _on_instance_scene_pressed() -> void:
	if _instance_file_dialog:
		_instance_file_dialog.queue_free()
	_instance_file_dialog = FileDialog.new()
	_instance_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_instance_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_instance_file_dialog.filters = PackedStringArray(["*.tscn,*.scn;Godot Scene"])
	_instance_file_dialog.title = "Instance Child Scene"
	_instance_file_dialog.size = Vector2i(600, 400)
	_style_dialog_dark(_instance_file_dialog)
	_instance_file_dialog.file_selected.connect(func(path):
		_instance_scene_from_path(path)
		_instance_file_dialog.queue_free()
		_instance_file_dialog = null
	)
	add_child(_instance_file_dialog)
	_instance_file_dialog.popup_centered()

func _instance_scene_from_path(path: String) -> void:
	# Refuse to instance the scene we're currently editing — would recurse.
	if path == _loaded_scene_path:
		push_warning("VG 2D Editor: cannot instance the currently-open scene into itself.")
		return
	var res := ResourceLoader.load(path)
	if not (res is PackedScene):
		push_warning("VG 2D Editor: not a PackedScene: " + path)
		return
	var inst: Node = (res as PackedScene).instantiate()
	if inst == null:
		push_warning("VG 2D Editor: failed to instantiate: " + path)
		return
	# Attach under selected Node2D if any, else under scene root.
	var parent: Node = _scene_root
	if is_instance_valid(_primary_selected) and _primary_selected is Node:
		parent = _primary_selected
	# Position at view center if the instance root is a Node2D.
	if inst is Node2D and parent == _scene_root:
		var pos := _cam_offset
		if _snap_enabled:
			pos = Vector2(snappedf(pos.x, _snap_value), snappedf(pos.y, _snap_value))
		(inst as Node2D).position = pos
	# Give it a unique name based on the scene file.
	var base := path.get_file().get_basename()
	inst.name = _unique_name(base, parent)
	parent.add_child(inst)
	# scene_file_path is set automatically by instantiate(); preserve it.
	_push_undo({"type": "add", "nodes": [{"node": inst, "name": inst.name}]})
	# _select_node only handles CanvasItem; skip selection for non-CanvasItem
	# instance roots (rare in 2D scenes, but possible — e.g. a pure Node root).
	if inst is CanvasItem:
		_select_node(inst)
	_rebuild_scene_tree()
	_scene_dirty = true
	print("VG 2D Editor: Instanced → ", path, " as ", inst.name)

# ─────────────────────────────────────────────────────────────────────────────
# DRAG-DROP REPARENT (scene tree)
# ─────────────────────────────────────────────────────────────────────────────
func _tree_get_drag_data(_at: Vector2):
	var sel := _scene_tree.get_selected()
	if sel == null:
		return null
	var node = sel.get_metadata(0)
	if node == null or node == _scene_root:
		return null  # don't allow dragging the root
	# Build a small drag preview label.
	var preview := Label.new()
	preview.text = "↪ " + str(node.name)
	preview.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	_scene_tree.set_drag_preview(preview)
	return {"type": "vg_scene_node", "node": node}

func _tree_can_drop_data(_at: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY or data.get("type", "") != "vg_scene_node":
		return false
	var src: Node = data.get("node", null)
	if not is_instance_valid(src):
		return false
	var target_item := _scene_tree.get_item_at_position(_at)
	if target_item == null:
		return false
	var target_node = target_item.get_metadata(0)
	if target_node == null:
		# Dropping onto the "Scene" root item — allowed (reparent to _scene_root).
		return src.get_parent() != _scene_root or _scene_tree.get_drop_section_at_position(_at) != 0
	if not is_instance_valid(target_node):
		return false
	# Disallow dropping a node onto itself or any of its descendants.
	if target_node == src or _node_is_descendant_of(target_node, src):
		return false
	return true

func _node_is_descendant_of(node: Node, ancestor: Node) -> bool:
	var p := node.get_parent()
	while p != null:
		if p == ancestor:
			return true
		p = p.get_parent()
	return false

func _tree_drop_data(_at: Vector2, data) -> void:
	if typeof(data) != TYPE_DICTIONARY or data.get("type", "") != "vg_scene_node":
		return
	var src: Node = data.get("node", null)
	if not is_instance_valid(src):
		return
	var target_item := _scene_tree.get_item_at_position(_at)
	if target_item == null:
		return
	var target_node = target_item.get_metadata(0)
	var section := _scene_tree.get_drop_section_at_position(_at)  # -1=before, 0=on, +1=after
	# Resolve new parent + index.
	var new_parent: Node
	var new_index: int = -1
	if target_node == null:
		# Dropped on the "Scene" root row.
		new_parent = _scene_root
	elif section == 0:
		# Drop ONTO the item → make it a child (append at end).
		new_parent = target_node
	else:
		# Drop BETWEEN — sibling of target_node.
		new_parent = target_node.get_parent()
		if new_parent == null:
			return
		new_index = target_node.get_index()
		if section > 0:
			new_index += 1
	# Preserve world transform if both are Node2D.
	var src_was_n2d := src is Node2D
	var preserved_xform: Transform2D
	if src_was_n2d:
		preserved_xform = (src as Node2D).global_transform
	# Reparent.
	var old_parent := src.get_parent()
	if old_parent == new_parent and new_index == src.get_index():
		return  # no-op
	if old_parent != null:
		old_parent.remove_child(src)
	if new_index >= 0:
		new_parent.add_child(src)
		new_parent.move_child(src, min(new_index, new_parent.get_child_count() - 1))
	else:
		new_parent.add_child(src)
	# Restore world transform.
	if src_was_n2d and new_parent is Node2D:
		(src as Node2D).global_transform = preserved_xform
	# Re-uniquify name if a sibling collides.
	var base_name := str(src.name)
	if _name_collides(new_parent, src):
		src.name = _unique_name(base_name, new_parent)
	_scene_dirty = true
	_rebuild_scene_tree()
	if src is CanvasItem:
		_select_node(src)
	print("VG 2D Editor: reparented ", base_name, " → ", new_parent.name)

func _name_collides(parent: Node, exclude: Node) -> bool:
	for child in parent.get_children():
		if child != exclude and child.name == exclude.name:
			return true
	return false

# ─────────────────────────────────────────────────────────────────────────────
# CHANGE TYPE
# ─────────────────────────────────────────────────────────────────────────────
const _CHANGE_TYPE_CANDIDATES: Array = [
	"Node2D", "Sprite2D", "AnimatedSprite2D", "Area2D",
	"StaticBody2D", "RigidBody2D", "CharacterBody2D",
	"Camera2D", "Path2D", "PathFollow2D", "Marker2D",
]
var _change_type_dialog: AcceptDialog = null

func _on_change_type_pressed() -> void:
	if not is_instance_valid(_primary_selected):
		push_warning("VG 2D Editor: select a node first.")
		return
	if _primary_selected == _scene_root:
		push_warning("VG 2D Editor: cannot change type of the scene root.")
		return
	if _change_type_dialog:
		_change_type_dialog.queue_free()
	_change_type_dialog = AcceptDialog.new()
	_change_type_dialog.title = "Change Type — " + str(_primary_selected.name) + " (" + _primary_selected.get_class() + ")"
	_change_type_dialog.size = Vector2i(360, 420)
	_style_dialog_dark(_change_type_dialog)
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(320, 320)
	list.auto_height = false
	var current_cls := _primary_selected.get_class()
	for cls in _CHANGE_TYPE_CANDIDATES:
		if cls == current_cls:
			continue
		list.add_item(cls)
	_change_type_dialog.add_child(list)
	_change_type_dialog.get_ok_button().text = "Convert"
	var target_node: Node = _primary_selected
	_change_type_dialog.confirmed.connect(func():
		var sel_ids := list.get_selected_items()
		if sel_ids.is_empty():
			return
		var new_cls := list.get_item_text(sel_ids[0])
		_apply_change_type(target_node, new_cls)
		_change_type_dialog.queue_free()
		_change_type_dialog = null
	)
	_change_type_dialog.canceled.connect(func():
		_change_type_dialog.queue_free()
		_change_type_dialog = null
	)
	add_child(_change_type_dialog)
	_change_type_dialog.popup_centered()

func _apply_change_type(old_node: Node, new_class: String) -> void:
	if not ClassDB.class_exists(new_class) or not ClassDB.can_instantiate(new_class):
		push_warning("VG 2D Editor: cannot instantiate " + new_class)
		return
	var new_node = ClassDB.instantiate(new_class)
	if new_node == null:
		push_warning("VG 2D Editor: instantiate returned null for " + new_class)
		return
	# Copy common Node2D / CanvasItem properties when both sides support them.
	new_node.name = old_node.name + "_tmp"
	var copy_props := [
		"position", "rotation", "scale", "skew",  # Node2D
		"visible", "modulate", "self_modulate", "z_index", "z_as_relative",  # CanvasItem
	]
	for p in copy_props:
		if p in old_node and p in new_node:
			new_node.set(p, old_node.get(p))
	# Re-parent children.
	var children := old_node.get_children().duplicate()
	for c in children:
		old_node.remove_child(c)
		new_node.add_child(c)
	# Insert into the same parent at the same index.
	var parent := old_node.get_parent()
	var idx := old_node.get_index()
	var final_name := str(old_node.name)
	parent.remove_child(old_node)
	old_node.queue_free()
	parent.add_child(new_node)
	parent.move_child(new_node, idx)
	new_node.name = final_name
	_scene_dirty = true
	_rebuild_scene_tree()
	if new_node is CanvasItem:
		_select_node(new_node)
	print("VG 2D Editor: changed type → ", new_class, " (", final_name, ")")

# ─────────────────────────────────────────────────────────────────────────────
# IMPORT TEXTURE
# ─────────────────────────────────────────────────────────────────────────────
func _on_import_texture_pressed() -> void:
	if not _primary_selected or not is_instance_valid(_primary_selected):
		push_warning("VG 2D Editor: Select a Sprite2D first")
		return
	if not (_primary_selected is Sprite2D):
		push_warning("VG 2D Editor: Selected node is not a Sprite2D")
		return

	if _import_file_dialog:
		_import_file_dialog.queue_free()

	_import_file_dialog = FileDialog.new()
	_import_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_import_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_import_file_dialog.filters = PackedStringArray(["*.png;PNG Images", "*.jpg;JPEG Images", "*.svg;SVG Images", "*.webp;WebP Images", "*.tres;Godot Resources"])
	_import_file_dialog.title = "Load Texture"
	_import_file_dialog.size = Vector2i(600, 400)
	_style_dialog_dark(_import_file_dialog)

	var target = _primary_selected
	_import_file_dialog.file_selected.connect(func(path):
		if is_instance_valid(target) and target is Sprite2D:
			var tex = load(path)
			if tex is Texture2D:
				target.texture = tex
				_overlay.queue_redraw()
				_scene_dirty = true
				print("VG 2D Editor: Loaded texture → ", path)
			else:
				push_warning("VG 2D Editor: Could not load texture: " + path)
		_import_file_dialog.queue_free()
		_import_file_dialog = null
	)

	add_child(_import_file_dialog)
	_import_file_dialog.popup_centered()

# ─────────────────────────────────────────────────────────────────────────────
# SCENE TREE UI
# ─────────────────────────────────────────────────────────────────────────────
func _rebuild_scene_tree() -> void:
	if not is_instance_valid(_scene_tree):
		return
	_scene_tree.clear()

	var root_item = _scene_tree.create_item()
	root_item.set_text(0, "Scene" if _loaded_scene_path.is_empty() else _loaded_scene_path.get_file().get_basename())
	root_item.set_metadata(0, null)

	if is_instance_valid(_scene_root):
		_add_tree_children(_scene_root, root_item)

	# Auto-expand so the user can see children without hunting for the
	# disclosure triangle in a small pane.
	root_item.set_collapsed_recursive(false)

func _add_tree_children(parent: Node, tree_item: TreeItem) -> void:
	for child in parent.get_children():
		if child.name in ["EditorCamera", "EditorBackground", "SceneRoot", "EditorOverlay"]:
			# Skip internal nodes — but recurse into SceneRoot
			if child == _scene_root:
				_add_tree_children(child, tree_item)
			continue

		var item = _scene_tree.create_item(tree_item)
		var vis = "👁️ " if child.is_visible() else "🚫 " if child is CanvasItem else ""
		var type_hint = child.get_class()
		item.set_text(0, vis + child.name + "  (" + type_hint + ")")
		item.set_metadata(0, child)

		# Highlight selected
		if child in _selected_nodes:
			item.set_custom_color(0, SELECTION_COLOR)

		# Recurse
		_add_tree_children(child, item)

func _on_scene_tree_selected() -> void:
	var sel = _scene_tree.get_selected()
	if sel and sel.get_metadata(0) is Node2D:
		_select_node(sel.get_metadata(0))
		_viewport_container.grab_focus()

func _on_scene_tree_double_clicked() -> void:
	var sel = _scene_tree.get_selected()
	if sel and sel.get_metadata(0) is Node2D:
		node_double_clicked.emit(sel.get_metadata(0))

func _on_scene_tree_rmb(_pos: Vector2, _mouse_btn: int) -> void:
	var sel = _scene_tree.get_selected()
	if sel and sel.get_metadata(0) is Node2D:
		_select_node(sel.get_metadata(0))
	_show_tree_context_menu(_scene_tree.get_global_mouse_position())

func _update_scene_tree_selection() -> void:
	# Walk tree items and update highlighting
	var root_item = _scene_tree.get_root()
	if root_item:
		_update_tree_item_selection(root_item)

func _update_tree_item_selection(item: TreeItem) -> void:
	var node = item.get_metadata(0)
	if node is Node2D:
		if node in _selected_nodes:
			item.set_custom_color(0, SELECTION_COLOR)
		else:
			item.clear_custom_color(0)
	for child_item in item.get_children():
		_update_tree_item_selection(child_item)

# ─────────────────────────────────────────────────────────────────────────────
# CONTEXT MENUS — custom dark panel-based (no native PopupMenu windows)
# ─────────────────────────────────────────────────────────────────────────────
func _build_context_menus() -> void:
	pass  # Menus are built inline at show time

func _dismiss_popup() -> void:
	if is_instance_valid(_popup_backdrop):
		_popup_backdrop.queue_free()
		_popup_backdrop = null

func _show_dark_popup_menu(items: Array, callback: Callable) -> void:
	_dismiss_popup()

	# Full-screen transparent backdrop to catch outside clicks
	_popup_backdrop = Control.new()
	_popup_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup_backdrop.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			_dismiss_popup()
	)

	# Dark menu panel
	var panel = PanelContainer.new()
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.16, 0.16, 0.20)
	panel_sb.set_border_width_all(1)
	panel_sb.border_color = Color(0.35, 0.38, 0.50)
	panel_sb.set_corner_radius_all(6)
	panel_sb.set_content_margin_all(6)
	panel_sb.shadow_color = Color(0, 0, 0, 0.35)
	panel_sb.shadow_size = 6
	panel_sb.shadow_offset = Vector2(2, 2)
	panel.add_theme_stylebox_override("panel", panel_sb)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	panel.add_child(vbox)

	for item in items:
		if item.has("separator") and item.separator:
			var sep = HSeparator.new()
			var sep_sb = StyleBoxFlat.new()
			sep_sb.bg_color = Color(0.28, 0.28, 0.35)
			sep_sb.content_margin_top = 3
			sep_sb.content_margin_bottom = 3
			sep_sb.content_margin_left = 4
			sep_sb.content_margin_right = 4
			sep.add_theme_stylebox_override("separator", sep_sb)
			vbox.add_child(sep)
		else:
			var btn = Button.new()
			btn.text = "  " + item.text
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
			btn.add_theme_color_override("font_hover_color", Color.WHITE)
			btn.add_theme_font_size_override("font_size", 13)
			btn.custom_minimum_size = Vector2(210, 26)
			var btn_normal = StyleBoxFlat.new()
			btn_normal.bg_color = Color(0.16, 0.16, 0.20)
			btn_normal.set_content_margin_all(3)
			btn_normal.content_margin_left = 6
			btn_normal.content_margin_right = 6
			btn.add_theme_stylebox_override("normal", btn_normal)
			var btn_hover = StyleBoxFlat.new()
			btn_hover.bg_color = Color(0.24, 0.36, 0.58)
			btn_hover.set_corner_radius_all(3)
			btn_hover.set_content_margin_all(3)
			btn_hover.content_margin_left = 6
			btn_hover.content_margin_right = 6
			btn.add_theme_stylebox_override("hover", btn_hover)
			var btn_pressed = btn_hover.duplicate()
			btn_pressed.bg_color = Color(0.20, 0.30, 0.48)
			btn.add_theme_stylebox_override("pressed", btn_pressed)
			var btn_focus = StyleBoxEmpty.new()
			btn.add_theme_stylebox_override("focus", btn_focus)
			var item_id = item.id
			btn.pressed.connect(func():
				callback.call(item_id)
				_dismiss_popup()
			)
			vbox.add_child(btn)

	_popup_backdrop.add_child(panel)
	get_tree().root.add_child(_popup_backdrop)

	# Position at mouse cursor within the root window
	var mouse_pos = get_viewport().get_mouse_position()
	panel.position = mouse_pos

	# Clamp to screen on the next frame once size is known
	panel.resized.connect(func():
		var win_size = get_tree().root.size
		if panel.position.x + panel.size.x > win_size.x - 8:
			panel.position.x = win_size.x - panel.size.x - 8
		if panel.position.y + panel.size.y > win_size.y - 8:
			panel.position.y = win_size.y - panel.size.y - 8
	, CONNECT_ONE_SHOT)

func _show_context_menu(_screen_pos: Vector2) -> void:
	var items = [
		{"text": "View Code", "id": 0},
		{"separator": true},
		{"text": "Duplicate    Ctrl+D", "id": 1},
		{"text": "Delete         Del", "id": 2},
		{"text": "Focus            F", "id": 3},
		{"text": "Reset Transform", "id": 4},
		{"text": "Toggle Visibility", "id": 5},
		{"separator": true},
		{"text": "Rename        F2", "id": 6},
		{"separator": true},
		{"text": "Copy       Ctrl+C", "id": 7},
		{"text": "Paste      Ctrl+V", "id": 8},
		{"separator": true},
		{"text": "Select All Ctrl+A", "id": 9},
	]
	_show_dark_popup_menu(items, _on_context_menu_item)

func _show_tree_context_menu(_screen_pos: Vector2) -> void:
	var items = [
		{"text": "View Code", "id": 0},
		{"separator": true},
		{"text": "Rename", "id": 1},
		{"text": "Duplicate", "id": 2},
		{"text": "Delete", "id": 3},
		{"text": "Toggle Visibility", "id": 4},
		{"text": "Reset Transform", "id": 5},
		{"separator": true},
		{"text": "Instance Child Scene…", "id": 6},
		{"text": "Change Type…", "id": 7},
	]
	_show_dark_popup_menu(items, _on_tree_context_menu_item)

func _on_context_menu_item(id: int) -> void:
	match id:
		0:
			if _primary_selected:
				view_code_requested.emit(_primary_selected)
		1: _duplicate_selected()
		2: _delete_selected()
		3: _focus_selected()
		4: _reset_transform_selected()
		5: _toggle_visibility_selected()
		6: _rename_selected()
		7: _copy_selected()
		8: _paste()
		9: _select_all()

func _on_tree_context_menu_item(id: int) -> void:
	match id:
		0:
			if _primary_selected:
				view_code_requested.emit(_primary_selected)
		1: _rename_selected()
		2: _duplicate_selected()
		3: _delete_selected()
		4: _toggle_visibility_selected()
		5: _reset_transform_selected()
		6: _on_instance_scene_pressed()
		7: _on_change_type_pressed()

# ─────────────────────────────────────────────────────────────────────────────
# UNDO / REDO
# ─────────────────────────────────────────────────────────────────────────────
func _push_undo(action: Dictionary) -> void:
	_undo_stack.push_back(action)
	if _undo_stack.size() > MAX_UNDO:
		_undo_stack.pop_front()
	_redo_stack.clear()

func _undo() -> void:
	if _undo_stack.is_empty():
		return

	var action = _undo_stack.pop_back()
	match action.type:
		"transform":
			var befores: Array = action.before
			for entry in befores:
				var n = entry.node
				if is_instance_valid(n):
					n.position = entry.position
					n.rotation = entry.rotation
					n.scale = entry.scale
		"add":
			for entry in action.nodes:
				var n = entry.node
				if is_instance_valid(n):
					n.get_parent().remove_child(n)
					n.queue_free()
		"delete":
			for entry in action.nodes:
				var dup = entry.node_dup.duplicate()
				var parent = entry.parent
				if is_instance_valid(parent):
					parent.add_child(dup)
					dup.name = entry.name
		"shape_resize":
			var n = action.node
			if is_instance_valid(n) and n.shape:
				if n.shape is RectangleShape2D and action.has("before_size"):
					n.shape.size = action.before_size
				elif n.shape is CircleShape2D and action.has("before_radius"):
					n.shape.radius = action.before_radius
				elif n.shape is CapsuleShape2D and action.has("before_size"):
					n.shape.radius = action.before_size.x
					n.shape.height = action.before_size.y

	_redo_stack.push_back(action)
	_rebuild_scene_tree()
	_update_transform_panel()
	_overlay.queue_redraw()

func _redo() -> void:
	if _redo_stack.is_empty():
		return

	var action = _redo_stack.pop_back()
	match action.type:
		"transform":
			var afters: Array = action.after
			for entry in afters:
				var n = entry.node
				if is_instance_valid(n):
					n.position = entry.position
					n.rotation = entry.rotation
					n.scale = entry.scale
		"add":
			for entry in action.nodes:
				var n = entry.node
				if is_instance_valid(n):
					_scene_root.add_child(n)
		"delete":
			for entry in action.nodes:
				var n = entry.node_dup
				if is_instance_valid(n) and is_instance_valid(n.get_parent()):
					n.get_parent().remove_child(n)
					n.queue_free()
		"shape_resize":
			var n = action.node
			if is_instance_valid(n) and n.shape:
				if n.shape is RectangleShape2D and action.has("after_size"):
					n.shape.size = action.after_size
				elif n.shape is CircleShape2D and action.has("after_radius"):
					n.shape.radius = action.after_radius
				elif n.shape is CapsuleShape2D and action.has("after_size"):
					n.shape.radius = action.after_size.x
					n.shape.height = action.after_size.y

	_undo_stack.push_back(action)
	_rebuild_scene_tree()
	_update_transform_panel()
	_overlay.queue_redraw()

# ─────────────────────────────────────────────────────────────────────────────
# SCENE LOAD / SAVE
# ─────────────────────────────────────────────────────────────────────────────

## Ensure the SubViewport, Camera, and SceneRoot exist.
## Called defensively from load_scene() in case _ready() / _build_ui()
## did not complete (e.g. a silent error in the long _build_ui chain).
func _ensure_scene_ready() -> void:
	if _scene_root != null:
		return
	push_warning("[VG2D] _scene_root was null — late-initializing viewport + scene")
	if _viewport == null:
		if _viewport_container == null:
			_viewport_container = SubViewportContainer.new()
			_viewport_container.stretch = true
			_viewport_container.size_flags_horizontal = SIZE_EXPAND_FILL
			_viewport_container.size_flags_vertical = SIZE_EXPAND_FILL
			add_child(_viewport_container)
		_viewport = SubViewport.new()
		_viewport.size = Vector2i(1024, 768)
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_viewport.transparent_bg = false
		_viewport_container.add_child(_viewport)
	_build_2d_scene()

## Load a .tscn scene into the 2D editor viewport.
## We parse the .tscn text first to strip VisualGasicScript references
## so the C++ VG runtime never initialises inside the editor.
func load_scene(path: String) -> void:
	if path.is_empty():
		return

	# Defensive: ensure the viewport/scene root exist
	_ensure_scene_ready()

	# Clear existing scene
	for child in _scene_root.get_children():
		_scene_root.remove_child(child)
		child.queue_free()

	_selected_nodes.clear()
	_primary_selected = null
	_undo_stack.clear()
	_redo_stack.clear()

	# --- Strip VG scripts from the .tscn text before loading -----------
	print("[VG2D] load_scene: stripping VG scripts from: ", path)
	var clean_path := _create_clean_scene_copy(path)
	if clean_path.is_empty():
		push_warning("VG 2D Editor: Failed to create script-free copy of: " + path)
		return

	print("[VG2D] load_scene: loading cleaned scene from: ", clean_path)
	var packed = ResourceLoader.load(clean_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	print("[VG2D] load_scene: ResourceLoader returned: ", packed)

	# Delete the temp file (and any .uid sidecar) after loading
	if FileAccess.file_exists(clean_path):
		DirAccess.remove_absolute(clean_path)
	var uid_sidecar: String = clean_path + ".uid"
	if FileAccess.file_exists(uid_sidecar):
		DirAccess.remove_absolute(uid_sidecar)

	if packed is PackedScene:
		var instance = packed.instantiate()
		print("[VG2D] load_scene: instantiate returned: ", instance)
		if instance:
			print("[VG2D] load_scene: instance type=", instance.get_class(), "  children=", instance.get_child_count())
			# Move all children into our scene root.
			# CanvasLayer nodes are special — they create a separate rendering
			# layer that breaks coordinate systems in our SubViewport editor.
			# Flatten them: replace each CanvasLayer with a Control sized to
			# the viewport so anchor-based children resolve correctly.
			# Direct Control children of the root also need a Control parent
			# for anchors to work (Node2D parents can't resolve anchors).
			var vp_size := Vector2(_viewport.size)
			var children_to_move: Array = []
			for child in instance.get_children():
				children_to_move.append(child)
			for child in children_to_move:
				child.owner = null
				instance.remove_child(child)
				if child is CanvasLayer:
					# Replace CanvasLayer with a Control container sized to viewport
					var placeholder := Control.new()
					placeholder.name = child.name
					placeholder.size = vp_size
					placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
					_scene_root.add_child(placeholder)
					# Reparent all CanvasLayer children into the placeholder
					var layer_children: Array = []
					for lc in child.get_children():
						layer_children.append(lc)
					for lc in layer_children:
						lc.owner = null
						child.remove_child(lc)
						placeholder.add_child(lc)
					child.queue_free()
					print("[VG2D] Flattened CanvasLayer '", placeholder.name, "' → Control(", vp_size, ") with ", placeholder.get_child_count(), " children")
				elif child is Control:
					# Control nodes need a Control parent for anchors to work.
					# Wrap in a viewport-sized Control if there isn't one yet.
					var wrapper := Control.new()
					wrapper.name = child.name + "_Wrapper"
					wrapper.size = vp_size
					wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
					_scene_root.add_child(wrapper)
					wrapper.add_child(child)
					print("[VG2D] Wrapped Control '", child.name, "' in viewport-sized parent")
				else:
					_scene_root.add_child(child)
			instance.queue_free()

			# Strip shader materials so textures render properly in preview
			_strip_shader_materials(_scene_root)
			_loaded_scene_path = path  # store the REAL path, not the temp
			_scene_dirty = false
			_rebuild_scene_tree()
			_update_status()
			if is_instance_valid(_overlay):
				_overlay.queue_redraw()
			# Center and zoom to fit the entire scene
			_fit_scene_in_view()
			print("[VG2D] Loaded scene: ", path, "  nodes in _scene_root: ", _scene_root.get_child_count())
		else:
			push_warning("VG 2D Editor: Could not instantiate scene: " + path)
	else:
		push_warning("VG 2D Editor: Could not load: " + path + "  (ResourceLoader returned: " + str(packed) + ")")

## Create a temporary copy of a .tscn with all VisualGasicScript /
## .vg ext_resource entries and their script= assignments removed.
## Also strips the uid= from the header so ResourceLoader won't
## redirect back to the original (cached) scene.
## Returns the temp file path, or "" on failure.
static func _create_clean_scene_copy(original_path: String) -> String:
	var text := FileAccess.get_file_as_string(original_path)
	if text.is_empty():
		push_warning("[VG] _create_clean_scene_copy: could not read " + original_path)
		return ""

	# Collect ext_resource IDs that point to .vg files
	var vg_ids: Array[String] = []
	var lines := text.split("\n")
	var clean_lines: PackedStringArray = PackedStringArray()

	for line in lines:
		var stripped := line.strip_edges()

		# --- Strip uid= from [gd_scene ...] header so Godot can't
		#     redirect to the original cached resource via UID lookup.
		if stripped.begins_with("[gd_scene"):
			var uid_start := stripped.find(' uid="')
			if uid_start != -1:
				var uid_end := stripped.find('"', uid_start + 6)  # after uid="
				if uid_end != -1:
					stripped = stripped.substr(0, uid_start) + stripped.substr(uid_end + 1)
			clean_lines.append(stripped)
			continue

		# Match:  [ext_resource type="VisualGasicScript" path="..." id="1"]
		#     or  [ext_resource ... path="res://foo.vg" ...]
		if stripped.begins_with("[ext_resource") and (".vg" in stripped or "VisualGasicScript" in stripped):
			# Extract the id value (id="...").
			# Use rfind to avoid matching inside uid="uid://..." which also
			# contains the substring 'id="'.
			var id_pos := stripped.rfind(' id="')
			if id_pos != -1:
				var id_start := id_pos + 5  # len(' id="')
				var id_end := stripped.find('"', id_start)
				if id_end != -1:
					vg_ids.append(stripped.substr(id_start, id_end - id_start))
			continue  # skip this ext_resource line entirely

		# Skip any  script = ExtResource("<vg_id>")  assignments
		if stripped.begins_with("script") and "ExtResource" in stripped:
			var skip := false
			for vid in vg_ids:
				if ('"' + vid + '"') in stripped:
					skip = true
					break
			if skip:
				continue

		clean_lines.append(line)

	# Also fix load_steps count (one fewer per stripped ext_resource)
	var result := "\n".join(clean_lines)
	if vg_ids.size() > 0:
		# Decrement load_steps in the header
		var ls_pos := result.find("load_steps=")
		if ls_pos != -1:
			var num_start := ls_pos + 11  # length of "load_steps="
			var num_end := num_start
			while num_end < result.length() and result[num_end].is_valid_int():
				num_end += 1
			if num_end > num_start:
				var old_val := result.substr(num_start, num_end - num_start).to_int()
				var new_val := max(old_val - vg_ids.size(), 1)
				result = result.substr(0, num_start) + str(new_val) + result.substr(num_end)

	# Write temp file next to the original so relative sub-resource paths resolve
	var dir := original_path.get_base_dir()
	var temp_name := "_vg_editor_temp_scene.tscn"
	var temp_path := dir.path_join(temp_name)
	var f := FileAccess.open(temp_path, FileAccess.WRITE)
	if f == null:
		push_warning("[VG] _create_clean_scene_copy: could not write " + temp_path)
		return ""
	f.store_string(result)
	f.flush()
	f.close()
	print("[VG] Created clean scene copy: ", temp_path, "  (stripped ", vg_ids.size(), " VG script refs)")
	return temp_path

func _save_scene() -> void:
	if _loaded_scene_path.is_empty():
		save_scene_as()
		return

	var packed = PackedScene.new()
	# Create a temporary root to pack
	var temp_root = Node2D.new()
	temp_root.name = _loaded_scene_path.get_file().get_basename()

	# Duplicate children into temp root. Pass DUPLICATE_USE_INSTANTIATION
	# (flag 8) so any child that was added via PackedScene.instantiate() keeps
	# its scene_file_path on the duplicate — otherwise PackedScene.pack() below
	# would flatten the instance and the .tscn would lose its [instance=...]
	# reference.
	var dup_flags := 1 | 2 | 4 | 8  # signals|groups|scripts|use_instantiation
	for child in _scene_root.get_children():
		var dup = child.duplicate(dup_flags)
		temp_root.add_child(dup)
		dup.owner = temp_root

	# Recursively set owner so deep descendants are packed too. Stop at
	# instance boundaries: nodes inside an instanced scene must stay owned
	# by that instance's root or the saver will serialise every internal
	# child as an "editable override", bloating the scene and breaking the
	# instance link.
	_set_owner_for_save(temp_root, temp_root)

	var err = packed.pack(temp_root)
	temp_root.queue_free()

	if err != OK:
		push_warning("VG 2D Editor: Failed to pack scene: " + str(err))
		return

	err = ResourceSaver.save(packed, _loaded_scene_path)
	if err != OK:
		push_warning("VG 2D Editor: Failed to save: " + str(err))
		return

	_scene_dirty = false
	_update_status()
	scene_saved.emit(_loaded_scene_path)
	# Announce on the process-wide bus so file browser and any other open
	# editor referencing this .tscn can refresh.
	preload("res://addons/visual_gasic/vg_asset_bus.gd").get_instance().emit_saved(_loaded_scene_path, "vg_2d_editor")
	print("VG 2D Editor: Saved → ", _loaded_scene_path)

func save_scene_as() -> void:
	if _save_file_dialog:
		_save_file_dialog.queue_free()

	_save_file_dialog = FileDialog.new()
	_save_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_save_file_dialog.filters = PackedStringArray(["*.tscn;Godot Scene"])
	_save_file_dialog.title = "Save 2D Scene As"
	_save_file_dialog.size = Vector2i(600, 400)
	_style_dialog_dark(_save_file_dialog)

	if not _loaded_scene_path.is_empty():
		_save_file_dialog.current_path = _loaded_scene_path
	else:
		_save_file_dialog.current_file = "new_2d_scene.tscn"

	_save_file_dialog.file_selected.connect(func(path):
		_loaded_scene_path = path
		_save_scene()
		_save_file_dialog.queue_free()
		_save_file_dialog = null
	)

	add_child(_save_file_dialog)
	_save_file_dialog.popup_centered()

func new_scene() -> void:
	for child in _scene_root.get_children():
		_scene_root.remove_child(child)
		child.queue_free()

	_loaded_scene_path = ""
	_selected_nodes.clear()
	_primary_selected = null
	_undo_stack.clear()
	_redo_stack.clear()
	_scene_dirty = false

	_rebuild_scene_tree()
	_reset_camera()
	_update_status()
	_overlay.queue_redraw()

func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)

func _set_owner_for_save(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		# Do NOT recurse into instances — their internal nodes are owned by
		# the instance root, not us, and re-owning them would force the
		# saver to write them as edited overrides.
		if child.scene_file_path == "":
			_set_owner_for_save(child, root)

# ─────────────────────────────────────────────────────────────────────────────
# HELP DIALOG
# ─────────────────────────────────────────────────────────────────────────────
func _build_help_dialog() -> void:
	_help_dialog = AcceptDialog.new()
	_help_dialog.title = "2D Scene Editor — Keyboard Shortcuts"
	_style_dialog_dark(_help_dialog)
	_help_dialog.dialog_text = """
CAMERA
  Middle Mouse Drag ....... Pan
  Alt + Left Drag ......... Pan (Laptop)
  Mouse Wheel ............. Zoom In / Out
  Pinch (Trackpad) ........ Zoom
  Two-Finger Swipe ........ Pan (Trackpad)

TOOLS
  S ....................... Select Tool
  W ....................... Move Tool
  E ....................... Rotate Tool
  R ....................... Scale Tool

EDITING
  Click .................. Select object
  Shift + Click .......... Multi-select (toggle)
  Drag (on selected) ..... Move object(s)
  Rubber-band ............ Drag on empty = area select
  Ctrl+D ................. Duplicate
  Ctrl+C / Ctrl+V ........ Copy / Paste
  Ctrl+A ................. Select All
  Delete ................. Delete selected
  F2 ..................... Rename
  F ....................... Focus on selected
  G ....................... Toggle grid snap
  Ctrl+Z / Ctrl+Y ........ Undo / Redo
  Ctrl+S ................. Save scene
  Escape ................. Deselect all
  Right-click ............ Context menu
  Double-click ........... Open code editor
"""

	_help_dialog.min_size = Vector2(480, 600)
	add_child(_help_dialog)

# ─────────────────────────────────────────────────────────────────────────────
# UTILITY
# ─────────────────────────────────────────────────────────────────────────────
func _unique_name(base: String, parent: Node) -> String:
	var existing: Array = []
	for child in parent.get_children():
		existing.append(child.name)

	if base not in existing:
		return base

	var i = 2
	while (base + str(i)) in existing:
		i += 1
	return base + str(i)

func _update_status() -> void:
	if not is_instance_valid(_status_label):
		return

	var parts: Array = []

	if _loaded_scene_path.is_empty():
		parts.append("No scene")
	else:
		parts.append(_loaded_scene_path.get_file())
		if _scene_dirty:
			parts.append("(modified)")

	if _primary_selected and is_instance_valid(_primary_selected):
		parts.append("| Selected: " + _primary_selected.name)
		if _selected_nodes.size() > 1:
			parts.append("(+" + str(_selected_nodes.size() - 1) + " more)")

	var tool_names = ["Select", "Move", "Rotate", "Scale"]
	parts.append("| Tool: " + tool_names[_tool_mode])

	parts.append("| Zoom: " + str(int(_cam_zoom * 100)) + "%")

	if _snap_enabled:
		parts.append("| Snap: " + str(int(_snap_value)) + "px")

	_status_label.text = "  ".join(parts)

func _style_popup_dark(popup: PopupMenu) -> void:
	# Force dark styling on PopupMenu. Uses every mechanism available to
	# override the editor theme: local overrides, a full Theme resource,
	# transparent window background, and a forced theme-cache refresh.
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.18, 0.18, 0.22)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(0.35, 0.35, 0.45)
	panel_style.set_corner_radius_all(4)
	panel_style.set_content_margin_all(4)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.28, 0.38, 0.58)
	hover_style.set_corner_radius_all(3)

	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = Color(0.3, 0.3, 0.38)
	sep_style.set_content_margin_all(0)
	sep_style.content_margin_top = 1
	sep_style.content_margin_bottom = 1

	# 1. Set a full Theme on the popup (affects children resolution)
	var t = Theme.new()
	t.set_stylebox("panel", "PopupMenu", panel_style)
	t.set_stylebox("hover", "PopupMenu", hover_style)
	t.set_stylebox("separator", "PopupMenu", sep_style)
	t.set_stylebox("labeled_separator_left", "PopupMenu", sep_style)
	t.set_stylebox("labeled_separator_right", "PopupMenu", sep_style)
	t.set_color("font_color", "PopupMenu", Color(0.88, 0.88, 0.88))
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_disabled_color", "PopupMenu", Color(0.45, 0.45, 0.45))
	t.set_color("font_separator_color", "PopupMenu", Color(0.55, 0.55, 0.55))
	t.set_color("font_accelerator_color", "PopupMenu", Color(0.5, 0.6, 0.8))
	# Also set on PopupPanel type in case Godot uses it internally
	t.set_stylebox("panel", "PopupPanel", panel_style)
	popup.theme = t

	# 2. Set local overrides (highest priority in theme resolution)
	popup.add_theme_stylebox_override("panel", panel_style)
	popup.add_theme_stylebox_override("hover", hover_style)
	popup.add_theme_stylebox_override("separator", sep_style)
	popup.add_theme_stylebox_override("labeled_separator_left", sep_style)
	popup.add_theme_stylebox_override("labeled_separator_right", sep_style)
	popup.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
	popup.add_theme_color_override("font_hover_color", Color.WHITE)
	popup.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.45))
	popup.add_theme_color_override("font_separator_color", Color(0.55, 0.55, 0.55))
	popup.add_theme_color_override("font_accelerator_color", Color(0.5, 0.6, 0.8))

	# 3. Kill any native OS window background
	popup.transparent = true

	# 4. Force the theme cache to update
	popup.notification(Window.NOTIFICATION_THEME_CHANGED)

func _style_dialog_dark(dialog: Window) -> void:
	# Use a full Theme to override editor theme for Window/Dialog nodes
	var t = Theme.new()

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.18, 0.18, 0.22)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(0.35, 0.35, 0.45)
	panel_style.set_corner_radius_all(4)
	panel_style.set_content_margin_all(8)

	t.set_stylebox("embedded_border", "Window", panel_style)
	t.set_color("title_color", "Window", Color(0.88, 0.88, 0.88))

	if dialog is AcceptDialog:
		var base_panel = StyleBoxFlat.new()
		base_panel.bg_color = Color(0.18, 0.18, 0.22)
		base_panel.set_content_margin_all(8)
		base_panel.set_corner_radius_all(4)
		t.set_stylebox("panel", "AcceptDialog", base_panel)
		# Also style the label text
		t.set_color("font_color", "Label", Color(0.88, 0.88, 0.88))
		# Style OK button
		var btn_normal = StyleBoxFlat.new()
		btn_normal.bg_color = Color(0.25, 0.25, 0.30)
		btn_normal.set_corner_radius_all(3)
		btn_normal.set_content_margin_all(4)
		var btn_hover = StyleBoxFlat.new()
		btn_hover.bg_color = Color(0.32, 0.32, 0.38)
		btn_hover.set_corner_radius_all(3)
		btn_hover.set_content_margin_all(4)
		t.set_stylebox("normal", "Button", btn_normal)
		t.set_stylebox("hover", "Button", btn_hover)
		t.set_color("font_color", "Button", Color(0.88, 0.88, 0.88))

	if dialog is FileDialog:
		# Style internal controls for file dialogs
		var fd_panel = StyleBoxFlat.new()
		fd_panel.bg_color = Color(0.16, 0.16, 0.19)
		fd_panel.set_content_margin_all(6)
		fd_panel.set_corner_radius_all(4)
		t.set_stylebox("panel", "FileDialog", fd_panel)
		# Style internal ItemList / Tree
		var list_bg = StyleBoxFlat.new()
		list_bg.bg_color = Color(0.14, 0.14, 0.17)
		list_bg.set_border_width_all(1)
		list_bg.border_color = Color(0.25, 0.25, 0.30)
		list_bg.set_corner_radius_all(3)
		list_bg.set_content_margin_all(4)
		t.set_stylebox("panel", "ItemList", list_bg)
		t.set_stylebox("panel", "Tree", list_bg)
		t.set_color("font_color", "ItemList", Color(0.85, 0.85, 0.85))
		t.set_color("font_color", "Tree", Color(0.85, 0.85, 0.85))
		t.set_color("font_selected_color", "ItemList", Color(1.0, 1.0, 1.0))
		t.set_color("font_selected_color", "Tree", Color(1.0, 1.0, 1.0))
		var sel_style = StyleBoxFlat.new()
		sel_style.bg_color = Color(0.24, 0.36, 0.55)
		sel_style.set_corner_radius_all(3)
		t.set_stylebox("selected", "ItemList", sel_style)
		t.set_stylebox("selected_focus", "ItemList", sel_style)
		t.set_stylebox("selected", "Tree", sel_style)
		t.set_stylebox("selected_focus", "Tree", sel_style)
		# Style buttons in the dialog
		var btn_n = StyleBoxFlat.new()
		btn_n.bg_color = Color(0.25, 0.25, 0.30)
		btn_n.set_corner_radius_all(3)
		btn_n.set_content_margin_all(4)
		var btn_h = StyleBoxFlat.new()
		btn_h.bg_color = Color(0.32, 0.32, 0.38)
		btn_h.set_corner_radius_all(3)
		btn_h.set_content_margin_all(4)
		t.set_stylebox("normal", "Button", btn_n)
		t.set_stylebox("hover", "Button", btn_h)
		t.set_color("font_color", "Button", Color(0.88, 0.88, 0.88))
		# Style LineEdit
		var le_style = StyleBoxFlat.new()
		le_style.bg_color = Color(0.14, 0.14, 0.17)
		le_style.set_border_width_all(1)
		le_style.border_color = Color(0.3, 0.3, 0.38)
		le_style.set_corner_radius_all(3)
		le_style.set_content_margin_all(4)
		t.set_stylebox("normal", "LineEdit", le_style)
		t.set_color("font_color", "LineEdit", Color(0.88, 0.88, 0.88))
		t.set_color("font_color", "Label", Color(0.85, 0.85, 0.85))
		# Style OptionButton
		t.set_color("font_color", "OptionButton", Color(0.85, 0.85, 0.85))

	dialog.theme = t

	# Also apply direct overrides as fallback
	dialog.add_theme_stylebox_override("embedded_border", panel_style)
	dialog.add_theme_color_override("title_color", Color(0.88, 0.88, 0.88))
	if dialog is AcceptDialog:
		var base_panel2 = StyleBoxFlat.new()
		base_panel2.bg_color = Color(0.18, 0.18, 0.22)
		base_panel2.set_content_margin_all(8)
		base_panel2.set_corner_radius_all(4)
		dialog.add_theme_stylebox_override("panel", base_panel2)

func _build_dark_scrollbar_theme() -> Theme:
	var theme = Theme.new()
	var grabber = StyleBoxFlat.new()
	grabber.bg_color = Color(0.35, 0.35, 0.38)
	grabber.set_corner_radius_all(4)
	grabber.content_margin_left = 4
	grabber.content_margin_right = 4
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber", "HScrollBar", grabber)

	var grabber_hl = grabber.duplicate()
	grabber_hl.bg_color = Color(0.45, 0.45, 0.5)
	theme.set_stylebox("grabber_highlight", "VScrollBar", grabber_hl)
	theme.set_stylebox("grabber_highlight", "HScrollBar", grabber_hl)

	var grabber_pressed = grabber.duplicate()
	grabber_pressed.bg_color = Color(0.5, 0.5, 0.55)
	theme.set_stylebox("grabber_pressed", "VScrollBar", grabber_pressed)
	theme.set_stylebox("grabber_pressed", "HScrollBar", grabber_pressed)

	var scroll_bg = StyleBoxFlat.new()
	scroll_bg.bg_color = Color(0.18, 0.18, 0.20)
	scroll_bg.content_margin_left = 2
	scroll_bg.content_margin_right = 2
	theme.set_stylebox("scroll", "VScrollBar", scroll_bg)
	theme.set_stylebox("scroll", "HScrollBar", scroll_bg)
	return theme

func _build_dark_toolbar_theme() -> Theme:
	var t = Theme.new()

	# Button styles
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.22, 0.22, 0.26)
	btn_normal.set_corner_radius_all(3)
	btn_normal.set_content_margin_all(4)
	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.30, 0.30, 0.36)
	var btn_pressed = btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.18, 0.28, 0.45)
	var btn_disabled = btn_normal.duplicate()
	btn_disabled.bg_color = Color(0.18, 0.18, 0.20)
	t.set_stylebox("normal", "Button", btn_normal)
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_stylebox("pressed", "Button", btn_pressed)
	t.set_stylebox("disabled", "Button", btn_disabled)
	t.set_color("font_color", "Button", Color(0.85, 0.85, 0.85))
	t.set_color("font_hover_color", "Button", Color(1.0, 1.0, 1.0))
	t.set_color("font_pressed_color", "Button", Color(0.7, 0.85, 1.0))
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.45, 0.45))

	# CheckButton styles
	t.set_color("font_color", "CheckButton", Color(0.85, 0.85, 0.85))
	t.set_color("font_hover_color", "CheckButton", Color(1.0, 1.0, 1.0))
	t.set_color("font_pressed_color", "CheckButton", Color(0.7, 0.85, 1.0))
	t.set_stylebox("normal", "CheckButton", btn_normal)
	t.set_stylebox("hover", "CheckButton", btn_hover)
	t.set_stylebox("pressed", "CheckButton", btn_pressed)

	# SpinBox / LineEdit internal styles
	var le_style = StyleBoxFlat.new()
	le_style.bg_color = Color(0.14, 0.14, 0.17)
	le_style.set_border_width_all(1)
	le_style.border_color = Color(0.3, 0.3, 0.38)
	le_style.set_corner_radius_all(3)
	le_style.set_content_margin_all(3)
	t.set_stylebox("normal", "LineEdit", le_style)
	var le_focus = le_style.duplicate()
	le_focus.border_color = Color(0.4, 0.5, 0.7)
	t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_color("font_color", "LineEdit", Color(0.88, 0.88, 0.88))
	t.set_color("caret_color", "LineEdit", Color(0.88, 0.88, 0.88))

	# Label
	t.set_color("font_color", "Label", Color(0.75, 0.75, 0.75))

	# VSeparator
	var vsep = StyleBoxFlat.new()
	vsep.bg_color = Color(0.3, 0.3, 0.35)
	vsep.content_margin_left = 1
	vsep.content_margin_right = 1
	vsep.content_margin_top = 4
	vsep.content_margin_bottom = 4
	t.set_stylebox("separator", "VSeparator", vsep)

	return t

# ─────────────────────────────────────────────────────────────────────────────
# _process — Sync viewport size and overlay
# ─────────────────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if not visible:
		return

	# Keep viewport size synced
	if is_instance_valid(_viewport) and is_instance_valid(_viewport_container):
		var container_size = _viewport_container.size
		if container_size.x > 0 and container_size.y > 0:
			_viewport.size = Vector2i(container_size)

	# Redraw overlay each frame (selection handles track moving objects)
	if is_instance_valid(_overlay):
		_overlay.queue_redraw()

# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC API (mirrors 3D editor for plugin compatibility)
# ─────────────────────────────────────────────────────────────────────────────

## Returns the primary selected node, or null.
func get_selected_node() -> Node2D:
	return _primary_selected if is_instance_valid(_primary_selected) else null

## Returns true if the scene has unsaved changes.
func is_dirty() -> bool:
	return _scene_dirty

## Returns the loaded scene path, or empty string.
func get_scene_path() -> String:
	return _loaded_scene_path

## Returns an array of node names in the scene (for code editor Object dropdown).
func get_scene_node_names() -> Array:
	var names: Array = []
	if is_instance_valid(_scene_root):
		_collect_node_names(_scene_root, names)
	return names

## Returns an array of {name, type} dictionaries for type-aware events.
func get_scene_node_info() -> Array:
	var info: Array = []
	if is_instance_valid(_scene_root):
		_collect_node_info(_scene_root, info)
	return info

func _collect_node_names(parent: Node, out: Array) -> void:
	for child in parent.get_children():
		if child.name not in ["EditorCamera", "EditorBackground", "EditorOverlay"]:
			out.append(child.name)
			_collect_node_names(child, out)

func _collect_node_info(parent: Node, out: Array) -> void:
	for child in parent.get_children():
		if child.name not in ["EditorCamera", "EditorBackground", "EditorOverlay"]:
			out.append({"name": child.name, "type": child.get_class()})
			_collect_node_info(child, out)


# ─── VGPluginRegistry contract ──────────────────────────────
## Called by VGPluginRegistry.open_asset(). Returns true if the editor
## accepted the file. Existing internal callers should keep using their
## native open methods; this is the registry-friendly alias only.
func open_asset(path: String) -> bool:
	load_scene(path)
	preload("res://addons/visual_gasic/vg_asset_bus.gd").get_instance().emit_opened(path, "vg_2d_editor")
	preload("res://addons/visual_gasic/vg_context_broker.gd").get_instance().set_current_asset(path, "vg_2d_editor")
	return true
