extends "res://bleed_city_2.gd"

const Cockpit = preload("res://backlight_cockpit.gd")
const ICE := Color(0.22, 0.78, 1.0)
const GOLD := Color(1.0, 0.57, 0.16)
const SHELL := Color(0.22, 0.29, 0.36)
const INK := Color(0.045, 0.065, 0.10)
const CELLS := [Vector3(7, 0, 29), Vector3(-8, 0, 68), Vector3(31, 0, 49)]

var points := PackedVector3Array()
var shades := PackedColorArray()
var normals := PackedVector3Array()
var light_points := PackedVector3Array()
var light_shades := PackedColorArray()
var light_normals := PackedVector3Array()
var shell_material: ShaderMaterial
var light_material: ShaderMaterial
var atmosphere: Environment
var optics: Array[SubViewport] = []
var optical_material: ShaderMaterial
var carrier: MeshInstance3D
var dashboard: Node2D
var dashboard_view: SubViewport
var antialiasing := Viewport.MSAA_2X

func reset() -> void:
	super.reset()
	position_xz = Vector2(3.8, 4)
	heading = -0.06
	buggy_position = Vector2(0, 14)

func _triangle(a: Vector3, b: Vector3, c: Vector3, color: Color, lit: bool, normal: Vector3) -> void:
	if lit:
		light_points.append_array(PackedVector3Array([a, b, c]))
		light_shades.append_array(PackedColorArray([color, color, color]))
		light_normals.append_array(PackedVector3Array([normal, normal, normal]))
	else:
		points.append_array(PackedVector3Array([a, b, c]))
		shades.append_array(PackedColorArray([color, color, color]))
		normals.append_array(PackedVector3Array([normal, normal, normal]))

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, lit := false, normal := Vector3.ZERO) -> void:
	if normal == Vector3.ZERO:
		normal = (b - a).cross(c - a).normalized()
	_triangle(a, b, c, color, lit, normal)
	_triangle(a, c, d, color, lit, normal)

func _box(p: Vector3, size: Vector3, color: Color, lit := false, transform := Transform3D.IDENTITY) -> void:
	var corners: Array[Vector3] = []
	for v in [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0),
			Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)]:
		corners.append(transform * (p + v * size))
	var directions := [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT, Vector3.UP, Vector3.DOWN]
	var faces := [[0, 1, 2, 3], [4, 7, 6, 5], [0, 3, 7, 4], [1, 5, 6, 2], [3, 2, 6, 7], [0, 4, 5, 1]]
	for i in 6:
		var f: Array = faces[i]
		_quad(corners[f[0]], corners[f[1]], corners[f[2]], corners[f[3]], color, lit, transform.basis * directions[i])

func _trace(path: Array[Vector3], width: float, color: Color, transform := Transform3D.IDENTITY) -> void:
	for i in range(path.size() - 1):
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var across := Vector3(-(b.y - a.y), b.x - a.x, 0).normalized() * width * 0.5
		_quad(transform * (a - across), transform * (b - across),
			transform * (b + across), transform * (a + across), color, true)

func _prism(profile: PackedVector2Array, depth: float, color: Color, transform := Transform3D.IDENTITY) -> void:
	var center := Vector2.ZERO
	for p in profile:
		center += p / profile.size()
	for i in profile.size():
		var a := Vector3(profile[i].x, profile[i].y, 0)
		var q := profile[(i + 1) % profile.size()]
		var b := Vector3(q.x, q.y, 0)
		var edge := q - profile[i]
		var n := Vector3(edge.y, -edge.x, 0).normalized()
		_quad(transform * a, transform * b, transform * (b + Vector3(0, 0, depth)),
			transform * (a + Vector3(0, 0, depth)), color, false, transform.basis * n)
		for z in [0.0, depth]:
			_triangle(transform * Vector3(center.x, center.y, z),
				transform * (a + Vector3(0, 0, z)), transform * (b + Vector3(0, 0, z)),
				color, false, transform.basis * (Vector3.FORWARD if z == 0 else Vector3.BACK))

func _cylinder(center: Vector3, radius: float, length: float, color: Color, axis := 1, lit := false) -> void:
	var basis := Basis.IDENTITY if axis == 1 else Basis(Vector3.FORWARD, PI / 2)
	for i in 32:
		var a := Vector3(cos(i * TAU / 32), 0, sin(i * TAU / 32))
		var b := Vector3(cos((i + 1) * TAU / 32), 0, sin((i + 1) * TAU / 32))
		var p := center + basis * (a * radius - Vector3.UP * length / 2)
		var q := center + basis * (b * radius - Vector3.UP * length / 2)
		_quad(p, q, q + basis * Vector3.UP * length, p + basis * Vector3.UP * length,
			color, lit, basis * (a + b).normalized())
		for side in [-1.0, 1.0]:
			var cap: Vector3 = center + basis * Vector3.UP * length * side / 2
			_triangle(cap, cap + basis * a * radius, cap + basis * b * radius, color, lit, basis * Vector3.UP * side)

func _wheel_ring(x: float, radius: float, width: float, color: Color) -> void:
	for i in 48:
		var a := Vector3(0, cos(i * TAU / 48), sin(i * TAU / 48))
		var b := Vector3(0, cos((i + 1) * TAU / 48), sin((i + 1) * TAU / 48))
		_quad(Vector3(x, 0, 0) + a * radius, Vector3(x, 0, 0) + b * radius,
			Vector3(x, 0, 0) + b * (radius - width), Vector3(x, 0, 0) + a * (radius - width), color, true)

func _finish(label: String) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	for luminous in [false, true]:
		var vertices_for_surface := light_points if luminous else points
		if vertices_for_surface.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices_for_surface
		arrays[Mesh.ARRAY_NORMAL] = light_normals if luminous else normals
		arrays[Mesh.ARRAY_COLOR] = light_shades if luminous else shades
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, light_material if luminous else shell_material)
	points.clear()
	shades.clear()
	normals.clear()
	light_points.clear()
	light_shades.clear()
	light_normals.clear()
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance

func _materials() -> void:
	shell_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
varying vec3 world_point;
varying vec3 world_normal;
void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}
void fragment() {
	vec3 n = normalize(world_normal);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - world_point);
	float key = max(dot(n, normalize(vec3(-0.4, 0.75, -0.6))), 0.0);
	float rim = pow(1.0 - abs(dot(n, eye)), 3.0);
	vec3 satin = COLOR.rgb * (0.38 + key * 0.75);
	satin += vec3(0.025, 0.065, 0.10) * rim;
	if (world_point.y < 0.01 && n.y > 0.9) {
		vec2 tile = abs(fract(world_point.xz / 7.0 - 0.5) - 0.5) * 7.0;
		float edge_distance = min(tile.x, tile.y);
		float aa = max(fwidth(edge_distance), 0.002);
		float seam = 1.0 - smoothstep(0.025 - aa, 0.025 + aa, edge_distance);
		seam *= 1.0 - smoothstep(25.0, 95.0, length(VERTEX));
		satin *= 1.0 - seam * 0.35;
		float mottling = sin(world_point.x * 9.0 + sin(world_point.z * 13.0)) * sin(world_point.z * 8.0);
		satin += vec3(0.004, 0.006, 0.008) * mottling;
	}
	float spill = exp(-abs(abs(world_point.x) - 6.5) * 0.7);
	satin += vec3(0.008, 0.05, 0.075) * spill * max(n.y, 0.0);
	float haze = 1.0 - exp(-length(VERTEX) * 0.0018);
	ALBEDO = mix(satin, vec3(0.065, 0.065, 0.12), haze);
}
"""
	shell_material.shader = shader
	light_material = ShaderMaterial.new()
	var light_shader := Shader.new()
	light_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() { ALBEDO = COLOR.rgb; }
"""
	light_material.shader = light_shader
	atmosphere = Environment.new()
	atmosphere.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_shader := Shader.new()
	sky_shader.code = """shader_type sky;
void sky() {
	float y = EYEDIR.y;
	float band = exp(-abs(y + 0.012) * 19.0);
	float halo = exp(-abs(y + 0.005) * 4.0);
	vec3 sky_color = vec3(0.006, 0.012, 0.025);
	sky_color += vec3(0.21, 0.045, 0.24) * band;
	sky_color += vec3(0.035, 0.025, 0.085) * halo;
	COLOR = sky_color;
}
"""
	var sky_material := ShaderMaterial.new()
	sky_material.shader = sky_shader
	sky.sky_material = sky_material
	atmosphere.sky = sky

func build(view: Node) -> void:
	_materials()
	_box(Vector3(-62, -0.5, -16), Vector3(124, 0.5, 178), Color(0.07, 0.13, 0.18))
	for x in [-6.5, 6.5]:
		_box(Vector3(x - 0.1, 0.006, -12), Vector3(0.20, 0.025, 166), ICE, true)
	for z in [36.0, 84.0, 132.0]:
		for side in [-1.0, 1.0]:
			_box(Vector3(-56, 0.01, z + side * 4), Vector3(112, 0.025, 0.17), ICE * 0.7, true)
	for z in [25.0, 73.0, 121.0]:
		_gate(z)
	for side in [-1.0, 1.0]:
		for i in 4:
			var z := 10.0 + i * 35
			var x := -52.0 if side < 0 else 24.0
			_building(Vector3(x, 0, z), Vector3(28, 15 + (i % 3) * 7, 21), side, i)
		_monument(Vector3(side * 43, 0, 61))
	_plaza()
	_transit_court()
	world = _finish("SolidBacklitArchitecture")
	_courier()
	vehicle = _finish("ArcCourier")
	_cylinder(Vector3.ZERO, 0.6, 0.34, INK, 0)
	for x in [-0.177, 0.177]:
		_wheel_ring(x, 0.53, 0.105, ICE)
		_wheel_ring(x * 1.01, 0.22, 0.08, ICE * 0.7)
	var wheel_mesh := _finish("WheelPrototype")
	for side in [-1.0, 1.0]:
		for z in [-1.35, 1.4]:
			var wheel := MeshInstance3D.new()
			wheel.mesh = wheel_mesh.mesh
			wheel.position = Vector3(side * 1.12, 0.62, z)
			vehicle.add_child(wheel)
			wheels.append(wheel)
	wheel_mesh.queue_free()
	_carrier()
	carrier = _finish("DistrictCarrier")
	carrier.position = Vector3(-11, 1.4, 48)
	carrier.rotation.y = -0.25
	solids.append(Rect2(-14.5, 43, 7, 10))
	for point in CELLS:
		_cell()
		var cell := _finish("ChargeCell")
		cell.position = point
		bottles.append(cell)
	_create_optics(view)
	initialized = true

func _gate(z: float) -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * 13
		var transform := Transform3D(Basis.IDENTITY, Vector3(x, 0, z))
		_prism(PackedVector2Array([Vector2(-2.7, 0), Vector2(2.7, 0), Vector2(2.1, 10),
			Vector2(1.1, 14), Vector2(-1.1, 14), Vector2(-2.1, 10)]), 3.4, SHELL, transform)
		solids.append(Rect2(x - 2.7, z, 5.4, 3.4))
		_box(Vector3(x - 1.6, 1.2, z - 0.03), Vector3(3.2, 8.5, 0.025), INK)
		for offset in [-0.9, 0.9]:
			_trace([Vector3(offset, 1.6, -0.06), Vector3(offset, 8.3, -0.06),
				Vector3(offset * 0.45, 9.6, -0.06), Vector3(offset * 0.45, 12, -0.06)], 0.14, GOLD, transform)
		for y in [2.0, 2.6, 3.2]:
			_box(Vector3(x - 0.4, y, z - 0.07), Vector3(0.8, 0.19, 0.04), GOLD * 0.9, true)
	_box(Vector3(-15.3, 12, z), Vector3(30.6, 2.0, 3.4), SHELL)
	_box(Vector3(-10, 12.5, z - 0.04), Vector3(20, 0.9, 0.03), INK)
	for x in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		_box(Vector3(x - 1.4, 12.7, z - 0.08), Vector3(2.8, 0.44, 0.04), GOLD, true)
	_box(Vector3(-10, 11.9, z + 0.3), Vector3(20, 0.09, 2.8), ICE * 0.7, true)

func _building(p: Vector3, size: Vector3, side: float, index: int) -> void:
	# A recessed entrance is a real gap between two blocks, with a solid lintel.
	solids.append(Rect2(p.x, p.z + 3, size.x, size.z - 3))
	solids.append(Rect2(p.x, p.z, size.x * 0.38, 3))
	solids.append(Rect2(p.x + size.x * 0.62, p.z, size.x * 0.38, 3))
	_box(p + Vector3(0, 0, 3), size - Vector3(0, 0, 3), SHELL * (0.8 + index * 0.08))
	for offset in [0.0, size.x * 0.62]:
		_box(p + Vector3(offset, 0, 0), Vector3(size.x * 0.38, size.y, 3), SHELL)
	_box(p + Vector3(size.x * 0.38, 4, 0), Vector3(size.x * 0.24, size.y - 4, 3), SHELL)
	_box(p + Vector3(size.x * 0.38, 0, 0), Vector3(size.x * 0.24, 0.02, 3), ICE * 0.28, true)
	for y in range(6, int(size.y - 2), 3):
		_box(p + Vector3(2, y, -0.04), Vector3(size.x - 4, 0.4, 0.04), ICE * (0.7 if y % 2 == 0 else 0.45), true)
	_box(p + Vector3(3, size.y, 4), Vector3(size.x - 6, 1.5, size.z - 6), INK)
	_box(p + Vector3(4, size.y + 1.51, 5), Vector3(size.x - 8, 0.02, size.z - 8), ICE * 0.24, true)
	var face_x := p.x + size.x + 0.02 if side < 0 else p.x - 0.02
	var lens_center := Vector3(face_x - side * 0.03, minf(size.y - 4, 9), p.z + size.z - 4)
	_cylinder(lens_center, 2.8, 0.16, SHELL * 0.65, 0)
	_cylinder(lens_center - Vector3(side * 0.10, 0, 0), 2.12, 0.18, ICE * 0.72, 0, true)
	var transform := Transform3D(Basis(Vector3.UP, PI / 2 if side < 0 else -PI / 2), Vector3(face_x, 0, p.z + size.z * 0.5))
	for i in 5:
		var x := -5.0 + i * 2.2
		_trace([Vector3(x, 1.0, 0), Vector3(x, size.y * 0.35, 0), Vector3(x + 1, size.y * 0.35 + 1, 0),
			Vector3(x + 1, size.y * 0.74, 0)], 0.12, ICE * 0.85, transform)
		_box(Vector3(x + 0.7, size.y * 0.75, -0.015), Vector3(0.6, 0.8, 0.05), ICE, true, transform)
	for y in range(4, int(size.y), 4):
		_trace([Vector3(-size.z / 2, y, 0.025), Vector3(size.z / 2, y, 0.025)],
			0.025, Color(0.12, 0.21, 0.30), transform)
	for x in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		_trace([Vector3(x, 0.1, 0.025), Vector3(x, size.y - 0.1, 0.025)],
			0.025, Color(0.12, 0.21, 0.30), transform)

func _transit_court() -> void:
	for side in [-1.0, 1.0]:
		for i in 2:
			var center := Vector3(side * 10.2, 0, 95 + i * 16)
			var transform := Transform3D(Basis.IDENTITY, center - Vector3(0, 0, 1.2))
			_prism(PackedVector2Array([Vector2(-1.6, 0), Vector2(1.6, 0),
				Vector2(0.9, 3.2), Vector2(-0.9, 3.2)]), 2.4, SHELL, transform)
			_box(center + Vector3(-1.05, 3.2, -1.4), Vector3(2.1, 0.26, 2.8), INK)
			_box(center + Vector3(-0.67, 1.5, -1.22), Vector3(1.34, 1.15, 0.025), INK)
			var digit := 1 + i + (2 if side > 0 else 0)
			_digit(center + Vector3(-0.30, 1.62, -1.25), digit)
			solids.append(Rect2(center.x - 1.6, center.z - 1.2, 3.2, 2.4))
			_annulus(center + Vector3(0, 5.5, 0), 1.45, 0.14, GOLD)
			_trace([Vector3(-0.36, 6.3, 0), Vector3(0, 6.72, 0), Vector3(0.36, 6.3, 0)],
				0.10, GOLD, Transform3D(Basis.IDENTITY, center))
			_box(center + Vector3(-0.05, 5.9, 0), Vector3(0.1, 0.7, 0.05), GOLD, true)
		_box(Vector3(side * 10.2 - 0.14, 0.012, 89), Vector3(0.28, 0.025, 31), GOLD * 0.75, true)

func _annulus(center: Vector3, radius: float, width: float, color: Color) -> void:
	for i in 64:
		var a := Vector3(cos(i * TAU / 64), 0, sin(i * TAU / 64))
		var b := Vector3(cos((i + 1) * TAU / 64), 0, sin((i + 1) * TAU / 64))
		for y in [-0.08, 0.08]:
			var p := center + Vector3(0, y, 0)
			_quad(p + a * radius, p + b * radius, p + b * (radius - width), p + a * (radius - width), color, true)
		_quad(center + a * radius - Vector3.UP * 0.08, center + b * radius - Vector3.UP * 0.08,
			center + b * radius + Vector3.UP * 0.08, center + a * radius + Vector3.UP * 0.08, color, true)

func _digit(p: Vector3, number: int) -> void:
	var segments := ["", "bc", "abged", "abgcd", "fgbc"]
	var bars := {
		"a": Rect2(0, 0.85, 0.6, 0.08), "b": Rect2(0.52, 0.45, 0.08, 0.4),
		"c": Rect2(0.52, 0.05, 0.08, 0.4), "d": Rect2(0, 0, 0.6, 0.08),
		"e": Rect2(0, 0.05, 0.08, 0.4), "f": Rect2(0, 0.45, 0.08, 0.4),
		"g": Rect2(0, 0.43, 0.6, 0.08)}
	for segment in segments[number]:
		var rect: Rect2 = bars[segment]
		_box(p + Vector3(rect.position.x, rect.position.y, 0), Vector3(rect.size.x, rect.size.y, 0.03), GOLD * 0.85, true)

func _monument(p: Vector3) -> void:
	_cylinder(p + Vector3(0, 2, 0), 5.2, 4, SHELL)
	_cylinder(p + Vector3(0, 11, 0), 3.7, 16, INK)
	for y in [4.0, 6.0, 9.0, 12.0, 15.0, 19.0]:
		_cylinder(p + Vector3(0, y, 0), 3.85, 0.32, ICE, 1, true)
	_cylinder(p + Vector3(0, 24, 0), 1.6, 10, SHELL)
	_cylinder(p + Vector3(0, 29.1, 0), 1.65, 0.18, GOLD, 1, true)
	solids.append(Rect2(p.x - 5.2, p.z - 5.2, 10.4, 10.4))

func _plaza() -> void:
	for x in [-14.0, 14.0]:
		for z in [8.0, 42.0, 89.0, 145.0]:
			_box(Vector3(x - 0.5, 0, z), Vector3(1, 1.8, 1), INK)
			_box(Vector3(x - 0.36, 1.5, z - 0.025), Vector3(0.72, 0.22, 1.05), ICE, true)
			solids.append(Rect2(x - 0.5, z, 1, 1))
	_box(Vector3(-9, 0, 145), Vector3(18, 0.4, 6), SHELL)
	for x in [-5.0, 0.0, 5.0]:
		_box(Vector3(x - 1, 0.4, 147), Vector3(2, 4.5, 2), INK)
		_box(Vector3(x - 0.7, 1, 146.98), Vector3(1.4, 2.8, 0.03), GOLD, true)
	solids.append(Rect2(-9, 145, 18, 6))

func _courier() -> void:
	var hull := PackedVector2Array([Vector2(-0.96, 0.43), Vector2(0.96, 0.43), Vector2(1.05, 0.78),
		Vector2(0.78, 1.13), Vector2(-0.78, 1.13), Vector2(-1.05, 0.78)])
	_prism(hull, 3.6, SHELL, Transform3D(Basis.IDENTITY, Vector3(0, 0, -1.8)))
	_prism(PackedVector2Array([Vector2(-1.25, 1.13), Vector2(1.25, 1.13), Vector2(0.72, 1.92),
		Vector2(-0.58, 1.92)]), 1.35, INK, Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-0.675, 0, 0)))
	_box(Vector3(-0.69, 1.93, -0.72), Vector3(1.38, 0.06, 1.3), SHELL)
	_quad(Vector3(-0.61, 1.2, 1.20), Vector3(0.61, 1.2, 1.20),
		Vector3(0.61, 1.87, 0.64), Vector3(-0.61, 1.87, 0.64), Color(0.07, 0.16, 0.23))
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 0.98 - 0.045, 0.74, -1.75), Vector3(0.09, 0.17, 3.5), ICE, true)
		_quad(Vector3(side * 0.64 - 0.025, 1.16, 1.24), Vector3(side * 0.64 + 0.025, 1.16, 1.24),
			Vector3(side * 0.64 + 0.025, 1.93, 0.59), Vector3(side * 0.64 - 0.025, 1.93, 0.59), ICE, true)
		for z in [-1.35, 1.4]:
			_box(Vector3(side * 1.05 - 0.3, 1.0, z - 0.7), Vector3(0.6, 0.22, 1.4), SHELL)
		_box(Vector3(side * 0.52 - 0.18, 0.84, 1.81), Vector3(0.36, 0.13, 0.03), Color(0.72, 0.94, 1.0), true)
		_box(Vector3(side * 0.5 - 0.2, 0.72, -1.83), Vector3(0.4, 0.1, 0.04), GOLD, true)
	for z in [-1.6, -1.35, -1.1]:
		_box(Vector3(-0.5, 1.14, z), Vector3(1, 0.03, 0.08), ICE * 0.7, true)
	_box(Vector3(-0.65, 1.93, 0.58), Vector3(1.3, 0.06, 0.06), ICE * 0.8, true)

func _carrier() -> void:
	var profile := PackedVector2Array([Vector2(-2.5, 0.0), Vector2(2.5, 0.0), Vector2(3.1, 0.7),
		Vector2(2.7, 2.1), Vector2(1.7, 2.8), Vector2(-1.7, 2.8), Vector2(-2.7, 2.1), Vector2(-3.1, 0.7)])
	_prism(profile, 7.2, SHELL * 0.8, Transform3D(Basis.IDENTITY, Vector3(0, 0, -3.6)))
	_box(Vector3(-1.6, 1.55, 3.61), Vector3(3.2, 0.8, 0.03), INK)
	_box(Vector3(-1.6, 1.55, -3.65), Vector3(3.2, 0.8, 0.03), INK)
	for z in [-3.67, 3.67]:
		for side in [-1.0, 1.0]:
			_trace([Vector3(side * 2.2, 0.5, z), Vector3(side * 1.4, 0.5, z),
				Vector3(side * 0.9, 1.1, z), Vector3(side * 0.9, 2.45, z)], 0.16, GOLD)
		for x in [-0.5, 0.0, 0.5]:
			_box(Vector3(x - 0.12, 1.7, z - 0.01), Vector3(0.24, 0.42, 0.03), GOLD * 0.85, true)
	for side in [-1.0, 1.0]:
		var transform := Transform3D(Basis(Vector3.UP, side * PI / 2), Vector3(side * 2.9, 0, 0))
		_trace([Vector3(-2.6, 0.65, 0.06), Vector3(-1.4, 0.65, 0.06), Vector3(-0.8, 1.3, 0.06),
			Vector3(1.3, 1.3, 0.06), Vector3(2, 1.9, 0.06)], 0.18, GOLD, transform)
		_box(Vector3(side * 2.0 - 0.4, -0.16, -3.0), Vector3(0.8, 0.12, 6), GOLD * 0.8, true)
		_box(Vector3(side * 1.2 - 0.3, 1.3, 3.66), Vector3(0.6, 0.16, 0.04), GOLD, true)
	for z in [-2.8, -2.1, -1.4, -0.7]:
		_box(Vector3(-1.6, 2.81, z), Vector3(3.2, 0.03, 0.23), GOLD * 0.8, true)

func _cell() -> void:
	_cylinder(Vector3(0, 0.15, 0), 0.42, 0.3, SHELL)
	_cylinder(Vector3(0, 0.7, 0), 0.28, 0.9, INK)
	for y in [0.35, 0.53, 0.71, 0.89, 1.07]:
		_cylinder(Vector3(0, y, 0), 0.295, 0.07, ICE, 1, true)
	_cylinder(Vector3(0, 1.23, 0), 0.34, 0.18, SHELL)
	_cylinder(Vector3(0, 1.35, 0), 0.13, 0.08, GOLD, 1, true)

func collect_bottle() -> void:
	if driving:
		return
	for i in bottles.size():
		var point: Vector3 = CELLS[i]
		if bottles[i].visible and position_xz.distance_to(Vector2(point.x, point.z)) < 2.4:
			bottles[i].visible = false
			collected += 1
			return

func _effect(view: Node, size: Vector2i, code: String, texture: Texture2D) -> SubViewport:
	var target := SubViewport.new()
	target.size = size
	target.disable_3d = true
	target.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.add_child(target)
	var canvas := TextureRect.new()
	canvas.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	canvas.size = Vector2(size)
	canvas.texture = texture
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = code
	material.shader = shader
	canvas.material = material
	target.add_child(canvas)
	optics.append(target)
	return target

func _create_optics(view: Node) -> void:
	var blur := """shader_type canvas_item;
uniform vec2 direction = vec2(1.0, 0.0);
uniform bool threshold = false;
void fragment() {
	vec3 result = vec3(0.0);
	for (int i = -4; i <= 4; i++) {
		vec3 sample_color = texture(TEXTURE, UV + direction * TEXTURE_PIXEL_SIZE * float(i) * 1.8).rgb;
		if (threshold) {
			float peak = max(sample_color.r, max(sample_color.g, sample_color.b));
			sample_color *= smoothstep(0.48, 0.88, peak);
		}
		float weight = exp(-float(i * i) * 0.16);
		result += sample_color * weight / 4.38;
	}
	COLOR = vec4(result, 1.0);
}
"""
	var horizontal := _effect(view, Vector2i(320, 180), blur, view.viewport.get_texture())
	var horizontal_material: ShaderMaterial = horizontal.get_child(0).material
	horizontal_material.set_shader_parameter("threshold", true)
	horizontal_material.set_shader_parameter("direction", Vector2(3, 0))
	var vertical := _effect(view, Vector2i(320, 180), blur, horizontal.get_texture())
	var vertical_material: ShaderMaterial = vertical.get_child(0).material
	vertical_material.set_shader_parameter("direction", Vector2(0, 1))
	var composite := """shader_type canvas_item;
uniform sampler2D halo_texture : filter_linear;
uniform float glow_amount = 0.65;
uniform float film_time = 0.0;
void fragment() {
	vec3 source = texture(TEXTURE, UV).rgb;
	vec3 halo = texture(halo_texture, UV).rgb;
	vec3 color = source + halo * glow_amount;
	float vignette = 1.0 - 0.18 * dot(UV - vec2(0.5), UV - vec2(0.5));
	float grain = fract(sin(dot(floor(UV * vec2(960.0, 540.0)), vec2(12.9898, 78.233)) + film_time) * 43758.5453);
	color = color * vignette + (grain - 0.5) * 0.006;
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
"""
	var output := _effect(view, view.viewport.size, composite, view.viewport.get_texture())
	optical_material = output.get_child(0).material
	optical_material.set_shader_parameter("halo_texture", vertical.get_texture())
	dashboard_view = SubViewport.new()
	dashboard_view.size = view.viewport.size
	dashboard_view.transparent_bg = true
	dashboard_view.disable_3d = true
	dashboard_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.add_child(dashboard_view)
	dashboard = Cockpit.new()
	dashboard_view.add_child(dashboard)

func deactivate() -> void:
	visible = false
	for output in optics:
		output.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if dashboard_view != null:
		dashboard_view.render_target_update_mode = SubViewport.UPDATE_DISABLED

func render_style(view: Node, time: float, distance: float, detail: int) -> Texture2D:
	if not initialized:
		build(view)
	visible = true
	if view.viewport.transparent_bg:
		view.viewport.transparent_bg = false
	if view.camera.environment != atmosphere:
		view.camera.environment = atmosphere
	antialiasing = Viewport.MSAA_DISABLED if detail == 0 else Viewport.MSAA_2X
	vehicle.position = Vector3(buggy_position.x, 0, buggy_position.y)
	vehicle.rotation.y = buggy_heading
	vehicle.visible = not driving or inspection != 0
	for wheel in wheels:
		wheel.rotation.x = wheel_angle
		wheel.rotation.y = steering if wheel.position.z > 0 else 0
	carrier.position.y = 1.4 + sin(time * 0.8) * 0.07
	if inspection == 1:
		camera_position = Vector3(44, 35, -16)
		camera_heading = -0.48
		camera_pitch = -0.27
	elif inspection == 2:
		camera_position = Vector3(buggy_position.x + 4.6, 2.9, buggy_position.y + 5.3)
		camera_heading = -2.43
		camera_pitch = -0.20
	else:
		camera_position = Vector3(position_xz.x, 1.62 if driving else 1.8, position_xz.y)
		camera_heading = heading
		camera_pitch = -0.025
	view.present(camera_position.x, camera_position.y, camera_position.z,
		camera_heading, camera_pitch, distance if inspection == 0 else maxf(distance, 240))
	if detail == 0:
		return view.viewport.get_texture()
	for output in optics:
		output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	optical_material.set_shader_parameter("glow_amount", 0.62 if detail == 1 else 0.85)
	optical_material.set_shader_parameter("film_time", floorf(time * 24))
	return optics.back().get_texture()

func cockpit_texture(time: float) -> Texture2D:
	dashboard.time = time
	dashboard.speed = velocity
	dashboard.heading = heading
	dashboard.charge = collected
	dashboard.queue_redraw()
	dashboard_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	return dashboard_view.get_texture()
