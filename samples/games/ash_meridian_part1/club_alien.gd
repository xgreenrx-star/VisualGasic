extends Node3D

const DATA := "res://assets/ai_face/club_alien_dialogue.json"
const VOICES := "res://assets/audio/club/alien/"
var city: Node
var dialogue: Dictionary
var section := "intro"
var index := -1
var clock := 0.0
var greeted := false
var near := false
var player: AudioStreamPlayer3D
var face_materials: Array[ShaderMaterial] = []
var faces: Array[MeshInstance3D] = []
var subtitle := ""
var subtitle_left := 0.0
var head_yaw := 0.0
var head_pitch := 0.0

func _voices_enabled() -> bool:
	var ancestor: Node = city
	while ancestor != null:
		for property: Dictionary in ancestor.get_property_list():
			if property["name"] == "opt_orac_voice":
				return bool(ancestor.get("opt_orac_voice"))
		ancestor = ancestor.get_parent()
	return true

func _return_section(state: Dictionary) -> String:
	if state.get("club_dock_visited", false) and not state.get("alien_dock_discussed", false):
		return "returned"
	return "repeat"

func setup(owner_city: Node) -> void:
	city = owner_city
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(DATA)) != OK:
		push_error("Alien dialogue could not be parsed: " + json.get_error_message())
		return
	dialogue = json.data
	player = AudioStreamPlayer3D.new()
	player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	player.unit_size = 5.0
	player.max_distance = 15.0
	player.position = Vector3(-3.2, 2.7, 22.8)
	add_child(player)
	_build_face()

func _feature_point(data: Dictionary, point: Vector2) -> Vector3:
	var nearest := 0
	var distance := INF
	for i in data["verts"].size():
		var xy: Array = data["verts"][i]
		var candidate := point.distance_squared_to(Vector2(xy[0], xy[1]))
		if candidate < distance:
			nearest = i
			distance = candidate
	return Vector3((point.x - 500.0) * 0.0032, (490.0 - point.y) * 0.0032,
		-float(data["height"][nearest]) * 0.35 - 0.012)

func _append_hair(vertices: PackedVector3Array, uvs: PackedVector2Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77124
	# Full, unruly crown and swept-out sides share the tracked wire surface.
	for strand in range(420):
		var side := -1.0 if strand % 2 == 0 else 1.0
		var crown := strand < 160
		var angle := rng.randf_range(0.02, 0.65) if crown else rng.randf_range(0.55, 1.62)
		var root_point := Vector3(side * sin(angle) * 0.73, cos(angle) * 1.25,
			rng.randf_range(-0.02, 0.32))
		var spread := rng.randf_range(0.18, 0.48) if crown else rng.randf_range(0.35, 0.78)
		var lift := rng.randf_range(0.3, 0.62)
		var tip := root_point + Vector3(side * spread, rng.randf_range(-0.08, 0.42),
			rng.randf_range(-0.14, 0.28))
		var bend := root_point + Vector3(side * spread * 0.8, lift, -0.07)
		var previous := root_point
		for segment in range(1, 11):
			var t := segment / 10.0
			var point := (1.0 - t) * (1.0 - t) * root_point + 2.0 * (1.0 - t) * t * bend + t * t * tip
			point.y += sin(t * TAU * 1.5 + strand) * 0.025 * t
			vertices.append(previous)
			vertices.append(point)
			uvs.append(Vector2(0.5, 0.2))
			uvs.append(Vector2(0.5, 0.2))
			previous = point

func _build_face() -> void:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string("res://assets/ai_face/human_face.json")) != OK:
		push_error("Alien human hologram asset cannot be parsed.")
		return
	var data: Dictionary = json.data
	for wire in [false, true]:
		var vertices := PackedVector3Array()
		var uvs := PackedVector2Array()
		var elements: Array = data["edges"] if wire else data["tris"]
		for element: Array in elements:
			for point_index: int in element:
				var xy: Array = data["verts"][point_index]
				vertices.append(Vector3((float(xy[0]) - 500.0) * 0.0032,
					(490.0 - float(xy[1])) * 0.0032, -float(data["height"][point_index]) * 0.35))
				uvs.append(Vector2(float(xy[0]), float(xy[1])) / 1000.0)
		if wire:
			var features: Array = data["features"].values()
			for iris: Array in data["irises"]:
				var ring := []
				for step in range(25):
					var angle := TAU * step / 24.0
					ring.append([iris[0] + cos(angle) * iris[2], iris[1] + sin(angle) * iris[2]])
				features.append(ring)
			for feature: Array in features:
				for segment in range(feature.size() - 1):
					for endpoint in [segment, segment + 1]:
						var xy: Array = feature[endpoint]
						var point := Vector2(xy[0], xy[1])
						vertices.append(_feature_point(data, point))
						uvs.append(point / 1000.0)
			_append_hair(vertices, uvs)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES if wire else Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/club_alien.gdshader")
		material.set_shader_parameter("wire", wire)
		face_materials.append(material)
		var face := MeshInstance3D.new()
		face.name = "HumanHologramWire" if wire else "HumanHologram"
		face.mesh = mesh
		face.material_override = material
		face.position = Vector3(-3.2, 2.7, 22.8)
		add_child(face)
		faces.append(face)

func tick(delta: float) -> void:
	clock += delta
	near = city.get("position_xz").distance_to(Vector2(-3.2, 20.8)) < 4.0
	var in_room: bool = city.get("position_xz").y > 16.3
	subtitle_left = maxf(0.0, subtitle_left - delta)
	if not in_room:
		player.stop()
		if city.get("message") == subtitle:
			city.set("message_left", 0.0)
		subtitle_left = 0.0
	if not _voices_enabled():
		player.stop()
	if near and not greeted:
		greeted = true
		if not city.get("stratum").get("alien_english", false):
			advance()
	var mouth := 0.0
	if player.playing and subtitle.begins_with("ALIEN:"):
		mouth = 0.22 + 0.22 * sin(clock * 13.0) + 0.12 * sin(clock * 23.0)
	for material in face_materials:
		material.set_shader_parameter("clock", clock)
		material.set_shader_parameter("mouth", maxf(0.0, mouth))
	var toward: Vector2 = city.get("position_xz") - Vector2(-3.2, 22.8)
	var target_yaw := 0.0
	var target_pitch := 0.0
	if in_room and toward.length_squared() > 0.01:
		target_yaw = clampf(atan2(-toward.x, -toward.y), -1.35, 1.35)
		var eye_y := 1.7 + float(city.get("stratum").get("foot_y", 0.0))
		target_pitch = clampf(atan2(eye_y - 2.7, toward.length()), -0.5, 0.35)
	var follow := 1.0 - exp(-5.0 * maxf(delta, 0.0))
	head_yaw = lerp_angle(head_yaw, target_yaw, follow)
	head_pitch = lerp_angle(head_pitch, target_pitch, follow)
	for face in faces:
		face.rotation = Vector3(head_pitch, head_yaw, 0.0)
		face.position.y = 2.7 + sin(clock * 0.6) * 0.015
	if in_room and subtitle_left > 0.0:
		city.set("message", subtitle)
		city.set("message_left", subtitle_left)

func advance() -> void:
	if dialogue.is_empty():
		city.call("notify", "ORAC: The room's resident intelligence is not responding.")
		return
	var state: Dictionary = city.get("stratum")
	if index < 0:
		if state.get("alien_english", false):
			if not state.get("narcean_lexicon", false):
				section = "intro"
				index = 4
			else:
				section = _return_section(state)
	index += 1
	if index >= dialogue[section].size():
		section = _return_section(state)
		index = 0
	var line: Dictionary = dialogue[section][index]
	player.position = Vector3(-3.2, 2.7, 22.8)
	if line["speaker"] != "ALIEN":
		var listener: Vector2 = city.get("position_xz")
		player.position = Vector3(listener.x, 1.7, listener.y)
	if line.get("learn_english", false):
		state["alien_english"] = true
	if line.get("grant_lexicon", false):
		state["narcean_lexicon"] = true
	if line.get("activate_pad", false):
		state["club_pad_activated"] = true
	if section == "returned" and index == 3:
		state["alien_dock_discussed"] = true
	var path := VOICES + section + "_" + str(index) + ".ogg"
	player.stop()
	if not ResourceLoader.exists(path):
		push_error("Missing Alien encounter speech: " + path)
		subtitle_left = 8.0
	else:
		player.stream = load(path)
		if _voices_enabled():
			player.play()
		subtitle_left = maxf(5.0, player.stream.get_length() + 1.0)
	subtitle = line["caption"]
	city.call("notify", subtitle)
	city.set("message_left", subtitle_left)

func prompt() -> String:
	if near:
		return "ALIEN HOLOGRAM / F: CONTINUE CONVERSATION"
	return ""
