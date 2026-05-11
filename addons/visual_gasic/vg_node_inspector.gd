@tool
## VG Node Inspector
##
## A reusable properties inspector panel for VG 2D and 3D editors.
## Introspects the selected node and generates property editors for:
##   - Common properties (visibility, modulate, z_index, etc.)
##   - Physics properties (collision layer/mask)
##   - Material / color properties
##   - Light properties
##   - Groups
##   - Signals (read-only list with "Connect" to generate VG Sub stub)
##
## Usage:
##   var inspector = preload("vg_node_inspector.gd").new()
##   parent_vbox.add_child(inspector)
##   inspector.inspect(some_node)
##   inspector.clear()
extends VBoxContainer

## Emitted when user clicks "Connect" on a signal — host editor can generate code stub
signal signal_connect_requested(node_name: String, signal_name: String)

## Emitted when a property is changed via the inspector
signal property_changed(node: Node, property: String, old_value: Variant, new_value: Variant)

var _target_node: Node = null
var _updating: bool = false  # prevent feedback loops

# Section containers for toggling
var _sections: Dictionary = {}  # { section_name: VBoxContainer }
var _section_headers: Dictionary = {}  # { section_name: Button }

# ─── Property widget references (to update on selection change) ───
var _prop_widgets: Dictionary = {}  # { property_path: Control }


func _init() -> void:
	name = "VGNodeInspector"
	size_flags_horizontal = SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 2)


## Inspect a node — builds or rebuilds the full inspector UI.
func inspect(node: Node) -> void:
	if node == _target_node:
		_refresh_values()
		return
	_target_node = node
	_rebuild()


## Clear the inspector.
func clear() -> void:
	_target_node = null
	_prop_widgets.clear()
	_sections.clear()
	_section_headers.clear()
	for c in get_children():
		c.queue_free()


## Refresh displayed values from the target node without rebuilding.
func _refresh_values() -> void:
	if not is_instance_valid(_target_node):
		return
	_updating = true
	for prop_path in _prop_widgets:
		var w = _prop_widgets[prop_path]
		if not is_instance_valid(w):
			continue
		var val = _target_node.get(prop_path)
		if w is SpinBox:
			w.value = val if val != null else 0.0
		elif w is CheckButton or w is CheckBox:
			w.button_pressed = val if val != null else false
		elif w is ColorPickerButton:
			w.color = val if val != null else Color.WHITE
		elif w is OptionButton:
			if val is int:
				w.selected = val
		elif w is LineEdit:
			var s = str(val) if val != null else ""
			if w.text != s:
				w.text = s
	_updating = false


## Full rebuild of the inspector UI for the current target node.
func _rebuild() -> void:
	# Clear existing
	_prop_widgets.clear()
	_sections.clear()
	_section_headers.clear()
	for c in get_children():
		c.queue_free()

	if not is_instance_valid(_target_node):
		return

	# Header (VB6 dialect: "TextBox" not "LineEdit")
	var _vb6_type: String = VGIntelliSense.to_vb6_type_name(_target_node.get_class())
	var header = _make_section_header("🔍 Properties: " + _vb6_type)
	add_child(header)

	# ── Node section (name, visibility) ──
	_add_section("Node")
	_add_bool_prop("Node", "visible", "Visible")

	# 2D-specific
	if _target_node is CanvasItem:
		_add_color_prop("Node", "modulate", "Modulate")
		_add_color_prop("Node", "self_modulate", "Self Modulate")
		_add_bool_prop("Node", "show_behind_parent", "Show Behind Parent")
		if _target_node.get("z_index") != null:
			_add_int_prop("Node", "z_index", "Z Index", -4096, 4096)
		if _target_node.get("z_as_relative") != null:
			_add_bool_prop("Node", "z_as_relative", "Z Is Relative")

	# 3D-specific visibility
	if _target_node is Node3D:
		pass  # visible already covered

	# ── Sprite / Texture section ──
	if _target_node is Sprite2D or _target_node is Sprite3D:
		_add_section("Sprite")
		_add_bool_prop("Sprite", "flip_h", "Flip H")
		_add_bool_prop("Sprite", "flip_v", "Flip V")
		if _target_node is Sprite2D:
			_add_bool_prop("Sprite", "centered", "Centered")
			_add_int_prop("Sprite", "hframes", "H Frames", 1, 64)
			_add_int_prop("Sprite", "vframes", "V Frames", 1, 64)
			_add_int_prop("Sprite", "frame", "Frame", 0, 256)

	# ── ColorRect ──
	if _target_node is ColorRect:
		_add_section("ColorRect")
		_add_color_prop("ColorRect", "color", "Color")

	# ── Label / RichTextLabel ──
	if _target_node is Label:
		_add_section("Label")
		_add_string_prop("Label", "text", "Text")
		_add_enum_prop("Label", "horizontal_alignment", "H Align",
			["Left", "Center", "Right", "Fill"])
		_add_enum_prop("Label", "vertical_alignment", "V Align",
			["Top", "Center", "Bottom", "Fill"])
		_add_bool_prop("Label", "autowrap_mode", "Autowrap")

	if _target_node is Label3D:
		_add_section("Label3D")
		_add_string_prop("Label3D", "text", "Text")
		_add_float_prop("Label3D", "font_size", "Font Size", 1.0, 256.0, 1.0)
		_add_color_prop("Label3D", "modulate", "Color")
		_add_bool_prop("Label3D", "billboard", "Billboard")

	# ── Line2D ──
	if _target_node is Line2D:
		_add_section("Line2D")
		_add_float_prop("Line2D", "width", "Width", 0.1, 100.0, 0.5)
		_add_color_prop("Line2D", "default_color", "Color")

	# ── Light2D ──
	if _target_node is PointLight2D:
		_add_section("Light2D")
		_add_color_prop("Light2D", "color", "Color")
		_add_float_prop("Light2D", "energy", "Energy", 0.0, 16.0, 0.1)
		_add_float_prop("Light2D", "texture_scale", "Scale", 0.01, 10.0, 0.1)

	# ── Light3D ──
	if _target_node is Light3D:
		_add_section("Light3D")
		_add_color_prop("Light3D", "light_color", "Color")
		_add_float_prop("Light3D", "light_energy", "Energy", 0.0, 16.0, 0.1)
		if _target_node is OmniLight3D:
			_add_float_prop("Light3D", "omni_range", "Range", 0.1, 100.0, 0.5)
		elif _target_node is SpotLight3D:
			_add_float_prop("Light3D", "spot_range", "Range", 0.1, 100.0, 0.5)
			_add_float_prop("Light3D", "spot_angle", "Angle", 1.0, 179.0, 1.0)
		if _target_node.get("shadow_enabled") != null:
			_add_bool_prop("Light3D", "shadow_enabled", "Cast Shadow")

	# ── Camera2D ──
	if _target_node is Camera2D:
		_add_section("Camera2D")
		_add_bool_prop("Camera2D", "enabled", "Enabled")
		_add_float_prop("Camera2D", "zoom", "Zoom", 0.01, 10.0, 0.1)

	# ── Camera3D ──
	if _target_node is Camera3D:
		_add_section("Camera3D")
		_add_bool_prop("Camera3D", "current", "Current")
		_add_float_prop("Camera3D", "fov", "FOV", 10.0, 170.0, 1.0)
		_add_float_prop("Camera3D", "near", "Near", 0.001, 10.0, 0.01)
		_add_float_prop("Camera3D", "far", "Far", 10.0, 10000.0, 10.0)

	# ── RayCast2D ──
	if _target_node is RayCast2D:
		_add_section("RayCast2D")
		_add_bool_prop("RayCast2D", "enabled", "Enabled")

	# ── AudioStreamPlayer2D / 3D ──
	if _target_node is AudioStreamPlayer2D:
		_add_section("Audio")
		_add_float_prop("Audio", "volume_db", "Volume dB", -80.0, 24.0, 0.5)
		_add_float_prop("Audio", "max_distance", "Max Distance", 1.0, 10000.0, 10.0)
	if _target_node is AudioStreamPlayer3D:
		_add_section("Audio")
		_add_float_prop("Audio", "volume_db", "Volume dB", -80.0, 24.0, 0.5)
		_add_float_prop("Audio", "max_db", "Max dB", -80.0, 24.0, 0.5)

	# ── GPUParticles2D / CPUParticles2D ──
	if _target_node is GPUParticles2D or _target_node is CPUParticles2D:
		_add_section("Particles")
		_add_bool_prop("Particles", "emitting", "Emitting")
		_add_float_prop("Particles", "lifetime", "Lifetime", 0.01, 60.0, 0.1)
		_add_int_prop("Particles", "amount", "Amount", 1, 1000)

	# ── CSG properties ──
	if _target_node is CSGShape3D:
		_add_section("CSG")
		_add_enum_prop("CSG", "operation", "Operation",
			["Union", "Intersection", "Subtraction"])
		_add_bool_prop("CSG", "use_collision", "Use Collision")

	# ── GeometryInstance3D material color ──
	if _target_node is GeometryInstance3D:
		_add_section("Material")
		_add_material_color("Material")

	# ── Collision Layer/Mask ──
	if _target_node is CollisionObject2D or _target_node is CollisionObject3D:
		_add_section("Physics")
		_add_collision_grid("Physics", "collision_layer", "Collision Layer")
		_add_collision_grid("Physics", "collision_mask", "Collision Mask")

	# Area-specific
	if _target_node is Area2D or _target_node is Area3D:
		_add_bool_prop("Physics", "monitoring", "Monitoring")
		_add_bool_prop("Physics", "monitorable", "Monitorable")

	# RigidBody
	if _target_node is RigidBody2D:
		_add_float_prop("Physics", "mass", "Mass", 0.001, 10000.0, 0.1)
		_add_float_prop("Physics", "gravity_scale", "Gravity Scale", -10.0, 10.0, 0.1)
		_add_bool_prop("Physics", "freeze", "Freeze")
	if _target_node is RigidBody3D:
		_add_float_prop("Physics", "mass", "Mass", 0.001, 10000.0, 0.1)
		_add_float_prop("Physics", "gravity_scale", "Gravity Scale", -10.0, 10.0, 0.1)
		_add_bool_prop("Physics", "freeze", "Freeze")

	# CollisionShape size
	if _target_node is CollisionShape2D:
		_add_section("Shape")
		var shape = _target_node.shape
		if shape is RectangleShape2D:
			_add_shape_vector2("Shape", shape, "size", "Size")
		elif shape is CircleShape2D:
			_add_shape_float("Shape", shape, "radius", "Radius", 0.1, 1000.0)
		elif shape is CapsuleShape2D:
			_add_shape_float("Shape", shape, "radius", "Radius", 0.1, 1000.0)
			_add_shape_float("Shape", shape, "height", "Height", 0.1, 2000.0)

	if _target_node is CollisionShape3D:
		_add_section("Shape")
		var shape = _target_node.shape
		if shape is BoxShape3D:
			_add_shape_vector3("Shape", shape, "size", "Size")
		elif shape is SphereShape3D:
			_add_shape_float("Shape", shape, "radius", "Radius", 0.01, 100.0)
		elif shape is CapsuleShape3D:
			_add_shape_float("Shape", shape, "radius", "Radius", 0.01, 100.0)
			_add_shape_float("Shape", shape, "height", "Height", 0.01, 200.0)

	# ── Groups ──
	_add_section("Groups")
	_build_groups_editor()

	# ── Signals ──
	_add_section("Signals")
	_build_signals_list()

	_updating = false


# ─── Section Headers ────────────────────────────────────────

func _make_section_header(text: String) -> PanelContainer:
	var panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.26, 0.35)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", sb)
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	panel.add_child(lbl)
	return panel


func _add_section(section_name: String) -> void:
	# Collapsible header button
	var btn = Button.new()
	btn.text = "▼ " + section_name
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.flat = true
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	add_child(btn)
	_section_headers[section_name] = btn

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_child(vbox)
	add_child(margin)
	_sections[section_name] = vbox

	btn.pressed.connect(func():
		var vis = not vbox.visible
		vbox.visible = vis
		btn.text = ("▼ " if vis else "▶ ") + section_name
	)


func _get_section(section_name: String) -> VBoxContainer:
	if not _sections.has(section_name):
		_add_section(section_name)
	return _sections[section_name]


# ─── Property Widgets ───────────────────────────────────────

func _add_bool_prop(section: String, prop: String, label_text: String) -> void:
	if _target_node.get(prop) == null:
		return
	var sec = _get_section(section)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	lbl.custom_minimum_size.x = 90
	row.add_child(lbl)
	var cb = CheckButton.new()
	cb.button_pressed = _target_node.get(prop)
	cb.toggled.connect(func(val):
		if _updating: return
		var old = _target_node.get(prop)
		_target_node.set(prop, val)
		property_changed.emit(_target_node, prop, old, val)
	)
	row.add_child(cb)
	sec.add_child(row)
	_prop_widgets[prop] = cb


func _add_int_prop(section: String, prop: String, label_text: String, min_val: int = -9999, max_val: int = 9999) -> void:
	if _target_node.get(prop) == null:
		return
	var sec = _get_section(section)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	lbl.custom_minimum_size.x = 90
	row.add_child(lbl)
	var spin = SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = 1
	spin.value = _target_node.get(prop)
	spin.size_flags_horizontal = SIZE_EXPAND_FILL
	spin.value_changed.connect(func(val):
		if _updating: return
		var old = _target_node.get(prop)
		_target_node.set(prop, int(val))
		property_changed.emit(_target_node, prop, old, int(val))
	)
	row.add_child(spin)
	sec.add_child(row)
	_prop_widgets[prop] = spin


func _add_float_prop(section: String, prop: String, label_text: String, min_val: float = -9999.0, max_val: float = 9999.0, step: float = 0.1) -> void:
	if _target_node.get(prop) == null:
		return
	var sec = _get_section(section)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	lbl.custom_minimum_size.x = 90
	row.add_child(lbl)
	var spin = SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step
	spin.value = _target_node.get(prop)
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.size_flags_horizontal = SIZE_EXPAND_FILL
	spin.value_changed.connect(func(val):
		if _updating: return
		var old = _target_node.get(prop)
		_target_node.set(prop, val)
		property_changed.emit(_target_node, prop, old, val)
	)
	row.add_child(spin)
	sec.add_child(row)
	_prop_widgets[prop] = spin


func _add_string_prop(section: String, prop: String, label_text: String) -> void:
	if _target_node.get(prop) == null:
		return
	var sec = _get_section(section)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	lbl.custom_minimum_size.x = 90
	row.add_child(lbl)
	var le = LineEdit.new()
	le.text = str(_target_node.get(prop))
	le.size_flags_horizontal = SIZE_EXPAND_FILL
	le.text_submitted.connect(func(new_text):
		if _updating: return
		var old = _target_node.get(prop)
		_target_node.set(prop, new_text)
		property_changed.emit(_target_node, prop, old, new_text)
	)
	row.add_child(le)
	sec.add_child(row)
	_prop_widgets[prop] = le


func _add_color_prop(section: String, prop: String, label_text: String) -> void:
	if _target_node.get(prop) == null:
		return
	var sec = _get_section(section)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	lbl.custom_minimum_size.x = 90
	row.add_child(lbl)
	var picker = ColorPickerButton.new()
	picker.color = _target_node.get(prop)
	picker.custom_minimum_size = Vector2(60, 24)
	picker.size_flags_horizontal = SIZE_EXPAND_FILL
	picker.color_changed.connect(func(c):
		if _updating: return
		var old = _target_node.get(prop)
		_target_node.set(prop, c)
		property_changed.emit(_target_node, prop, old, c)
	)
	row.add_child(picker)
	sec.add_child(row)
	_prop_widgets[prop] = picker


func _add_enum_prop(section: String, prop: String, label_text: String, options: Array) -> void:
	if _target_node.get(prop) == null:
		return
	var sec = _get_section(section)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	lbl.custom_minimum_size.x = 90
	row.add_child(lbl)
	var opt = OptionButton.new()
	for o in options:
		opt.add_item(o)
	var current = _target_node.get(prop)
	if current is int and current < options.size():
		opt.selected = current
	opt.size_flags_horizontal = SIZE_EXPAND_FILL
	opt.item_selected.connect(func(idx):
		if _updating: return
		var old = _target_node.get(prop)
		_target_node.set(prop, idx)
		property_changed.emit(_target_node, prop, old, idx)
	)
	row.add_child(opt)
	sec.add_child(row)
	_prop_widgets[prop] = opt


# ─── Material Color (3D) ────────────────────────────────────

func _add_material_color(section: String) -> void:
	var sec = _get_section(section)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var lbl = Label.new()
	lbl.text = "Albedo"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	lbl.custom_minimum_size.x = 90
	row.add_child(lbl)
	var picker = ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(60, 24)
	picker.size_flags_horizontal = SIZE_EXPAND_FILL

	# Try to read existing material color
	var geo = _target_node as GeometryInstance3D
	if geo:
		var mat = geo.get_surface_override_material(0) if geo.get_surface_override_material_count() > 0 else null
		if mat == null and geo is MeshInstance3D and geo.mesh:
			mat = geo.mesh.surface_get_material(0) if geo.mesh.get_surface_count() > 0 else null
		if mat is StandardMaterial3D:
			picker.color = mat.albedo_color
		else:
			picker.color = Color.WHITE

	picker.color_changed.connect(func(c):
		if _updating: return
		if not is_instance_valid(_target_node): return
		var g = _target_node as GeometryInstance3D
		if not g: return
		var m = g.get_surface_override_material(0) if g.get_surface_override_material_count() > 0 else null
		if not m is StandardMaterial3D:
			m = StandardMaterial3D.new()
		m.albedo_color = c
		g.set_surface_override_material(0, m)
		property_changed.emit(_target_node, "material_color", Color.WHITE, c)
	)
	row.add_child(picker)
	sec.add_child(row)


# ─── Collision Layer/Mask Grid ──────────────────────────────

func _add_collision_grid(section: String, prop: String, label_text: String) -> void:
	if _target_node.get(prop) == null:
		return
	var sec = _get_section(section)

	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	sec.add_child(lbl)

	# 4 rows × 8 columns = 32 bits (Godot standard)
	var grid = GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 1)
	grid.add_theme_constant_override("v_separation", 1)

	var current_val: int = _target_node.get(prop)
	var checkboxes: Array = []

	for bit in range(32):
		var cb = CheckBox.new()
		cb.tooltip_text = "Layer " + str(bit + 1)
		cb.button_pressed = (current_val & (1 << bit)) != 0
		cb.custom_minimum_size = Vector2(20, 20)
		cb.toggled.connect(_on_collision_bit_toggled.bind(prop, bit))
		grid.add_child(cb)
		checkboxes.append(cb)

	sec.add_child(grid)

	# Store checkboxes for refresh — use composite key
	_prop_widgets[prop + "_grid"] = checkboxes


func _on_collision_bit_toggled(on: bool, prop: String, bit: int) -> void:
	if _updating or not is_instance_valid(_target_node):
		return
	var old_val: int = _target_node.get(prop)
	var new_val: int
	if on:
		new_val = old_val | (1 << bit)
	else:
		new_val = old_val & ~(1 << bit)
	_target_node.set(prop, new_val)
	property_changed.emit(_target_node, prop, old_val, new_val)


# ─── Shape Properties ──────────────────────────────────────

func _add_shape_float(section: String, shape: Resource, prop: String, label_text: String, min_val: float = 0.1, max_val: float = 1000.0) -> void:
	var sec = _get_section(section)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	lbl.custom_minimum_size.x = 90
	row.add_child(lbl)
	var spin = SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = 0.1
	spin.value = shape.get(prop)
	spin.size_flags_horizontal = SIZE_EXPAND_FILL
	spin.value_changed.connect(func(val):
		if _updating: return
		shape.set(prop, val)
	)
	row.add_child(spin)
	sec.add_child(row)


func _add_shape_vector2(section: String, shape: Resource, prop: String, label_text: String) -> void:
	var sec = _get_section(section)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	sec.add_child(lbl)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var vec: Vector2 = shape.get(prop)
	var sx = SpinBox.new()
	sx.prefix = "X "
	sx.min_value = 0.1
	sx.max_value = 2000
	sx.step = 0.5
	sx.value = vec.x
	sx.size_flags_horizontal = SIZE_EXPAND_FILL
	sx.value_changed.connect(func(v):
		if _updating: return
		var cur = shape.get(prop)
		shape.set(prop, Vector2(v, cur.y))
	)
	row.add_child(sx)
	var sy = SpinBox.new()
	sy.prefix = "Y "
	sy.min_value = 0.1
	sy.max_value = 2000
	sy.step = 0.5
	sy.value = vec.y
	sy.size_flags_horizontal = SIZE_EXPAND_FILL
	sy.value_changed.connect(func(v):
		if _updating: return
		var cur = shape.get(prop)
		shape.set(prop, Vector2(cur.x, v))
	)
	row.add_child(sy)
	sec.add_child(row)


func _add_shape_vector3(section: String, shape: Resource, prop: String, label_text: String) -> void:
	var sec = _get_section(section)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	sec.add_child(lbl)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var vec: Vector3 = shape.get(prop)
	for axis_name in ["x", "y", "z"]:
		var spin = SpinBox.new()
		spin.prefix = axis_name.to_upper() + " "
		spin.min_value = 0.01
		spin.max_value = 200
		spin.step = 0.05
		spin.value = vec[axis_name]
		spin.size_flags_horizontal = SIZE_EXPAND_FILL
		var ax = axis_name  # capture for closure
		spin.value_changed.connect(func(v):
			if _updating: return
			var cur: Vector3 = shape.get(prop)
			cur[ax] = v
			shape.set(prop, cur)
		)
		row.add_child(spin)
	sec.add_child(row)


# ─── Groups Editor ──────────────────────────────────────────

func _build_groups_editor() -> void:
	var sec = _get_section("Groups")

	# Current groups
	var groups = _target_node.get_groups()
	for g in groups:
		var g_str = str(g)
		# Skip internal Godot groups
		if g_str.begins_with("_"):
			continue
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var tag = Label.new()
		tag.text = "🏷️ " + g_str
		tag.add_theme_font_size_override("font_size", 11)
		tag.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		tag.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(tag)
		var rm_btn = Button.new()
		rm_btn.text = "✕"
		rm_btn.tooltip_text = "Remove from group '" + g_str + "'"
		rm_btn.add_theme_font_size_override("font_size", 10)
		rm_btn.flat = true
		rm_btn.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
		var group_to_remove = g_str
		rm_btn.pressed.connect(func():
			_target_node.remove_from_group(group_to_remove)
			_rebuild()
		)
		row.add_child(rm_btn)
		sec.add_child(row)

	# Add group row
	var add_row = HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 4)
	var add_le = LineEdit.new()
	add_le.placeholder_text = "group name..."
	add_le.size_flags_horizontal = SIZE_EXPAND_FILL
	add_le.add_theme_font_size_override("font_size", 11)
	add_row.add_child(add_le)
	var add_btn = Button.new()
	add_btn.text = "+ Add"
	add_btn.add_theme_font_size_override("font_size", 10)
	add_btn.pressed.connect(func():
		var g_name = add_le.text.strip_edges()
		if g_name.is_empty(): return
		_target_node.add_to_group(g_name, true)
		_rebuild()
	)
	add_le.text_submitted.connect(func(_t):
		add_btn.pressed.emit()
	)
	add_row.add_child(add_btn)
	sec.add_child(add_row)


# ─── Signals List ───────────────────────────────────────────

func _build_signals_list() -> void:
	var sec = _get_section("Signals")

	# Get the class's signal list
	var sig_list = _target_node.get_signal_list()
	if sig_list.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "(no signals)"
		empty_lbl.add_theme_font_size_override("font_size", 10)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		sec.add_child(empty_lbl)
		return

	# Filter to show the most commonly used signals
	var common_signals = [
		"body_entered", "body_exited",
		"area_entered", "area_exited",
		"pressed", "toggled",
		"value_changed", "text_submitted", "text_changed",
		"mouse_entered", "mouse_exited",
		"input_event",
		"visibility_changed",
		"ready", "tree_entered", "tree_exiting",
		"timeout",
		"animation_finished",
		"screen_entered", "screen_exited",
		"sleeping_state_changed",
	]

	var shown_count = 0
	for sig_info in sig_list:
		var sig_name: String = sig_info["name"]
		if sig_name not in common_signals and shown_count > 12:
			continue  # limit noise, show all common + first 12 others

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var sig_lbl = Label.new()
		sig_lbl.text = "⚡ " + sig_name
		sig_lbl.add_theme_font_size_override("font_size", 10)
		var is_common = sig_name in common_signals
		sig_lbl.add_theme_color_override("font_color",
			Color(0.9, 0.85, 0.5) if is_common else Color(0.6, 0.6, 0.6))
		sig_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(sig_lbl)

		# "Connect" button
		var conn_btn = Button.new()
		conn_btn.text = "→ Sub"
		conn_btn.tooltip_text = "Generate a VG Sub handler for " + sig_name
		conn_btn.add_theme_font_size_override("font_size", 9)
		conn_btn.flat = true
		conn_btn.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
		var sn = sig_name  # capture
		conn_btn.pressed.connect(func():
			signal_connect_requested.emit(_target_node.name, sn)
		)
		row.add_child(conn_btn)

		# Show connection count
		var conns = _target_node.get_signal_connection_list(sig_name)
		if conns.size() > 0:
			var count_lbl = Label.new()
			count_lbl.text = "(" + str(conns.size()) + ")"
			count_lbl.add_theme_font_size_override("font_size", 9)
			count_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
			row.add_child(count_lbl)

		sec.add_child(row)
		shown_count += 1

	if sig_list.size() > shown_count:
		var more = Label.new()
		more.text = "... +" + str(sig_list.size() - shown_count) + " more signals"
		more.add_theme_font_size_override("font_size", 9)
		more.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		sec.add_child(more)
