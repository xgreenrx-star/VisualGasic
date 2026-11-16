extends Node

const CYAN := Color(0.18, 0.86, 1.0)
const PINK := Color(1.0, 0.24, 0.78)
const KEYS := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_W, KEY_A, KEY_S, KEY_D, KEY_ENTER, KEY_SPACE, KEY_ESCAPE, KEY_F, KEY_E, KEY_V, KEY_BACKSPACE, KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9]

var viewport: SubViewport
var camera: Camera3D
var world_mesh: MeshInstance3D
var frame_mesh: MeshInstance3D
var line_material: ShaderMaterial
var face_material: StandardMaterial3D
var held: Dictionary = {}
var taps: Dictionary = {}
var vertices := PackedVector3Array()
var colors := PackedColorArray()
var edges := PackedVector3Array()
var edge_colors := PackedColorArray()
var yard_key := ""
var building_yard := false
var rebuild_count := 0
var cockpit_view: SubViewport
var buggy_view: SubViewport
var ship_instruments: Node2D
var buggy_instruments: Node2D
var stars: Node2D
var clouds: MeshInstance3D
var city2: Node3D
var city2_output: SubViewport
var city2_antialiasing := Viewport.MSAA_2X
var city3: Node3D
var city3_output: SubViewport
var city3_antialiasing := Viewport.MSAA_2X
var backlight_city: Node3D

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	camera = Camera3D.new()
	camera.near = 0.1
	camera.current = true
	viewport.add_child(camera)
	world_mesh = MeshInstance3D.new()
	frame_mesh = MeshInstance3D.new()
	viewport.add_child(world_mesh)
	viewport.add_child(frame_mesh)
	face_material = StandardMaterial3D.new()
	face_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	face_material.vertex_color_use_as_albedo = true
	face_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	line_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float line_width = 1.6;
void vertex() {
	vec4 p = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 q = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX + NORMAL, 1.0);
	vec2 direction = (q.xy / max(q.w, 0.001) - p.xy / max(p.w, 0.001)) * vec2(960.0, 540.0);
	vec2 across = vec2(-direction.y, direction.x) / max(length(direction), 0.001);
	p.xy += across * UV.x * line_width / vec2(960.0, 540.0) * p.w;
	POSITION = p;
	POSITION.z += 0.00002 * POSITION.w;
}
void fragment() { ALBEDO = COLOR.rgb * 1.25; }
"""
	line_material.shader = shader
	var halo := ShaderMaterial.new()
	var halo_shader := Shader.new()
	halo_shader.code = shader.code.replace("unshaded, cull_disabled, depth_draw_never", "unshaded, cull_disabled, blend_add, depth_draw_never").replace(
		"line_width = 1.6", "line_width = 5.0").replace("ALBEDO = COLOR.rgb * 1.25;", "ALBEDO = COLOR.rgb; ALPHA = 0.12;")
	halo.shader = halo_shader
	line_material.next_pass = halo
	cockpit_view = SubViewport.new()
	cockpit_view.size = Vector2i(960, 540)
	cockpit_view.transparent_bg = true
	cockpit_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(cockpit_view)
	stars = Node2D.new()
	stars.set_script(load("res://cockpit_stars.gd"))
	cockpit_view.add_child(stars)
	_add_cached_art(cockpit_view, "res://cockpit_art.gd")
	ship_instruments = Node2D.new()
	ship_instruments.set_script(load("res://cockpit_instruments.gd"))
	cockpit_view.add_child(ship_instruments)
	buggy_view = SubViewport.new()
	buggy_view.size = Vector2i(960, 540)
	buggy_view.transparent_bg = true
	buggy_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(buggy_view)
	_add_cached_art(buggy_view, "res://buggy_art.gd")
	buggy_instruments = Node2D.new()
	buggy_instruments.set_script(load("res://cockpit_instruments.gd"))
	buggy_instruments.buggy = true
	buggy_view.add_child(buggy_instruments)
	_create_clouds()

func _add_cached_art(target: SubViewport, script_path: String) -> void:
	var art_view := SubViewport.new()
	art_view.size = Vector2i(960, 540)
	art_view.transparent_bg = true
	art_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(art_view)
	var art := Node2D.new()
	art.set_script(load(script_path))
	art_view.add_child(art)
	var canvas := TextureRect.new()
	canvas.texture = art_view.get_texture()
	canvas.size = Vector2(960, 540)
	target.add_child(canvas)

func cockpit_texture(t: float, speed: float, height: float, alert: float) -> Texture2D:
	stars.time = t
	stars.queue_redraw()
	ship_instruments.update_readings(t, speed, 0, height, alert, 0)
	cockpit_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	return cockpit_view.get_texture()

func buggy_texture(t: float, speed: float, heading: float, distance: float, destination := 368.0, top_speed := 16.0) -> Texture2D:
	buggy_instruments.update_readings(t, speed, heading, 0, 0, distance, destination, top_speed)
	buggy_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	return buggy_view.get_texture()

func _create_clouds() -> void:
	clouds = MeshInstance3D.new()
	var mesh := ArrayMesh.new()
	var cloud_vertices := PackedVector3Array()
	var cloud_colors := PackedColorArray()
	var cloud_normals := PackedVector3Array()
	var sphere := SphereMesh.new()
	sphere.radial_segments = 16
	sphere.rings = 8
	var sphere_arrays := sphere.get_mesh_arrays()
	var points: PackedVector3Array = sphere_arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = sphere_arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = sphere_arrays[Mesh.ARRAY_INDEX]
	for i in 36:
		var side := -1.0 if i % 2 == 0 else 1.0
		var center := Vector3(side * (20 + sin(i * 2.4) * 4), 22 - i * 0.48, 30 + i * 16)
		for puff in 3:
			for index in indices:
				cloud_vertices.append(center + Vector3(puff * 4 - 4, sin(puff * 2.0), 0) + points[index] * Vector3(12, 3.5, 6))
				cloud_normals.append((normals[index] / Vector3(12, 3.5, 6)).normalized())
				cloud_colors.append(Color(0.16 + puff * 0.006, 0.21 + puff * 0.008, 0.28 + puff * 0.01))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = cloud_vertices
	arrays[Mesh.ARRAY_NORMAL] = cloud_normals
	arrays[Mesh.ARRAY_COLOR] = cloud_colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = COLOR.rgb * (0.5 + 0.5 * max(NORMAL.y, 0.0));
	ALPHA = smoothstep(0.0, 0.6, facing) * 0.5;
}
"""
	material.shader = shader
	mesh.surface_set_material(0, material)
	clouds.mesh = mesh
	clouds.visible = false
	viewport.add_child(clouds)

func landing_clouds() -> void:
	clouds.visible = true

func sample_input() -> void:
	taps.clear()
	for code in KEYS:
		var down := Input.is_key_pressed(code) or Input.is_physical_key_pressed(code)
		taps[code] = down and not held.get(code, false)
		held[code] = down

func menu_tap(code: int) -> bool:
	var hit: bool = taps.get(code, false)
	taps[code] = false
	return hit

func begin_frame(backlight_active := false) -> void:
	vertices.clear()
	colors.clear()
	edges.clear()
	edge_colors.clear()
	world_mesh.visible = false
	frame_mesh.visible = false
	clouds.visible = false
	if not backlight_active:
		if camera.environment != null:
			camera.environment = null
		if not viewport.transparent_bg:
			viewport.transparent_bg = true
	if backlight_city != null:
		backlight_city.deactivate()
		if backlight_city.audio != null:
			if not backlight_active:
				backlight_city.audio.stop()
			else:
				backlight_city.audio.stream_paused = bool(get_parent().get("menu_on")) or bool(get_parent().get("dev_on"))
	if city2 != null:
		city2.visible = false
		city2_output.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if city3 != null:
		city3.visible = false
		city3_output.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func segment(a: Vector3, b: Vector3, color: Color) -> void:
	edges.append(a)
	edges.append(b)
	edge_colors.append(color)
	edge_colors.append(color)

func hoop(x: float, y: float, z: float, radius: float, color: Color) -> void:
	var center := Vector3(x, y, z)
	for i in 40:
		var a := TAU * i / 40.0
		var b := TAU * (i + 1) / 40.0
		segment(center + Vector3(cos(a), sin(a), 0) * radius, center + Vector3(cos(b), sin(b), 0) * radius, color)

func face(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	var ink := Color(color.r * 0.055, color.g * 0.055, color.b * 0.07, 1.0)
	for point in [a, b, c, a, c, d]:
		vertices.append(point)
		colors.append(ink)
	for pair in [[a, b], [b, c], [c, d], [d, a]]:
		segment(pair[0], pair[1], color)

func _mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, face_material)
	if not edges.is_empty():
		var line_vertices := PackedVector3Array()
		var line_normals := PackedVector3Array()
		var line_colors := PackedColorArray()
		var line_uvs := PackedVector2Array()
		for i in range(0, edges.size(), 2):
			for corner in [Vector2(0, -1), Vector2(0, 1), Vector2(1, 1), Vector2(0, -1), Vector2(1, 1), Vector2(1, -1)]:
				var index := i + int(corner.x)
				line_vertices.append(edges[index])
				line_normals.append(edges[i + 1] - edges[i])
				line_colors.append(edge_colors[index])
				line_uvs.append(Vector2(corner.y, 0))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = line_vertices
		arrays[Mesh.ARRAY_NORMAL] = line_normals
		arrays[Mesh.ARRAY_COLOR] = line_colors
		arrays[Mesh.ARRAY_TEX_UV] = line_uvs
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, line_material)
	return mesh

func begin_yard(key: String) -> bool:
	world_mesh.visible = true
	if yard_key == key and world_mesh.mesh != null:
		return false
	building_yard = true
	yard_key = key
	return true

func bleed_city() -> void:
	if not begin_yard("bleed-city"):
		return
	var city: Node = get_node_or_null("BleedCity")
	if city == null:
		city = load("res://bleed_city.gd").new()
		city.name = "BleedCity"
		add_child(city)
	city.build(self)
	end_yard()

func _ensure_city2() -> void:
	if city2 == null:
		city2 = load("res://bleed_city_2.gd").new()
		city2.name = "BleedCity2"
		viewport.add_child(city2)
		city2_output = SubViewport.new()
		city2_output.size = viewport.size
		city2_output.render_target_update_mode = SubViewport.UPDATE_DISABLED
		city2_output.disable_3d = true
		add_child(city2_output)
		var canvas := TextureRect.new()
		canvas.size = Vector2(viewport.size)
		canvas.texture = viewport.get_texture()
		var material := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = """shader_type canvas_item;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 bloom = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.78539816;
		vec2 direction = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE;
		vec3 near_color = texture(TEXTURE, UV + direction * 2.0).rgb;
		vec3 far_color = texture(TEXTURE, UV + direction * 5.0).rgb;
		bloom += max(near_color - vec3(0.2), vec3(0.0)) * 0.065;
		bloom += max(far_color - vec3(0.2), vec3(0.0)) * 0.035;
	}
	COLOR = vec4(source.rgb + bloom, 1.0);
}
"""
		material.shader = shader
		canvas.material = material
		city2_output.add_child(canvas)

func start_bleed_city2() -> void:
	_ensure_city2()
	city2.reset()

func tick_bleed_city2(delta: float) -> void:
	city2.tick(delta, self)

func bleed_city2(time: float, distance: float, detail: int) -> Texture2D:
	_ensure_city2()
	city2.visible = true
	city2_antialiasing = Viewport.MSAA_DISABLED if detail == 0 else (Viewport.MSAA_4X if detail == 2 else Viewport.MSAA_2X)
	city2.render(self, time, distance)
	if detail == 0:
		return viewport.get_texture()
	city2_output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return city2_output.get_texture()

func city2_driving() -> bool:
	return city2.driving and city2.inspection == 0

func city2_cockpit(time: float) -> Texture2D:
	return buggy_texture(time, city2.velocity, city2.heading, city2.position_xz.y, 154, 18)

func city2_status() -> String:
	return "AIR BOTTLES %d/3   V: STREET / DISTRICT / BUGGY" % city2.collected

func _ensure_city3() -> void:
	if city3 != null:
		return
	city3 = load("res://bleed_city_3.gd").new()
	city3.name = "BleedCity3"
	viewport.add_child(city3)
	city3.visible = false
	city3_output = SubViewport.new()
	city3_output.size = viewport.size
	city3_output.render_target_update_mode = SubViewport.UPDATE_DISABLED
	city3_output.disable_3d = true
	add_child(city3_output)
	var canvas := TextureRect.new()
	canvas.size = Vector2(viewport.size)
	canvas.texture = viewport.get_texture()
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 bloom = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.78539816;
		vec2 direction = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE;
		vec3 near_color = texture(TEXTURE, UV + direction * 2.0).rgb;
		vec3 far_color = texture(TEXTURE, UV + direction * 5.0).rgb;
		bloom += max(near_color - vec3(0.22), vec3(0.0)) * 0.05;
		bloom += max(far_color - vec3(0.22), vec3(0.0)) * 0.028;
	}
	COLOR = vec4(min(source.rgb + bloom, vec3(1.0)), 1.0);
}
"""
	material.shader = shader
	canvas.material = material
	city3_output.add_child(canvas)

func start_bleed_city3() -> void:
	_ensure_city3()
	city3.reset()

func tick_bleed_city3(delta: float) -> void:
	city3.tick(delta, self)

func bleed_city3(time: float, distance: float, detail: int) -> Texture2D:
	_ensure_city3()
	city3.visible = true
	city3_antialiasing = Viewport.MSAA_DISABLED if detail == 0 else (Viewport.MSAA_4X if detail == 2 else Viewport.MSAA_2X)
	city3.render(self, time, distance)
	if detail == 0:
		return viewport.get_texture()
	city3_output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return city3_output.get_texture()

func city3_driving() -> bool:
	return city3.driving and city3.inspection == 0

func city3_cockpit(time: float) -> Texture2D:
	return buggy_texture(time, city3.velocity, city3.heading, city3.position_xz.y, 124, 16)

func city3_status() -> String:
	return "AIR BOTTLES %d/3   V: STREET / DISTRICT / BUGGY" % city3.collected

func start_backlight_city() -> void:
	if backlight_city == null:
		backlight_city = load("res://backlight_exploration.gd").new()
		backlight_city.name = "BacklightCity"
		viewport.add_child(backlight_city)
	backlight_city.reset()

func tick_backlight_city(delta: float) -> void:
	backlight_city.tick(delta, self)

func draw_backlight_city(time: float, distance: float, detail: int) -> Texture2D:
	return backlight_city.render_style(self, time, distance, detail)

func backlight_driving() -> bool:
	return backlight_city.driving and backlight_city.inspection == 0 and backlight_city.place == "surface"

func backlight_cockpit(time: float) -> Texture2D:
	return buggy_texture(time, backlight_city.velocity, backlight_city.heading, backlight_city.position_xz.y, 420, 18)

func backlight_overlay() -> Texture2D:
	return backlight_city.hud_view.get_texture()

func backlight_status() -> String:
	return backlight_city.prompt()

func end_yard() -> void:
	world_mesh.mesh = _mesh()
	building_yard = false
	rebuild_count += 1
	vertices.clear()
	colors.clear()
	edges.clear()
	edge_colors.clear()

func present(x: float, y: float, z: float, yaw: float, pitch: float, distance: float) -> Texture2D:
	var antialiasing := Viewport.MSAA_DISABLED
	if backlight_city != null and backlight_city.visible:
		antialiasing = backlight_city.antialiasing
	elif city3 != null and city3.visible:
		antialiasing = city3_antialiasing
	elif city2 != null and city2.visible:
		antialiasing = city2_antialiasing
	if viewport.msaa_3d != antialiasing:
		viewport.msaa_3d = antialiasing
	var forward := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var right := Vector3.UP.cross(forward).normalized()
	camera.transform = Transform3D(Basis(right, forward.cross(right), -forward), Vector3(x, y, z))
	camera.fov = rad_to_deg(2.0 * atan(270.0 / 520.0))
	camera.far = maxf(distance, 50.0)
	if not edges.is_empty() or not vertices.is_empty():
		frame_mesh.mesh = _mesh()
		frame_mesh.visible = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return viewport.get_texture()

func box(origin: Vector3, size: Vector3, color: Color, transform := Transform3D.IDENTITY) -> void:
	var p: Array[Vector3] = []
	for offset in [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0),
			Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)]:
		p.append(transform * (origin + offset * size))
	for indices in [[0, 1, 2, 3], [4, 7, 6, 5], [0, 3, 7, 4], [1, 5, 6, 2], [3, 2, 6, 7], [0, 4, 5, 1]]:
		face(p[indices[0]], p[indices[1]], p[indices[2]], p[indices[3]], color)

func tower(x: float, z: float, w: float, h: float, side: float, kind: int, detail: int) -> void:
	var d := w * 0.72
	var outline := PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0), Vector2(w * 0.78, h * 0.14), Vector2(w * 0.78, h * 0.38),
		Vector2(w * 0.96, h * 0.42), Vector2(w * 0.96, h * 0.48), Vector2(w * 0.7, h * 0.48),
		Vector2(w * 0.7, h * 0.65), Vector2(w * 0.58, h * 0.65), Vector2(w * 0.58, h),
		Vector2(w * 0.43, h), Vector2(w * 0.43, h * (0.86 - kind * 0.03)),
		Vector2(w * 0.27, h * 0.8), Vector2(w * 0.27, h * 0.58), Vector2(w * 0.15, h * 0.58),
		Vector2(w * 0.15, h * 0.32), Vector2(w * 0.32, h * 0.25), Vector2(w * 0.32, h * 0.14)])
	_extrude(outline, d, CYAN, Transform3D(Basis.IDENTITY, Vector3(x, 0, z)))
	var mast := Vector3(x + w * 0.44, h, z + d * 0.48)
	segment(mast, mast + Vector3(0, 2.2 + kind, 0), CYAN)
	segment(mast + Vector3(-w * 0.16, -h * 0.2, 0), mast + Vector3(-w * 0.16, 1.0, 0), CYAN * 0.5)
	var street_x := x + w if side < 0 else x
	for dz in [0.0, d]:
		face(Vector3(street_x, 0, z + dz), Vector3(street_x - side * 2.0, 0, z + dz),
			Vector3(street_x, h * 0.25, z + dz), Vector3(street_x, h * 0.42, z + dz), CYAN * 0.65)
	if detail == 0:
		return
	for i in range(2 + detail * 2):
		var height := h * 0.18 + i * 0.22
		segment(Vector3(x + w * 0.36, height, z - 0.015), Vector3(x + w * 0.56, height, z - 0.015), CYAN * 0.65)
	var conduit_x := x + w * 0.67
	segment(Vector3(conduit_x, 0.1, z - 0.02), Vector3(conduit_x, h * 0.35, z - 0.02), CYAN)
	segment(Vector3(conduit_x, h * 0.35, z - 0.02), Vector3(conduit_x - w * 0.22, h * 0.44, z - 0.02), CYAN)
	segment(Vector3(conduit_x - w * 0.22, h * 0.44, z - 0.02), Vector3(conduit_x - w * 0.22, h * 0.82, z - 0.02), CYAN)
	for dz in [d * 0.2, d * 0.55]:
		segment(Vector3(street_x, h * 0.12, z + dz), Vector3(street_x, h * 0.3, z + dz), CYAN * 0.55)
		segment(Vector3(street_x, h * 0.3, z + dz), Vector3(street_x - side * w * 0.15, h * 0.4, z + dz), CYAN * 0.55)

func _extrude(outline: PackedVector2Array, depth: float, color: Color, transform: Transform3D) -> void:
	var indices := Geometry2D.triangulate_polygon(outline)
	for back in [0.0, depth]:
		for index in indices:
			var point := outline[index]
			vertices.append(transform * Vector3(point.x, point.y, back))
			colors.append(Color(color.r * 0.04, color.g * 0.045, color.b * 0.06))
	for i in outline.size():
		var p := outline[i]
		var q := outline[(i + 1) % outline.size()]
		face(transform * Vector3(p.x, p.y, 0), transform * Vector3(q.x, q.y, 0),
			transform * Vector3(q.x, q.y, depth), transform * Vector3(p.x, p.y, depth), color)

func _cylinder(center: Vector3, radius: float, length: float, axis: int, color: Color, transform: Transform3D) -> void:
	for i in 16:
		var a := TAU * i / 16.0
		var b := TAU * (i + 1) / 16.0
		var p := Vector3(0, cos(a), sin(a)) * radius if axis == 0 else Vector3(cos(a), 0, sin(a)) * radius
		var q := Vector3(0, cos(b), sin(b)) * radius if axis == 0 else Vector3(cos(b), 0, sin(b)) * radius
		var extent := Vector3(length, 0, 0) if axis == 0 else Vector3(0, length, 0)
		# Filled sides are independent of decorative coil rings.
		for point in [center + p, center + q, center + q + extent, center + p, center + q + extent, center + p + extent]:
			vertices.append(transform * point)
			colors.append(Color(0.008, 0.015, 0.022))
		for end in [Vector3.ZERO, extent]:
			for point in [center + end, center + p + end, center + q + end]:
				vertices.append(transform * point)
				colors.append(Color(0.008, 0.012, 0.019))
	_ring(center, radius, axis, color, transform)
	_ring(center + (Vector3(length, 0, 0) if axis == 0 else Vector3(0, length, 0)), radius, axis, color, transform)

func _ring(center: Vector3, radius: float, axis: int, color: Color, transform: Transform3D, spokes := false) -> void:
	for i in 20:
		var a := TAU * i / 20.0
		var b := TAU * (i + 1) / 20.0
		var p := Vector3(0, cos(a), sin(a)) if axis == 0 else Vector3(cos(a), 0, sin(a))
		var q := Vector3(0, cos(b), sin(b)) if axis == 0 else Vector3(cos(b), 0, sin(b))
		segment(transform * (center + p * radius), transform * (center + q * radius), color)
		if spokes and i % 4 == 0:
			segment(transform * (center + p * radius * 0.2), transform * (center + p * radius), color)

func turret(x: float, y: float, z: float, yaw: float) -> void:
	var transform := Transform3D(Basis(Vector3.UP, -yaw), Vector3(x, y, z))
	for side in [-1.0, 1.0]:
		for end in [-1.0, 1.0]:
			box(Vector3(-0.6 + end * 1.05, 0.03, side * 1.2 - 0.3), Vector3(1.1, 0.22, 0.6), PINK, transform)
	for i in 8:
		var a := TAU * i / 8.0
		var b := TAU * (i + 1) / 8.0
		var p := Vector3(cos(a), 0, sin(a))
		var q := Vector3(cos(b), 0, sin(b))
		face(transform * (p * 1.8), transform * (q * 1.8),
			transform * (q * 1.45 + Vector3.UP * 0.3), transform * (p * 1.45 + Vector3.UP * 0.3), PINK)
	_cylinder(Vector3(0, 0.3, 0), 0.6, 0.8, 1, PINK, transform)
	_ring(Vector3(0, 0.32, 0), 1.0, 1, CYAN, transform)
	_ring(Vector3(0, 0.45, 0), 0.72, 1, PINK, transform)
	for side in [-1.0, 1.0]:
		box(Vector3(-0.55, 0.8, side * 0.7 - 0.12), Vector3(1.15, 0.65, 0.24), PINK, transform)
		var housing := PackedVector2Array([Vector2(-0.8, 1.3), Vector2(0.85, 1.3), Vector2(0.85, 1.8),
			Vector2(0.55, 2.12), Vector2(-0.55, 2.12), Vector2(-0.8, 1.85)])
		_extrude(housing, 0.6, PINK, transform.translated_local(Vector3(0, 0, side * 0.58 - 0.3)))
		_cylinder(Vector3(0.8, 1.66, side * 0.58), 0.13, 1.5, 0, CYAN, transform)
		for rib in 5:
			_ring(Vector3(1.62 + rib * 0.12, 1.66, side * 0.58), 0.19, 0, CYAN, transform)
		_ring(Vector3(2.3, 1.66, side * 0.58), 0.15, 0, PINK, transform)
		_ring(Vector3(-0.52, 2.35, side * 0.64), 0.5, 0, CYAN, transform, true)
		_ring(Vector3(-0.52, 2.35, side * 0.64), 0.3, 0, CYAN, transform)
		segment(transform * Vector3(-0.52, 2.0, side * 0.64), transform * Vector3(-0.52, 2.35, side * 0.64), PINK)
	box(Vector3(-0.45, 1.4, -0.22), Vector3(1, 0.5, 0.44), PINK, transform)

func bridge(z: float) -> void:
	box(Vector3(-8.5, 4.8, z - 0.7), Vector3(17, 0.4, 1.4), CYAN * 0.65)
	for side in [-1.0, 1.0]:
		box(Vector3(side * 8.4 - 0.4, 0, z - 0.8), Vector3(0.8, 4.8, 1.6), CYAN * 0.7)
		for rib in 3:
			var previous := Vector3(side * 7.8, 0, z - 0.75 - rib * 0.06)
			for step in range(1, 17):
				var angle := step * PI * 0.5 / 16.0
				var point := Vector3(side * (7.8 - sin(angle) * 6.8), (1.0 - cos(angle)) * 4.5, previous.z)
				segment(previous, point, CYAN * (0.55 + rib * 0.2))
				previous = point
