extends Node3D
## Star Fox carrier director — scripted flight beats, monitor demos, exterior shader spectacle.

const SKY_DAY := "res://shaders/procedural_sky_day.gdshader"
const SKY_SPACE := "res://shaders/procedural_sky_space.gdshader"
const SKY_PLANET := "res://shaders/carrier_planet_sky.gdshader"
const PLANET_BODY := "res://shaders/carrier_planet_body.gdshader"
const SYNTH_GRID := "res://shaders/synth_grid.gdshader"
const SCREEN_PLAYER_SCRIPT := preload("res://showcase_carrier_screen.gd")
const COCKPIT_HUD_SCRIPT := preload("res://showcase_cockpit_hud.gd")
const EXTERIOR_SPECTACLE_SCRIPT := preload("res://showcase_carrier_exterior_spectacle.gd")

const T_ZOOM_IN := 2.8
const T_ZOOM_OUT := 2.6

const CITY_U0 := 0.0
const RING_U := 0.72

const SCENE_GRID := "res://shader_showcase_main.tscn"
const SCENE_DASH := "res://dash_main.tscn"
const SCENE_ABOUT := "res://about_vg_main.tscn"
const SCENE_SQUASH := "res://squash_tease_main.tscn"

const BEATS: Array[Dictionary] = [
	{"id": "space_warp", "duration": 7.0, "title": "DEEP SPACE", "sub": "Star warp · tons of streaking stars"},
	{"id": "planet_reveal", "duration": 5.0, "title": "PLANET AHEAD", "sub": "Warp drops out · first world visible"},
	{"id": "descent_city", "duration": 9.0, "title": "ATMOSPHERIC ENTRY", "sub": "Diving toward the city planet"},
	{"id": "city_fly", "duration": 13.0, "title": "CITY CANYONS", "sub": "Weaving between towers"},
	{"id": "ring_pass", "duration": 4.0, "title": "CHECKPOINT RING", "sub": "Fly through the gate"},
	{"id": "ascend_space", "duration": 9.0, "title": "TO ORBIT", "sub": "Climb into deep space · cockpit"},
	{"id": "cockpit_standby", "duration": 2.5, "title": "COCKPIT", "sub": "Monitor standby"},
	{"id": "mon_grid_in", "duration": T_ZOOM_IN, "title": "SHADER · SYNTH GRID", "sub": "Zoom into monitor"},
	{"id": "mon_grid", "duration": 14.0, "title": "SHADER · SYNTH GRID", "sub": "First shader spectacle beat"},
	{"id": "mon_grid_out", "duration": T_ZOOM_OUT, "title": "SHADER · SYNTH GRID", "sub": "Zoom out"},
	{"id": "starfield_travel", "duration": 9.0, "title": "HYPERSPACE LANE", "sub": "Starfield · next planet ahead"},
	{"id": "descent_grid", "duration": 10.0, "title": "GRID WORLD", "sub": "Synth surface · meteor impacts"},
	{"id": "grid_fly", "duration": 11.0, "title": "GRID RUN", "sub": "Low flight · ring on horizon"},
	{"id": "grid_ring", "duration": 4.0, "title": "GRID RING", "sub": "Through the checkpoint"},
	{"id": "grid_ascend", "duration": 8.0, "title": "LEAVING GRID", "sub": "Ascent to space"},
	{"id": "cockpit_chrome", "duration": 10.0, "title": "CHROME METABALLS", "sub": "Exterior spectacle · through windshield"},
	{"id": "mon_gd_in", "duration": T_ZOOM_IN, "title": "NEON RUNNER", "sub": "Geometry Dash on monitor"},
	{"id": "mon_gd", "duration": 24.0, "title": "NEON RUNNER", "sub": "Visual Gasic · .vg runtime"},
	{"id": "mon_gd_out", "duration": T_ZOOM_OUT, "title": "NEON RUNNER", "sub": "Pull back · fault cube outside"},
	{"id": "cockpit_fault", "duration": 9.0, "title": "FAULT CUBE", "sub": "Chrome becomes the cube · cockpit view"},
	{"id": "ship_warp_out", "duration": 9.0, "title": "BREAK AWAY", "sub": "Hard turn · star warp"},
	{"id": "starfield_about", "duration": 5.0, "title": "NARCEA ROUTE", "sub": "Starfield · About VG queued"},
	{"id": "mon_about_in", "duration": T_ZOOM_IN, "title": "ABOUT VISUAL GASIC", "sub": "Zoom into Narcea story"},
	{"id": "mon_about", "duration": 35.0, "title": "ABOUT VISUAL GASIC", "sub": "Pac-Man belt · backstory"},
	{"id": "mon_about_out", "duration": T_ZOOM_OUT, "title": "ABOUT VISUAL GASIC", "sub": "Zoom out"},
	{"id": "mon_squash_in", "duration": T_ZOOM_IN, "title": "SQUASH THE CREEPS", "sub": "Zoom into 3D tease"},
	{"id": "mon_squash", "duration": 20.0, "title": "SQUASH THE CREEPS", "sub": "First 3D game · .vg"},
	{"id": "showcase_end", "duration": 4.0, "title": "SHOWCASE COMPLETE", "sub": "F5 to replay · Space skips beat"},
]

const COL_HULL := Color(0.78, 0.82, 0.88)
const COL_WING_TIP := Color(0.1, 0.38, 0.92)
const COL_ACCENT := Color(0.72, 0.58, 0.32)
const COL_JOINT := Color(0.22, 0.24, 0.28)
const COL_BUILD_A := Color(0.62, 0.64, 0.68)
const COL_BUILD_B := Color(0.82, 0.18, 0.16)
const COL_CITY_GROUND := Color(0.18, 0.62, 0.22)

const CORRIDOR_HALF := 22.0
const BUILDING_SIZE := 8.0
const PATH_CLEARANCE := 6.0
const GRID_GROUND_SIZE := 420.0
const GRID_SUBDIV := 56

enum WorldMode { SPACE, ATMOSPHERE, CITY, GRID }

var beat_idx: int = 0
var beat_t: float = 0.0
var world_mode: int = WorldMode.SPACE
var is_headless: bool = false
var flight_curve: Curve3D
var space_curve: Curve3D

var environment_node: WorldEnvironment
var sky: Sky
var sky_mat_day: ShaderMaterial
var sky_mat_space: ShaderMaterial
var sky_mat_planet: ShaderMaterial
var sun_light: DirectionalLight3D
var camera: Camera3D
var flight_path: Path3D
var path_follow: PathFollow3D
var ship_root: Node3D
var visual_root: Node3D
var exterior_root: Node3D
var demo_viewport: SubViewport
var screen_player: Node
var cockpit_layer: CanvasLayer
var cockpit_hud: Control
var exterior_spectacle: Node3D
var meteors: Node3D

var ring_mesh: MeshInstance3D
var city_root: Node3D
var city_ground: MeshInstance3D
var ground_mesh: MeshInstance3D
var grid_mat: ShaderMaterial
var planet_mesh: MeshInstance3D

var fullscreen_layer: CanvasLayer
var fullscreen_back: ColorRect
var fullscreen_rect: TextureRect
var hud_layer: CanvasLayer
var title_label: Label
var sub_label: Label
var skip_label: Label

var _space_u: float = 0.0
var _demo_playback: bool = false
var _path_length: float = 1.0
var _cam_pos: Vector3 = Vector3.ZERO
var _cam_look: Vector3 = Vector3.FORWARD
var _cam_fov: float = 68.0
var _cam_ready: bool = false
var _warp_strength: float = 0.0
var _monitor_scene: String = ""


func _ready() -> void:
	is_headless = DisplayServer.get_name() == "headless"
	_setup_environment()
	_setup_light()
	_build_city_ground()
	_build_grid_ground()
	flight_curve = _build_weave_path()
	space_curve = _build_space_path()
	_path_length = flight_curve.get_baked_length()
	_build_city_along_path()
	_build_ring_on_path()
	_build_planet()
	_build_ship_on_path()
	_setup_exterior_spectacle()
	_setup_meteors()
	_setup_demo_viewport()
	_setup_cameras()
	_setup_fullscreen_overlay()
	_setup_cockpit_hud()
	_setup_hud()
	_set_demo_playback(false)
	if cockpit_hud:
		cockpit_hud.set_demo_texture(demo_viewport.get_texture())
	_use_space_path()
	_set_surface_kind("none")
	_set_world_mode(WorldMode.SPACE)
	_set_path_ratio(0.12)
	_set_exterior_visible(true)
	_reset_ship_visual_offset()
	_on_beat_enter(_current_beat())


func _process(delta: float) -> void:
	beat_t += delta
	_update_beat(_current_beat(), delta)
	_update_hud_for_beat(_current_beat())
	if beat_t >= float(_current_beat().get("duration", 1.0)):
		_advance_beat()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				get_tree().quit()
			KEY_SPACE, KEY_ENTER:
				_advance_beat()


func _current_beat() -> Dictionary:
	if beat_idx < 0 or beat_idx >= BEATS.size():
		return BEATS[BEATS.size() - 1]
	return BEATS[beat_idx]


func _advance_beat() -> void:
	_on_beat_exit(_current_beat())
	beat_idx += 1
	if beat_idx >= BEATS.size():
		beat_idx = BEATS.size() - 1
		if is_headless:
			get_tree().quit()
		return
	beat_t = 0.0
	_reset_camera_spring()
	_on_beat_enter(_current_beat())


func _on_beat_enter(beat: Dictionary) -> void:
	_reset_ship_visual_offset()
	var id := str(beat.get("id", ""))
	match id:
		"mon_grid_in", "mon_gd_in", "mon_about_in", "mon_squash_in":
			_load_monitor_scene(_scene_for_beat(id))
		"mon_grid", "mon_gd", "mon_about", "mon_squash":
			_set_demo_playback(true)
		"cockpit_chrome":
			_use_space_path()
			_set_world_mode(WorldMode.SPACE)
			_set_surface_kind("none")
			_set_exterior_visible(false)
			_set_cockpit_hud_visible(true)
			exterior_spectacle.set_mode(EXTERIOR_SPECTACLE_SCRIPT.Mode.CHROME)
		"mon_gd_out":
			exterior_spectacle.begin_crossfade_to_fault()
		"cockpit_fault":
			exterior_spectacle.set_mode(EXTERIOR_SPECTACLE_SCRIPT.Mode.FAULT)
		"ship_warp_out":
			exterior_spectacle.set_mode(EXTERIOR_SPECTACLE_SCRIPT.Mode.OFF)
		"starfield_about":
			exterior_spectacle.set_mode(EXTERIOR_SPECTACLE_SCRIPT.Mode.OFF)
			_load_monitor_scene(SCENE_ABOUT)
		"showcase_end":
			_set_demo_playback(false)


func _on_beat_exit(beat: Dictionary) -> void:
	var id := str(beat.get("id", ""))
	match id:
		"mon_grid", "mon_gd", "mon_about", "mon_squash":
			_set_demo_playback(false)
		"cockpit_chrome":
			_load_monitor_scene(SCENE_DASH)
		"mon_gd_out":
			exterior_spectacle.set_mode(EXTERIOR_SPECTACLE_SCRIPT.Mode.FAULT)


func _scene_for_beat(id: String) -> String:
	match id:
		"mon_grid_in":
			return SCENE_GRID
		"mon_gd_in":
			return SCENE_DASH
		"mon_about_in":
			return SCENE_ABOUT
		"mon_squash_in":
			return SCENE_SQUASH
	return ""


func _load_monitor_scene(path: String) -> void:
	if path.is_empty() or screen_player == null:
		return
	_monitor_scene = path
	screen_player.load_beat({"path": path})
	_set_demo_playback(false)


func _update_beat(beat: Dictionary, delta: float) -> void:
	var id := str(beat.get("id", ""))
	var dur := maxf(float(beat.get("duration", 1.0)), 0.01)
	var phase := clampf(beat_t / dur, 0.0, 1.0)
	match id:
		"space_warp":
			_update_space_warp(delta, phase)
		"planet_reveal":
			_update_planet_reveal(delta, phase)
		"descent_city":
			_update_descent_city(delta, phase)
		"city_fly":
			_update_city_fly(delta, phase)
		"ring_pass", "grid_ring":
			_update_ring_pass(delta, phase, id == "grid_ring")
		"ascend_space", "grid_ascend":
			_update_ascend_space(delta, phase, id == "grid_ascend")
		"cockpit_standby":
			_update_cockpit_standby(delta)
		"mon_grid_in", "mon_gd_in", "mon_about_in", "mon_squash_in":
			_update_monitor_zoom_in(delta, phase)
		"mon_grid", "mon_gd", "mon_about", "mon_squash":
			_update_monitor_play(delta)
		"mon_grid_out", "mon_gd_out", "mon_about_out":
			_update_monitor_zoom_out(delta, phase)
		"starfield_travel", "starfield_about":
			_update_starfield_travel(delta, phase, id == "starfield_about")
		"descent_grid":
			_update_descent_grid(delta, phase)
		"grid_fly":
			_update_grid_fly(delta, phase)
		"cockpit_chrome", "cockpit_fault":
			_update_cockpit_spectacle(delta, id == "cockpit_fault")
		"ship_warp_out":
			_update_ship_warp_out(delta, phase)
		"showcase_end":
			_update_showcase_end(delta)
		_:
			pass


func _use_city_path() -> void:
	if flight_path:
		flight_path.curve = flight_curve
		_path_length = flight_curve.get_baked_length()


func _use_space_path() -> void:
	if flight_path:
		flight_path.curve = space_curve
		_path_length = space_curve.get_baked_length()


func _tick_space_drift(delta: float) -> void:
	_space_u = fmod(_space_u + delta * 0.042, 1.0)
	_set_path_ratio(_space_u)
	_apply_ship_bank(_space_u, delta)
	_apply_planet_pose(1.0, 0.1)


func _set_world_mode(mode: int) -> void:
	world_mode = mode
	match mode:
		WorldMode.SPACE:
			sky.sky_material = sky_mat_space
			environment_node.environment.fog_density = 0.00012
		WorldMode.ATMOSPHERE:
			sky.sky_material = sky_mat_planet
			environment_node.environment.fog_density = 0.0014
		WorldMode.CITY:
			sky.sky_material = sky_mat_day
			if planet_mesh:
				planet_mesh.visible = false
			environment_node.environment.fog_density = 0.0008
		WorldMode.GRID:
			sky.sky_material = sky_mat_day
			if planet_mesh:
				planet_mesh.visible = false
			environment_node.environment.fog_density = 0.00065
	_apply_warp_sky()


func _set_surface_kind(kind: String) -> void:
	var city_on := kind == "city"
	var grid_on := kind == "grid"
	if city_ground:
		city_ground.visible = city_on
	if city_root:
		city_root.visible = city_on
	if ground_mesh:
		ground_mesh.visible = grid_on
	if meteors:
		meteors.visible = grid_on


func _apply_warp_sky() -> void:
	if sky_mat_space:
		sky_mat_space.set_shader_parameter("warp", _warp_strength)


func _set_demo_playback(on: bool) -> void:
	_demo_playback = on
	if demo_viewport == null:
		return
	demo_viewport.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	demo_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	)


func _reset_ship_visual_offset() -> void:
	if visual_root:
		visual_root.position = Vector3.ZERO
		visual_root.rotation_degrees = Vector3.ZERO


func _tick_grid_energy(t: float) -> void:
	if grid_mat == null or not ground_mesh or not ground_mesh.visible:
		return
	grid_mat.set_shader_parameter("u_energy", clampf(sin(t * 1.8) * 0.35 + 0.55, 0.0, 1.0))
	if meteors and meteors.has_method("get_grid_ripples"):
		grid_mat.set_shader_parameter("u_ripples", meteors.get_grid_ripples())


func _update_space_warp(delta: float, phase: float) -> void:
	_use_space_path()
	_set_surface_kind("none")
	_set_world_mode(WorldMode.SPACE)
	_warp_strength = lerpf(0.15, 1.0, smoothstep(0.0, 0.35, phase))
	_space_u = fmod(_space_u + delta * lerpf(0.05, 0.22, phase), 1.0)
	_set_path_ratio(_space_u)
	_apply_ship_bank(_space_u, delta)
	_apply_exterior_chase_cam()
	_set_exterior_visible(true)
	camera.fov = lerpf(62.0, 88.0, _warp_strength * 0.65)


func _update_planet_reveal(delta: float, phase: float) -> void:
	_use_space_path()
	_set_surface_kind("none")
	_warp_strength = lerpf(1.0, 0.0, phase)
	_set_world_mode(WorldMode.SPACE if phase < 0.55 else WorldMode.ATMOSPHERE)
	_apply_planet_pose(lerpf(0.85, 0.35, phase), lerpf(0.2, 0.75, phase))
	_space_u = fmod(_space_u + delta * 0.06, 1.0)
	_set_path_ratio(_space_u)
	_apply_ship_bank(_space_u, delta)
	_apply_exterior_chase_cam()
	_set_exterior_visible(true)
	camera.fov = lerpf(78.0, 62.0, phase)


func _update_descent_city(delta: float, phase: float) -> void:
	_use_city_path()
	_set_surface_kind("city")
	_set_path_ratio(CITY_U0)
	_apply_ship_bank(CITY_U0, delta)
	visual_root.position.y = lerpf(105.0, 0.0, phase)
	_apply_exterior_chase_cam()
	_apply_transition_to_surface(phase)
	_set_exterior_visible(true)


func _update_city_fly(delta: float, phase: float) -> void:
	_use_city_path()
	_set_surface_kind("city")
	_set_world_mode(WorldMode.CITY)
	var u := lerpf(CITY_U0, RING_U * 0.88, smoothstep(0.0, 1.0, phase))
	_set_path_ratio(u)
	_apply_ship_bank(u, delta)
	_apply_exterior_chase_cam()
	_set_exterior_visible(true)
	_update_ring_glow(u)


func _update_ring_pass(delta: float, phase: float, on_grid: bool) -> void:
	_use_city_path()
	if on_grid:
		_set_surface_kind("grid")
		_set_world_mode(WorldMode.GRID)
		_tick_grid_energy(beat_t)
	else:
		_set_surface_kind("city")
		_set_world_mode(WorldMode.CITY)
	var u0 := RING_U * 0.88 if phase < 0.35 else RING_U
	var u := lerpf(u0, RING_U + 0.04, smoothstep(0.35, 1.0, phase))
	_set_path_ratio(clampf(u, 0.0, 1.0))
	_apply_ship_bank(u, delta)
	_apply_exterior_chase_cam()
	_set_exterior_visible(true)
	_update_ring_glow(u)


func _update_ascend_space(delta: float, phase: float, from_grid: bool) -> void:
	_use_city_path()
	if from_grid:
		_set_surface_kind("grid")
	else:
		_set_surface_kind("city")
	var u := lerpf(RING_U + 0.04, 1.0, smoothstep(0.0, 1.0, phase))
	_set_path_ratio(u)
	_apply_ship_bank(u, delta)
	if from_grid:
		_tick_grid_energy(beat_t)
	_apply_exterior_chase_cam()
	_set_exterior_visible(phase < 0.82)
	_apply_transition_to_space(phase)
	_update_ring_glow(u)
	if phase > 0.78:
		_set_cockpit_hud_visible(true)
		_apply_cockpit_cam(delta)


func _update_descent_grid(delta: float, phase: float) -> void:
	_use_city_path()
	_set_surface_kind("grid")
	_set_path_ratio(CITY_U0)
	_apply_ship_bank(CITY_U0, delta)
	visual_root.position.y = lerpf(100.0, 0.0, phase)
	_apply_exterior_chase_cam()
	_apply_transition_to_surface(phase)
	if phase > 0.55:
		_set_world_mode(WorldMode.GRID)
		_tick_grid_energy(beat_t)
	_set_exterior_visible(true)


func _update_grid_fly(delta: float, phase: float) -> void:
	_use_city_path()
	_set_surface_kind("grid")
	_set_world_mode(WorldMode.GRID)
	var u := lerpf(CITY_U0, RING_U * 0.86, smoothstep(0.0, 1.0, phase))
	_set_path_ratio(u)
	_apply_ship_bank(u, delta)
	_apply_exterior_chase_cam()
	_set_exterior_visible(true)
	_tick_grid_energy(beat_t)
	if phase > 0.72 and ring_mesh:
		ring_mesh.visible = true
	_update_ring_glow(u)


func _update_starfield_travel(delta: float, phase: float, preload_about: bool) -> void:
	_use_space_path()
	_set_surface_kind("none")
	_set_world_mode(WorldMode.SPACE)
	_warp_strength = lerpf(0.0, 0.55, sin(phase * PI) * 0.5 + 0.5)
	_space_u = fmod(_space_u + delta * 0.09, 1.0)
	_set_path_ratio(_space_u)
	_apply_ship_bank(_space_u, delta)
	_apply_planet_pose(lerpf(0.55, 0.25, phase), 0.25)
	if preload_about and phase > 0.35:
		_set_cockpit_hud_visible(true)
		_apply_cockpit_cam(delta)
	else:
		_apply_exterior_chase_cam()
		_set_exterior_visible(true)


func _update_cockpit_standby(delta: float) -> void:
	_use_space_path()
	_set_world_mode(WorldMode.SPACE)
	_set_surface_kind("none")
	_tick_space_drift(delta)
	_apply_cockpit_cam(delta)
	_set_cockpit_hud_visible(true)
	fullscreen_layer.visible = false
	if cockpit_hud:
		cockpit_hud.set_zoom_progress(0.0)


func _update_monitor_zoom_in(delta: float, phase: float) -> void:
	_tick_space_drift(delta)
	_apply_cockpit_cam(delta)
	_set_cockpit_hud_visible(true)
	if cockpit_hud:
		cockpit_hud.set_zoom_progress(phase)
		cockpit_hud.set_crt_mix(1.0 - smoothstep(0.35, 0.85, phase))
	var overlay_u := smoothstep(0.55, 1.0, phase)
	fullscreen_layer.visible = overlay_u > 0.01
	fullscreen_rect.modulate.a = overlay_u
	if overlay_u > 0.85:
		_set_cockpit_hud_visible(false)
	if str(_current_beat().get("id", "")) == "mon_gd_in":
		_update_cockpit_spectacle(delta, false)


func _update_monitor_play(delta: float) -> void:
	_tick_space_drift(delta)
	fullscreen_layer.visible = true
	fullscreen_rect.modulate.a = 1.0
	_set_cockpit_hud_visible(false)
	_apply_cockpit_cam(delta)
	if str(_current_beat().get("id", "")) == "mon_gd":
		_update_cockpit_spectacle(delta, exterior_spectacle.mode != EXTERIOR_SPECTACLE_SCRIPT.Mode.FAULT)


func _update_monitor_zoom_out(delta: float, phase: float) -> void:
	_tick_space_drift(delta)
	var overlay_u := 1.0 - smoothstep(0.0, 0.45, phase)
	fullscreen_layer.visible = overlay_u > 0.01
	fullscreen_rect.modulate.a = overlay_u
	_set_cockpit_hud_visible(true)
	if cockpit_hud:
		cockpit_hud.set_zoom_progress(1.0 - phase)
		cockpit_hud.set_hud_fade(smoothstep(0.2, 0.9, phase))
		cockpit_hud.set_crt_mix(smoothstep(0.35, 1.0, phase))
	_apply_cockpit_cam(delta)
	if str(_current_beat().get("id", "")) == "mon_gd_out":
		_update_cockpit_spectacle(delta, true)


func _update_cockpit_spectacle(delta: float, fault_mode: bool) -> void:
	_use_space_path()
	_set_world_mode(WorldMode.SPACE)
	_set_surface_kind("none")
	_set_exterior_visible(false)
	_tick_space_drift(delta)
	_apply_cockpit_cam(delta)
	_set_cockpit_hud_visible(true)
	fullscreen_layer.visible = false
	if exterior_spectacle:
		exterior_spectacle.tick(delta)
		exterior_spectacle.sync_to_ship(ship_root.global_transform)
	if fault_mode and exterior_spectacle.mode == EXTERIOR_SPECTACLE_SCRIPT.Mode.CROSSFADE:
		pass


func _update_ship_warp_out(delta: float, phase: float) -> void:
	_use_space_path()
	_set_world_mode(WorldMode.SPACE)
	_set_surface_kind("none")
	_warp_strength = lerpf(0.0, 1.0, smoothstep(0.25, 1.0, phase))
	visual_root.rotation_degrees.y = lerpf(0.0, 118.0, smoothstep(0.0, 0.45, phase))
	_space_u = fmod(_space_u + delta * lerpf(0.04, 0.2, phase), 1.0)
	_set_path_ratio(_space_u)
	if phase < 0.42:
		_apply_exterior_chase_cam()
		_set_exterior_visible(true)
	else:
		_set_exterior_visible(false)
		_set_cockpit_hud_visible(true)
		_apply_cockpit_cam(delta)
	camera.fov = lerpf(62.0, 84.0, _warp_strength * 0.7)


func _update_showcase_end(_delta: float) -> void:
	_tick_space_drift(_delta)
	_apply_cockpit_cam(_delta)
	fullscreen_layer.visible = true
	fullscreen_rect.modulate.a = 0.35
	_set_cockpit_hud_visible(true)


func _update_hud_for_beat(beat: Dictionary) -> void:
	title_label.text = str(beat.get("title", ""))
	sub_label.text = str(beat.get("sub", ""))


func _apply_planet_pose(dist: float, approach: float) -> void:
	if planet_mesh == null:
		return
	planet_mesh.visible = dist > 0.02 or approach > 0.05
	var sc := lerpf(3.2, 0.48, clampf(dist, 0.0, 1.0))
	planet_mesh.scale = Vector3.ONE * sc
	planet_mesh.position = Vector3(
		lerpf(6.0, 20.0, dist),
		lerpf(-22.0, -48.0, dist),
		lerpf(55.0, -210.0, dist)
	)
	if planet_mesh.material_override is ShaderMaterial:
		var mat: ShaderMaterial = planet_mesh.material_override
		mat.set_shader_parameter("approach", approach)
		mat.set_shader_parameter("glow", 0.55 + approach * 0.85)
		mat.set_shader_parameter("time_offset", beat_t)


func _apply_transition_to_space(t: float) -> void:
	if t < 0.32:
		_set_world_mode(WorldMode.CITY)
		_apply_planet_pose(0.0, 0.0)
	elif t < 0.68:
		var u := (t - 0.32) / 0.36
		_set_world_mode(WorldMode.ATMOSPHERE)
		sky_mat_planet.set_shader_parameter("entry_phase", 0.25 + u * 0.45)
		sky_mat_planet.set_shader_parameter("space_blend", u * 0.35)
		_apply_planet_pose(u * 0.28, 0.35 + u * 0.45)
	else:
		var u := (t - 0.68) / 0.32
		_set_world_mode(WorldMode.SPACE)
		_apply_planet_pose(lerpf(0.28, 1.0, u), lerpf(0.8, 0.12, u))


func _apply_transition_to_surface(t: float) -> void:
	if t < 0.22:
		var u := t / 0.22
		_set_world_mode(WorldMode.SPACE)
		_apply_planet_pose(lerpf(1.0, 0.62, u), lerpf(0.12, 0.35, u))
	elif t < 0.72:
		var u := (t - 0.22) / 0.5
		_set_world_mode(WorldMode.ATMOSPHERE)
		sky_mat_planet.set_shader_parameter("entry_phase", 0.35 + u * 0.55)
		sky_mat_planet.set_shader_parameter("space_blend", 1.0 - u * 0.92)
		_apply_planet_pose(lerpf(0.62, 0.06, u), lerpf(0.35, 1.0, u))
	else:
		var u := (t - 0.72) / 0.28
		_set_world_mode(WorldMode.CITY)
		_apply_planet_pose(lerpf(0.06, 0.0, u), lerpf(1.0, 0.0, u))


func _path_bank_at(u: float) -> Dictionary:
	var du := 0.018
	var p_l := flight_curve.sample_baked(maxf(0.0, u - du) * _path_length)
	var p_r := flight_curve.sample_baked(minf(1.0, u + du) * _path_length)
	var lateral := p_r.x - p_l.x
	var pitch := p_l.y - p_r.y
	return {
		"roll": clampf(-lateral * 4.2, -42.0, 42.0),
		"pitch": clampf(pitch * 3.2, -28.0, 28.0),
	}


func _apply_ship_bank(u: float, delta: float) -> void:
	var bank := _path_bank_at(u)
	var k := 1.0 - exp(-7.0 * delta)
	visual_root.rotation_degrees.z = lerpf(visual_root.rotation_degrees.z, bank.roll, k)
	visual_root.rotation_degrees.x = lerpf(visual_root.rotation_degrees.x, bank.pitch, k)


func _apply_exterior_chase_cam() -> void:
	var xf := ship_root.global_transform
	var fwd := (-xf.basis.z).normalized()
	var up := xf.basis.y.normalized()
	var blend_up := up.lerp(Vector3.UP, 0.22).normalized()
	camera.global_position = xf.origin - fwd * 3.35 + up * 1.02
	camera.look_at(xf.origin + fwd * 22.0, blend_up)
	camera.fov = 62.0


func _apply_cockpit_cam(delta: float) -> void:
	var cam := _chase_cockpit_cam_local()
	_smooth_camera(_xf(cam.pos), _xf(cam.look), cam.fov, delta, 7.5)


func _set_path_ratio(u: float) -> void:
	path_follow.progress_ratio = clampf(u, 0.0, 1.0)


func _reset_camera_spring() -> void:
	_cam_ready = false


func _smooth_camera(world_pos: Vector3, world_look: Vector3, target_fov: float, delta: float, stiffness: float = 5.5) -> void:
	if not _cam_ready:
		_cam_pos = camera.global_position
		_cam_look = world_look
		_cam_fov = camera.fov
		_cam_ready = true
	var k := 1.0 - exp(-stiffness * delta)
	_cam_pos = _cam_pos.lerp(world_pos, k)
	_cam_look = _cam_look.lerp(world_look, k)
	_cam_fov = lerpf(_cam_fov, target_fov, k)
	camera.global_position = _cam_pos
	camera.look_at(_cam_look, Vector3.UP)
	camera.fov = _cam_fov


func _xf(local: Vector3) -> Vector3:
	return ship_root.global_transform * local


func _align_ring_to_path(fwd: Vector3) -> Basis:
	# TorusMesh default: ring lies flat (hole along Y). Star Fox hoop: hole along flight path.
	var up_ref := Vector3.UP
	if absf(fwd.dot(up_ref)) > 0.92:
		up_ref = Vector3(0, 0, 1)
	var right := up_ref.cross(fwd).normalized()
	var ring_up := fwd.cross(right).normalized()
	return Basis(right, fwd, ring_up)


func _chase_cockpit_cam_local() -> Dictionary:
	var sway_x := sin(beat_t * 0.65) * 0.035
	var sway_y := sin(beat_t * 1.05) * 0.022
	return {
		"pos": Vector3(sway_x, 0.48 + sway_y, 0.42),
		"look": Vector3(sway_x * 0.2, 0.02, -120.0),
		"fov": 76.0,
	}


func _set_cockpit_hud_visible(on: bool) -> void:
	if cockpit_layer:
		cockpit_layer.visible = on
	if on and cockpit_hud:
		cockpit_hud.call_deferred("_sync_viewport_size")


func _set_exterior_visible(on: bool) -> void:
	if exterior_root:
		exterior_root.visible = on


func _setup_environment() -> void:
	environment_node = WorldEnvironment.new()
	var env := Environment.new()
	sky = Sky.new()
	sky_mat_day = ShaderMaterial.new()
	sky_mat_day.shader = load(SKY_DAY)
	sky_mat_space = ShaderMaterial.new()
	sky_mat_space.shader = load(SKY_SPACE)
	sky_mat_planet = ShaderMaterial.new()
	sky_mat_planet.shader = load(SKY_PLANET)
	sky_mat_planet.set_shader_parameter("entry_phase", 0.35)
	sky_mat_planet.set_shader_parameter("space_blend", 0.85)
	sky.sky_material = sky_mat_day
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_density = 0.0008
	env.fog_sky_affect = 0.45
	environment_node.environment = env
	add_child(environment_node)


func _setup_light() -> void:
	sun_light = DirectionalLight3D.new()
	sun_light.light_color = Color(1.0, 0.98, 0.92)
	sun_light.light_energy = 1.05
	sun_light.rotation_degrees = Vector3(-52, 38, 0)
	add_child(sun_light)


func _setup_exterior_spectacle() -> void:
	exterior_spectacle = EXTERIOR_SPECTACLE_SCRIPT.new()
	exterior_spectacle.name = "ExteriorSpectacle"
	add_child(exterior_spectacle)


func _setup_meteors() -> void:
	if is_headless:
		return
	meteors = preload("res://showcase_meteors.gd").new()
	meteors.name = "Meteors"
	meteors.visible = false
	add_child(meteors)


func _build_city_ground() -> void:
	city_ground = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(420, 420)
	city_ground.mesh = plane
	city_ground.position = Vector3(2, -0.02, -28)
	city_ground.material_override = _flat_mat(COL_CITY_GROUND)
	city_ground.visible = false
	add_child(city_ground)


func _nearest_on_path(world_pos: Vector3) -> Dictionary:
	var best_dist := INF
	var best_y := 20.0
	var steps := 64
	for j in steps + 1:
		var u := float(j) / float(steps)
		var p := flight_curve.sample_baked(u * _path_length)
		var d := Vector2(world_pos.x - p.x, world_pos.z - p.z).length()
		if d < best_dist:
			best_dist = d
			best_y = p.y
	return {"dist": best_dist, "path_y": best_y}


func _build_city_along_path() -> void:
	city_root = Node3D.new()
	city_root.name = "City"
	city_root.visible = false
	add_child(city_root)

	var rng := RandomNumberGenerator.new()
	rng.seed = 8080
	var samples := 34

	for i in samples + 1:
		if i % 2 == 1 and i > 0 and i < samples:
			continue
		var u := float(i) / float(samples)
		var center := flight_curve.sample_baked(u * _path_length)
		var center_ahead := flight_curve.sample_baked(clampf(u + 0.02, 0.0, 1.0) * _path_length)
		var forward := (center_ahead - center).normalized()
		var right := forward.cross(Vector3.UP)
		if right.length_squared() < 0.01:
			right = forward.cross(Vector3(0, 0, 1))
		if right.length_squared() < 0.01:
			right = Vector3.RIGHT
		else:
			right = right.normalized()

		for side_i in 2:
			var side: int = -1 if side_i == 0 else 1
			for lane in 2:
				var lane_gap := 14.0 + float(lane) * (BUILDING_SIZE + 10.0)
				var lateral: float = float(side) * (CORRIDOR_HALF + lane_gap)
				var pos: Vector3 = center + right * lateral
				if pos.y < 2.0:
					continue
				var near := _nearest_on_path(pos)
				if near.dist < CORRIDOR_HALF + BUILDING_SIZE * 0.5 + PATH_CLEARANCE:
					continue
				var h := rng.randf_range(12.0, 32.0) if lane == 0 else rng.randf_range(10.0, 22.0)
				var max_top: float = near.path_y - 9.0
				if near.dist < CORRIDOR_HALF + BUILDING_SIZE + 16.0:
					max_top = near.path_y - 11.0
				h = minf(h, maxf(8.0, max_top))
				var col := COL_BUILD_A if (i + lane + side) % 3 != 0 else COL_BUILD_B
				_add_building(city_root, pos, Vector3(BUILDING_SIZE, h, BUILDING_SIZE), col)


func _add_building(parent: Node3D, pos: Vector3, size: Vector3, col: Color) -> void:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.position = Vector3(pos.x, size.y * 0.5, pos.z)
	m.material_override = _flat_mat(col)
	parent.add_child(m)


func _update_ring_glow(u: float) -> void:
	if ring_mesh == null:
		return
	var flash := maxf(0.0, 1.0 - absf(u - RING_U) * 14.0)
	if ring_mesh.material_override is StandardMaterial3D:
		(ring_mesh.material_override as StandardMaterial3D).emission_energy_multiplier = 0.5 + flash * 1.3


func _build_grid_ground() -> void:
	ground_mesh = MeshInstance3D.new()
	ground_mesh.name = "SynthGridGround"
	ground_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var a_mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var uvs := PackedVector2Array()
	var size := GRID_GROUND_SIZE
	var subdivisions := GRID_SUBDIV

	for z in range(subdivisions + 1):
		for x in range(subdivisions + 1):
			var px := (float(x) / float(subdivisions)) * size - (size * 0.5)
			var pz := (float(z) / float(subdivisions)) * size - (size * 0.5)
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
	ground_mesh.mesh = a_mesh
	ground_mesh.position = Vector3(2, -0.05, -28)

	grid_mat = ShaderMaterial.new()
	grid_mat.shader = load(SYNTH_GRID)
	var empty_ripples := PackedVector4Array()
	empty_ripples.resize(4)
	for i in 4:
		empty_ripples[i] = Vector4.ZERO
	grid_mat.set_shader_parameter("u_ripples", empty_ripples)
	grid_mat.set_shader_parameter("u_blend", 1.0)
	grid_mat.set_shader_parameter("u_energy", 0.55)
	ground_mesh.material_override = grid_mat
	ground_mesh.visible = false
	add_child(ground_mesh)


func _build_space_path() -> Curve3D:
	var curve := Curve3D.new()
	curve.add_point(Vector3(-5, 125, 40), Vector3(0, 0, 0), Vector3(3, 0, -28))
	curve.add_point(Vector3(8, 122, -45), Vector3(-2, 0, -26), Vector3(4, -1, -30))
	curve.add_point(Vector3(-6, 118, -130), Vector3(3, 0, -28), Vector3(-3, 1, -26))
	curve.add_point(Vector3(5, 115, -215), Vector3(-2, 0, -24), Vector3(0, 0, 0))
	return curve


func _build_planet() -> void:
	planet_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 95.0
	sphere.height = 180.0
	planet_mesh.mesh = sphere
	planet_mesh.position = Vector3(8, -55, 120)
	planet_mesh.rotation_degrees = Vector3(-12, 24, 0)
	var pmat := ShaderMaterial.new()
	pmat.shader = load(PLANET_BODY)
	planet_mesh.material_override = pmat
	planet_mesh.visible = false
	add_child(planet_mesh)


func _build_weave_path() -> Curve3D:
	var curve := Curve3D.new()
	# Hard S-turns — ship steers; camera stays locked behind.
	curve.add_point(Vector3(0, 26, 70), Vector3(0, 0, 0), Vector3(-10, 0, -22))
	curve.add_point(Vector3(-20, 22, 32), Vector3(-6, -1, -14), Vector3(12, 0, -18))
	curve.add_point(Vector3(22, 19, 0), Vector3(10, -1, -14), Vector3(-12, 1, -16))
	curve.add_point(Vector3(-18, 17, -36), Vector3(-8, 0, -14), Vector3(10, 2, -14))
	curve.add_point(Vector3(16, 20, -68), Vector3(8, 2, -16), Vector3(-8, 2, -14))
	curve.add_point(Vector3(-6, 24, -96), Vector3(-4, 2, -14), Vector3(6, 4, -16))
	curve.add_point(Vector3(6, 38, -122), Vector3(4, 6, -14), Vector3(0, 0, 0))
	return curve


func _build_ring_on_path() -> void:
	var u := RING_U
	var p := flight_curve.sample_baked(u * flight_curve.get_baked_length())
	var p2 := flight_curve.sample_baked(clampf(u + 0.01, 0.0, 1.0) * flight_curve.get_baked_length())
	var fwd := (p2 - p).normalized()
	if fwd.length_squared() < 0.01:
		fwd = Vector3(0, 0, -1)

	ring_mesh = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 7.5
	torus.outer_radius = 9.0
	ring_mesh.mesh = torus
	ring_mesh.position = p
	ring_mesh.basis = _align_ring_to_path(fwd)
	var mat := _flat_mat(Color(0.2, 0.75, 1.0))
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.8, 1.0)
	mat.emission_energy_multiplier = 0.9
	ring_mesh.material_override = mat
	add_child(ring_mesh)


func _build_ship_on_path() -> void:
	flight_path = Path3D.new()
	flight_path.curve = flight_curve
	add_child(flight_path)
	_path_length = flight_curve.get_baked_length()

	path_follow = PathFollow3D.new()
	path_follow.loop = false
	path_follow.rotation_mode = PathFollow3D.ROTATION_ORIENTED
	flight_path.add_child(path_follow)

	ship_root = Node3D.new()
	ship_root.name = "Ship"
	path_follow.add_child(ship_root)

	visual_root = Node3D.new()
	visual_root.name = "Visual"
	ship_root.add_child(visual_root)

	exterior_root = Node3D.new()
	exterior_root.name = "Exterior"
	visual_root.add_child(exterior_root)
	_build_arwing(exterior_root)


func _build_arwing(parent: Node3D) -> void:
	# Arwing-style silhouette: long needle nose, tan dorsal stripe, horizontal blades, blue fins.
	_add_part(parent, Vector3(0, 0, -1.55), Vector3(0.5, 0.36, 2.15), Vector3.ZERO, COL_HULL)
	_add_part(parent, Vector3(0, 0.02, -2.75), Vector3(0.36, 0.26, 1.25), Vector3.ZERO, COL_HULL)
	_add_part(parent, Vector3(0, 0.03, -3.45), Vector3(0.24, 0.18, 0.72), Vector3.ZERO, COL_HULL)
	_add_part(parent, Vector3(0, 0.04, -3.95), Vector3(0.14, 0.12, 0.38), Vector3.ZERO, COL_HULL)
	_add_part(parent, Vector3(0, 0.05, -4.22), Vector3(0.08, 0.08, 0.18), Vector3.ZERO, COL_HULL)
	_add_part(parent, Vector3(0, 0.2, -2.15), Vector3(0.14, 0.045, 2.65), Vector3.ZERO, COL_ACCENT)

	_add_part(parent, Vector3(0, 0, 0.12), Vector3(0.54, 0.4, 1.28), Vector3.ZERO, COL_HULL)
	_add_part(parent, Vector3(0, 0.14, -0.15), Vector3(0.38, 0.18, 0.55), Vector3(-20, 0, 0), COL_HULL)

	# Long horizontal dagger wings.
	_add_part(parent, Vector3(-1.55, 0, 0.18), Vector3(2.75, 0.045, 0.82), Vector3(0, 0, -5), COL_HULL)
	_add_part(parent, Vector3(1.55, 0, 0.18), Vector3(2.75, 0.045, 0.82), Vector3(0, 0, 5), COL_HULL)
	_add_part(parent, Vector3(-2.65, 0, 0.02), Vector3(0.95, 0.035, 0.32), Vector3(0, 0, -10), COL_HULL)
	_add_part(parent, Vector3(2.65, 0, 0.02), Vector3(0.95, 0.035, 0.32), Vector3(0, 0, 10), COL_HULL)

	# Fin root joints.
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			_add_part(
				parent,
				Vector3(float(sx) * 0.3, float(sy) * 0.16, 0.52),
				Vector3(0.2, 0.2, 0.24),
				Vector3.ZERO,
				COL_JOINT
			)

	# Four blue triangular stabilizers (upper/lower, port/starboard).
	_add_arwing_fin(parent, Vector3(-0.26, 0.2, 0.48), Vector3(-1, 1, 1))
	_add_arwing_fin(parent, Vector3(0.26, 0.2, 0.48), Vector3(1, 1, 1))
	_add_arwing_fin(parent, Vector3(-0.26, -0.2, 0.48), Vector3(-1, -1, 1))
	_add_arwing_fin(parent, Vector3(0.26, -0.2, 0.48), Vector3(1, -1, 1))

	_add_part(parent, Vector3(0, 0.08, 1.02), Vector3(0.95, 0.05, 0.48), Vector3(-10, 0, 0), COL_HULL)

	var eng_l := _add_part(parent, Vector3(-0.26, 0, 1.22), Vector3(0.2, 0.2, 0.32), Vector3.ZERO, COL_JOINT)
	var eng_r := _add_part(parent, Vector3(0.26, 0, 1.22), Vector3(0.2, 0.2, 0.32), Vector3.ZERO, COL_JOINT)
	for eng in [eng_l, eng_r]:
		if eng.material_override is StandardMaterial3D:
			var m: StandardMaterial3D = eng.material_override
			m.emission_enabled = true
			m.emission = Color(0.35, 0.85, 1.0)
			m.emission_energy_multiplier = 1.4


func _add_arwing_fin(parent: Node3D, anchor: Vector3, dir: Vector3) -> void:
	var tilt_y := 32.0 * dir.x
	var tilt_x := -38.0 * dir.y
	var fin := _add_prism(parent, anchor, Vector3(0.52, 1.15, 0.09), Vector3(tilt_x, tilt_y, 0), COL_WING_TIP)
	fin.position = anchor + Vector3(dir.x * 0.22, dir.y * 0.22, -0.08)
	_add_part(
		parent,
		fin.position,
		Vector3(0.48, 0.035, 0.095),
		Vector3(tilt_x + 8.0 * dir.y, tilt_y, 0),
		COL_JOINT
	)
	_add_part(
		parent,
		fin.position + Vector3(0, 0.18 * dir.y, 0.02),
		Vector3(0.48, 0.025, 0.095),
		Vector3(tilt_x + 8.0 * dir.y, tilt_y, 0),
		COL_JOINT
	)


func _setup_cockpit_hud() -> void:
	cockpit_layer = CanvasLayer.new()
	cockpit_layer.layer = 6
	cockpit_layer.visible = false
	add_child(cockpit_layer)

	cockpit_hud = COCKPIT_HUD_SCRIPT.new()
	cockpit_hud.name = "CockpitHud"
	cockpit_layer.add_child(cockpit_hud)


func _add_part(parent: Node3D, pos: Vector3, size: Vector3, rot: Vector3, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.position = pos
	m.rotation_degrees = rot
	m.material_override = _flat_mat(col)
	parent.add_child(m)
	return m


func _add_prism(parent: Node3D, pos: Vector3, size: Vector3, rot: Vector3, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = size
	m.mesh = prism
	m.position = pos
	m.rotation_degrees = rot
	m.material_override = _flat_mat(col)
	parent.add_child(m)
	return m


func _flat_mat(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _setup_demo_viewport() -> void:
	demo_viewport = SubViewport.new()
	demo_viewport.size = Vector2i(1280, 720)
	demo_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	demo_viewport.handle_input_locally = false
	add_child(demo_viewport)
	screen_player = SCREEN_PLAYER_SCRIPT.new()
	demo_viewport.add_child(screen_player)


func _setup_cameras() -> void:
	camera = Camera3D.new()
	camera.fov = 68.0
	camera.current = true
	add_child(camera)


func _setup_fullscreen_overlay() -> void:
	fullscreen_layer = CanvasLayer.new()
	fullscreen_layer.layer = 8
	fullscreen_layer.visible = false
	add_child(fullscreen_layer)

	fullscreen_back = ColorRect.new()
	fullscreen_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	fullscreen_back.color = Color(0.008, 0.012, 0.028)
	fullscreen_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fullscreen_layer.add_child(fullscreen_back)

	fullscreen_rect = TextureRect.new()
	fullscreen_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fullscreen_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fullscreen_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fullscreen_rect.texture = demo_viewport.get_texture()
	fullscreen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fullscreen_layer.add_child(fullscreen_rect)


func _setup_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 20
	add_child(hud_layer)
	title_label = Label.new()
	title_label.position = Vector2(16, 12)
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	hud_layer.add_child(title_label)
	sub_label = Label.new()
	sub_label.position = Vector2(16, 40)
	sub_label.add_theme_font_size_override("font_size", 14)
	sub_label.add_theme_color_override("font_color", Color(0.55, 0.95, 1, 0.9))
	hud_layer.add_child(sub_label)
	if not is_headless:
		skip_label = Label.new()
		skip_label.position = Vector2(360, 688)
		skip_label.add_theme_font_size_override("font_size", 13)
		skip_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
		skip_label.text = "SPACE SKIP  ·  CARRIER: GODOT PRIMITIVES  ·  SCREEN: VISUAL GASIC"
		hud_layer.add_child(skip_label)
