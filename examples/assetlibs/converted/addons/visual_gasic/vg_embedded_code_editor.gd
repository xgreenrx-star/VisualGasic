@tool
extends VBoxContainer
## VB6-Style Embedded Code Editor
##
## Replaces the Form Designer canvas in-place when the user double-clicks a
## control or chooses View → Code.  The Toolbox, Properties panel, and Project
## Explorer all remain visible — exactly like VB6.
##
## Layout (top to bottom):
##   ┌─────────────────────────────────────────────┐
##   │ [Object ▼]  [Event ▼]                       │  ← procedure nav bar
##   ├─────────────────────────────────────────────┤
##   │                                             │
##   │            VGCodeEdit (.vg source)          │  ← full code editor
##   │                                             │
##   └─────────────────────────────────────────────┘

# =============================================================================
# SIGNALS
# =============================================================================

signal view_object_requested          ## user clicked "View Object" or pressed F7
signal code_saved(path: String)       ## code was flushed to disk

# =============================================================================
# STATE
# =============================================================================

## Path to the currently loaded .vg file (e.g. "res://Form1.vg")
var _vg_path: String = ""

## Whether unsaved changes exist
var _dirty: bool = false

## The code editor widget
var _code_edit: CodeEdit = null  # will be VGCodeEdit

## Procedure navigation: Object dropdown
var _object_combo: OptionButton = null

## Procedure navigation: Event/Procedure dropdown
var _proc_combo: OptionButton = null

## Parsed procedure list: Array of { name: String, line: int }
var _procedures: Array = []

## Known control names on the form (for Object dropdown)
var _control_names: Array[String] = []

# VB6 cream theme colors
const BG_COLOR := Color(0.98, 0.97, 0.93)         # cream background
const TEXT_COLOR := Color(0.1, 0.1, 0.1)           # near-black text
const KEYWORD_COLOR := Color(0.0, 0.0, 0.6)        # dark blue keywords
const COMMENT_COLOR := Color(0.0, 0.5, 0.0)        # green comments
const STRING_COLOR := Color(0.6, 0.0, 0.0)         # dark red strings
const NUMBER_COLOR := Color(0.0, 0.4, 0.4)         # teal numbers
const TOOLBAR_BG := Color(0.92, 0.91, 0.87)        # slightly darker toolbar
const BORDER_COLOR := Color(0.75, 0.74, 0.70)      # subtle border

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	name = "EmbeddedCodeEditor"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_build_ui()

func _build_ui() -> void:
	# ── Procedure navigation bar ──
	var nav_bar := HBoxContainer.new()
	nav_bar.name = "ProcNavBar"
	nav_bar.custom_minimum_size.y = 28
	nav_bar.add_theme_constant_override("separation", 4)

	# Background panel for the nav bar
	var nav_panel := PanelContainer.new()
	nav_panel.name = "NavPanel"
	var nav_sb := StyleBoxFlat.new()
	nav_sb.bg_color = TOOLBAR_BG
	nav_sb.border_color = BORDER_COLOR
	nav_sb.set_border_width_all(1)
	nav_sb.border_width_top = 0
	nav_sb.content_margin_left = 4
	nav_sb.content_margin_right = 4
	nav_sb.content_margin_top = 2
	nav_sb.content_margin_bottom = 2
	nav_panel.add_theme_stylebox_override("panel", nav_sb)

	var nav_hbox := HBoxContainer.new()
	nav_hbox.add_theme_constant_override("separation", 8)

	# Object dropdown (left half)
	_object_combo = OptionButton.new()
	_object_combo.name = "ObjectCombo"
	_object_combo.custom_minimum_size.x = 160
	_object_combo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_object_combo.tooltip_text = "Object"
	_object_combo.add_theme_font_size_override("font_size", 12)
	_object_combo.item_selected.connect(_on_object_selected)
	nav_hbox.add_child(_object_combo)

	# Procedure dropdown (right half)
	_proc_combo = OptionButton.new()
	_proc_combo.name = "ProcCombo"
	_proc_combo.custom_minimum_size.x = 160
	_proc_combo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_proc_combo.tooltip_text = "Procedure"
	_proc_combo.add_theme_font_size_override("font_size", 12)
	_proc_combo.item_selected.connect(_on_proc_selected)
	nav_hbox.add_child(_proc_combo)

	nav_panel.add_child(nav_hbox)
	add_child(nav_panel)

	# ── Code editor ──
	var code_edit_script = load("res://addons/visual_gasic/vg_code_edit.gd")
	if code_edit_script:
		_code_edit = code_edit_script.new()
	else:
		# Fallback to plain CodeEdit
		_code_edit = CodeEdit.new()
		push_warning("VG Embedded Code Editor: vg_code_edit.gd not found, using plain CodeEdit")

	_code_edit.name = "CodeEdit"
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# VB6 cream theme
	_apply_vb6_theme()

	_code_edit.text_changed.connect(_on_code_changed)
	_code_edit.caret_changed.connect(_on_caret_moved)
	add_child(_code_edit)

func _apply_vb6_theme() -> void:
	if not _code_edit:
		return

	# Try to apply theme from VGThemeManager first
	var theme_mgr_script = load("res://addons/visual_gasic/vg_theme_manager.gd")
	if theme_mgr_script and theme_mgr_script.has_method("apply_to_code_edit"):
		theme_mgr_script.apply_to_code_edit(_code_edit)
		return

	# Fallback: VB6 Classic cream theme
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = BG_COLOR
	bg_sb.border_color = BORDER_COLOR
	bg_sb.set_border_width_all(1)
	_code_edit.add_theme_stylebox_override("normal", bg_sb)

	_code_edit.add_theme_color_override("font_color", TEXT_COLOR)
	_code_edit.add_theme_color_override("caret_color", TEXT_COLOR)
	_code_edit.add_theme_color_override("font_selected_color", Color.WHITE)
	_code_edit.add_theme_color_override("selection_color", Color(0.2, 0.4, 0.8, 0.5))
	_code_edit.add_theme_color_override("current_line_color", Color(0.93, 0.92, 0.88))
	_code_edit.add_theme_color_override("line_number_color", Color(0.5, 0.5, 0.5))

	# Override syntax highlighter colors for VB6 look
	if _code_edit.syntax_highlighter and _code_edit.syntax_highlighter is CodeHighlighter:
		var hl: CodeHighlighter = _code_edit.syntax_highlighter
		# Re-color keywords to dark blue
		for keyword in _get_vb6_keywords():
			hl.add_keyword_color(keyword, KEYWORD_COLOR)
		hl.number_color = NUMBER_COLOR
		hl.symbol_color = Color(0.3, 0.3, 0.3)
		hl.function_color = TEXT_COLOR
		hl.member_variable_color = TEXT_COLOR

func _get_vb6_keywords() -> Array:
	# Minimal set — VGCodeEdit already has these, this is fallback
	return [
		"Dim", "Sub", "Function", "End", "If", "Then", "Else", "ElseIf",
		"Select", "Case", "For", "To", "Step", "Next", "Each", "In",
		"Do", "Loop", "While", "Wend", "Until", "With", "Exit",
		"GoTo", "GoSub", "Call", "Return", "And", "Or", "Not", "Xor",
		"Mod", "Is", "Like", "As", "New", "Set", "Let", "Get",
		"Private", "Public", "Static", "Const", "ReDim", "Preserve",
		"ByVal", "ByRef", "Optional", "Property", "True", "False",
		"Nothing", "Null", "Empty", "Me", "On", "Error", "Resume",
		"Print", "Debug", "Try", "Catch", "Finally", "Throw",
		"Type", "Enum", "Class", "Option", "Explicit",
		"Open", "Close", "Input", "Output", "Append", "Line",
		"Write", "Read", "Integer", "Long", "Single", "Double",
		"String", "Boolean", "Byte", "Date", "Variant", "Object",
	]

# =============================================================================
# FILE I/O
# =============================================================================

## Load a .vg file into the editor. If the file doesn't exist, creates a stub.
func load_file(path: String) -> void:
	_vg_path = path

	# Create the file if it doesn't exist
	if not FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string("' Visual Gasic Form Script\nOption Explicit\n\n")
			f.close()

	# Read file contents
	var f := FileAccess.open(path, FileAccess.READ)
	if f:
		var content := f.get_as_text()
		f.close()
		_code_edit.text = content
		_dirty = false
		_rebuild_proc_list()
		_rebuild_object_combo()
		# Update status
		print("VG Code Editor: Loaded ", path)
	else:
		push_warning("VG Code Editor: Cannot open " + path)

## Save the current buffer back to disk.
func save_file() -> void:
	if _vg_path.is_empty():
		return
	var f := FileAccess.open(_vg_path, FileAccess.WRITE)
	if f:
		f.store_string(_code_edit.text)
		f.close()
		_dirty = false
		code_saved.emit(_vg_path)
		print("VG Code Editor: Saved ", _vg_path)

## Returns the currently loaded file path.
func get_file_path() -> String:
	return _vg_path

## Returns true if the buffer has unsaved changes.
func is_dirty() -> bool:
	return _dirty

## Returns the underlying CodeEdit node.
func get_code_edit() -> CodeEdit:
	return _code_edit

# =============================================================================
# EVENT HANDLER INJECTION
# =============================================================================

## Ensure a Sub stub exists for the given event, and navigate the caret to it.
## If it already exists, just jump to it.
func ensure_event_handler(sub_name: String) -> void:
	if not _code_edit:
		return

	var full_sub := "Sub " + sub_name + "()"
	var text := _code_edit.text

	# Check if sub already exists (case-insensitive)
	if text.to_lower().find(full_sub.to_lower()) == -1:
		# Append the stub
		if not text.ends_with("\n"):
			text += "\n"
		text += "\n" + full_sub + "\n    \nEnd Sub\n"
		_code_edit.text = text
		_dirty = true
		_rebuild_proc_list()

	# Navigate to the body line (the blank line inside the Sub)
	var lines := _code_edit.text.split("\n")
	for i in lines.size():
		if lines[i].strip_edges().to_lower().begins_with(full_sub.to_lower()):
			var body_line := i + 1
			_code_edit.set_caret_line(body_line)
			_code_edit.set_caret_column(4)
			# Deferred scroll
			_deferred_center_caret.call_deferred()
			break

	_code_edit.grab_focus()

func _deferred_center_caret() -> void:
	if is_instance_valid(_code_edit):
		_code_edit.center_viewport_to_caret()

# =============================================================================
# PROCEDURE NAVIGATION
# =============================================================================

func _rebuild_proc_list() -> void:
	_procedures.clear()
	if not _code_edit:
		return

	var lines := _code_edit.text.split("\n")
	var rx := RegEx.new()
	rx.compile("^\\s*(?:(?:Public|Private|Static)\\s+)?(?:Sub|Function|Property\\s+(?:Get|Let|Set))\\s+(\\w+)")

	for i in lines.size():
		var m := rx.search(lines[i])
		if m:
			_procedures.append({ "name": m.get_string(1), "line": i, "full": lines[i].strip_edges() })

	# Populate the procedure combo
	_proc_combo.clear()
	_proc_combo.add_item("(Declarations)", 0)
	for idx in _procedures.size():
		var p = _procedures[idx]
		_proc_combo.add_item(p["name"], idx + 1)

	# Select current procedure based on caret position
	_update_proc_selection()

func _rebuild_object_combo() -> void:
	_object_combo.clear()
	_object_combo.add_item("(General)")

	# Add form controls
	for ctrl_name in _control_names:
		_object_combo.add_item(ctrl_name)

	# If file has Form_ events, add "Form" as an object
	if _code_edit and _code_edit.text.find("Form_") != -1:
		# Check it's not already listed
		var has_form := false
		for i in _object_combo.item_count:
			if _object_combo.get_item_text(i) == "Form":
				has_form = true
				break
		if not has_form:
			_object_combo.add_item("Form")

## Sets the list of form control names for the Object dropdown.
func set_control_names(names: Array[String]) -> void:
	_control_names = names
	_rebuild_object_combo()

func _update_proc_selection() -> void:
	if not _code_edit or _procedures.is_empty():
		# Select (Declarations)
		if _proc_combo.item_count > 0:
			_proc_combo.select(0)
		return

	var caret_line := _code_edit.get_caret_line()

	# Find which procedure the caret is inside
	var best_idx := -1
	for i in _procedures.size():
		if _procedures[i]["line"] <= caret_line:
			best_idx = i

	if best_idx >= 0:
		# +1 because item 0 is "(Declarations)"
		_proc_combo.select(best_idx + 1)

		# Also update object combo to match
		var proc_name: String = _procedures[best_idx]["name"]
		if "_" in proc_name:
			var obj_name := proc_name.get_slice("_", 0)
			for i in _object_combo.item_count:
				if _object_combo.get_item_text(i) == obj_name:
					_object_combo.select(i)
					break
	else:
		_proc_combo.select(0)

func _on_proc_selected(index: int) -> void:
	if index == 0:
		# (Declarations) — go to top of file
		_code_edit.set_caret_line(0)
		_code_edit.set_caret_column(0)
		_code_edit.center_viewport_to_caret()
		_code_edit.grab_focus()
		return

	var proc_idx := index - 1
	if proc_idx >= 0 and proc_idx < _procedures.size():
		var line: int = _procedures[proc_idx]["line"]
		_code_edit.set_caret_line(line + 1)  # body line
		_code_edit.set_caret_column(4)
		_code_edit.center_viewport_to_caret()
		_code_edit.grab_focus()

func _on_object_selected(index: int) -> void:
	var obj_name := _object_combo.get_item_text(index)
	if obj_name == "(General)":
		# Jump to declarations area (top)
		_code_edit.set_caret_line(0)
		_code_edit.set_caret_column(0)
		_code_edit.center_viewport_to_caret()
		_code_edit.grab_focus()
		return

	# Filter procedures for this object and update proc combo
	var filtered: Array = []
	for p in _procedures:
		if p["name"].begins_with(obj_name + "_"):
			filtered.append(p)

	if filtered.size() > 0:
		# Jump to first event for this object
		_code_edit.set_caret_line(filtered[0]["line"] + 1)
		_code_edit.set_caret_column(4)
		_code_edit.center_viewport_to_caret()
		_code_edit.grab_focus()

# =============================================================================
# CALLBACKS
# =============================================================================

func _on_code_changed() -> void:
	_dirty = true
	# Rebuild procedure list (debounced via call_deferred to avoid per-keystroke cost)
	_rebuild_proc_list.call_deferred()

func _on_caret_moved() -> void:
	_update_proc_selection()

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if not visible or not _code_edit or not _code_edit.has_focus():
		return

	if event is InputEventKey and event.pressed:
		# Ctrl+S → save
		if event.ctrl_pressed and event.keycode == KEY_S:
			save_file()
			get_viewport().set_input_as_handled()
		# Shift+F7 → View Object (back to form)
		elif event.keycode == KEY_F7 and event.shift_pressed:
			view_object_requested.emit()
			get_viewport().set_input_as_handled()
		# F7 alone also goes back to object view (VB6 toggle behavior)
		elif event.keycode == KEY_F7 and not event.ctrl_pressed and not event.alt_pressed:
			view_object_requested.emit()
			get_viewport().set_input_as_handled()
