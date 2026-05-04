@tool
extends VBoxContainer
## Expander — collapsible header + content panel.
## Click the header to toggle. Content can be any Control children added
## under the `Content` VBox.

@export var title: String = "Expander" : set = _set_title
@export var expanded: bool = true : set = _set_expanded

@onready var _header: Button = $Header
@onready var _content: VBoxContainer = $Content

func _ready() -> void:
	if _header:
		_header.text = _arrow() + "  " + title
		_header.pressed.connect(_toggle)
	if _content:
		_content.visible = expanded

func _toggle() -> void:
	expanded = not expanded

func _set_title(v: String) -> void:
	title = v
	if is_inside_tree() and _header:
		_header.text = _arrow() + "  " + v

func _set_expanded(v: bool) -> void:
	expanded = v
	if is_inside_tree():
		if _header:
			_header.text = _arrow() + "  " + title
		if _content:
			_content.visible = v

func _arrow() -> String:
	return "▼" if expanded else "▶"
