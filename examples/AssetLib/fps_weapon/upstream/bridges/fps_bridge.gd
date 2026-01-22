extends Node

@export var target_node_path: NodePath = "FPSRoot"

func spawn_projectile(velocity: float) -> void:
    var n = get_node_or_null(target_node_path)
    if not n:
        print("FPSBridge: target not found: " + str(target_node_path))
        return
    if n.has_method("spawn_projectile"):
        n.call("spawn_projectile", velocity)
        return
    # fallback: try to instance a pre-made projectile scene under 'projectile_scene'
    if n.has("projectile_scene"):
        var scn = n.get("projectile_scene")
        if scn:
            var inst = scn.instantiate()
            get_tree().root.add_child(inst)
            if inst.has_method("set_velocity"):
                inst.call("set_velocity", velocity)
            return
    print("FPSBridge: couldn't spawn projectile on target")

# Alias for VisualGasic naming conventions
func SpawnProjectile(velocity: float) -> void:
    spawn_projectile(velocity)