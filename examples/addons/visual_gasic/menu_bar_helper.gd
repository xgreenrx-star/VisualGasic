@tool
extends MenuBar
## Menu Bar Helper - Disables mouse input in editor to prevent drop interception
##
## In the editor, mouse_filter is set to IGNORE on the MenuBar AND all its
## internal children (HBoxContainer, etc.) to prevent them from intercepting
## drag-drop operations. This script restores normal behavior at runtime.
##
## The problem: MenuBar creates internal Controls that intercept editor drops,
## causing "Invalid owner" errors. We must disable ALL of them in the editor.

func _ready() -> void:
	if Engine.is_editor_hint():
		# In editor: disable mouse input on this MenuBar and ALL children
		# This prevents internal HBoxContainer etc. from intercepting drops
		_set_mouse_filter_recursive(self, Control.MOUSE_FILTER_IGNORE)
	else:
		# At runtime: restore normal mouse handling so menus work
		_set_mouse_filter_recursive(self, Control.MOUSE_FILTER_STOP)

func _enter_tree() -> void:
	# Also do this on enter_tree in case _ready already ran
	if Engine.is_editor_hint():
		# Use call_deferred to ensure all internal children are created
		call_deferred("_disable_mouse_for_editor")

func _disable_mouse_for_editor() -> void:
	if Engine.is_editor_hint():
		_set_mouse_filter_recursive(self, Control.MOUSE_FILTER_IGNORE)

## Recursively set mouse_filter on a node and all its Control children
func _set_mouse_filter_recursive(node: Node, filter: Control.MouseFilter) -> void:
	if node is Control:
		node.mouse_filter = filter
	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)
