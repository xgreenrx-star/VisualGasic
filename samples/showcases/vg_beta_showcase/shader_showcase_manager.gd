extends Node3D
## Three-scene shader spectacle for VG Beta Showcase.
##
## Scenes: Synth Grid (14s) -> Liquid Chrome (16s) -> Fault Cube (14.5s) = 44.5s total.
## Backrooms splits this into three portal visits via set_portal_segment(0..2) + begin_portal_play().
##
## Portal API: set_showcase_frozen, reset_for_portal, freeze_showcase_frame, resume_portal_preview.
## Standalone run (shader_showcase_main.tscn): auto-advances to about_vg_main after DEMO_DURATION.
## Headless: quits at DEMO_DURATION for scripted capture pipelines.

const SYNTH_SHADER_PATH := "res://shaders/synth_grid.gdshader"
const SKY_DAY_PATH := "res://shaders/procedural_sky_day.gdshader"
const SKY_SPACE_PATH := "res://shaders/procedural_sky_space.gdshader"
const SKY_FAULT_PATH := "res://shaders/procedural_sky_fault.gdshader"
const CHROME_SHADER_PATH := "res://shaders/chrome_metaball.gdshader"
const FAULT_SHADER_PATH := "res://shaders/fault_cube.gdshader"
const FAULT_CORONA_PATH := "res://shaders/fault_plasma_corona.gdshader"
const FAULT_ENERGY_RING_PATH := "res://shaders/fault_energy_ring.gdshader"
const SUN_SHADER_PATH := "res://shaders/showcase_sun.gdshader"
const MOON_SHADER_PATH := "res://shaders/showcase_moon.gdshader"
const NEXT_SCENE := "res://about_vg_main.tscn"

const SCENE_HOLDS: Array[float] = [14.0, 16.0, 14.5]
const DEMO_DURATION := 44.5
const CROSSFADE := 1.0
const SUN_DIVE_START := 11.0
const SUN_DIVE_DURATION := 3.0
const CHROME_UNDER_WHITE_START := 12.5
const SUN_WHITE_REVEAL := 1.0
const SUN_REST_POS := Vector3(28.0, 22.0, -34.0)
const MOON_DIVE_START := CHROME_UNDER_WHITE_START + 13.5
const MOON_DIVE_DURATION := 3.3
const FAULT_UNDER_WHITE_START := CHROME_UNDER_WHITE_START + 15.0
const MOON_WHITE_REVEAL := 1.0
const MOON_REST_POS := Vector3(-24.0, 20.0, -36.0)

enum SceneId { SYNTH_GRID, CHROME, FAULT_CUBE }

var environment_node: WorldEnvironment
var sky: Sky
var sky_mat_day: ShaderMaterial
var sky_mat_space: ShaderMaterial
var sky_mat_fault: ShaderMaterial
var sun_light: DirectionalLight3D
var camera_node: Camera3D
var synth_mesh: MeshInstance3D
var chrome_mesh: MeshInstance3D
var fault_mesh: MeshInstance3D
var fault_corona_mesh: MeshInstance3D
var fault_ring_meshes: Array[MeshInstance3D] = []
var fault_ring_mat: ShaderMaterial
var sun_mesh: MeshInstance3D
var sun_mat: ShaderMaterial
var moon_mesh: MeshInstance3D
var moon_mat: ShaderMaterial
var sun_overlay: ColorRect
var lorenz_cloud: Node3D
var meteors: Node3D
var hud_layer: CanvasLayer
var title_label: Label
var sub_label: Label
var timer_label: Label
var skip_label: Label

var demo_timer: float = 0.0
var current_scene: int = SceneId.SYNTH_GRID
var synth_mat: ShaderMaterial
var chrome_mat: ShaderMaterial
var fault_mat: ShaderMaterial
var fault_corona_mat: ShaderMaterial
var is_headless: bool = false
var _showcase_frozen := false
var _portal_segment := -1
var _portal_play_t := -1.0  # < 0 = preview (portal/zoom); >= 0 = fullscreen play elapsed


func _portal_mode() -> bool:
	return _portal_segment >= 0


func _portal_segment_duration() -> float:
	match _portal_segment:
		SceneId.SYNTH_GRID:
			return SCENE_HOLDS[0]
		SceneId.CHROME:
			return SCENE_HOLDS[1]
		SceneId.FAULT_CUBE:
			return SCENE_HOLDS[2]
		_:
			return DEMO_DURATION


func _portal_segment_local_time() -> float:
	match _portal_segment:
		SceneId.SYNTH_GRID:
			return demo_timer
		SceneId.CHROME:
			return demo_timer - CHROME_UNDER_WHITE_START
		SceneId.FAULT_CUBE:
			return demo_timer - FAULT_UNDER_WHITE_START
		_:
			return demo_timer


func set_portal_segment(segment: int) -> void:
	_portal_segment = segment
	_portal_play_t = -1.0


func begin_portal_play() -> void:
	if not _portal_mode():
		return
	_showcase_frozen = false
	_portal_play_t = 0.0
	match _portal_segment:
		SceneId.SYNTH_GRID:
			demo_timer = 0.0
			current_scene = SceneId.SYNTH_GRID
			set_scene_weights(1.0, 0.0, 0.0)
		SceneId.CHROME:
			demo_timer = CHROME_UNDER_WHITE_START
			current_scene = SceneId.CHROME
			set_scene_weights(0.0, 1.0, 0.0)
		_:
			demo_timer = FAULT_UNDER_WHITE_START
			current_scene = SceneId.FAULT_CUBE
			set_scene_weights(0.0, 0.0, 1.0)
	_apply_sky_for_scene()
	_apply_portal_environment()
	handle_scene_cycling()
	animate_camera()
	update_shader_uniforms()
	update_synth_sun()
	update_chrome_moon()
	if hud_layer:
		hud_layer.visible = true
	if sun_overlay:
		var layer := sun_overlay.get_parent()
		if layer is CanvasLayer:
			layer.visible = true
	update_hud()


func set_showcase_frozen(frozen: bool) -> void:
	_showcase_frozen = frozen
	if hud_layer:
		hud_layer.visible = not frozen
	if sun_overlay:
		var layer := sun_overlay.get_parent()
		if layer is CanvasLayer:
			layer.visible = not frozen
	if frozen:
		snap_preview_frame()


func freeze_showcase_frame() -> void:
	# Hold the last rendered PLAY frame — do not reset timer/camera (zoom-out shrink).
	_showcase_frozen = true
	if hud_layer:
		hud_layer.visible = false
	if sun_overlay:
		var layer := sun_overlay.get_parent()
		if layer is CanvasLayer:
			layer.visible = false


func resume_portal_preview() -> void:
	# Leave fullscreen play but keep animating in the portal (pull-back / window close).
	_showcase_frozen = false
	_portal_play_t = -1.0
	if hud_layer:
		hud_layer.visible = false
	if sun_overlay:
		var layer := sun_overlay.get_parent()
		if layer is CanvasLayer:
			layer.visible = false


func reset_for_portal() -> void:
	_showcase_frozen = false
	_portal_play_t = -1.0
	match _portal_segment:
		0:
			demo_timer = 0.0
			current_scene = SceneId.SYNTH_GRID
			set_scene_weights(1.0, 0.0, 0.0)
		1:
			demo_timer = CHROME_UNDER_WHITE_START
			current_scene = SceneId.CHROME
			set_scene_weights(0.0, 1.0, 0.0)
		2:
			demo_timer = FAULT_UNDER_WHITE_START
			current_scene = SceneId.FAULT_CUBE
			set_scene_weights(0.0, 0.0, 1.0)
		_:
			demo_timer = 0.0
			set_scene_weights(1.0, 0.0, 0.0)
	_apply_sky_for_scene()
	_apply_portal_environment()
	if hud_layer:
		hud_layer.visible = false
	if sun_overlay:
		var layer := sun_overlay.get_parent()
		if layer is CanvasLayer:
			layer.visible = false
	if camera_node:
		camera_node.current = true
	animate_camera()
	update_shader_uniforms()


func snap_preview_frame() -> void:
	demo_timer = 0.0
	set_scene_weights(1.0, 0.0, 0.0)
	_apply_sky_for_scene()
	_apply_portal_environment()
	if camera_node:
		camera_node.current = true
	animate_camera()
	update_shader_uniforms_preview()
	update_synth_sun()
	update_chrome_moon()
	update_fault_fx()


func update_shader_uniforms_preview() -> void:
	if synth_mat and synth_mesh.visible:
		synth_mat.set_shader_parameter("u_energy", 0.55)
		if meteors and meteors.has_method("get_grid_ripples"):
			synth_mat.set_shader_parameter("u_ripples", meteors.get_grid_ripples())


func _ready() -> void:
	is_headless = DisplayServer.get_name() == "headless"
	setup_cinematic_environment()
	setup_sun_light()
	setup_camera()
	create_synth_grid_scene()
	create_synth_sun()
	create_chrome_moon()
	create_chrome_scene()
	create_fault_fx_scene()
	create_fault_cube_scene()
	if not is_headless:
		add_child(preload("res://showcase_synth_audio.gd").new())
		lorenz_cloud = preload("res://showcase_lorenz_cloud.gd").new()
		add_child(lorenz_cloud)
		meteors = preload("res://showcase_meteors.gd").new()
		add_child(meteors)
	setup_hud()
	setup_sun_overlay()
	set_scene_weights(1.0, 0.0, 0.0)


func _process(delta: float) -> void:
	if _showcase_frozen:
		update_shader_uniforms_preview()
		update_synth_sun()
		return
	demo_timer += delta
	if _portal_play_t >= 0.0:
		_portal_play_t += delta
	handle_scene_cycling()
	animate_camera()
	update_fault_fx()
	update_synth_sun()
	update_chrome_moon()
	update_shader_uniforms()
	update_hud()

	if demo_timer >= DEMO_DURATION:
		if is_headless:
			get_tree().quit()
		elif not _is_embedded_in_carrier():
			get_tree().change_scene_to_file(NEXT_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if not _is_embedded_in_carrier():
					get_tree().quit()
			KEY_SPACE, KEY_ENTER:
				if not _is_embedded_in_carrier():
					get_tree().change_scene_to_file(NEXT_SCENE)


func _is_embedded_in_carrier() -> bool:
	if get_viewport() is SubViewport:
		return true
	return has_meta("vg_portal_embedded") and bool(get_meta("vg_portal_embedded"))


func setup_cinematic_environment() -> void:
	environment_node = WorldEnvironment.new()
	var env := Environment.new()

	sky = Sky.new()
	sky_mat_day = ShaderMaterial.new()
	sky_mat_day.shader = load(SKY_DAY_PATH)
	sky_mat_space = ShaderMaterial.new()
	sky_mat_space.shader = load(SKY_SPACE_PATH)
	sky_mat_fault = ShaderMaterial.new()
	sky_mat_fault.shader = load(SKY_FAULT_PATH)
	sky.sky_material = sky_mat_day
	env.sky = sky
	env.background_mode = Environment.BG_SKY

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.45, 0.62, 1.0)
	env.ambient_light_energy = 0.55
	env.glow_enabled = true
	env.glow_intensity = 1.15
	env.glow_bloom = 0.35
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.25
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.014
	env.volumetric_fog_albedo = Color(0.65, 0.78, 0.95, 1.0)
	environment_node.environment = env
	add_child(environment_node)


func setup_sun_light() -> void:
	sun_light = DirectionalLight3D.new()
	sun_light.light_color = Color(1.0, 0.96, 0.88, 1.0)
	sun_light.light_energy = 1.35
	sun_light.shadow_enabled = false
	sun_light.rotation_degrees = Vector3(-42.0, 32.0, 0.0)
	add_child(sun_light)


func setup_camera() -> void:
	camera_node = Camera3D.new()
	camera_node.fov = 68.0
	camera_node.near = 0.05
	camera_node.far = 200.0
	camera_node.current = true
	add_child(camera_node)


func create_synth_grid_scene() -> void:
	synth_mesh = MeshInstance3D.new()
	synth_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	synth_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

	var a_mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var uvs := PackedVector2Array()
	var size := 120.0
	var subdivisions := 48

	for z in range(subdivisions + 1):
		for x in range(subdivisions + 1):
			var px := (float(x) / float(subdivisions)) * size - (size / 2.0)
			var pz := (float(z) / float(subdivisions)) * size - (size / 2.0)
			vertices.append(Vector3(px, 0.0, pz))
			uvs.append(Vector2(float(x) / float(subdivisions), float(z) / float(subdivisions)))

	for z in range(subdivisions):
		for x in range(subdivisions):
			var row1 := z * (subdivisions + 1) + x
			var row2 := (z + 1) * (subdivisions + 1) + x
			indices.append_array([row1, row1 + 1, row2, row2, row1 + 1, row2 + 1])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	a_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	synth_mesh.mesh = a_mesh

	synth_mat = ShaderMaterial.new()
	synth_mat.shader = load(SYNTH_SHADER_PATH)
	var empty_ripples := PackedVector4Array()
	empty_ripples.resize(4)
	for i in 4:
		empty_ripples[i] = Vector4.ZERO
	synth_mat.set_shader_parameter("u_ripples", empty_ripples)
	synth_mesh.material_override = synth_mat
	add_child(synth_mesh)


func create_synth_sun() -> void:
	sun_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sun_mesh.mesh = sphere
	sun_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sun_mesh.position = SUN_REST_POS
	sun_mesh.scale = Vector3.ONE * 5.0

	sun_mat = ShaderMaterial.new()
	sun_mat.shader = load(SUN_SHADER_PATH)
	sun_mat.set_shader_parameter("u_blend", 1.0)
	sun_mesh.material_override = sun_mat
	add_child(sun_mesh)


func create_chrome_moon() -> void:
	moon_mesh = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	moon_mesh.mesh = quad
	moon_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moon_mesh.position = MOON_REST_POS
	moon_mesh.scale = Vector3.ONE * 6.0

	moon_mat = ShaderMaterial.new()
	moon_mat.shader = load(MOON_SHADER_PATH)
	moon_mat.set_shader_parameter("u_blend", 0.0)
	moon_mesh.material_override = moon_mat
	moon_mesh.visible = false
	add_child(moon_mesh)


func setup_sun_overlay() -> void:
	var overlay_layer := CanvasLayer.new()
	overlay_layer.layer = 15
	sun_overlay = ColorRect.new()
	sun_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sun_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sun_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
	overlay_layer.add_child(sun_overlay)
	add_child(overlay_layer)


func create_chrome_scene() -> void:
	chrome_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(8.0, 8.0, 8.0)
	chrome_mesh.mesh = box
	chrome_mesh.position = Vector3(0.0, 3.0, 0.0)
	chrome_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	chrome_mat = ShaderMaterial.new()
	chrome_mat.shader = load(CHROME_SHADER_PATH)
	chrome_mesh.material_override = chrome_mat
	chrome_mesh.visible = false
	add_child(chrome_mesh)


func create_fault_fx_scene() -> void:
	fault_corona_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	fault_corona_mesh.mesh = sphere
	fault_corona_mesh.position = Vector3(0.0, 3.0, 0.0)
	fault_corona_mesh.scale = Vector3.ONE * 13.0
	fault_corona_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	fault_corona_mat = ShaderMaterial.new()
	fault_corona_mat.shader = load(FAULT_CORONA_PATH)
	fault_corona_mesh.material_override = fault_corona_mat
	fault_corona_mesh.visible = false
	add_child(fault_corona_mesh)

	fault_ring_mat = ShaderMaterial.new()
	fault_ring_mat.shader = load(FAULT_ENERGY_RING_PATH)
	var ring_rots: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(62.0, 38.0, 18.0),
		Vector3(28.0, -48.0, 72.0),
	]
	var ring_scales: Array[float] = [4.2, 5.4, 6.6]
	for i in ring_rots.size():
		var ring_mesh := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.72
		torus.outer_radius = 1.0
		torus.rings = 28
		torus.ring_segments = 48
		ring_mesh.mesh = torus
		ring_mesh.position = Vector3(0.0, 3.0, 0.0)
		ring_mesh.scale = Vector3.ONE * ring_scales[i]
		ring_mesh.rotation_degrees = ring_rots[i]
		ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring_mesh.material_override = fault_ring_mat
		ring_mesh.set_instance_shader_parameter("u_phase", float(i) * 2.09)
		ring_mesh.visible = false
		add_child(ring_mesh)
		fault_ring_meshes.append(ring_mesh)


func create_fault_cube_scene() -> void:
	fault_mesh = MeshInstance3D.new()
	fault_mesh.mesh = _build_unwelded_cube_mesh(1.8, 10)
	fault_mesh.position = Vector3(0.0, 3.0, 0.0)
	fault_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	fault_mat = ShaderMaterial.new()
	fault_mat.shader = load(FAULT_SHADER_PATH)
	fault_mat.set_shader_parameter("explosion_factor", 1.0)
	fault_mesh.material_override = fault_mat
	fault_mesh.visible = false
	add_child(fault_mesh)


func _build_unwelded_cube_mesh(half_size: float, subdiv: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var faces: Array[Dictionary] = [
		{"n": Vector3(0, 1, 0), "u": Vector3(1, 0, 0), "v": Vector3(0, 0, 1), "o": Vector3(0, half_size, 0)},
		{"n": Vector3(0, -1, 0), "u": Vector3(1, 0, 0), "v": Vector3(0, 0, -1), "o": Vector3(0, -half_size, 0)},
		{"n": Vector3(1, 0, 0), "u": Vector3(0, 0, -1), "v": Vector3(0, 1, 0), "o": Vector3(half_size, 0, 0)},
		{"n": Vector3(-1, 0, 0), "u": Vector3(0, 0, 1), "v": Vector3(0, 1, 0), "o": Vector3(-half_size, 0, 0)},
		{"n": Vector3(0, 0, 1), "u": Vector3(1, 0, 0), "v": Vector3(0, 1, 0), "o": Vector3(0, 0, half_size)},
		{"n": Vector3(0, 0, -1), "u": Vector3(-1, 0, 0), "v": Vector3(0, 1, 0), "o": Vector3(0, 0, -half_size)},
	]

	for face in faces:
		var n: Vector3 = face["n"]
		var u_axis: Vector3 = face["u"]
		var v_axis: Vector3 = face["v"]
		var origin: Vector3 = face["o"]
		var base_idx := vertices.size()

		for gz in range(subdiv + 1):
			for gx in range(subdiv + 1):
				var fu := (float(gx) / float(subdiv) - 0.5) * 2.0 * half_size
				var fv := (float(gz) / float(subdiv) - 0.5) * 2.0 * half_size
				vertices.append(origin + u_axis * fu + v_axis * fv)
				normals.append(n)
				uvs.append(Vector2(float(gx) / float(subdiv), float(gz) / float(subdiv)))

		for gz in range(subdiv):
			for gx in range(subdiv):
				var i0 := base_idx + gz * (subdiv + 1) + gx
				var i1 := i0 + 1
				var i2 := i0 + (subdiv + 1)
				var i3 := i2 + 1
				indices.append_array([i0, i2, i1, i1, i2, i3])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func setup_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 20
	add_child(hud_layer)

	var bar := ColorRect.new()
	bar.color = Color(0.0, 0.0, 0.0, 0.48)
	bar.position = Vector2.ZERO
	bar.size = Vector2(1280.0, 56.0)
	hud_layer.add_child(bar)

	title_label = Label.new()
	title_label.position = Vector2(16.0, 8.0)
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.35, 0.92, 1.0, 0.95))
	hud_layer.add_child(title_label)

	sub_label = Label.new()
	sub_label.position = Vector2(16.0, 32.0)
	sub_label.add_theme_font_size_override("font_size", 14)
	sub_label.add_theme_color_override("font_color", Color(0.72, 0.55, 1.0, 0.82))
	hud_layer.add_child(sub_label)

	timer_label = Label.new()
	timer_label.position = Vector2(1200.0, 12.0)
	timer_label.add_theme_font_size_override("font_size", 20)
	timer_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45, 0.88))
	hud_layer.add_child(timer_label)

	skip_label = Label.new()
	skip_label.text = "SPACE SKIP"
	skip_label.position = Vector2(590.0, 688.0)
	skip_label.add_theme_font_size_override("font_size", 14)
	skip_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.38))
	hud_layer.add_child(skip_label)


func _segment_info() -> Dictionary:
	var start := 0.0
	for i in SCENE_HOLDS.size():
		var hold: float = SCENE_HOLDS[i]
		if demo_timer < start + hold:
			return {"idx": i, "start": start, "hold": hold, "local_t": demo_timer - start}
		start += hold
	var last := SCENE_HOLDS.size() - 1
	var last_hold: float = SCENE_HOLDS[last]
	var last_start: float = start - last_hold
	return {"idx": last, "start": last_start, "hold": last_hold, "local_t": last_hold}


func _sun_dive_t() -> float:
	if _portal_mode():
		return 0.0
	return clampf((demo_timer - SUN_DIVE_START) / SUN_DIVE_DURATION, 0.0, 1.0)


func _moon_dive_t() -> float:
	if _portal_mode():
		return 0.0
	return clampf((demo_timer - MOON_DIVE_START) / MOON_DIVE_DURATION, 0.0, 1.0)


func _sun_whiteout_alpha() -> float:
	if _portal_mode():
		return 0.0
	if demo_timer < SUN_DIVE_START:
		return 0.0
	var dive := _sun_dive_t()
	if demo_timer < CHROME_UNDER_WHITE_START:
		return clampf((dive - 0.55) / 0.45, 0.0, 1.0)
	var reveal := clampf((demo_timer - CHROME_UNDER_WHITE_START) / SUN_WHITE_REVEAL, 0.0, 1.0)
	return 1.0 - reveal


func _moon_whiteout_alpha() -> float:
	if _portal_mode():
		return 0.0
	if demo_timer < MOON_DIVE_START:
		return 0.0
	var dive := _moon_dive_t()
	if demo_timer < FAULT_UNDER_WHITE_START:
		return clampf((dive - 0.55) / 0.45, 0.0, 1.0)
	var reveal := clampf((demo_timer - FAULT_UNDER_WHITE_START) / MOON_WHITE_REVEAL, 0.0, 1.0)
	return 1.0 - reveal


func _whiteout_alpha() -> float:
	return maxf(_sun_whiteout_alpha(), _moon_whiteout_alpha())


func _render_scene() -> int:
	if demo_timer < CHROME_UNDER_WHITE_START:
		return SceneId.SYNTH_GRID
	if demo_timer < FAULT_UNDER_WHITE_START:
		return SceneId.CHROME
	return SceneId.FAULT_CUBE


func handle_scene_cycling() -> void:
	if _portal_segment >= 0:
		match _portal_segment:
			SceneId.SYNTH_GRID:
				current_scene = SceneId.SYNTH_GRID
				set_scene_weights(1.0, 0.0, 0.0)
			SceneId.CHROME:
				current_scene = SceneId.CHROME
				set_scene_weights(0.0, 1.0, 0.0)
			_:
				current_scene = SceneId.FAULT_CUBE
				set_scene_weights(0.0, 0.0, 1.0)
		if lorenz_cloud:
			lorenz_cloud.visible = false
		if meteors:
			meteors.visible = _portal_segment == SceneId.SYNTH_GRID
		if sun_overlay:
			sun_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
		_apply_sky_for_scene()
		_apply_portal_environment()
		return

	current_scene = _render_scene()
	var dive := _sun_dive_t()
	var moon_dive := _moon_dive_t()
	var whiteout := _whiteout_alpha()

	var synth_w := 0.0
	var chrome_w := 0.0
	var fault_w := 0.0

	if demo_timer < CHROME_UNDER_WHITE_START:
		synth_w = 1.0
		if dive > 0.0:
			synth_w = maxf(0.0, 1.0 - dive * 1.15)
	elif demo_timer < FAULT_UNDER_WHITE_START:
		chrome_w = 1.0
		if moon_dive > 0.0:
			chrome_w = maxf(0.0, 1.0 - moon_dive * 1.15)
	else:
		fault_w = 1.0
		var fault_local := demo_timer - FAULT_UNDER_WHITE_START
		var fault_visual_hold: float = DEMO_DURATION - FAULT_UNDER_WHITE_START
		if fault_local > fault_visual_hold - CROSSFADE:
			fault_w = clampf((fault_visual_hold - fault_local) / CROSSFADE, 0.0, 1.0)

	set_scene_weights(synth_w, chrome_w, fault_w)

	if lorenz_cloud:
		lorenz_cloud.visible = demo_timer < CHROME_UNDER_WHITE_START and synth_w > 0.05 and dive < 0.2
	if meteors:
		meteors.visible = demo_timer < CHROME_UNDER_WHITE_START and synth_w > 0.05 and dive < 0.15

	if sun_overlay:
		var moon_phase := _moon_whiteout_alpha()
		if moon_phase > 0.0 and demo_timer >= MOON_DIVE_START:
			sun_overlay.color = Color(0.9, 0.94, 1.0, moon_phase)
		else:
			sun_overlay.color = Color(1.0, 1.0, 1.0, whiteout)

	_apply_sky_for_scene()

	if environment_node and environment_node.environment:
		var env := environment_node.environment
		match current_scene:
			SceneId.FAULT_CUBE:
				env.background_mode = Environment.BG_SKY
				env.volumetric_fog_enabled = true
				_apply_fault_environment(_fault_bg_pulse())
			SceneId.SYNTH_GRID:
				env.background_mode = Environment.BG_SKY
				env.ambient_light_color = Color(0.35, 0.45, 0.62, 1.0)
				env.ambient_light_energy = 0.55
				env.volumetric_fog_enabled = true
				env.volumetric_fog_density = 0.014
				env.volumetric_fog_albedo = Color(0.55, 0.72, 0.95, 1.0)
				if dive > 0.0:
					env.glow_intensity = 1.3 + dive * 2.2
					env.glow_bloom = 0.42 + dive * 0.55
					env.glow_hdr_threshold = maxf(0.65, 1.15 - dive * 0.55)
				else:
					env.glow_intensity = 1.15
					env.glow_bloom = 0.32
					env.glow_hdr_threshold = 1.25
			SceneId.CHROME:
				env.background_mode = Environment.BG_SKY
				env.ambient_light_color = Color(0.12, 0.16, 0.28, 1.0)
				env.ambient_light_energy = 0.35
				env.volumetric_fog_enabled = false
				if moon_dive > 0.0:
					env.glow_intensity = 1.2 + moon_dive * 2.0
					env.glow_bloom = 0.35 + moon_dive * 0.5
					env.glow_hdr_threshold = maxf(0.7, 1.25 - moon_dive * 0.5)
				else:
					env.glow_intensity = 1.25
					env.glow_bloom = 0.38
					env.glow_hdr_threshold = 1.2


func _apply_sky_for_scene() -> void:
	if sky == null:
		return
	var target: ShaderMaterial
	if _portal_segment == SceneId.SYNTH_GRID or _portal_segment == SceneId.CHROME:
		target = sky_mat_space
	elif _portal_segment == SceneId.FAULT_CUBE:
		target = sky_mat_fault
	elif demo_timer >= FAULT_UNDER_WHITE_START:
		target = sky_mat_fault
	elif demo_timer >= CHROME_UNDER_WHITE_START:
		target = sky_mat_space
	else:
		target = sky_mat_day
	if sky.sky_material != target:
		sky.sky_material = target


func _apply_portal_environment() -> void:
	if environment_node == null or environment_node.environment == null:
		return
	var env := environment_node.environment
	env.background_mode = Environment.BG_SKY
	match _portal_segment:
		SceneId.SYNTH_GRID:
			env.ambient_light_color = Color(0.1, 0.14, 0.26, 1.0)
			env.ambient_light_energy = 0.42
			env.volumetric_fog_enabled = true
			env.volumetric_fog_density = 0.006
			env.volumetric_fog_albedo = Color(0.08, 0.12, 0.22, 1.0)
			env.glow_intensity = 1.15
			env.glow_bloom = 0.28
			env.glow_hdr_threshold = 1.2
		SceneId.CHROME:
			env.ambient_light_color = Color(0.12, 0.16, 0.28, 1.0)
			env.ambient_light_energy = 0.35
			env.volumetric_fog_enabled = false
			env.glow_intensity = 1.25
			env.glow_bloom = 0.38
			env.glow_hdr_threshold = 1.2
		_:
			env.volumetric_fog_enabled = true
			_apply_fault_environment(_fault_bg_pulse())


func _fault_bg_pulse() -> float:
	if demo_timer < FAULT_UNDER_WHITE_START:
		return 0.0
	var fault_t := demo_timer - FAULT_UNDER_WHITE_START
	return 0.5 + 0.5 * sin(fault_t * 1.25)


func set_scene_weights(synth_w: float, chrome_w: float, fault_w: float) -> void:
	if synth_mat:
		synth_mat.set_shader_parameter("u_blend", synth_w)
	if chrome_mat:
		chrome_mat.set_shader_parameter("u_blend", chrome_w)
	if fault_mat:
		fault_mat.set_shader_parameter("u_blend", fault_w)
	if fault_corona_mat:
		fault_corona_mat.set_shader_parameter("u_blend", fault_w)
	if fault_ring_mat:
		fault_ring_mat.set_shader_parameter("u_blend", fault_w)
	synth_mesh.visible = synth_w > 0.001
	chrome_mesh.visible = chrome_w > 0.001
	fault_mesh.visible = fault_w > 0.001
	fault_corona_mesh.visible = fault_w > 0.001
	for ring in fault_ring_meshes:
		ring.visible = fault_w > 0.001


func animate_camera() -> void:
	if _portal_mode():
		match _portal_segment:
			SceneId.SYNTH_GRID:
				var scene_t := demo_timer
				var prog := clampf(scene_t / SCENE_HOLDS[0], 0.0, 1.0)
				var speed := 1.0 + prog * 1.4
				camera_node.transform.origin = Vector3(
					sin(scene_t * 0.22 * speed) * 2.8,
					3.5 + sin(scene_t * 0.5) * 0.35,
					14.0 - prog * 4.0
				)
				camera_node.look_at(Vector3(0.0, 1.0, -4.0))
			SceneId.CHROME:
				var chrome_t := _portal_segment_local_time()
				camera_node.transform.origin = Vector3(
					cos(chrome_t * 0.45) * 7.5,
					4.5 + sin(chrome_t * 0.35) * 1.2,
					sin(chrome_t * 0.45) * 7.5 + 4.0
				)
				camera_node.look_at(Vector3(0.0, 3.0, 0.0))
			_:
				var fault_t := _portal_segment_local_time()
				camera_node.transform.origin = Vector3(
					sin(fault_t * 0.38) * 9.0,
					5.0 + cos(fault_t * 0.52) * 2.0,
					cos(fault_t * 0.38) * 9.0 + 3.0
				)
				camera_node.look_at(Vector3(0.0, 3.0, 0.0))
		return

	var scene_t: float = demo_timer
	if demo_timer < CHROME_UNDER_WHITE_START:
		var prog := clampf(demo_timer / SCENE_HOLDS[0], 0.0, 1.0)
		var speed := 1.0 + prog * 1.4
		camera_node.transform.origin = Vector3(
			sin(scene_t * 0.22 * speed) * 2.8,
			3.5 + sin(scene_t * 0.5) * 0.35,
			14.0 - prog * 4.0
		)
		camera_node.look_at(Vector3(0.0, 1.0, -4.0))
	elif demo_timer < FAULT_UNDER_WHITE_START:
		var chrome_t := demo_timer - CHROME_UNDER_WHITE_START
		camera_node.transform.origin = Vector3(
			cos(chrome_t * 0.45) * 7.5,
			4.5 + sin(chrome_t * 0.35) * 1.2,
			sin(chrome_t * 0.45) * 7.5 + 4.0
		)
		camera_node.look_at(Vector3(0.0, 3.0, 0.0))
	else:
		var fault_t := demo_timer - FAULT_UNDER_WHITE_START
		camera_node.transform.origin = Vector3(
			sin(fault_t * 0.38) * 9.0,
			5.0 + cos(fault_t * 0.52) * 2.0,
			cos(fault_t * 0.38) * 9.0 + 3.0
		)
		camera_node.look_at(Vector3(0.0, 3.0, 0.0))


func update_shader_uniforms() -> void:
	if synth_mat and synth_mesh.visible:
		synth_mat.set_shader_parameter("u_energy", clampf(demo_timer / SCENE_HOLDS[0], 0.0, 1.0))
		if meteors and meteors.has_method("get_grid_ripples"):
			synth_mat.set_shader_parameter("u_ripples", meteors.get_grid_ripples())
	if fault_mat and fault_mesh.visible:
		var fault_t := demo_timer - FAULT_UNDER_WHITE_START
		var boom := 1.0 + sin(fault_t * 1.7) * 0.35
		fault_mat.set_shader_parameter("explosion_factor", boom)
		if fault_corona_mat:
			fault_corona_mat.set_shader_parameter("explosion_factor", boom)
		if fault_ring_mat:
			fault_ring_mat.set_shader_parameter("explosion_factor", boom)


func _apply_fault_environment(bg_pulse: float) -> void:
	if environment_node == null or environment_node.environment == null:
		return
	var env := environment_node.environment
	var dark_amb := Color(0.06, 0.05, 0.12, 1.0)
	var bright_amb := Color(0.28, 0.18, 0.32, 1.0)
	var dark_fog := Color(0.05, 0.03, 0.1, 1.0)
	var bright_fog := Color(0.38, 0.14, 0.06, 1.0)
	env.ambient_light_color = dark_amb.lerp(bright_amb, bg_pulse)
	env.ambient_light_energy = lerpf(0.12, 0.5, bg_pulse)
	env.volumetric_fog_density = lerpf(0.0015, 0.006, bg_pulse)
	env.volumetric_fog_albedo = dark_fog.lerp(bright_fog, bg_pulse)
	env.glow_intensity = lerpf(0.9, 1.85, bg_pulse)
	env.glow_bloom = lerpf(0.28, 0.58, bg_pulse)
	env.glow_hdr_threshold = lerpf(1.0, 0.72, bg_pulse)
	if sky_mat_fault:
		sky_mat_fault.set_shader_parameter("u_pulse", bg_pulse)
	if fault_corona_mat:
		fault_corona_mat.set_shader_parameter("u_bg_pulse", bg_pulse)


func update_fault_fx() -> void:
	if fault_corona_mesh == null or not fault_corona_mesh.visible:
		return
	var bg_pulse := _fault_bg_pulse()
	_apply_fault_environment(bg_pulse)
	var spin := demo_timer * 0.55
	for i in fault_ring_meshes.size():
		var ring := fault_ring_meshes[i]
		ring.rotate_object_local(Vector3(0.0, 1.0, 0.0), 0.012 + float(i) * 0.004)
		ring.rotate_object_local(Vector3(1.0, 0.0, 0.0), 0.006 * sin(spin + float(i)))
	fault_corona_mesh.scale = Vector3.ONE * (13.0 + sin(demo_timer * 2.5) * 0.35)


func update_synth_sun() -> void:
	if sun_mesh == null or sun_mat == null:
		return
	if _portal_mode():
		sun_mesh.visible = false
		sun_mat.set_shader_parameter("u_blend", 0.0)
		return
	if demo_timer >= CHROME_UNDER_WHITE_START:
		sun_mesh.visible = false
		sun_mat.set_shader_parameter("u_blend", 0.0)
		return

	sun_mesh.visible = true
	var dive := _sun_dive_t()
	var pulse: float = 0.5 + 0.5 * sin(demo_timer * 2.6)

	if dive <= 0.0:
		sun_mesh.global_position = SUN_REST_POS
		sun_mesh.scale = Vector3.ONE * (5.0 + pulse * 0.75)
		sun_mat.set_shader_parameter("u_pulse", pulse)
		sun_mat.set_shader_parameter("u_heat", 0.0)
		sun_mat.set_shader_parameter("u_blend", 1.0)
	else:
		var ease := dive * dive * (3.0 - 2.0 * dive)
		var cam_pos := camera_node.global_position
		var cam_forward := -camera_node.global_transform.basis.z.normalized()
		var end_pos := cam_pos + cam_forward * 0.8
		sun_mesh.global_position = SUN_REST_POS.lerp(end_pos, ease)
		var start_scale := 5.5
		var end_scale := 220.0
		var scale_val := start_scale * pow(end_scale / start_scale, ease)
		sun_mesh.scale = Vector3.ONE * scale_val
		sun_mat.set_shader_parameter("u_pulse", 1.0)
		sun_mat.set_shader_parameter("u_heat", ease)
		sun_mat.set_shader_parameter("u_blend", 1.0)


func update_chrome_moon() -> void:
	if moon_mesh == null or moon_mat == null:
		return

	if _portal_segment == SceneId.SYNTH_GRID:
		moon_mesh.visible = true
		moon_mat.set_shader_parameter("u_blend", 1.0)
		var t := demo_timer
		var wobble := Vector3(sin(t * 2.2) * 0.6, cos(t * 1.8) * 0.4, sin(t * 3.1) * 0.35)
		moon_mesh.global_position = MOON_REST_POS + wobble
		moon_mesh.scale = Vector3.ONE * (6.0 + sin(t * 1.6) * 0.35)
		moon_mesh.rotation.z = sin(t * 2.2) * 0.12
		moon_mat.set_shader_parameter("u_pulse", 0.45 + 0.55 * sin(t * 1.4))
		moon_mat.set_shader_parameter("u_heat", 0.0)
		_face_billboard(moon_mesh)
		return

	if _portal_mode():
		moon_mesh.visible = false
		moon_mat.set_shader_parameter("u_blend", 0.0)
		return

	var moon_end := MOON_DIVE_START + MOON_DIVE_DURATION
	var show_moon := demo_timer >= CHROME_UNDER_WHITE_START and demo_timer < moon_end
	if not show_moon:
		moon_mesh.visible = false
		moon_mat.set_shader_parameter("u_blend", 0.0)
		return

	moon_mesh.visible = true
	moon_mat.set_shader_parameter("u_blend", 1.0)
	var dive := _moon_dive_t()
	var t := demo_timer

	if dive <= 0.0:
		var wobble := Vector3(
			sin(t * 3.1) * 1.1,
			cos(t * 2.4) * 0.85,
			sin(t * 4.7) * 0.65
		)
		moon_mesh.global_position = MOON_REST_POS + wobble
		moon_mesh.scale = Vector3.ONE * (6.0 + sin(t * 2.3) * 0.55)
		moon_mesh.rotation.z = sin(t * 2.8) * 0.18
		moon_mat.set_shader_parameter("u_pulse", 0.5 + 0.5 * sin(t * 2.1))
		moon_mat.set_shader_parameter("u_heat", 0.0)
	else:
		var ease := dive * dive * (3.0 - 2.0 * dive)
		var cam_pos := camera_node.global_position
		var cam_forward := -camera_node.global_transform.basis.z.normalized()
		var end_pos := cam_pos + cam_forward * 0.8
		var wobble_amp := maxf(0.0, 1.0 - ease * 1.4)
		var wobble := Vector3(
			sin(t * 9.0) * 0.45,
			cos(t * 11.0) * 0.35,
			sin(t * 8.0) * 0.25
		) * wobble_amp
		moon_mesh.global_position = MOON_REST_POS.lerp(end_pos, ease) + wobble
		var start_scale := 6.0
		var end_scale := 220.0
		moon_mesh.scale = Vector3.ONE * (start_scale * pow(end_scale / start_scale, ease))
		moon_mat.set_shader_parameter("u_pulse", 1.0)
		moon_mat.set_shader_parameter("u_heat", ease)

	_face_billboard(moon_mesh)


func _face_billboard(mesh: MeshInstance3D) -> void:
	var cam_pos := camera_node.global_position
	var to_cam := cam_pos - mesh.global_position
	if to_cam.length_squared() < 0.001:
		return
	mesh.look_at(cam_pos, Vector3.UP)


func update_hud() -> void:
	var dur := _portal_segment_duration() if _portal_mode() else DEMO_DURATION
	var elapsed := demo_timer
	if _portal_mode():
		if _portal_play_t < 0.0:
			timer_label.text = ""
		else:
			elapsed = _portal_play_t
			var remain := maxf(0.0, dur - elapsed)
			timer_label.text = "%dS" % int(round(remain))
	else:
		var remain := maxf(0.0, dur - elapsed)
		timer_label.text = "%dS" % int(round(remain))
	match current_scene:
		SceneId.SYNTH_GRID:
			title_label.text = "SYNTH GRID"
			if _portal_mode():
				sub_label.text = "DISPLACED MESH  |  METEORS  |  CRESCENT MOON"
			elif demo_timer >= SUN_DIVE_START:
				sub_label.text = "SOLAR DIVE  |  WHITEOUT TRANSITION"
			else:
				sub_label.text = "DISPLACED MESH  |  LORENZ CLOUD  |  METEORS  |  SOLAR DIVE FINALE"
		SceneId.CHROME:
			title_label.text = "LIQUID CHROME"
			if _portal_mode():
				sub_label.text = "DEEP SPACE  |  METABALL SDF"
			elif demo_timer >= MOON_DIVE_START:
				sub_label.text = "CRESCENT MOON DIVE  |  SILVER WHITEOUT"
			else:
				sub_label.text = "DEEP SPACE  |  METABALL SDF  |  CRESCENT MOON"
		SceneId.FAULT_CUBE:
			title_label.text = "FAULT CUBE"
			sub_label.text = "PLASMA CORONA  |  ORBITAL ENERGY RINGS  |  VERTEX EXPLOSION"
