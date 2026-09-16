extends Node3D
## Lorenz attractor point cloud — soft dots, no billboard streaks.

const COUNT := 96
const SIGMA := 10.0
const RHO := 28.0
const BETA := 8.0 / 3.0
const SIM_STEP := 1.0 / 60.0

var multimesh_instance: MultiMeshInstance3D
var positions: PackedVector3Array
var _hide_frames: PackedInt32Array
var _sim_accum: float = 0.0
var _frame: int = 0


func _ready() -> void:
	positions = PackedVector3Array()
	positions.resize(COUNT)
	_hide_frames = PackedInt32Array()
	_hide_frames.resize(COUNT)
	for i in COUNT:
		var t := float(i) * 0.013
		positions[i] = Vector3(
			sin(t * 3.1) * 0.4 + 0.2,
			cos(t * 2.7) * 0.4,
			sin(t * 1.9) * 0.4 + 8.0
		)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = COUNT

	var dot := SphereMesh.new()
	dot.radius = 0.065
	dot.height = 0.13
	mm.mesh = dot

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.35, 0.78, 1.0, 0.42)
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.62, 1.0)
	mat.emission_energy_multiplier = 1.1

	multimesh_instance = MultiMeshInstance3D.new()
	multimesh_instance.multimesh = mm
	multimesh_instance.material_override = mat
	multimesh_instance.position = Vector3(0.0, 14.0, -28.0)
	add_child(multimesh_instance)
	_push_transforms(true)


func _process(delta: float) -> void:
	if not visible:
		return
	_frame += 1
	_sim_accum += minf(delta, 0.033)
	while _sim_accum >= SIM_STEP:
		_step_lorenz(SIM_STEP)
		_sim_accum -= SIM_STEP
	_push_transforms(_frame % 10 == 0)


func _step_lorenz(step: float) -> void:
	var dt := step * 0.85
	for i in COUNT:
		var p := positions[i]
		var dx := SIGMA * (p.y - p.x)
		var dy := p.x * (RHO - p.z) - p.y
		var dz := p.x * p.y - BETA * p.z
		p += Vector3(dx, dy, dz) * dt * 0.08
		if p.length() > 42.0:
			var t := float(i) * 0.013
			p = Vector3(sin(t * 3.1) * 0.4, cos(t * 2.7) * 0.4, 8.0 + sin(t * 1.9) * 0.4)
			_hide_frames[i] = 6
		elif p.length() > 28.0:
			_hide_frames[i] = 2
		positions[i] = p


func _push_transforms(update_colors: bool) -> void:
	var mm := multimesh_instance.multimesh
	for i in COUNT:
		var p := positions[i]
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
		if _hide_frames[i] > 0:
			_hide_frames[i] -= 1
			mm.set_instance_color(i, Color(0.0, 0.0, 0.0, 0.0))
		elif update_colors:
			var hue := clampf(p.length() / 28.0, 0.0, 1.0)
			mm.set_instance_color(i, Color(0.2 + hue * 0.45, 0.5 + hue * 0.28, 1.0, 0.38 + hue * 0.28))
