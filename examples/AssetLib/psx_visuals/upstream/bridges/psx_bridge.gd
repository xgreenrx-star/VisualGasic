extends Node

# PSX Visuals bridge helper
# Place this node in your scene (name it e.g. "PSXBridge") and set target_node_path
# to the plugin node (default: "PSXVisuals"). This provides safe methods for VisualGasic
# demos to call to set plugin parameters or toggle effects.

@export var target_node_path: NodePath = "PSXVisuals"

func _ready():
    pass

func set_param(name: String, value) -> void:
    var n = get_node_or_null(target_node_path)
    if not n:
        print("PSXBridge: target node not found: " + str(target_node_path))
        return
    if n.has_method("set"):
        n.set(name, value)
        return
    if n.has_method("set_param"):
        n.call("set_param", name, value)
        return
    print("PSXBridge: could not set param '" + name + "' on target node")

func toggle_effect(name: String) -> void:
    var n = get_node_or_null(target_node_path)
    if not n:
        print("PSXBridge: target node not found: " + str(target_node_path))
        return
    if n.has_method("toggle_effect"):
        n.call("toggle_effect", name)
        return
    # fallback: try boolean flip on a named property
    var cur = n.get(name)
    n.set(name, not cur)

func set_global(name: String, value) -> void:
    # attempt to set a global/auto uniform if plugin exposes such method
    var n = get_node_or_null(target_node_path)
    if not n:
        print("PSXBridge: target node not found: " + str(target_node_path))
        return
    if n.has_method("set_global"):
        n.call("set_global", name, value)
        return
    # fallback to set property
    if n.has_method("set"):
        n.set(name, value)
        return
    print("PSXBridge: could not set global '" + name + "'")