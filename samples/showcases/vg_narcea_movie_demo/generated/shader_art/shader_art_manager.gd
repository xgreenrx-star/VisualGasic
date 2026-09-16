extends Node3D
## Compact shader-on-shapes reel (Beta Showcase style) for Narcea movie embed.

const DEMO_SEC := 18.0
const SCENE_LEN := 6.0

var _t := 0.0
var _cam: Camera3D
var _synth: MeshInstance3D
var _chrome: MeshInstance3D
var _fault: MeshInstance3D
var _synth_mat: ShaderMaterial
var _chrome_mat: ShaderMaterial
var _fault_mat: ShaderMaterial


func _ready() -> void:
	_setup_env()
	_cam = Camera3D.new()
	_cam.fov = 58.0
	_cam.current = true
	add_child(_cam)

	_synth_mat = ShaderMaterial.new()
	_synth_mat.shader = load("res://generated/shader_art/shaders/synth_grid.gdshader")
	_synth = _make_mesh(PlaneMesh.new(), Vector3(0, 0, 0), Vector3(12, 1, 12), _synth_mat)
	add_child(_synth)

	_chrome_mat = ShaderMaterial.new()
	_chrome_mat.shader = load("res://generated/shader_art/shaders/chrome_metaball.gdshader")
	var sphere := SphereMesh.new()
	sphere.radius = 1.6
	sphere.height = 3.2
	_chrome = _make_mesh(sphere, Vector3(0, 0.5, 0), Vector3.ONE, _chrome_mat)
	add_child(_chrome)

	_fault_mat = ShaderMaterial.new()
	_fault_mat.shader = load("res://generated/shader_art/shaders/fault_cube.gdshader")
	_fault = _make_mesh(BoxMesh.new(), Vector3(0, 0, 0), Vector3(2.4, 2.4, 2.4), _fault_mat)
	add_child(_fault)

	_set_scene(0)


func _make_mesh(mesh: Mesh, pos: Vector3, scale: Vector3, mat: ShaderMaterial) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	inst.scale = scale
	inst.material_override = mat
	return inst


func _setup_env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.35, 0.55)
	env.ambient_light_energy = 0.7
	env.glow_enabled = true
	env.glow_intensity = 1.1
	env.glow_bloom = 0.4
	we.environment = env
	add_child(we)


func _process(delta: float) -> void:
	_t += delta
	var scene_idx := int(_t / SCENE_LEN) % 3
	_set_scene(scene_idx)

	var local := fmod(_t, SCENE_LEN) / SCENE_LEN
	var orbit := _t * 0.45
	_cam.position = Vector3(sin(orbit) * 5.5, 2.2 + sin(_t * 0.7) * 0.35, cos(orbit) * 5.5)
	_cam.look_at(Vector3(0, 0.2, 0), Vector3.UP)

	if _synth_mat:
		_synth_mat.set_shader_parameter("u_blend", 1.0)
		_synth_mat.set_shader_parameter("u_energy", 0.35 + local * 0.45)
	if _chrome_mat:
		_chrome_mat.set_shader_parameter("u_blend", 1.0)
		_chrome.rotation.y = _t * 0.9
	if _fault_mat:
		_fault_mat.set_shader_parameter("u_blend", 1.0)
		_fault_mat.set_shader_parameter("explosion_factor", 0.6 + sin(_t * 2.2) * 0.35)
		_fault.rotation = Vector3(_t * 0.35, _t * 0.55, _t * 0.25)


func _set_scene(idx: int) -> void:
	_synth.visible = idx == 0
	_chrome.visible = idx == 1
	_fault.visible = idx == 2
