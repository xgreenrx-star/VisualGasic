extends RefCounted
class_name VGGodotCompat
## Godot version compatibility helpers for VisualGasic editor UI.


static func connect_popup_preshow(node: Node, callable: Callable) -> void:
	if node == null or not callable.is_valid():
		return
	if node is OptionButton:
		var popup: PopupMenu = (node as OptionButton).get_popup()
		if popup and popup.has_signal("about_to_popup") and not popup.about_to_popup.is_connected(callable):
			popup.about_to_popup.connect(callable)
		return
	if node.has_signal("about_to_popup") and not node.about_to_popup.is_connected(callable):
		node.about_to_popup.connect(callable)
