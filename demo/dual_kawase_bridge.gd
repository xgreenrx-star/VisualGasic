extends Node

@export var target_node_path: NodePath = "DualKawase"

func _ready():
	pass

func set_param(name: String, value) -> void:
	var n = get_node_or_null(target_node_path)
	if n and n.has_method("set"):
		n.set(name, value)
		return
	if n and n.has_method("set_param"):
		n.call("set_param", name, value)
		return
	print("DualKawaseBridge: could not set param")

func apply_to_viewport(viewport: Node) -> void:
	var n = get_node_or_null(target_node_path)
	if not n:
		print("DualKawaseBridge: target node not found: " + str(target_node_path))
		return
	if n.has_method("apply_to_viewport"):
		n.call("apply_to_viewport", viewport)
		print("DualKawaseBridge: applied to viewport")
		return
	print("DualKawaseBridge: target has no apply_to_viewport")