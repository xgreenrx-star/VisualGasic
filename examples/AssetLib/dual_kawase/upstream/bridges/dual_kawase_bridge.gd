extends Node

# Dual Kawase bridge helper
# Place this node in your scene (name it e.g. "DualKawaseBridge") and set target_node_path
# to the plugin node (default: "DualKawase"). This provides safe methods that VisualGasic
# demos can call without needing low-level resource construction access.

@export var target_node_path: NodePath = "DualKawase"

func _ready():
    pass

func set_param(name: String, value) -> void:
    var n = get_node_or_null(target_node_path)
    if not n:
        print("DualKawaseBridge: target node not found: " + str(target_node_path))
        return
    if n.has_method("set"):
        n.set(name, value)
        return
    if n.has_method("set_param"):
        n.call("set_param", name, value)
        return
    print("DualKawaseBridge: could not set param '" + name + "' on target node")

func toggle_enabled() -> void:
    var n = get_node_or_null(target_node_path)
    if not n:
        print("DualKawaseBridge: target node not found: " + str(target_node_path))
        return
    if n.has_method("get") and n.has_method("set"):
        var cur = null
        # attempt to read property safely
        cur = n.get("enabled")
        n.set("enabled", not cur)
        return
    if n.has_method("toggle_enabled"):
        n.call("toggle_enabled")
        return
    print("DualKawaseBridge: cannot toggle enabled on target node")

func apply_to_viewport(viewport: Node) -> void:
    var n = get_node_or_null(target_node_path)
    if not n:
        print("DualKawaseBridge: target node not found: " + str(target_node_path))
        return
    if n.has_method("apply_to_viewport"):
        n.call("apply_to_viewport", viewport)
        return
    print("DualKawaseBridge: target node has no apply_to_viewport method")