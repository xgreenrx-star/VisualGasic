extends ColorRect
## Title / end card over the IDE screenshot background.

@onready var _headline: Label = $Center/VBox/Headline
@onready var _subline: Label = $Center/VBox/Subline
@onready var _body: RichTextLabel = $Center/VBox/Body


func _ready() -> void:
	visible = false
	_body.visible = false


func show_title(headline: String, subline: String, body: String = "") -> void:
	_headline.text = headline
	_subline.text = subline
	if body.is_empty():
		_body.text = ""
		_body.visible = false
	else:
		_body.text = body
		_body.visible = true
	visible = true


func hide_card() -> void:
	visible = false
