@tool
extends Panel
## Form Editor Helper - Enables drag-resize and provides design-time tools
## 
## Features:
## - Drag-resize of the parent Window in the editor
## - Snap-to-grid for control placement
## - Alignment toolbar for precise positioning
## - Smart guides when controls align
## - Intercepts custom vg_control drops to avoid MenuBar issues

signal form_resized(new_size: Vector2)

# Grid settings
var grid_enabled: bool = true
var grid_size: int = 8  # Default 8px grid
var show_grid: bool = true
var grid_color: Color = Color(0.3, 0.3, 0.3, 0.5)

# Resize tracking
var _last_size := Vector2.ZERO
var _updating := false

# Alignment toolbar (created in editor)
var _alignment_toolbar: Control = null

func _ready() -> void:
	# Use MOUSE_FILTER_PASS to allow receiving drop data while letting clicks through
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# ── Apply VB6 Classic Theme to the parent Window ──
	# This is the authoritative, bulletproof theme application point.
	# It runs every time any VG form is loaded — in the editor's 2D viewport,
	# after scene reloads, and at runtime (F5).  Godot's theme inheritance
	# is dynamic, so all child controls (Button, LineEdit, etc.) will
	# immediately pick up the VB6 styles.
	var parent_window = get_parent()
	if parent_window is Window:
		# Read the C++ serializer's theme font size before we replace it.
		# The C++ inline theme is the source of truth for the base font size.
		var base_font_size := 12  # fallback = VB6 default 8pt
		var existing_theme = parent_window.theme
		if existing_theme and existing_theme.default_font_size > 0:
			base_font_size = existing_theme.default_font_size
		var vb6_theme = _build_vb6_classic_theme(base_font_size)
		if vb6_theme:
			parent_window.theme = vb6_theme
			print("[VG-THEME] Applied VB6 Classic Theme to '", parent_window.name, "' (", vb6_theme.get_type_list().size(), " types)")
		else:
			print("[VG-THEME] ERROR: _build_vb6_classic_theme() returned null!")
		
		# Remove auto-generated empty MenuBars that were added by the old C++ serializer
		# to blank forms.  A MenuBar is "empty default" when every PopupMenu child
		# has zero user items (no add_item calls).  Forms created from the
		# "Main Form with Menu" template will have items, so they are kept.
		# Check both "MainMenu" (current convention) and "MenuBar" (old convention).
		var main_menu = parent_window.get_node_or_null("MainMenu")
		if main_menu == null:
			main_menu = parent_window.get_node_or_null("MenuBar")
		if main_menu is MenuBar:
			var all_empty := true
			for child in main_menu.get_children():
				if child is PopupMenu and child.item_count > 0:
					all_empty = false
					break
			if all_empty:
				main_menu.queue_free()
				print("[VG-THEME] Removed empty default MainMenu from '", parent_window.name, "'")
	else:
		print("[VG-THEME] Parent is not Window: ", parent_window.get_class() if parent_window else "null")

	if Engine.is_editor_hint():
		# Initialize size tracking from parent Window
		var parent_window2 = get_parent()
		if parent_window2 is Window:
			size = Vector2(parent_window2.size)
		_last_size = size

		# Request redraw for grid
		queue_redraw()

## Check if we can accept this drop data (vg_control custom type)
func _can_drop_data(at_position: Vector2, data) -> bool:
	if not Engine.is_editor_hint():
		return false
	if data is Dictionary and data.get("type") == "vg_control":
		return true
	return false

## Handle the drop - instance the scene and add to form root
func _drop_data(at_position: Vector2, data) -> void:
	if not Engine.is_editor_hint():
		return
	if not data is Dictionary or data.get("type") != "vg_control":
		return
	
	var scene_path = data.get("scene_path", "")
	if scene_path.is_empty():
		return
	
	# Get the form root (parent Window)
	var form_root = get_parent()
	if not form_root:
		return
	
	# Load and instance the scene
	var scene = load(scene_path)
	if not scene:
		printerr("VisualGasic: Could not load scene: ", scene_path)
		return
	
	var instance = scene.instantiate()
	if not instance:
		printerr("VisualGasic: Could not instantiate scene: ", scene_path)
		return
	
	# Add to form root (NOT to _FormBackground)
	form_root.add_child(instance, true)  # force_readable_name
	instance.owner = form_root
	
	# Position at drop location, snapped to grid
	if instance is Control:
		var snapped_pos = snap_to_grid(at_position)
		instance.position = snapped_pos
	
	# Set button/label text to match the node name
	var control_name = scene_path.get_file().get_basename()
	if control_name in ["Button", "Label", "CheckBox", "OptionButton"] and "text" in instance:
		instance.text = instance.name
	
	# CRITICAL: Remove the drag meta so _process() doesn't ALSO fire
	# _handle_vg_drop_delayed, which would create a duplicate control
	if Engine.has_meta("_vg_active_drag"):
		Engine.remove_meta("_vg_active_drag")
	
	print("VisualGasic: Dropped ", instance.name, " at ", at_position)
	
	# Select the new node in the editor
	var editor = EditorInterface
	if editor:
		var selection = editor.get_selection()
		if selection:
			selection.clear()
			selection.add_node(instance)

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if _updating:
		return
		
	var parent_window = get_parent()
	if parent_window is Window:
		# Check if our size changed (user dragged resize handles)
		if size != _last_size and size != Vector2.ZERO:
			_updating = true
			# Update the Window's size to match
			parent_window.size = Vector2i(size)
			emit_signal("form_resized", size)
			_last_size = size
			_updating = false
		# Check if Window size changed (via inspector)
		elif Vector2(parent_window.size) != _last_size:
			_last_size = Vector2(parent_window.size)
			size = _last_size

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	if not show_grid or not grid_enabled:
		return
	
	# Draw grid
	var rect_size = size
	for x in range(0, int(rect_size.x), grid_size):
		draw_line(Vector2(x, 0), Vector2(x, rect_size.y), grid_color)
	for y in range(0, int(rect_size.y), grid_size):
		draw_line(Vector2(0, y), Vector2(rect_size.x, y), grid_color)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not get_parent() is Window:
		warnings.append("FormEditorHelper should be a child of a Window node")
	return warnings

# =============================================================================
# SNAP-TO-GRID FUNCTIONS
# =============================================================================

## Snaps a position to the nearest grid point
func snap_to_grid(pos: Vector2) -> Vector2:
	if not grid_enabled:
		return pos
	return Vector2(
		round(pos.x / grid_size) * grid_size,
		round(pos.y / grid_size) * grid_size
	)

## Snaps a control's position to the grid
func snap_control_to_grid(control: Control) -> void:
	if not grid_enabled:
		return
	control.position = snap_to_grid(control.position)

## Snaps all controls in the form to the grid
func snap_all_to_grid() -> void:
	var parent = get_parent()
	if not parent:
		return
	for child in parent.get_children():
		if child is Control and child != self:
			snap_control_to_grid(child)

# =============================================================================
# ALIGNMENT FUNCTIONS
# =============================================================================

## Aligns selected controls to the left edge of the leftmost control
static func align_left(controls: Array) -> void:
	if controls.size() < 2:
		return
	var min_x = INF
	for ctrl in controls:
		if ctrl is Control:
			min_x = min(min_x, ctrl.position.x)
	for ctrl in controls:
		if ctrl is Control:
			ctrl.position.x = min_x

## Aligns selected controls to the right edge of the rightmost control
static func align_right(controls: Array) -> void:
	if controls.size() < 2:
		return
	var max_right = -INF
	for ctrl in controls:
		if ctrl is Control:
			max_right = max(max_right, ctrl.position.x + ctrl.size.x)
	for ctrl in controls:
		if ctrl is Control:
			ctrl.position.x = max_right - ctrl.size.x

## Aligns selected controls to the top edge of the topmost control
static func align_top(controls: Array) -> void:
	if controls.size() < 2:
		return
	var min_y = INF
	for ctrl in controls:
		if ctrl is Control:
			min_y = min(min_y, ctrl.position.y)
	for ctrl in controls:
		if ctrl is Control:
			ctrl.position.y = min_y

## Aligns selected controls to the bottom edge of the bottommost control
static func align_bottom(controls: Array) -> void:
	if controls.size() < 2:
		return
	var max_bottom = -INF
	for ctrl in controls:
		if ctrl is Control:
			max_bottom = max(max_bottom, ctrl.position.y + ctrl.size.y)
	for ctrl in controls:
		if ctrl is Control:
			ctrl.position.y = max_bottom - ctrl.size.y

## Centers selected controls horizontally
static func align_center_h(controls: Array) -> void:
	if controls.size() < 2:
		return
	var total_center = 0.0
	for ctrl in controls:
		if ctrl is Control:
			total_center += ctrl.position.x + ctrl.size.x / 2
	var center = total_center / controls.size()
	for ctrl in controls:
		if ctrl is Control:
			ctrl.position.x = center - ctrl.size.x / 2

## Centers selected controls vertically
static func align_center_v(controls: Array) -> void:
	if controls.size() < 2:
		return
	var total_center = 0.0
	for ctrl in controls:
		if ctrl is Control:
			total_center += ctrl.position.y + ctrl.size.y / 2
	var center = total_center / controls.size()
	for ctrl in controls:
		if ctrl is Control:
			ctrl.position.y = center - ctrl.size.y / 2

## Distributes controls evenly horizontally
static func distribute_horizontal(controls: Array) -> void:
	if controls.size() < 3:
		return
	# Sort by x position
	var sorted_controls = controls.duplicate()
	sorted_controls.sort_custom(func(a, b): return a.position.x < b.position.x)
	
	var first = sorted_controls[0]
	var last = sorted_controls[-1]
	var total_width = (last.position.x + last.size.x) - first.position.x
	var total_control_width = 0.0
	for ctrl in sorted_controls:
		total_control_width += ctrl.size.x
	
	var gap = (total_width - total_control_width) / (controls.size() - 1)
	var current_x = first.position.x
	
	for ctrl in sorted_controls:
		ctrl.position.x = current_x
		current_x += ctrl.size.x + gap

## Distributes controls evenly vertically
static func distribute_vertical(controls: Array) -> void:
	if controls.size() < 3:
		return
	# Sort by y position
	var sorted_controls = controls.duplicate()
	sorted_controls.sort_custom(func(a, b): return a.position.y < b.position.y)
	
	var first = sorted_controls[0]
	var last = sorted_controls[-1]
	var total_height = (last.position.y + last.size.y) - first.position.y
	var total_control_height = 0.0
	for ctrl in sorted_controls:
		total_control_height += ctrl.size.y
	
	var gap = (total_height - total_control_height) / (controls.size() - 1)
	var current_y = first.position.y
	
	for ctrl in sorted_controls:
		ctrl.position.y = current_y
		current_y += ctrl.size.y + gap

## Makes all selected controls the same width as the first selected
static func make_same_width(controls: Array) -> void:
	if controls.size() < 2:
		return
	var target_width = controls[0].size.x
	for ctrl in controls:
		if ctrl is Control:
			ctrl.size.x = target_width

## Makes all selected controls the same height as the first selected
static func make_same_height(controls: Array) -> void:
	if controls.size() < 2:
		return
	var target_height = controls[0].size.y
	for ctrl in controls:
		if ctrl is Control:
			ctrl.size.y = target_height

## Makes all selected controls the same size as the first selected
static func make_same_size(controls: Array) -> void:
	if controls.size() < 2:
		return
	var target_size = controls[0].size
	for ctrl in controls:
		if ctrl is Control:
			ctrl.size = target_size

## Centers a control within its parent
static func center_in_parent(control: Control) -> void:
	var parent = control.get_parent()
	if parent is Control:
		control.position = (parent.size - control.size) / 2
	elif parent is Window:
		control.position = (Vector2(parent.size) - control.size) / 2

## Arranges controls in a grid pattern
## controls: Array of Control nodes to arrange
## columns: Number of columns in the grid
## h_spacing: Horizontal gap between controls (px)
## v_spacing: Vertical gap between controls (px)
## sort_by_position: If true, sort by spatial position; if false, use array order
## make_same_size: If true, resize all controls to match the first one
static func arrange_grid(controls: Array, columns: int = 4, h_spacing: float = 4.0, v_spacing: float = 4.0, sort_by_position: bool = true, make_same_size: bool = false) -> void:
	if controls.size() < 2 or columns < 1:
		return
	
	# Sort controls
	var sorted_controls = controls.duplicate()
	if sort_by_position:
		sorted_controls.sort_custom(func(a, b):
			var row_tolerance = 20.0
			if abs(a.position.y - b.position.y) < row_tolerance:
				return a.position.x < b.position.x
			return a.position.y < b.position.y
		)
	
	# Determine cell size
	var cell_w: float = 0.0
	var cell_h: float = 0.0
	if make_same_size and sorted_controls.size() > 0:
		cell_w = sorted_controls[0].size.x
		cell_h = sorted_controls[0].size.y
		for ctrl in sorted_controls:
			if ctrl is Control:
				ctrl.size = Vector2(cell_w, cell_h)
	else:
		for ctrl in sorted_controls:
			if ctrl is Control:
				cell_w = max(cell_w, ctrl.size.x)
				cell_h = max(cell_h, ctrl.size.y)
	
	# Start from top-left of the bounding box
	var start_x: float = INF
	var start_y: float = INF
	for ctrl in sorted_controls:
		if ctrl is Control:
			start_x = min(start_x, ctrl.position.x)
			start_y = min(start_y, ctrl.position.y)
	if start_x == INF: start_x = 0
	if start_y == INF: start_y = 0
	
	# Place each control
	for i in range(sorted_controls.size()):
		var ctrl = sorted_controls[i]
		if not ctrl is Control:
			continue
		var row = i / columns
		var col = i % columns
		ctrl.position = Vector2(
			start_x + col * (cell_w + h_spacing),
			start_y + row * (cell_h + v_spacing)
		)

# =============================================================================
# GRID SETTINGS
# =============================================================================

func set_grid_size(new_size: int) -> void:
	grid_size = max(1, new_size)
	queue_redraw()

func set_grid_enabled(enabled: bool) -> void:
	grid_enabled = enabled
	queue_redraw()

func set_show_grid(show: bool) -> void:
	show_grid = show
	queue_redraw()

func toggle_grid() -> void:
	grid_enabled = not grid_enabled
	queue_redraw()

# =============================================================================
# VB6 CLASSIC (WIN98) THEME — applied to parent Window for WYSIWYG fidelity
# =============================================================================
# This ensures Godot's 2D preview and runtime match the Form Designer.
# Uses the authentic Win32 system color palette from the C++ header.

static func _build_vb6_classic_theme(p_default_font_size: int = 12) -> Theme:
	var t = Theme.new()
	# Use the font size from the C++ serializer's inline theme (source of truth).
	# VB6 default = 8pt → 12px.  The C++ canvas draws at the same size.
	t.default_font_size = p_default_font_size

	# ── Win32 system colors (matching C++ visual_gasic_form_designer.h) ──
	var btn_face      := Color(0.831, 0.816, 0.784)  # #D4D0C8
	var btn_shadow    := Color(0.51, 0.51, 0.51)
	var dark_shadow   := Color(0.25, 0.25, 0.25)
	var win_bg        := Color(1.0, 1.0, 1.0)
	var win_text      := Color(0.0, 0.0, 0.0)
	var form_bg       := Color(0.753, 0.753, 0.753)  # #C0C0C0
	var scrollbar_bg  := Color(0.87, 0.87, 0.87)
	var progress_fill := Color(0.0, 0.5, 0.0)
	var placeholder   := Color(0.6, 0.6, 0.6)
	var title_bg      := Color(0.0, 0.0, 0.5)
	var title_text    := Color(1.0, 1.0, 1.0)
	var disabled_text := Color(0.51, 0.51, 0.51)
	var border_mid    := Color(0.6, 0.6, 0.6)

	# ── Helpers ──
	var _raised = func(bg: Color) -> StyleBoxFlat:
		var sb = StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = border_mid
		sb.set_border_width_all(2)
		sb.content_margin_left = 4; sb.content_margin_right = 4
		sb.content_margin_top = 2; sb.content_margin_bottom = 2
		return sb

	var _sunken = func(bg: Color) -> StyleBoxFlat:
		var sb = StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = btn_shadow
		sb.set_border_width_all(2)
		sb.content_margin_left = 4; sb.content_margin_right = 4
		sb.content_margin_top = 2; sb.content_margin_bottom = 2
		return sb

	# ── Window ──
	var win_sb = StyleBoxFlat.new()
	win_sb.bg_color = form_bg
	win_sb.set_content_margin_all(0)
	t.set_stylebox("embedded_border", "Window", win_sb)
	t.set_stylebox("embedded_unfocused_border", "Window", win_sb)

	# ── Panel / PanelContainer — form background ──
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = form_bg
	panel_sb.set_content_margin_all(0)
	t.set_stylebox("panel", "Panel", panel_sb)
	var pc_sb = StyleBoxFlat.new()
	pc_sb.bg_color = form_bg
	pc_sb.set_content_margin_all(0)
	t.set_stylebox("panel", "PanelContainer", pc_sb)

	# ── Button ──
	t.set_stylebox("normal",   "Button", _raised.call(btn_face))
	t.set_stylebox("hover",    "Button", _raised.call(Color(0.87, 0.855, 0.824)))
	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = btn_face
	btn_pressed.border_color = dark_shadow
	btn_pressed.set_border_width_all(2)
	btn_pressed.content_margin_left = 5; btn_pressed.content_margin_right = 3
	btn_pressed.content_margin_top = 3; btn_pressed.content_margin_bottom = 1
	t.set_stylebox("pressed",  "Button", btn_pressed)
	t.set_stylebox("disabled", "Button", _raised.call(btn_face))
	var btn_focus = StyleBoxFlat.new()
	btn_focus.bg_color = btn_face
	btn_focus.border_color = Color(0, 0, 0)
	btn_focus.set_border_width_all(1)
	btn_focus.content_margin_left = 4; btn_focus.content_margin_right = 4
	btn_focus.content_margin_top = 2; btn_focus.content_margin_bottom = 2
	t.set_stylebox("focus",    "Button", btn_focus)
	t.set_color("font_color",          "Button", win_text)
	t.set_color("font_hover_color",    "Button", win_text)
	t.set_color("font_pressed_color",  "Button", win_text)
	t.set_color("font_disabled_color", "Button", disabled_text)
	t.set_color("font_focus_color",    "Button", win_text)

	# ── LineEdit (TextBox) ──
	t.set_stylebox("normal",    "LineEdit", _sunken.call(win_bg))
	var le_focus = _sunken.call(win_bg)
	le_focus.border_color = Color(0, 0, 0)
	t.set_stylebox("focus",     "LineEdit", le_focus)
	t.set_stylebox("read_only", "LineEdit", _sunken.call(btn_face))
	t.set_color("font_color",             "LineEdit", win_text)
	t.set_color("font_selected_color",    "LineEdit", title_text)
	t.set_color("font_uneditable_color",  "LineEdit", disabled_text)
	t.set_color("font_placeholder_color", "LineEdit", placeholder)
	t.set_color("selection_color",        "LineEdit", title_bg)
	t.set_color("caret_color",            "LineEdit", win_text)

	# ── TextEdit (TextArea) ──
	t.set_stylebox("normal",    "TextEdit", _sunken.call(win_bg))
	var te_focus = _sunken.call(win_bg)
	te_focus.border_color = Color(0, 0, 0)
	t.set_stylebox("focus",     "TextEdit", te_focus)
	t.set_stylebox("read_only", "TextEdit", _sunken.call(btn_face))
	t.set_color("font_color",             "TextEdit", win_text)
	t.set_color("font_selected_color",    "TextEdit", title_text)
	t.set_color("font_readonly_color",    "TextEdit", disabled_text)
	t.set_color("font_placeholder_color", "TextEdit", placeholder)
	t.set_color("selection_color",        "TextEdit", title_bg)
	t.set_color("caret_color",            "TextEdit", win_text)

	# ── Label ──
	t.set_color("font_color",        "Label", win_text)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))

	# ── CheckBox ──
	var cb_bg = StyleBoxFlat.new()
	cb_bg.bg_color = Color(0, 0, 0, 0)
	cb_bg.set_content_margin_all(2)
	for state in ["normal", "hover", "pressed"]:
		t.set_stylebox(state, "CheckBox",   cb_bg)
		t.set_stylebox(state, "CheckButton",cb_bg)
	for ctype in ["CheckBox", "CheckButton"]:
		t.set_color("font_color",         ctype, win_text)
		t.set_color("font_hover_color",   ctype, win_text)
		t.set_color("font_pressed_color", ctype, win_text)

	# ── OptionButton (ComboBox) ──
	var ob = _raised.call(btn_face)
	ob.content_margin_right = 20
	t.set_stylebox("normal",   "OptionButton", ob)
	t.set_stylebox("hover",    "OptionButton", ob)
	t.set_stylebox("pressed",  "OptionButton", ob)
	t.set_stylebox("disabled", "OptionButton", ob)
	t.set_color("font_color",         "OptionButton", win_text)
	t.set_color("font_hover_color",   "OptionButton", win_text)
	t.set_color("font_pressed_color", "OptionButton", win_text)

	# ── ItemList (ListBox) ──
	t.set_stylebox("panel", "ItemList", _sunken.call(win_bg))
	t.set_color("font_color",          "ItemList", win_text)
	t.set_color("font_selected_color", "ItemList", title_text)
	var il_sel = StyleBoxFlat.new()
	il_sel.bg_color = title_bg; il_sel.set_content_margin_all(2)
	t.set_stylebox("selected",       "ItemList", il_sel)
	t.set_stylebox("selected_focus", "ItemList", il_sel)

	# ── Tree (TreeView) ──
	t.set_stylebox("panel", "Tree", _sunken.call(win_bg))
	t.set_color("font_color",          "Tree", win_text)
	t.set_color("font_selected_color", "Tree", title_text)
	var tree_sel = StyleBoxFlat.new()
	tree_sel.bg_color = title_bg; tree_sel.set_content_margin_all(2)
	t.set_stylebox("selected",       "Tree", tree_sel)
	t.set_stylebox("selected_focus", "Tree", tree_sel)

	# ── TabContainer ──
	var tc = StyleBoxFlat.new()
	tc.bg_color = btn_face; tc.border_color = btn_shadow
	tc.set_border_width_all(1); tc.set_content_margin_all(4)
	t.set_stylebox("panel", "TabContainer", tc)
	var tab_s = StyleBoxFlat.new()
	tab_s.bg_color = btn_face; tab_s.border_color = btn_shadow
	tab_s.border_width_left = 1; tab_s.border_width_top = 1
	tab_s.border_width_right = 1; tab_s.border_width_bottom = 0
	tab_s.content_margin_left = 8; tab_s.content_margin_right = 8
	tab_s.content_margin_top = 4; tab_s.content_margin_bottom = 4
	t.set_stylebox("tab_selected", "TabContainer", tab_s)
	t.set_stylebox("tab_selected", "TabBar",       tab_s)
	var tab_u = StyleBoxFlat.new()
	tab_u.bg_color = Color(0.75, 0.74, 0.72); tab_u.border_color = btn_shadow
	tab_u.set_border_width_all(1)
	tab_u.content_margin_left = 8; tab_u.content_margin_right = 8
	tab_u.content_margin_top = 4; tab_u.content_margin_bottom = 4
	t.set_stylebox("tab_unselected", "TabContainer", tab_u)
	t.set_stylebox("tab_unselected", "TabBar",       tab_u)
	t.set_color("font_selected_color",   "TabContainer", win_text)
	t.set_color("font_unselected_color", "TabContainer", disabled_text)
	t.set_color("font_selected_color",   "TabBar",       win_text)
	t.set_color("font_unselected_color", "TabBar",       disabled_text)

	# ── ProgressBar ──
	t.set_stylebox("background", "ProgressBar", _sunken.call(btn_face))
	var pb_fill = StyleBoxFlat.new()
	pb_fill.bg_color = progress_fill; pb_fill.set_content_margin_all(0)
	t.set_stylebox("fill", "ProgressBar", pb_fill)

	# ── ScrollBars ──
	for sb_type in ["HScrollBar", "VScrollBar"]:
		var sc = StyleBoxFlat.new()
		sc.bg_color = scrollbar_bg; sc.set_content_margin_all(0)
		t.set_stylebox("scroll", sb_type, sc)
		var gr = _raised.call(btn_face)
		gr.content_margin_left = 2; gr.content_margin_right = 2
		gr.content_margin_top = 2; gr.content_margin_bottom = 2
		t.set_stylebox("grabber",          sb_type, gr)
		t.set_stylebox("grabber_highlight",sb_type, gr)
		t.set_stylebox("grabber_pressed",  sb_type, gr)

	# ── Sliders ──
	for sl_type in ["HSlider", "VSlider"]:
		var sl = StyleBoxFlat.new()
		sl.bg_color = scrollbar_bg; sl.border_color = btn_shadow
		sl.set_border_width_all(1); sl.set_content_margin_all(0)
		t.set_stylebox("slider", sl_type, sl)
		t.set_stylebox("grabber_area",           sl_type, _raised.call(btn_face))
		t.set_stylebox("grabber_area_highlight", sl_type, _raised.call(btn_face))

	# ── MenuBar ──
	var menu = StyleBoxFlat.new()
	menu.bg_color = btn_face; menu.set_content_margin_all(2)
	t.set_stylebox("normal",  "MenuBar", menu)
	t.set_stylebox("hover",   "MenuBar", menu)
	t.set_stylebox("pressed", "MenuBar", menu)
	t.set_color("font_color",         "MenuBar", win_text)
	t.set_color("font_hover_color",   "MenuBar", win_text)
	t.set_color("font_pressed_color", "MenuBar", win_text)

	# ── PopupMenu ──
	var popup = StyleBoxFlat.new()
	popup.bg_color = btn_face; popup.border_color = btn_shadow
	popup.set_border_width_all(1); popup.set_content_margin_all(2)
	t.set_stylebox("panel", "PopupMenu", popup)
	var popup_hover = StyleBoxFlat.new()
	popup_hover.bg_color = title_bg; popup_hover.set_content_margin_all(2)
	t.set_stylebox("hover", "PopupMenu", popup_hover)
	t.set_color("font_color",       "PopupMenu", win_text)
	t.set_color("font_hover_color", "PopupMenu", title_text)

	# ── RichTextLabel ──
	t.set_stylebox("normal", "RichTextLabel", _sunken.call(win_bg))
	t.set_color("default_color",      "RichTextLabel", win_text)
	t.set_color("font_selected_color","RichTextLabel", title_text)
	t.set_color("selection_color",    "RichTextLabel", title_bg)

	# ── SpinBox ──
	t.set_color("font_color", "SpinBox", win_text)

	# ── Tooltip ──
	var tip = StyleBoxFlat.new()
	tip.bg_color = Color(1, 1, 0.94); tip.border_color = Color(0, 0, 0)
	tip.set_border_width_all(1); tip.set_content_margin_all(4)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", win_text)

	return t
