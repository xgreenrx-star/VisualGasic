@tool
extends Window
## Find All References Panel
##
## Shows all usages of a variable, Sub, or Function:
## - Ctrl+Shift+F on identifier to trigger
## - Results panel with file:line listings
## - Click to navigate
## - Filter by type (read/write/call)
## - Search across all .vg files

signal reference_selected(file_path: String, line: int, column: int)

var _results_tree: Tree
var _search_term: String = ""
var _filter_option: OptionButton
var _status_label: Label
var _results: Array[Dictionary] = []

# Reference types
enum RefType {
	ALL = 0,
	DECLARATION = 1,
	READ = 2,
	WRITE = 3,
	CALL = 4
}

func _init() -> void:
	title = "Find All References"
	size = Vector2i(600, 400)
	min_size = Vector2i(400, 300)

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.offset_left = 8
	main_vbox.offset_right = -8
	main_vbox.offset_top = 8
	main_vbox.offset_bottom = -8
	add_child(main_vbox)
	
	# Header with search term and filter
	var header = HBoxContainer.new()
	main_vbox.add_child(header)
	
	var search_label = Label.new()
	search_label.text = "References to:"
	header.add_child(search_label)
	
	var term_label = Label.new()
	term_label.name = "TermLabel"
	term_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	header.add_child(term_label)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	var filter_label = Label.new()
	filter_label.text = "Filter:"
	header.add_child(filter_label)
	
	_filter_option = OptionButton.new()
	_filter_option.add_item("All References", RefType.ALL)
	_filter_option.add_item("Declarations", RefType.DECLARATION)
	_filter_option.add_item("Read Access", RefType.READ)
	_filter_option.add_item("Write Access", RefType.WRITE)
	_filter_option.add_item("Calls", RefType.CALL)
	_filter_option.item_selected.connect(_on_filter_changed)
	header.add_child(_filter_option)
	
	# Results tree
	_results_tree = Tree.new()
	_results_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_results_tree.hide_root = true
	_results_tree.columns = 3
	_results_tree.set_column_title(0, "Location")
	_results_tree.set_column_title(1, "Line")
	_results_tree.set_column_title(2, "Context")
	_results_tree.set_column_titles_visible(true)
	_results_tree.set_column_expand(0, false)
	_results_tree.set_column_custom_minimum_width(0, 200)
	_results_tree.set_column_expand(1, false)
	_results_tree.set_column_custom_minimum_width(1, 50)
	_results_tree.set_column_expand(2, true)
	_results_tree.item_activated.connect(_on_item_activated)
	main_vbox.add_child(_results_tree)
	
	# Status bar
	_status_label = Label.new()
	_status_label.text = "Ready"
	main_vbox.add_child(_status_label)
	
	close_requested.connect(hide)

## Finds all references to a symbol in the workspace
func find_references(symbol: String, workspace_path: String = "res://") -> void:
	_search_term = symbol
	title = "Find All References — '%s'" % symbol
	
	# Update header
	var term_label = get_node_or_null("VBoxContainer/HBoxContainer/TermLabel")
	if term_label:
		term_label.text = symbol
	
	_results.clear()
	_status_label.text = "Searching..."
	
	# Find all .vg files
	var vg_files = _find_vg_files(workspace_path)
	
	for file_path in vg_files:
		_search_file(file_path, symbol)
	
	_status_label.text = "%d references found in %d files" % [_results.size(), vg_files.size()]
	_display_results()
	popup_centered()

## Opens the panel pre-filtered to Calls — shows every line that calls 'symbol'.
## This is the Call Hierarchy entry point (Ctrl+Shift+H / context menu).
func find_callers(symbol: String, workspace_path: String = "res://") -> void:
	find_references(symbol, workspace_path)
	title = "Call Hierarchy — '%s'" % symbol
	_filter_option.select(RefType.CALL)  # index == value for this enum
	_display_results()

## Recursively finds all .vg files
func _find_vg_files(path: String) -> Array[String]:
	var files: Array[String] = []
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			var full_path = path.path_join(file_name)
			
			if dir.current_is_dir():
				if not file_name.begins_with(".") and file_name != "addons":
					files.append_array(_find_vg_files(full_path))
			elif file_name.ends_with(".vg"):
				files.append(full_path)
			
			file_name = dir.get_next()
		
		dir.list_dir_end()
	
	return files

## Searches a single file for references
func _search_file(file_path: String, symbol: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return
	
	var content = file.get_as_text()
	file.close()
	
	var lines = content.split("\n")
	var regex = RegEx.new()
	regex.compile("(?<![A-Za-z0-9_])" + symbol + "(?![A-Za-z0-9_])")
	
	for line_num in range(lines.size()):
		var line = lines[line_num]
		var matches = regex.search_all(line)
		
		for match in matches:
			var col = match.get_start()
			
			# Skip if inside string or comment
			if _is_inside_string_or_comment(line, col):
				continue
			
			var ref_type = _determine_ref_type(line, col, symbol)
			
			_results.append({
				"file": file_path,
				"line": line_num + 1,  # 1-based
				"column": col,
				"context": line.strip_edges(),
				"type": ref_type
			})

## Determines the reference type (declaration, read, write, call)
func _determine_ref_type(line: String, col: int, symbol: String) -> RefType:
	var line_upper = line.to_upper()
	var before = line.substr(0, col).strip_edges()
	var after = line.substr(col + symbol.length()).strip_edges()
	
	# Declaration patterns
	if "DIM " in line_upper or "PRIVATE " in line_upper or "PUBLIC " in line_upper:
		if before.ends_with("Dim") or before.ends_with("Private") or before.ends_with("Public") or before.ends_with("Static"):
			return RefType.DECLARATION
	
	if line_upper.begins_with("SUB " + symbol.to_upper()) or line_upper.begins_with("FUNCTION " + symbol.to_upper()):
		return RefType.DECLARATION
	
	# Call pattern (followed by parenthesis or nothing on a line)
	if after.begins_with("(") or (after.is_empty() and not "=" in before):
		return RefType.CALL
	
	# Write pattern (before = or Set)
	if after.begins_with("=") and not after.begins_with("=="):
		return RefType.WRITE
	if before.ends_with("Set"):
		return RefType.WRITE
	
	# Default to read
	return RefType.READ

## Checks if position is inside string or comment
func _is_inside_string_or_comment(line: String, pos: int) -> bool:
	# Check for comment
	var comment_pos = line.find("'")
	if comment_pos >= 0 and comment_pos < pos:
		# Check if comment is inside a string
		var in_str = false
		for i in range(comment_pos):
			if line[i] == '"':
				in_str = not in_str
		if not in_str:
			return true
	
	# Check if inside string
	var in_string = false
	for i in range(mini(pos, line.length())):
		if line[i] == '"':
			in_string = not in_string
	
	return in_string

## Displays results in the tree
func _display_results() -> void:
	_results_tree.clear()
	var root = _results_tree.create_item()
	
	var current_filter = _filter_option.get_selected_id()
	var filtered_results = _results.filter(func(r): 
		return current_filter == RefType.ALL or r["type"] == current_filter
	)
	
	# Group by file
	var by_file: Dictionary = {}
	for result in filtered_results:
		var file = result["file"]
		if not by_file.has(file):
			by_file[file] = []
		by_file[file].append(result)
	
	# Create tree items
	for file_path in by_file:
		var file_item = _results_tree.create_item(root)
		file_item.set_text(0, file_path.get_file())
		file_item.set_tooltip_text(0, file_path)
		file_item.set_text(1, str(by_file[file_path].size()))
		file_item.set_selectable(0, false)
		file_item.set_selectable(1, false)
		file_item.set_selectable(2, false)
		
		for result in by_file[file_path]:
			var item = _results_tree.create_item(file_item)
			item.set_text(0, "  Line %d" % result["line"])
			item.set_text(1, _get_type_icon(result["type"]))
			item.set_text(2, result["context"])
			item.set_tooltip_text(2, result["context"])
			item.set_meta("file", result["file"])
			item.set_meta("line", result["line"])
			item.set_meta("column", result["column"])
	
	_status_label.text = "%d references shown" % filtered_results.size()

## Gets an icon/label for the reference type
func _get_type_icon(type: RefType) -> String:
	match type:
		RefType.DECLARATION: return "📋"
		RefType.READ: return "📖"
		RefType.WRITE: return "✏️"
		RefType.CALL: return "📞"
		_: return ""

## Called when filter changes
func _on_filter_changed(_index: int) -> void:
	_display_results()

## Called when an item is double-clicked
func _on_item_activated() -> void:
	var selected = _results_tree.get_selected()
	if not selected:
		return
	
	if not selected.has_meta("file"):
		return
	
	var file_path = selected.get_meta("file")
	var line = selected.get_meta("line")
	var column = selected.get_meta("column")
	
	reference_selected.emit(file_path, line, column)
