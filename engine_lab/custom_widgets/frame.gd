@tool
extends Panel

# Visual Gasic Frame (GroupBox)
# A container with a visible caption/title.

@onready var label = $Label

var Caption: String:
	set(v):
		if label: label.text = v
	get:
		if label: return label.text
		return ""

func _ready():
	# Ensure label matches if set in editor
	pass
