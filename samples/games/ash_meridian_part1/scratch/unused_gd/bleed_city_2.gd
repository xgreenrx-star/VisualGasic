extends Node3D

const CYAN := Color(0.12, 0.92, 1.0)
const PINK := Color(1.0, 0.20, 0.74)
const AMBER := Color(1.0, 0.61, 0.13)
const WHITE := Color(0.78, 0.96, 1.0)
const BOTTLE_POSITIONS := [Vector3(7, 0.5, 29), Vector3(-8, 0.5, 68), Vector3(31, 0.5, 49)]

var position_xz := Vector2(5, 9)
var heading := -0.18
var velocity := 0.0
var driving := false
var inspection := 0
var buggy_position := Vector2(0, 18)
var buggy_heading := 0.0
var collected := 0
var solids: Array[Rect2] = []
var bottles: Array[MeshInstance3D] = []
var wheels: Array[Node3D] = []
var vehicle: MeshInstance3D
var world: MeshInstance3D
var beam: MeshInstance3D
var initialized := false
var wheel_angle := 0.0
var steering := 0.0
var camera_position := Vector3.ZERO
var camera_heading := 0.0
var camera_pitch := -0.08
var neon: ShaderMaterial

func reset() -> void:
	position_xz = Vector2(5, 9)
	heading = -0.18
	velocity = 0
	driving = false
	inspection = 0
	buggy_position = Vector2(0, 18)
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
		neon.set_shader_parameter("line_width", 1.05)
		var halo: ShaderMaterial = view.line_material.next_pass.duplicate()
		halo.set_shader_parameter("line_width", 4.5)
		neon.next_pass = halo
	if instance.mesh.get_surface_count() == 2:
		instance.mesh.surface_set_material(1, neon)
	view.vertices.clear()
	view.colors.clear()
	view.edges.clear()
	view.edge_colors.clear()
	add_child(instance)
	return instance

func build(view: Node) -> void:
	_roads(view)
	_hall(view, Vector3(-31, 0, 12), 16, 24, 9, false)
	_hall(view, Vector3(15, 0, 15), 18, 22, 11, true)
	_hall(view, Vector3(-34, 0, 61), 19, 24, 12, true)
	_hall(view, Vector3(16, 0, 63), 18, 22, 8, false)
	_hall(view, Vector3(-31, 0, 117), 16, 23, 10, false)
	_hall(view, Vector3(16, 0, 119), 18, 22, 10, true)
	for side in [-1.0, 1.0]:
		for z in [22.0, 73.0, 129.0]:
			_refinery(view, Vector3(side * 46, 0, z), 2.8, 16 + fmod(z, 9), PINK)
			_refinery(view, Vector3(side * 52, 0, z + 8), 2.2, 12, AMBER if z > 100 else PINK)
			_pipe(view, [Vector3(side * 46, 14, z), Vector3(side * 39, 14, z),
				Vector3(side * 39, 6, z), Vector3(side * 31, 6, z)], 0.38, PINK)
			for dz in [0.0, 5.0, 10.0]:
				_frame(view, Vector3(side * 40, 0, z + dz), 3.5, 9)
	_catwalk(view, Vector3(-40, 7, 43), Vector3(40, 7, 43), AMBER)
	_catwalk(view, Vector3(-39, 8, 93), Vector3(39, 8, 93), PINK)
	_shaft(view)
	_crane(view, Vector3(38, 0, 108))
	_dock(view, Vector3(-46, 0, 100))
	for x in [-22.0, -14.0]:
		_refinery(view, Vector3(x, 0, 149), 3, 23, AMBER)
	world = _freeze(view, "DistrictGeometry")
	_buggy(view)
	vehicle = _freeze(view, "AirBuggy")
	_wheel(view)
	var wheel_mesh := _freeze(view, "WheelPrototype")
	remove_child(wheel_mesh)
	for side in [-1.0, 1.0]:
		for z in [-1.35, 1.4]:
			var wheel := MeshInstance3D.new()
			wheel.mesh = wheel_mesh.mesh
			wheel.position = Vector3(side * 1.12, 0.59, z)
			vehicle.add_child(wheel)
			wheels.append(wheel)
	wheel_mesh.free()
	for point in BOTTLE_POSITIONS:
		_bottle(view, Transform3D(Basis.IDENTITY, point), 0.65)
		bottles.append(_freeze(view, "AirBottle"))
	_beam(view)
	beam = _freeze(view, "ShaftLight")
	var beam_material := StandardMaterial3D.new()
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.albedo_color = WHITE
	beam.mesh.surface_set_material(0, beam_material)
	initialized = true

func _road_strip(view: Node, center: Vector3, width: float, length: float, across := false) -> void:
	var size := Vector3(width, 0.28, length)
	if across:
		size = Vector3(length, 0.28, width)
	view.box(center - size * Vector3(0.5, 0, 0.5) - Vector3(0, 0.3, 0), size, CYAN * 0.27)
	for side in [-1.0, 1.0]:
		for rail in [width * 0.5 - 0.1, width * 0.5 - 0.45]:
			var a := Vector3(side * rail, 0.015, -length * 0.5)
			var b := Vector3(side * rail, 0.015, length * 0.5)
			if across:
				a = Vector3(a.z, a.y, a.x)
				b = Vector3(b.z, b.y, b.x)
			view.segment(center + a, center + b, CYAN)

func _roads(view: Node) -> void:
	# Separate strips leave the junction interiors clear of crossing edge lines.
	for x in [-36.0, 0.0, 36.0]:
		for span in [Vector2(-12, 42), Vector2(54, 94), Vector2(106, 155)]:
			if x == 0 and span.x == 106:
				_road_strip(view, Vector3(0, 0, 136), 12, 38)
			elif x == 0 and span.x == 54:
				_road_strip(view, Vector3(0, 0, 70), 12, 32)
			else:
				_road_strip(view, Vector3(x, 0, (span.x + span.y) / 2), 12, span.y - span.x)
	for z in [48.0, 100.0]:
		if z == 100:
			for span in [Vector2(-42, -9), Vector2(9, 42)]:
				_road_strip(view, Vector3((span.x + span.y) / 2, -0.025, z), 12, span.y - span.x, true)
		else:
			_road_strip(view, Vector3(0, -0.025, z), 12, 84, true)
		for x in [-36.0, 0.0, 36.0]:
			for side in [-1.0, 1.0]:
				for end in [-1.0, 1.0]:
					var center := Vector3(x + side * 9, 0.03, z + end * 9)
					for inset in [0.0, 0.3]:
						var previous := center + Vector3(-side * (3 + inset), 0, 0)
						for i in range(1, 13):
							var angle := i * PI * 0.5 / 12
							var point: Vector3 = center + Vector3(-side * cos(angle), 0, -end * sin(angle)) * (3 + inset)
							view.segment(previous, point, CYAN)
							previous = point
	for z in range(-8, 150, 5):
		if absf(z - 48) > 8 and absf(z - 100) > 14:
			view.segment(Vector3(-0.1, 0.02, z), Vector3(-0.1, 0.02, z + 2), CYAN * 0.5)
	for z in range(4, 150, 20):
		for x in [-6.8, 6.8]:
			view.box(Vector3(x - 0.2, 0, z), Vector3(0.4, 0.65, 0.4), AMBER)
	# Piers and service ducts make the roadway a structure suspended in the void.
	for x in [-36.0, 0.0, 36.0]:
		for z in range(0, 150, 12):
			for side in [-1.0, 1.0]:
				view.box(Vector3(x + side * 5 - 0.12, -7, z), Vector3(0.24, 6.7, 0.24), CYAN * 0.35)
			view.segment(Vector3(x - 5, -1.8, z), Vector3(x + 5, -1.8, z), CYAN * 0.4)
		_pipe(view, [Vector3(x - 4.5, -0.7, -10), Vector3(x - 4.5, -0.7, 86)], 0.18, CYAN * 0.6)

func _strut(view: Node, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var direction := b - a
	var up := Vector3.FORWARD if absf(direction.normalized().dot(Vector3.UP)) > 0.95 else Vector3.UP
	var right := up.cross(direction).normalized()
	var basis := Basis(right, direction.normalized(), right.cross(direction).normalized())
	view.box(Vector3(-width / 2, 0, -width / 2), Vector3(width, direction.length(), width), color, Transform3D(basis, a))

func _frame(view: Node, origin: Vector3, width: float, height: float) -> void:
	for side in [-1.0, 1.0]:
		_strut(view, origin + Vector3(side * width / 2, 0, 0), origin + Vector3(side * width / 2, height, 0), 0.18, PINK)
	for y in [0.3, height * 0.5, height]:
		_strut(view, origin + Vector3(-width / 2, y, 0), origin + Vector3(width / 2, y, 0), 0.16, PINK)
	for level in 2:
		var y := level * height / 2
		view.segment(origin + Vector3(-width / 2, y, 0), origin + Vector3(width / 2, y + height / 2, 0), PINK)
		view.segment(origin + Vector3(width / 2, y, 0), origin + Vector3(-width / 2, y + height / 2, 0), PINK)

func _hall(view: Node, p: Vector3, width: float, length: float, height: float, sawtooth: bool) -> void:
	# An open doorway has actual side walls and a lintel, not a filled front plane.
	solids.append(Rect2(Vector2(p.x, p.z), Vector2(0.5, length)))
	solids.append(Rect2(Vector2(p.x + width - 0.5, p.z), Vector2(0.5, length)))
	solids.append(Rect2(Vector2(p.x, p.z + length - 0.5), Vector2(width, 0.5)))
	view.box(p, Vector3(0.35, height, length), PINK)
	view.box(p + Vector3(width - 0.35, 0, 0), Vector3(0.35, height, length), PINK)
	view.box(p + Vector3(0, 0, length - 0.35), Vector3(width, height, 0.35), PINK)
	view.box(p + Vector3(0, height - 2, 0), Vector3(width, 2, 0.4), PINK)
	for x in [0.0, width]:
		for z in range(0, int(length) + 1, 4):
			_strut(view, p + Vector3(x, 0, z), p + Vector3(x, height, z), 0.22, PINK)
			view.segment(p + Vector3(x, height * 0.45, z), p + Vector3(x, height, minf(z + 4, length)), PINK * 0.7)
	for z in range(0, int(length), 6):
		var crest := height + (2.8 if sawtooth else 1.5)
		var a := p + Vector3(0, height, z)
		var b := p + Vector3(width, height, z)
		var peak := p + Vector3(width * (0.8 if sawtooth else 0.5), crest, z)
		for offset in [0.0, 6.0]:
			view.segment(a + Vector3(0, 0, offset), peak + Vector3(0, 0, offset), PINK)
			view.segment(b + Vector3(0, 0, offset), peak + Vector3(0, 0, offset), PINK)
		view.face(a, peak, peak + Vector3(0, 0, 6), a + Vector3(0, 0, 6), PINK * 0.8)
		view.face(peak, b, b + Vector3(0, 0, 6), peak + Vector3(0, 0, 6), PINK * 0.8)
	view.box(p + Vector3(0.5, -0.15, 0.5), Vector3(width - 1, 0.15, length - 1), CYAN * 0.35)
	for x in [width * 0.2, width * 0.8]:
		_bottle(view, Transform3D(Basis.IDENTITY, p + Vector3(x, 0.8, length * 0.65)), 1.2)
	# Door portal is amber; the rest of the structure remains magenta.
	_strut(view, p + Vector3(1, 0, 0.05), p + Vector3(1, height - 2, 0.05), 0.1, AMBER)
	_strut(view, p + Vector3(width - 1, 0, 0.05), p + Vector3(width - 1, height - 2, 0.05), 0.1, AMBER)

func _tube(view: Node, a: Vector3, b: Vector3, radius: float, color: Color, ribs := 0) -> void:
	var direction := b - a
	var up := Vector3.FORWARD if absf(direction.normalized().dot(Vector3.UP)) > 0.95 else Vector3.UP
	var right := up.cross(direction).normalized()
	var basis := Basis(right, direction.normalized(), right.cross(direction).normalized())
	var transform := Transform3D(basis, a)
	view._cylinder(Vector3.ZERO, radius, direction.length(), 1, color, transform)
	for i in 4:
		var offset := Vector3(cos(i * PI / 2), 0, sin(i * PI / 2)) * radius
		view.segment(transform * offset, transform * (offset + Vector3.UP * direction.length()), color * 0.65)
	for i in range(1, ribs + 1):
		view._ring(Vector3(0, direction.length() * i / (ribs + 1), 0), radius * 1.025, 1, color, transform)

func _pipe(view: Node, points: Array, radius: float, color: Color) -> void:
	for i in range(points.size() - 1):
		_tube(view, points[i], points[i + 1], radius, color)
		view._ring(Vector3.ZERO, radius * 1.18, 1, color, Transform3D(Basis.IDENTITY, points[i]))

func _refinery(view: Node, p: Vector3, radius: float, height: float, color: Color) -> void:
	_tube(view, p + Vector3.UP * 2, p + Vector3.UP * height, radius, color, 6)
	for y in [2.0, height * 0.55, height]:
		view._ring(p + Vector3.UP * y, radius + 0.25, 1, color, Transform3D.IDENTITY)
	for i in 12:
		var angle := TAU * i / 12
		var edge := p + Vector3(cos(angle) * radius, height, sin(angle) * radius)
		var next := p + Vector3(cos(angle + TAU / 12) * radius, height, sin(angle + TAU / 12) * radius)
		view.face(edge, next, p + Vector3.UP * (height + 1.5), p + Vector3.UP * (height + 1.5), color * 0.7)
	for side in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			view.box(p + Vector3(side * radius * 0.65 - 0.12, 0, z * radius * 0.65 - 0.12), Vector3(0.24, 2, 0.24), color)
	for rung in range(1, int(height * 2)):
		var y := rung * 0.5
		view.segment(p + Vector3(-0.4, y, -radius - 0.3), p + Vector3(0.4, y, -radius - 0.3), color)
	for x in [-0.4, 0.4]:
		view.segment(p + Vector3(x, 0.2, -radius - 0.3), p + Vector3(x, height, -radius - 0.3), color)
	solids.append(Rect2(Vector2(p.x - radius, p.z - radius), Vector2.ONE * radius * 2))

func _catwalk(view: Node, a: Vector3, b: Vector3, color: Color) -> void:
	view.box(a + Vector3(0, -0.25, -0.7), Vector3(b.x - a.x, 0.25, 1.4), color * 0.65)
	for side in [-1.0, 1.0]:
		view.segment(a + Vector3(0, 1, side * 0.7), b + Vector3(0, 1, side * 0.7), color)
		for x in range(int(a.x), int(b.x) + 1, 2):
			view.segment(Vector3(x, a.y, a.z + side * 0.7), Vector3(x, a.y + 1, a.z + side * 0.7), color)
	for x in [-12.0, 12.0]:
		_strut(view, Vector3(x, 0, a.z), Vector3(x, a.y, a.z), 0.22, color)

func _shaft(view: Node) -> void:
	var center := Vector3(0, -0.1, 100)
	for i in 48:
		var a := TAU * i / 48
		var b := TAU * (i + 1) / 48
		var p := Vector3(cos(a), 0, sin(a))
		var q := Vector3(cos(b), 0, sin(b))
		view.face(center + p * 9, center + q * 9, center + q * 6, center + p * 6, CYAN)
		view.face(center + p * 6, center + q * 6, center + q * 6 - Vector3.UP * 5, center + p * 6 - Vector3.UP * 5, CYAN * 0.6)
		if i % 3 == 0:
			view.segment(center + p * 8.5, center + p * 8.5 + Vector3.UP, CYAN)
			view.segment(center + p * 8.5 + Vector3.UP, center + q * 8.5 + Vector3.UP, CYAN)
	solids.append(Rect2(-6, 94, 12, 12))
	for z in [91.0, 109.0]:
		_road_strip(view, Vector3(0, 0, z), 3, 24, true)

func _beam(view: Node) -> void:
	_tube(view, Vector3(0, -4, 100), Vector3(0, 64, 100), 0.48, WHITE)
	for i in 8:
		var angle := i * TAU / 8
		var offset := Vector3(cos(angle), 0, sin(angle)) * (0.9 + i * 0.15)
		view.segment(Vector3(0, 0, 100) + offset, Vector3(0, 58 - i * 3, 100) + offset, WHITE * 0.65)
	view._ring(Vector3(0, 0.05, 100), 5.5, 1, WHITE, Transform3D.IDENTITY)

func _crane(view: Node, p: Vector3) -> void:
	_frame(view, p, 4, 13)
	_strut(view, p + Vector3(0, 13, 0), p + Vector3(-20, 15, 0), 0.4, AMBER)
	view.segment(p + Vector3(0, 16, 0), p + Vector3(-20, 15, 0), AMBER)
	_tube(view, p + Vector3(-19, 15, 0), p + Vector3(-19, 3, 0), 0.035, AMBER)
	view._ring(p + Vector3(-19, 3, 0), 0.5, 0, AMBER, Transform3D.IDENTITY)
	view.box(p + Vector3(-2, 10, -1.5), Vector3(3, 2, 3), AMBER)

func _dock(view: Node, p: Vector3) -> void:
	view.box(p + Vector3(-8, -0.5, -10), Vector3(16, 0.5, 21), CYAN * 0.45)
	solids.append(Rect2(Vector2(p.x - 5, p.z - 7), Vector2(10, 14)))
	# A tapered, closed hull with a raised canopy and paired engine pods.
	var outline := PackedVector2Array([Vector2(-1.1, 0.7), Vector2(-4.2, 0.8),
		Vector2(-4.2, 2), Vector2(-2.1, 3), Vector2(2.1, 3), Vector2(4.2, 2),
		Vector2(4.2, 0.8), Vector2(1.1, 0.7)])
	view._extrude(outline, 10, CYAN, Transform3D(Basis.IDENTITY, p + Vector3(0, 0, -5)))
	view.box(p + Vector3(-1.6, 2.7, -1), Vector3(3.2, 1.3, 4), CYAN)
	for side in [-1.0, 1.0]:
		_tube(view, p + Vector3(side * 4.3, 2, -6), p + Vector3(side * 4.3, 2, 4), 1, CYAN, 4)
		_tube(view, p + Vector3(side * 4.3, 2, -6.05), p + Vector3(side * 4.3, 2, -5.9), 0.65, AMBER)
		_strut(view, p + Vector3(side * 2.5, 0, -4), p + Vector3(side * 2.5, 1, -4), 0.2, CYAN)

func _bottle(view: Node, transform: Transform3D, scale: float) -> void:
	var shaped := transform.scaled_local(Vector3.ONE * scale)
	var profile := PackedVector2Array([Vector2(0, 0.1), Vector2(0.28, 0.12),
		Vector2(0.42, 0.28), Vector2(0.42, 1.4), Vector2(0.30, 1.62),
		Vector2(0.12, 1.77), Vector2(0, 1.77)])
	for i in 24:
		var angle := TAU * i / 24
		var next := TAU * (i + 1) / 24
		for j in range(profile.size() - 1):
			var a := Vector3(cos(angle) * profile[j].x, profile[j].y, sin(angle) * profile[j].x)
			var b := Vector3(cos(next) * profile[j].x, profile[j].y, sin(next) * profile[j].x)
			var c := Vector3(cos(next) * profile[j + 1].x, profile[j + 1].y, sin(next) * profile[j + 1].x)
			var d := Vector3(cos(angle) * profile[j + 1].x, profile[j + 1].y, sin(angle) * profile[j + 1].x)
			for point in [a, b, c, a, c, d]:
				view.vertices.append(shaped * point)
				view.colors.append(Color(0.016, 0.005, 0.014))
			if i % 6 == 0:
				view.segment(shaped * a, shaped * d, PINK * 0.65)
	view._cylinder(Vector3(0, 1.77, 0), 0.12, 0.3, 1, CYAN, shaped)
	for y in [0.3, 0.42, 1.3, 1.4]:
		view._ring(Vector3(0, y, 0), 0.45, 1, PINK, shaped)
	view._cylinder(Vector3(-0.3, 1.91, 0), 0.14, 0.6, 0, CYAN, shaped)
	view._ring(Vector3(0.36, 1.72, 0), 0.19, 0, AMBER, shaped)

func _buggy(view: Node) -> void:
	view.box(Vector3(-0.7, 0.44, -1.7), Vector3(1.4, 0.2, 3.4), PINK)
	view.box(Vector3(-0.6, 0.7, -0.5), Vector3(1.2, 0.5, 1.2), CYAN * 0.6)
	for side in [-1.0, 1.0]:
		var points := [Vector3(side * 0.7, 0.65, 1.7), Vector3(side * 0.7, 1.5, 0.75),
			Vector3(side * 0.65, 1.6, -0.65), Vector3(side * 0.8, 0.7, -1.55)]
		_pipe(view, points, 0.055, PINK)
		_strut(view, points[0], points[3], 0.08, PINK)
		_strut(view, points[1], points[3], 0.065, PINK)
		for z in [-1.35, 1.4]:
			_tube(view, Vector3(side * 0.48, 0.95, z * 0.8), Vector3(side * 1.05, 0.5, z), 0.07, CYAN)
			for rib in 9:
				var t := rib / 8.0
				var p := Vector3(side * lerpf(0.48, 1.05, t), lerpf(0.95, 0.5, t), lerpf(z * 0.8, z, t))
				view._ring(p, 0.12, 1, PINK, Transform3D.IDENTITY)
			_pipe(view, [Vector3(0, 1.3, -1.25), Vector3(side * 0.6, 1.3, -1.4), Vector3(side * 1.0, 0.65, z)], 0.025, CYAN)
	for z in [-0.65, 0.75]:
		_tube(view, Vector3(-0.7, 1.55, z), Vector3(0.7, 1.55, z), 0.055, PINK)
	_bottle(view, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 1, -1.0)), 0.65)
	for x in [-0.38, 0.38]:
		view.box(Vector3(x - 0.2, 0.65, -0.4), Vector3(0.4, 0.65, 0.5), PINK * 0.55)
		_tube(view, Vector3(x, 0.8, 1.6), Vector3(x, 0.8, 1.72), 0.16, AMBER)
	view._ring(Vector3(-0.38, 1.05, 0.8), 0.21, 1, CYAN, Transform3D.IDENTITY)
	view.box(Vector3(-0.76, 0.45, 1.7), Vector3(1.52, 0.12, 0.12), CYAN)

func _wheel(view: Node) -> void:
	view._cylinder(Vector3(-0.2, 0, 0), 0.55, 0.4, 0, PINK, Transform3D.IDENTITY)
	for x in [-0.21, 0.21]:
		view._ring(Vector3(x, 0, 0), 0.39, 0, CYAN, Transform3D.IDENTITY, true)
		view._ring(Vector3(x, 0, 0), 0.14, 0, CYAN, Transform3D.IDENTITY)
	for i in 16:
		var angle := i * TAU / 16
		view.segment(Vector3(-0.2, cos(angle) * 0.55, sin(angle) * 0.55),
			Vector3(0.2, cos(angle + 0.1) * 0.55, sin(angle + 0.1) * 0.55), PINK * 0.5)

func blocked(point: Vector2, radius: float) -> bool:
	if point.x < -58 + radius or point.x > 58 - radius or point.y < -12 + radius or point.y > 154 - radius:
		return true
	for rect in solids:
		if rect.grow(radius).has_point(point):
			return true
	return false

func move_distance(distance: float) -> void:
	var delta := Vector2(sin(heading), cos(heading)) * distance
	var steps := maxi(1, ceili(delta.length() / 0.25))
	var radius := 1.4 if driving else 0.35
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
			var exit_position: Vector2 = buggy_position + Vector2(cos(heading), -sin(heading)) * side * 2.5
			if not blocked(exit_position, 0.35):
				driving = false
				velocity = 0
				position_xz = exit_position
				return
	elif position_xz.distance_to(buggy_position) < 3.8:
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
	heading += turn * delta * (1.3 if driving else 1.7)
	steering = move_toward(steering, turn * 0.4 if driving else 0.0, delta * 2)
	if driving:
		velocity = move_toward(velocity, throttle * (18 if throttle > 0 else 6), delta * (7 if throttle != 0 else 5))
		var before := position_xz
		move_distance(velocity * delta)
		if delta > 0 and position_xz.distance_to(before) < absf(velocity * delta) * 0.2:
			velocity = 0
		buggy_position = position_xz
		buggy_heading = heading
		wheel_angle += velocity * delta / 0.55
	else:
		move_distance(throttle * 4.5 * delta)

func render(view: Node, time: float, distance: float) -> Texture2D:
	if not initialized:
		build(view)
	vehicle.position = Vector3(buggy_position.x, 0, buggy_position.y)
	vehicle.rotation.y = buggy_heading
	vehicle.visible = not driving or inspection != 0
	for wheel in wheels:
		wheel.rotation.x = wheel_angle
		wheel.rotation.y = steering if wheel.position.z > 0 else 0
	beam.scale.x = 1 + sin(time * 2) * 0.05
	if inspection == 1:
		camera_position = Vector3(52, 43, -12)
		camera_heading = -0.59
		camera_pitch = -0.45
	elif inspection == 2:
		camera_position = Vector3(buggy_position.x + 4.5, 3.2, buggy_position.y + 5)
		camera_heading = -2.4
		camera_pitch = -0.3
	else:
		camera_position = Vector3(position_xz.x, 1.65, position_xz.y)
		camera_heading = heading
		camera_pitch = -0.06
	return view.present(camera_position.x, camera_position.y, camera_position.z,
		camera_heading, camera_pitch, distance if inspection == 0 else maxf(distance, 220))
