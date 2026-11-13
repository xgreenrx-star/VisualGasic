extends Node3D

const BASE := "res://assets/opening_cinematic/"
const TABLE_TOP := 0.88
const CYAN := Color(0.13, 0.68, 0.77)
const AMBER := Color(1.0, 0.49, 0.16)
const HEAD_PROFILE: Array[Vector4] = [
	Vector4(0.012, -0.162, 0.03, 0.04),
	Vector4(0.057, -0.148, 0.055, 0.038),
	Vector4(0.091, -0.112, 0.078, 0.018),
	Vector4(0.108, -0.065, 0.091, 0.008),
	Vector4(0.12, -0.02, 0.101, 0.0),
	Vector4(0.119, 0.027, 0.101, -0.002),
	Vector4(0.116, 0.072, 0.104, -0.006),
	Vector4(0.112, 0.112, 0.098, -0.009),
	Vector4(0.086, 0.15, 0.077, -0.014),
	Vector4(0.035, 0.174, 0.034, -0.018),
	Vector4(0.001, 0.178, 0.001, -0.018)]

var timeline: Dictionary
var lines: Array = []
var clips: Dictionary = {}
var duration := 0.0
var position_seconds := 0.0
var playing := false
var active_id := ""
var camera: Camera3D
var voice: AudioStreamPlayer
var subtitle: Label
var speaker: Label
var clock: Label
var status: Label
var play_button: Button
var mute: CheckButton
var scrubber: HSlider
var actors: Dictionary = {}
var contact_meshes: Array[MeshInstance3D] = []
var traffic: Array[Node3D] = []
var device: Node3D
var transfer_label: Label3D
var finished := false
var ready_for_review := false
var fatal_error := ""
var capture_time := -1.0
var capture_path := ""
var capture_frames := 0
var capture_saved := false
var materials: Dictionary = {}
var speech_envelopes: Dictionary = {}
var review_controls: Array[Control] = []
var caption_panel: Control
var study_title: Label
var bottom_bar: ColorRect

func _ready() -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_build_ui()
	if not _load_edit():
		return
	_build_room()
	actors["MARK"] = _build_actor("MARK", Vector3(0, 0, -0.98), 0.0)
	actors["JASON"] = _build_actor("JASON", Vector3(0, 0, 0.98), PI)
	camera = Camera3D.new()
	camera.near = 0.04
	camera.far = 150.0
	add_child(camera)
	camera.current = true
	voice = AudioStreamPlayer.new()
	add_child(voice)
	ready_for_review = true
	var sample := OS.get_environment("ASH_BAR_TIME")
	capture_path = OS.get_environment("ASH_BAR_CAPTURE")
	if not sample.is_empty():
		capture_time = sample.to_float()
		seek(capture_time)
	else:
		seek(0.0)
	if not capture_path.is_empty():
		set_presentation_mode()
		RenderingServer.frame_post_draw.connect(_capture)

func _fail(message: String) -> void:
	fatal_error = message
	playing = false
	if is_instance_valid(voice):
		voice.stop()
	status.text = message
	status.modulate = Color(1.0, 0.4, 0.3)
	play_button.disabled = true
	push_error("Opening bar study: " + message)

func _load_edit() -> bool:
	var parser := JSON.new()
	var error := parser.parse(FileAccess.get_file_as_string(BASE + "timeline.json"))
	if error != OK or not parser.data is Dictionary:
		_fail("Cannot read timeline.json. Rebuild the opening animatic first.")
		return false
	timeline = parser.data
	var envelope_parser := JSON.new()
	if envelope_parser.parse(FileAccess.get_file_as_string(BASE + "speech-envelope.json")) != OK:
		_fail("Cannot read speech-envelope.json. Rebuild the opening performance data.")
		return false
	speech_envelopes = envelope_parser.data
	var script_parser := JSON.new()
	if script_parser.parse(FileAccess.get_file_as_string(BASE + "script.json")) != OK:
		_fail("Cannot read the canonical opening script.")
		return false
	var source: Dictionary = script_parser.data
	if source.version != timeline.version or source.lines.size() != timeline.lines.size():
		_fail("The opening timeline is stale. Rebuild the animatic.")
		return false
	for i in range(source.lines.size()):
		for key: String in ["id", "text", "speaker", "profile", "speed", "silence"]:
			if source.lines[i][key] != timeline.lines[i][key]:
				_fail("Stale dialogue/delivery for line " + str(source.lines[i].id))
				return false
	for shot: Dictionary in timeline.shots:
		if shot.id == "departure":
			duration = float(shot.at)
	if duration <= 0.0:
		_fail("Timeline has no station departure boundary.")
		return false
	for line: Dictionary in timeline.lines:
		if float(line.at) >= duration:
			continue
		var clip := AudioStreamOggVorbis.load_from_file(BASE + line.audio)
		if clip == null or absf(clip.get_length() - float(line.seconds)) > 0.02:
			_fail("Missing or stale voice clip for line " + str(line.id))
			return false
		if not speech_envelopes.has(line.id) or speech_envelopes[line.id].text != line.text or speech_envelopes[line.id].sha256 != FileAccess.get_sha256(BASE + line.audio):
			_fail("Missing or stale performance envelope for line " + str(line.id))
			return false
		var envelope: Dictionary = speech_envelopes[line.id]
		if envelope.hz != 50 or envelope.samples.size() != int(ceil(float(line.seconds) * 50)):
			_fail("Invalid performance sample timing for line " + str(line.id))
			return false
		for value: float in envelope.samples:
			if not is_finite(value) or value < 0.0 or value > 1.0:
				_fail("Invalid performance sample for line " + str(line.id))
				return false
		clips[line.id] = clip
		lines.append(line)
	return true

func _material(key: String, color: Color, metal := 0.0, emission := 0.0) -> StandardMaterial3D:
	if materials.has(key):
		return materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = 0.68 if metal == 0.0 else 0.4
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	materials[key] = material
	return material

func _mesh(parent: Node3D, mesh: Mesh, point: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = point
	parent.add_child(instance)
	return instance

func _box(parent: Node3D, point: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _mesh(parent, shape, point, material)

func _ellipsoid(parent: Node3D, point: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radial_segments = 32
	shape.rings = 16
	var instance := _mesh(parent, shape, point, material)
	instance.scale = size
	return instance

func _cylinder(parent: Node3D, point: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 16
	return _mesh(parent, shape, point, material)

func _profile_mesh(profile: Array[Vector3], segments := 12) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	for ring in range(profile.size() - 1):
		for i in range(segments):
			var corners: Array[Vector3] = []
			for index in [Vector2i(ring, i), Vector2i(ring + 1, i), Vector2i(ring + 1, i + 1), Vector2i(ring, i + 1)]:
				var shape := profile[index.x]
				var angle := TAU * float(index.y) / segments
				corners.append(Vector3(sin(angle) * shape.x, shape.y, cos(angle) * shape.z))
			for corner in [0, 1, 2, 0, 2, 3]:
				surface.add_vertex(corners[corner])
	surface.index()
	surface.generate_normals()
	return surface.commit()

func _curve(parent: Node3D, points: Array[Vector3], radius: float, material: Material) -> void:
	for i in range(points.size() - 1):
		_segment(parent, points[i], points[i + 1], radius, material)

func _face_mesh(older: bool) -> ArrayMesh:
	var rings := HEAD_PROFILE
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	for ring in range((rings.size() - 1) * 6):
		for i in range(80):
			for index: Vector2i in [Vector2i(ring, i), Vector2i(ring + 1, i), Vector2i(ring + 1, i + 1), Vector2i(ring, i), Vector2i(ring + 1, i + 1), Vector2i(ring, i + 1)]:
				var ring_index := mini(index.x / 6, rings.size() - 2)
				var blend := float(index.x - ring_index * 6) / 6.0
				var p0 := rings[maxi(0, ring_index - 1)]
				var p1 := rings[ring_index]
				var p2 := rings[ring_index + 1]
				var p3 := rings[mini(rings.size() - 1, ring_index + 2)]
				var shape := 0.5 * (2.0 * p1 + (p2 - p0) * blend + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * blend * blend + (3.0 * p1 - p0 - 3.0 * p2 + p3) * blend * blend * blend)
				shape.x = maxf(0.001, shape.x)
				shape.z = maxf(0.001, shape.z)
				var angle := TAU * index.y / 80.0
				var x := sin(angle) * shape.x
				var z := cos(angle) * shape.z + shape.w
				if cos(angle) > 0:
					# Flatten the facial plane while retaining cheek and temple volume.
					z = lerpf(z, shape.z + shape.w, pow(cos(angle), 0.55) * 0.65)
					var socket := exp(-pow((absf(x) - 0.05) / 0.025, 2)) * exp(-pow((shape.y - 0.025) / 0.035, 2))
					z -= socket * (0.009 if older else 0.006)
					var bridge := exp(-pow(x / 0.016, 2)) * exp(-pow((shape.y + 0.002) / 0.043, 2))
					var tip := exp(-pow(x / 0.021, 2)) * exp(-pow((shape.y + 0.031) / 0.015, 2))
					var cheek := exp(-pow((absf(x) - 0.075) / 0.032, 2)) * exp(-pow((shape.y + 0.027) / 0.025, 2))
					z += bridge * 0.018 + tip * 0.016 + cheek * 0.005
				surface.add_vertex(Vector3(x * (1.025 if older else 0.98), shape.y, z))
	surface.index()
	surface.generate_normals()
	return surface.commit()

func _head_dimensions(y: float) -> Vector4:
	for i in range(HEAD_PROFILE.size() - 1):
		if y <= HEAD_PROFILE[i + 1].y:
			return HEAD_PROFILE[i].lerp(HEAD_PROFILE[i + 1], inverse_lerp(HEAD_PROFILE[i].y, HEAD_PROFILE[i + 1].y, y))
	return Vector4(0, y, 0, -0.018)

func _hair_mesh(older: bool) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	for ring in range(18):
		for i in range(80):
			for index: Vector2i in [Vector2i(ring, i), Vector2i(ring + 1, i), Vector2i(ring + 1, i + 1), Vector2i(ring, i), Vector2i(ring + 1, i + 1), Vector2i(ring, i + 1)]:
				var theta := TAU * index.y / 80.0
				var t := index.x / 18.0
				var front := maxf(0.0, cos(theta))
				var hairline := 0.01 + front * (0.111 if older else 0.09)
				hairline += sin(theta * 2.0) * front * 0.009
				var flow := sin(theta * 17.0 + t * 5.0) * 0.0007
				var y := lerpf(hairline, 0.187, sin(t * PI * 0.5))
				var shape := _head_dimensions(y - 0.008)
				var margin := (0.008 + flow) * (1.0 - t)
				var width := shape.x * (1.025 if older else 0.98) + margin
				var depth := cos(theta) * (shape.z + margin)
				if front > 0.0:
					depth = lerpf(depth, shape.z + margin, pow(front, 0.55) * 0.65)
				surface.add_vertex(Vector3(
					sin(theta) * width,
					y,
					depth + shape.w))
	surface.index()
	surface.generate_normals()
	return surface.commit()

func _sleeve(parent: Node3D, start: Vector3, end: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var profile: Array[Vector3] = []
	for sample: Vector2 in [Vector2(-0.5, 0.55), Vector2(-0.46, 0.82), Vector2(-0.28, 0.94), Vector2(0, 1.04), Vector2(0.3, 1), Vector2(0.45, 0.85), Vector2(0.5, 0.5)]:
		profile.append(Vector3(radius * sample.y, sample.x, radius * sample.y))
	var part := _mesh(parent, _profile_mesh(profile, 24), Vector3.ZERO, material)
	_orient_segment(part, start, end)
	part.scale.y = start.distance_to(end)
	return part

func _build_face(head: Node3D, identity: String, skin: Material, hair: Material) -> Dictionary:
	var older := identity == "MARK"
	var lip := _material(identity + "_lip", Color(0.32, 0.19, 0.15))
	var crease := _material(identity + "_crease", Color(0.39, 0.3, 0.245))
	var eye_white := _material("eye_white", Color(0.46, 0.49, 0.44))
	var iris := _material(identity + "_iris", Color(0.12, 0.22, 0.2) if older else Color(0.2, 0.17, 0.12))
	var pupil := _material("pupil", Color(0.012, 0.018, 0.02))
	var glint := _material("eye_glint", Color(0.8, 0.86, 0.83), 0, 0.2)
	_mesh(head, _face_mesh(older), Vector3.ZERO, skin)
	for side in [-1, 1]:
		_ellipsoid(head, Vector3(side * 0.013, -0.043, 0.118), Vector3(0.007, 0.003, 0.006), crease)
		var ear := _ellipsoid(head, Vector3(side * 0.12, -0.005, -0.002), Vector3(0.034, 0.074, 0.039), skin)
		ear.rotation.z = side * -0.12
		_ellipsoid(head, Vector3(side * 0.132, -0.006, 0.012), Vector3(0.011, 0.042, 0.013), crease)
	var eyes: Array[Node3D] = []
	var brows: Array[Node3D] = []
	for side in [-1, 1]:
		var eye := Node3D.new()
		head.add_child(eye)
		eye.position = Vector3(side * 0.05, 0.027, 0.096)
		eye.rotation.y = side * 0.15
		_ellipsoid(eye, Vector3.ZERO, Vector3(0.047, 0.019, 0.021), eye_white)
		_ellipsoid(eye, Vector3(-side * 0.002, 0, 0.011), Vector3(0.016, 0.017, 0.005), iris)
		_ellipsoid(eye, Vector3(-side * 0.002, 0, 0.014), Vector3(0.007, 0.01, 0.003), pupil)
		_ellipsoid(eye, Vector3(-0.005, 0.004, 0.016), Vector3(0.003, 0.003, 0.002), glint)
		_curve(eye, [Vector3(-0.025, 0, 0), Vector3(-0.012, 0.009, 0.008), Vector3(0.009, 0.009, 0.008), Vector3(0.025, 0.001, 0)], 0.0025, skin)
		_curve(eye, [Vector3(-0.025, 0, 0), Vector3(-0.01, -0.007, 0.007), Vector3(0.012, -0.007, 0.007), Vector3(0.025, 0.001, 0)], 0.002, skin)
		eyes.append(eye)
		var brow := Node3D.new()
		head.add_child(brow)
		brow.position = Vector3(side * 0.05, 0.054, 0.096)
		_curve(brow, [Vector3(-0.025, 0, 0), Vector3(-0.006, 0.006, 0.006), Vector3(0.013, 0.005, 0.003), Vector3(0.025, -0.001, -0.004)], 0.0035, hair)
		brows.append(brow)
		if older:
			_curve(head, [Vector3(side * 0.03, -0.045, 0.1), Vector3(side * 0.044, -0.065, 0.096), Vector3(side * 0.046, -0.081, 0.089)], 0.0006, crease)
			_curve(head, [Vector3(side * 0.034, 0.011, 0.097), Vector3(side * 0.05, 0.006, 0.099), Vector3(side * 0.069, 0.01, 0.091)], 0.0008, crease)
		if older:
			for y in [0.087, 0.097]:
				_curve(head, [Vector3(-0.055, y, 0.09), Vector3(0, y + 0.004, 0.1), Vector3(0.055, y, 0.09)], 0.0006, crease)
	var mouth := Node3D.new()
	head.add_child(mouth)
	mouth.position = Vector3(0, -0.081, 0.101)
	var cavity := _ellipsoid(mouth, Vector3.ZERO, Vector3(0.054, 0.003, 0.009), _material("mouth_cavity", Color(0.065, 0.028, 0.025)))
	var upper := _ellipsoid(mouth, Vector3(0, 0.002, 0.001), Vector3(0.055, 0.006, 0.009), lip)
	var lower := _ellipsoid(mouth, Vector3(0, -0.004, 0.002), Vector3(0.05, 0.007, 0.01), lip)
	var chin := _ellipsoid(head, Vector3(0, -0.126, 0.082), Vector3(0.08, 0.032, 0.027), skin)
	var rng := RandomNumberGenerator.new()
	rng.seed = 148 if older else 812
	if older:
		var stubble := _material("stubble", Color(0.27, 0.26, 0.23))
		for i in range(110):
			var x := rng.randf_range(-0.075, 0.075)
			var y := rng.randf_range(-0.14, -0.087)
			if absf(x) > lerpf(0.05, 0.085, inverse_lerp(-0.14, -0.087, y)):
				continue
			_ellipsoid(head, Vector3(x, y, 0.097 - absf(x) * 0.23), Vector3(0.0014, 0.0027, 0.0012), stubble)
	_mesh(head, _hair_mesh(older), Vector3.ZERO, hair)
	for side in [-1, 1]:
		_ellipsoid(head, Vector3(side * 0.115, 0.055, -0.027), Vector3(0.022, 0.13, 0.08), hair)
	return {"eyes": eyes, "brows": brows, "mouth": mouth, "cavity": cavity, "upper_lip": upper, "lower_lip": lower, "chin": chin}

func _segment(parent: Node3D, start: Vector3, end: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var part := _cylinder(parent, (start + end) * 0.5, radius, start.distance_to(end), material)
	_orient_segment(part, start, end)
	return part

func _orient_segment(part: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	var direction := (end - start).normalized()
	var right := direction.cross(Vector3.FORWARD).normalized()
	part.basis = Basis(right, direction, right.cross(direction).normalized())
	part.position = (start + end) * 0.5

func _label(parent: Node3D, text: String, point: Vector3, size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = point
	label.font_size = size
	label.pixel_size = 0.002
	label.modulate = color
	label.outline_size = 0
	parent.add_child(label)
	return label

func _spot(point: Vector3, target: Vector3, color: Color, energy: float, angle: float, shadows: bool) -> void:
	var light := SpotLight3D.new()
	add_child(light)
	light.position = point
	light.look_at(target)
	light.light_color = color
	light.light_energy = energy
	light.spot_range = 12.0
	light.spot_angle = angle
	light.spot_attenuation = 0.6
	light.shadow_enabled = shadows
	light.shadow_bias = 0.15
	light.shadow_normal_bias = 1.5

func _surface(color: Color, metal: float, roughness: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/opening_bar_surface.gdshader")
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("metalness", metal)
	material.set_shader_parameter("surface_roughness", roughness)
	return material

func _build_room() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.008, 0.014, 0.025)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.25, 0.35, 0.45)
	settings.ambient_light_energy = 0.28
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	var shell := _material("shell", Color(0.045, 0.068, 0.085), 0.6)
	var panel := _material("panel", Color(0.075, 0.095, 0.11), 0.4)
	var dark := _material("dark", Color(0.017, 0.025, 0.035), 0.25)
	var cyan := _material("cyan", CYAN, 0.2, 0.65)
	var amber := _material("amber", AMBER, 0.2, 0.6)
	var upholstery := _material("upholstery", Color(0.09, 0.065, 0.05))
	_box(self, Vector3(0, -0.12, 0), Vector3(12, 0.24, 16), dark)
	_box(self, Vector3(0, 3.8, 0), Vector3(12, 0.22, 16), shell)
	var wall_surface := _surface(Color(0.065, 0.08, 0.09), 0.35, 0.77)
	_box(self, Vector3(0, 1.8, -4.4), Vector3(12, 3.8, 0.24), wall_surface)
	_box(self, Vector3(-5.4, 1.8, 0), Vector3(0.2, 3.8, 12), shell)
	_box(self, Vector3(0, 1.8, 5.2), Vector3(12, 3.8, 0.24), wall_surface)
	for x in [-4.6, -2.7, 2.7, 4.6]:
		_box(self, Vector3(x, 1.9, -4.22), Vector3(0.14, 3.5, 0.18), dark)
		_box(self, Vector3(x + 0.1, 2.5, -4.1), Vector3(0.018, 1.35, 0.025), cyan)
	for z in [-3.6, -1.5, 1.5, 3.6]:
		_box(self, Vector3(0, 0.012, z), Vector3(10, 0.015, 0.02), panel)
		_box(self, Vector3(0, 3.55, z), Vector3(10.5, 0.26, 0.2), dark)
		_box(self, Vector3(0, 3.4, z), Vector3(2.6, 0.025, 0.05), amber)
	for x in [-5.0, 5.0]:
		_box(self, Vector3(x, 0.035, 0), Vector3(0.025, 0.025, 10), cyan)
	_box(self, Vector3(-0.9, 0.57, -3.1), Vector3(3.0, 1.15, 0.65), dark)
	_box(self, Vector3(-0.9, 1.17, -3.1), Vector3(3.2, 0.08, 0.8), shell)
	_box(self, Vector3(-0.9, 1.16, -2.67), Vector3(3.1, 0.025, 0.025), amber)
	for y in [1.7, 2.25, 2.8]:
		_box(self, Vector3(-0.9, y, -4.0), Vector3(2.6, 0.06, 0.4), dark)
		for i in range(9):
			var bottle_material := _material("bottle%d" % (i % 3), [Color(0.19, 0.26, 0.24), Color(0.27, 0.16, 0.07), Color(0.11, 0.2, 0.24)][i % 3], 0.3)
			var height := 0.19 + float(i % 3) * 0.055
			_cylinder(self, Vector3(-1.95 + i * 0.26, y + height * 0.5, -3.93), 0.055, height, bottle_material)
			_cylinder(self, Vector3(-1.95 + i * 0.26, y + height + 0.03, -3.93), 0.025, 0.06, bottle_material)
	_label(self, "LAST LIGHT  /  DOCK 07", Vector3(-0.9, 3.25, -4.23), 38, CYAN)
	_label(self, "OUTBOUND BERTHS", Vector3(3.35, 2.5, -4.23), 25, AMBER)
	_box(self, Vector3(3.4, 1.1, -4.2), Vector3(1.5, 2.15, 0.12), dark)
	_box(self, Vector3(2.6, 1.15, -4.08), Vector3(0.025, 2.3, 0.025), amber)
	_box(self, Vector3(4.2, 1.15, -4.08), Vector3(0.025, 2.3, 0.025), amber)
	_build_window(shell, dark, cyan, amber)
	_build_set_dressing(shell, dark, cyan, amber)
	for z in [-2.7, 2.7]:
		_box(self, Vector3(-4.9, 0.45, z), Vector3(0.65, 0.9, 1.7), upholstery)
		_box(self, Vector3(-4.95, 1.1, z), Vector3(0.35, 0.7, 1.8), upholstery)
		_box(self, Vector3(-4.0, 0.77, z), Vector3(1.3, 0.08, 1.25), shell)
		_box(self, Vector3(-4.0, 0.82, z), Vector3(1.2, 0.01, 0.015), amber)
	_box(self, Vector3(0, TABLE_TOP - 0.055, 0), Vector3(1.85, 0.11, 1.34), _surface(Color(0.025, 0.042, 0.052), 0.45, 0.54))
	_box(self, Vector3(0, TABLE_TOP - 0.12, 0), Vector3(1.94, 0.04, 1.43), shell)
	_box(self, Vector3(0, 0.38, 0), Vector3(0.38, 0.76, 0.55), shell)
	for x in [-0.94, 0.94]:
		_box(self, Vector3(x, TABLE_TOP - 0.055, 0), Vector3(0.018, 0.025, 1.4), cyan)
	for z in [-0.7, 0.7]:
		_box(self, Vector3(0, TABLE_TOP - 0.055, z), Vector3(1.88, 0.025, 0.018), cyan)
	_build_props()
	_box(self, Vector3(0, 2.9, 0), Vector3(1.65, 0.15, 0.8), dark)
	_box(self, Vector3(0, 2.8, 0), Vector3(1.35, 0.025, 0.54), amber)
	for x in [-0.62, 0.62]:
		_cylinder(self, Vector3(x, 3.25, 0), 0.012, 0.65, shell)
	_spot(Vector3(-0.6, 2.7, 1.25), Vector3(0, 1.45, -1), Color(1, 0.86, 0.7), 1.1, 42, true)
	_spot(Vector3(2.0, 2.7, -2.2), Vector3(0, 1.3, -0.8), Color(0.27, 0.72, 0.9), 1.6, 38, true)
	_spot(Vector3(-1.6, 2.6, -1.5), Vector3(0, 1.35, 0.9), Color(1, 0.65, 0.36), 1.35, 45, true)
	_spot(Vector3(3.4, 3.1, 1.0), Vector3(0, 1.2, 0.4), Color(0.2, 0.6, 0.85), 0.7, 50, false)
	_spot(Vector3(-0.9, 3.4, -2.0), Vector3(-0.9, 1.9, -4), Color(1, 0.62, 0.3), 0.85, 45, false)
	_spot(Vector3(0.3, 1.7, 1.9), Vector3(0, 1.5, -0.98), Color(0.65, 0.78, 0.86), 0.12, 30, false)

func _build_set_dressing(shell: Material, dark: Material, cyan: Material, amber: Material) -> void:
	var brass := _material("brass", Color(0.29, 0.22, 0.12), 0.65)
	var rubber := _material("rubber", Color(0.03, 0.035, 0.035))
	var pale := _material("label_paper", Color(0.36, 0.32, 0.23))
	for x in [-4.8, -2.5, 0.8, 2.35, 4.7]:
		_box(self, Vector3(x, 1.7, -4.24), Vector3(0.018, 3.25, 0.025), dark)
		for y in [0.35, 1.35, 3.05]:
			_cylinder(self, Vector3(x, y, -4.2), 0.021, 0.008, brass).rotation.x = PI / 2
	for y in [0.3, 0.44]:
		_segment(self, Vector3(-5, y, -4.1), Vector3(4.7, y, -4.1), 0.033, shell)
		for x in [-4.5, -2.5, 0.5, 2.5, 4.5]:
			_box(self, Vector3(x, y, -4.09), Vector3(0.06, 0.1, 0.09), brass)
	for z in [-2.7, 2.7]:
		for x in [-0.75, -0.25, 0.25, 0.75]:
			_segment(self, Vector3(x, 3.65, z - 0.6), Vector3(x, 3.65, z + 0.6), 0.032, shell)
	_box(self, Vector3(-0.9, 3.23, -4.17), Vector3(2.85, 0.37, 0.08), dark)
	for y in [3.01, 3.45]:
		_box(self, Vector3(-0.9, y, -4.08), Vector3(2.95, 0.013, 0.02), brass)
	for y in [1.7, 2.25, 2.8]:
		_box(self, Vector3(-0.9, y - 0.04, -3.88), Vector3(2.5, 0.015, 0.02), amber)
		for i in range(9):
			_box(self, Vector3(-1.95 + i * 0.26, y + 0.11, -3.871), Vector3(0.068, 0.07, 0.005), pale)
			_box(self, Vector3(-1.95 + i * 0.26, y + 0.11, -3.866), Vector3(0.036, 0.008, 0.002), dark)
	_box(self, Vector3(2.9, 1.9, 5.04), Vector3(1.75, 1.5, 0.1), dark)
	var menu := _label(self, "LAST LIGHT\n\nBERTH 07 / NIGHT SHIFT\n\nCOFFEE   /   SOMETHING STRONGER\n\nNO CREDIT. NO EXCEPTIONS.", Vector3(2.9, 1.95, 4.96), 22, Color(0.48, 0.65, 0.65))
	menu.rotation.y = PI
	for x in [1.97, 3.83]:
		_box(self, Vector3(x, 1.9, 4.94), Vector3(0.015, 1.62, 0.02), cyan)
	for z in [-4.0, 4.85]:
		_box(self, Vector3(-3.3, 2.0, z), Vector3(1.15, 1.0, 0.1), dark)
		for i in range(10):
			_box(self, Vector3(-3.3, 1.59 + i * 0.09, z + (0.06 if z < 0 else -0.06)), Vector3(1.04, 0.035, 0.05), shell)
	for x in [-2.5, 2.5]:
		for z in [-2.5, 2.5]:
			_segment(self, Vector3(x, 3.7, z), Vector3(x, 2.65, z), 0.012, rubber)
			_cylinder(self, Vector3(x, 2.54, z), 0.16, 0.2, dark)
			_cylinder(self, Vector3(x, 2.43, z), 0.125, 0.014, amber)
			for i in range(6):
				var angle := TAU * i / 6
				var offset := Vector3(cos(angle) * 0.13, 0, sin(angle) * 0.13)
				_segment(self, Vector3(x, 2.36, z) + offset, Vector3(x, 2.55, z) + offset, 0.006, brass)
	for i in range(11):
		var scratch := _box(self, Vector3(-0.75 + i * 0.014, TABLE_TOP + 0.0007, 0.42), Vector3(0.0008, 0.0004, 0.035 + (i % 3) * 0.012), shell)
		scratch.rotation.y = 0.4
	for x in [-0.83, 0.83]:
		for z in [-0.56, 0.56]:
			_cylinder(self, Vector3(x, TABLE_TOP + 0.001, z), 0.009, 0.001, brass)
	var coaster := _cylinder(self, Vector3(0.58, TABLE_TOP + 0.002, -0.33), 0.085, 0.004, rubber)
	coaster.name = "DrinkCoaster"
	for i in range(3):
		_cylinder(self, Vector3(-0.5 + i * 0.06, TABLE_TOP + 0.004, -0.12 + i * 0.025), 0.024, 0.008, brass)
	for i in range(6):
		var card := _box(self, Vector3(-0.56 + i * 0.002, TABLE_TOP + 0.002 + i * 0.002, -0.25), Vector3(0.105, 0.002, 0.165), rubber)
		card.rotation.y = -0.15

func _build_window(shell: Material, dark: Material, cyan: Material, amber: Material) -> void:
	_box(self, Vector3(5.4, 0.5, 0), Vector3(0.2, 1, 12), shell)
	_box(self, Vector3(5.4, 3.5, 0), Vector3(0.2, 1, 12), shell)
	for z in [-4.5, -1.8, 1.8, 4.5]:
		_box(self, Vector3(5.4, 2.0, z), Vector3(0.22, 2.1, 0.12), dark)
		_box(self, Vector3(5.28, 1.05, z), Vector3(0.025, 0.025, 0.6), cyan)
	for i in range(9):
		_box(self, Vector3(8 + i * 1.9, -0.6, -5 - i * 1.2), Vector3(0.6, 1.2 + i * 0.25, 0.8), shell)
		_box(self, Vector3(7 + i * 2.3, 0.1, -4 - i * 1.2), Vector3(0.15, 0.05, 0.9), amber)
	for z in [-6.0, 6.0]:
		_box(self, Vector3(11, 3.0, z), Vector3(0.8, 8.0, 0.55), dark)
		_segment(self, Vector3(10.5, 0.2, z), Vector3(10.5, 5.6, z - 2.5), 0.14, shell)
		for i in range(4):
			_box(self, Vector3(10.55, 1 + i * 1.2, z - 0.3), Vector3(0.03, 0.11, 0.35), amber)
	_box(self, Vector3(12, 6.2, 0), Vector3(1, 0.7, 13), dark)
	_box(self, Vector3(11.45, 5.8, 0), Vector3(0.025, 0.025, 11), cyan)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1986
	var star := _material("star", Color(0.55, 0.65, 0.73), 0, 1)
	for i in range(65):
		_box(self, Vector3(32, rng.randf_range(-6, 15), rng.randf_range(-30, 30)), Vector3(0.025, 0.025, 0.025), star)
	for i in range(2):
		var ship := Node3D.new()
		add_child(ship)
		_box(ship, Vector3.ZERO, Vector3(0.65, 0.2, 1.3), shell)
		_box(ship, Vector3(0, 0.03, -0.1), Vector3(1.2, 0.04, 0.65), dark)
		_box(ship, Vector3(0, 0, -0.68), Vector3(0.25, 0.06, 0.025), amber)
		traffic.append(ship)

func _build_props() -> void:
	var paper := _material("cards", Color(0.72, 0.74, 0.67))
	var ink := _material("card_ink", Color(0.08, 0.17, 0.2))
	for i in range(5):
		var card := Node3D.new()
		add_child(card)
		card.position = Vector3(-0.34 + i * 0.12, TABLE_TOP + 0.005 + i * 0.001, 0.31)
		card.rotation.y = -0.22 + i * 0.11
		_box(card, Vector3.ZERO, Vector3(0.105, 0.002, 0.165), paper)
		var diamond := _box(card, Vector3(0, 0.002, 0), Vector3(0.035, 0.002, 0.035), ink)
		diamond.rotation.y = PI / 4
		var pip := _box(card, Vector3(-0.033, 0.002, -0.055), Vector3(0.012, 0.002, 0.012), ink)
		pip.rotation.y = PI / 4
	var bottle := _material("glass", Color(0.26, 0.32, 0.28), 0.65)
	_cylinder(self, Vector3(0.58, TABLE_TOP + 0.08, -0.33), 0.062, 0.16, bottle)
	_cylinder(self, Vector3(0.58, TABLE_TOP + 0.164, -0.33), 0.057, 0.007, _material("drink", Color(0.36, 0.16, 0.045), 0.35))
	device = Node3D.new()
	add_child(device)
	var case_material := _material("device", Color(0.11, 0.16, 0.18), 0.65)
	_box(device, Vector3.ZERO, Vector3(0.22, 0.025, 0.3), case_material)
	_box(device, Vector3(0, 0.014, 0), Vector3(0.185, 0.006, 0.22), _material("screen", Color(0.025, 0.13, 0.16), 0.2, 1))
	transfer_label = _label(device, "COORDINATES\nHOLD TO SEND", Vector3(0, 0.02, 0), 15, AMBER)
	transfer_label.pixel_size = 0.0007
	transfer_label.rotation.x = -PI / 2

func _build_actor(identity: String, point: Vector3, yaw: float) -> Dictionary:
	var actor := Node3D.new()
	actor.name = identity
	add_child(actor)
	actor.position = point
	actor.rotation.y = yaw
	var coat_color := Color(0.12, 0.17, 0.19) if identity == "MARK" else Color(0.055, 0.09, 0.13)
	var coat := _material(identity + "_coat", coat_color)
	var skin := _material(identity + "_skin", Color(0.48, 0.37, 0.29) if identity == "MARK" else Color(0.49, 0.36, 0.27))
	var hair := _material(identity + "_hair", Color(0.16, 0.18, 0.17) if identity == "MARK" else Color(0.055, 0.043, 0.034))
	var trim := _material(identity + "_trim", coat_color.lightened(0.055))
	var dark := materials.dark as Material
	var chair := Node3D.new()
	actor.add_child(chair)
	_box(chair, Vector3(0, 0.45, -0.08), Vector3(0.61, 0.12, 0.56), dark)
	_box(chair, Vector3(0, 0.91, -0.3), Vector3(0.59, 0.89, 0.1), coat)
	for x in [-0.24, 0.24]:
		for z in [-0.27, 0.15]:
			_box(chair, Vector3(x, 0.22, z), Vector3(0.04, 0.44, 0.04), dark)
	for x in [-0.16, 0.16]:
		_segment(actor, Vector3(x, 0.54, 0), Vector3(x, 0.47, 0.42), 0.105, coat)
		_segment(actor, Vector3(x, 0.47, 0.42), Vector3(x, 0.15, 0.46), 0.08, coat)
		_box(actor, Vector3(x, 0.09, 0.53), Vector3(0.17, 0.16, 0.29), dark)
	var body := Node3D.new()
	actor.add_child(body)
	_mesh(body, _profile_mesh([Vector3(0.19, 0.72, 0.15), Vector3(0.21, 0.8, 0.164), Vector3(0.215, 0.94, 0.17), Vector3(0.235, 1.13, 0.175), Vector3(0.255, 1.23, 0.15), Vector3(0.2, 1.31, 0.11), Vector3(0.075, 1.35, 0.065)], 32), Vector3.ZERO, coat)
	_box(body, Vector3(0, 1.04, 0.17), Vector3(0.006, 0.48, 0.008), dark)
	_box(body, Vector3(0.012, 1.04, 0.175), Vector3(0.002, 0.46, 0.006), trim)
	_box(body, Vector3(-0.115, 1.1, 0.157), Vector3(0.11, 0.004, 0.012), dark)
	_box(body, Vector3(0.112, 1.1, 0.158), Vector3(0.1, 0.004, 0.012), dark)
	for y in [0.86, 0.93, 1.0, 1.07, 1.14]:
		_box(body, Vector3(0.012, y, 0.181), Vector3(0.006, 0.003, 0.003), trim)
	for side in [-1, 1]:
		var collar := _box(body, Vector3(side * 0.068, 1.285, 0.11), Vector3(0.062, 0.1, 0.018), dark)
		collar.rotation.z = side * -0.35
		_segment(body, Vector3(side * 0.226, 1.25, 0.068), Vector3(side * 0.205, 1.15, 0.101), 0.003, materials.cyan)
		_ellipsoid(body, Vector3(side * 0.235, 1.235, 0.02), Vector3(0.16, 0.16, 0.21), coat)
	_cylinder(body, Vector3(0, 1.385, 0.015), 0.052, 0.14, skin)
	var head := Node3D.new()
	body.add_child(head)
	head.position = Vector3(0, 1.57, 0.025)
	var features := _build_face(head, identity, skin, hair)
	var arms: Array = []
	for side in [-1, 1]:
		var pose := _arm_pose(side)
		var shoulder: Vector3 = pose.shoulder
		var elbow: Vector3 = pose.elbow
		var wrist: Vector3 = pose.wrist
		var upper := _sleeve(actor, shoulder, elbow, 0.068, coat)
		var lower := _sleeve(actor, elbow, wrist, 0.046, coat)
		contact_meshes.append(upper)
		contact_meshes.append(lower)
		var elbow_joint := _ellipsoid(actor, elbow, Vector3(0.085, 0.085, 0.085), coat)
		contact_meshes.append(elbow_joint)
		var hidden_hand := Node3D.new()
		hidden_hand.name = "HandsRestingInLap"
		hidden_hand.position = wrist
		hidden_hand.visible = false
		actor.add_child(hidden_hand)
		arms.append({"side": side, "upper": upper, "lower": lower, "hand": hidden_hand, "elbow": elbow_joint, "pose": pose, "rest_wrist": wrist})
	return {"root": actor, "body": body, "head": head, "chair": chair, "arms": arms, "features": features}

func _arm_pose(side: float, rise := 0.0) -> Dictionary:
	return {
		"shoulder": Vector3(side * 0.235, 1.28 + rise, 0.02),
		"elbow": Vector3(side * 0.25, 0.89 + rise * 0.6, 0.08),
		"wrist": Vector3(side * 0.2, 0.58 + rise * 0.6, -0.05)
	}

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	for anchor in [0.0, 1.0]:
		var bar := ColorRect.new()
		bar.color = Color(0.005, 0.009, 0.015)
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if anchor == 0.0 else Control.PRESET_BOTTOM_WIDE)
		bar.offset_top = 0 if anchor == 0.0 else -88
		bar.offset_bottom = 42 if anchor == 0.0 else 0
		ui.add_child(bar)
		if anchor == 1.0:
			bottom_bar = bar
	var title := Label.new()
	study_title = title
	title.text = "ASH MERIDIAN  /  LAST LIGHT     -     LOOK DEVELOPMENT / SCRATCH PERFORMANCE"
	title.position = Vector2(24, 10)
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color(0.5, 0.7, 0.76)
	ui.add_child(title)
	var captions := VBoxContainer.new()
	caption_panel = captions
	captions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	captions.offset_left = 100
	captions.offset_right = -100
	captions.offset_top = -170
	captions.offset_bottom = -92
	ui.add_child(captions)
	speaker = Label.new()
	speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker.add_theme_font_size_override("font_size", 14)
	speaker.modulate = Color(1, 0.72, 0.4)
	captions.add_child(speaker)
	subtitle = Label.new()
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_shadow_color", Color.BLACK)
	subtitle.add_theme_constant_override("shadow_offset_x", 2)
	subtitle.add_theme_constant_override("shadow_offset_y", 2)
	captions.add_child(subtitle)
	var controls := HBoxContainer.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_left = 24
	controls.offset_right = -24
	controls.offset_top = -75
	controls.offset_bottom = -40
	controls.add_theme_constant_override("separation", 14)
	ui.add_child(controls)
	review_controls.append(controls)
	play_button = Button.new()
	play_button.text = "Play"
	play_button.pressed.connect(toggle_playback)
	controls.add_child(play_button)
	var restart := Button.new()
	restart.text = "Restart"
	restart.pressed.connect(func() -> void: pause(); seek(0))
	controls.add_child(restart)
	mute = CheckButton.new()
	mute.text = "Mute"
	mute.toggled.connect(func(_value: bool) -> void: _stop_voice(); _sync_dialogue())
	controls.add_child(mute)
	scrubber = HSlider.new()
	scrubber.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrubber.step = 0.01
	scrubber.value_changed.connect(seek)
	controls.add_child(scrubber)
	clock = Label.new()
	controls.add_child(clock)
	var skip := Button.new()
	skip.text = "Skip"
	skip.pressed.connect(skip_study)
	controls.add_child(skip)
	status = Label.new()
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	status.offset_left = 24
	status.offset_top = -32
	status.offset_bottom = -10
	status.add_theme_font_size_override("font_size", 12)
	status.modulate = Color(0.5, 0.65, 0.7)
	status.text = "Space: pause/resume | Esc: skip | Scratch voices / audio-driven jaw study | Campaign unchanged"
	ui.add_child(status)
	review_controls.append(status)

func set_presentation_mode() -> void:
	for control: Control in review_controls:
		control.hide()
	study_title.text = "ASH MERIDIAN  /  LAST LIGHT                                     LOOK DEVELOPMENT / SCRATCH PERFORMANCE"
	study_title.modulate.a = 0.65
	bottom_bar.offset_top = -42
	caption_panel.offset_top = -122
	caption_panel.offset_bottom = -46

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		skip_study()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_SPACE:
		toggle_playback()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not ready_for_review:
		return
	if playing:
		position_seconds = minf(duration, position_seconds + delta)
		if position_seconds >= duration:
			skip_study()
		else:
			_update_frame()

func pause() -> void:
	playing = false
	if is_instance_valid(voice):
		voice.stream_paused = true
	if is_instance_valid(play_button):
		play_button.text = "Play"

func toggle_playback() -> void:
	if not ready_for_review:
		return
	if playing:
		pause()
		return
	if finished:
		seek(0.0)
	playing = true
	voice.stream_paused = false
	play_button.text = "Pause"
	_sync_dialogue()

func _stop_voice() -> void:
	if is_instance_valid(voice):
		voice.stop()
		voice.stream_paused = false
		voice.stream = null
	active_id = ""

func seek(seconds: float) -> void:
	if not ready_for_review:
		return
	_stop_voice()
	position_seconds = clampf(seconds, 0.0, duration)
	finished = position_seconds >= duration
	_update_frame()

func skip_study() -> void:
	pause()
	seek(duration)

func _sync_dialogue() -> void:
	var current: Dictionary = {}
	for line: Dictionary in lines:
		if position_seconds >= float(line.at) and position_seconds < float(line.at) + float(line.seconds):
			current = line
			break
	speaker.text = str(current.get("speaker", ""))
	subtitle.text = str(current.get("text", ""))
	if not playing or mute.button_pressed or current.is_empty():
		if playing and (mute.button_pressed or current.is_empty()):
			_stop_voice()
		return
	if active_id != current.id:
		_stop_voice()
		active_id = current.id
		voice.stream = clips[active_id]
		voice.play(position_seconds - float(current.at))

func _pulse(time: float, start: float, end: float) -> float:
	return smoothstep(start, start + 0.7, time) * (1.0 - smoothstep(end - 0.7, end, time))

func _update_frame() -> void:
	var t := position_seconds
	_animate_actor(actors.MARK, t, true)
	_animate_actor(actors.JASON, t, false)
	device.position = Vector3(0.28, TABLE_TOP + 0.018, lerpf(-0.34, -0.12, smoothstep(15, 17, t)))
	device.rotation.y = lerpf(0.2, -0.12, smoothstep(15, 17, t))
	transfer_label.text = "COORDINATES\nHOLD TO SEND" if t < 15 else "TRANSFER\nCOMPLETE"
	transfer_label.modulate = AMBER if t < 15 else CYAN
	for i in range(traffic.size()):
		traffic[i].position = Vector3(11 + i * 5, 1.5 + i * 1.5, fposmod(t * (0.32 + i * 0.1) + i * 8, 26) - 13)
	_update_camera(t)
	_sync_dialogue()
	scrubber.max_value = duration
	scrubber.set_value_no_signal(t)
	clock.text = "%d:%02d / %d:%02d" % [int(t) / 60, int(t) % 60, int(duration) / 60, int(duration) % 60]
	if finished:
		speaker.text = "END OF BAR STUDY"
		subtitle.text = "Departure and ring approach remain separate production work."

func _animate_actor(actor: Dictionary, t: float, is_mark: bool) -> void:
	var body: Node3D = actor.body
	var head: Node3D = actor.head
	var rise := _pulse(t, 48, 53) * 0.09 if not is_mark else 0.0
	body.position.y = rise + sin(t * 1.35) * 0.003
	body.rotation.x = -0.04 if is_mark else 0.02
	var avoidance := _pulse(t, 26, 38) if is_mark else _pulse(t, 44, 48)
	head.rotation = Vector3(0.025 + avoidance * 0.12, avoidance * -0.18, sin(t * 0.45) * 0.012)
	if is_mark:
		head.rotation.x += _pulse(t, 19, 23) * -0.055
	var features: Dictionary = actor.features
	var phase := fposmod(t + (0.0 if is_mark else 1.43), 4.7)
	var blink := smoothstep(0.0, 0.065, phase) * (1.0 - smoothstep(0.09, 0.18, phase))
	for eye: Node3D in features.eyes:
		eye.scale.y = maxf(0.06, 0.84 - blink * 0.8)
	var concern := _pulse(t, 18, 38) if is_mark else _pulse(t, 23, 28)
	for i in range(features.brows.size()):
		var brow: Node3D = features.brows[i]
		brow.rotation.z = (1 if i == 0 else -1) * concern * 0.13
		brow.position.y = 0.054 + concern * 0.002
	var speech := speech_amount("MARK" if is_mark else "JASON", t)
	(features.cavity as Node3D).scale.y = 0.003 + speech * 0.016
	(features.lower_lip as Node3D).position.y = -0.004 - speech * 0.009
	(features.upper_lip as Node3D).position.y = 0.002 + speech * 0.0015
	(features.chin as Node3D).position.y = -0.126 - speech * 0.003
	var chair: Node3D = actor.chair
	chair.position.z = -rise * 0.5
	for index in range(actor.arms.size()):
		var arm: Dictionary = actor.arms[index]
		var side := float(arm.side)
		var pose := _arm_pose(side, rise)
		var shoulder: Vector3 = pose.shoulder
		var elbow: Vector3 = pose.elbow
		var wrist: Vector3 = pose.wrist
		_orient_segment(arm.upper, shoulder, elbow)
		_orient_segment(arm.lower, elbow, wrist)
		(arm.lower as Node3D).scale.y = elbow.distance_to(wrist)
		(arm.upper as Node3D).scale.y = shoulder.distance_to(elbow)
		(arm.elbow as Node3D).position = elbow
		(arm.hand as Node3D).position = wrist
		arm.pose = pose
		actor.arms[index] = arm

func speech_amount(identity: String, seconds: float) -> float:
	for line: Dictionary in lines:
		var local := seconds - float(line.at)
		if line.speaker != identity or local < 0.0 or local >= float(line.seconds):
			continue
		var envelope: Dictionary = speech_envelopes[line.id]
		var samples: Array = envelope.samples
		var index := local * float(envelope.hz)
		var first := mini(int(index), samples.size() - 1)
		var second := mini(first + 1, samples.size() - 1)
		return lerpf(float(samples[first]), float(samples[second]), fposmod(index, 1.0))
	return 0.0

func _update_camera(t: float) -> void:
	var point: Vector3
	var target: Vector3
	var lens := 42.0
	if t < 10:
		point = Vector3(-1.55, 1.73, 2.55).lerp(Vector3(-1.35, 1.68, 2.3), smoothstep(0, 10, t))
		target = Vector3(0, 1.22, -0.5)
	elif t < 17.8:
		point = Vector3(-1.1, 1.8, 1.35)
		target = Vector3(0.08, 1.17, -0.65)
	elif t < 23.5:
		point = Vector3(-0.53, 1.65, 0.6).lerp(Vector3(-0.48, 1.64, 0.48), smoothstep(17.8, 23.5, t))
		target = Vector3(0, 1.56, -0.95)
		lens = 35
	elif t < 26.4:
		point = Vector3(-0.7, 1.62, -0.65)
		target = Vector3(0, 1.52, 0.94)
		lens = 38
	elif t < 38:
		point = Vector3(-0.65, 1.67, 0.8)
		target = Vector3(0, 1.51, -0.97)
		lens = 36
	elif t < 44.8:
		point = Vector3(-0.68, 1.62, -0.7)
		target = Vector3(0, 1.52, 0.96)
		lens = 37
	elif t < 48:
		point = Vector3(-0.55, 1.65, 0.65)
		target = Vector3(0, 1.53, -0.97)
		lens = 35
	elif t < 55.8:
		point = Vector3(-2.6, 1.7, 1.7)
		target = Vector3(0, 1.18, 0)
		lens = 44
	elif t < 63:
		point = Vector3(-0.7, 1.64, 0.9)
		target = Vector3(0, 1.48, -0.97)
		lens = 38
	elif t < 66.8:
		point = Vector3(-0.7, 1.63, -0.65)
		target = Vector3(0, 1.53, 0.97)
		lens = 38
	elif t < 73.8:
		point = Vector3(-1.1, 1.7, 1.4)
		target = Vector3(0.15, 1.26, -0.5)
	elif t < 81:
		point = Vector3(-0.53, 1.65, 0.6).lerp(Vector3(-0.46, 1.64, 0.45), smoothstep(73.8, 81, t))
		target = Vector3(0, 1.54, -0.97)
		lens = 35
	else:
		point = Vector3(-2.6, 1.7, 1.7)
		target = Vector3(0, 1.18, 0)
	camera.position = point
	camera.look_at(target)
	camera.fov = lens

func lap_rest_table_edge_clearance() -> float:
	var clearance := INF
	for part: MeshInstance3D in contact_meshes:
		var bounds := part.get_aabb()
		var min_x := INF
		var max_x := -INF
		var min_z := INF
		var max_z := -INF
		for i in range(8):
			var corner := part.global_transform * bounds.get_endpoint(i)
			min_x = minf(min_x, corner.x)
			max_x = maxf(max_x, corner.x)
			min_z = minf(min_z, corner.z)
			max_z = maxf(max_z, corner.z)
		var x_gap := maxf(maxf(-0.925 - max_x, min_x - 0.925), 0.0)
		var z_gap := maxf(maxf(-0.67 - max_z, min_z - 0.67), 0.0)
		clearance = minf(clearance, Vector2(x_gap, z_gap).length())
	return clearance

func _capture() -> void:
	if capture_saved:
		return
	capture_frames += 1
	if capture_frames < 8 or not ready_for_review:
		return
	capture_saved = true
	var error := get_viewport().get_texture().get_image().save_png(capture_path)
	if error != OK:
		_fail("Cannot save review capture: " + error_string(error))
		get_tree().quit(1)
	else:
		print("BAR_STUDY_CAPTURED: ", capture_path)
		get_tree().quit()

func _exit_tree() -> void:
	_stop_voice()
	clips.clear()
