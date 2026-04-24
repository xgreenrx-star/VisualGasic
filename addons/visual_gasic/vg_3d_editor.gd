@tool
## VG 3D Scene Editor — Full-featured 3D editing surface embedded in the VG IDE.
##
## Features: orbit camera with presets (Top/Front/Right/etc.), orthographic/perspective
## toggle, transform gizmos with local/world space, snap grid, undo/redo, duplicate,
## right-click context menus, numeric transform input fields, quick color picker,
## view mode switching (solid/wireframe/unshaded/overdraw), visibility toggles,
## drop-to-floor, inline rename, keyboard shortcuts overlay, and scene load/save.
##
## Architecture: HSplitContainer with a left toolbox/scene-tree/transform panel
## and a right SubViewport + toolbar area.
## All 3D manipulation happens inside a SubViewport with its own Camera3D and lights.
extends HSplitContainer

# ─────────────────────────────────────────────────────────────────────────────
# SIGNALS
# ─────────────────────────────────────────────────────────────────────────────
signal back_to_form_requested
signal node_selected(node: Node3D)
signal selection_cleared
signal node_double_clicked(node: Node3D)
signal view_code_requested(node: Node3D)
signal scene_saved(path: String)  ## Emitted after a successful save (Save or Save As)

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────
const ORBIT_SPEED := 0.005
const PAN_SPEED := 0.02
const ZOOM_SPEED := 1.0
const MIN_DISTANCE := 0.5
const MAX_DISTANCE := 100.0
const DEFAULT_DISTANCE := 8.0
const GRID_SIZE := 20
const MAX_UNDO := 50

# ─────────────────────────────────────────────────────────────────────────────
# ENUMS
# ─────────────────────────────────────────────────────────────────────────────
enum GizmoMode { TRANSLATE, ROTATE, SCALE }
enum ViewMode { SOLID, WIREFRAME, UNSHADED, OVERDRAW }

# ─────────────────────────────────────────────────────────────────────────────
# STATE VARIABLES
# ─────────────────────────────────────────────────────────────────────────────

# Camera orbit
var _orbit_yaw: float = -0.5
var _orbit_pitch: float = -0.4
var _orbit_distance: float = DEFAULT_DISTANCE
var _orbit_target: Vector3 = Vector3.ZERO
var _orbiting: bool = false
var _panning: bool = false
var _alt_orbiting: bool = false   # Alt+LMB orbit (laptop friendly)
var _alt_panning: bool = false    # Alt+Shift+LMB pan (laptop friendly)
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _is_orthographic: bool = false

# Selection
var _selected_node: Node3D = null
var _selection_wireframe: MeshInstance3D = null

# Gizmo
var _gizmo_mode: GizmoMode = GizmoMode.TRANSLATE
var _gizmo_root: Node3D = null
var _gizmo_dragging: bool = false
var _gizmo_axis: int = -1
var _gizmo_drag_start: Vector2 = Vector2.ZERO
var _gizmo_drag_origin: Vector3 = Vector3.ZERO
var _gizmo_arrows: Array = []
var _local_space: bool = false

# Transform tracking for undo
var _drag_transform_before: Dictionary = {}

# Snap
var _snap_enabled: bool = false
var _snap_value: float = 0.5

# Scene
var _scene_root: Node3D = null
var _loaded_scene_path: String = ""
var _scene_dirty: bool = false
var _save_file_dialog: FileDialog = null
var _import_file_dialog: FileDialog = null
var _env_preset_menu: PopupMenu = null

# View mode
var _view_mode: ViewMode = ViewMode.SOLID

# Undo/Redo
var _undo_stack: Array = []
var _redo_stack: Array = []

# Right-click tracking
var _rmb_press_pos: Vector2 = Vector2.ZERO

# UI references
var _viewport: SubViewport = null
var _viewport_container: SubViewportContainer = null
var _camera: Camera3D = null
var _environment: WorldEnvironment = null
var _sun_light: DirectionalLight3D = null
var _grid_mesh: MeshInstance3D = null

var _toolbox_list: ItemList = null
var _scene_tree: Tree = null
var _gizmo_mode_btn_translate: CheckButton = null
var _gizmo_mode_btn_rotate: CheckButton = null
var _gizmo_mode_btn_scale: CheckButton = null
var _snap_toggle: CheckButton = null
var _snap_spin: SpinBox = null
var _status_label: Label = null
var _toolbar_row1: HBoxContainer = null
var _toolbar_row2: HBoxContainer = null

var _local_world_btn: Button = null
var _view_mode_btn: Button = null
var _camera_preset_btn: MenuButton = null
var _ortho_btn: Button = null
var _color_picker_btn: ColorPickerButton = null
var _undo_btn: Button = null
var _redo_btn: Button = null
var _help_dialog: AcceptDialog = null
var _popup_backdrop: Control = null  # Custom dark popup overlay (replaces native PopupMenu)

# Transform panel spinboxes
var _pos_x: SpinBox = null
var _pos_y: SpinBox = null
var _pos_z: SpinBox = null
var _rot_x: SpinBox = null
var _rot_y: SpinBox = null
var _rot_z: SpinBox = null
var _scl_x: SpinBox = null
var _scl_y: SpinBox = null
var _scl_z: SpinBox = null
var _node_inspector = null  # VG Node Inspector panel

# ─────────────────────────────────────────────────────────────────────────────
# TOOLBOX ITEMS — the object types available for placement
# ─────────────────────────────────────────────────────────────────────────────
var _toolbox_items: Array = [
	{name = "Box", type = "CSGBox3D", icon = "🟫"},
	{name = "Sphere", type = "CSGSphere3D", icon = "🔵"},
	{name = "Cylinder", type = "CSGCylinder3D", icon = "🟡"},
	{name = "Mesh (Box)", type = "MeshInstance3D", icon = "🔺"},
	{name = "Omni Light", type = "OmniLight3D", icon = "💡"},
	{name = "Spot Light", type = "SpotLight3D", icon = "🔦"},
	{name = "Dir Light", type = "DirectionalLight3D", icon = "☀️"},
	{name = "Camera", type = "Camera3D", icon = "📷"},
	{name = "Rigid Body", type = "RigidBody3D", icon = "⚙️"},
	{name = "Static Body", type = "StaticBody3D", icon = "🧱"},
	{name = "Char Body", type = "CharacterBody3D", icon = "🏃"},
	{name = "Area 3D", type = "Area3D", icon = "📦"},
	{name = "Sprite 3D", type = "Sprite3D", icon = "🖼️"},
	{name = "Label 3D", type = "Label3D", icon = "🔤"},
	{name = "Audio 3D", type = "AudioStreamPlayer3D", icon = "🔊"},
	{name = "Node3D", type = "Node3D", icon = "⊕"},
	{name = "Path3D", type = "Path3D", icon = "〰️"},
]

# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_ui()
	_build_3d_scene()
	_build_gizmos()
	_build_help_dialog()
	_build_context_menus()
	_update_camera()
	_populate_toolbox()

# ─────────────────────────────────────────────────────────────────────────────
# BUILD UI
# ─────────────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	# Overall: HSplitContainer = self
	split_offset = 250

	# ── LEFT PANEL ──────────────────────────────────────────────────────────
	var left_panel = PanelContainer.new()
	left_panel.custom_minimum_size.x = 240

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
	left_scroll.add_child(left_vbox)

	# Resizable split between 3D Objects and Scene Tree. Previously these
	# were stacked in a plain VBox, so the user couldn't rebalance their
	# heights when one list outgrew its share.
	var toolbox_tree_split := VSplitContainer.new()
	toolbox_tree_split.size_flags_vertical = SIZE_EXPAND_FILL
	toolbox_tree_split.size_flags_horizontal = SIZE_EXPAND_FILL
	toolbox_tree_split.custom_minimum_size.y = 520
	var toolbox_pane := VBoxContainer.new()
	toolbox_pane.size_flags_vertical = SIZE_EXPAND_FILL
	toolbox_pane.custom_minimum_size.y = 80
	toolbox_tree_split.add_child(toolbox_pane)
	var scene_pane := VBoxContainer.new()
	scene_pane.size_flags_vertical = SIZE_EXPAND_FILL
	scene_pane.custom_minimum_size.y = 80
	toolbox_tree_split.add_child(scene_pane)
	left_vbox.add_child(toolbox_tree_split)

	# Toolbox header
	var toolbox_label = Label.new()
	toolbox_label.text = "📦 3D Objects"
	toolbox_label.add_theme_font_size_override("font_size", 14)
	toolbox_pane.add_child(toolbox_label)

	# Toolbox item list
	_toolbox_list = ItemList.new()
	# Height now governed by the VSplitContainer pane, not a fixed min.
	_toolbox_list.custom_minimum_size = Vector2(0, 0)
	_toolbox_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_toolbox_list.size_flags_vertical = SIZE_EXPAND_FILL
	_toolbox_list.item_activated.connect(_on_toolbox_item_activated)
	_toolbox_list.theme = _build_dark_scrollbar_theme()
	toolbox_pane.add_child(_toolbox_list)

	# Add button
	var add_btn = Button.new()
	add_btn.text = "➕ Add to Scene"
	add_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	var add_style = StyleBoxFlat.new()
	add_style.bg_color = Color(0.15, 0.5, 0.2)
	add_style.set_corner_radius_all(4)
	add_btn.add_theme_stylebox_override("normal", add_style)
	add_btn.add_theme_color_override("font_color", Color.WHITE)
	add_btn.pressed.connect(_on_add_object_btn_pressed)
	toolbox_pane.add_child(add_btn)

	# ── SCENE TREE (bottom pane of split) ──
	var tree_label = Label.new()
	tree_label.text = "🌳 Scene Tree"
	tree_label.add_theme_font_size_override("font_size", 14)
	scene_pane.add_child(tree_label)

	_scene_tree = Tree.new()
	_scene_tree.custom_minimum_size = Vector2(0, 0)
	_scene_tree.size_flags_vertical = SIZE_EXPAND_FILL
	_scene_tree.size_flags_horizontal = SIZE_EXPAND_FILL
	_scene_tree.item_selected.connect(_on_scene_tree_selected)
	_scene_tree.item_activated.connect(_on_scene_tree_double_clicked)
	_scene_tree.item_mouse_selected.connect(_on_scene_tree_rmb)
	_scene_tree.theme = _build_dark_scrollbar_theme()
	scene_pane.add_child(_scene_tree)

	# Scene tree action buttons
	var tree_btns = HBoxContainer.new()
	tree_btns.size_flags_horizontal = SIZE_EXPAND_FILL

	var vis_btn = Button.new()
	vis_btn.text = "👁️ Vis"
	vis_btn.tooltip_text = "Toggle visibility of selected node"
	vis_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	vis_btn.pressed.connect(_toggle_visibility_selected)
	tree_btns.add_child(vis_btn)

	var rename_btn = Button.new()
	rename_btn.text = "✏️ Rename"
	rename_btn.tooltip_text = "Rename selected node (F2)"
	rename_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	rename_btn.pressed.connect(_rename_selected)
	tree_btns.add_child(rename_btn)

	var del_btn = Button.new()
	del_btn.text = "🗑️ Delete"
	del_btn.tooltip_text = "Delete selected node (Del)"
	del_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	var del_style = StyleBoxFlat.new()
	del_style.bg_color = Color(0.6, 0.15, 0.15)
	del_style.set_corner_radius_all(4)
	del_btn.add_theme_stylebox_override("normal", del_style)
	del_btn.add_theme_color_override("font_color", Color.WHITE)
	del_btn.pressed.connect(_on_delete_selected)
	tree_btns.add_child(del_btn)

	scene_pane.add_child(tree_btns)

	left_vbox.add_child(HSeparator.new())

	# ── TRANSFORM PANEL ─────────────────────────────────────────────────────
	var transform_label = Label.new()
	transform_label.text = "📐 Transform"
	transform_label.add_theme_font_size_override("font_size", 14)
	left_vbox.add_child(transform_label)

	var transform_grid = GridContainer.new()
	transform_grid.columns = 2
	transform_grid.size_flags_horizontal = SIZE_EXPAND_FILL

	# Position
	var pos_header = Label.new()
	pos_header.text = "Position"
	pos_header.add_theme_font_size_override("font_size", 11)
	pos_header.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	transform_grid.add_child(pos_header)
	transform_grid.add_child(Control.new())  # spacer

	_pos_x = _make_spin(transform_grid, "X", 0.01, -1000, 1000)
	_pos_y = _make_spin(transform_grid, "Y", 0.01, -1000, 1000)
	_pos_z = _make_spin(transform_grid, "Z", 0.01, -1000, 1000)

	# Rotation
	var rot_header = Label.new()
	rot_header.text = "Rotation (°)"
	rot_header.add_theme_font_size_override("font_size", 11)
	rot_header.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	transform_grid.add_child(rot_header)
	transform_grid.add_child(Control.new())

	_rot_x = _make_spin(transform_grid, "X", 0.1, -360, 360)
	_rot_y = _make_spin(transform_grid, "Y", 0.1, -360, 360)
	_rot_z = _make_spin(transform_grid, "Z", 0.1, -360, 360)

	# Scale
	var scl_header = Label.new()
	scl_header.text = "Scale"
	scl_header.add_theme_font_size_override("font_size", 11)
	scl_header.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	transform_grid.add_child(scl_header)
	transform_grid.add_child(Control.new())

	_scl_x = _make_spin(transform_grid, "X", 0.01, 0.001, 100)
	_scl_y = _make_spin(transform_grid, "Y", 0.01, 0.001, 100)
	_scl_z = _make_spin(transform_grid, "Z", 0.01, 0.001, 100)
	_scl_x.value = 1.0
	_scl_y.value = 1.0
	_scl_z.value = 1.0

	left_vbox.add_child(transform_grid)

	# ── Node Inspector (properties, collision, groups, signals) ──
	left_vbox.add_child(HSeparator.new())
	var InspectorScript = load("res://addons/visual_gasic/vg_node_inspector.gd")
	if InspectorScript:
		_node_inspector = InspectorScript.new()
		_node_inspector.signal_connect_requested.connect(func(node_name, sig_name):
			print("[VG3D] Generate Sub: ", node_name, "_", sig_name)
		)
		_node_inspector.property_changed.connect(func(_node, _prop, _old_val, _new_val):
			pass  # 3D viewport auto-redraws
		)
		left_vbox.add_child(_node_inspector)

	add_child(left_panel)

	# ── RIGHT PANEL ─────────────────────────────────────────────────────────
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = SIZE_EXPAND_FILL

	# ── TOOLBAR ROW 1 ───────────────────────────────────────────────────────
	_toolbar_row1 = HBoxContainer.new()
	_toolbar_row1.add_theme_constant_override("separation", 4)

	# Back to Form button
	var back_btn = Button.new()
	back_btn.text = "← Form"
	back_btn.tooltip_text = "Return to Form Designer view"
	var back_style = StyleBoxFlat.new()
	back_style.bg_color = Color(0.35, 0.35, 0.45)
	back_style.set_corner_radius_all(4)
	back_btn.add_theme_stylebox_override("normal", back_style)
	back_btn.add_theme_color_override("font_color", Color.WHITE)
	back_btn.pressed.connect(func(): back_to_form_requested.emit())
	_toolbar_row1.add_child(back_btn)

	_toolbar_row1.add_child(VSeparator.new())

	# Gizmo mode buttons
	_gizmo_mode_btn_translate = CheckButton.new()
	_gizmo_mode_btn_translate.text = "Move"
	_gizmo_mode_btn_translate.tooltip_text = "Translate mode (W)"
	_gizmo_mode_btn_translate.button_pressed = true
	_gizmo_mode_btn_translate.toggled.connect(func(p: bool):
		if p: _set_gizmo_mode(GizmoMode.TRANSLATE))
	_toolbar_row1.add_child(_gizmo_mode_btn_translate)

	_gizmo_mode_btn_rotate = CheckButton.new()
	_gizmo_mode_btn_rotate.text = "Rotate"
	_gizmo_mode_btn_rotate.tooltip_text = "Rotate mode (E)"
	_gizmo_mode_btn_rotate.toggled.connect(func(p: bool):
		if p: _set_gizmo_mode(GizmoMode.ROTATE))
	_toolbar_row1.add_child(_gizmo_mode_btn_rotate)

	_gizmo_mode_btn_scale = CheckButton.new()
	_gizmo_mode_btn_scale.text = "Scale"
	_gizmo_mode_btn_scale.tooltip_text = "Scale mode (R)"
	_gizmo_mode_btn_scale.toggled.connect(func(p: bool):
		if p: _set_gizmo_mode(GizmoMode.SCALE))
	_toolbar_row1.add_child(_gizmo_mode_btn_scale)

	_toolbar_row1.add_child(VSeparator.new())

	# Local/World toggle
	_local_world_btn = Button.new()
	_local_world_btn.text = "🌐 World"
	_local_world_btn.tooltip_text = "Toggle local/world transform space"
	_local_world_btn.pressed.connect(_toggle_local_world)
	_toolbar_row1.add_child(_local_world_btn)

	_toolbar_row1.add_child(VSeparator.new())

	# Snap controls
	_snap_toggle = CheckButton.new()
	_snap_toggle.text = "⊞ Snap"
	_snap_toggle.tooltip_text = "Toggle grid snapping"
	_snap_toggle.toggled.connect(func(pressed: bool): _snap_enabled = pressed)
	_toolbar_row1.add_child(_snap_toggle)

	_snap_spin = SpinBox.new()
	_snap_spin.min_value = 0.05
	_snap_spin.max_value = 10.0
	_snap_spin.step = 0.05
	_snap_spin.value = 0.5
	_snap_spin.custom_minimum_size.x = 65
	_snap_spin.tooltip_text = "Snap increment"
	_snap_spin.value_changed.connect(func(v: float): _snap_value = v)
	_toolbar_row1.add_child(_snap_spin)

	_toolbar_row1.add_child(VSeparator.new())

	# Import Model button
	var import_btn = Button.new()
	import_btn.text = "📦 Import"
	import_btn.tooltip_text = "Import 3D model (.glb, .gltf, .obj)"
	import_btn.pressed.connect(_show_import_model_dialog)
	_toolbar_row1.add_child(import_btn)

	# Environment Preset button
	var env_menu_btn = MenuButton.new()
	env_menu_btn.text = "🌍 Env"
	env_menu_btn.tooltip_text = "Add environment & lighting preset"
	_env_preset_menu = env_menu_btn.get_popup()
	_env_preset_menu.add_item("☀️  Outdoor Day", 0)
	_env_preset_menu.add_item("🌙 Outdoor Night", 1)
	_env_preset_menu.add_item("💡 Indoor", 2)
	_env_preset_menu.add_item("✨ Space", 3)
	_env_preset_menu.add_separator()
	_env_preset_menu.add_item("🗑️  Remove Environment", 10)
	_env_preset_menu.id_pressed.connect(_on_env_preset_selected)
	_style_popup_dark(_env_preset_menu)
	_toolbar_row1.add_child(env_menu_btn)

	# Spacer
	var spacer1 = Control.new()
	spacer1.size_flags_horizontal = SIZE_EXPAND_FILL
	_toolbar_row1.add_child(spacer1)

	# Save button
	var save_btn = Button.new()
	save_btn.text = "💾 Save"
	save_btn.tooltip_text = "Save scene (Ctrl+S)"
	save_btn.pressed.connect(_save_scene)
	_toolbar_row1.add_child(save_btn)

	right_panel.add_child(_toolbar_row1)

	# ── TOOLBAR ROW 2 ───────────────────────────────────────────────────────
	_toolbar_row2 = HBoxContainer.new()
	_toolbar_row2.add_theme_constant_override("separation", 4)

	# Camera preset dropdown
	_camera_preset_btn = MenuButton.new()
	_camera_preset_btn.text = "📷 View"
	_camera_preset_btn.tooltip_text = "Camera view presets (Numpad)"
	var cam_popup: PopupMenu = _camera_preset_btn.get_popup()
	cam_popup.add_item("Perspective (default)", 0)
	cam_popup.add_separator()
	cam_popup.add_item("Top       (Num 7)", 1)
	cam_popup.add_item("Bottom  (Ctrl+7)", 2)
	cam_popup.add_item("Front     (Num 1)", 3)
	cam_popup.add_item("Back      (Ctrl+1)", 4)
	cam_popup.add_item("Left       (Num 3 Ctrl)", 5)
	cam_popup.add_item("Right     (Num 3)", 6)
	cam_popup.id_pressed.connect(_on_camera_preset_selected)
	_style_popup_dark(cam_popup)
	_toolbar_row2.add_child(_camera_preset_btn)

	# Ortho/Perspective toggle
	_ortho_btn = Button.new()
	_ortho_btn.text = "Persp"
	_ortho_btn.tooltip_text = "Toggle Perspective/Orthographic (Numpad 5)"
	_ortho_btn.pressed.connect(_toggle_ortho)
	_toolbar_row2.add_child(_ortho_btn)

	_toolbar_row2.add_child(VSeparator.new())

	# View mode button (cycles through solid/wireframe/unshaded/overdraw)
	_view_mode_btn = Button.new()
	_view_mode_btn.text = "🔲 Solid"
	_view_mode_btn.tooltip_text = "Cycle view mode: Solid → Wireframe → Unshaded → Overdraw"
	_view_mode_btn.pressed.connect(_cycle_view_mode)
	_toolbar_row2.add_child(_view_mode_btn)

	_toolbar_row2.add_child(VSeparator.new())

	# Color picker
	_color_picker_btn = ColorPickerButton.new()
	_color_picker_btn.custom_minimum_size = Vector2(32, 28)
	_color_picker_btn.color = Color.WHITE
	_color_picker_btn.tooltip_text = "Apply color/material to selected object"
	_color_picker_btn.color_changed.connect(_on_color_changed)
	_toolbar_row2.add_child(_color_picker_btn)

	var color_label = Label.new()
	color_label.text = "🎨"
	color_label.tooltip_text = "Quick color picker"
	_toolbar_row2.add_child(color_label)

	_toolbar_row2.add_child(VSeparator.new())

	# Undo / Redo
	_undo_btn = Button.new()
	_undo_btn.text = "↩ Undo"
	_undo_btn.tooltip_text = "Undo (Ctrl+Z)"
	_undo_btn.pressed.connect(_undo)
	_toolbar_row2.add_child(_undo_btn)

	_redo_btn = Button.new()
	_redo_btn.text = "↪ Redo"
	_redo_btn.tooltip_text = "Redo (Ctrl+Y)"
	_redo_btn.pressed.connect(_redo)
	_toolbar_row2.add_child(_redo_btn)

	# Focus / Reset / Drop
	_toolbar_row2.add_child(VSeparator.new())

	var focus_btn = Button.new()
	focus_btn.text = "🎯 Focus"
	focus_btn.tooltip_text = "Focus camera on selected (F)"
	focus_btn.pressed.connect(_focus_selected)
	_toolbar_row2.add_child(focus_btn)

	var reset_btn = Button.new()
	reset_btn.text = "🔄 Reset"
	reset_btn.tooltip_text = "Reset camera to default view"
	reset_btn.pressed.connect(_reset_camera)
	_toolbar_row2.add_child(reset_btn)

	var drop_btn = Button.new()
	drop_btn.text = "⬇ Floor"
	drop_btn.tooltip_text = "Drop selected object to floor (Y=0)"
	drop_btn.pressed.connect(_drop_to_floor)
	_toolbar_row2.add_child(drop_btn)

	# Spacer
	var spacer2 = Control.new()
	spacer2.size_flags_horizontal = SIZE_EXPAND_FILL
	_toolbar_row2.add_child(spacer2)

	# Help button
	var help_btn = Button.new()
	help_btn.text = "? Help"
	help_btn.tooltip_text = "Show keyboard shortcuts (F1)"
	help_btn.pressed.connect(_show_help)
	_toolbar_row2.add_child(help_btn)

	right_panel.add_child(_toolbar_row2)

	# ── STATUS BAR ──────────────────────────────────────────────────────────
	_status_label = Label.new()
	_status_label.text = "New Scene | Move"
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	right_panel.add_child(_status_label)

	# ── VIEWPORT ────────────────────────────────────────────────────────────
	_viewport_container = SubViewportContainer.new()
	_viewport_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_viewport_container.size_flags_vertical = SIZE_EXPAND_FILL
	_viewport_container.stretch = true
	_viewport_container.focus_mode = Control.FOCUS_ALL
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport_container.gui_input.connect(_on_viewport_input)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1024, 768)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.own_world_3d = true
	_viewport_container.add_child(_viewport)

	right_panel.add_child(_viewport_container)
	add_child(right_panel)

# ─────────────────────────────────────────────────────────────────────────────
# HELPER — create a labeled SpinBox row for the transform panel
# ─────────────────────────────────────────────────────────────────────────────
func _make_spin(parent: Node, axis_label: String, step: float, min_v: float, max_v: float) -> SpinBox:
	var lbl = Label.new()
	lbl.text = axis_label
	lbl.custom_minimum_size.x = 20
	lbl.add_theme_font_size_override("font_size", 12)
	if axis_label == "X":
		lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	elif axis_label == "Y":
		lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	elif axis_label == "Z":
		lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
	parent.add_child(lbl)

	var spin = SpinBox.new()
	spin.step = step
	spin.min_value = min_v
	spin.max_value = max_v
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.size_flags_horizontal = SIZE_EXPAND_FILL
	spin.custom_minimum_size.x = 70
	spin.value_changed.connect(_on_transform_value_changed)
	parent.add_child(spin)
	return spin

# ─────────────────────────────────────────────────────────────────────────────
# BUILD 3D SCENE — camera, environment, lights, grid, origin axes
# ─────────────────────────────────────────────────────────────────────────────
func _build_3d_scene() -> void:
	if not is_instance_valid(_viewport):
		return

	# Camera
	_camera = Camera3D.new()
	_camera.name = "EditorCamera"
	_camera.fov = 70
	_camera.near = 0.05
	_camera.far = 500
	_viewport.add_child(_camera)

	# Environment
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.18, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.35)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	_environment = WorldEnvironment.new()
	_environment.name = "EditorEnv"
	_environment.environment = env
	_viewport.add_child(_environment)

	# Directional light (sun)
	_sun_light = DirectionalLight3D.new()
	_sun_light.name = "EditorSun"
	_sun_light.rotation_degrees = Vector3(-45, 30, 0)
	_sun_light.light_energy = 0.8
	_sun_light.shadow_enabled = true
	_viewport.add_child(_sun_light)

	# Fill light (softer, opposite direction)
	var fill = DirectionalLight3D.new()
	fill.name = "EditorFill"
	fill.rotation_degrees = Vector3(30, -150, 0)
	fill.light_energy = 0.3
	fill.shadow_enabled = false
	_viewport.add_child(fill)

	# Grid floor
	_create_grid()

	# Origin axes
	_create_origin_axes()

	# Scene root — user objects go here
	_scene_root = Node3D.new()
	_scene_root.name = "SceneRoot"
	_viewport.add_child(_scene_root)

func _create_grid() -> void:
	_grid_mesh = MeshInstance3D.new()
	_grid_mesh.name = "EditorGrid"
	var im = ImmediateMesh.new()
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.35, 0.35, 0.35, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = false

	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var half = GRID_SIZE / 2
	for i in range(-half, half + 1):
		var fi = float(i)
		# Lines along Z
		im.surface_add_vertex(Vector3(fi, 0, -half))
		im.surface_add_vertex(Vector3(fi, 0, half))
		# Lines along X
		im.surface_add_vertex(Vector3(-half, 0, fi))
		im.surface_add_vertex(Vector3(half, 0, fi))
	im.surface_end()

	_grid_mesh.mesh = im
	_viewport.add_child(_grid_mesh)

func _create_origin_axes() -> void:
	var axes_mesh = MeshInstance3D.new()
	axes_mesh.name = "OriginAxes"
	var im = ImmediateMesh.new()

	# X axis — Red
	var mat_x = StandardMaterial3D.new()
	mat_x.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_x.albedo_color = Color(1, 0.2, 0.2)
	mat_x.no_depth_test = true
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat_x)
	im.surface_add_vertex(Vector3.ZERO)
	im.surface_add_vertex(Vector3(2, 0, 0))
	im.surface_end()

	# Y axis — Green
	var mat_y = StandardMaterial3D.new()
	mat_y.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_y.albedo_color = Color(0.2, 1, 0.2)
	mat_y.no_depth_test = true
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat_y)
	im.surface_add_vertex(Vector3.ZERO)
	im.surface_add_vertex(Vector3(0, 2, 0))
	im.surface_end()

	# Z axis — Blue
	var mat_z = StandardMaterial3D.new()
	mat_z.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_z.albedo_color = Color(0.3, 0.3, 1)
	mat_z.no_depth_test = true
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat_z)
	im.surface_add_vertex(Vector3.ZERO)
	im.surface_add_vertex(Vector3(0, 0, 2))
	im.surface_end()

	axes_mesh.mesh = im
	_viewport.add_child(axes_mesh)

# ─────────────────────────────────────────────────────────────────────────────
# GIZMO BUILD — translate/rotate/scale arrows
# ─────────────────────────────────────────────────────────────────────────────
func _build_gizmos() -> void:
	if not is_instance_valid(_viewport):
		return

	_gizmo_root = Node3D.new()
	_gizmo_root.name = "TransformGizmo"
	_gizmo_root.visible = false
	_viewport.add_child(_gizmo_root)

	# X axis arrow — Red
	var x_arrow = _create_arrow_mesh(Color(1, 0.2, 0.2), Vector3.RIGHT)
	x_arrow.name = "GizmoX"
	_gizmo_root.add_child(x_arrow)
	_gizmo_arrows.append(x_arrow)

	# Y axis arrow — Green
	var y_arrow = _create_arrow_mesh(Color(0.2, 1, 0.2), Vector3.UP)
	y_arrow.name = "GizmoY"
	_gizmo_root.add_child(y_arrow)
	_gizmo_arrows.append(y_arrow)

	# Z axis arrow — Blue
	var z_arrow = _create_arrow_mesh(Color(0.3, 0.3, 1), Vector3.BACK)
	z_arrow.name = "GizmoZ"
	_gizmo_root.add_child(z_arrow)
	_gizmo_arrows.append(z_arrow)

func _create_arrow_mesh(color: Color, direction: Vector3) -> MeshInstance3D:
	var mesh_inst = MeshInstance3D.new()
	var im = ImmediateMesh.new()
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.no_depth_test = true

	# Shaft line
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	im.surface_add_vertex(Vector3.ZERO)
	im.surface_add_vertex(direction * 1.2)
	im.surface_end()

	# Arrowhead (triangle fan → built from individual triangles)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	var tip = direction * 1.5
	var base_center = direction * 1.2
	var perp1: Vector3
	var perp2: Vector3
	if abs(direction.dot(Vector3.UP)) < 0.9:
		perp1 = direction.cross(Vector3.UP).normalized()
	else:
		perp1 = direction.cross(Vector3.RIGHT).normalized()
	perp2 = direction.cross(perp1).normalized()

	var segments := 8
	for i in range(segments):
		var angle0 = float(i) / float(segments) * TAU
		var angle1 = float(i + 1) / float(segments) * TAU
		var v0 = base_center + (perp1 * cos(angle0) + perp2 * sin(angle0)) * 0.06
		var v1 = base_center + (perp1 * cos(angle1) + perp2 * sin(angle1)) * 0.06
		im.surface_add_vertex(tip)
		im.surface_add_vertex(v0)
		im.surface_add_vertex(v1)
	im.surface_end()

	mesh_inst.mesh = im
	return mesh_inst

# ─────────────────────────────────────────────────────────────────────────────
# DARK THEME — apply dark styling to popup menus, dialogs, and file dialogs
# ─────────────────────────────────────────────────────────────────────────────
func _build_dark_scrollbar_theme() -> Theme:
	## Build a reusable Theme with dark-styled VScrollBar + HScrollBar.
	var t = Theme.new()
	# Track (background groove)
	var track = StyleBoxFlat.new()
	track.bg_color = Color(0.14, 0.14, 0.17)
	track.set_corner_radius_all(3)
	track.set_content_margin_all(2)
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("scroll", "HScrollBar", track)
	# Grabber (normal)
	var grab = StyleBoxFlat.new()
	grab.bg_color = Color(0.35, 0.35, 0.42)
	grab.set_corner_radius_all(3)
	grab.set_content_margin_all(2)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber", "HScrollBar", grab)
	# Grabber (hover)
	var grab_hl = StyleBoxFlat.new()
	grab_hl.bg_color = Color(0.45, 0.45, 0.55)
	grab_hl.set_corner_radius_all(3)
	grab_hl.set_content_margin_all(2)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab_hl)
	t.set_stylebox("grabber_highlight", "HScrollBar", grab_hl)
	# Grabber (pressed)
	var grab_pr = StyleBoxFlat.new()
	grab_pr.bg_color = Color(0.5, 0.55, 0.7)
	grab_pr.set_corner_radius_all(3)
	grab_pr.set_content_margin_all(2)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab_pr)
	t.set_stylebox("grabber_pressed", "HScrollBar", grab_pr)
	return t

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

	# 1. Set a full Theme on the popup
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
	t.set_stylebox("panel", "PopupPanel", panel_style)
	popup.theme = t

	# 2. Set local overrides (highest priority)
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
	# Embedded panel background
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.18, 0.18, 0.22)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(0.35, 0.35, 0.45)
	panel_style.set_corner_radius_all(4)
	panel_style.set_content_margin_all(8)
	dialog.add_theme_stylebox_override("embedded_border", panel_style)
	# If it's a native Godot dialog, try to force unbordered so our panel shows
	if dialog is AcceptDialog:
		var base_panel = StyleBoxFlat.new()
		base_panel.bg_color = Color(0.18, 0.18, 0.22)
		base_panel.set_content_margin_all(8)
		base_panel.set_corner_radius_all(4)
		dialog.add_theme_stylebox_override("panel", base_panel)
	dialog.add_theme_color_override("title_color", Color(0.88, 0.88, 0.88))

# ─────────────────────────────────────────────────────────────────────────────
# HELP DIALOG — keyboard shortcuts overlay (F1)
# ─────────────────────────────────────────────────────────────────────────────
func _build_help_dialog() -> void:
	_help_dialog = AcceptDialog.new()
	_help_dialog.title = "🎮 VG 3D Scene Editor — Keyboard Shortcuts"
	_help_dialog.min_size = Vector2(480, 600)
	_style_dialog_dark(_help_dialog)
	_help_dialog.dialog_text = """CAMERA CONTROLS
  Middle Mouse Drag    Orbit camera
  Shift + MMB Drag     Pan camera
  Right Mouse Drag     Orbit camera (alt)
  Mouse Wheel          Zoom in/out

LAPTOP / TRACKPAD
  Alt + Left Drag      Orbit camera
  Alt + Shift + Left   Pan camera
  Two-finger swipe     Orbit camera
  Shift + swipe        Pan camera
  Pinch                Zoom in/out

TOOLS
  W                    Move mode
  E                    Rotate mode
  R                    Scale mode
  F                    Focus on selected
  G                    Toggle grid

EDITING
  Double-click         Jump to VG code for object
  Ctrl+D               Duplicate selected
  Ctrl+Z               Undo
  Ctrl+Y               Redo
  Ctrl+S               Save scene
  Delete / Backspace   Delete selected
  F2                   Rename selected node
  Right-click          Context menu (incl. View Code)

CAMERA PRESETS (Numpad)
  7                    Top view
  Ctrl+7               Bottom view
  1                    Front view
  Ctrl+1               Back view
  3                    Right view
  Ctrl+3               Left view
  5                    Toggle Ortho/Perspective

VIEW
  View Mode button     Solid / Wireframe / Unshaded / Overdraw
  Local/World button   Toggle gizmo transform space
  Color picker         Apply material color to selected"""
	add_child(_help_dialog)

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

# ─────────────────────────────────────────────────────────────────────────────
# CAMERA CONTROL
# ─────────────────────────────────────────────────────────────────────────────
func _update_camera() -> void:
	if not is_instance_valid(_camera):
		return
	# Clamp pitch (allow near-poles for presets)
	_orbit_pitch = clampf(_orbit_pitch, -PI * 0.499, PI * 0.499)
	_orbit_distance = clampf(_orbit_distance, MIN_DISTANCE, MAX_DISTANCE)

	# Spherical to cartesian
	var offset = Vector3(
		_orbit_distance * cos(_orbit_pitch) * sin(_orbit_yaw),
		_orbit_distance * sin(-_orbit_pitch),
		_orbit_distance * cos(_orbit_pitch) * cos(_orbit_yaw)
	)
	_camera.position = _orbit_target + offset

	# Handle degenerate up vector for top/bottom views
	var up = Vector3.UP
	if _orbit_pitch < -PI * 0.45:
		up = Vector3(0, 0, -1)
	elif _orbit_pitch > PI * 0.45:
		up = Vector3(0, 0, 1)
	_camera.look_at(_orbit_target, up)

	# Orthographic projection
	if _is_orthographic:
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_camera.size = _orbit_distance * 1.0
	else:
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE

func _reset_camera() -> void:
	_orbit_yaw = -0.5
	_orbit_pitch = -0.4
	_orbit_distance = DEFAULT_DISTANCE
	_orbit_target = Vector3.ZERO
	_is_orthographic = false
	if is_instance_valid(_ortho_btn):
		_ortho_btn.text = "Persp"
	_update_camera()

func _focus_selected() -> void:
	if is_instance_valid(_selected_node):
		_orbit_target = _selected_node.global_position
		_orbit_distance = 5.0
		_update_camera()

func _set_camera_preset(preset: String) -> void:
	match preset:
		"perspective":
			_orbit_yaw = -0.5
			_orbit_pitch = -0.4
			_orbit_distance = DEFAULT_DISTANCE
			_is_orthographic = false
		"top":
			_orbit_yaw = 0.0
			_orbit_pitch = -PI * 0.499
			_is_orthographic = true
		"bottom":
			_orbit_yaw = 0.0
			_orbit_pitch = PI * 0.499
			_is_orthographic = true
		"front":
			_orbit_yaw = 0.0
			_orbit_pitch = 0.0
			_is_orthographic = true
		"back":
			_orbit_yaw = PI
			_orbit_pitch = 0.0
			_is_orthographic = true
		"left":
			_orbit_yaw = -PI * 0.5
			_orbit_pitch = 0.0
			_is_orthographic = true
		"right":
			_orbit_yaw = PI * 0.5
			_orbit_pitch = 0.0
			_is_orthographic = true

	if is_instance_valid(_ortho_btn):
		_ortho_btn.text = "Ortho" if _is_orthographic else "Persp"
	_update_camera()

func _toggle_ortho() -> void:
	_is_orthographic = not _is_orthographic
	if is_instance_valid(_ortho_btn):
		_ortho_btn.text = "Ortho" if _is_orthographic else "Persp"
	_update_camera()

func _on_camera_preset_selected(id: int) -> void:
	match id:
		0: _set_camera_preset("perspective")
		1: _set_camera_preset("top")
		2: _set_camera_preset("bottom")
		3: _set_camera_preset("front")
		4: _set_camera_preset("back")
		5: _set_camera_preset("left")
		6: _set_camera_preset("right")

# ─────────────────────────────────────────────────────────────────────────────
# VIEWPORT INPUT HANDLING
# ─────────────────────────────────────────────────────────────────────────────
func _on_viewport_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventPanGesture:
		_handle_pan_gesture(event)
	elif event is InputEventMagnifyGesture:
		_handle_magnify_gesture(event)
	elif event is InputEventKey:
		_handle_key(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	# Grab focus on any click
	if is_instance_valid(_viewport_container):
		_viewport_container.grab_focus()

	match event.button_index:
		MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_last_mouse_pos = event.position
				if event.shift_pressed:
					_panning = true
					_orbiting = false
				else:
					_orbiting = true
					_panning = false
			else:
				_orbiting = false
				_panning = false

		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_orbit_distance -= ZOOM_SPEED * (_orbit_distance * 0.1)
				_update_camera()

		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_orbit_distance += ZOOM_SPEED * (_orbit_distance * 0.1)
				_update_camera()

		MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Alt+LMB = orbit, Alt+Shift+LMB = pan  (laptop / no-MMB)
				if event.alt_pressed:
					_last_mouse_pos = event.position
					if event.shift_pressed:
						_alt_panning = true
						_alt_orbiting = false
					else:
						_alt_orbiting = true
						_alt_panning = false
					return
				# Double-click detection — jump to VG code (like form designer)
				if event.double_click:
					_pick_and_select(event.position)
					if is_instance_valid(_selected_node) and _selected_node != _scene_root:
						node_double_clicked.emit(_selected_node)
					return
				# Check gizmo hit first
				if _selected_node and _gizmo_root.visible:
					var axis = _gizmo_hit_test(event.position)
					if axis >= 0:
						_gizmo_dragging = true
						_gizmo_axis = axis
						_gizmo_drag_start = event.position
						_gizmo_drag_origin = _selected_node.global_position if _gizmo_mode == GizmoMode.TRANSLATE else Vector3.ZERO
						if _gizmo_mode == GizmoMode.SCALE:
							_gizmo_drag_origin = _selected_node.scale
						# Record transform for undo
						_drag_transform_before = {
							pos = _selected_node.position,
							rot = _selected_node.rotation,
							scl = _selected_node.scale
						}
						return
				# Otherwise, do click-to-select via AABB picking
				_pick_and_select(event.position)
			else:
				_alt_orbiting = false
				_alt_panning = false
				if _gizmo_dragging:
					_gizmo_dragging = false
					_scene_dirty = true
					# Push undo for the completed drag
					if is_instance_valid(_selected_node) and _drag_transform_before.size() > 0:
						var after = {
							pos = _selected_node.position,
							rot = _selected_node.rotation,
							scl = _selected_node.scale
						}
						_push_undo({
							type = "transform",
							node_ref = _selected_node,
							before = _drag_transform_before,
							after = after
						})
						_drag_transform_before = {}

		MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_last_mouse_pos = event.position
				_rmb_press_pos = event.position
				_orbiting = true
			else:
				_orbiting = false
				# If barely moved, show context menu instead of orbit
				if event.position.distance_to(_rmb_press_pos) < 5.0:
					_show_viewport_context_menu(event.position)

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _orbiting or _alt_orbiting:
		var delta = event.position - _last_mouse_pos
		_last_mouse_pos = event.position
		_orbit_yaw += delta.x * ORBIT_SPEED
		_orbit_pitch += delta.y * ORBIT_SPEED
		_update_camera()
	elif _panning or _alt_panning:
		var delta = event.position - _last_mouse_pos
		_last_mouse_pos = event.position
		var cam_right = _camera.global_basis.x
		var cam_up = _camera.global_basis.y
		_orbit_target -= cam_right * delta.x * PAN_SPEED * (_orbit_distance * 0.01)
		_orbit_target += cam_up * delta.y * PAN_SPEED * (_orbit_distance * 0.01)
		_update_camera()
	elif _gizmo_dragging:
		_handle_gizmo_drag(event.position)

func _handle_pan_gesture(event: InputEventPanGesture) -> void:
	# Trackpad two-finger swipe:  Shift → pan,  otherwise → orbit
	if event.shift_pressed or event.alt_pressed:
		var cam_right = _camera.global_basis.x
		var cam_up = _camera.global_basis.y
		_orbit_target += cam_right * event.delta.x * PAN_SPEED * (_orbit_distance * 0.04)
		_orbit_target -= cam_up * event.delta.y * PAN_SPEED * (_orbit_distance * 0.04)
	else:
		_orbit_yaw += event.delta.x * ORBIT_SPEED * 4.0
		_orbit_pitch += event.delta.y * ORBIT_SPEED * 4.0
	_update_camera()

func _handle_magnify_gesture(event: InputEventMagnifyGesture) -> void:
	# Trackpad pinch-to-zoom
	if event.factor < 1.0:
		_orbit_distance += ZOOM_SPEED * (_orbit_distance * 0.1)
	else:
		_orbit_distance -= ZOOM_SPEED * (_orbit_distance * 0.1)
	_update_camera()

func _handle_key(event: InputEventKey) -> void:
	if not event.pressed:
		return

	# Ctrl+key shortcuts
	if event.ctrl_pressed:
		match event.keycode:
			KEY_Z:
				_undo()
				return
			KEY_Y:
				_redo()
				return
			KEY_D:
				_duplicate_selected()
				return
			KEY_S:
				_save_scene()
				return
			KEY_KP_7:
				_set_camera_preset("bottom")
				return
			KEY_KP_1:
				_set_camera_preset("back")
				return
			KEY_KP_3:
				_set_camera_preset("left")
				return

	# Regular key shortcuts
	match event.keycode:
		KEY_W:
			_set_gizmo_mode(GizmoMode.TRANSLATE)
		KEY_E:
			_set_gizmo_mode(GizmoMode.ROTATE)
		KEY_R:
			_set_gizmo_mode(GizmoMode.SCALE)
		KEY_F:
			_focus_selected()
		KEY_G:
			_toggle_grid()
		KEY_DELETE, KEY_BACKSPACE:
			_on_delete_selected()
		KEY_F1:
			_show_help()
		KEY_F2:
			_rename_selected()
		KEY_KP_7:
			_set_camera_preset("top")
		KEY_KP_1:
			_set_camera_preset("front")
		KEY_KP_3:
			_set_camera_preset("right")
		KEY_KP_5:
			_toggle_ortho()

# ─────────────────────────────────────────────────────────────────────────────
# RAYCAST SELECTION
# ─────────────────────────────────────────────────────────────────────────────
## Iterative pick — avoids GDScript ref limitations.
func _do_pick(ray_origin: Vector3, ray_dir: Vector3) -> Node3D:
	if not is_instance_valid(_scene_root):
		return null
	var best_node: Node3D = null
	var best_dist: float = INF
	var stack: Array = [_scene_root]
	while stack.size() > 0:
		var node = stack.pop_back()
		if node is Node3D and node != _scene_root:
			var aabb: AABB = _get_node_aabb(node)
			if aabb.size != Vector3.ZERO:
				var hit = _ray_aabb_intersect(ray_origin, ray_dir, aabb)
				if hit >= 0.0 and hit < best_dist:
					best_dist = hit
					best_node = node
		for child in node.get_children():
			stack.push_back(child)
	return best_node

func _get_node_aabb(node: Node3D) -> AABB:
	if node is VisualInstance3D:
		return node.get_aabb().abs()
	# For non-visual nodes (lights, cameras, etc.) use a small box
	return AABB(node.global_position - Vector3(0.3, 0.3, 0.3), Vector3(0.6, 0.6, 0.6))

func _ray_aabb_intersect(origin: Vector3, dir: Vector3, aabb: AABB) -> float:
	# Slab method intersection test
	var t_min := -INF
	var t_max := INF
	var pos = aabb.position
	var end_pt = aabb.end

	for i in range(3):
		if abs(dir[i]) < 1e-8:
			if origin[i] < pos[i] or origin[i] > end_pt[i]:
				return -1.0
		else:
			var t1 = (pos[i] - origin[i]) / dir[i]
			var t2 = (end_pt[i] - origin[i]) / dir[i]
			if t1 > t2:
				var tmp = t1
				t1 = t2
				t2 = tmp
			t_min = maxf(t_min, t1)
			t_max = minf(t_max, t2)
			if t_min > t_max:
				return -1.0
	if t_max < 0:
		return -1.0
	return t_min if t_min >= 0 else t_max

## Click-to-select via AABB raycasting against all scene children.
func _pick_and_select(screen_pos: Vector2) -> void:
	if not is_instance_valid(_camera) or not is_instance_valid(_viewport):
		return

	var ray_origin = _camera.project_ray_origin(screen_pos)
	var ray_dir = _camera.project_ray_normal(screen_pos)

	var hit_node = _do_pick(ray_origin, ray_dir)
	if hit_node:
		_select_node(hit_node)
	else:
		_deselect()

# ─────────────────────────────────────────────────────────────────────────────
# SELECTION MANAGEMENT
# ─────────────────────────────────────────────────────────────────────────────
func _select_node(node: Node3D) -> void:
	_selected_node = node
	_update_selection_highlight()
	_update_gizmo_position()
	_gizmo_root.visible = true
	_sync_scene_tree_selection()
	_update_transform_panel()
	if _node_inspector:
		_node_inspector.inspect(node)
	_update_status()
	node_selected.emit(node)

func _deselect() -> void:
	_selected_node = null
	_gizmo_root.visible = false
	_clear_selection_highlight()
	_sync_scene_tree_selection()
	_clear_transform_panel()
	if _node_inspector:
		_node_inspector.clear()
	_update_status()
	selection_cleared.emit()

func _update_selection_highlight() -> void:
	_clear_selection_highlight()
	if not is_instance_valid(_selected_node):
		return

	# Create an orange wireframe box around the selected node
	_selection_wireframe = MeshInstance3D.new()
	_selection_wireframe.name = "_SelectionHighlight"
	var aabb = _get_node_aabb(_selected_node)
	if aabb.size == Vector3.ZERO:
		aabb = AABB(Vector3(-0.3, -0.3, -0.3), Vector3(0.6, 0.6, 0.6))

	var im = ImmediateMesh.new()
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.6, 0.1, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.no_depth_test = true

	# Draw wireframe box edges
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var p = aabb.position
	var s = aabb.size
	var corners = [
		p,
		p + Vector3(s.x, 0, 0),
		p + Vector3(s.x, 0, s.z),
		p + Vector3(0, 0, s.z),
		p + Vector3(0, s.y, 0),
		p + Vector3(s.x, s.y, 0),
		p + Vector3(s.x, s.y, s.z),
		p + Vector3(0, s.y, s.z),
	]
	# Bottom face
	for i in [0, 1, 1, 2, 2, 3, 3, 0]:
		im.surface_add_vertex(corners[i])
	# Top face
	for i in [4, 5, 5, 6, 6, 7, 7, 4]:
		im.surface_add_vertex(corners[i])
	# Verticals
	for i in range(4):
		im.surface_add_vertex(corners[i])
		im.surface_add_vertex(corners[i + 4])
	im.surface_end()

	_selection_wireframe.mesh = im
	# Parent to selected node so it moves with it
	_selected_node.add_child(_selection_wireframe)

func _clear_selection_highlight() -> void:
	if is_instance_valid(_selection_wireframe):
		_selection_wireframe.queue_free()
		_selection_wireframe = null

# ─────────────────────────────────────────────────────────────────────────────
# GIZMO INTERACTION
# ─────────────────────────────────────────────────────────────────────────────
func _set_gizmo_mode(mode: GizmoMode) -> void:
	_gizmo_mode = mode
	if is_instance_valid(_gizmo_mode_btn_translate):
		_gizmo_mode_btn_translate.button_pressed = (mode == GizmoMode.TRANSLATE)
	if is_instance_valid(_gizmo_mode_btn_rotate):
		_gizmo_mode_btn_rotate.button_pressed = (mode == GizmoMode.ROTATE)
	if is_instance_valid(_gizmo_mode_btn_scale):
		_gizmo_mode_btn_scale.button_pressed = (mode == GizmoMode.SCALE)
	_update_status()

func _update_gizmo_position() -> void:
	if is_instance_valid(_selected_node) and is_instance_valid(_gizmo_root):
		_gizmo_root.global_position = _selected_node.global_position
		# In local space, rotate the gizmo to match the node
		if _local_space:
			_gizmo_root.global_rotation = _selected_node.global_rotation
		else:
			_gizmo_root.rotation = Vector3.ZERO

func _gizmo_hit_test(screen_pos: Vector2) -> int:
	if not is_instance_valid(_camera) or not is_instance_valid(_gizmo_root):
		return -1

	var ray_origin = _camera.project_ray_origin(screen_pos)
	var ray_dir = _camera.project_ray_normal(screen_pos)
	var gizmo_pos = _gizmo_root.global_position

	# Test against each axis — simple distance-to-line check
	var axes: Array[Vector3]
	if _local_space and is_instance_valid(_selected_node):
		axes = [
			_selected_node.global_basis.x.normalized(),
			_selected_node.global_basis.y.normalized(),
			_selected_node.global_basis.z.normalized()
		]
	else:
		axes = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]

	var best_axis := -1
	var best_dist := 0.25  # threshold in world units

	for i in range(3):
		var axis_end = gizmo_pos + axes[i] * 1.5
		var dist = _point_line_distance(ray_origin, ray_dir, gizmo_pos, axis_end)
		if dist < best_dist:
			best_dist = dist
			best_axis = i

	return best_axis

func _point_line_distance(ray_origin: Vector3, ray_dir: Vector3, p1: Vector3, p2: Vector3) -> float:
	# Distance between two lines (ray and the gizmo axis line)
	var u = ray_dir.normalized()
	var v = (p2 - p1).normalized()
	var w = ray_origin - p1

	var a = u.dot(u)
	var b = u.dot(v)
	var c = v.dot(v)
	var d = u.dot(w)
	var e = v.dot(w)
	var denom = a * c - b * b
	if abs(denom) < 1e-8:
		return INF

	var sc = (b * e - c * d) / denom
	var tc = (a * e - b * d) / denom

	# Clamp tc to the gizmo axis length
	tc = clampf(tc, 0.0, 1.5)
	if sc < 0:
		return INF  # Behind camera

	var closest_on_ray = ray_origin + u * sc
	var closest_on_axis = p1 + v * tc
	return closest_on_ray.distance_to(closest_on_axis)

func _handle_gizmo_drag(screen_pos: Vector2) -> void:
	if not is_instance_valid(_selected_node) or not is_instance_valid(_camera):
		return

	var delta_pixels = screen_pos - _gizmo_drag_start

	# Determine axis direction based on local/world space
	var axes: Array[Vector3]
	if _local_space:
		axes = [
			_selected_node.global_basis.x.normalized(),
			_selected_node.global_basis.y.normalized(),
			_selected_node.global_basis.z.normalized()
		]
	else:
		axes = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var axis = axes[_gizmo_axis]

	if _gizmo_mode == GizmoMode.TRANSLATE:
		# Project axis direction to screen to determine movement
		var world_pos = _selected_node.global_position
		var screen_start = _camera.unproject_position(world_pos)
		var screen_axis_end = _camera.unproject_position(world_pos + axis)
		var screen_axis_dir = (screen_axis_end - screen_start)
		if screen_axis_dir.length() < 1e-4:
			return
		screen_axis_dir = screen_axis_dir.normalized()

		# Project pixel delta onto axis direction
		var movement = delta_pixels.dot(screen_axis_dir) * 0.02 * (_orbit_distance * 0.1)
		if _snap_enabled:
			movement = snapped(movement, _snap_value)

		var new_pos = _gizmo_drag_origin + axis * movement
		_selected_node.global_position = new_pos

	elif _gizmo_mode == GizmoMode.ROTATE:
		var angle = delta_pixels.x * 0.01
		if _snap_enabled:
			angle = snapped(angle, deg_to_rad(15))
		var current_rot = _selected_node.rotation
		current_rot[_gizmo_axis] = angle
		_selected_node.rotation = current_rot

	elif _gizmo_mode == GizmoMode.SCALE:
		var scale_factor = 1.0 + delta_pixels.x * 0.005
		var new_scale = _gizmo_drag_origin
		new_scale[_gizmo_axis] = _gizmo_drag_origin[_gizmo_axis] * scale_factor
		if _snap_enabled:
			new_scale[_gizmo_axis] = snapped(new_scale[_gizmo_axis], _snap_value)
		_selected_node.scale = new_scale

	_update_gizmo_position()
	_update_selection_highlight()
	_update_transform_panel()
	_scene_dirty = true

# ─────────────────────────────────────────────────────────────────────────────
# UNDO / REDO
# ─────────────────────────────────────────────────────────────────────────────
func _push_undo(action: Dictionary) -> void:
	_undo_stack.push_back(action)
	if _undo_stack.size() > MAX_UNDO:
		var old = _undo_stack.pop_front()
		_cleanup_undo_action(old)
	# Clear redo stack
	for a in _redo_stack:
		_cleanup_undo_action(a)
	_redo_stack.clear()
	_update_status()

func _cleanup_undo_action(action: Dictionary) -> void:
	if action.has("stored_node") and is_instance_valid(action.stored_node):
		action.stored_node.free()

func _undo() -> void:
	if _undo_stack.is_empty():
		return
	var action = _undo_stack.pop_back()
	match action.type:
		"transform":
			var node = action.get("node_ref")
			if is_instance_valid(node):
				node.position = action.before.pos
				node.rotation = action.before.rot
				node.scale = action.before.scl
				if _selected_node == node:
					_update_gizmo_position()
					_update_selection_highlight()
					_update_transform_panel()
		"add":
			var node = action.get("node_ref")
			if is_instance_valid(node):
				action.stored_node = node.duplicate()
				if _selected_node == node:
					_deselect()
				node.queue_free()
				_rebuild_scene_tree()
		"delete":
			if action.has("stored_node") and is_instance_valid(action.stored_node):
				var restored = action.stored_node.duplicate()
				_scene_root.add_child(restored)
				action.node_ref = restored
				_select_node(restored)
				_rebuild_scene_tree()
		"color":
			var node = action.get("node_ref")
			if is_instance_valid(node) and node is GeometryInstance3D:
				node.material_override = action.get("before_mat")

	_redo_stack.push_back(action)
	_scene_dirty = true
	_update_status()

func _redo() -> void:
	if _redo_stack.is_empty():
		return
	var action = _redo_stack.pop_back()
	match action.type:
		"transform":
			var node = action.get("node_ref")
			if is_instance_valid(node):
				node.position = action.after.pos
				node.rotation = action.after.rot
				node.scale = action.after.scl
				if _selected_node == node:
					_update_gizmo_position()
					_update_selection_highlight()
					_update_transform_panel()
		"add":
			if action.has("stored_node") and is_instance_valid(action.stored_node):
				var restored = action.stored_node.duplicate()
				_scene_root.add_child(restored)
				action.node_ref = restored
				_select_node(restored)
				_rebuild_scene_tree()
		"delete":
			var node = action.get("node_ref")
			if is_instance_valid(node):
				action.stored_node = node.duplicate()
				if _selected_node == node:
					_deselect()
				node.queue_free()
				_rebuild_scene_tree()
		"color":
			var node = action.get("node_ref")
			if is_instance_valid(node) and node is GeometryInstance3D:
				node.material_override = action.get("after_mat")

	_undo_stack.push_back(action)
	_scene_dirty = true
	_update_status()

# ─────────────────────────────────────────────────────────────────────────────
# CONTEXT MENU HANDLERS
# ─────────────────────────────────────────────────────────────────────────────
func _show_viewport_context_menu(viewport_pos: Vector2) -> void:
	# Do a pick first to select whatever is under the cursor
	_pick_and_select(viewport_pos)

	var items: Array = []
	if is_instance_valid(_selected_node) and _selected_node != _scene_root:
		items.append({"text": "📝 View Code  (DblClick)", "id": 16})
		items.append({"separator": true})
		items.append({"text": "Duplicate    (Ctrl+D)", "id": 10})
		items.append({"text": "Delete        (Del)", "id": 11})
		items.append({"text": "Focus          (F)", "id": 12})
		items.append({"text": "Drop to Floor", "id": 13})
		items.append({"text": "Reset Transform", "id": 14})
		items.append({"text": "Toggle Visibility", "id": 15})
		items.append({"separator": true})

	items.append({"text": "Add Box", "id": 0})
	items.append({"text": "Add Sphere", "id": 1})
	items.append({"text": "Add Cylinder", "id": 2})
	items.append({"text": "Add Light", "id": 3})
	items.append({"text": "Add Camera", "id": 4})
	items.append({"text": "Add Node3D", "id": 5})
	items.append({"separator": true})
	items.append({"text": "📦 Import Model...", "id": 20})
	items.append({"text": "🌍 Add Environment...", "id": 21})

	_show_dark_popup_menu(items, _on_context_menu_selected)

func _on_context_menu_selected(id: int) -> void:
	match id:
		0: _add_3d_object("CSGBox3D", "Box")
		1: _add_3d_object("CSGSphere3D", "Sphere")
		2: _add_3d_object("CSGCylinder3D", "Cylinder")
		3: _add_3d_object("OmniLight3D", "Light")
		4: _add_3d_object("Camera3D", "Camera")
		5: _add_3d_object("Node3D", "Node3D")
		10: _duplicate_selected()
		11: _on_delete_selected()
		12: _focus_selected()
		13: _drop_to_floor()
		14: _reset_transform()
		15: _toggle_visibility_selected()
		16:
			if is_instance_valid(_selected_node):
				view_code_requested.emit(_selected_node)
		20: _show_import_model_dialog()
		21: _show_env_preset_popup()

func _on_scene_tree_rmb(position: Vector2, button: int) -> void:
	if button != MOUSE_BUTTON_RIGHT:
		return
	_show_tree_context_menu()

func _show_tree_context_menu() -> void:
	var items: Array = []
	if is_instance_valid(_selected_node) and _selected_node != _scene_root:
		items.append({"text": "📝 View Code", "id": 6})
		items.append({"separator": true})
		items.append({"text": "Rename (F2)", "id": 0})
		items.append({"text": "Duplicate", "id": 1})
		items.append({"text": "Delete", "id": 2})
		items.append({"separator": true})
		items.append({"text": "Toggle Visibility", "id": 3})
		items.append({"text": "Drop to Floor", "id": 4})
		items.append({"text": "Reset Transform", "id": 5})
	else:
		items.append({"text": "Add Box", "id": 10})
		items.append({"text": "Add Node3D", "id": 11})

	_show_dark_popup_menu(items, _on_tree_context_menu_selected)

func _on_tree_context_menu_selected(id: int) -> void:
	match id:
		0: _rename_selected()
		1: _duplicate_selected()
		2: _on_delete_selected()
		3: _toggle_visibility_selected()
		4: _drop_to_floor()
		5: _reset_transform()
		6:
			if is_instance_valid(_selected_node):
				view_code_requested.emit(_selected_node)
		10: _add_3d_object("CSGBox3D", "Box")
		11: _add_3d_object("Node3D", "Node3D")

# ─────────────────────────────────────────────────────────────────────────────
# TRANSFORM PANEL — sync SpinBoxes with selected node
# ─────────────────────────────────────────────────────────────────────────────
func _update_transform_panel() -> void:
	if not is_instance_valid(_selected_node):
		return
	if not is_instance_valid(_pos_x):
		return
	_pos_x.set_value_no_signal(snapped(_selected_node.position.x, 0.001))
	_pos_y.set_value_no_signal(snapped(_selected_node.position.y, 0.001))
	_pos_z.set_value_no_signal(snapped(_selected_node.position.z, 0.001))
	_rot_x.set_value_no_signal(snapped(rad_to_deg(_selected_node.rotation.x), 0.01))
	_rot_y.set_value_no_signal(snapped(rad_to_deg(_selected_node.rotation.y), 0.01))
	_rot_z.set_value_no_signal(snapped(rad_to_deg(_selected_node.rotation.z), 0.01))
	_scl_x.set_value_no_signal(snapped(_selected_node.scale.x, 0.001))
	_scl_y.set_value_no_signal(snapped(_selected_node.scale.y, 0.001))
	_scl_z.set_value_no_signal(snapped(_selected_node.scale.z, 0.001))

func _clear_transform_panel() -> void:
	if not is_instance_valid(_pos_x):
		return
	_pos_x.set_value_no_signal(0)
	_pos_y.set_value_no_signal(0)
	_pos_z.set_value_no_signal(0)
	_rot_x.set_value_no_signal(0)
	_rot_y.set_value_no_signal(0)
	_rot_z.set_value_no_signal(0)
	_scl_x.set_value_no_signal(1)
	_scl_y.set_value_no_signal(1)
	_scl_z.set_value_no_signal(1)

func _on_transform_value_changed(_value: float) -> void:
	if not is_instance_valid(_selected_node):
		return
	if not is_instance_valid(_pos_x):
		return
	_selected_node.position = Vector3(_pos_x.value, _pos_y.value, _pos_z.value)
	_selected_node.rotation = Vector3(
		deg_to_rad(_rot_x.value),
		deg_to_rad(_rot_y.value),
		deg_to_rad(_rot_z.value)
	)
	_selected_node.scale = Vector3(_scl_x.value, _scl_y.value, _scl_z.value)
	_update_gizmo_position()
	_update_selection_highlight()
	_scene_dirty = true

# ─────────────────────────────────────────────────────────────────────────────
# EXTRAS — color, drop, rename, visibility, view mode, local/world, help
# ─────────────────────────────────────────────────────────────────────────────
func _on_color_changed(color: Color) -> void:
	_apply_color_to_selected(color)

func _apply_color_to_selected(color: Color) -> void:
	if not is_instance_valid(_selected_node):
		return
	if _selected_node is GeometryInstance3D:
		var before_mat = _selected_node.material_override
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		_selected_node.material_override = mat
		_push_undo({
			type = "color",
			node_ref = _selected_node,
			before_mat = before_mat,
			after_mat = mat
		})
		_scene_dirty = true

func _drop_to_floor() -> void:
	if not is_instance_valid(_selected_node) or _selected_node == _scene_root:
		return
	var before = {
		pos = _selected_node.position,
		rot = _selected_node.rotation,
		scl = _selected_node.scale
	}
	var aabb = _get_node_aabb(_selected_node)
	# Move so the bottom of the AABB touches Y=0
	_selected_node.position.y = -aabb.position.y
	var after = {
		pos = _selected_node.position,
		rot = _selected_node.rotation,
		scl = _selected_node.scale
	}
	_push_undo({type = "transform", node_ref = _selected_node, before = before, after = after})
	_update_gizmo_position()
	_update_selection_highlight()
	_update_transform_panel()
	_scene_dirty = true

func _reset_transform() -> void:
	if not is_instance_valid(_selected_node) or _selected_node == _scene_root:
		return
	var before = {
		pos = _selected_node.position,
		rot = _selected_node.rotation,
		scl = _selected_node.scale
	}
	_selected_node.position = Vector3.ZERO
	_selected_node.rotation = Vector3.ZERO
	_selected_node.scale = Vector3.ONE
	var after = {pos = Vector3.ZERO, rot = Vector3.ZERO, scl = Vector3.ONE}
	_push_undo({type = "transform", node_ref = _selected_node, before = before, after = after})
	_update_gizmo_position()
	_update_selection_highlight()
	_update_transform_panel()
	_scene_dirty = true

func _rename_selected() -> void:
	if not is_instance_valid(_selected_node) or _selected_node == _scene_root:
		return
	var dialog = AcceptDialog.new()
	dialog.title = "Rename Node"
	dialog.min_size = Vector2(320, 100)
	_style_dialog_dark(dialog)
	var line_edit = LineEdit.new()
	line_edit.text = _selected_node.name
	line_edit.select_all()
	line_edit.custom_minimum_size.x = 280
	dialog.add_child(line_edit)
	dialog.register_text_enter(line_edit)
	var node_ref = _selected_node
	dialog.confirmed.connect(func():
		var new_name = line_edit.text.strip_edges()
		if not new_name.is_empty() and is_instance_valid(node_ref):
			node_ref.name = new_name
			_rebuild_scene_tree()
			_update_status()
		dialog.queue_free()
	)
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered()
	line_edit.grab_focus()

func _toggle_visibility_selected() -> void:
	if not is_instance_valid(_selected_node) or _selected_node == _scene_root:
		return
	_selected_node.visible = not _selected_node.visible
	_rebuild_scene_tree()

func _duplicate_selected() -> void:
	if not is_instance_valid(_selected_node) or _selected_node == _scene_root:
		return
	var dup = _selected_node.duplicate()
	dup.name = _unique_name(_selected_node.name)
	dup.position += Vector3(1, 0, 0)  # Offset slightly
	_selected_node.get_parent().add_child(dup)
	_push_undo({type = "add", node_ref = dup})
	_select_node(dup)
	_rebuild_scene_tree()
	_scene_dirty = true
	print("[VG3D] Duplicated to: ", dup.name)

func _cycle_view_mode() -> void:
	_view_mode = (_view_mode + 1) % 4 as ViewMode
	if not is_instance_valid(_viewport):
		return
	match _view_mode:
		ViewMode.SOLID:
			_viewport.debug_draw = Viewport.DEBUG_DRAW_DISABLED
			if is_instance_valid(_view_mode_btn):
				_view_mode_btn.text = "🔲 Solid"
		ViewMode.WIREFRAME:
			_viewport.debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
			if is_instance_valid(_view_mode_btn):
				_view_mode_btn.text = "📐 Wire"
		ViewMode.UNSHADED:
			_viewport.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
			if is_instance_valid(_view_mode_btn):
				_view_mode_btn.text = "💡 Unshaded"
		ViewMode.OVERDRAW:
			_viewport.debug_draw = Viewport.DEBUG_DRAW_OVERDRAW
			if is_instance_valid(_view_mode_btn):
				_view_mode_btn.text = "🔴 Overdraw"

func _toggle_local_world() -> void:
	_local_space = not _local_space
	if is_instance_valid(_local_world_btn):
		_local_world_btn.text = "📍 Local" if _local_space else "🌐 World"
	_update_gizmo_position()

func _toggle_grid() -> void:
	if is_instance_valid(_grid_mesh):
		_grid_mesh.visible = not _grid_mesh.visible

func _show_help() -> void:
	if is_instance_valid(_help_dialog):
		_help_dialog.popup_centered()

# ─────────────────────────────────────────────────────────────────────────────
# TOOLBOX
# ─────────────────────────────────────────────────────────────────────────────
func _populate_toolbox() -> void:
	if not is_instance_valid(_toolbox_list):
		return
	_toolbox_list.clear()
	for item in _toolbox_items:
		_toolbox_list.add_item(item.icon + " " + item.name)

func _on_toolbox_item_activated(index: int) -> void:
	if index < 0 or index >= _toolbox_items.size():
		return
	var item = _toolbox_items[index]
	_add_3d_object(item.type, item.name)

func _on_add_object_btn_pressed() -> void:
	if not is_instance_valid(_toolbox_list):
		return
	var selected = _toolbox_list.get_selected_items()
	if selected.size() == 0:
		# Nothing selected — add the first item (Box) as default
		_on_toolbox_item_activated(0)
	else:
		_on_toolbox_item_activated(selected[0])

func _add_3d_object(type_name: String, display_name: String) -> void:
	if not is_instance_valid(_scene_root):
		return

	var node: Node3D = null

	match type_name:
		"CSGBox3D":
			node = CSGBox3D.new()
			node.name = _unique_name("Box")
		"CSGSphere3D":
			node = CSGSphere3D.new()
			node.name = _unique_name("Sphere")
		"CSGCylinder3D":
			node = CSGCylinder3D.new()
			node.name = _unique_name("Cylinder")
		"MeshInstance3D":
			node = MeshInstance3D.new()
			node.mesh = BoxMesh.new()
			node.name = _unique_name("Mesh")
		"OmniLight3D":
			node = OmniLight3D.new()
			node.name = _unique_name("OmniLight")
			node.light_energy = 2.0
			node.omni_range = 10.0
		"SpotLight3D":
			node = SpotLight3D.new()
			node.name = _unique_name("SpotLight")
		"DirectionalLight3D":
			node = DirectionalLight3D.new()
			node.name = _unique_name("DirLight")
			node.rotation_degrees = Vector3(-45, 0, 0)
		"Camera3D":
			node = Camera3D.new()
			node.name = _unique_name("Camera")
		"RigidBody3D":
			node = RigidBody3D.new()
			node.name = _unique_name("RigidBody")
			var col_shape = CollisionShape3D.new()
			col_shape.shape = BoxShape3D.new()
			node.add_child(col_shape)
			var mesh_i = MeshInstance3D.new()
			mesh_i.mesh = BoxMesh.new()
			node.add_child(mesh_i)
		"StaticBody3D":
			node = StaticBody3D.new()
			node.name = _unique_name("StaticBody")
			var col_shape = CollisionShape3D.new()
			col_shape.shape = BoxShape3D.new()
			node.add_child(col_shape)
			var mesh_i = MeshInstance3D.new()
			mesh_i.mesh = BoxMesh.new()
			node.add_child(mesh_i)
		"CharacterBody3D":
			node = CharacterBody3D.new()
			node.name = _unique_name("CharBody")
			var col_shape = CollisionShape3D.new()
			col_shape.shape = CapsuleShape3D.new()
			node.add_child(col_shape)
			var mesh_i = MeshInstance3D.new()
			mesh_i.mesh = CapsuleMesh.new()
			node.add_child(mesh_i)
		"Area3D":
			node = Area3D.new()
			node.name = _unique_name("Area")
			var col_shape = CollisionShape3D.new()
			col_shape.shape = BoxShape3D.new()
			node.add_child(col_shape)
		"Sprite3D":
			node = Sprite3D.new()
			node.name = _unique_name("Sprite3D")
		"Label3D":
			node = Label3D.new()
			node.name = _unique_name("Label3D")
			node.text = "Hello 3D"
			node.font_size = 32
		"AudioStreamPlayer3D":
			node = AudioStreamPlayer3D.new()
			node.name = _unique_name("Audio3D")
		"Node3D":
			node = Node3D.new()
			node.name = _unique_name("Node3D")
		"Path3D":
			node = Path3D.new()
			node.name = _unique_name("Path3D")
		_:
			# Generic fallback
			node = Node3D.new()
			node.name = _unique_name(display_name)

	# Place new object in front of camera at the orbit target
	if node:
		node.position = _orbit_target
		_scene_root.add_child(node)
		_push_undo({type = "add", node_ref = node})
		_select_node(node)
		_rebuild_scene_tree()
		_scene_dirty = true
		print("[VG3D] Added: ", node.name, " (", type_name, ")")

func _unique_name(base: String) -> String:
	if not is_instance_valid(_scene_root):
		return base
	var idx := 1
	var name_try := base
	while _scene_root.has_node(NodePath(name_try)):
		idx += 1
		name_try = base + str(idx)
	return name_try

# ─────────────────────────────────────────────────────────────────────────────
# SCENE TREE UI
# ─────────────────────────────────────────────────────────────────────────────
func _rebuild_scene_tree() -> void:
	if not is_instance_valid(_scene_tree) or not is_instance_valid(_scene_root):
		return
	_scene_tree.clear()

	var root_item = _scene_tree.create_item()
	root_item.set_text(0, _scene_root.name)
	root_item.set_metadata(0, _scene_root)

	_add_tree_children(root_item, _scene_root)

func _add_tree_children(parent_item: TreeItem, parent_node: Node) -> void:
	for child in parent_node.get_children():
		# Skip editor-internal nodes
		if child.name.begins_with("_Selection") or child.name.begins_with("EditorCamera") \
			or child.name.begins_with("EditorEnv") or child.name.begins_with("EditorSun") \
			or child.name.begins_with("EditorFill") or child.name.begins_with("EditorGrid") \
			or child.name.begins_with("OriginAxes") or child.name.begins_with("TransformGizmo"):
			continue
		if child is Node3D or child is CollisionShape3D:
			var item = _scene_tree.create_item(parent_item)
			var icon = _get_node_icon(child)
			var vis_indicator = "" if child.visible else " 🚫"
			item.set_text(0, icon + " " + child.name + vis_indicator)
			item.set_metadata(0, child)
			# Dim hidden nodes
			if not child.visible:
				item.set_custom_color(0, Color(0.5, 0.5, 0.5))
			_add_tree_children(item, child)

func _get_node_icon(node: Node) -> String:
	if node is Camera3D: return "📷"
	if node is OmniLight3D: return "💡"
	if node is SpotLight3D: return "🔦"
	if node is DirectionalLight3D: return "☀️"
	if node is MeshInstance3D: return "🔺"
	if node is CSGBox3D: return "🟫"
	if node is CSGSphere3D: return "🔵"
	if node is CSGCylinder3D: return "🟡"
	if node is RigidBody3D: return "⚙️"
	if node is StaticBody3D: return "🧱"
	if node is CharacterBody3D: return "🏃"
	if node is Area3D: return "📦"
	if node is Sprite3D: return "🖼️"
	if node is Label3D: return "🔤"
	if node is AudioStreamPlayer3D: return "🔊"
	if node is CollisionShape3D: return "🔶"
	if node is Path3D: return "〰️"
	return "⊕"

func _on_scene_tree_selected() -> void:
	var item = _scene_tree.get_selected()
	if item:
		var node = item.get_metadata(0)
		if node is Node3D and node != _scene_root:
			_select_node(node)
			# Transfer focus to viewport so Delete / keyboard shortcuts work
			if is_instance_valid(_viewport_container):
				_viewport_container.grab_focus()

## Scene tree double-click → jump to VG code for that node (like form designer).
func _on_scene_tree_double_clicked() -> void:
	var item = _scene_tree.get_selected()
	if item:
		var node = item.get_metadata(0)
		if node is Node3D and node != _scene_root:
			node_double_clicked.emit(node)

func _sync_scene_tree_selection() -> void:
	if not is_instance_valid(_scene_tree):
		return
	# Walk tree items and select the one matching _selected_node
	var root_item = _scene_tree.get_root()
	if not root_item:
		return
	_select_tree_item_recursive(root_item)

func _select_tree_item_recursive(item: TreeItem) -> bool:
	if item.get_metadata(0) == _selected_node:
		item.select(0)
		return true
	var child = item.get_first_child()
	while child:
		if _select_tree_item_recursive(child):
			return true
		child = child.get_next()
	return false

# ─────────────────────────────────────────────────────────────────────────────
# DELETE
# ─────────────────────────────────────────────────────────────────────────────
func _on_delete_selected() -> void:
	if not is_instance_valid(_selected_node) or _selected_node == _scene_root:
		return

	var node_to_delete = _selected_node
	var node_name = node_to_delete.name

	# Store for undo
	var stored = node_to_delete.duplicate()
	_push_undo({type = "delete", stored_node = stored, node_ref = node_to_delete, node_name = node_name})

	_deselect()
	node_to_delete.get_parent().remove_child(node_to_delete)
	node_to_delete.queue_free()
	_rebuild_scene_tree()
	_scene_dirty = true
	print("[VG3D] Deleted: ", node_name)

# ─────────────────────────────────────────────────────────────────────────────
# SCENE LOAD / SAVE
# ─────────────────────────────────────────────────────────────────────────────
## Load a .tscn scene into the 3D editor viewport.
## We parse the .tscn text first to strip VisualGasicScript references
## so the C++ VG runtime never initialises inside the editor.
func load_scene(path: String) -> void:
	if path.is_empty():
		return

	# Clear existing scene content
	_deselect()
	for child in _scene_root.get_children():
		child.queue_free()

	# Clear undo/redo stacks for new scene
	for a in _undo_stack:
		_cleanup_undo_action(a)
	_undo_stack.clear()
	for a in _redo_stack:
		_cleanup_undo_action(a)
	_redo_stack.clear()

	# --- Strip VG scripts from the .tscn text before loading -----------
	print("[VG3D] load_scene: stripping VG scripts from: ", path)
	var clean_path := _create_clean_scene_copy(path)
	if clean_path.is_empty():
		push_warning("[VG3D] Failed to create script-free copy of: " + path)
		return

	print("[VG3D] load_scene: loading cleaned scene from: ", clean_path)
	var packed = ResourceLoader.load(clean_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	print("[VG3D] load_scene: ResourceLoader returned: ", packed)

	# Delete the temp file after loading
	if FileAccess.file_exists(clean_path):
		DirAccess.remove_absolute(clean_path)

	if packed:
		var instance = packed.instantiate()
		print("[VG3D] load_scene: instantiate returned: ", instance)
		if instance:
			print("[VG3D] load_scene: instance type=", instance.get_class(), "  children=", instance.get_child_count())
			# If the root is a Node3D, add its children directly
			if instance is Node3D:
				var children_to_move: Array = []
				for child in instance.get_children():
					children_to_move.append(child)
				for child in children_to_move:
					instance.remove_child(child)
					_scene_root.add_child(child)
				instance.queue_free()
			else:
				_scene_root.add_child(instance)

			_loaded_scene_path = path  # store the REAL path, not the temp
			_scene_dirty = false
			_rebuild_scene_tree()
			_update_status()
			print("[VG3D] Loaded scene: ", path, "  nodes in _scene_root: ", _scene_root.get_child_count())
	else:
		push_warning("[VG3D] Failed to load scene: " + path)

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
			# Extract the id value (id="...")
			var id_pos := stripped.find('id="')
			if id_pos != -1:
				var id_start := id_pos + 4
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

## Save the current 3D scene to disk.  If no path has been set yet,
## automatically open a Save As dialog instead of silently failing.
func _save_scene() -> void:
	if _loaded_scene_path.is_empty():
		save_scene_as()
		return

	var packed = PackedScene.new()
	# Create a temporary root to pack
	var temp_root = Node3D.new()
	temp_root.name = _loaded_scene_path.get_file().get_basename()

	# Duplicate scene content
	for child in _scene_root.get_children():
		var dup = child.duplicate()
		temp_root.add_child(dup)
		dup.owner = temp_root

	packed.pack(temp_root)
	var err = ResourceSaver.save(packed, _loaded_scene_path)
	temp_root.queue_free()

	if err == OK:
		_scene_dirty = false
		_update_status()
		print("[VG3D] Scene saved: ", _loaded_scene_path)
		scene_saved.emit(_loaded_scene_path)
	else:
		push_error("[VG3D] Failed to save scene: " + str(err))

## Open a Save As file dialog so the user can choose where to save the scene.
func save_scene_as() -> void:
	if _save_file_dialog == null:
		_save_file_dialog = FileDialog.new()
		_save_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_save_file_dialog.access = FileDialog.ACCESS_RESOURCES
		_save_file_dialog.title = "Save 3D Scene As"
		_save_file_dialog.filters = PackedStringArray(["*.tscn ; Godot Scene"])
		_save_file_dialog.min_size = Vector2i(500, 400)
		_save_file_dialog.file_selected.connect(_on_save_as_file_selected)
		_style_dialog_dark(_save_file_dialog)
		add_child(_save_file_dialog)
	# Suggest a default name based on scene content
	var suggested := "Level1.tscn"
	if is_instance_valid(_scene_root) and _scene_root.get_child_count() > 0:
		var first_child = _scene_root.get_child(0)
		if first_child and not first_child.name.begins_with("_"):
			suggested = first_child.name + "_Scene.tscn"
	_save_file_dialog.current_file = suggested
	_save_file_dialog.popup_centered()

## Callback: user chose a file path in the Save As dialog.
func _on_save_as_file_selected(path: String) -> void:
	# Ensure .tscn extension
	if not path.ends_with(".tscn"):
		path += ".tscn"
	_loaded_scene_path = path
	_save_scene()  # Now that we have a path, the normal save will work

## Explicitly set the scene path (e.g. for a brand-new scene before saving).
func set_scene_path(path: String) -> void:
	_loaded_scene_path = path
	_update_status()

## Create a new empty 3D scene.
func new_scene() -> void:
	_deselect()
	for child in _scene_root.get_children():
		child.queue_free()
	# Clear undo/redo
	for a in _undo_stack:
		_cleanup_undo_action(a)
	_undo_stack.clear()
	for a in _redo_stack:
		_cleanup_undo_action(a)
	_redo_stack.clear()
	_loaded_scene_path = ""
	_scene_dirty = false
	_rebuild_scene_tree()
	_update_status()

## Load the currently edited scene from the Godot editor.
func load_current_editor_scene() -> void:
	var scene_root = EditorInterface.get_edited_scene_root()
	if scene_root and not scene_root.scene_file_path.is_empty():
		if scene_root is Node3D or _has_3d_children(scene_root):
			load_scene(scene_root.scene_file_path)
		else:
			new_scene()
	else:
		new_scene()

func _has_3d_children(node: Node) -> bool:
	for child in node.get_children():
		if child is Node3D:
			return true
		if _has_3d_children(child):
			return true
	return false

# ─────────────────────────────────────────────────────────────────────────────
# STATUS
# ─────────────────────────────────────────────────────────────────────────────
func _update_status() -> void:
	if not is_instance_valid(_status_label):
		return
	var parts: Array = []

	# Scene name
	if _loaded_scene_path.is_empty():
		parts.append("New Scene")
	else:
		parts.append(_loaded_scene_path.get_file())
	if _scene_dirty:
		parts.append("*")

	# Selection info
	if is_instance_valid(_selected_node):
		parts.append(" | " + _selected_node.name)
		parts.append(_format_vec3(_selected_node.global_position))

	# Gizmo mode
	var mode_names = ["Move", "Rotate", "Scale"]
	parts.append(" | " + mode_names[_gizmo_mode])

	# Space
	parts.append("(" + ("Local" if _local_space else "World") + ")")

	# Projection
	parts.append(" | " + ("Ortho" if _is_orthographic else "Persp"))

	# Undo count
	if _undo_stack.size() > 0:
		parts.append(" | Undo:" + str(_undo_stack.size()))

	_status_label.text = " ".join(parts)

func _format_vec3(v: Vector3) -> String:
	return "(" + str(snapped(v.x, 0.01)) + ", " + str(snapped(v.y, 0.01)) + ", " + str(snapped(v.z, 0.01)) + ")"

# ─────────────────────────────────────────────────────────────────────────────
# PROCESS — update gizmo each frame, sync viewport size, update transform panel
# ─────────────────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if is_instance_valid(_selected_node) and is_instance_valid(_gizmo_root):
		_update_gizmo_position()
		# Keep transform panel in sync during gizmo drag
		if _gizmo_dragging:
			_update_transform_panel()

	# Update viewport size to match container
	if is_instance_valid(_viewport) and is_instance_valid(_viewport_container):
		var container_size = _viewport_container.size
		if container_size.x > 0 and container_size.y > 0:
			var new_size = Vector2i(int(container_size.x), int(container_size.y))
			if _viewport.size != new_size:
				_viewport.size = new_size

# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────────────────────────────────────
## Get the selected node (for Properties panel integration).
func get_selected_node() -> Node3D:
	return _selected_node

## Get whether the scene has unsaved changes.
func is_dirty() -> bool:
	return _scene_dirty

## Get the loaded scene path.
func get_scene_path() -> String:
	return _loaded_scene_path

## Get all user node names in the 3D scene (for code editor Object dropdown).
func get_scene_node_names() -> Array:
	var names: Array = []
	if not is_instance_valid(_scene_root):
		return names
	_collect_node_names(_scene_root, names)
	return names

## Get all user node names AND their types (for code editor Object + Procedure dropdowns).
## Returns Array of { "name": String, "type": String } dictionaries.
func get_scene_node_info() -> Array:
	var info: Array = []
	if not is_instance_valid(_scene_root):
		return info
	_collect_node_info(_scene_root, info)
	return info

func _collect_node_info(parent: Node, info: Array) -> void:
	for child in parent.get_children():
		if child.name.begins_with("_Selection") or child.name.begins_with("EditorCamera") \
			or child.name.begins_with("EditorEnv") or child.name.begins_with("EditorSun") \
			or child.name.begins_with("EditorFill") or child.name.begins_with("EditorGrid") \
			or child.name.begins_with("OriginAxes") or child.name.begins_with("TransformGizmo"):
			continue
		if child is Node3D:
			info.append({"name": child.name, "type": get_node_type_name(child)})
			_collect_node_info(child, info)

func _collect_node_names(parent: Node, names: Array) -> void:
	for child in parent.get_children():
		if child.name.begins_with("_Selection") or child.name.begins_with("EditorCamera") \
			or child.name.begins_with("EditorEnv") or child.name.begins_with("EditorSun") \
			or child.name.begins_with("EditorFill") or child.name.begins_with("EditorGrid") \
			or child.name.begins_with("OriginAxes") or child.name.begins_with("TransformGizmo"):
			continue
		if child is Node3D:
			names.append(child.name)
			_collect_node_names(child, names)

## Get the type name string for a 3D node (used for event mapping).
func get_node_type_name(node: Node3D) -> String:
	if node is RigidBody3D: return "RigidBody3D"
	if node is CharacterBody3D: return "CharacterBody3D"
	if node is StaticBody3D: return "StaticBody3D"
	if node is Area3D: return "Area3D"
	if node is Camera3D: return "Camera3D"
	if node is OmniLight3D: return "OmniLight3D"
	if node is SpotLight3D: return "SpotLight3D"
	if node is DirectionalLight3D: return "DirectionalLight3D"
	if node is CSGBox3D: return "CSGBox3D"
	if node is CSGSphere3D: return "CSGSphere3D"
	if node is CSGCylinder3D: return "CSGCylinder3D"
	if node is MeshInstance3D: return "MeshInstance3D"
	if node is Sprite3D: return "Sprite3D"
	if node is Label3D: return "Label3D"
	if node is AudioStreamPlayer3D: return "AudioStreamPlayer3D"
	if node is Path3D: return "Path3D"
	return "Node3D"

# ─────────────────────────────────────────────────────────────────────────────
# ASSET IMPORT — Import .glb/.gltf/.obj models into the 3D scene
# ─────────────────────────────────────────────────────────────────────────────
func _show_import_model_dialog() -> void:
	if is_instance_valid(_import_file_dialog):
		_import_file_dialog.popup_centered()
		return

	_import_file_dialog = FileDialog.new()
	_import_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_import_file_dialog.title = "Import 3D Model"
	_import_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_import_file_dialog.filters = PackedStringArray([
		"*.glb ; GLTF Binary",
		"*.gltf ; GLTF Text",
		"*.obj ; Wavefront OBJ",
		"*.fbx ; FBX Model",
	])
	_import_file_dialog.size = Vector2i(700, 500)
	_import_file_dialog.file_selected.connect(_on_import_model_selected)
	_style_dialog_dark(_import_file_dialog)
	add_child(_import_file_dialog)
	_import_file_dialog.popup_centered()

func _on_import_model_selected(source_path: String) -> void:
	if source_path.is_empty():
		return

	# Determine project root (where project.godot lives)
	var project_root := ProjectSettings.globalize_path("res://")
	var filename := source_path.get_file()

	# Create a models/ directory if it doesn't exist
	var models_dir := "res://models"
	if not DirAccess.dir_exists_absolute(models_dir):
		DirAccess.make_dir_recursive_absolute(models_dir)

	var dest_res := models_dir.path_join(filename)
	var dest_abs := ProjectSettings.globalize_path(dest_res)

	# Copy the file into the project
	if source_path != dest_abs:
		var err := DirAccess.copy_absolute(source_path, dest_abs)
		if err != OK:
			push_error("[VG3D] Failed to copy model: %s → %s (error %d)" % [source_path, dest_abs, err])
			_update_status_text("Import failed: copy error")
			return

	# Also copy any sidecar files (.bin for .gltf, .mtl for .obj)
	var source_dir := source_path.get_base_dir()
	var base_name := filename.get_basename()
	var ext := filename.get_extension().to_lower()

	if ext == "gltf":
		# Copy .bin sidecar if it exists
		var bin_path := source_dir.path_join(base_name + ".bin")
		if FileAccess.file_exists(bin_path):
			DirAccess.copy_absolute(bin_path, ProjectSettings.globalize_path(models_dir.path_join(base_name + ".bin")))
	elif ext == "obj":
		# Copy .mtl sidecar if it exists
		var mtl_path := source_dir.path_join(base_name + ".mtl")
		if FileAccess.file_exists(mtl_path):
			DirAccess.copy_absolute(mtl_path, ProjectSettings.globalize_path(models_dir.path_join(base_name + ".mtl")))

	# Tell Godot's editor to scan and import the file
	if Engine.is_editor_hint():
		var efs := EditorInterface.get_resource_filesystem()
		if efs:
			efs.scan()
			# Wait for scan to complete before loading
			await efs.filesystem_changed
			# Small extra delay for import processing
			await get_tree().create_timer(0.5).timeout

	# Now load and instantiate the model
	_instantiate_imported_model(dest_res)

func _instantiate_imported_model(res_path: String) -> void:
	if not is_instance_valid(_scene_root):
		return

	# Try to load the resource
	var scene := ResourceLoader.load(res_path) as PackedScene
	if scene:
		# It's a PackedScene (common for .glb/.gltf)
		var instance := scene.instantiate()
		if instance is Node3D:
			instance.name = _unique_name(res_path.get_file().get_basename().capitalize().replace(" ", ""))
			instance.position = _orbit_target
			_scene_root.add_child(instance)
			_push_undo({type = "add", node_ref = instance})
			_select_node(instance)
			_rebuild_scene_tree()
			_scene_dirty = true
			_update_status_text("Imported: " + instance.name)
			print("[VG3D] Imported model: ", instance.name, " from ", res_path)
		else:
			push_error("[VG3D] Imported scene root is not Node3D")
		return

	# Try loading as a Mesh resource (some .obj files load as Mesh)
	var mesh_res := ResourceLoader.load(res_path) as Mesh
	if mesh_res:
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.mesh = mesh_res
		mesh_inst.name = _unique_name(res_path.get_file().get_basename().capitalize().replace(" ", ""))
		mesh_inst.position = _orbit_target
		_scene_root.add_child(mesh_inst)
		_push_undo({type = "add", node_ref = mesh_inst})
		_select_node(mesh_inst)
		_rebuild_scene_tree()
		_scene_dirty = true
		_update_status_text("Imported: " + mesh_inst.name)
		print("[VG3D] Imported mesh: ", mesh_inst.name, " from ", res_path)
		return

	push_error("[VG3D] Could not load model: ", res_path)
	_update_status_text("Import failed: could not load")

func _update_status_text(text: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = text

# ─────────────────────────────────────────────────────────────────────────────
# ENVIRONMENT PRESETS — Quick-add WorldEnvironment + Lighting
# ─────────────────────────────────────────────────────────────────────────────
func _show_env_preset_popup() -> void:
	if is_instance_valid(_env_preset_menu):
		_style_popup_dark(_env_preset_menu)
		_env_preset_menu.position = DisplayServer.mouse_get_position()
		_env_preset_menu.reset_size()
		_env_preset_menu.popup()

func _on_env_preset_selected(id: int) -> void:
	match id:
		0: _add_environment_preset("Outdoor Day")
		1: _add_environment_preset("Outdoor Night")
		2: _add_environment_preset("Indoor")
		3: _add_environment_preset("Space")
		10: _remove_user_environment()

func _add_environment_preset(preset_name: String) -> void:
	if not is_instance_valid(_scene_root):
		return

	# Remove any existing user environment first
	_remove_user_environment()

	# Create WorldEnvironment node
	var world_env := WorldEnvironment.new()
	world_env.name = "Environment"
	var env := Environment.new()

	# Create DirectionalLight3D
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true

	match preset_name:
		"Outdoor Day":
			env.background_mode = Environment.BG_SKY
			var sky := Sky.new()
			var sky_mat := ProceduralSkyMaterial.new()
			sky_mat.sky_top_color = Color(0.35, 0.55, 0.85)
			sky_mat.sky_horizon_color = Color(0.65, 0.75, 0.85)
			sky_mat.ground_bottom_color = Color(0.15, 0.12, 0.10)
			sky_mat.ground_horizon_color = Color(0.55, 0.50, 0.45)
			sky.sky_material = sky_mat
			env.sky = sky
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.ambient_light_energy = 0.5
			env.tonemap_mode = Environment.TONE_MAPPER_ACES
			sun.light_energy = 1.2
			sun.rotation_degrees = Vector3(-50, -30, 0)
			sun.light_color = Color(1.0, 0.95, 0.88)

		"Outdoor Night":
			env.background_mode = Environment.BG_SKY
			var sky := Sky.new()
			var sky_mat := ProceduralSkyMaterial.new()
			sky_mat.sky_top_color = Color(0.02, 0.02, 0.08)
			sky_mat.sky_horizon_color = Color(0.05, 0.05, 0.12)
			sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.02)
			sky_mat.ground_horizon_color = Color(0.03, 0.03, 0.06)
			sky.sky_material = sky_mat
			env.sky = sky
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.ambient_light_energy = 0.1
			env.tonemap_mode = Environment.TONE_MAPPER_ACES
			env.glow_enabled = true
			sun.light_energy = 0.15
			sun.rotation_degrees = Vector3(-30, 45, 0)
			sun.light_color = Color(0.6, 0.65, 0.8)

		"Indoor":
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.15, 0.14, 0.13)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.8, 0.75, 0.65)
			env.ambient_light_energy = 0.4
			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			env.ssao_enabled = true
			sun.light_energy = 0.8
			sun.rotation_degrees = Vector3(-60, -20, 0)
			sun.light_color = Color(1.0, 0.95, 0.85)

		"Space":
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.0, 0.0, 0.02)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.05, 0.05, 0.1)
			env.ambient_light_energy = 0.2
			env.tonemap_mode = Environment.TONE_MAPPER_ACES
			env.glow_enabled = true
			env.glow_intensity = 1.5
			sun.light_energy = 1.5
			sun.rotation_degrees = Vector3(-25, 60, 0)
			sun.light_color = Color(1.0, 1.0, 1.0)

	world_env.environment = env
	_scene_root.add_child(world_env)
	_scene_root.add_child(sun)
	_push_undo({type = "add", node_ref = world_env})
	_rebuild_scene_tree()
	_scene_dirty = true
	_update_status_text("Added environment: " + preset_name)
	print("[VG3D] Added environment preset: ", preset_name)

func _remove_user_environment() -> void:
	if not is_instance_valid(_scene_root):
		return
	# Remove user-created WorldEnvironment and Sun nodes (not the editor ones)
	for child in _scene_root.get_children():
		if child.name == "Environment" and child is WorldEnvironment:
			_scene_root.remove_child(child)
			child.queue_free()
		elif child.name == "Sun" and child is DirectionalLight3D:
			_scene_root.remove_child(child)
			child.queue_free()
	_rebuild_scene_tree()
	_scene_dirty = true
