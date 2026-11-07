extends Node2D

const FACE_PATH := "res://assets/ai_face/alien_face.json"
var data: Dictionary
var feature_weights: Dictionary = {}
var nfeat := 0
var time := 0.0
var reduced_motion := false
var voice_level := 0.0
var mode := "idle"
var blink_enabled := true
var triangle_indices := PackedInt32Array()
var expression := "idle"

func set_expression(value: String) -> void:
	expression = value

func _ready() -> void:
	var parser := JSON.new()
	var error := parser.parse(FileAccess.get_file_as_string(FACE_PATH))
	if error != OK or not parser.data is Dictionary:
		push_error("Cannot parse detailed Narcean face: " + FACE_PATH)
		return
	data = parser.data
	if data.get("format") != "ash_meridian_ai_face" or data.get("verts", []).size() != data.get("jaw_w", []).size() or data.get("verts", []).size() != data.get("upper_w", []).size():
		push_error("Invalid detailed Narcean face geometry: " + FACE_PATH)
		data = {}
		return
	nfeat = data.features.size()
	for triangle in data.tris:
		triangle_indices.append_array(PackedInt32Array(triangle))
	for name in data.features:
		var values := PackedVector2Array()
		for point in data.features[name]:
			values.append(weights(Vector2(point[0], point[1])))
		feature_weights[name] = values

func weights(point: Vector2) -> Vector2:
	var distance_from_mouth: float = point.y - data.mouth_y
	var latitude := absf(point.x - 500)
	var half_width: float = data.mouth_hw
	var jaw := 0.0
	var upper := 0.0
	if distance_from_mouth >= -1:
		var lips := sqrt(maxf(0, 1 - pow(latitude / half_width, 2)))
		var rigid := clampf((215 - latitude) / 95, 0, 1)
		rigid = smoothstep(0, 1, rigid)
		var blend := smoothstep(0, 45, distance_from_mouth)
		jaw = lerpf(lips, rigid, blend) * clampf((distance_from_mouth + 3) / 8, 0, 1)
	else:
		upper = sqrt(maxf(0, 1 - pow(latitude / (half_width * 1.05), 2))) * maxf(0, 1 + distance_from_mouth / 50)
	return Vector2(jaw, upper)

func set_time(seconds: float) -> void:
	time = maxf(0, seconds)
	queue_redraw()

func set_mode(value: String) -> void:
	mode = value

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value

func set_voice_level(value: float) -> void:
	voice_level = clampf(value, 0, 1)

func blink_amount() -> float:
	if not blink_enabled or reduced_motion:
		return 0
	var phase := fmod(time, 4.7)
	return maxf(0, 1 - absf(phase - 0.1) / 0.1) if phase < 0.2 else 0.0

func posed(point: Vector2, weight: Vector2) -> Vector2:
	var amount := voice_level if mode == "talk" else 0.0
	if reduced_motion:
		amount = 0
	var latitude := point.x - 500
	if not reduced_motion:
		var eye_region := maxf(0, 1 - absf(point.y - 445) / 65) * maxf(0, 1 - absf(absf(latitude) - 100) / 100)
		if expression == "shock":
			point.y -= eye_region * 18
		elif expression in ["curse", "threat"]:
			point.y += eye_region * 12 * maxf(0, 1 - absf(latitude) / 190)
	var corner := maxf(0, 1 - absf(absf(latitude) - 75) / 55) * maxf(0, 1 - absf(point.y - data.mouth_y) / 30)
	point.x += signf(latitude) * data.corner_push * amount * corner
	point.y += data.jaw_drop * amount * weight.x - data.upper_lift * amount * weight.y
	var breath := 1.0 if reduced_motion else 1 + sin(time * 1.4) * 0.006
	var local := (point - Vector2(data.rest_focus[0], data.rest_focus[1])) * 0.3 * breath
	if not reduced_motion:
		var intensity := 1.0 if expression != "idle" else 0.25
		local.x *= 1 + sin(time * 1.3) * 0.025 * intensity
		local = local.rotated(sin(time * 1.7) * 0.035 * intensity)
		local += Vector2(sin(time * 0.9) * 2, sin(time * 2.3) * 2 * intensity)
	return local + Vector2(150, 165)

func _draw() -> void:
	if data.is_empty():
		return
	var vertices := PackedVector2Array()
	var colours := PackedColorArray()
	var count: int = data.verts.size()
	for index in range(count):
		var source := Vector2(data.verts[index][0], data.verts[index][1])
		vertices.append(posed(source, Vector2(data.jaw_w[index], data.upper_w[index])))
		var height: float = data.height[index]
		var shade := clampf(0.35 + height * 0.45 + (600 - source.x) / 900, 0.18, 1)
		colours.append(Color(0.015 * shade, 0.38 * shade, 0.62 * shade, 0.92))
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), triangle_indices, vertices, colours)
	var lines := PackedVector2Array()
	for edge in data.edges:
		lines.append(vertices[edge[0]])
		lines.append(vertices[edge[1]])
	draw_multiline(lines, Color(0.16, 0.7, 0.95, 0.13), 3, true)
	draw_multiline(lines, Color(0.3, 0.84, 1, 0.65), 0.65, true)
	if blink_amount() > 0:
		for name in ["eye_l", "eye_r"]:
			var eyelid := PackedVector2Array()
			for point in data.features[name]:
				eyelid.append(posed(Vector2(point[0], point[1]), Vector2.ZERO))
			draw_colored_polygon(eyelid, Color(0.02, 0.27, 0.43, blink_amount()))
	for name in data.features:
		var points := PackedVector2Array()
		for index in range(data.features[name].size()):
			var source := Vector2(data.features[name][index][0], data.features[name][index][1])
			if name in ["eye_l", "eye_r", "lid_l", "lid_r"]:
				source.y = 463 + (source.y - 463) * (1 - blink_amount())
			points.append(posed(source, feature_weights[name][index]))
		var width := 1.6 if name in data.bold_features else 0.9
		draw_polyline(points, Color(0.12, 0.8, 1, 0.12), 5, true)
		draw_polyline(points, Color(0.82, 0.98, 1), width, true)
	if blink_amount() < 0.5:
		for iris in data.irises:
			var drift := Vector2.ZERO if reduced_motion else Vector2(sin(time * 0.55) * 3, cos(time * 0.41) * 2)
			var centre := posed(Vector2(iris[0], iris[1]) + drift, Vector2.ZERO)
			draw_arc(centre, iris[2] * 0.3, 0, TAU, 32, Color(0.6, 1, 0.93), 1.2, true)
			draw_arc(centre, iris[2] * 0.126, 0, TAU, 24, Color(0.6, 1, 0.93), 1, true)
	for y in range(25, 310, 4):
		draw_line(Vector2(45, y), Vector2(255, y), Color(0, 0.02, 0.03, 0.13), 1)
