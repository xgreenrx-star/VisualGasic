extends Node

@export var target_node_path: NodePath = "LaserRoot"

func set_param(name: String, value) -> void:
    var n = get_node_or_null(target_node_path)
    if not n:
        print("LaserBridge: target not found: " + str(target_node_path))
        return
    if n.has_method("set"):
        n.set(name, value)
        return
    print("LaserBridge: could not set param '" + name + "'")

func fire() -> void:
    var n = get_node_or_null(target_node_path)
    if not n:
        print("LaserBridge: target not found: " + str(target_node_path))
        return
    if n.has_method("fire"):
        n.call("fire")
        return
    print("LaserBridge: no fire method on target")

# Alias for VisualGasic naming
func Fire() -> void:
    fire()