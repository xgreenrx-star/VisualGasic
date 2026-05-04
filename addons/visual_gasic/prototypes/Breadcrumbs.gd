@tool
extends HBoxContainer
## Breadcrumbs — chain of LinkButtons separated by " ▸ ".
## Set `path` (Array[String]) to update; emits `crumb_clicked(index)`.

signal crumb_clicked(index: int)

@export var path: PackedStringArray = PackedStringArray(["Home", "Folder", "File"]) : set = _set_path
@export var separator: String = "▸"

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	_rebuild()

func _set_path(v: PackedStringArray) -> void:
	path = v
	if is_inside_tree():
		_rebuild()

func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	for i in range(path.size()):
		var lb := LinkButton.new()
		lb.text = path[i]
		lb.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
		var idx := i
		lb.pressed.connect(func(): crumb_clicked.emit(idx))
		add_child(lb)
		if i < path.size() - 1:
			var sep := Label.new()
			sep.text = " " + separator + " "
			sep.modulate = Color(1, 1, 1, 0.6)
			add_child(sep)
