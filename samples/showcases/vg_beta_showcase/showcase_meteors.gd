extends Node3D
## Meteors during synth grid — falling streak + grid ripple on impact.

const POOL := 4
const MAX_RIPPLES := 4
const GRID_Y := 0.45
const RIPPLE_LIFE := 2.5

var _rng := RandomNumberGenerator.new()
var _spawn_cd := 1.5
var _slots: Array = []
var _ripples: Array = []


func _ready() -> void:
	_rng.randomize()
	for _i in POOL:
		var slot := _make_slot()
		_slots.append(slot)
		add_child(slot["root"])
	for _i in MAX_RIPPLES:
		_ripples.append({"x": 0.0, "z": 0.0, "age": 999.0, "strength": 0.0})


func _make_slot() -> Dictionary:
	var root := Node3D.new()
	root.visible = false

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.11
	sphere.height = 0.22
	head.mesh = sphere
	head.material_override = _glow_mat(Color(1.0, 0.96, 0.88, 0.95), 3.0)
	root.add_child(head)

	var trail := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.06, 0.06, 1.0)
	trail.mesh = box
	trail.material_override = _glow_mat(Color(1.0, 1.0, 1.0, 0.82), 2.2)
	root.add_child(trail)

	return {
		"root": root,
		"head": head,
		"trail": trail,
		"phase": "idle",
		"pos": Vector3.ZERO,
		"vel": Vector3.ZERO,
	}


func _glow_mat(col: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = Color(col.r, col.g, col.b, 1.0)
	mat.emission_energy_multiplier = energy
	return mat


func get_grid_ripples() -> PackedVector4Array:
	var out := PackedVector4Array()
	out.resize(MAX_RIPPLES)
	for i in MAX_RIPPLES:
		var r: Dictionary = _ripples[i]
		out[i] = Vector4(float(r["x"]), float(r["z"]), float(r["age"]), float(r["strength"]))
	return out


func _process(delta: float) -> void:
	_age_ripples(delta)
	if not visible:
		return

	_spawn_cd -= delta
	if _spawn_cd <= 0.0:
		_try_spawn()
		_spawn_cd = _rng.randf_range(2.4, 5.2)

	for slot in _slots:
		_tick_slot(slot, delta)


func _try_spawn() -> void:
	for slot in _slots:
		if slot["phase"] == "idle":
			_spawn_meteor(slot)
			return


func _spawn_meteor(slot: Dictionary) -> void:
	var target_x := _rng.randf_range(-9.0, 9.0)
	var target_z := _rng.randf_range(-7.0, 5.0)
	var start := Vector3(
		target_x + _rng.randf_range(-4.0, 4.0),
		_rng.randf_range(17.0, 24.0),
		target_z + _rng.randf_range(-5.0, 5.0)
	)
	var target := Vector3(target_x, GRID_Y, target_z)
	var vel := (target - start).normalized() * _rng.randf_range(15.0, 24.0)

	slot["pos"] = start
	slot["vel"] = vel
	slot["phase"] = "fall"
	slot["root"].visible = true
	slot["head"].visible = true
	slot["trail"].visible = true
	_align_meteor(slot)


func _spawn_ripple(x: float, z: float, strength: float) -> void:
	var slot_idx := 0
	var best_age := -1.0
	for i in MAX_RIPPLES:
		var r: Dictionary = _ripples[i]
		if float(r["strength"]) <= 0.001:
			slot_idx = i
			break
		if float(r["age"]) > best_age:
			best_age = float(r["age"])
			slot_idx = i

	_ripples[slot_idx] = {"x": x, "z": z, "age": 0.0, "strength": strength}


func _tick_slot(slot: Dictionary, delta: float) -> void:
	if slot["phase"] != "fall":
		return

	slot["pos"] = slot["pos"] + slot["vel"] * delta
	_align_meteor(slot)
	if slot["pos"].y > GRID_Y:
		return

	slot["pos"].y = GRID_Y
	var strength := clampf(slot["vel"].length() / 24.0, 0.5, 1.0)
	_spawn_ripple(slot["pos"].x, slot["pos"].z, strength)
	slot["phase"] = "idle"
	slot["root"].visible = false


func _align_meteor(slot: Dictionary) -> void:
	var root: Node3D = slot["root"]
	var trail: MeshInstance3D = slot["trail"]
	root.position = slot["pos"]

	var dir: Vector3 = slot["vel"]
	if dir.length_squared() < 0.001:
		return
	dir = dir.normalized()
	var trail_len := clampf(slot["vel"].length() * 0.09, 1.4, 3.2)
	root.basis = Basis.looking_at(dir, Vector3.UP)
	trail.position = Vector3(0.0, 0.0, trail_len * 0.5)
	trail.scale = Vector3(1.0, 1.0, trail_len)


func _age_ripples(delta: float) -> void:
	for ripple in _ripples:
		if float(ripple["strength"]) <= 0.001:
			continue
		ripple["age"] = float(ripple["age"]) + delta
		if float(ripple["age"]) > RIPPLE_LIFE:
			ripple["strength"] = 0.0
			ripple["age"] = 999.0
