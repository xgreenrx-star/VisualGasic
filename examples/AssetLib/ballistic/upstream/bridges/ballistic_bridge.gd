extends Node

@export var target_node_path: NodePath = "BallisticRoot"

# Request a velocity vector; bridge tries to call upstream helper if present,
# otherwise it falls back to a basic straight-line approximation (no gravity).
func request_velocity(tx: float, ty: float, tz: float, speed: float) -> Dictionary:
    var n = get_node_or_null(target_node_path)
    if n and n.has_method("best_firing_velocity_by_speed"):
        var res = n.call("best_firing_velocity_by_speed", Vector3(tx,ty,tz), speed)
        print("BallisticBridge: got res from upstream: " + str(res))
        return {"ok":true, "v":res}
    # Fallback: simple direct normalized vector
    var dir = Vector3(tx,ty,tz)
    if dir.length() == 0:
        return {"ok":false}
    var v = dir.normalized() * speed
    print("BallisticBridge: fallback velocity " + str(v))
    return {"ok":true, "v":v}

# VisualGasic-friendly alias
func RequestVelocity(tx: float, ty: float, tz: float, speed: float) -> void:
    request_velocity(tx,ty,tz,speed)
