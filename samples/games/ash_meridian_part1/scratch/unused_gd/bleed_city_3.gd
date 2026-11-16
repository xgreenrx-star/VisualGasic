extends Node3D

const CYAN := Color(0.10, 0.96, 1.0)
const PINK := Color(1.0, 0.16, 0.72)
const AMBER := Color(1.0, 0.58, 0.08)
const WHITE := Color(0.86, 0.97, 1.0)
const BOTTLE_POSITIONS := [Vector3(6.2, 0.55, 22), Vector3(-7.4, 0.55, 58), Vector3(18, 0.55, 84)]

var position_xz := Vector2(0, 6)
var heading := 0.0
var velocity := 0.0
var driving := false
var inspection := 0
var buggy_position := Vector2(0, 16)
var buggy_heading := 0.0
var collected := 0
var solids: Array[Rect2] = []
var bottles: Array[MeshInstance3D] = []
var wheels: Array[Node3D] = []
var lamps: Array[Node3D] = []
var vehicle: MeshInstance3D
var world: MeshInstance3D
var beam: MeshInstance3D
var initialized := false
var wheel_angle := 0.0
var steering := 0.0
var neon: ShaderMaterial

func reset() -> void:
	position_xz = Vector2(0, 6)
	heading = 0
	velocity = 0
	driving = false
	inspection = 0
	buggy_position = Vector2(0, 16)
	buggy_heading = 0
	collected = 0
	wheel_angle = 0
	steering = 0
	for bottle in bottles:
		bottle.visible = true

func _freeze(view: Node, label: String) -> MeshInstance3D:
	var seen: Dictionary = {}
	var unique_edges := PackedVector3Array()
	var unique_colors := PackedColorArray()
	for i in range(0, view.edges.size(), 2):
		var a: Vector3 = view.edges[i]
		var b: Vector3 = view.edges[i + 1]
		if a == b:
			continue
		var pair := [a, b] if a < b else [b, a]
		if seen.has(pair):
			continue
		seen[pair] = true
		unique_edges.append(a)
		unique_edges.append(b)
		unique_colors.append(view.edge_colors[i])
		unique_colors.append(view.edge_colors[i + 1])
	view.edges = unique_edges
	view.edge_colors = unique_colors
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = view._mesh()
	if neon == null:
		neon = view.line_material.duplicate()
		neon.set_shader_parameter("line_width", 1.08)
		var halo: ShaderMaterial = view.line_material.next_pass.duplicate()
		halo.set_shader_parameter("line_width", 4.8)
		neon.next_pass = halo
	if instance.mesh.get_surface_count() == 2:
		instance.mesh.surface_set_material(1, neon)
	elif view.vertices.is_empty() and instance.mesh.get_surface_count() == 1:
		instance.mesh.surface_set_material(0, neon)
	view.vertices.clear()
	view.colors.clear()
	view.edges.clear()
	view.edge_colors.clear()
	add_child(instance)
	return instance

func build(view: Node) -> void:
	_roads(view)
	for i in 6:
		var z := 4.0 + i * 18.0
		_hall(view, Vector3(-40, 0, z), 15, 13, 8.0 + float(i % 3) * 1.4)
		_hall(view, Vector3(25, 0, z + 2.0), 15, 13, 7.2 + float((i + 1) % 3) * 1.6)
		_silo(view, Vector3(-19.5, 0, z + 5.0), 2.15, 11.0 + i * 1.4, CYAN if i % 2 == 0 else PINK)
		_silo(view, Vector3(15.5, 0, z + 7.0), 1.7, 9.0 + i, AMBER if i % 2 == 0 else PINK)
		if i == 2 or i == 4:
			_span(view, z + 11.0, 6.4, PINK)
	_tower(view, Vector3(-46, 0, 22), PINK)
	_tower(view, Vector3(44, 0, 26), CYAN)
	_tower(view, Vector3(-46, 0, 78), PINK)
	_tower(view, Vector3(44, 0, 86), AMBER)
	_catwalk(view, 48.0)
	_catwalk(view, 84.0)
	_lights(view)
	_ship(view, Vector3(-46, 0, 96))
	_shaft(view)
	world = _freeze(view, "ScaffoldCity")
	_buggy(view)
	vehicle = _freeze(view, "OpenBuggy")
	_wheel(view)
	var wheel_mesh := _freeze(view, "Wheel")
	remove_child(wheel_mesh)
	for side in [-1.0, 1.0]:
		for z in [-1.45, 1.35]:
			var wheel := MeshInstance3D.new()
			wheel.mesh = wheel_mesh.mesh
			wheel.position = Vector3(side * 1.15, 0.52, z)
			vehicle.add_child(wheel)
			wheels.append(wheel)
	wheel_mesh.free()
	for point in BOTTLE_POSITIONS:
		_bottle(view, point)
		bottles.append(_freeze(view, "AirBottle"))
	_beam(view)
	beam = _freeze(view, "ShaftBeam")
	var beam_material := StandardMaterial3D.new()
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.albedo_color = Color(0.75, 0.95, 1.0, 0.85)
	beam.mesh.surface_set_material(0, beam_material)
	_lamp(view)
	var lamp_mesh := _freeze(view, "Searchlight")
	remove_child(lamp_mesh)
	for side in [-1.0, 1.0]:
		var lamp := Node3D.new()
		lamp.position = Vector3(side * 8.2, 0, 38)
		var head := MeshInstance3D.new()
		head.mesh = lamp_mesh.mesh
		lamp.add_child(head)
		add_child(lamp)
		lamps.append(lamp)
	lamp_mesh.free()
	for lamp in lamps:
		var cone := MeshInstance3D.new()
		cone.mesh = _cone_mesh()
		lamp.add_child(cone)
	initialized = true

func _strut(view: Node, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var direction := b - a
	if direction.length() < 0.05:
		return
	var up := Vector3.FORWARD if absf(direction.normalized().dot(Vector3.UP)) > 0.92 else Vector3.UP
	var right := up.cross(direction).normalized()
	var basis := Basis(right, direction.normalized(), right.cross(direction).normalized())
	view.box(Vector3(-width / 2, 0, -width / 2), Vector3(width, direction.length(), width), color, Transform3D(basis, a))

func _tube(view: Node, a: Vector3, b: Vector3, radius: float, color: Color, ribs := 0) -> void:
	var direction := b - a
	if direction.length() < 0.05:
		return
	var up := Vector3.FORWARD if absf(direction.normalized().dot(Vector3.UP)) > 0.92 else Vector3.UP
	var right := up.cross(direction).normalized()
	var transform := Transform3D(Basis(right, direction.normalized(), right.cross(direction).normalized()), a)
	view._cylinder(Vector3.ZERO, radius, direction.length(), 1, color, transform)
	for i in 4:
		var offset := Vector3(cos(i * PI / 2.0), 0, sin(i * PI / 2.0)) * radius
		view.segment(transform * offset, transform * (offset + Vector3.UP * direction.length()), color * 0.75)
	for i in range(1, ribs + 1):
		view._ring(Vector3(0, direction.length() * i / float(ribs + 1), 0), radius * 1.04, 1, color, transform)

func _roads(view: Node) -> void:
	# Dark deck, bright twin rails. The road is a bridge over the void.
	view.box(Vector3(-5.2, -0.35, -8), Vector3(10.4, 0.28, 128), Color(0.02, 0.04, 0.05))
	view.box(Vector3(-42, -0.38, 32), Vector3(84, 0.28, 10), Color(0.02, 0.04, 0.05))
	for side in [-1.0, 1.0]:
		view.segment(Vector3(side * 4.6, 0.04, -8), Vector3(side * 4.6, 0.04, 118), CYAN)
		view.segment(Vector3(side * 3.9, 0.04, -8), Vector3(side * 3.9, 0.04, 118), CYAN * 0.72)
		view.segment(Vector3(-40, 0.05, 34 + side * 3.6), Vector3(40, 0.05, 34 + side * 3.6), CYAN)
	for z in range(-6, 116, 6):
		if absf(z - 36) > 7:
			view.segment(Vector3(-0.08, 0.05, z), Vector3(-0.08, 0.05, z + 2.2), CYAN * 0.55)
	for z in range(0, 114, 8):
		for side in [-1.0, 1.0]:
			_strut(view, Vector3(side * 5.1, -6.5, z), Vector3(side * 5.1, 0, z), 0.16, CYAN * 0.45)
		view.segment(Vector3(-5.1, -2.2, z), Vector3(5.1, -2.2, z), CYAN * 0.4)
	for x in [-4.6, 4.6]:
		for z in [32.4, 39.6]:
			var center := Vector3(x * 2.2, 0.05, z)
			var previous := center + Vector3(-signf(x) * 4.2, 0, 0)
			for i in range(1, 10):
				var angle := i * PI * 0.5 / 9.0
				var point := center + Vector3(-signf(x) * cos(angle), 0, -signf(z - 36) * sin(angle)) * 4.2
				view.segment(previous, point, CYAN)
				previous = point

func _tower(view: Node, origin: Vector3, color: Color) -> void:
	var heights := [11.0, 16.5, 8.5, 14.0, 6.5, 12.5]
	var offsets := [Vector3(0, 0, 0), Vector3(1.6, 0, 0.4), Vector3(-1.3, 0, 0.8), Vector3(0.5, 0, -1.4), Vector3(-0.4, 0, -0.7), Vector3(1.1, 0, 1.3)]
	for i in heights.size():
		_tube(view, origin + offsets[i], origin + offsets[i] + Vector3.UP * heights[i], 0.28 + (i % 3) * 0.08, color, 3)
	for y in [4.0, 8.0]:
		for i in range(offsets.size() - 1):
			view.segment(origin + offsets[i] + Vector3.UP * y, origin + offsets[i + 1] + Vector3.UP * y, color * 0.8)
	_tube(view, origin + Vector3(-1.3, 6, 0.8), origin + Vector3(4.5, 6, 2.2), 0.16, color)
	_tube(view, origin + Vector3(4.5, 6, 2.2), origin + Vector3(4.5, 2.2, 2.2), 0.16, color)

func _hall(view: Node, p: Vector3, width: float, length: float, height: float) -> void:
	for x in [0.0, width]:
		for z in [0.0, length]:
			_strut(view, p + Vector3(x, 0, z), p + Vector3(x, height, z), 0.2, PINK)
			solids.append(Rect2(Vector2(p.x + x - 0.45, p.z + z - 0.45), Vector2(0.9, 0.9)))
	for y in [height * 0.45, height]:
		view.segment(p + Vector3(0, y, 0), p + Vector3(width, y, 0), PINK)
		view.segment(p + Vector3(width, y, 0), p + Vector3(width, y, length), PINK)
		view.segment(p + Vector3(width, y, length), p + Vector3(0, y, length), PINK)
		view.segment(p + Vector3(0, y, length), p + Vector3(0, y, 0), PINK)
	for i in 4:
		var z := length * i / 3.0
		view.segment(p + Vector3(0, height, z), p + Vector3(width * 0.5, height + 1.6, z), PINK)
		view.segment(p + Vector3(width, height, z), p + Vector3(width * 0.5, height + 1.6, z), PINK)
	for i in 3:
		var x := width * (i + 1) / 4.0
		_tube(view, p + Vector3(x, 0.2, length * 0.35), p + Vector3(x, height * 0.85, length * 0.35), 0.12, CYAN, 2)
		_tube(view, p + Vector3(x, 0.4, length * 0.62), p + Vector3(x, height * 0.7, length * 0.62), 0.09, PINK, 2)
	view.segment(p, p + Vector3(width, height * 0.45, length), PINK * 0.75)
	view.segment(p + Vector3(width, 0, 0), p + Vector3(0, height * 0.45, length), PINK * 0.75)
	view.segment(p + Vector3(0, 0, length), p + Vector3(width, height * 0.45, 0), PINK * 0.75)
	view.segment(p + Vector3(width, 0, length), p + Vector3(0, height * 0.45, 0), PINK * 0.75)
	view.box(p + Vector3(0.4, -0.08, 0.4), Vector3(width - 0.8, 0.08, length - 0.8), Color(0.03, 0.01, 0.03))
	_strut(view, p + Vector3(1.2, 0, -0.05), p + Vector3(1.2, height * 0.72, -0.05), 0.08, AMBER)
	_strut(view, p + Vector3(width - 1.2, 0, -0.05), p + Vector3(width - 1.2, height * 0.72, -0.05), 0.08, AMBER)
	view.segment(p + Vector3(1.2, height * 0.72, 0), p + Vector3(width - 1.2, height * 0.72, 0), AMBER)

func _silo(view: Node, p: Vector3, radius: float, height: float, color: Color) -> void:
	for i in 9:
		var y := height * i / 8.0
		view._ring(p + Vector3.UP * y, radius, 1, color, Transform3D.IDENTITY)
	for i in 10:
		var angle := TAU * i / 10.0
		var edge := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		view.segment(p + edge, p + edge + Vector3.UP * height, color)
	for i in 5:
		var t := i / 4.0
		view._ring(p + Vector3.UP * (height + t * 2.2), radius * (1.0 - t * 0.75), 1, color, Transform3D.IDENTITY)
	for rung in range(0, int(height), 1):
		view.segment(p + Vector3(-0.35, rung, -radius - 0.25), p + Vector3(0.35, rung, -radius - 0.25), color * 0.8)
	solids.append(Rect2(Vector2(p.x - radius, p.z - radius), Vector2(radius * 2, radius * 2)))

func _catwalk(view: Node, z: float) -> void:
	for side in [-1.0, 1.0]:
		_strut(view, Vector3(side * 14, 0, z), Vector3(side * 14, 5.2, z), 0.16, PINK)
		view.segment(Vector3(-14, 5.2, z + side * 0.7), Vector3(14, 5.2, z + side * 0.7), PINK)
		view.segment(Vector3(-14, 6.3, z + side * 0.7), Vector3(14, 6.3, z + side * 0.7), CYAN * 0.8)
	for x in range(-12, 14, 2):
		view.segment(Vector3(x, 5.2, z - 0.7), Vector3(x, 5.2, z + 0.7), PINK * 0.7)

func _span(view: Node, z: float, y: float, color: Color) -> void:
	_tube(view, Vector3(-22, y, z), Vector3(22, y, z), 0.16, color, 5)
	_tube(view, Vector3(-22, y - 0.9, z + 0.6), Vector3(22, y - 0.9, z + 0.6), 0.1, CYAN, 3)
	for x in [-18.0, -6.0, 6.0, 18.0]:
		view.segment(Vector3(x, y, z), Vector3(x, y - 0.9, z + 0.6), color * 0.8)

func _lights(view: Node) -> void:
	for side in [-1.0, 1.0]:
		_tube(view, Vector3(side * 8.2, 0, 38), Vector3(side * 8.2, 3.2, 38), 0.35, PINK, 2)
		view._ring(Vector3(side * 8.2, 3.3, 38), 0.7, 1, AMBER, Transform3D.IDENTITY)

func _lamp(view: Node) -> void:
	for i in 4:
		var t := i / 3.0
		view._ring(Vector3(0, 3.4 + t * 14.0, 0), lerpf(0.45, 5.8, t), 1, PINK, Transform3D.IDENTITY)

func _cone_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var apex := Vector3(0, 3.3, 0)
	for i in 20:
		var a := TAU * i / 20.0
		var b := TAU * (i + 1) / 20.0
		vertices.append(apex)
		vertices.append(Vector3(cos(a) * 5.6, 17.2, sin(a) * 5.6))
		vertices.append(Vector3(cos(b) * 5.6, 17.2, sin(b) * 5.6))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(1.0, 0.12, 0.62, 0.16)
	mesh.surface_set_material(0, material)
	return mesh

func _ship(view: Node, p: Vector3) -> void:
	var nose := p + Vector3(0, 2.2, -8)
	var tail := p + Vector3(0, 2.4, 7)
	view.segment(nose, p + Vector3(-2.2, 1.2, -2), CYAN)
	view.segment(nose, p + Vector3(2.2, 1.2, -2), CYAN)
	view.segment(nose, p + Vector3(0, 3.4, -2), CYAN)
	for y in [1.2, 3.4]:
		view.segment(p + Vector3(-2.4, y, -2), p + Vector3(2.4, y, -2), CYAN)
		view.segment(p + Vector3(-2.4, y, -2), p + Vector3(-2.2, y, 6), CYAN)
		view.segment(p + Vector3(2.4, y, -2), p + Vector3(2.2, y, 6), CYAN)
	view.segment(p + Vector3(-2.2, 1.2, 6), tail, CYAN)
	view.segment(p + Vector3(2.2, 1.2, 6), tail, CYAN)
	view.segment(p + Vector3(0, 3.4, 6), tail + Vector3(0, 0.4, 0), CYAN)
	for side in [-1.0, 1.0]:
		_tube(view, p + Vector3(side * 3.3, 2.2, -1), p + Vector3(side * 3.3, 2.2, 5), 0.55, CYAN, 3)

func _shaft(view: Node) -> void:
	var center := Vector3(0, 0, 112)
	for i in 24:
		var a := TAU * i / 24.0
		var b := TAU * (i + 1) / 24.0
		view.segment(center + Vector3(cos(a), 0, sin(a)) * 4.2, center + Vector3(cos(b), 0, sin(b)) * 4.2, WHITE)
		view.segment(center + Vector3(cos(a), 0, sin(a)) * 6.4, center + Vector3(cos(b), 0, sin(b)) * 6.4, CYAN)
	solids.append(Rect2(-4.2, 107.8, 8.4, 8.4))

func _beam(view: Node) -> void:
	_tube(view, Vector3(0, 0, 112), Vector3(0, 42, 112), 0.35, WHITE, 4)

func _bottle(view: Node, origin: Vector3, yaw := 0.0) -> void:
	var transform := Transform3D(Basis(Vector3.UP, yaw), origin)
	for i in 8:
		view._ring(Vector3(i * 0.36, 0.55, 0), 0.34, 0, PINK, transform)
	for i in 6:
		var angle := TAU * i / 6.0
		view.segment(transform * Vector3(0, 0.55 + cos(angle) * 0.34, sin(angle) * 0.34), transform * Vector3(2.5, 0.55 + cos(angle) * 0.34, sin(angle) * 0.34), PINK * 0.7)
	view._cylinder(Vector3(-0.55, 0.55, 0), 0.14, 0.7, 0, CYAN, transform)
	view._ring(Vector3(-0.55, 0.55, 0), 0.22, 0, CYAN, transform)
	view._cylinder(Vector3(-0.35, 0.18, 0), 0.09, 0.32, 1, AMBER, transform)
	view._ring(Vector3(-0.35, 0.18, 0), 0.16, 1, AMBER, transform)

func _buggy(view: Node) -> void:
	var cage := [Vector3(-0.75, 0.45, 1.7), Vector3(0.75, 0.45, 1.7), Vector3(0.7, 1.15, 0.35), Vector3(-0.7, 1.15, 0.35), Vector3(-0.85, 0.5, -1.6), Vector3(0.85, 0.5, -1.6)]
	view.segment(cage[0], cage[1], PINK)
	view.segment(cage[1], cage[2], PINK)
	view.segment(cage[2], cage[3], PINK)
	view.segment(cage[3], cage[0], PINK)
	view.segment(cage[4], cage[5], PINK)
	view.segment(cage[0], cage[4], PINK)
	view.segment(cage[1], cage[5], PINK)
	view.segment(cage[3], cage[4], PINK)
	view.segment(cage[2], cage[5], PINK)
	view.segment(Vector3(-0.7, 1.15, 0.35), Vector3(-0.55, 1.55, -0.4), PINK)
	view.segment(Vector3(0.7, 1.15, 0.35), Vector3(0.55, 1.55, -0.4), PINK)
	view.segment(Vector3(-0.55, 1.55, -0.4), Vector3(0.55, 1.55, -0.4), CYAN)
	for side in [-1.0, 1.0]:
		for z in [-1.45, 1.35]:
			_tube(view, Vector3(side * 0.35, 0.85, z * 0.55), Vector3(side * 1.05, 0.52, z), 0.055, CYAN)
			for rib in 7:
				var t := rib / 6.0
				var point := Vector3(side * lerpf(0.35, 1.05, t), lerpf(0.85, 0.52, t), lerpf(z * 0.55, z, t))
				view._ring(point, 0.1, 1, PINK, Transform3D.IDENTITY)
	_bottle(view, Vector3(0, 0.15, -0.15), PI / 2.0)
	for side in [-1.0, 1.0]:
		view.segment(Vector3(0, 0.7, -0.2), Vector3(side * 1.05, 0.52, -1.45), CYAN)
		view.segment(Vector3(0, 0.7, -0.2), Vector3(side * 1.05, 0.52, 1.35), CYAN)

func _wheel(view: Node) -> void:
	view._cylinder(Vector3(-0.16, 0, 0), 0.52, 0.32, 0, PINK, Transform3D.IDENTITY)
	for x in [-0.17, 0.17]:
		view._ring(Vector3(x, 0, 0), 0.36, 0, CYAN, Transform3D.IDENTITY, true)

func blocked(point: Vector2, radius: float) -> bool:
	if point.x < -48 + radius or point.x > 48 - radius or point.y < -6 + radius or point.y > 124 - radius:
		return true
	for rect in solids:
		if rect.grow(radius).has_point(point):
			return true
	return false

func move_distance(distance: float) -> void:
	var delta := Vector2(sin(heading), cos(heading)) * distance
	var steps := maxi(1, ceili(delta.length() / 0.25))
	var radius := 1.35 if driving else 0.35
	for i in steps:
		var step := delta / steps
		var x := position_xz + Vector2(step.x, 0)
		if not blocked(x, radius):
			position_xz = x
		var z := position_xz + Vector2(0, step.y)
		if not blocked(z, radius):
			position_xz = z

func interact_vehicle() -> void:
	if inspection != 0:
		inspection = 0
	if driving:
		for side in [1.0, -1.0]:
			var exit_position: Vector2 = buggy_position + Vector2(cos(heading), -sin(heading)) * float(side) * 2.4
			if not blocked(exit_position, 0.35):
				driving = false
				velocity = 0
				position_xz = exit_position
				return
	elif position_xz.distance_to(buggy_position) < 3.6:
		driving = true
		position_xz = buggy_position
		heading = buggy_heading
		velocity = 0

func collect_bottle() -> void:
	if driving:
		return
	for i in bottles.size():
		var point: Vector3 = BOTTLE_POSITIONS[i]
		if bottles[i].visible and position_xz.distance_to(Vector2(point.x, point.z)) < 2.4:
			bottles[i].visible = false
			collected += 1
			return

func tick(delta: float, view: Node) -> void:
	if view.menu_tap(KEY_V):
		inspection = (inspection + 1) % 3
	if view.menu_tap(KEY_F):
		interact_vehicle()
	if view.menu_tap(KEY_E):
		collect_bottle()
	if inspection != 0:
		return
	var turn := float(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))
	turn -= float(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	var throttle := float(Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	throttle -= float(Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
	heading += turn * delta * (1.25 if driving else 1.7)
	steering = move_toward(steering, turn * 0.35 if driving else 0.0, delta * 2)
	if driving:
		velocity = move_toward(velocity, throttle * (16 if throttle > 0 else 6), delta * (7 if throttle != 0 else 5))
		var before := position_xz
		move_distance(velocity * delta)
		if delta > 0 and position_xz.distance_to(before) < absf(velocity * delta) * 0.2:
			velocity = 0
		buggy_position = position_xz
		buggy_heading = heading
		wheel_angle += velocity * delta / 0.52
	else:
		move_distance(throttle * 4.2 * delta)

func render(view: Node, time: float, distance: float) -> Texture2D:
	if not initialized:
		build(view)
	vehicle.position = Vector3(buggy_position.x, 0, buggy_position.y)
	vehicle.rotation.y = buggy_heading
	vehicle.visible = not driving or inspection != 0
	for wheel in wheels:
		wheel.rotation.x = wheel_angle
		wheel.rotation.y = steering if wheel.position.z > 0 else 0
	for i in lamps.size():
		lamps[i].rotation.y = sin(time * 0.35 + i) * 0.35
	beam.scale = Vector3(1, 1 + sin(time * 2.2) * 0.08, 1)
	if inspection == 1:
		return view.present(46, 42, -16, -0.62, -0.48, maxf(distance, 240))
	if inspection == 2:
		return view.present(buggy_position.x + 5, 2.4, buggy_position.y + 6, -2.5, -0.22, maxf(distance, 80))
	return view.present(position_xz.x, 1.7 if driving else 1.65, position_xz.y, heading, -0.08, distance)
