extends Node

@export var target_node_path: NodePath = "ProceduralRoot"

func set_param(name: String, value) -> void:
    var n = get_node_or_null(target_node_path)
    if not n:
        print("ProceduralBridge: target not found: " + str(target_node_path))
        return
    if n.has_method("set"):
        n.set(name, value)
        return
    if n.has_method("set_param"):
        n.call("set_param", name, value)
        return
    print("ProceduralBridge: could not set param '" + name + "'")

func regenerate() -> void:
    var n = get_node_or_null(target_node_path)
    if not n:
        print("ProceduralBridge: target not found: " + str(target_node_path))
        return
    if n.has_method("regenerate"):
        n.call("regenerate")
        return
    print("ProceduralBridge: no regenerate method found on target")