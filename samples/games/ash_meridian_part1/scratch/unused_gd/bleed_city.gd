extends Node

const CYAN := Color(0.15, 0.95, 1.0)
const PINK := Color(1.0, 0.22, 0.78)
const AMBER := Color(1.0, 0.62, 0.12)
const BEAM := Color(0.82, 0.95, 1.0)

func build(view: Node) -> void:
	_road(view)
	_hall(view, Vector3(-22, 0, 6), Vector3(10, 7, 8))
	_hall(view, Vector3(-24, 0, 22), Vector3(12, 9, 10))
	_hall(view, Vector3(-20, 0, 42), Vector3(9, 6, 14))
	_hall(view, Vector3(-26, 0, 64), Vector3(14, 11, 12))
	_hall(view, Vector3(12, 0, 8), Vector3(11, 8, 9))
	_hall(view, Vector3(14, 0, 28), Vector3(8, 5, 16))
	_hall(view, Vector3(10, 0, 52), Vector3(13, 10, 11))
	_pipes(view)
	_silo(view, Vector3(22, 0, 70), 2.2, 14.0)
	_silo(view, Vector3(28, 0, 78), 1.5, 9.0)
	_catwalk(view, 48.0)
	_bottle(view, Vector3(5.5, 0.4, 24))
	_buggy(view, Vector3(0, 0, 18))
	_beam(view, Vector3(0, 0, 110))

func _road(view: Node) -> void:
	for side in [-1.0, 1.0]:
		for lane in [1.35, 2.15]:
			view.segment(Vector3(side * lane, 0.05, -6), Vector3(side * lane, 0.05, 96), CYAN)
		for z in range(-4, 96, 4):
			view.segment(Vector3(side * 1.35, 0.05, z), Vector3(side * 2.15, 0.05, z), CYAN * 0.55)
	for x in range(-28, 32, 4):
		view.segment(Vector3(x, 0.05, 34.6), Vector3(x, 0.05, 35.4), CYAN * 0.7)
		view.segment(Vector3(x, 0.05, 37.2), Vector3(x, 0.05, 38.0), CYAN * 0.7)

func _hall(view: Node, origin: Vector3, size: Vector3) -> void:
	var posts := [
		origin,
		origin + Vector3(size.x, 0, 0),
		origin + Vector3(size.x, 0, size.z),
		origin + Vector3(0, 0, size.z),
	]
	for post in posts:
		view.segment(post, post + Vector3(0, size.y, 0), PINK)
	var roof := origin + Vector3(0, size.y, 0)
	view.segment(roof, roof + Vector3(size.x, 0, 0), PINK)
	view.segment(roof + Vector3(size.x, 0, 0), roof + Vector3(size.x, 0, size.z), PINK)
	view.segment(roof + Vector3(size.x, 0, size.z), roof + Vector3(0, 0, size.z), PINK)
	view.segment(roof + Vector3(0, 0, size.z), roof, PINK)
	view.segment(roof, roof + Vector3(size.x, 0, size.z), PINK * 0.65)
	var mid := size.y * 0.45
	view.segment(origin + Vector3(0, mid, 0), origin + Vector3(size.x, mid, 0), PINK * 0.75)
	view.segment(origin + Vector3(0, mid, size.z), origin + Vector3(size.x, mid, size.z), PINK * 0.75)
	for step in 4:
		var y := size.y * (0.25 + step * 0.15)
		view.segment(origin + Vector3(size.x * 0.5, y, 0), origin + Vector3(size.x * 0.5, y, size.z), PINK * 0.4)

func _pipes(view: Node) -> void:
	view.segment(Vector3(-16, 6.2, 14), Vector3(-14, 6.2, 30), CYAN * 0.8)
	view.segment(Vector3(-14, 6.2, 30), Vector3(-12, 4.4, 48), CYAN * 0.8)
	view.segment(Vector3(16, 5.4, 16), Vector3(18, 5.4, 36), PINK * 0.8)
	view.segment(Vector3(18, 5.4, 36), Vector3(20, 8.0, 58), PINK * 0.8)
	view.segment(Vector3(-8, 3.2, 36), Vector3(8, 3.2, 36), CYAN)

func _silo(view: Node, origin: Vector3, radius: float, height: float) -> void:
	for i in 7:
		_ring(view, origin + Vector3(0, height * i / 6.0, 0), radius, AMBER)
	for i in 8:
		var a := TAU * i / 8.0
		var p := Vector3(cos(a) * radius, 0, sin(a) * radius)
		view.segment(origin + p, origin + p + Vector3(0, height, 0), AMBER)
	_ring(view, origin + Vector3(0, height + 0.6, 0), radius * 0.45, AMBER)

func _catwalk(view: Node, z: float) -> void:
	view.segment(Vector3(-16, 0, z), Vector3(-16, 4.2, z), PINK)
	view.segment(Vector3(16, 0, z), Vector3(16, 4.2, z), PINK)
	view.segment(Vector3(-16, 4.2, z - 0.8), Vector3(16, 4.2, z - 0.8), PINK)
	view.segment(Vector3(-16, 4.2, z + 0.8), Vector3(16, 4.2, z + 0.8), PINK)
	for x in range(-14, 16, 2):
		view.segment(Vector3(x, 4.2, z - 0.8), Vector3(x, 4.2, z + 0.8), PINK * 0.7)

func _bottle(view: Node, origin: Vector3) -> void:
	for i in 5:
		_ring_x(view, origin + Vector3(i * 0.55, 0.7, 0), 0.42, PINK)
	_ring_x(view, origin + Vector3(-0.35, 0.7, 0), 0.22, CYAN)
	_ring_x(view, origin + Vector3(-0.7, 0.7, 0), 0.16, CYAN)
	view.segment(origin + Vector3(-0.7, 0.7, 0), origin + Vector3(-1.3, 0.7, 0), CYAN)
	view.segment(origin + Vector3(-0.9, 0.55, 0), origin + Vector3(-0.9, 0.15, 0), AMBER)
	_ring_x(view, origin + Vector3(-0.9, 0.12, 0), 0.12, AMBER)

func _buggy(view: Node, origin: Vector3) -> void:
	view.segment(origin + Vector3(-0.8, 0.4, -1.2), origin + Vector3(0.8, 0.4, -1.2), CYAN)
	view.segment(origin + Vector3(0.8, 0.4, -1.2), origin + Vector3(0.7, 0.9, 0.2), CYAN)
	view.segment(origin + Vector3(0.7, 0.9, 0.2), origin + Vector3(-0.7, 0.9, 0.2), CYAN)
	view.segment(origin + Vector3(-0.7, 0.9, 0.2), origin + Vector3(-0.8, 0.4, -1.2), CYAN)
	view.segment(origin + Vector3(-0.8, 0.4, 1.3), origin + Vector3(0.8, 0.4, 1.3), CYAN)
	view.segment(origin + Vector3(-0.8, 0.4, -1.2), origin + Vector3(-0.8, 0.4, 1.3), CYAN)
	view.segment(origin + Vector3(0.8, 0.4, -1.2), origin + Vector3(0.8, 0.4, 1.3), CYAN)
	for side in [-1.0, 1.0]:
		for z in [-0.8, 0.9]:
			_ring_x(view, origin + Vector3(side * 0.95, 0.38, z), 0.38, CYAN)

func _beam(view: Node, origin: Vector3) -> void:
	_ring(view, origin + Vector3(0, 0.2, 0), 3.2, BEAM)
	_ring(view, origin + Vector3(0, 0.2, 0), 2.2, BEAM)
	view.segment(origin, origin + Vector3(0, 28, 0), BEAM)

func _ring(view: Node, center: Vector3, radius: float, color: Color) -> void:
	for i in 16:
		var a := TAU * i / 16.0
		var b := TAU * (i + 1) / 16.0
		view.segment(center + Vector3(cos(a), 0, sin(a)) * radius, center + Vector3(cos(b), 0, sin(b)) * radius, color)

func _ring_x(view: Node, center: Vector3, radius: float, color: Color) -> void:
	for i in 12:
		var a := TAU * i / 12.0
		var b := TAU * (i + 1) / 12.0
		view.segment(center + Vector3(0, cos(a), sin(a)) * radius, center + Vector3(0, cos(b), sin(b)) * radius, color)
