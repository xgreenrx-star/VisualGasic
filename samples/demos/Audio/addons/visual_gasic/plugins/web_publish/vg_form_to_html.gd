@tool
## VG Form → HTML Converter
##
## Converts VisualGasic Form Designer scenes (.tscn) into standalone
## HTML/CSS/JS web pages.  Maps VG/Godot controls to their natural
## HTML equivalents:
##
##   Label        → <span>          CommandButton → <button>
##   TextBox      → <input>         CheckBox      → <input type="checkbox">
##   ComboBox     → <select>        ListBox       → <select multiple>
##   RadioButton  → <input radio>   Frame         → <fieldset>
##   ProgressBar  → <progress>      PictureBox    → <div.picture-box>
##   HScrollBar   → <input range>   VScrollBar    → <input range vertical>
##   Timer        → setInterval()   RichTextBox   → <div contenteditable>
##   MenuBar      → <nav>           TabControl    → <div.tabs>
##
## This is the true Flash successor for applications — VB6 forms
## published directly to the web as responsive HTML5 pages.
extends RefCounted


# ─── Control → HTML Mapping ──────────────────────────────────

## Maps Godot / VG class names to HTML generation functions.
## Each entry: { "tag": ..., "type": ..., "self_closing": bool }
const CONTROL_MAP = {
	# VG custom controls
	"VGTextBox":      {"tag": "input",    "type": "text",     "self_closing": true},
	"VGComboBox":     {"tag": "select",   "type": "",         "self_closing": false},
	"VGListBox":      {"tag": "select",   "type": "",         "self_closing": false,  "attrs": "multiple"},
	"VGCheckBox":     {"tag": "input",    "type": "checkbox", "self_closing": true},
	"VGRadioButton":  {"tag": "input",    "type": "radio",    "self_closing": true},
	"VGLabel":        {"tag": "span",     "type": "",         "self_closing": false},
	"VGFrame":        {"tag": "fieldset", "type": "",         "self_closing": false},
	"VGPictureBox":   {"tag": "div",      "type": "",         "self_closing": false,  "class": "picture-box"},
	"VGProgressBar":  {"tag": "progress", "type": "",         "self_closing": false},
	"VGHScrollBar":   {"tag": "input",    "type": "range",    "self_closing": true},
	"VGVScrollBar":   {"tag": "input",    "type": "range",    "self_closing": true,   "attrs": "orient=\"vertical\""},
	"VGRichTextBox":  {"tag": "div",      "type": "",         "self_closing": false,  "attrs": "contenteditable=\"true\"", "class": "rich-text"},
	"VGTimer":        {"tag": "script",   "type": "",         "self_closing": false},

	# Standard Godot controls (fallbacks)
	"Label":          {"tag": "span",     "type": "",         "self_closing": false},
	"Button":         {"tag": "button",   "type": "",         "self_closing": false},
	"LineEdit":       {"tag": "input",    "type": "text",     "self_closing": true},
	"TextEdit":       {"tag": "textarea", "type": "",         "self_closing": false},
	"CheckBox":       {"tag": "input",    "type": "checkbox", "self_closing": true},
	"CheckButton":    {"tag": "input",    "type": "checkbox", "self_closing": true},
	"RadioButton":    {"tag": "input",    "type": "radio",    "self_closing": true},
	"OptionButton":   {"tag": "select",   "type": "",         "self_closing": false},
	"SpinBox":        {"tag": "input",    "type": "number",   "self_closing": true},
	"HSlider":        {"tag": "input",    "type": "range",    "self_closing": true},
	"VSlider":        {"tag": "input",    "type": "range",    "self_closing": true,   "attrs": "orient=\"vertical\""},
	"ProgressBar":    {"tag": "progress", "type": "",         "self_closing": false},
	"RichTextLabel":  {"tag": "div",      "type": "",         "self_closing": false,  "class": "rich-text"},
	"PanelContainer": {"tag": "div",      "type": "",         "self_closing": false,  "class": "panel"},
	"TabContainer":   {"tag": "div",      "type": "",         "self_closing": false,  "class": "tab-container"},
	"MenuBar":        {"tag": "nav",      "type": "",         "self_closing": false},
	"Panel":          {"tag": "div",      "type": "",         "self_closing": false,  "class": "panel"},
	"ColorRect":      {"tag": "div",      "type": "",         "self_closing": false},
	"TextureRect":    {"tag": "img",      "type": "",         "self_closing": true},
	"HSeparator":     {"tag": "hr",       "type": "",         "self_closing": true},
	"VSeparator":     {"tag": "div",      "type": "",         "self_closing": false,  "class": "vsep"},
}


# ─── CSS Theme Presets ───────────────────────────────────────

static func _get_theme_css(theme_name: String) -> String:
	match theme_name:
		"Classic VB6":
			return """
body { font-family: 'MS Sans Serif', 'Segoe UI', Tahoma, sans-serif; background: #c0c0c0; margin: 0; }
.vg-form { background: #c0c0c0; border: 2px outset #dfdfdf; position: relative; margin: 20px auto; }
button { font-family: inherit; padding: 2px 12px; border: 2px outset #dfdfdf; background: #c0c0c0; cursor: pointer; }
button:active { border-style: inset; }
input[type="text"], textarea, select { font-family: inherit; border: 2px inset #808080; background: #fff; padding: 2px 4px; }
fieldset { border: 2px groove #808080; padding: 8px; }
fieldset legend { font-size: 0.9em; }
.picture-box { border: 1px solid #808080; background: #fff; }
progress { accent-color: #000080; }
span { user-select: none; }
"""
		"Dark Mode":
			return """
body { font-family: 'Segoe UI', system-ui, sans-serif; background: #1a1a2e; color: #e0e0e0; margin: 0; }
.vg-form { background: #16213e; border: 1px solid #0f3460; border-radius: 8px; position: relative; margin: 20px auto; box-shadow: 0 4px 20px rgba(0,0,0,0.4); }
button { font-family: inherit; padding: 6px 16px; border: 1px solid #0f3460; background: #1a1a4e; color: #e0e0e0; border-radius: 4px; cursor: pointer; transition: background 0.2s; }
button:hover { background: #2a2a6e; }
input[type="text"], textarea, select { font-family: inherit; border: 1px solid #0f3460; background: #0d1b3e; color: #e0e0e0; padding: 4px 8px; border-radius: 4px; }
fieldset { border: 1px solid #0f3460; border-radius: 4px; padding: 8px; }
.picture-box { border: 1px solid #0f3460; background: #0d1b3e; border-radius: 4px; }
progress { accent-color: #e94560; }
input[type="checkbox"], input[type="radio"] { accent-color: #e94560; }
select option { background: #16213e; color: #e0e0e0; }
"""
		"Bootstrap-like":
			return """
body { font-family: system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif; background: #f8f9fa; margin: 0; }
.vg-form { background: #fff; border: 1px solid #dee2e6; border-radius: 8px; position: relative; margin: 20px auto; padding: 0; box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
button { font-family: inherit; padding: 6px 16px; border: 1px solid #0d6efd; background: #0d6efd; color: #fff; border-radius: 6px; cursor: pointer; transition: all 0.15s; }
button:hover { background: #0b5ed7; }
input[type="text"], textarea, select { font-family: inherit; border: 1px solid #ced4da; background: #fff; padding: 6px 12px; border-radius: 6px; transition: border-color 0.15s; }
input[type="text"]:focus, textarea:focus, select:focus { border-color: #86b7fe; outline: 0; box-shadow: 0 0 0 0.25rem rgba(13,110,253,0.25); }
fieldset { border: 1px solid #dee2e6; border-radius: 6px; padding: 12px; }
.picture-box { border: 1px solid #dee2e6; border-radius: 6px; background: #f8f9fa; }
progress { accent-color: #0d6efd; border-radius: 4px; }
input[type="checkbox"], input[type="radio"] { accent-color: #0d6efd; width: 16px; height: 16px; }
"""
		"Minimal":
			return """
body { font-family: system-ui, sans-serif; background: #fafafa; margin: 0; }
.vg-form { background: #fff; border: none; position: relative; margin: 20px auto; }
button { font-family: inherit; padding: 6px 16px; border: 1px solid #ccc; background: #fff; cursor: pointer; }
button:hover { background: #f0f0f0; }
input[type="text"], textarea, select { font-family: inherit; border: 1px solid #ccc; padding: 4px 8px; }
fieldset { border: 1px solid #ddd; padding: 8px; }
.picture-box { border: 1px solid #ddd; }
"""
		_:  # "Modern Flat" (default)
			return """
body { font-family: 'Segoe UI', system-ui, sans-serif; background: #f0f2f5; margin: 0; }
.vg-form { background: #fff; border: 1px solid #e0e0e0; border-radius: 12px; position: relative; margin: 20px auto; box-shadow: 0 2px 12px rgba(0,0,0,0.06); }
button { font-family: inherit; padding: 8px 20px; border: none; background: #4a90d9; color: #fff; border-radius: 6px; cursor: pointer; transition: background 0.2s, transform 0.1s; }
button:hover { background: #357abd; }
button:active { transform: scale(0.97); }
input[type="text"], textarea, select { font-family: inherit; border: 1px solid #d0d0d0; background: #fafafa; padding: 6px 10px; border-radius: 6px; transition: border 0.2s; }
input[type="text"]:focus, textarea:focus, select:focus { border-color: #4a90d9; outline: none; }
fieldset { border: 1px solid #e0e0e0; border-radius: 8px; padding: 12px; }
fieldset legend { color: #666; font-weight: 600; }
.picture-box { border: 1px solid #e0e0e0; border-radius: 6px; background: #f5f5f5; overflow: hidden; }
progress { accent-color: #4a90d9; border-radius: 4px; height: 8px; }
input[type="checkbox"], input[type="radio"] { accent-color: #4a90d9; }
"""


# ─── Main Export Entry Point ─────────────────────────────────

## Export a VG form (.tscn) to an HTML file.
## Returns { ok: bool, html_file: String, error: String }
static func export_form(form_path: String, output_dir: String,
		options: Dictionary = {}, log_fn: Callable = Callable()) -> Dictionary:

	_log_msg(log_fn, "  Loading form: " + form_path)

	# Load the scene
	var scene: PackedScene = load(form_path)
	if not scene:
		return {"ok": false, "error": "Cannot load scene: " + form_path}

	# Instantiate to walk the tree
	var root: Node = scene.instantiate()
	if not root:
		return {"ok": false, "error": "Cannot instantiate scene"}

	# Extract form properties
	var form_name: String = root.name
	var form_width: int = 640
	var form_height: int = 480
	if root is Control:
		form_width = int(root.size.x) if root.size.x > 0 else 640
		form_height = int(root.size.y) if root.size.y > 0 else 480

	_log_msg(log_fn, "  Form: " + form_name + " (" + str(form_width) + "×" + str(form_height) + ")")

	# Walk the tree and collect control info
	var controls: Array = []
	_walk_tree(root, controls, Vector2.ZERO)

	_log_msg(log_fn, "  Found " + str(controls.size()) + " controls")

	# Generate HTML
	var title: String = options.get("title", form_name)
	var theme: String = options.get("theme", "Modern Flat")
	var layout: String = options.get("layout", "Responsive (flex/grid)")
	var responsive: bool = options.get("responsive", true)
	var include_js: bool = options.get("include_js", true)

	var html: String = _generate_html(title, form_name, form_width, form_height,
		controls, theme, layout, responsive, include_js)

	# Ensure output directory exists
	if not DirAccess.dir_exists_absolute(output_dir):
		DirAccess.make_dir_recursive_absolute(output_dir)

	# Write HTML file
	var safe_name: String = form_name.to_lower().replace(" ", "_")
	var html_filename: String = safe_name + ".html"
	var html_path: String = output_dir + html_filename

	var file = FileAccess.open(html_path, FileAccess.WRITE)
	if not file:
		root.queue_free()
		return {"ok": false, "error": "Cannot write to " + html_path}
	file.store_string(html)
	file.close()

	_log_msg(log_fn, "  ✓ Wrote " + html_path + " (" + str(html.length()) + " bytes)")

	# Clean up the instantiated scene
	root.queue_free()

	return {
		"ok": true,
		"html_file": html_path,
		"form_name": form_name,
		"control_count": controls.size(),
	}


# ─── Tree Walker ─────────────────────────────────────────────

## Recursively walk the node tree and collect control information.
static func _walk_tree(node: Node, controls: Array, parent_offset: Vector2) -> void:
	for child in node.get_children():
		if not child is Control:
			continue
		var ctrl: Control = child
		var info := {
			"name": ctrl.name,
			"class": ctrl.get_class(),
			"x": int(ctrl.position.x + parent_offset.x),
			"y": int(ctrl.position.y + parent_offset.y),
			"w": int(ctrl.size.x),
			"h": int(ctrl.size.y),
			"text": "",
			"visible": ctrl.visible,
			"children": [],
		}

		# Extract text from common control types
		if ctrl.has_method("get_text"):
			info["text"] = str(ctrl.get_text())
		elif ctrl is Label:
			info["text"] = ctrl.text
		elif ctrl is Button:
			info["text"] = ctrl.text
		elif ctrl is LineEdit:
			info["text"] = ctrl.text
			if ctrl.placeholder_text != "":
				info["placeholder"] = ctrl.placeholder_text
		elif ctrl is TextEdit:
			info["text"] = ctrl.text

		# Extract value from range-based controls
		if ctrl is Range:
			info["min_value"] = ctrl.min_value
			info["max_value"] = ctrl.max_value
			info["value"] = ctrl.value

		# Check box/button state
		if ctrl is BaseButton:
			info["pressed"] = ctrl.button_pressed

		# Detect VG custom class via metadata or script
		if ctrl.has_meta("vg_class"):
			info["class"] = ctrl.get_meta("vg_class")
		elif ctrl.get_script():
			var script_path: String = ctrl.get_script().resource_path
			# Try to detect VG class from script name
			var fname: String = script_path.get_file().get_basename()
			if fname.begins_with("vg_") or fname.begins_with("VG"):
				info["class"] = fname.to_pascal_case()

		# Colors
		if ctrl is ColorRect:
			info["color"] = "#" + ctrl.color.to_html(false)

		# Font size (if overridden)
		if ctrl.has_theme_font_size_override("font_size"):
			info["font_size"] = ctrl.get_theme_font_size("font_size")

		# OptionButton items
		if ctrl is OptionButton:
			var items: Array = []
			for i in range(ctrl.item_count):
				items.append(ctrl.get_item_text(i))
			info["items"] = items
			info["selected"] = ctrl.selected

		controls.append(info)

		# Recurse into container children (for containers like Panel, Frame, etc.)
		if ctrl.get_child_count() > 0:
			var child_controls: Array = []
			_walk_tree(ctrl, child_controls, Vector2(info["x"], info["y"]))
			info["children"] = child_controls


# ─── HTML Generation ─────────────────────────────────────────

static func _generate_html(title: String, form_name: String,
		form_w: int, form_h: int, controls: Array,
		theme: String, layout: String, responsive: bool,
		include_js: bool) -> String:

	var is_absolute: bool = layout.begins_with("Absolute")
	var is_centered: bool = layout.begins_with("Centered")

	var html := "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n"
	html += "  <meta charset=\"UTF-8\">\n"
	html += "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n"
	html += "  <title>" + _esc(title) + "</title>\n"
	html += "  <style>\n"

	# Theme CSS
	html += _get_theme_css(theme)

	# Layout-specific CSS
	if is_absolute:
		html += ".vg-form { width: " + str(form_w) + "px; height: " + str(form_h) + "px; overflow: hidden; }\n"
		html += ".vg-control { position: absolute; box-sizing: border-box; }\n"
		if responsive:
			html += "@media (max-width: " + str(form_w + 40) + "px) {\n"
			html += "  .vg-form { width: 100%; height: auto; min-height: " + str(form_h) + "px; transform-origin: top left; }\n"
			html += "}\n"
	elif is_centered:
		html += ".vg-form { max-width: " + str(form_w) + "px; padding: 24px; }\n"
		html += ".vg-control { margin-bottom: 12px; display: block; }\n"
		html += "label.vg-label { display: block; margin-bottom: 4px; }\n"
	else:
		# Responsive flex/grid
		html += ".vg-form { max-width: " + str(form_w) + "px; padding: 20px; }\n"
		html += ".vg-form-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 12px; }\n"
		html += ".vg-control { display: flex; flex-direction: column; }\n"
		html += ".vg-control label { margin-bottom: 4px; font-size: 0.9em; color: #666; }\n"
		html += ".vg-control input, .vg-control select, .vg-control textarea { width: 100%; box-sizing: border-box; }\n"
		html += ".vg-control button { align-self: flex-start; }\n"
		html += ".vg-full-width { grid-column: 1 / -1; }\n"

	html += "  </style>\n</head>\n<body>\n\n"

	# Form container
	html += "<div class=\"vg-form\" id=\"" + _esc(form_name) + "\">\n"

	if not is_absolute:
		html += "  <div class=\"vg-form-grid\">\n"

	# Generate controls
	for ctrl in controls:
		html += _generate_control_html(ctrl, is_absolute, "  ")

	if not is_absolute:
		html += "  </div>\n"

	html += "</div>\n\n"

	# JavaScript event stubs
	if include_js:
		html += _generate_js_stubs(controls, form_name)

	html += "</body>\n</html>\n"
	return html


# ─── Individual Control → HTML ───────────────────────────────

static func _generate_control_html(ctrl: Dictionary, absolute: bool, indent: String) -> String:
	var cls: String = ctrl.get("class", "Control")
	var name: String = ctrl.get("name", "ctrl")
	var text: String = ctrl.get("text", "")
	var w: int = ctrl.get("w", 100)
	var h: int = ctrl.get("h", 30)
	var x: int = ctrl.get("x", 0)
	var y: int = ctrl.get("y", 0)

	# Find mapping
	var mapping: Dictionary = CONTROL_MAP.get(cls, {"tag": "div", "type": "", "self_closing": false})
	var tag: String = mapping.get("tag", "div")
	var input_type: String = mapping.get("type", "")
	var self_closing: bool = mapping.get("self_closing", false)
	var extra_attrs: String = mapping.get("attrs", "")
	var extra_class: String = mapping.get("class", "")

	# Skip invisible
	if not ctrl.get("visible", true):
		return ""

	# Build style
	var style := ""
	if absolute:
		style = "left:" + str(x) + "px;top:" + str(y) + "px;width:" + str(w) + "px;height:" + str(h) + "px;"

	# Build element ID
	var el_id: String = name.to_snake_case()

	# Build CSS classes
	var css_classes := "vg-control"
	if extra_class != "":
		css_classes += " " + extra_class
	# Full-width elements in grid mode
	if not absolute and w > 300:
		css_classes += " vg-full-width"

	var html := indent

	# Special handling for different control types
	match tag:
		"input":
			if input_type == "checkbox" or input_type == "radio":
				# Wrap in label
				var checked: String = " checked" if ctrl.get("pressed", false) else ""
				html += "<label class=\"" + css_classes + "\""
				if style != "":
					html += " style=\"" + style + "\""
				html += ">"
				html += "<input type=\"" + input_type + "\" id=\"" + el_id + "\" name=\"" + el_id + "\"" + checked
				if extra_attrs != "":
					html += " " + extra_attrs
				html += "> " + _esc(text) + "</label>\n"
			else:
				# Text input / number / range
				if not absolute:
					html += "<div class=\"" + css_classes + "\">"
					# Find associated label (if previous sibling was a Label)
					html += "<label for=\"" + el_id + "\">" + _esc(name) + "</label>"
				html += "<input type=\"" + input_type + "\" id=\"" + el_id + "\" name=\"" + el_id + "\""
				if text != "":
					html += " value=\"" + _esc(text) + "\""
				if ctrl.has("placeholder"):
					html += " placeholder=\"" + _esc(ctrl["placeholder"]) + "\""
				if style != "" and absolute:
					html += " class=\"vg-control\" style=\"" + style + "\""
				if extra_attrs != "":
					html += " " + extra_attrs
				# Range-specific attributes
				if input_type == "range" or input_type == "number":
					if ctrl.has("min_value"):
						html += " min=\"" + str(ctrl["min_value"]) + "\""
					if ctrl.has("max_value"):
						html += " max=\"" + str(ctrl["max_value"]) + "\""
					if ctrl.has("value"):
						html += " value=\"" + str(ctrl["value"]) + "\""
				html += ">"
				if not absolute:
					html += "</div>"
				html += "\n"

		"select":
			if not absolute:
				html += "<div class=\"" + css_classes + "\">"
				html += "<label for=\"" + el_id + "\">" + _esc(name) + "</label>"
			html += "<select id=\"" + el_id + "\" name=\"" + el_id + "\""
			if style != "" and absolute:
				html += " class=\"vg-control\" style=\"" + style + "\""
			if extra_attrs != "":
				html += " " + extra_attrs
			html += ">\n"
			# Add options from items
			var items: Array = ctrl.get("items", [])
			var sel_idx: int = ctrl.get("selected", 0)
			if items.size() == 0:
				html += indent + "  <option>Item 1</option>\n"
			else:
				for i in range(items.size()):
					var selected_attr: String = " selected" if i == sel_idx else ""
					html += indent + "  <option" + selected_attr + ">" + _esc(str(items[i])) + "</option>\n"
			html += indent + "</select>"
			if not absolute:
				html += "</div>"
			html += "\n"

		"button":
			html += "<button id=\"" + el_id + "\""
			if absolute:
				html += " class=\"vg-control\" style=\"" + style + "\""
			else:
				html += " class=\"" + css_classes + "\""
			html += " onclick=\"" + el_id + "_Click()\">" + _esc(text if text != "" else name) + "</button>\n"

		"span":
			# Label
			html += "<span id=\"" + el_id + "\""
			if absolute:
				html += " class=\"vg-control\" style=\"" + style + "\""
			else:
				html += " class=\"" + css_classes + "\""
			if ctrl.has("font_size"):
				html += " style=\"font-size:" + str(ctrl["font_size"]) + "px\""
			html += ">" + _esc(text) + "</span>\n"

		"textarea":
			if not absolute:
				html += "<div class=\"" + css_classes + "\">"
				html += "<label for=\"" + el_id + "\">" + _esc(name) + "</label>"
			html += "<textarea id=\"" + el_id + "\""
			if absolute:
				html += " class=\"vg-control\" style=\"" + style + "\""
			html += " rows=\"" + str(maxi(h / 20, 3)) + "\">" + _esc(text) + "</textarea>"
			if not absolute:
				html += "</div>"
			html += "\n"

		"fieldset":
			html += "<fieldset id=\"" + el_id + "\""
			if absolute:
				html += " class=\"vg-control\" style=\"" + style + "\""
			else:
				html += " class=\"" + css_classes + " vg-full-width\""
			html += ">\n"
			html += indent + "  <legend>" + _esc(text if text != "" else name) + "</legend>\n"
			# Recurse children
			for child in ctrl.get("children", []):
				html += _generate_control_html(child, absolute, indent + "  ")
			html += indent + "</fieldset>\n"

		"progress":
			html += "<progress id=\"" + el_id + "\""
			if absolute:
				html += " class=\"vg-control\" style=\"" + style + "\""
			else:
				html += " class=\"" + css_classes + "\""
			if ctrl.has("max_value"):
				html += " max=\"" + str(ctrl["max_value"]) + "\""
			if ctrl.has("value"):
				html += " value=\"" + str(ctrl["value"]) + "\""
			html += "></progress>\n"

		"hr":
			html += "<hr"
			if absolute:
				html += " class=\"vg-control\" style=\"" + style + "\""
			html += ">\n"

		"nav":
			html += "<nav id=\"" + el_id + "\""
			if absolute:
				html += " class=\"vg-control\" style=\"" + style + "\""
			html += "><ul style=\"list-style:none;margin:0;padding:0;display:flex;\">\n"
			html += indent + "  <li><a href=\"#\">File</a></li>\n"
			html += indent + "  <li><a href=\"#\">Edit</a></li>\n"
			html += indent + "  <li><a href=\"#\">Help</a></li>\n"
			html += indent + "</ul></nav>\n"

		"img":
			html += "<img id=\"" + el_id + "\""
			if absolute:
				html += " class=\"vg-control\" style=\"" + style + "\""
			html += " src=\"\" alt=\"" + _esc(name) + "\">\n"

		"script":
			# Timer → setInterval
			var interval: float = ctrl.get("value", 1.0)
			html += "<script>/* Timer: " + name + " */\n"
			html += indent + "let " + el_id + "_enabled = true;\n"
			html += indent + "setInterval(function() { if (" + el_id + "_enabled) " + el_id + "_Timer(); }, " + str(int(interval * 1000)) + ");\n"
			html += indent + "</script>\n"

		_:
			# Generic div
			html += "<div id=\"" + el_id + "\""
			if absolute:
				html += " class=\"vg-control " + extra_class + "\" style=\"" + style + "\""
			else:
				html += " class=\"" + css_classes + "\""
			if ctrl.has("color"):
				html += " style=\"background:" + ctrl["color"] + ";\""
			if extra_attrs != "":
				html += " " + extra_attrs
			html += ">"
			if text != "":
				html += _esc(text)
			for child in ctrl.get("children", []):
				html += "\n" + _generate_control_html(child, absolute, indent + "  ")
			html += "</div>\n"

	return html


# ─── JavaScript Event Stubs ─────────────────────────────────

static func _generate_js_stubs(controls: Array, form_name: String) -> String:
	var js := "<script>\n"
	js += "// ═══════════════════════════════════════════════════════\n"
	js += "// Event handlers for " + form_name + "\n"
	js += "// Generated by VisualGasic Web Publish — edit freely!\n"
	js += "// ═══════════════════════════════════════════════════════\n\n"

	# Form_Load equivalent
	js += "// Runs when the page loads (like Form_Load in VB6)\n"
	js += "window.addEventListener('DOMContentLoaded', function() {\n"
	js += "  console.log('" + _esc(form_name) + " loaded');\n"
	js += "  " + form_name.to_snake_case() + "_Load();\n"
	js += "});\n\n"
	js += "function " + form_name.to_snake_case() + "_Load() {\n"
	js += "  // TODO: Initialize your form here\n"
	js += "}\n\n"

	# Per-control event stubs
	for ctrl in controls:
		var name: String = ctrl.get("name", "ctrl").to_snake_case()
		var cls: String = ctrl.get("class", "")
		var mapping: Dictionary = CONTROL_MAP.get(cls, {})
		var tag: String = mapping.get("tag", "div")
		var input_type: String = mapping.get("type", "")

		match tag:
			"button":
				js += "function " + name + "_Click() {\n"
				js += "  // TODO: Handle " + ctrl.get("name", "button") + " click\n"
				js += "}\n\n"
			"input":
				if input_type == "text":
					js += "// " + ctrl.get("name", "textbox") + " change handler\n"
					js += "document.getElementById('" + name + "')?.addEventListener('input', function(e) {\n"
					js += "  " + name + "_Change(e.target.value);\n"
					js += "});\n"
					js += "function " + name + "_Change(text) {\n"
					js += "  // TODO: Handle text change\n"
					js += "}\n\n"
				elif input_type == "checkbox" or input_type == "radio":
					js += "document.getElementById('" + name + "')?.addEventListener('change', function(e) {\n"
					js += "  " + name + "_Click(e.target.checked);\n"
					js += "});\n"
					js += "function " + name + "_Click(checked) {\n"
					js += "  // TODO: Handle check change\n"
					js += "}\n\n"
				elif input_type == "range" or input_type == "number":
					js += "document.getElementById('" + name + "')?.addEventListener('input', function(e) {\n"
					js += "  " + name + "_Change(Number(e.target.value));\n"
					js += "});\n"
					js += "function " + name + "_Change(value) {\n"
					js += "  // TODO: Handle value change\n"
					js += "}\n\n"
			"select":
				js += "document.getElementById('" + name + "')?.addEventListener('change', function(e) {\n"
				js += "  " + name + "_Click(e.target.selectedIndex, e.target.value);\n"
				js += "});\n"
				js += "function " + name + "_Click(index, value) {\n"
				js += "  // TODO: Handle selection change\n"
				js += "}\n\n"
			"textarea":
				js += "document.getElementById('" + name + "')?.addEventListener('input', function(e) {\n"
				js += "  " + name + "_Change(e.target.value);\n"
				js += "});\n"
				js += "function " + name + "_Change(text) {\n"
				js += "  // TODO: Handle text change\n"
				js += "}\n\n"
			"script":
				js += "function " + name + "_Timer() {\n"
				js += "  // TODO: Handle timer tick\n"
				js += "}\n\n"

		# Recurse into children
		for child in ctrl.get("children", []):
			js += _generate_js_stubs([child], form_name)

	js += "</script>\n"
	return js


# ─── Utilities ───────────────────────────────────────────────

static func _esc(text: String) -> String:
	return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")

static func _log_msg(log_fn: Callable, msg: String) -> void:
	if log_fn.is_valid():
		log_fn.call(msg)
	else:
		print("[FormToHTML] ", msg)
