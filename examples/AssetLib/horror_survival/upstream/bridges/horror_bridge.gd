extends Node

@export var target_node_path: NodePath = "HorrorRoot"

func set_param(name: String, value) -> void:
    var n = get_node_or_null(target_node_path)
    if not n:
        print("HorrorBridge: target not found: " + str(target_node_path))
        return
    if n.has_method("set"):
        n.set(name, value)
        return
    print("HorrorBridge: could not set param '" + name + "'")

func regenerate() -> void:
    var n = get_node_or_null(target_node_path)
    if not n:
        print("HorrorBridge: target not found: " + str(target_node_path))
        return
    if n.has_method("regenerate"):
        n.call("regenerate")
        return
    print("HorrorBridge: no regenerate method found on target")