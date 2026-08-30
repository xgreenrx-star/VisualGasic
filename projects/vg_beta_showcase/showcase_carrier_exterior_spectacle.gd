extends Node3D
## Chrome metaball / fault cube spectacle — visible through the cockpit windshield in deep space.

enum Mode { OFF, CHROME, FAULT, CROSSFADE }

const CHROME_SHADER := "res://shaders/chrome_metaball.gdshader"
const FAULT_SHADER := "res://shaders/fault_cube.gdshader"
const FAULT_CORONA := "res://shaders/fault_plasma_corona.gdshader"
const FAULT_RING := "res://shaders/fault_energy_ring.gdshader"
const SKY_FAULT := "res://shaders/procedural_sky_fault.gdshader"

var mode: int = Mode.OFF
var scene_t: float = 0.0
var crossfade: float = 0.0

var env_node: WorldEnvironment
var sky: Sky
var sky_fault: ShaderMaterial
var chrome_mesh: MeshInstance3D
var chrome_mat: ShaderMaterial
var fault_mesh: MeshInstance3D
var fault_mat: ShaderMaterial
var fault_corona: MeshInstance3D
var fault_corona_mat: ShaderMaterial
var fault_rings: Array[MeshInstance3D] = []
var fault_ring_mat: ShaderMaterial


func _ready() -> void:
	visible = false
	_build_environment()
	_build_chrome()
	_build_fault()
	set_mode(Mode.OFF)


func set_mode(next: int) -> void:
	mode = next
	scene_t = 0.0
	visible = mode != Mode.OFF
	match mode:
		Mode.OFF:
			crossfade = 0.0
		Mode.CHROME:
			crossfade = 0.0
			_apply_weights(0.0, 1.0)
		Mode.FAULT:
			crossfade = 1.0
			_apply_weights(0.0, 1.0)
		Mode.CROSSFADE:
			pass
	_apply_visibility()


func begin_crossfade_to_fault() -> void:
	mode = Mode.CROSSFADE


func tick(delta: float) -> void:
	if mode == Mode.OFF:
		return
	scene_t += delta
	if mode == Mode.CROSSFADE:
		crossfade = clampf(crossfade + delta * 0.22, 0.0, 1.0)
		if crossfade >= 1.0:
			mode = Mode.FAULT
	_apply_weights(1.0 - crossfade, crossfade)
	_update_uniforms()
	_update_pose()


func sync_to_ship(ship_xf: Transform3D, look_local: Vector3 = Vector3(0, 0, -1)) -> void:
	var world_look := ship_xf.basis * look_local
	global_position = ship_xf.origin + world_look.normalized() * 42.0
	look_at(global_position + world_look.normalized() * 30.0, Vector3.UP)


func _apply_weights(chrome_w: float, fault_w: float) -> void:
	if chrome_mat:
		chrome_mat.set_shader_parameter("u_blend", chrome_w)
	if fault_mat:
		fault_mat.set_shader_parameter("u_blend", fault_w)
	if fault_corona_mat:
		fault_corona_mat.set_shader_parameter("u_blend", fault_w)
	if fault_ring_mat:
		fault_ring_mat.set_shader_parameter("u_blend", fault_w)
	if chrome_mesh:
		chrome_mesh.visible = chrome_w > 0.01
	if fault_mesh:
		fault_mesh.visible = fault_w > 0.01
	if fault_corona:
		fault_corona.visible = fault_w > 0.01
	for ring in fault_rings:
		ring.visible = fault_w > 0.01


func _apply_visibility() -> void:
	_apply_weights(1.0 - crossfade, crossfade)


func _update_uniforms() -> void:
	if fault_mat and fault_mesh.visible:
		var boom := 1.0 + sin(scene_t * 1.7) * 0.35
		fault_mat.set_shader_parameter("explosion_factor", boom)
		if fault_corona_mat:
			fault_corona_mat.set_shader_parameter("explosion_factor", boom)
		if fault_ring_mat:
			fault_ring_mat.set_shader_parameter("explosion_factor", boom)


func _update_pose() -> void:
	var spin := scene_t
	if chrome_mesh and chrome_mesh.visible:
		chrome_mesh.rotation.y = spin * 0.35
		chrome_mesh.rotation.x = sin(spin * 0.22) * 0.18
	if fault_mesh and fault_mesh.visible:
		fault_mesh.rotation.y = spin * 0.48
		fault_mesh.rotation.x = sin(spin * 0.31) * 0.25


func _build_environment() -> void:
	env_node = WorldEnvironment.new()
	var env := Environment.new()
	sky = Sky.new()
	sky_fault = ShaderMaterial.new()
	sky_fault.shader = load(SKY_FAULT)
	sky.sky_material = sky_fault
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.16, 0.28)
	env.ambient_light_energy = 0.45
	env.glow_enabled = true
	env.glow_intensity = 1.25
	env.glow_bloom = 0.38
	env.glow_hdr_threshold = 1.15
	env_node.environment = env
	add_child(env_node)


func _build_chrome() -> void:
	chrome_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(10.0, 10.0, 10.0)
	chrome_mesh.mesh = box
	chrome_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chrome_mat = ShaderMaterial.new()
	chrome_mat.shader = load(CHROME_SHADER)
	chrome_mesh.material_override = chrome_mat
	add_child(chrome_mesh)


func _build_fault() -> void:
	fault_corona = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	fault_corona.mesh = sphere
	fault_corona.scale = Vector3.ONE * 14.0
	fault_corona.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fault_corona_mat = ShaderMaterial.new()
	fault_corona_mat.shader = load(FAULT_CORONA)
	fault_corona.material_override = fault_corona_mat
	add_child(fault_corona)

	fault_ring_mat = ShaderMaterial.new()
	fault_ring_mat.shader = load(FAULT_RING)
	for i in 3:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.72
		torus.outer_radius = 1.0
		ring.mesh = torus
		ring.scale = Vector3.ONE * (4.0 + float(i) * 1.2)
		ring.rotation_degrees = Vector3(28.0 * float(i), 38.0 * float(i), 18.0 * float(i))
		ring.material_override = fault_ring_mat
		ring.set_instance_shader_parameter("u_phase", float(i) * 2.09)
		add_child(ring)
		fault_rings.append(ring)

	fault_mesh = MeshInstance3D.new()
	fault_mesh.mesh = _build_unwelded_cube(2.0, 10)
	fault_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fault_mat = ShaderMaterial.new()
	fault_mat.shader = load(FAULT_SHADER)
	fault_mat.set_shader_parameter("explosion_factor", 1.0)
	fault_mesh.material_override = fault_mat
	add_child(fault_mesh)


func _build_unwelded_cube(half: float, jitter: float) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var corners: Array[Vector3] = []
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for sz in [-1, 1]:
				var p := Vector3(float(sx), float(sy), float(sz)) * half
				p += Vector3(
					rng.randf_range(-1.0, 1.0),
					rng.randf_range(-1.0, 1.0),
					rng.randf_range(-1.0, 1.0)
				) * (jitter * 0.01)
				corners.append(p)
	var faces: Array[PackedInt32Array] = [
		PackedInt32Array([0, 1, 3, 2]),
		PackedInt32Array([4, 6, 7, 5]),
		PackedInt32Array([0, 2, 6, 4]),
		PackedInt32Array([1, 5, 7, 3]),
		PackedInt32Array([0, 4, 5, 1]),
		PackedInt32Array([2, 3, 7, 6]),
	]
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for f in faces:
		var base := verts.size()
		for vi in f:
			verts.append(corners[vi])
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
