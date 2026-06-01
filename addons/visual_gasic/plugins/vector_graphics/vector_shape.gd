@tool
extends Resource
class_name VectorShape

@export var shape_type: String = ""
@export var points: Array = []
@export var rect: Rect2 = Rect2()
@export var stroke_color: Color = Color.WHITE
@export var fill_color: Color = Color(1, 1, 1, 0)
@export var stroke_width: float = 2.0
@export var text: String = ""
@export var font: Font = null
@export var is_closed: bool = false
