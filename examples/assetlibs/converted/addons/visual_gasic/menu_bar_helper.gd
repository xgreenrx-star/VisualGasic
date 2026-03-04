@tool
extends MenuBar
## MenuBar Helper - Manages mouse_filter for editor vs runtime behavior.
##
## In the editor, mouse_filter is set to IGNORE so the MenuBar doesn't intercept
## toolbox drag-drop operations. At runtime, STOP is restored so menus work normally.

func _ready() -> void:
	if not Engine.is_editor_hint():
		# Runtime: restore normal mouse interaction so menus are clickable
		mouse_filter = Control.MOUSE_FILTER_STOP
