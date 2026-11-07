extends SubViewport

var assembly := Node3D.new()
var lamps: Array[MeshInstance3D] = []
var lamp_materials: Array[StandardMaterial3D] = []
var light := OmniLight3D.new()
var indicator_materials: Array[StandardMaterial3D] = []
var internal_lights: Array[OmniLight3D] = []

func cable(points: Array[Vector3], radius: float, surface: Material, ribbed: bool = false) -> void:
	var curve := Curve3D.new()
	for index in range(points.size()):
		var before := points[maxi(0, index - 1)]
		var after := points[mini(points.size() - 1, index + 1)]
		var tangent := (after - before) * 0.18
		curve.add_point(points[index], -tangent, tangent)
	var length := curve.get_baked_length()
	var segments := 46 if ribbed else 25
	for index in range(segments):
		var start := curve.sample_baked(length * index / segments)
		var finish := curve.sample_baked(length * (index + 1) / segments)
		rod(start, finish, radius, surface)
		if ribbed:
			var ring := MeshInstance3D.new()
			var mesh := TorusMesh.new()
			mesh.inner_radius = radius * 0.9
			mesh.outer_radius = radius * 1.25
			mesh.rings = 8
			mesh.ring_segments = 8
			ring.mesh = mesh
			ring.material_override = surface
			ring.position = (start + finish) * 0.5
			ring.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())
			assembly.add_child(ring)

func material(colour: Color, metallic: float = 0, glow: float = 0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = colour
	result.metallic = metallic
	result.roughness = 0.28
	if colour.a < 1:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		result.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow > 0:
		result.emission_enabled = true
		result.emission = colour
		result.emission_energy_multiplier = glow
	return result

func box(position: Vector3, dimensions: Vector3, surface: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.material_override = surface
	node.position = position
	assembly.add_child(node)
	return node

func rod(start: Vector3, end: Vector3, radius: float, surface: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = start.distance_to(end)
	mesh.radial_segments = 12
	node.mesh = mesh
	node.material_override = surface
	node.position = (start + end) * 0.5
	var direction := (end - start).normalized()
	node.quaternion = Quaternion(Vector3.UP, direction)
	assembly.add_child(node)
	return node

func _ready() -> void:
	size = Vector2i(640, 640)
	transparent_bg = true
	own_world_3d = true
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(assembly)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.1
	camera.position = Vector3(3.9, 2.8, 4.8)
	add_child(camera)
	camera.look_at(Vector3(0, 0.05, 0))
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.35, 0.55, 0.65)
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -35, 0)
	key.light_color = Color(0.75, 0.88, 1)
	key.light_energy = 1.8
	add_child(key)
	light.position = Vector3(0, 0.4, 0)
	light.light_color = Color(0.2, 0.8, 1)
	light.light_energy = 1
	light.omni_range = 4
	add_child(light)
	var silver := material(Color(0.68, 0.71, 0.68), 0.7)
	var edges := material(Color(0.75, 0.85, 0.82), 0.35, 0.15)
	var dark := material(Color(0.025, 0.065, 0.07), 0.3)
	var copper := material(Color(0.8, 0.48, 0.18), 0.7, 0.25)
	var glass := material(Color(0.3, 0.75, 0.85, 0.045))
	var circuit := material(Color(0.38, 0.42, 0.21), 0.1)
	var ivory := material(Color(0.78, 0.75, 0.6), 0.1)
	var tube_glass := material(Color(0.72, 0.82, 0.75, 0.16))
	box(Vector3(0, -0.83, 0), Vector3(2.55, 0.14, 1.95), dark)
	box(Vector3(0, -0.74, 0), Vector3(2.42, 0.035, 1.82), circuit)
	for x in [-1.24, 1.24]:
		for z in [-0.94, 0.94]:
			rod(Vector3(x, -0.8, z), Vector3(x, 0.92, z), 0.025, silver)
			for y in [-0.7, 0.82]:
				rod(Vector3(x - 0.045, y, z), Vector3(x + 0.045, y, z), 0.047, silver)
	for y in [-0.8, 0.92]:
		for z in [-0.94, 0.94]:
			rod(Vector3(-1.24, y, z), Vector3(1.24, y, z), 0.018, edges)
		for x in [-1.24, 1.24]:
			rod(Vector3(x, y, -0.94), Vector3(x, y, 0.94), 0.018, edges)
	box(Vector3(0, 0.92, 0), Vector3(2.48, 0.008, 1.88), glass)
	for z in [-0.94, 0.94]:
		box(Vector3(0, 0.06, z), Vector3(2.48, 1.72, 0.008), glass)
	for x in [-1.24, 1.24]:
		box(Vector3(x, 0.06, 0), Vector3(0.008, 1.72, 1.88), glass)
	var colours := [Color(0.82, 0.18, 0.08), Color(0.85, 0.61, 0.16), Color(0.24, 0.58, 0.24), Color(0.65, 0.7, 0.4)]
	for bank in range(3):
		var z := -0.62 + bank * 0.55
		box(Vector3(-0.88, 0.02, z), Vector3(0.045, 1.28, 0.24), ivory)
		box(Vector3(0.88, 0.02, z), Vector3(0.045, 1.28, 0.24), circuit)
		for lane in range(4):
			var y := -0.5 + lane * 0.35
			var start := Vector3(-1.04, y, z)
			var finish := Vector3(1.04, y, z)
			var colour: Color = colours[(lane + bank) % colours.size()]
			var luminous := material(colour, 0.25, 0.4)
			lamps.append(rod(start + Vector3(0.12, 0, 0), finish - Vector3(0.12, 0, 0), 0.036, luminous))
			lamp_materials.append(luminous)
			rod(start, start + Vector3(0.12, 0, 0), 0.085, silver)
			rod(finish - Vector3(0.12, 0, 0), finish, 0.085, silver)
			rod(start + Vector3(0.12, 0, 0), finish - Vector3(0.12, 0, 0), 0.09, tube_glass)
			for pin in range(3):
				var x := -0.7 + pin * 0.7
				rod(Vector3(x, y - 0.05, z), Vector3(x, y - 0.12, z), 0.026, copper)
			cable([finish, Vector3(1.13, y, z + 0.1), Vector3(0.9, -0.7, z + 0.2)], 0.009, ivory)
	for index in range(5):
		var x := -0.72 + index * 0.3
		rod(Vector3(x, -0.64, -0.76), Vector3(x, 0.67, -0.76), 0.04, material(colours[index % 4], 0.3, 0.2))
		cable([Vector3(x, 0.65, -0.76), Vector3(x + 0.13, 0.78, -0.3), Vector3(x + 0.16, 0.35, 0.48)], 0.012, ivory)
	cable([Vector3(-0.68, 0.57, 0.7), Vector3(-0.78, 0.33, 0.81), Vector3(-0.62, -0.45, 0.85), Vector3(0.05, -0.58, 0.84), Vector3(0.55, -0.27, 0.82), Vector3(0.59, 0.5, 0.72)], 0.057, silver, true)
	cable([Vector3(-0.55, -0.5, -0.6), Vector3(-0.28, 0.64, -0.5), Vector3(0.32, 0.73, -0.4), Vector3(0.63, -0.4, -0.1)], 0.045, ivory, true)
	for index in range(8):
		var x := -0.98 + index * 0.28
		rod(Vector3(x, -0.68, -0.83), Vector3(x, -0.68, 0.78), 0.008, copper)
		box(Vector3(x, -0.64, 0.8), Vector3(0.1, 0.08, 0.09), silver)
	box(Vector3(-0.2, 1.01, -0.15), Vector3(0.62, 0.12, 0.5), silver)
	box(Vector3(-0.2, 1.08, -0.15), Vector3(0.39, 0.035, 0.28), material(Color(0.6, 0.95, 0.95), 0.2, 0.6))
	for index in range(6):
		var colour: Color = colours[index % colours.size()]
		var surface := material(colour, 0.1, 2)
		indicator_materials.append(surface)
		var position := Vector3(-0.9 + (index % 3) * 0.86, -0.35 + (index / 3) * 0.9, 0.67)
		box(position - Vector3(0, 0, 0.035), Vector3(0.19, 0.19, 0.09), silver)
		var bulb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.065
		sphere.height = 0.13
		sphere.radial_segments = 12
		sphere.rings = 6
		bulb.mesh = sphere
		bulb.material_override = surface
		bulb.position = position
		assembly.add_child(bulb)
		if index < 3:
			var glow := OmniLight3D.new()
			glow.position = position + Vector3(0, 0.08, -0.14)
			glow.light_color = colour
			glow.omni_range = 1.15
			glow.light_energy = 0.5
			assembly.add_child(glow)
			internal_lights.append(glow)

func animate(time: float, speaking: float, reduced: bool) -> void:
	assembly.rotation.y = 0.1 if reduced else 0.1 + sin(time * 0.22) * 0.1
	for index in range(lamp_materials.size()):
		var strength := 0.5
		if not reduced:
			strength += (0.5 + 0.5 * sin(time * (5 if speaking > 0 else 1.4) + index * 1.7)) * (0.9 if speaking > 0 else 0.35)
		lamp_materials[index].emission_energy_multiplier = strength
	light.light_energy = 0.8 if reduced else 0.8 + speaking * 0.4
	for index in range(indicator_materials.size()):
		var pulse := 0.55 if reduced else 0.12 + pow(0.5 + 0.5 * sin(time * (5.0 if speaking > 0 else 2.2) + index * 1.9), 3)
		indicator_materials[index].emission_energy_multiplier = 0.5 + pulse * 4
		if index < internal_lights.size():
			internal_lights[index].light_energy = 0.12 + pulse * 1.4
	render_target_update_mode = SubViewport.UPDATE_ONCE
