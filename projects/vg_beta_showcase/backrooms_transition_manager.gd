extends Node3D
## Backrooms transition director — hub, four halls, portal zoom between showcase demos.
##
## Flow: tour.vg (5s) -> this scene -> for each entry in DEMOS[]:
##   walk hall -> open portal -> zoom in -> PLAY SubViewport demo -> zoom out -> walk to hub -> next hall.
## End: FINISHED screen (P=Storm, R=replay, ESC=quit).
##
## See ARCHITECTURE.md for portal embed contract (set_showcase_frozen, reset_for_portal, vg_portal_embedded).

const SCREEN_PLAYER := preload("res://backrooms_screen.gd")
const HALL_AUDIO := preload("res://backrooms_hall_audio.gd")
const LUCID_MUSIC := preload("res://lucid_music_player.gd")
const FINISHED_SCREEN := preload("res://showcase_finished_screen.gd")
const WALL_TEX := preload("res://assets/backrooms/concrete-wall-diffuse.png")
const CARPET_TEX := preload("res://assets/backrooms/backrooms-carpet-diffuse.png")
const CEILING_TEX := preload("res://assets/backrooms/backrooms-ceiling-tile-diffuse.png")

const STORM_SCENE := "res://storm_main.tscn"
const STORM_PLAY_META := "showcase_play_storm"
const STORM_FROM_END_META := "showcase_storm_from_end"
const RESUME_END_META := "showcase_resume_end"
const DEMO_INDEX_ABOUT := 3
const DEMO_INDEX_DASH := 5
const DEMO_INDEX_STORM := 6
const STORM_MOVIE_CAP_SEC := 45.0
const SKIP_LABEL_TOUR_POS := Vector2(280, 688)
const SKIP_LABEL_TOUR_TEXT := "SPACE SKIP  ·  1 ABOUT  ·  2 END  ·  BACKROOMS TRANSITIONS"
const SKIP_LABEL_FINISHED_TEXT := "P — STORM  ·  R/ENTER — REPLAY  ·  1 — ABOUT  ·  ESC — QUIT"

# Ordered playlist. demo_index % NUM_HALLS selects hall; "segment" splits shader_showcase into three portal visits.
const DEMOS: Array[Dictionary] = [
	{
		"path": "res://shader_showcase_main.tscn",
		"duration": 14.0,
		"segment": 0,
		"title": "Shader Showcase",
		"sub": "Synth grid",
		"portal": "window",
	},
	{
		"path": "res://shader_showcase_main.tscn",
		"duration": 16.0,
		"segment": 1,
		"title": "Shader Showcase",
		"sub": "Liquid chrome",
		"portal": "door",
	},
	{
		"path": "res://shader_showcase_main.tscn",
		"duration": 14.5,
		"segment": 2,
		"title": "Shader Showcase",
		"sub": "Fault cube",
		"portal": "window",
	},
	{
		"path": "res://about_vg_main.tscn",
		"duration": 42.0,
		"segment": -1,
		"title": "About Visual Gasic",
		"sub": "Whenever · Python · system APIs",
		"portal": "door",
		"wait_input": true,
	},
	{
		"path": "res://squash_tease_main.tscn",
		"duration": 20.0,
		"segment": -1,
		"title": "Squash the Creeps",
		"sub": "Godot tutorial game in .vg",
		"portal": "window",
	},
	{
		"path": "res://dash_main.tscn",
		"duration": 30.0,
		"segment": -1,
		"title": "Neon Runner",
		"sub": "Geometry dash tease",
		"portal": "door",
	},
	{
		"path": "res://storm_main.tscn",
		"duration": 60.0,
		"movie_duration": 45.0,
		"segment": -1,
		"title": "Vector Storm",
		"sub": "Attract mode",
		"portal": "window",
	},
]

const T_WALK := 8.0
const T_WALK_BACK := 7.0
const T_TURN_HUB := 1.25
const T_OPEN := 1.35
const T_ZOOM_IN := 2.4
const T_ZOOM_OUT := 2.2
const T_CLOSE := 1.0
const T_END_FADE := 3.0
const MOVIE_FINISHED_HOLD := 20.0

const NUM_HALLS := 4
const HUB_HALF := 2.25
const HALL_LEN := 11.0

const HALL_W := 3.8
const HALL_H := 3.0
const EYE_H := 1.48
const PORTAL_W := 2.0
const PORTAL_H := 1.35
const APPROACH_STOP := 3.5
const SEG_OVERLAP := 0.35
const WALL_UV_PER_M := 0.65  # concrete tiles — higher = finer/smaller pattern
const FLOOR_UV_PER_M := 0.64
const WALL_Y := 1.5  # HALL_H * 0.5 — wall boxes centered here reach floor to ceiling
const END_WALL_OVERLAP := 0.0
# Feature screenshots on hallway walls — set false to disable if too hard to read.
const SHOW_WALL_FRAMES := true
const FRAME_PIC_W := 3.32
const FRAME_PIC_H := 2.68
const FRAME_BORDER := 0.05
const FRAME_Y := WALL_Y
const WALL_FACE_NUDGE := 0.04  # mount slightly into hall from inner wall face

# Rotating gallery — 12 shots, 8 wall slots (2 per hall). Pair advances each hall walk.
const WALL_FRAME_CATALOG: Array[Dictionary] = [
	{"path": "res://assets/wall_frames/immediate_window.png", "caption": "Immediate Window"},
	{"path": "res://assets/wall_frames/platformer_2d.png", "caption": "2D Platformer"},
	{"path": "res://assets/wall_frames/agck_level_editor.png", "caption": "AGCK Level Editor"},
	{"path": "res://assets/wall_frames/working_nodes_manual.png", "caption": "Working Nodes"},
	{"path": "res://assets/wall_frames/agck_actor_paths.png", "caption": "AGCK Actor Paths"},
	{"path": "res://assets/wall_frames/agck_instrument.png", "caption": "AGCK Instrument"},
	{"path": "res://assets/wall_frames/hex_editor.png", "caption": "Hex Editor"},
	{"path": "res://assets/wall_frames/toolbox_properties.png", "caption": "Toolbox & Properties"},
	{"path": "res://assets/wall_frames/thrust_demo.png", "caption": "Thrust Demo"},
	{"path": "res://assets/wall_frames/sprite_editor.png", "caption": "Sprite Editor"},
	{"path": "res://assets/wall_frames/sky_shaders.png", "caption": "Sky Shaders"},
	{"path": "res://assets/wall_frames/theme_picker.png", "caption": "Theme Picker"},
]

# Fixed mount points per hall (along = meters from hub; side ±1 = left/right).
const WALL_FRAME_SLOTS: Array = [
	[{"along": 3.0, "side": -1}, {"along": 7.6, "side": 1}],
	[{"along": 3.4, "side": 1}, {"along": 8.0, "side": -1}],
	[{"along": 2.9, "side": -1}, {"along": 7.3, "side": 1}],
	[{"along": 3.8, "side": 1}, {"along": 8.4, "side": -1}],
]

# Spray-paint tags on hallway walls (hall index, meters from hub, side ±1).
const WALL_GRAFFITI: Array = [
	{
		"hall": 0,
		"along": 4.9,
		"side": 1,
		"text": "Charli was here",
		"color": Color(0.96, 0.18, 0.52, 0.88),
		"y": 1.05,
		"tilt": -14.0,
		"size": 26,
		"style": "tag",
	},
	{
		"hall": 2,
		"along": 5.6,
		"side": -1,
		"text": "Hal Labs",
		"color": Color(0.12, 0.9, 0.78, 0.9),
		"y": 1.82,
		"tilt": 9.0,
		"size": 38,
		"style": "stencil",
	},
	{
		"hall": 1,
		"along": 5.9,
		"side": -1,
		"text": "Don't trust the flies",
		"color": Color(0.92, 0.78, 0.18, 0.86),
		"y": 1.28,
		"tilt": -6.0,
		"size": 22,
		"style": "scrawl",
	},
	{
		"hall": 3,
		"along": 5.2,
		"side": 1,
		"text": "5.4.0-beta1",
		"color": Color(0.72, 0.82, 0.98, 0.88),
		"y": 1.62,
		"tilt": 4.0,
		"size": 32,
		"style": "stencil",
	},
]
# Portal frame is rotated yaw+PI: the hall/camera sits on local -Z, wall interior on +Z.
const PORTAL_HALL_Z := -0.09
const PORTAL_RECESS_Z := 0.035
const WINDOW_OPEN_Y := PORTAL_H - 0.02  # sash bottom clears opening top (PORTAL_H * 0.5)

# Main loop states — driven from _process() and _set_phase().
enum Phase { WALK, OPEN, ZOOM_IN, PLAY, ZOOM_OUT, CLOSE, FINISHED }
enum WalkMode { TO_PORTAL, TO_CENTER, TURN_AT_HUB }
enum FrameLookPhase { NONE, TURN_OUT, HOLD, TURN_BACK }

const T_FRAME_TURN := 0.65
const T_FRAME_HOLD := 2.0
const T_FRAME_HOLD_SHORT := 1.2
const T_FRAME_RETURN := 0.55

const HALL_AMBIENT_TINTS: Array[Color] = [
	Color(0.92, 0.84, 0.96),  # shader / squash — magenta whisper
	Color(0.90, 0.86, 0.99),  # chrome / neon
	Color(0.80, 0.90, 1.0),   # fault / storm — cold blue
	Color(0.96, 0.88, 0.70),  # about — amber
]

const HALL_SIGN_NAMES: PackedStringArray = [
	"SYNTH HALL",
	"CHROME HALL",
	"STORM HALL",
	"ABOUT HALL",
]

var demo_index := 0
var phase := Phase.WALK
var phase_t := 0.0
var play_t := 0.0
var is_headless := false
var movie_mode := false
var use_door := true
var finished := false

var camera: Camera3D
var hallway_root: Node3D
var portal_root: Node3D
var door_panel: MeshInstance3D
var door_pivot: Node3D
var window_sash: MeshInstance3D
var portal_quad: MeshInstance3D
var portal_frame: Node3D
var demo_viewport: SubViewport
var screen_player: Node
var portal_mat: StandardMaterial3D
var portal_void_mat: StandardMaterial3D
var demo_loaded := false
var demo_running := false
var demo_preview_ready := false
var window_glass: MeshInstance3D
var door_handle: Node3D
var sash_mat: StandardMaterial3D
var metal_mat: StandardMaterial3D
var demo_preview_pending := false
var _demo_staging_frames := 0
var fullscreen_layer: CanvasLayer
var fullscreen_rect: TextureRect
var portal_rect: TextureRect
var void_zoom_rect: ColorRect
var hud_layer: CanvasLayer
var title_label: Label
var sub_label: Label
var skip_label: Label
var next_label: Label

var walk_points: PackedVector3Array = PackedVector3Array()
var walk_yaws: PackedFloat32Array = PackedFloat32Array()
var portal_stop_pos: Vector3 = Vector3.ZERO
var portal_door_pos: Vector3 = Vector3.ZERO
var portal_face_yaw: float = 0.0
var wall_tex_mat: StandardMaterial3D
var carpet_tex_mat: StandardMaterial3D
var ceiling_tex_mat: StandardMaterial3D
var door_mat: StandardMaterial3D
var frame_mat: StandardMaterial3D
var light_mat: StandardMaterial3D
var final_walk_start_idx := 0
var _hub_built := false
var _active_hall := 0
var walk_mode := WalkMode.TO_PORTAL
var _hall_portals: Array[Dictionary] = []
var _walk_move_t := 0.0
var _walk_move_u := 0.0
var _frame_look_phase := FrameLookPhase.NONE
var _frame_look_t := 0.0
var _frame_look_pos := Vector3.ZERO
var _frame_look_from_yaw := 0.0
var _frame_look_to_yaw := 0.0
var _frame_look_target := Vector3.ZERO
var _hall_frame_queue: Array = []
var _hall_frame_bindings: Array = [[], [], [], []]
var _gallery_textures: Array[Texture2D] = []
var _hall_visit_count: Array[int] = [0, 0, 0, 0]
var _gallery_walk_serial := 0
var _hall_gallery_base: Array[int] = [0, 2, 4, 6]
var _world_env: Environment
var _hall_audio: Node
var _lucid_music: Node
var _flicker_lights: Array = [{}, {}, {}, {}]
var portal_trim_mat: StandardMaterial3D
var portal_glow_light: OmniLight3D
var _storm_leak: GPUParticles3D
var _punch_layer: CanvasLayer
var _punch_label: Label
var _end_screen_nodes: Array[Node] = []
var _return_face_yaw := 0.0


func _ready() -> void:
	is_headless = DisplayServer.get_name() == "headless"
	movie_mode = OS.has_feature("movie")
	_setup_materials()
	_setup_environment()
	_setup_lights()
	_setup_hallway_root()
	_setup_demo_viewport()
	_setup_fullscreen_overlay()
	_setup_portal_rect()
	_setup_hud()
	_setup_camera()
	if not is_headless:
		_hall_audio = HALL_AUDIO.new()
		add_child(_hall_audio)
		_lucid_music = LUCID_MUSIC.new()
		add_child(_lucid_music)
	if not _ensure_gallery_textures():
		push_warning("Backrooms: wall gallery textures unavailable — frames use placeholder")
	_build_hub_layout()
	if get_tree().root.has_meta(RESUME_END_META):
		get_tree().root.remove_meta(RESUME_END_META)
		_start_finished()
	else:
		_start_demo_cycle()
	set_process_input(true)


func _key_match(event: InputEventKey, key: Key) -> bool:
	return event.keycode == key or event.physical_keycode == key


func _setup_materials() -> void:
	wall_tex_mat = StandardMaterial3D.new()
	wall_tex_mat.albedo_texture = WALL_TEX
	wall_tex_mat.roughness = 0.92
	wall_tex_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	carpet_tex_mat = StandardMaterial3D.new()
	carpet_tex_mat.albedo_texture = CARPET_TEX
	carpet_tex_mat.roughness = 0.98
	carpet_tex_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	ceiling_tex_mat = StandardMaterial3D.new()
	ceiling_tex_mat.albedo_texture = CEILING_TEX
	ceiling_tex_mat.roughness = 0.88
	ceiling_tex_mat.uv1_triplanar = true
	ceiling_tex_mat.uv1_world_triplanar = true
	ceiling_tex_mat.uv1_triplanar_sharpness = 0.9
	ceiling_tex_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	door_mat = StandardMaterial3D.new()
	door_mat.albedo_texture = WALL_TEX
	door_mat.uv1_scale = Vector3(6.0, 4.6, 1.0)
	door_mat.roughness = 0.82
	sash_mat = StandardMaterial3D.new()
	sash_mat.albedo_texture = WALL_TEX
	sash_mat.uv1_scale = Vector3(6.0, 4.6, 1.0)
	sash_mat.roughness = 0.88
	metal_mat = StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.72, 0.68, 0.58)
	metal_mat.metallic = 0.85
	metal_mat.roughness = 0.35
	frame_mat = StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.42, 0.38, 0.28)
	frame_mat.roughness = 0.85
	light_mat = StandardMaterial3D.new()
	light_mat.albedo_color = Color(0.95, 0.98, 0.82)
	light_mat.emission_enabled = true
	light_mat.emission = Color(0.92, 0.96, 0.75)
	light_mat.emission_energy_multiplier = 2.2


func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.5, 0.38)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.88, 0.84, 0.62)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	_world_env = env
	add_child(we)


func _setup_lights() -> void:
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-55, 35, 0)
	fill.light_color = Color(0.98, 0.95, 0.82)
	fill.light_energy = 0.35
	add_child(fill)


func _setup_hallway_root() -> void:
	hallway_root = Node3D.new()
	hallway_root.name = "Hallway"
	add_child(hallway_root)


func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.08
	camera.current = true
	add_child(camera)


func _setup_demo_viewport() -> void:
	demo_viewport = SubViewport.new()
	demo_viewport.size = Vector2i(1280, 720)
	demo_viewport.own_world_3d = true
	demo_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	demo_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	demo_viewport.transparent_bg = false
	demo_viewport.handle_input_locally = false
	demo_viewport.process_mode = Node.PROCESS_MODE_INHERIT
	add_child(demo_viewport)
	screen_player = SCREEN_PLAYER.new()
	screen_player.name = "ScreenPlayer"
	demo_viewport.add_child(screen_player)

	portal_void_mat = StandardMaterial3D.new()
	portal_void_mat.albedo_color = Color(0.12, 0.1, 0.06)
	portal_void_mat.emission_enabled = true
	portal_void_mat.emission = Color(0.42, 0.34, 0.14)
	portal_void_mat.emission_energy_multiplier = 0.65
	portal_void_mat.roughness = 0.9


func _setup_fullscreen_overlay() -> void:
	fullscreen_layer = CanvasLayer.new()
	fullscreen_layer.layer = 8
	fullscreen_layer.visible = false
	add_child(fullscreen_layer)
	fullscreen_rect = TextureRect.new()
	fullscreen_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fullscreen_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fullscreen_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fullscreen_rect.texture = demo_viewport.get_texture()
	fullscreen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fullscreen_layer.add_child(fullscreen_rect)


func _setup_portal_rect() -> void:
	portal_rect = TextureRect.new()
	portal_rect.visible = false
	portal_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portal_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portal_rect.texture = demo_viewport.get_texture()
	portal_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fullscreen_layer.add_child(portal_rect)

	void_zoom_rect = ColorRect.new()
	void_zoom_rect.visible = false
	void_zoom_rect.color = Color(0.14, 0.11, 0.07)
	void_zoom_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fullscreen_layer.add_child(void_zoom_rect)


func _setup_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 20
	add_child(hud_layer)
	title_label = Label.new()
	title_label.position = Vector2(16, 12)
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	hud_layer.add_child(title_label)
	sub_label = Label.new()
	sub_label.position = Vector2(16, 40)
	sub_label.add_theme_font_size_override("font_size", 14)
	sub_label.add_theme_color_override("font_color", Color(0.55, 0.95, 1, 0.85))
	hud_layer.add_child(sub_label)
	if not is_headless:
		skip_label = Label.new()
		skip_label.position = Vector2(280, 688)
		skip_label.add_theme_font_size_override("font_size", 13)
		skip_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.42))
		skip_label.text = "SPACE SKIP  ·  1 ABOUT  ·  2 END  ·  BACKROOMS TRANSITIONS"
		hud_layer.add_child(skip_label)
		next_label = Label.new()
		next_label.position = Vector2(16, 62)
		next_label.add_theme_font_size_override("font_size", 13)
		next_label.add_theme_color_override("font_color", Color(0.78, 0.92, 0.55, 0.9))
		hud_layer.add_child(next_label)


func _start_demo_cycle() -> void:
	if demo_index >= DEMOS.size():
		_start_finished()
		return
	_active_hall = demo_index % NUM_HALLS
	_activate_hall(_active_hall)
	_unload_demo()
	_setup_walk_to_portal(_active_hall)
	_walk_sample(0.0)
	walk_mode = WalkMode.TO_PORTAL
	_set_phase(Phase.WALK)
	_update_hud_demo()
	_stage_demo_behind_portal()


func _clear_hallway() -> void:
	for c in hallway_root.get_children():
		c.queue_free()
	_hall_portals.clear()
	portal_root = null
	door_panel = null
	door_pivot = null
	window_sash = null
	window_glass = null
	door_handle = null
	portal_quad = null
	portal_frame = null
	portal_mat = null
	_flicker_lights = [{}, {}, {}, {}]
	_hall_frame_bindings = [[], [], [], []]


func _hall_yaw(hall: int) -> float:
	return float(hall) * PI * 0.5


func _hub_center_eye() -> Vector3:
	return Vector3(0.0, EYE_H, 0.0)


func _hall_origin(hall: int) -> Vector3:
	return _fwd(_hall_yaw(hall)) * HUB_HALF


func _portal_wall_pos(hall: int) -> Vector3:
	return _hall_origin(hall) + _fwd(_hall_yaw(hall)) * HALL_LEN


func _portal_stop_for_hall(hall: int) -> Vector3:
	var yaw := _hall_yaw(hall)
	var dist := HUB_HALF + HALL_LEN - APPROACH_STOP
	return _fwd(yaw) * dist + Vector3(0.0, EYE_H, 0.0)


# One-time 3D layout: hub carpet, four sealed hall segments, portals, graffiti, initial gallery textures.
func _build_hub_layout() -> void:
	if _hub_built:
		return
	_clear_hallway()
	_hall_frame_bindings = [[], [], [], []]

	var hub := Node3D.new()
	hub.name = "Hub"
	hallway_root.add_child(hub)
	var hub_size := HUB_HALF * 2.0
	_add_box(
		hub,
		Vector3(0.0, -0.05, 0.0),
		Vector3(hub_size, 0.14, hub_size),
		0.0,
		_surface_mat(carpet_tex_mat, Vector3(hub_size * FLOOR_UV_PER_M, 1.0, hub_size * FLOOR_UV_PER_M))
	)
	_add_box(
		hub,
		Vector3(0.0, HALL_H - 0.04, 0.0),
		Vector3(hub_size, 0.12, hub_size),
		0.0,
		_surface_mat(ceiling_tex_mat, Vector3(1.6, 1.6, 1.0))
	)

	for i in range(NUM_HALLS):
		var yaw := _hall_yaw(i)
		var origin := _hall_origin(i)
		_build_sealed_segment(origin, yaw, HALL_LEN, SEG_OVERLAP, END_WALL_OVERLAP, i)
		var is_door := str(DEMOS[i].get("portal", "")) == "door"
		_hall_portals.append(_create_hall_portal(_portal_wall_pos(i), yaw, is_door, i))

	_build_hub_centerpiece(hub)
	_build_hall_signs(hub)
	_build_wall_graffiti()
	for h in range(NUM_HALLS):
		_refresh_hall_gallery(h)
	_hub_built = true


func _ensure_gallery_textures() -> bool:
	if _gallery_textures.size() == WALL_FRAME_CATALOG.size():
		return true
	_gallery_textures.clear()
	for entry in WALL_FRAME_CATALOG:
		var path := str(entry["path"])
		var tex := _load_gallery_texture_from_path(path)
		if tex == null:
			return false
		_gallery_textures.append(tex)
	return true


func _load_gallery_texture_from_path(path: String) -> Texture2D:
	var abs_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		push_error("Backrooms: gallery file not found %s" % path)
		return null
	var image := Image.load_from_file(abs_path)
	if image.is_empty():
		push_error("Backrooms: failed to decode gallery image %s" % path)
		return null
	return ImageTexture.create_from_image(image)


func _gallery_texture(index: int) -> Texture2D:
	if _gallery_textures.is_empty():
		_ensure_gallery_textures()
	if index < 0 or index >= _gallery_textures.size():
		return null
	return _gallery_textures[index]


func _gallery_catalog_index(hall: int, slot: int) -> int:
	return (_hall_gallery_base[hall] + slot) % WALL_FRAME_CATALOG.size()


func _advance_hall_gallery(hall: int) -> void:
	_hall_gallery_base[hall] = (_gallery_walk_serial * 2) % WALL_FRAME_CATALOG.size()
	_gallery_walk_serial += 1


func _refresh_hall_gallery(hall: int) -> void:
	if hall < 0 or hall >= _hall_frame_bindings.size() or _gallery_textures.is_empty():
		return
	for slot_i in _hall_frame_bindings[hall].size():
		var binding: Dictionary = _hall_frame_bindings[hall][slot_i]
		var cat_i := _gallery_catalog_index(hall, slot_i)
		var tex := _gallery_texture(cat_i)
		if tex == null:
			continue
		var mat: StandardMaterial3D = binding["pic_mat"]
		mat.albedo_texture = tex
		mat.emission_texture = tex
		var cap: Label3D = binding.get("caption")
		if cap:
			cap.text = str(WALL_FRAME_CATALOG[cat_i]["caption"])


func _refresh_all_hall_galleries() -> void:
	for h in range(NUM_HALLS):
		_refresh_hall_gallery(h)


func _build_hub_centerpiece(hub: Node3D) -> void:
	var wet := MeshInstance3D.new()
	var wet_mesh := QuadMesh.new()
	wet_mesh.size = Vector2(1.35, 1.35)
	wet.mesh = wet_mesh
	wet.rotation.x = -PI * 0.5
	wet.position = Vector3(0.0, 0.002, 0.0)
	var wet_mat := StandardMaterial3D.new()
	wet_mat.albedo_color = Color(0.12, 0.14, 0.18, 0.42)
	wet_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet_mat.roughness = 0.05
	wet.material_override = wet_mat
	hub.add_child(wet)

	var pedestal := Node3D.new()
	pedestal.name = "CenterPlaque"
	pedestal.position = Vector3(0.0, 0.0, 0.0)
	hub.add_child(pedestal)
	_add_box(pedestal, Vector3(0.0, 0.42, 0.0), Vector3(0.72, 0.84, 0.38), 0.0, frame_mat)
	_add_box(pedestal, Vector3(0.0, 0.88, 0.0), Vector3(0.82, 0.06, 0.44), 0.0, frame_mat)
	var plaque := Label3D.new()
	plaque.text = "VISUAL GASIC\n5.4.0-BETA1"
	plaque.font_size = 28
	plaque.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plaque.position = Vector3(0.0, 0.92, 0.24)
	plaque.modulate = Color(0.95, 0.88, 0.55)
	plaque.outline_size = 6
	plaque.outline_modulate = Color(0.05, 0.04, 0.03, 0.55)
	pedestal.add_child(plaque)


func _build_hall_signs(hub: Node3D) -> void:
	for i in range(NUM_HALLS):
		var yaw := _hall_yaw(i)
		var sign_pos := _hall_origin(i) + _fwd(yaw) * 0.55 + Vector3(0.0, 2.35, 0.0)
		var sign := Label3D.new()
		sign.text = HALL_SIGN_NAMES[i]
		sign.font_size = 22
		sign.modulate = Color(0.82, 0.78, 0.62, 0.75)
		sign.outline_size = 4
		sign.position = sign_pos
		sign.rotation.y = yaw
		hub.add_child(sign)


func _apply_hall_ambient(hall: int) -> void:
	if _world_env == null:
		return
	var base := Color(0.88, 0.84, 0.62)
	var tint := HALL_AMBIENT_TINTS[hall % HALL_AMBIENT_TINTS.size()]
	_world_env.ambient_light_color = base.lerp(tint, 0.24)
	if demo_index == DEMOS.size() - 1 and hall == 2:
		_world_env.ambient_light_color = base.lerp(HALL_AMBIENT_TINTS[2], 0.38)


func _activate_hall(hall: int) -> void:
	_active_hall = hall
	_apply_hall_ambient(hall)
	var pd: Dictionary = _hall_portals[hall]
	portal_root = pd.root
	portal_frame = pd.frame
	portal_quad = pd.quad
	portal_mat = pd.mat
	window_sash = pd.get("sash")
	window_glass = pd.get("glass")
	door_panel = pd.get("door_panel")
	door_pivot = pd.get("door_pivot")
	door_handle = pd.get("door_handle")
	use_door = pd.is_door
	portal_face_yaw = _hall_yaw(hall)
	portal_stop_pos = _portal_stop_for_hall(hall)
	portal_door_pos = _portal_wall_pos(hall) + Vector3(0.0, EYE_H, 0.0)
	portal_trim_mat = pd.get("trim_mat")
	portal_glow_light = pd.get("glow_light")
	_storm_leak = pd.get("storm_leak")
	_reset_portal_seal()
	_update_storm_leak(false, 0.0)


func _reset_portal_seal() -> void:
	if portal_frame:
		var seal := portal_frame.get_node_or_null("SealFill")
		if seal:
			seal.queue_free()
	if use_door and door_pivot:
		door_pivot.rotation.y = 0.0
	elif window_sash:
		window_sash.visible = true
		window_sash.position.y = 0.0
		window_sash.position.z = PORTAL_HALL_Z
	_hide_portal_content()


func _seal_active_portal() -> void:
	if window_sash:
		window_sash.visible = true
		_sync_window_portal(0.0)
	_hide_portal_content()
	if portal_frame and portal_frame.get_node_or_null("SealFill") == null:
		var fill := MeshInstance3D.new()
		fill.name = "SealFill"
		var quad := QuadMesh.new()
		quad.size = Vector2(PORTAL_W - 0.1, PORTAL_H - 0.08)
		fill.mesh = quad
		fill.material_override = _surface_mat(wall_tex_mat, Vector3(WALL_UV_PER_M * 4.0, WALL_UV_PER_M * 4.0, 1.0))
		fill.position = Vector3(0, 0, PORTAL_HALL_Z + 0.01)
		fill.rotation.y = PI
		portal_frame.add_child(fill)


func _fwd(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0.0, -cos(yaw))


func _right(yaw: float) -> Vector3:
	return Vector3(cos(yaw), 0.0, sin(yaw))


func _append_walk_segment(origin: Vector3, yaw: float, length: float, steps: int, yaw_end = null) -> void:
	if steps < 2:
		steps = 2
	for i in range(steps):
		var u := float(i) / float(steps - 1)
		walk_points.append(origin + _fwd(yaw) * length * u + Vector3(0, EYE_H, 0))
		var step_yaw := yaw
		if yaw_end != null and u > 0.4:
			step_yaw = lerp_angle(yaw, float(yaw_end), smoothstep(0.4, 1.0, u))
		walk_yaws.append(step_yaw)


func _append_walk_to_point(from: Vector3, to: Vector3, yaw: float, steps: int) -> void:
	if steps < 2:
		steps = 2
	for i in range(steps):
		var u := float(i) / float(steps - 1)
		walk_points.append(from.lerp(to, u))
		walk_yaws.append(yaw)


# Camera paths for hall approach, return-to-hub, and hub turns between demos.
func _setup_walk_to_portal(hall: int) -> void:
	walk_points = PackedVector3Array()
	walk_yaws = PackedFloat32Array()
	var yaw := _hall_yaw(hall)
	var center := _hub_center_eye()
	var stop := _portal_stop_for_hall(hall)
	var steps := 16
	for i in range(steps):
		var u := float(i) / float(steps - 1)
		walk_points.append(center.lerp(stop, u))
		walk_yaws.append(yaw)
	final_walk_start_idx = maxi(0, walk_points.size() - 5)
	_hall_visit_count[hall] += 1
	_advance_hall_gallery(hall)
	_refresh_hall_gallery(hall)
	_reset_frame_look_for_walk(hall)


func _setup_walk_to_center(hall: int) -> void:
	walk_points = PackedVector3Array()
	walk_yaws = PackedFloat32Array()
	var yaw := _hall_yaw(hall)
	var face_back := yaw + PI
	_return_face_yaw = face_back
	var stop := _portal_stop_for_hall(hall)
	var center := _hub_center_eye()
	var turn_steps := 10
	for i in range(turn_steps):
		var u := float(i) / float(turn_steps - 1)
		walk_points.append(stop)
		walk_yaws.append(lerp_angle(yaw, face_back, smoothstep(0.0, 1.0, u)))
	_append_walk_to_point(stop, center, face_back, 14)
	final_walk_start_idx = 0
	_frame_look_phase = FrameLookPhase.NONE
	_hall_frame_queue.clear()


func _setup_turn_at_hub(from_hall: int, to_hall: int) -> void:
	walk_points = PackedVector3Array()
	walk_yaws = PackedFloat32Array()
	var center := _hub_center_eye()
	var yaw_from := _hall_yaw(from_hall) + PI
	var yaw_to := _hall_yaw(to_hall)
	var steps := 12
	for i in range(steps):
		var u := float(i) / float(steps - 1)
		walk_points.append(center)
		walk_yaws.append(lerp_angle(yaw_from, yaw_to, smoothstep(0.0, 1.0, u)))
	final_walk_start_idx = 0
	_frame_look_phase = FrameLookPhase.NONE
	_hall_frame_queue.clear()


func _begin_next_demo_after_hub() -> void:
	_active_hall = demo_index % NUM_HALLS
	_activate_hall(_active_hall)
	_unload_demo()
	_update_hud_demo()
	_stage_demo_behind_portal()
	_setup_walk_to_portal(_active_hall)
	walk_mode = WalkMode.TO_PORTAL
	phase_t = 0.0
	_walk_sample(0.0)
	_set_phase(Phase.WALK)


func _build_start_cap(origin: Vector3, yaw: float) -> void:
	var seg := Node3D.new()
	hallway_root.add_child(seg)
	var back := origin - _fwd(yaw) * 0.12
	_add_box(
		seg,
		back + Vector3(0, WALL_Y, 0),
		Vector3(HALL_W, HALL_H, 0.18),
		yaw,
		_surface_mat(wall_tex_mat, Vector3(HALL_W * WALL_UV_PER_M, HALL_H * WALL_UV_PER_M, 1.0))
	)


func _build_sealed_segment(origin: Vector3, yaw: float, length: float, overlap_near: float = SEG_OVERLAP, overlap_far: float = END_WALL_OVERLAP, hall_idx: int = -1) -> void:
	var fwd := _fwd(yaw)
	var right := _right(yaw)
	var seg := Node3D.new()
	hallway_root.add_child(seg)
	var span := length + overlap_near + overlap_far
	var center := origin + fwd * (length + overlap_far * 0.5 - span * 0.5)

	_add_box(
		seg,
		center + Vector3(0, -0.05, 0),
		Vector3(HALL_W, 0.14, span),
		yaw,
		_surface_mat(carpet_tex_mat, Vector3(HALL_W * FLOOR_UV_PER_M, 1.0, span * FLOOR_UV_PER_M))
	)
	_build_ceiling_bays(seg, origin, fwd, yaw, length)
	_add_box(
		seg,
		center - right * (HALL_W * 0.5) + Vector3(0, WALL_Y, 0),
		Vector3(0.18, HALL_H, span),
		yaw,
		_surface_mat(wall_tex_mat, Vector3(length * WALL_UV_PER_M, HALL_H * WALL_UV_PER_M, 1.0))
	)
	_add_box(
		seg,
		center + right * (HALL_W * 0.5) + Vector3(0, WALL_Y, 0),
		Vector3(0.18, HALL_H, span),
		yaw,
		_surface_mat(wall_tex_mat, Vector3(length * WALL_UV_PER_M, HALL_H * WALL_UV_PER_M, 1.0))
	)

	var light_step := 3.0
	var count := maxi(1, int(length / light_step))
	var housing_mat := _surface_mat(ceiling_tex_mat, Vector3(1.35, 1.35, 1.0))
	for i in range(count):
		var u := (float(i) + 0.5) / float(count)
		var lp := origin + fwd * (length * u) + Vector3(0, HALL_H - 0.1, 0)
		_add_box(seg, lp, Vector3(HALL_W * 0.58, 0.055, 0.26), yaw, housing_mat)
		var panel_mat := light_mat.duplicate() as StandardMaterial3D
		_add_box(
			seg,
			lp + Vector3(0, -0.016, 0),
			Vector3(HALL_W * 0.4, 0.03, 0.15),
			yaw,
			panel_mat
		)
		var bulb := OmniLight3D.new()
		bulb.position = lp + Vector3(0, -0.08, 0)
		bulb.light_color = Color(0.98, 0.95, 0.78)
		bulb.light_energy = 0.7
		bulb.omni_range = 7.0
		bulb.omni_attenuation = 1.25
		seg.add_child(bulb)
		if hall_idx >= 0 and i == 1:
			_flicker_lights[hall_idx] = {"bulb": bulb, "panel": panel_mat, "base": 0.7}

	if SHOW_WALL_FRAMES and hall_idx >= 0 and hall_idx < WALL_FRAME_SLOTS.size():
		for slot_i in WALL_FRAME_SLOTS[hall_idx].size():
			var slot: Dictionary = WALL_FRAME_SLOTS[hall_idx][slot_i]
			var binding := _add_wall_frame(seg, origin, fwd, right, yaw, slot, hall_idx, slot_i)
			_hall_frame_bindings[hall_idx].append(binding)


func _wall_face_inset() -> float:
	# Wall boxes are 0.18 m thick, centered on ±HALL_W/2 — inner face is 0.09 m further in.
	return HALL_W * 0.5 - 0.09 - WALL_FACE_NUDGE


func _wall_mount_pos(origin: Vector3, fwd: Vector3, right: Vector3, along: float, side: int, y: float) -> Vector3:
	return origin + fwd * along + right * float(side) * _wall_face_inset() + Vector3(0.0, y, 0.0)


func _wall_mount_yaw(yaw: float, side: int) -> float:
	# Quad +Z must point along hall_normal (from wall into the hall).
	var hall_normal := -_right(yaw) * float(side)
	return atan2(hall_normal.x, hall_normal.z)


func _wall_mount_content(parent: Node3D) -> Node3D:
	var content := Node3D.new()
	content.name = "Content"
	parent.add_child(content)
	return content


func _make_picture_mat(tex: Texture2D) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission_texture = tex
	mat.emission_energy_multiplier = 0.28
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


func _add_wall_quad(parent: Node3D, size: Vector2, local_pos: Vector3, mat: Material) -> MeshInstance3D:
	var q := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	q.mesh = quad
	q.position = local_pos
	q.material_override = mat
	parent.add_child(q)
	return q


func _add_wall_frame(parent: Node3D, origin: Vector3, fwd: Vector3, right: Vector3, yaw: float, slot: Dictionary, hall: int, slot_i: int) -> Dictionary:
	var along := float(slot["along"])
	var side := int(slot["side"])
	var cat_i := _gallery_catalog_index(hall, slot_i)
	var tex := _gallery_texture(cat_i)
	if tex == null:
		tex = WALL_TEX
	var caption := str(WALL_FRAME_CATALOG[cat_i]["caption"])
	var pos := _wall_mount_pos(origin, fwd, right, along, side, FRAME_Y)
	var root := Node3D.new()
	root.name = "WallFrame"
	root.position = pos
	root.rotation.y = _wall_mount_yaw(yaw, side)
	parent.add_child(root)

	var pic_w := FRAME_PIC_W
	var pic_h := FRAME_PIC_H
	var b := FRAME_BORDER
	var total_w := pic_w + b * 2.0
	var total_h := pic_h + b * 2.0
	var strip_z := 0.022
	var strip_t := 0.018
	var face_z := 0.045

	_add_wall_quad(root, Vector2(total_w, total_h), Vector3(0.0, 0.0, face_z - 0.016), frame_mat)
	var pic_mat := _make_picture_mat(tex)
	var pic := _add_wall_quad(root, Vector2(pic_w, pic_h), Vector3(0.0, 0.0, face_z), pic_mat)
	pic.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pic.sorting_offset = 0.1
	_add_box(root, Vector3(0.0, total_h * 0.5 - strip_t * 0.5, strip_z), Vector3(total_w, strip_t, 0.025), 0.0, frame_mat)
	_add_box(root, Vector3(0.0, -total_h * 0.5 + strip_t * 0.5, strip_z), Vector3(total_w, strip_t, 0.025), 0.0, frame_mat)
	_add_box(root, Vector3(-total_w * 0.5 + strip_t * 0.5, 0.0, strip_z), Vector3(strip_t, pic_h, 0.025), 0.0, frame_mat)
	_add_box(root, Vector3(total_w * 0.5 - strip_t * 0.5, 0.0, strip_z), Vector3(strip_t, pic_h, 0.025), 0.0, frame_mat)

	var cap := Label3D.new()
	cap.text = caption
	cap.font_size = 16
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.position = Vector3(0.0, -total_h * 0.5 - 0.14, face_z + 0.01)
	cap.modulate = Color(0.92, 0.88, 0.72, 0.82)
	cap.outline_size = 3
	root.add_child(cap)

	var bulb := OmniLight3D.new()
	bulb.position = Vector3(0.0, total_h * 0.5 + 0.12, 0.22)
	bulb.light_color = Color(0.98, 0.96, 0.88)
	bulb.light_energy = 0.18
	bulb.omni_range = 1.6
	bulb.omni_attenuation = 2.0
	root.add_child(bulb)
	return {"pic_mat": pic_mat, "caption": cap}


func _build_wall_graffiti() -> void:
	for entry in WALL_GRAFFITI:
		var hall := int(entry["hall"])
		if hall < 0 or hall >= NUM_HALLS:
			continue
		var yaw := _hall_yaw(hall)
		var origin := _hall_origin(hall)
		_add_wall_graffiti(
			hallway_root,
			origin,
			_fwd(yaw),
			_right(yaw),
			yaw,
			float(entry["along"]),
			int(entry["side"]),
			str(entry["text"]),
			entry["color"] as Color,
			float(entry["y"]),
			float(entry["tilt"]),
			int(entry["size"]),
			str(entry.get("style", "tag"))
		)


func _graffiti_spray_quad(parent: Node3D, size: Vector2, pos: Vector3, color: Color, rot_z: float = 0.0) -> void:
	var bleed := MeshInstance3D.new()
	var bleed_mesh := QuadMesh.new()
	bleed_mesh.size = size
	bleed.mesh = bleed_mesh
	bleed.position = pos
	bleed.rotation_degrees.z = rot_z
	var bleed_mat := StandardMaterial3D.new()
	bleed_mat.albedo_color = color
	bleed_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bleed_mat.roughness = 1.0
	bleed_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bleed.material_override = bleed_mat
	parent.add_child(bleed)


func _graffiti_label(
	parent: Node3D,
	text: String,
	color: Color,
	font_size: int,
	pos: Vector3,
	tilt_deg: float,
	alpha_mul: float = 1.0,
	outline: int = 4
) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.modulate = Color(color.r, color.g, color.b, color.a * alpha_mul)
	label.outline_size = outline
	label.outline_modulate = Color(0.05, 0.04, 0.03, 0.45 * alpha_mul)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = pos
	label.rotation_degrees.z = tilt_deg
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	parent.add_child(label)
	return label


func _graffiti_drip(parent: Node3D, x: float, top_y: float, color: Color, length: float, width: float = 0.012) -> void:
	_graffiti_spray_quad(
		parent,
		Vector2(width, length),
		Vector3(x, top_y - length * 0.5, 0.012),
		Color(color.r, color.g, color.b, color.a * 0.55)
	)


func _graffiti_style_tag(root: Node3D, text: String, color: Color, tilt_deg: float, font_size: int) -> void:
	_graffiti_spray_quad(
		root,
		Vector2(float(text.length()) * 0.062 + 0.22, font_size * 0.005),
		Vector3(0.018, -0.012, 0.008),
		Color(color.r, color.g, color.b, 0.16),
		tilt_deg * 0.5
	)
	_graffiti_label(root, text, color, font_size, Vector3(-0.014, 0.011, 0.018), tilt_deg - 5.0, 0.38, 3)
	_graffiti_label(root, text, color, font_size + 2, Vector3(0.016, -0.008, 0.022), tilt_deg + 4.0, 0.32, 2)
	_graffiti_label(root, text, color, font_size, Vector3(0.0, 0.0, 0.028), tilt_deg, 0.9, 6)
	var drips := [-0.28, -0.08, 0.14, 0.32]
	for i in drips.size():
		_graffiti_drip(root, drips[i], -float(font_size) * 0.0018, color, 0.06 + float(i % 3) * 0.035, 0.01 + float(i % 2) * 0.006)


func _graffiti_style_stencil(root: Node3D, text: String, color: Color, tilt_deg: float, font_size: int) -> void:
	var upper := text.to_upper()
	var block_w := float(upper.length()) * 0.072 + 0.24
	var block_h := font_size * 0.0048
	for i in 4:
		var spread := 0.028 + float(i) * 0.012
		_graffiti_spray_quad(
			root,
			Vector2(block_w + spread, block_h + spread * 0.55),
			Vector3((float(i) - 1.5) * 0.011, (float(i) - 1.5) * 0.008, 0.006 + float(i) * 0.003),
			Color(color.r, color.g, color.b, 0.09 + float(i) * 0.025),
			tilt_deg * 0.35
		)
	_graffiti_label(root, upper, color, font_size + 4, Vector3(0.022, -0.014, 0.018), tilt_deg + 3.0, 0.28, 10)
	_graffiti_label(root, upper, color, font_size, Vector3(0.0, 0.0, 0.028), tilt_deg, 0.92, 8)
	# Overspray outside stencil cut — fat corners.
	for corner in [Vector2(-1.0, 1.0), Vector2(1.0, 1.0), Vector2(-1.0, -1.0), Vector2(1.0, -1.0)]:
		_graffiti_spray_quad(
			root,
			Vector2(0.11, 0.09),
			Vector3(corner.x * block_w * 0.42, corner.y * block_h * 0.35, 0.014),
			Color(color.r, color.g, color.b, 0.2),
			tilt_deg
		)


func _graffiti_style_scrawl(root: Node3D, text: String, color: Color, tilt_deg: float, font_size: int) -> void:
	var words := text.split(" ")
	var x_cursor := -float(text.length()) * 0.028
	for w_idx in words.size():
		var word: String = words[w_idx]
		var wobble := sin(float(w_idx) * 2.17) * 5.0
		for pass_i in 4:
			var jitter := Vector3(
				(sin(float(w_idx * 5 + pass_i) * 1.9) * 0.018),
				(cos(float(w_idx * 3 + pass_i) * 2.3) * 0.014),
				0.014 + float(pass_i) * 0.004
			)
			var pass_size := font_size + pass_i - 2
			var pass_alpha := 0.24 if pass_i < 3 else 0.88
			var pass_tilt := tilt_deg + wobble + float(pass_i - 1) * 2.5
			_graffiti_label(
				root,
				word,
				color,
				pass_size,
				Vector3(x_cursor, 0.0, 0.0) + jitter,
				pass_tilt,
				pass_alpha,
				3 if pass_i < 3 else 5
			)
		x_cursor += float(word.length()) * 0.034 + 0.07
	# Shaky underline scribble.
	for seg in 5:
		var seg_x := -0.42 + float(seg) * 0.17
		_graffiti_spray_quad(
			root,
			Vector2(0.14, 0.022),
			Vector3(seg_x, -0.07 + sin(float(seg) * 1.4) * 0.018, 0.012),
			Color(color.r, color.g, color.b, 0.42),
			tilt_deg + float(seg) * 3.0 - 6.0
		)


func _add_wall_graffiti(
	parent: Node3D,
	origin: Vector3,
	fwd: Vector3,
	right: Vector3,
	yaw: float,
	along: float,
	side: int,
	text: String,
	color: Color,
	y: float,
	tilt_deg: float,
	font_size: int,
	style: String
) -> void:
	var pos := _wall_mount_pos(origin, fwd, right, along, side, y)
	var root := Node3D.new()
	root.name = "Graffiti_" + text.substr(0, min(8, text.length())).replace(" ", "")
	root.position = pos
	root.rotation.y = _wall_mount_yaw(yaw, side)
	parent.add_child(root)
	var content := _wall_mount_content(root)

	match style:
		"stencil":
			_graffiti_style_stencil(content, text, color, tilt_deg, font_size)
		"scrawl":
			_graffiti_style_scrawl(content, text, color, tilt_deg, font_size)
		_:
			_graffiti_style_tag(content, text, color, tilt_deg, font_size)


func _build_ceiling_bays(parent: Node3D, origin: Vector3, fwd: Vector3, yaw: float, length: float) -> void:
	var light_step := 3.0
	var count := maxi(1, int(length / light_step))
	var bays := count + 1
	var ceil_mat := _surface_mat(ceiling_tex_mat, Vector3(1.6, 1.6, 1.6))
	var inset := 0.42
	for b in range(bays):
		var u0 := float(b) / float(bays)
		var u1 := float(b + 1) / float(bays)
		if b > 0:
			u0 += inset / length
		if b < bays - 1:
			u1 -= inset / length
		var bay_len := (u1 - u0) * length
		if bay_len < 0.35:
			continue
		var mid := origin + fwd * (length * (u0 + u1) * 0.5)
		_add_box(
			parent,
			mid + Vector3(0, HALL_H - 0.04, 0),
			Vector3(HALL_W, 0.12, bay_len),
			yaw,
			ceil_mat
		)


func _add_box(parent: Node3D, center: Vector3, size: Vector3, yaw: float, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.position = center
	m.rotation.y = yaw
	m.material_override = mat
	parent.add_child(m)
	return m


func _surface_mat(base: StandardMaterial3D, uv_scale: Vector3) -> StandardMaterial3D:
	var mat := base.duplicate() as StandardMaterial3D
	mat.uv1_scale = uv_scale
	return mat


func _create_hall_portal(wall_pos: Vector3, yaw: float, is_door: bool, hall_idx: int = -1) -> Dictionary:
	var pd: Dictionary = {"is_door": is_door}
	var root := Node3D.new()
	root.name = "PortalWall"
	hallway_root.add_child(root)
	pd.root = root

	var depth := 0.2
	var hall_wall_uv := Vector3(HALL_W * WALL_UV_PER_M, HALL_H * WALL_UV_PER_M, 1.0)
	var cap_mat := _surface_mat(wall_tex_mat, hall_wall_uv)

	var side_strip := (HALL_W - PORTAL_W) * 0.5
	var top_h := maxf(HALL_H - (EYE_H + PORTAL_H * 0.5 + 0.06), 0.4)
	var bot_h := maxf(EYE_H - PORTAL_H * 0.5 - 0.04, 0.4)
	var cap_z := depth * 0.5
	var cap_center := wall_pos + Vector3(0, WALL_Y, 0)
	var wall_node := Node3D.new()
	wall_node.position = cap_center
	wall_node.rotation.y = yaw
	root.add_child(wall_node)

	_add_box(wall_node, Vector3(0.0, 0.0, cap_z), Vector3(HALL_W, HALL_H, depth * 0.55), 0.0, cap_mat)
	_add_box(wall_node, Vector3(-HALL_W * 0.5 + 0.09, 0.0, cap_z), Vector3(0.18, HALL_H, depth), 0.0, cap_mat)
	_add_box(wall_node, Vector3(HALL_W * 0.5 - 0.09, 0.0, cap_z), Vector3(0.18, HALL_H, depth), 0.0, cap_mat)
	_add_box(wall_node, Vector3(-(PORTAL_W * 0.5 + side_strip * 0.5), 0.0, cap_z), Vector3(side_strip, HALL_H, depth), 0.0, cap_mat)
	_add_box(wall_node, Vector3(PORTAL_W * 0.5 + side_strip * 0.5, 0.0, cap_z), Vector3(side_strip, HALL_H, depth), 0.0, cap_mat)
	_add_box(wall_node, Vector3(0.0, EYE_H + PORTAL_H * 0.5 + top_h * 0.5 - WALL_Y, 0.0), Vector3(PORTAL_W + 0.28, top_h, depth), 0.0, cap_mat)
	_add_box(wall_node, Vector3(0.0, bot_h * 0.5 - WALL_Y, 0.0), Vector3(PORTAL_W + 0.28, bot_h, depth), 0.0, cap_mat)

	var frame := Node3D.new()
	frame.position = wall_pos + Vector3(0, EYE_H, 0)
	frame.rotation.y = yaw + PI
	root.add_child(frame)
	pd.frame = frame

	var fw := PORTAL_W + 0.18
	var fh := PORTAL_H + 0.14
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = Color(0.28, 0.22, 0.14)
	trim_mat.emission_enabled = true
	trim_mat.emission = Color(0.55, 0.46, 0.2)
	trim_mat.emission_energy_multiplier = 0.55
	_add_box(frame, Vector3(0, fh * 0.5 - 0.04, 0), Vector3(fw, 0.1, 0.12), 0, trim_mat)
	_add_box(frame, Vector3(0, -fh * 0.5 + 0.04, 0), Vector3(fw, 0.1, 0.12), 0, trim_mat)
	_add_box(frame, Vector3(-fw * 0.5 + 0.04, 0, 0), Vector3(0.1, fh, 0.12), 0, trim_mat)
	_add_box(frame, Vector3(fw * 0.5 - 0.04, 0, 0), Vector3(0.1, fh, 0.12), 0, trim_mat)
	pd.trim_mat = trim_mat

	var glow := OmniLight3D.new()
	glow.name = "PortalGlow"
	glow.position = Vector3(0, 0, -0.25)
	glow.light_color = Color(0.98, 0.92, 0.68)
	glow.light_energy = 0.0
	glow.omni_range = 5.5
	glow.omni_attenuation = 1.4
	frame.add_child(glow)
	pd.glow_light = glow

	if hall_idx == 2:
		pd.storm_leak = _make_storm_leak(frame)
	else:
		pd.storm_leak = null

	var pmat := StandardMaterial3D.new()
	pmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.emission_enabled = true
	pmat.emission_energy_multiplier = 1.0
	pmat.roughness = 0.15
	pd.mat = pmat

	var quad_mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(PORTAL_W, PORTAL_H)
	quad_mi.mesh = quad
	quad_mi.material_override = portal_void_mat
	quad_mi.position = Vector3(0, 0, PORTAL_HALL_Z + 0.05)
	quad_mi.rotation.y = PI
	quad_mi.visible = false
	frame.add_child(quad_mi)
	pd.quad = quad_mi

	if is_door:
		var panel_half := (PORTAL_W - 0.08) * 0.5
		var pivot := Node3D.new()
		pivot.position = Vector3(PORTAL_W * 0.5 - 0.06, 0, PORTAL_HALL_Z)
		frame.add_child(pivot)
		pd.door_pivot = pivot
		var panel := MeshInstance3D.new()
		var door := BoxMesh.new()
		door.size = Vector3(PORTAL_W - 0.08, PORTAL_H - 0.04, 0.08)
		panel.mesh = door
		panel.material_override = door_mat
		panel.position = Vector3(-PORTAL_W * 0.5 + 0.05, 0, 0)
		pivot.add_child(panel)
		pd.door_panel = panel
		pd.door_handle = _add_handle(panel, Vector3(-panel_half + 0.12, 0.0, 0.0))
	else:
		var sill := MeshInstance3D.new()
		var sill_mesh := BoxMesh.new()
		sill_mesh.size = Vector3(PORTAL_W + 0.14, 0.08, 0.1)
		sill.mesh = sill_mesh
		sill.material_override = frame_mat
		sill.position = Vector3(0, -PORTAL_H * 0.5 + 0.05, 0.08)
		frame.add_child(sill)
		var header := MeshInstance3D.new()
		var header_mesh := BoxMesh.new()
		header_mesh.size = Vector3(PORTAL_W + 0.14, 0.1, 0.1)
		header.mesh = header_mesh
		header.material_override = frame_mat
		header.position = Vector3(0, PORTAL_H * 0.5 + 0.02, 0.08)
		frame.add_child(header)
		var sash := MeshInstance3D.new()
		var sash_mesh := BoxMesh.new()
		sash_mesh.size = Vector3(PORTAL_W - 0.06, PORTAL_H - 0.08, 0.07)
		sash.mesh = sash_mesh
		sash.material_override = sash_mat
		sash.position = Vector3(0, 0, PORTAL_HALL_Z)
		frame.add_child(sash)
		pd.sash = sash
		for mx in [-0.28, 0.28]:
			var mullion := MeshInstance3D.new()
			var m_mesh := BoxMesh.new()
			m_mesh.size = Vector3(0.05, PORTAL_H - 0.08, 0.06)
			mullion.mesh = m_mesh
			mullion.material_override = frame_mat
			mullion.position = Vector3(mx, 0, -0.015)
			sash.add_child(mullion)
		var glass := MeshInstance3D.new()
		var glass_mesh := BoxMesh.new()
		glass_mesh.size = Vector3(PORTAL_W - 0.12, PORTAL_H - 0.14, 0.012)
		glass.mesh = glass_mesh
		var glass_mat := StandardMaterial3D.new()
		glass_mat.albedo_color = Color(0.75, 0.82, 0.92, 0.12)
		glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass_mat.roughness = 0.03
		glass.material_override = glass_mat
		glass.position = Vector3(0, 0, PORTAL_RECESS_Z - 0.01)
		glass.visible = false
		frame.add_child(glass)
		pd.glass = glass

	return pd


func _make_storm_leak(frame: Node3D) -> GPUParticles3D:
	var leak := GPUParticles3D.new()
	leak.name = "StormLeak"
	leak.position = Vector3(0, 0, PORTAL_HALL_Z - 0.05)
	leak.emitting = false
	leak.amount = 48
	leak.lifetime = 0.65
	leak.explosiveness = 0.15
	leak.randomness = 0.55
	leak.visibility_aabb = AABB(Vector3(-1.2, -1.0, -0.6), Vector3(2.4, 2.0, 1.2))
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 28.0
	mat.initial_velocity_min = 0.35
	mat.initial_velocity_max = 1.4
	mat.gravity = Vector3(0, 0.15, 0.4)
	mat.scale_min = 0.04
	mat.scale_max = 0.12
	mat.color = Color(0.35, 0.85, 1.0, 0.75)
	leak.process_material = mat
	frame.add_child(leak)
	return leak


func _update_storm_leak(active: bool, amount: float) -> void:
	if _storm_leak == null:
		return
	_storm_leak.emitting = active and amount > 0.42
	if active:
		_storm_leak.amount = int(lerpf(24.0, 72.0, amount))


func _refresh_portal_texture() -> void:
	if portal_mat == null or demo_viewport == null:
		return
	var tex := demo_viewport.get_texture()
	portal_mat.albedo_texture = tex
	portal_mat.emission_texture = tex


func _demo_scene_root() -> Node:
	if screen_player == null or screen_player.get_child_count() == 0:
		return null
	return screen_player.get_child(0)


func _add_handle(parent: Node3D, local_pos: Vector3) -> Node3D:
	var handle_root := Node3D.new()
	handle_root.position = local_pos
	parent.add_child(handle_root)
	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.height = 0.025
	stem_mesh.top_radius = 0.028
	stem_mesh.bottom_radius = 0.028
	stem.mesh = stem_mesh
	stem.material_override = metal_mat
	stem.position = Vector3(0, 0, -0.04)
	handle_root.add_child(stem)
	var bar := MeshInstance3D.new()
	var bar_mesh := CylinderMesh.new()
	bar_mesh.height = 0.13
	bar_mesh.top_radius = 0.018
	bar_mesh.bottom_radius = 0.018
	bar.mesh = bar_mesh
	bar.material_override = metal_mat
	bar.rotation.x = PI * 0.5
	bar.position = Vector3(0, 0, -0.08)
	handle_root.add_child(bar)
	return handle_root


func _is_storm_demo() -> bool:
	if demo_index >= DEMOS.size():
		return false
	return str(DEMOS[demo_index].get("path", "")) == STORM_SCENE


func _apply_storm_portal_preview_hold(root: Node) -> void:
	if root == null or not root.has_method("set_showcase_frozen"):
		return
	root.call("set_showcase_frozen", true)


func _reset_storm_for_zoom_in() -> void:
	if not _is_storm_demo() or not demo_loaded:
		return
	var root := _demo_scene_root()
	if root == null:
		return
	if root.has_method("reset_for_portal"):
		root.call("reset_for_portal")
	if root.has_method("set_showcase_frozen"):
		root.call("set_showcase_frozen", false)


# Instantiate current DEMOS[demo_index] scene into demo_viewport; apply portal hooks per demo type.
func _load_current_demo() -> void:
	if demo_index >= DEMOS.size():
		return
	var path: String = str(DEMOS[demo_index].get("path", ""))
	demo_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	screen_player.call("load_scene", path)
	var root := _demo_scene_root()
	if root and root.has_method("set_portal_segment"):
		var seg := int(DEMOS[demo_index].get("segment", -1))
		root.call("set_portal_segment", seg)
	if root and root.has_method("reset_for_portal"):
		root.call("reset_for_portal")
	if _is_storm_demo():
		_apply_storm_portal_preview_hold(root)
	elif root and root.has_method("set_showcase_frozen"):
		root.call("set_showcase_frozen", false)
	demo_loaded = true
	demo_running = false


func _unload_demo() -> void:
	screen_player.call("clear_beat")
	demo_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	demo_loaded = false
	demo_running = false
	demo_preview_ready = false
	demo_preview_pending = false
	_demo_staging_frames = 0
	_hide_portal_content()
	_use_portal_void_texture()


func _hide_portal_content() -> void:
	if portal_quad:
		portal_quad.visible = false
	if window_glass:
		window_glass.visible = false


func _show_portal_demo() -> void:
	if not demo_loaded:
		return
	_refresh_portal_texture()
	if portal_quad and portal_mat:
		portal_quad.material_override = portal_mat
		portal_quad.visible = true
	if window_glass:
		window_glass.visible = true


func _stage_demo_behind_portal() -> void:
	if demo_preview_ready or demo_preview_pending or demo_index >= DEMOS.size():
		return
	demo_preview_pending = true
	demo_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_load_current_demo()
	_demo_staging_frames = 2
	call_deferred("_tick_demo_staging")


func _tick_demo_staging() -> void:
	if not demo_preview_pending:
		return
	_demo_staging_frames -= 1
	if _demo_staging_frames > 0:
		call_deferred("_tick_demo_staging")
	else:
		_finish_demo_staging()


func _finish_demo_staging() -> void:
	if not demo_preview_pending:
		return
	demo_preview_pending = false
	demo_preview_ready = true
	_refresh_portal_texture()
	if portal_quad and portal_mat:
		portal_quad.material_override = portal_mat
		portal_quad.visible = true
		portal_mat.emission_energy_multiplier = 0.45
	if window_glass:
		window_glass.visible = true


func _prepare_demo_preview() -> void:
	_stage_demo_behind_portal()


func _start_demo() -> void:
	if not demo_loaded:
		_load_current_demo()
	var root := _demo_scene_root()
	if root and root.has_method("begin_portal_play"):
		root.call("begin_portal_play")
	elif root and root.has_method("set_showcase_frozen"):
		root.call("set_showcase_frozen", false)
	demo_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	demo_running = true
	void_zoom_rect.visible = false
	portal_rect.visible = false
	fullscreen_rect.visible = true
	fullscreen_rect.modulate.a = 1.0
	if demo_index == DEMO_INDEX_ABOUT and _lucid_music:
		if _lucid_music.has_method("start_default"):
			_lucid_music.start_default()
		else:
			_lucid_music.start()
	elif demo_index == DEMO_INDEX_DASH and _lucid_music:
		if _lucid_music.has_method("start_playlist"):
			_lucid_music.start_playlist(LUCID_MUSIC.PLAYLIST_DASH, false)
		else:
			_lucid_music.start()


func _pause_demo() -> void:
	if not demo_loaded:
		return
	var root := _demo_scene_root()
	if root and root.has_method("freeze_showcase_frame"):
		root.call("freeze_showcase_frame")
	elif root and root.has_method("set_showcase_frozen"):
		root.call("set_showcase_frozen", true)
	demo_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	demo_running = false
	if (demo_index == DEMO_INDEX_ABOUT or demo_index == DEMO_INDEX_DASH) and _lucid_music and not finished:
		_lucid_music.stop()


func _resume_demo_portal() -> void:
	if not demo_loaded:
		return
	var root := _demo_scene_root()
	if root and root.has_method("resume_portal_preview"):
		root.call("resume_portal_preview")
	elif root and root.has_method("set_showcase_frozen"):
		root.call("set_showcase_frozen", false)
	demo_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	demo_running = false


func _use_portal_void_texture() -> void:
	_hide_portal_content()
	if portal_quad:
		portal_quad.material_override = portal_void_mat


# Phase entry point — wires zoom overlays, demo start/pause, storm reset on ZOOM_IN.
func _set_phase(next: Phase) -> void:
	phase = next
	phase_t = 0.0
	if next == Phase.OPEN:
		_stage_demo_behind_portal()
	elif next == Phase.ZOOM_IN:
		void_zoom_rect.visible = false
		_reset_storm_for_zoom_in()
		# Keep portal_rect — zoom-in continues the open-portal overlay without a flash.
	elif next == Phase.PLAY:
		play_t = 0.0
		_hide_benchmark_punch()
		if hud_layer:
			hud_layer.visible = _hud_visible_for_play()
		_start_demo()
	elif next == Phase.ZOOM_OUT:
		_resume_demo_portal()
		# Avoid one blank frame before _update_zoom_out runs.
		fullscreen_layer.visible = true
	elif next == Phase.CLOSE:
		_show_portal_demo()
		if not use_door:
			_sync_window_portal(1.0)
		fullscreen_layer.visible = true
	match phase:
		Phase.WALK:
			hallway_root.visible = true
			fullscreen_layer.visible = false
			if hud_layer:
				hud_layer.visible = _hud_visible_for_walk()
		Phase.OPEN, Phase.ZOOM_IN, Phase.ZOOM_OUT, Phase.CLOSE:
			hallway_root.visible = true
			if hud_layer:
				hud_layer.visible = _hud_visible_for_walk()
			# fullscreen_layer toggled by _update_open / _update_zoom_in / _update_zoom_out / _update_close
		Phase.PLAY:
			fullscreen_layer.visible = true
			fullscreen_rect.visible = true
			fullscreen_rect.modulate.a = 1.0
			portal_rect.visible = false
			if hud_layer:
				hud_layer.visible = _hud_visible_for_play()
		Phase.FINISHED:
			hallway_root.visible = false
			fullscreen_layer.visible = true


func _hud_visible_for_play() -> bool:
	return not is_headless and not movie_mode and _demo_waits_for_input()


func _hud_visible_for_walk() -> bool:
	return not is_headless and not movie_mode


func _demo_waits_for_input() -> bool:
	if demo_index >= DEMOS.size():
		return false
	return bool(DEMOS[demo_index].get("wait_input", false))


func _advance_play_on_input() -> void:
	if phase != Phase.PLAY or not _demo_waits_for_input() or is_headless:
		return
	_set_phase(Phase.ZOOM_OUT)


# Per-frame: phase machine, portal FX, walk sampling, late demo staging on hall approach.
func _process(delta: float) -> void:
	if finished:
		_update_finished(delta)
		return
	phase_t += delta
	match phase:
		Phase.WALK:
			_update_walk(delta)
			var walk_done := false
			match walk_mode:
				WalkMode.TO_PORTAL:
					walk_done = (
						_walk_move_u >= 1.0
						and _frame_look_phase == FrameLookPhase.NONE
						and _hall_frame_queue.is_empty()
					)
				_:
					walk_done = phase_t >= _walk_duration()
			if walk_done:
				match walk_mode:
					WalkMode.TO_PORTAL:
						_set_phase(Phase.OPEN)
					WalkMode.TO_CENTER:
						demo_index += 1
						if demo_index >= DEMOS.size():
							_start_finished()
						else:
							var next_hall := demo_index % NUM_HALLS
							_setup_turn_at_hub(_active_hall, next_hall)
							walk_mode = WalkMode.TURN_AT_HUB
							phase_t = 0.0
					WalkMode.TURN_AT_HUB:
						_begin_next_demo_after_hub()
		Phase.OPEN:
			_update_open()
			if phase_t >= T_OPEN:
				_set_phase(Phase.ZOOM_IN)
		Phase.ZOOM_IN:
			_update_zoom_in()
			if phase_t >= T_ZOOM_IN:
				_set_phase(Phase.PLAY) # _start_demo() runs inside _set_phase
		Phase.PLAY:
			play_t += delta
			_update_play()
			var zoom_out := false
			if movie_mode and _demo_waits_for_input():
				if demo_index == DEMO_INDEX_ABOUT:
					var root := _demo_scene_root()
					if root:
						if root.has_method("movie_play_complete"):
							zoom_out = bool(root.call("movie_play_complete"))
						else:
							zoom_out = bool(root.get("ready_to_continue"))
				var dur_wait: float = float(DEMOS[demo_index].get("duration", 30.0))
				if play_t >= dur_wait:
					zoom_out = true
			elif movie_mode and demo_index == DEMO_INDEX_STORM:
				var storm_root := _demo_scene_root()
				if storm_root and storm_root.has_method("movie_play_complete"):
					zoom_out = bool(storm_root.call("movie_play_complete"))
				if play_t >= STORM_MOVIE_CAP_SEC:
					zoom_out = true
			elif not _demo_waits_for_input():
				var dur: float = float(DEMOS[demo_index].get("duration", 30.0))
				if movie_mode and DEMOS[demo_index].has("movie_duration"):
					dur = float(DEMOS[demo_index].get("movie_duration"))
				if play_t >= dur:
					zoom_out = true
			if zoom_out:
				_set_phase(Phase.ZOOM_OUT)
		Phase.ZOOM_OUT:
			_update_zoom_out()
			if phase_t >= T_ZOOM_OUT:
				_set_phase(Phase.CLOSE)
		Phase.CLOSE:
			_update_close()
			if phase_t >= T_CLOSE:
				if demo_index >= DEMOS.size() - 1:
					_start_finished()
				else:
					_pause_demo()
					_unload_demo()
					_seal_active_portal()
					_setup_walk_to_center(_active_hall)
					walk_mode = WalkMode.TO_CENTER
					phase_t = 0.0
					phase = Phase.WALK
					_walk_sample(0.0)
	if demo_loaded and phase in [Phase.OPEN, Phase.ZOOM_IN, Phase.ZOOM_OUT, Phase.CLOSE]:
		_refresh_portal_texture()
	if phase == Phase.WALK and walk_mode == WalkMode.TO_PORTAL and _is_on_final_approach() and not demo_preview_ready and not demo_preview_pending:
		_stage_demo_behind_portal()
	_update_flicker_lights(delta)
	_update_portal_effects()
	_update_hud_phase()


func _walk_duration() -> float:
	match walk_mode:
		WalkMode.TO_CENTER:
			return T_WALK_BACK
		WalkMode.TURN_AT_HUB:
			return T_TURN_HUB
		_:
			return T_WALK


func _walk_sample(u: float) -> void:
	if walk_points.is_empty():
		return
	var idx_f := u * float(walk_points.size() - 1)
	var idx := int(idx_f)
	var frac := idx_f - float(idx)
	idx = clampi(idx, 0, walk_points.size() - 1)
	var idx2 := mini(idx + 1, walk_points.size() - 1)
	var p := walk_points[idx].lerp(walk_points[idx2], frac)
	var bob := sin(u * TAU * 3.2) * 0.012
	camera.position = p + Vector3(0, bob, 0)
	if walk_mode == WalkMode.TO_PORTAL:
		camera.fov = lerpf(62.0, 63.2, sin(u * PI))
	else:
		camera.fov = 62.0

	var look_yaw := portal_face_yaw
	if walk_yaws.size() == walk_points.size():
		look_yaw = lerp_angle(walk_yaws[idx], walk_yaws[idx2], frac)
	elif idx < walk_yaws.size():
		look_yaw = walk_yaws[idx]

	var ahead := camera.position + _fwd(look_yaw) * 4.0
	ahead.y = camera.position.y
	var portal_look := portal_door_pos
	portal_look.y = camera.position.y
	var look_at_pos := ahead
	if walk_mode == WalkMode.TO_PORTAL and final_walk_start_idx > 0:
		var approach_u := clampf((idx_f - float(final_walk_start_idx - 1)) / 4.0, 0.0, 1.0)
		look_at_pos = ahead.lerp(portal_look, smoothstep(0.0, 1.0, approach_u))
	elif walk_mode == WalkMode.TO_CENTER:
		var hub_look := _hub_center_eye()
		hub_look.y = camera.position.y + 0.04
		var walk_u := smoothstep(0.0, 1.0, phase_t / _walk_duration())
		if walk_u > 0.28:
			var pan_u := smoothstep(0.28, 1.0, walk_u)
			var side_glance := camera.position + _right(_return_face_yaw) * 1.1 + _fwd(_return_face_yaw) * 1.8
			side_glance.y = camera.position.y + 0.02
			look_at_pos = look_at_pos.lerp(hub_look, pan_u * 0.55).lerp(side_glance, pan_u * 0.22)
	camera.look_at(look_at_pos, Vector3.UP)


func _reset_frame_look_for_walk(hall: int) -> void:
	_walk_move_t = 0.0
	_walk_move_u = 0.0
	_frame_look_phase = FrameLookPhase.NONE
	_frame_look_t = 0.0
	_hall_frame_queue = _build_frame_look_queue(hall)


func _frame_hold_duration() -> float:
	if demo_index >= 3:
		return T_FRAME_HOLD_SHORT
	return T_FRAME_HOLD


func _build_frame_look_queue(hall: int) -> Array:
	var queue: Array = []
	if not SHOW_WALL_FRAMES or hall < 0 or hall >= WALL_FRAME_SLOTS.size():
		return queue
	var visit := _hall_visit_count[hall]
	var yaw := _hall_yaw(hall)
	var origin := _hall_origin(hall)
	var fwd := _fwd(yaw)
	var right := _right(yaw)
	var center := _hub_center_eye()
	var stop := _portal_stop_for_hall(hall)
	var frame_idx := 0
	for slot in WALL_FRAME_SLOTS[hall]:
		if visit > 1 and frame_idx > 0:
			frame_idx += 1
			continue
		frame_idx += 1
		var along := float(slot["along"])
		var side := int(slot["side"])
		var frame_pos := _wall_mount_pos(origin, fwd, right, along, side, FRAME_Y)
		queue.append({
			"u": _project_u_on_walk(center, stop, frame_pos),
			"yaw": _wall_mount_yaw(yaw, side),
			"frame_pos": frame_pos,
		})
	queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["u"]) < float(b["u"])
	)
	return queue


func _project_u_on_walk(start: Vector3, end: Vector3, point: Vector3) -> float:
	var a := Vector2(start.x, start.z)
	var b := Vector2(end.x, end.z)
	var p := Vector2(point.x, point.z)
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return 0.5
	var t := (p - a).dot(ab) / len_sq
	return clampf(t, 0.1, 0.9)


func _begin_frame_look(frame: Dictionary) -> void:
	_walk_sample(_walk_move_u)
	_frame_look_pos = camera.position
	_frame_look_from_yaw = _hall_yaw(_active_hall)
	_frame_look_to_yaw = float(frame["yaw"])
	_frame_look_target = frame["frame_pos"] as Vector3
	_frame_look_phase = FrameLookPhase.TURN_OUT
	_frame_look_t = 0.0


func _look_point_from_yaw(pos: Vector3, yaw: float, dist: float = 4.0) -> Vector3:
	var target := pos + _fwd(yaw) * dist
	target.y = pos.y + 0.04
	return target


func _apply_frame_look_camera(pos: Vector3, look_at_pos: Vector3) -> void:
	camera.position = pos
	look_at_pos.y = pos.y + 0.04
	camera.look_at(look_at_pos, Vector3.UP)


func _update_frame_look(delta: float) -> void:
	_frame_look_t += delta
	match _frame_look_phase:
		FrameLookPhase.TURN_OUT:
			var t := clampf(_frame_look_t / T_FRAME_TURN, 0.0, 1.0)
			var from_look := _look_point_from_yaw(_frame_look_pos, _frame_look_from_yaw)
			var look_pt := from_look.lerp(_frame_look_target, smoothstep(0.0, 1.0, t))
			_apply_frame_look_camera(_frame_look_pos, look_pt)
			if _frame_look_t >= T_FRAME_TURN:
				_frame_look_phase = FrameLookPhase.HOLD
				_frame_look_t = 0.0
		FrameLookPhase.HOLD:
			_apply_frame_look_camera(_frame_look_pos, _frame_look_target)
			if _frame_look_t >= _frame_hold_duration():
				_frame_look_phase = FrameLookPhase.TURN_BACK
				_frame_look_t = 0.0
		FrameLookPhase.TURN_BACK:
			var t := clampf(_frame_look_t / T_FRAME_RETURN, 0.0, 1.0)
			var to_look := _look_point_from_yaw(_frame_look_pos, _frame_look_from_yaw)
			var look_pt := _frame_look_target.lerp(to_look, smoothstep(0.0, 1.0, t))
			_apply_frame_look_camera(_frame_look_pos, look_pt)
			if _frame_look_t >= T_FRAME_RETURN:
				_frame_look_phase = FrameLookPhase.NONE
				_frame_look_t = 0.0


func _update_walk_to_portal(delta: float) -> void:
	if _frame_look_phase != FrameLookPhase.NONE:
		_update_frame_look(delta)
		return

	_walk_move_t += delta
	_walk_move_u = smoothstep(0.0, 1.0, _walk_move_t / T_WALK)

	if not _hall_frame_queue.is_empty() and _walk_move_u >= float(_hall_frame_queue[0]["u"]):
		var frame: Dictionary = _hall_frame_queue.pop_front()
		_begin_frame_look(frame)
		return

	_walk_sample(_walk_move_u)


func _update_walk(delta: float) -> void:
	if walk_mode == WalkMode.TO_PORTAL and SHOW_WALL_FRAMES:
		_update_walk_to_portal(delta)
		return
	var u := smoothstep(0.0, 1.0, phase_t / _walk_duration())
	_walk_sample(u)


func _walk_progress() -> float:
	if walk_points.size() < 2:
		return 0.0
	if walk_mode == WalkMode.TO_PORTAL and SHOW_WALL_FRAMES:
		return _walk_move_u
	var idx_f := smoothstep(0.0, 1.0, phase_t / _walk_duration()) * float(walk_points.size() - 1)
	return idx_f / float(walk_points.size() - 1)


func _is_on_final_approach() -> bool:
	if walk_points.is_empty():
		return false
	var idx_f := _walk_progress() * float(walk_points.size() - 1)
	return int(idx_f) >= final_walk_start_idx


func _portal_open_amount(t: float) -> float:
	return smoothstep(0.0, 1.0, t)


func _portal_zoom_alpha(u: float, demo_ready: bool) -> float:
	if demo_ready:
		return 1.0
	return smoothstep(0.08, 1.0, u)


func _sync_window_portal(open_u: float) -> void:
	if use_door or window_sash == null:
		return
	window_sash.position.y = lerpf(0.0, WINDOW_OPEN_Y, open_u)
	# Open: hide sash so the portal/overlay is unobstructed. Closing: sash in front occludes the quad.
	window_sash.visible = open_u < 0.985
	if window_sash.visible:
		window_sash.position.z = PORTAL_HALL_Z


func _face_portal(dolly: float = 0.0, _face_yaw: float = portal_face_yaw) -> void:
	var bob := sin(phase_t * 4.5) * 0.008
	camera.position = portal_stop_pos + _fwd(_face_yaw) * dolly
	camera.position.y += bob
	var look_at_pos := portal_door_pos
	look_at_pos.y = camera.position.y
	camera.look_at(look_at_pos, Vector3.UP)


func _update_open() -> void:
	var u := _portal_open_amount(phase_t / T_OPEN)
	_face_portal()
	if demo_preview_ready:
		_refresh_portal_texture()
		if portal_mat:
			portal_mat.emission_energy_multiplier = lerpf(0.85, 1.2, u)
		var rect := _portal_screen_rect()
		fullscreen_layer.visible = true
		_apply_portal_rect(rect, smoothstep(0.08, 1.0, u))
	if use_door and door_pivot:
		door_pivot.rotation.y = -u * deg_to_rad(92.0)
	else:
		_sync_window_portal(u)


func _portal_screen_rect() -> Rect2:
	if portal_quad == null or camera == null:
		return Rect2(420, 180, 440, 300)
	var corners: Array[Vector3] = [
		portal_quad.to_global(Vector3(-PORTAL_W * 0.5, -PORTAL_H * 0.5, 0)),
		portal_quad.to_global(Vector3(PORTAL_W * 0.5, -PORTAL_H * 0.5, 0)),
		portal_quad.to_global(Vector3(PORTAL_W * 0.5, PORTAL_H * 0.5, 0)),
		portal_quad.to_global(Vector3(-PORTAL_W * 0.5, PORTAL_H * 0.5, 0)),
	]
	var min_p := Vector2(99999, 99999)
	var max_p := Vector2(-99999, -99999)
	for c in corners:
		var sp := camera.unproject_position(c)
		min_p.x = minf(min_p.x, sp.x)
		min_p.y = minf(min_p.y, sp.y)
		max_p.x = maxf(max_p.x, sp.x)
		max_p.y = maxf(max_p.y, sp.y)
	return Rect2(min_p, max_p - min_p)


func _apply_void_rect(rect: Rect2, alpha: float) -> void:
	var show := alpha > 0.01
	void_zoom_rect.visible = show
	portal_rect.visible = false
	fullscreen_rect.visible = false
	if show:
		void_zoom_rect.modulate.a = alpha
		void_zoom_rect.position = rect.position
		void_zoom_rect.size = rect.size


func _apply_portal_rect(rect: Rect2, alpha: float) -> void:
	var show := alpha > 0.01
	portal_rect.visible = show
	void_zoom_rect.visible = false
	fullscreen_rect.visible = false
	if show:
		portal_rect.modulate.a = alpha
		portal_rect.position = rect.position
		portal_rect.size = rect.size


func _update_flicker_lights(delta: float) -> void:
	if finished or _active_hall < 0 or _active_hall >= _flicker_lights.size():
		return
	var flick: Dictionary = _flicker_lights[_active_hall]
	if flick.is_empty():
		return
	var bulb: OmniLight3D = flick.get("bulb")
	var panel: StandardMaterial3D = flick.get("panel")
	var base_energy: float = flick.get("base", 0.7)
	if bulb == null:
		return
	var flicker := 1.0
	if randf() < delta * 2.8:
		flicker = randf_range(0.38, 0.94)
	bulb.light_energy = base_energy * flicker
	if panel:
		panel.emission_energy_multiplier = lerpf(1.4, 2.6, flicker)


func _update_portal_effects() -> void:
	var approach := 0.0
	if phase == Phase.WALK and walk_mode == WalkMode.TO_PORTAL:
		approach = smoothstep(0.5, 1.0, _walk_move_u)
	elif phase in [Phase.OPEN, Phase.ZOOM_IN]:
		approach = 1.0
	if portal_trim_mat:
		portal_trim_mat.emission_energy_multiplier = lerpf(0.55, 1.4, approach)
	if portal_glow_light:
		portal_glow_light.light_energy = lerpf(0.0, 0.9, approach)
		if demo_index == DEMOS.size() - 1:
			portal_glow_light.light_color = Color(0.55, 0.82, 1.0).lerp(Color(0.98, 0.92, 0.68), 1.0 - approach * 0.5)
	if _hall_audio and _hall_audio.has_method("set_portal_bleed"):
		_hall_audio.call("set_portal_bleed", approach, demo_index)
	var storm_active := demo_index == DEMOS.size() - 1 and _active_hall == 2
	_update_storm_leak(storm_active, approach if storm_active else 0.0)


func _is_about_demo() -> bool:
	if demo_index >= DEMOS.size():
		return false
	return str(DEMOS[demo_index].get("path", "")).contains("about_vg")


func _show_benchmark_punch() -> void:
	if _punch_layer != null or is_headless:
		return
	_punch_layer = CanvasLayer.new()
	_punch_layer.layer = 35
	add_child(_punch_layer)
	var back := ColorRect.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.color = Color(0.01, 0.04, 0.02, 0.72)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_punch_layer.add_child(back)
	_punch_label = Label.new()
	_punch_label.set_anchors_preset(Control.PRESET_CENTER)
	_punch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_punch_label.text = "52× FASTER\nTHAN GDSCRIPT"
	_punch_label.add_theme_font_size_override("font_size", 54)
	_punch_label.add_theme_color_override("font_color", Color(0.38, 0.98, 0.68))
	_punch_layer.add_child(_punch_label)


func _hide_benchmark_punch() -> void:
	if _punch_layer:
		_punch_layer.queue_free()
	_punch_layer = null
	_punch_label = null


func _update_zoom_in() -> void:
	var u := smoothstep(0.0, 1.0, phase_t / T_ZOOM_IN)
	_face_portal()
	if _is_about_demo():
		if u >= 0.18 and u <= 0.52:
			_show_benchmark_punch()
			if _punch_label:
				var punch_u := clampf((u - 0.18) / 0.34, 0.0, 1.0)
				var alpha := sin(punch_u * PI)
				_punch_label.modulate.a = alpha
				if _punch_layer.get_child_count() > 0:
					var punch_back: ColorRect = _punch_layer.get_child(0)
					punch_back.modulate.a = alpha * 0.85
		elif u > 0.58:
			_hide_benchmark_punch()
	else:
		_hide_benchmark_punch()
	if use_door and door_pivot:
		door_pivot.rotation.y = -deg_to_rad(92.0)
	else:
		_sync_window_portal(1.0)

	var start_rect := _portal_screen_rect()
	var end_rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var cur := Rect2(
		start_rect.position.lerp(end_rect.position, u),
		start_rect.size.lerp(end_rect.size, u)
	)
	fullscreen_layer.visible = true
	if demo_preview_ready:
		_apply_portal_rect(cur, _portal_zoom_alpha(u, true))
		if portal_mat:
			portal_mat.emission_energy_multiplier = lerpf(0.4, 1.1, u)
	else:
		_apply_void_rect(cur, smoothstep(0.08, 1.0, u))
		if portal_void_mat:
			portal_void_mat.emission_energy_multiplier = lerpf(0.65, 1.15, u)

	if u > 0.82:
		hallway_root.visible = false


func _update_play() -> void:
	fullscreen_layer.visible = true
	fullscreen_rect.visible = true
	fullscreen_rect.modulate.a = 1.0
	portal_rect.visible = false
	void_zoom_rect.visible = false


func _update_zoom_out() -> void:
	var u := smoothstep(0.0, 1.0, phase_t / T_ZOOM_OUT)
	hallway_root.visible = true
	fullscreen_layer.visible = true

	_face_portal()

	var start_rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var end_rect := _portal_screen_rect()
	var cur := start_rect
	cur.position = start_rect.position.lerp(end_rect.position, u)
	cur.size = start_rect.size.lerp(end_rect.size, u)
	# Shrink the frozen PLAY frame into the portal — no extra hall-camera dolly.
	# Hold full opacity until CLOSE — avoid exposing bare wall behind the open frame.
	var demo_alpha := 1.0 if demo_loaded else 0.0
	_apply_portal_rect(cur, demo_alpha)

	if demo_loaded:
		_show_portal_demo()
		if portal_mat:
			portal_mat.emission_energy_multiplier = lerpf(1.2, 0.95, u)
		if not use_door:
			_sync_window_portal(1.0)


func _portal_close_overlay_alpha(portal_open: float) -> float:
	# 2D overlay only while the sash is fully open; once it descends, the 3D sash occludes the portal.
	if portal_open >= 0.985:
		return 1.0
	return 0.0


func _update_close() -> void:
	var u := smoothstep(0.0, 1.0, phase_t / T_CLOSE)
	var portal_open := 1.0 - u
	hallway_root.visible = true
	void_zoom_rect.visible = false
	fullscreen_rect.visible = false
	_face_portal()
	if demo_loaded:
		_show_portal_demo()
		var overlay_alpha := _portal_close_overlay_alpha(portal_open)
		if overlay_alpha > 0.01:
			fullscreen_layer.visible = true
			_apply_portal_rect(_portal_screen_rect(), overlay_alpha)
		else:
			fullscreen_layer.visible = false
			portal_rect.visible = false
		if portal_quad:
			portal_quad.visible = portal_open > 0.04
	else:
		fullscreen_layer.visible = false
		portal_rect.visible = false
	if use_door and door_pivot:
		door_pivot.rotation.y = lerpf(-deg_to_rad(92.0), 0.0, u)
	else:
		_sync_window_portal(portal_open)
	if u >= 0.995:
		fullscreen_layer.visible = false
		portal_rect.visible = false
		_pause_demo()
		_hide_portal_content()
		_use_portal_void_texture()


# End-of-tour card; P launches storm_main, R restarts from demo 0.
func _clear_finished_screen() -> void:
	for node in _end_screen_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_end_screen_nodes.clear()
	finished = false
	_configure_hud_finished(false)
	if _hall_audio and _hall_audio.player:
		_hall_audio.player.volume_db = -9.0
	if _lucid_music:
		_lucid_music.stop()


func _jump_to_demo_play(index: int) -> void:
	if is_headless or index < 0 or index >= DEMOS.size():
		return
	_clear_finished_screen()
	_hide_benchmark_punch()
	demo_index = index
	_active_hall = demo_index % NUM_HALLS
	_activate_hall(_active_hall)
	_unload_demo()
	_load_current_demo()
	demo_preview_ready = false
	demo_preview_pending = false
	hallway_root.visible = false
	void_zoom_rect.visible = false
	portal_rect.visible = false
	fullscreen_rect.texture = demo_viewport.get_texture()
	fullscreen_rect.visible = true
	fullscreen_rect.modulate.a = 1.0
	_update_hud_demo()
	_set_phase(Phase.PLAY)


func _jump_to_finished_screen() -> void:
	if is_headless:
		return
	_clear_finished_screen()
	_hide_benchmark_punch()
	_pause_demo()
	_unload_demo()
	_start_finished()


func _start_finished() -> void:
	finished = true
	phase = Phase.FINISHED
	phase_t = 0.0
	hallway_root.visible = false
	_unload_demo()
	_hide_benchmark_punch()
	fullscreen_layer.visible = true
	fullscreen_rect.visible = false
	portal_rect.visible = false
	void_zoom_rect.visible = false
	fullscreen_rect.modulate.a = 1.0
	fullscreen_rect.texture = null
	_end_screen_nodes.clear()
	var end_screen := FINISHED_SCREEN.new()
	end_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	fullscreen_layer.add_child(end_screen)
	_end_screen_nodes.append(end_screen)
	if hud_layer:
		hud_layer.visible = not is_headless and not movie_mode
	_configure_hud_finished(true)
	if _hall_audio and _hall_audio.player:
		_hall_audio.player.volume_db = -80.0
	if _lucid_music:
		if _lucid_music.has_method("start_playlist"):
			_lucid_music.start_playlist(LUCID_MUSIC.PLAYLIST_END, true)
		else:
			_lucid_music.start()


func _restart_showcase() -> void:
	_clear_finished_screen()
	if _hall_audio and _hall_audio.player:
		_hall_audio.player.volume_db = -9.0
	for node in _end_screen_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_end_screen_nodes.clear()
	finished = false
	demo_index = 0
	phase_t = 0.0
	_hall_visit_count = [0, 0, 0, 0]
	_gallery_walk_serial = 0
	_hall_gallery_base = [0, 2, 4, 6]
	fullscreen_rect.visible = false
	fullscreen_rect.texture = demo_viewport.get_texture()
	if hud_layer:
		hud_layer.visible = _hud_visible_for_walk()
	hallway_root.visible = true
	_start_demo_cycle()


func _update_finished(delta: float) -> void:
	phase_t += delta
	if is_headless and phase_t >= 1.0:
		get_tree().quit()
	elif movie_mode and phase_t >= MOVIE_FINISHED_HOLD:
		get_tree().quit()


func _configure_hud_finished(on: bool) -> void:
	if title_label:
		title_label.visible = not on
	if sub_label:
		sub_label.visible = not on
	if next_label:
		next_label.visible = not on
	if skip_label == null:
		return
	if on:
		skip_label.text = SKIP_LABEL_FINISHED_TEXT
		skip_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		skip_label.offset_left = -700.0
		skip_label.offset_top = -26.0
		skip_label.offset_right = -14.0
		skip_label.offset_bottom = -10.0
		skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	else:
		skip_label.text = SKIP_LABEL_TOUR_TEXT
		skip_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		skip_label.offset_left = SKIP_LABEL_TOUR_POS.x
		skip_label.offset_top = SKIP_LABEL_TOUR_POS.y
		skip_label.offset_right = SKIP_LABEL_TOUR_POS.x
		skip_label.offset_bottom = SKIP_LABEL_TOUR_POS.y
		skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _update_hud_demo() -> void:
	if demo_index >= DEMOS.size():
		return
	var d: Dictionary = DEMOS[demo_index]
	title_label.text = str(d.get("title", ""))
	sub_label.text = str(d.get("sub", ""))
	if next_label:
		next_label.text = "Next: %s" % str(d.get("title", ""))


func _update_hud_phase() -> void:
	if finished:
		return
	var portal_word := "door" if use_door else "window"
	match phase:
		Phase.WALK:
			match walk_mode:
				WalkMode.TO_CENTER:
					sub_label.text = "Returning to hub…"
				WalkMode.TURN_AT_HUB:
					sub_label.text = "Turning…"
				_:
					if demo_index < DEMOS.size() and next_label:
						next_label.text = "Next: %s" % str(DEMOS[demo_index].get("title", ""))
					if _is_on_final_approach():
						sub_label.text = "Walking the hall… (%s ahead)" % portal_word
					else:
						sub_label.text = "Walking the hall…"
		Phase.OPEN:
			sub_label.text = "Opening %s…" % portal_word
		Phase.ZOOM_IN:
			sub_label.text = "Stepping through…"
		Phase.PLAY:
			var d: Dictionary = DEMOS[demo_index]
			if _demo_waits_for_input():
				sub_label.text = "Press any key to continue…"
			else:
				sub_label.text = str(d.get("sub", ""))
		Phase.ZOOM_OUT:
			sub_label.text = "Pulling back…"
		Phase.CLOSE:
			sub_label.text = "Closing %s…" % portal_word


func _skip_to_next_demo() -> void:
	if finished:
		return
	match phase:
		Phase.WALK, Phase.OPEN:
			_set_phase(Phase.PLAY)
			hallway_root.visible = false
			fullscreen_layer.visible = true
			fullscreen_rect.visible = true
			fullscreen_rect.modulate.a = 1.0
			portal_rect.visible = false
		Phase.ZOOM_IN:
			_set_phase(Phase.PLAY)
			hallway_root.visible = false
			fullscreen_layer.visible = true
			fullscreen_rect.visible = true
			fullscreen_rect.modulate.a = 1.0
			portal_rect.visible = false
		Phase.PLAY:
			_set_phase(Phase.ZOOM_OUT)
		Phase.ZOOM_OUT, Phase.CLOSE:
			demo_index += 1
			if demo_index >= DEMOS.size():
				_start_finished()
			else:
				_begin_next_demo_after_hub()


func _launch_storm() -> void:
	if _lucid_music:
		_lucid_music.stop()
	if not ResourceLoader.exists(STORM_SCENE):
		push_error("Backrooms: missing %s" % STORM_SCENE)
		return
	get_tree().root.set_meta(STORM_PLAY_META, true)
	get_tree().root.set_meta(STORM_FROM_END_META, true)
	get_tree().change_scene_to_file(STORM_SCENE)


func _input(event: InputEvent) -> void:
	if movie_mode:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if not is_headless:
		if _key_match(event, KEY_1):
			get_viewport().set_input_as_handled()
			_jump_to_demo_play(DEMO_INDEX_ABOUT)
			return
		if _key_match(event, KEY_2):
			get_viewport().set_input_as_handled()
			_jump_to_finished_screen()
			return
	if finished and not is_headless:
		if _key_match(event, KEY_P):
			get_viewport().set_input_as_handled()
			_launch_storm()
			return
		if _key_match(event, KEY_R) or _key_match(event, KEY_ENTER):
			get_viewport().set_input_as_handled()
			_restart_showcase()
			return
		if _key_match(event, KEY_ESCAPE):
			get_viewport().set_input_as_handled()
			get_tree().quit()
			return
	if phase == Phase.PLAY and _demo_waits_for_input() and not is_headless:
		if _key_match(event, KEY_ESCAPE):
			get_viewport().set_input_as_handled()
			get_tree().quit()
			return
		get_viewport().set_input_as_handled()
		_advance_play_on_input()
		return
	if _key_match(event, KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		get_tree().quit()
		return
	if _key_match(event, KEY_SPACE) or _key_match(event, KEY_ENTER):
		if not is_headless and not finished:
			get_viewport().set_input_as_handled()
			_skip_to_next_demo()
