@tool
## AGCK Builder Backend — code generation engine
##
## Converts AGCK design data (levels, actors, sounds, settings) into
## real, editable VG project files:
##   - .vg   (VB6-syntax code — editable in VG Code Editor)
##   - .tscn (Godot scenes    — editable in VG 2D Editor)
##   - .png  (placeholder sprites — editable in VG Sprite Editor)
##
## Generated files are fully standalone — AGCK is the on-ramp,
## VG's native editors are the freeway.
extends RefCounted

# ─── Constants ───────────────────────────────────────────────
const CELL_PX   = 32   # Tile size in pixels
const GRID_W    = 20
const GRID_H    = 12

const BLOCK_NAMES = ["Empty", "Barrier", "Ladder", "Deadly", "Background", "Teleport", "Switch"]
const BLOCK_COLORS_HEX = [
	"1e1e24",  # Empty
	"808c99",  # Barrier
	"4dbf4d",  # Ladder
	"d93333",  # Deadly
	"406699",  # Background
	"a64dd9",  # Teleport
	"e6cc33",  # Switch
]

const ACTOR_TYPE_BASE_CLASS = {
	"Player":   "CharacterBody2D",
	"Drone":    "CharacterBody2D",
	"Missile":  "RigidBody2D",
	"Sentry":   "CharacterBody2D",
	"Computer": "StaticBody2D",
	"Zombie":   "CharacterBody2D",
	"Boss":     "CharacterBody2D",
	"Bat":      "CharacterBody2D",
	"NPC":      "StaticBody2D",
	"Tank":     "CharacterBody2D",
	"Fireball": "RigidBody2D",
	"Runner":   "CharacterBody2D",
	# Top-down view variants — same physics roles as their counterparts.
	"TopHero":   "CharacterBody2D",
	"TopGoblin": "CharacterBody2D",
	"TopChest":  "StaticBody2D",
}

# ─── Sound synthesis constants (mirror agck_sound_editor.gd) ─
const SAMPLE_RATE   = 22050
const NOTE_BASE_HZ  = 65.41   # C2
const NUM_NOTES     = 32
const MAX_NOTE_VAL  = 48
const ENVELOPE_MS   = 5

# ─── Log Callback ────────────────────────────────────────────
var _log_fn: Callable = Callable()

# Reference to tile library for real tile/actor sprites (set by agck_plugin)
var tile_library = null

func _log(msg: String, color: String = "#ccc") -> void:
	if _log_fn.is_valid():
		_log_fn.call("[color=" + color + "]" + msg + "[/color]")
	print("AGCK Build: ", msg)


# ═══════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════

## Run the full build pipeline.
## game_data: Dictionary with keys "settings", "actors", "levels", "sounds", "build"
## log_fn: Callable(bbcode_string) for progress output
## Returns: Dictionary {"ok": bool, "output_dir": String, "files": Array[String]}
func build(game_data: Dictionary, log_fn: Callable = Callable()) -> Dictionary:
	_log_fn = log_fn
	var result = {"ok": false, "output_dir": "", "files": []}

	# ── Validate
	var settings: Dictionary = game_data.get("settings", {})
	var actors: Array        = game_data.get("actors", [])
	var levels: Array        = game_data.get("levels", [])
	var sounds: Array        = game_data.get("sounds", [])
	var build_opts: Dictionary = game_data.get("build", {})

	var game_title: String = settings.get("game_title", "AGCKGame")
	# Sanitize to valid folder name
	var safe_name: String = game_title.replace(" ", "_").replace("/", "_").replace("\\", "_")
	if safe_name.is_empty():
		safe_name = "AGCKGame"

	var output_dir: String = build_opts.get("output_path", "res://build/")
	if not output_dir.ends_with("/"):
		output_dir += "/"
	output_dir += safe_name + "/"
	result["output_dir"] = output_dir

	_log("═══════════════════════════════════════════", "#ffcc55")
	_log("  AGCK BUILD: " + game_title, "#ffcc55")
	_log("  Output: " + output_dir, "#aaa")
	_log("═══════════════════════════════════════════", "#ffcc55")

	# ── Ensure output directory
	if not DirAccess.dir_exists_absolute(output_dir):
		DirAccess.make_dir_recursive_absolute(output_dir)
	var sprites_dir = output_dir + "sprites/"
	if not DirAccess.dir_exists_absolute(sprites_dir):
		DirAccess.make_dir_recursive_absolute(sprites_dir)

	# ── Step 1: Generate block tileset sprite
	_log("▸ Generating block tileset…")
	var tileset_path = sprites_dir + "blocks_tileset.png"
	_generate_block_tileset(tileset_path)
	result["files"].append(tileset_path)

	# ── Step 2: Generate actor placeholder sprites
	_log("▸ Generating actor sprites…")
	for i in range(actors.size()):
		var actor = actors[i]
		var aname: String = _safe_id(actor.get("name", "Actor" + str(i)))
		var spr_path = sprites_dir + "spr_" + aname.to_lower() + ".png"
		_generate_actor_sprite(spr_path, actor, i)
		result["files"].append(spr_path)

	# ── Step 2b: Generate sound WAV files
	_log("▸ Generating sound effects…")
	var sounds_dir = output_dir + "sounds/"
	if not DirAccess.dir_exists_absolute(sounds_dir):
		DirAccess.make_dir_recursive_absolute(sounds_dir)
	var sound_count := 0
	for si in range(sounds.size()):
		var snd = sounds[si]
		var custom_wav: String = snd.get("custom_wav", "")
		var has_content: bool = not custom_wav.is_empty()
		if not has_content:
			for n in snd.get("voice1_notes", []):
				if n > 0:
					has_content = true
					break
		if not has_content:
			for n in snd.get("voice2_notes", []):
				if n > 0:
					has_content = true
					break
		if not has_content:
			continue
		var snd_name := _safe_id(snd.get("name", "Sound_" + str(si + 1)))
		if not custom_wav.is_empty() and FileAccess.file_exists(custom_wav):
			# Copy user's WAV file into the build
			var ext := custom_wav.get_extension().to_lower()
			if ext.is_empty():
				ext = "wav"
			var dest_path: String = sounds_dir + "sfx_" + snd_name.to_lower() + "." + ext
			var src_bytes = FileAccess.get_file_as_bytes(custom_wav)
			if src_bytes.size() > 0:
				var out = FileAccess.open(dest_path, FileAccess.WRITE)
				if out:
					out.store_buffer(src_bytes)
					out.close()
					result["files"].append(dest_path)
					_log("  Copied WAV: " + custom_wav.get_file(), "#8cf")
			else:
				_log("  ⚠ WAV file empty: " + custom_wav, "#f88")
		else:
			var wav_path: String = sounds_dir + "sfx_" + snd_name.to_lower() + ".wav"
			_generate_sound_wav(wav_path, snd)
			result["files"].append(wav_path)
		sound_count += 1
	_log("  " + str(sound_count) + " sound(s) generated", "#8f8")

	# ── Step 3: Generate actor .tscn + .vg files
	_log("▸ Generating actor scenes & code…")
	for i in range(actors.size()):
		var actor = actors[i]
		var aname: String = _safe_id(actor.get("name", "Actor" + str(i)))
		var actor_dir = output_dir + "actors/"
		if not DirAccess.dir_exists_absolute(actor_dir):
			DirAccess.make_dir_recursive_absolute(actor_dir)

		var tscn_path = actor_dir + "Actor_" + aname + ".tscn"
		var vg_path   = actor_dir + "Actor_" + aname + ".vg"
		var spr_rel   = "../sprites/spr_" + aname.to_lower() + ".png"

		_generate_actor_tscn(tscn_path, aname, actor, spr_rel, i)
		_generate_actor_vg(vg_path, aname, actor, settings)
		result["files"].append(tscn_path)
		result["files"].append(vg_path)
		_log("  ✓ Actor_" + aname + " (.tscn + .vg)", "#8f8")

	# ── Step 4: Generate level .tscn files
	_log("▸ Generating level scenes…")
	var level_count = 0
	var level_indices: Array[int] = []   # track which level indices have content
	for i in range(levels.size()):
		var lvl = levels[i]
		if _level_is_empty(lvl):
			continue
		level_count += 1
		level_indices.append(i)
		var lvl_name = "Level_" + str(i + 1).pad_zeros(2)
		var lvl_dir = output_dir + "levels/"
		if not DirAccess.dir_exists_absolute(lvl_dir):
			DirAccess.make_dir_recursive_absolute(lvl_dir)

		var tscn_path = lvl_dir + lvl_name + ".tscn"
		var vg_path   = lvl_dir + lvl_name + ".vg"
		_generate_level_tscn(tscn_path, lvl, actors, i, level_indices, output_dir)
		_generate_level_vg(vg_path, lvl_name, lvl, actors, level_indices, output_dir, settings)
		result["files"].append(tscn_path)
		result["files"].append(vg_path)
		_log("  ✓ " + lvl_name + " (.tscn + .vg)", "#8f8")

	_log("  " + str(level_count) + " level(s) generated", "#aaa")

	# ── Step 5: Generate Main.tscn + Main.vg (game controller)
	_log("▸ Generating Main scene & controller…")
	var shader_layers_for_main: Array = game_data.get("shaders", [])
	_generate_main_tscn(output_dir + "Main.tscn", settings, level_count, level_indices, output_dir, sounds, shader_layers_for_main)
	_generate_main_vg(output_dir + "Main.vg", settings, actors, level_count, level_indices, output_dir, sounds, levels)
	result["files"].append(output_dir + "Main.tscn")
	result["files"].append(output_dir + "Main.vg")

	# ── Step 6: Generate shader effect files
	var shader_layers: Array = game_data.get("shaders", [])
	var active_shaders := 0
	if shader_layers.size() > 0:
		_log("▸ Generating shader effects…")
		var shaders_dir = output_dir + "shaders/"
		if not DirAccess.dir_exists_absolute(shaders_dir):
			DirAccess.make_dir_recursive_absolute(shaders_dir)
		for si in range(shader_layers.size()):
			var shader_data = shader_layers[si]
			if not shader_data.get("enabled", true):
				continue
			var shader_name = _safe_id(shader_data.get("shader_name", "Effect_" + str(si)))
			var shader_path = shaders_dir + "fx_" + shader_name.to_lower() + ".gdshader"
			_generate_shader_file(shader_path, shader_data)
			result["files"].append(shader_path)
			active_shaders += 1
		_log("  " + str(active_shaders) + " shader effect(s) generated", "#8f8")

	# ── Step 7: (project.godot updated by plugin after build)

	# ── Step 7: Generate project.agck manifest
	_log("▸ Writing project manifest…")
	_generate_manifest(output_dir + "project.agck", game_data)
	result["files"].append(output_dir + "project.agck")

	# ── Done
	_log("═══════════════════════════════════════════", "#44cc55")
	_log("  ✓ BUILD COMPLETE — " + str(result["files"].size()) + " files generated", "#44cc55")
	_log("  Output: " + output_dir, "#aaa")
	_log("  Open any .vg file in VG Code Editor to customize", "#aaa")
	_log("  Open any .tscn file in VG 2D Editor to arrange", "#aaa")
	_log("  Open any .png in VG Sprite Editor to draw art", "#aaa")
	_log("═══════════════════════════════════════════", "#44cc55")

	result["ok"] = true
	return result


# ═══════════════════════════════════════════════════════════════
# SPRITE GENERATION
# ═══════════════════════════════════════════════════════════════

func _generate_block_tileset(path: String) -> void:
	# If tile_library is available, export each tile type as individual PNGs
	# plus a composite tileset strip for TileMap usage
	if tile_library:
		var base_dir = path.get_base_dir() + "/"
		var total_tiles = 0
		for bt in range(1, BLOCK_NAMES.size()):  # skip Empty
			var count = tile_library.get_tile_count(bt)
			for ti in range(count):
				var tile_img = tile_library.get_tile_image(bt, ti)
				if tile_img:
					# Scale up to CELL_PX size for game use
					var scaled = tile_img.duplicate()
					scaled.resize(CELL_PX, CELL_PX, Image.INTERPOLATE_NEAREST)
					var tile_name = tile_library.get_tile_name(bt, ti)
					var safe = _safe_id(tile_name)
					var tile_path = base_dir + "tile_" + BLOCK_NAMES[bt].to_lower() + "_" + safe + ".png"
					scaled.save_png(tile_path)
					total_tiles += 1

		# Also generate a basic 7-color tileset strip as fallback
		var img = Image.create(CELL_PX * BLOCK_COLORS_HEX.size(), CELL_PX, false, Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		for i in range(BLOCK_COLORS_HEX.size()):
			var color = Color(BLOCK_COLORS_HEX[i])
			var ox = i * CELL_PX
			for y in range(CELL_PX):
				for x in range(CELL_PX):
					img.set_pixel(ox + x, y, color)
			var border = color.darkened(0.3)
			for p in range(CELL_PX):
				img.set_pixel(ox + p, 0, border)
				img.set_pixel(ox + p, CELL_PX - 1, border)
				img.set_pixel(ox, p, border)
				img.set_pixel(ox + CELL_PX - 1, p, border)
		img.save_png(path)
		_log("  Exported " + str(total_tiles) + " tile sprites + fallback tileset", "#8f8")
	else:
		# Fallback: plain colored tileset strip
		var img = Image.create(CELL_PX * BLOCK_COLORS_HEX.size(), CELL_PX, false, Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		for i in range(BLOCK_COLORS_HEX.size()):
			var color = Color(BLOCK_COLORS_HEX[i])
			var ox = i * CELL_PX
			for y in range(CELL_PX):
				for x in range(CELL_PX):
					img.set_pixel(ox + x, y, color)
			var border = color.darkened(0.3)
			for p in range(CELL_PX):
				img.set_pixel(ox + p, 0, border)
				img.set_pixel(ox + p, CELL_PX - 1, border)
				img.set_pixel(ox, p, border)
				img.set_pixel(ox + CELL_PX - 1, p, border)
		img.save_png(path)
		_log("  blocks_tileset.png (" + str(BLOCK_COLORS_HEX.size()) + " tiles)", "#8f8")


func _generate_actor_sprite(path: String, actor: Dictionary, actor_id: int = -1) -> void:
	# If tile_library has real sprites for this actor, use them (scaled up)
	if tile_library and actor_id >= 0:
		var aname_for_lib: String = actor.get("name", "Actor" + str(actor_id))
		var atype_for_lib: String = actor.get("type", "Drone")
		tile_library.ensure_actor_sprite(actor_id, aname_for_lib, atype_for_lib)
		var anims: Dictionary = tile_library.get_actor_anims(actor_id)
		if anims.size() > 1:
			# Multi-animation: output one PNG per animation
			var base_path: String = path.trim_suffix(".png")
			for anim_name in anims:
				var frames: Array = anims[anim_name]
				var safe_anim: String = anim_name.to_lower().replace(" ", "_")
				var anim_path: String = base_path + "_" + safe_anim + ".png"
				if frames.size() > 1:
					# Horizontal sprite sheet for this animation
					var sheet = Image.create(CELL_PX * frames.size(), CELL_PX, false, Image.FORMAT_RGBA8)
					sheet.fill(Color.TRANSPARENT)
					for fi in range(frames.size()):
						var scaled = frames[fi].duplicate()
						scaled.resize(CELL_PX, CELL_PX, Image.INTERPOLATE_NEAREST)
						sheet.blit_rect(scaled, Rect2i(0, 0, CELL_PX, CELL_PX), Vector2i(fi * CELL_PX, 0))
					sheet.save_png(anim_path)
				elif frames.size() == 1:
					var scaled = frames[0].duplicate()
					scaled.resize(CELL_PX, CELL_PX, Image.INTERPOLATE_NEAREST)
					scaled.save_png(anim_path)
			return
		elif anims.size() == 1:
			# Single animation — use original path
			var first_key: String = anims.keys()[0]
			var frames: Array = anims[first_key]
			if frames.size() > 1:
				# Multi-frame: output horizontal sprite sheet
				var sheet = Image.create(CELL_PX * frames.size(), CELL_PX, false, Image.FORMAT_RGBA8)
				sheet.fill(Color.TRANSPARENT)
				for fi in range(frames.size()):
					var scaled = frames[fi].duplicate()
					scaled.resize(CELL_PX, CELL_PX, Image.INTERPOLATE_NEAREST)
					sheet.blit_rect(scaled, Rect2i(0, 0, CELL_PX, CELL_PX), Vector2i(fi * CELL_PX, 0))
				sheet.save_png(path)
				return
			elif frames.size() == 1:
				var scaled = frames[0].duplicate()
				scaled.resize(CELL_PX, CELL_PX, Image.INTERPOLATE_NEAREST)
				scaled.save_png(path)
				return

	# Fallback: 32x32 placeholder sprite -- colored silhouette based on actor type
	var type_colors = {
		"Player":   Color(0.30, 0.75, 0.95),
		"Drone":    Color(0.85, 0.30, 0.30),
		"Missile":  Color(0.95, 0.60, 0.15),
		"Sentry":   Color(0.70, 0.40, 0.90),
		"Computer": Color(0.40, 0.80, 0.40),
		"Zombie":   Color(0.55, 0.75, 0.30),
		"Boss":     Color(0.90, 0.20, 0.50),
		"Bat":      Color(0.50, 0.35, 0.70),
		"NPC":      Color(0.30, 0.70, 0.85),
		"Tank":     Color(0.60, 0.60, 0.45),
		"Fireball": Color(0.95, 0.45, 0.10),
	}
	var atype: String = actor.get("type", "Drone")
	var base_color: Color = type_colors.get(atype, Color(0.5, 0.5, 0.5))

	var size = CELL_PX
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)

	# Simple character silhouette: body rectangle + head circle
	var body_top = size / 3
	var body_bot = size - 4
	var body_left = size / 4
	var body_right = size - size / 4

	# Body
	for y in range(body_top, body_bot):
		for x in range(body_left, body_right):
			img.set_pixel(x, y, base_color)

	# Head (circle at top center)
	var cx = size / 2
	var cy = size / 4
	var r = size / 6
	for y in range(maxi(0, cy - r), mini(size, cy + r)):
		for x in range(maxi(0, cx - r), mini(size, cx + r)):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
				img.set_pixel(x, y, base_color.lightened(0.2))

	# Eyes for non-Computer types
	if atype != "Computer":
		var eye_color = Color.WHITE
		var ey = cy
		img.set_pixel(cx - 2, ey, eye_color)
		img.set_pixel(cx + 1, ey, eye_color)

	# Border outline
	var outline = base_color.darkened(0.4)
	for y in range(size):
		for x in range(size):
			if img.get_pixel(x, y).a > 0.5:
				# Check neighbors
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var nx = x + dx
						var ny = y + dy
						if nx >= 0 and nx < size and ny >= 0 and ny < size:
							if img.get_pixel(nx, ny).a < 0.1:
								img.set_pixel(nx, ny, outline)

	img.save_png(path)


# ═══════════════════════════════════════════════════════════════
# ACTOR SCENE + CODE GENERATION
# ═══════════════════════════════════════════════════════════════

func _generate_actor_tscn(path: String, aname: String, actor: Dictionary, sprite_rel_path: String, actor_id: int = -1) -> void:
	var atype = actor.get("type", "Drone")
	var base_class = ACTOR_TYPE_BASE_CLASS.get(atype, "CharacterBody2D")
	var vg_script_path = path.replace(".tscn", ".vg")

	# Get animation data
	var anim_data: Array = actor.get("anim_data", [{"name": "Idle", "speed": 8, "loop": true}])
	# Backward compat: legacy single-animation format
	if anim_data.size() == 0:
		var old_speed: float = actor.get("anim_speed", 8)
		anim_data = [{"name": "Idle", "speed": old_speed, "loop": true}]

	# Get actual frame counts from tile library
	var anim_frames_map: Dictionary = {}  # { anim_name: frame_count }
	var total_frames: int = 0
	var multi_anim: bool = false
	if tile_library and actor_id >= 0:
		var anims_dict: Dictionary = tile_library.get_actor_anims(actor_id)
		for ad in anim_data:
			var an: String = ad.get("name", "Idle")
			if anims_dict.has(an):
				anim_frames_map[an] = anims_dict[an].size()
				total_frames += anims_dict[an].size()
			else:
				anim_frames_map[an] = 1
				total_frames += 1
		multi_anim = anims_dict.size() > 1
	else:
		for ad in anim_data:
			anim_frames_map[ad.get("name", "Idle")] = 1
			total_frames += 1

	var use_animated: bool = total_frames > 1 or multi_anim
	var safe_id := aname.replace(" ", "_").replace("-", "_").replace(".", "_")

	# Per-sprite shader FX
	var actor_sfx: String = actor.get("shader_fx", "(None)")
	var actor_sfx_code: String = SPRITE_SHADER_CODES.get(actor_sfx, "")
	var has_actor_shader: bool = actor_sfx != "(None)" and not actor_sfx_code.is_empty()
	var sfx_extra_steps: int = 2 if has_actor_shader else 0

	var tscn = ""

	if use_animated:
		# AnimatedSprite2D with SpriteFrames sub-resource
		# For multi-animation: each animation gets its own ext_resource (one PNG per anim)
		var ext_id := 2  # 1 = script

		var ext_map: Dictionary = {}  # { anim_name: ext_id }

		if multi_anim:
			var load_steps = 4 + total_frames + anim_data.size() + sfx_extra_steps
			tscn += '[gd_scene load_steps=' + str(load_steps) + ' format=3]\n\n'
			tscn += '[ext_resource type="Script" path="' + vg_script_path + '" id="1"]\n'
			for ad in anim_data:
				var an: String = ad.get("name", "Idle")
				var safe_anim := an.to_lower().replace(" ", "_")
				var anim_sprite_path := sprite_rel_path.trim_suffix(".png") + "_" + safe_anim + ".png"
				tscn += '[ext_resource type="Texture2D" path="' + anim_sprite_path + '" id="' + str(ext_id) + '"]\n'
				ext_map[an] = ext_id
				ext_id += 1
			tscn += '\n'
		else:
			var fc: int = anim_frames_map.get(anim_data[0].get("name", "Idle"), 1)
			var load_steps = 4 + fc + sfx_extra_steps
			tscn += '[gd_scene load_steps=' + str(load_steps) + ' format=3]\n\n'
			tscn += '[ext_resource type="Script" path="' + vg_script_path + '" id="1"]\n'
			tscn += '[ext_resource type="Texture2D" path="' + sprite_rel_path + '" id="2"]\n\n'
			ext_map[anim_data[0].get("name", "Idle")] = 2

		# AtlasTexture sub-resources for each frame of each animation
		var atlas_idx := 0
		var atlas_map: Dictionary = {}  # { anim_name: [atlas_id, ...] }
		for ad in anim_data:
			var an: String = ad.get("name", "Idle")
			var fc: int = anim_frames_map.get(an, 1)
			var eid: int = ext_map.get(an, 2)
			var ids: Array = []
			for fi in range(fc):
				tscn += '[sub_resource type="AtlasTexture" id="atlas_' + str(atlas_idx) + '"]\n'
				tscn += 'atlas = ExtResource("' + str(eid) + '")\n'
				tscn += 'region = Rect2(' + str(fi * CELL_PX) + ', 0, ' + str(CELL_PX) + ', ' + str(CELL_PX) + ')\n\n'
				ids.append(atlas_idx)
				atlas_idx += 1
			atlas_map[an] = ids

		# SpriteFrames resource with all named animations
		tscn += '[sub_resource type="SpriteFrames" id="sprite_frames"]\n'
		tscn += 'animations = ['
		var anim_idx := 0
		for ad in anim_data:
			var an: String = ad.get("name", "Idle")
			var aspeed: float = ad.get("speed", 8)
			var aloop: bool = ad.get("loop", true)
			var ids: Array = atlas_map.get(an, [])
			if anim_idx > 0:
				tscn += ', '
			tscn += '{\n'
			tscn += '"frames": [\n'
			for fi in range(ids.size()):
				tscn += '{\n'
				tscn += '"duration": 1.0,\n'
				tscn += '"texture": SubResource("atlas_' + str(ids[fi]) + '")\n'
				tscn += '}'
				if fi < ids.size() - 1:
					tscn += ','
				tscn += '\n'
			tscn += '],\n'
			tscn += '"loop": ' + str(aloop).to_lower() + ',\n'
			tscn += '"name": &"' + an + '",\n'
			tscn += '"speed": ' + _fstr(aspeed) + '\n'
			tscn += '}'
			anim_idx += 1
		tscn += ']\n\n'

		# Collision shapes. The physics body shape is slightly smaller than
		# a full cell so the actor doesn't catch on tile seams. The damage
		# Hitbox now matches the physics body size — testers reported the
		# previous CELL_PX-2 hitbox triggered phantom hits, but CELL_PX-10
		# was too forgiving (player passed through spikes). CELL_PX-4 = same
		# rect as the body, which is fair and predictable.
		tscn += '[sub_resource type="RectangleShape2D" id="shape_1"]\n'
		tscn += 'size = Vector2(' + str(CELL_PX - 4) + ', ' + str(CELL_PX - 4) + ')\n\n'
		tscn += '[sub_resource type="RectangleShape2D" id="hitbox_shape"]\n'
		tscn += 'size = Vector2(' + str(CELL_PX - 4) + ', ' + str(CELL_PX - 4) + ')\n\n'

		# Per-sprite shader FX sub-resources (if set)
		if has_actor_shader:
			tscn += '[sub_resource type="Shader" id="sprite_shader"]\n'
			tscn += 'code = "' + actor_sfx_code.replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t") + '"\n\n'
			tscn += '[sub_resource type="ShaderMaterial" id="sprite_shader_mat"]\n'
			tscn += 'shader = SubResource("sprite_shader")\n'
			var sfx_params: Dictionary = actor.get("shader_params", {})
			for pkey in sfx_params:
				var pval = sfx_params[pkey]
				var pstr: String
				if pval is float or pval is int:
					var fv: float = float(pval)
					if fv == int(fv):
						pstr = str(int(fv)) + ".0"
					else:
						pstr = str(fv)
				else:
					pstr = str(pval)
				tscn += 'shader_parameter/' + pkey + ' = ' + pstr + '\n'
			tscn += '\n'

		# Root node
		tscn += '[node name="Actor_' + aname + '" type="' + base_class + '"]\n'
		tscn += 'script = ExtResource("1")\n'
		if atype == "Player":
			tscn += 'metadata/_groups = ["player"]\n'
		elif atype in ["Drone", "Sentry", "Zombie", "Boss", "Bat", "Tank"]:
			tscn += 'metadata/_groups = ["enemies"]\n'
		elif atype in ["NPC"]:
			tscn += 'metadata/_groups = ["npc"]\n'
		tscn += '\n'

		# AnimatedSprite2D child — autoplay first animation
		var first_anim_name: String = anim_data[0].get("name", "Idle")
		tscn += '[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]\n'
		if has_actor_shader:
			tscn += 'material = SubResource("sprite_shader_mat")\n'
		tscn += 'sprite_frames = SubResource("sprite_frames")\n'
		tscn += 'autoplay = "' + first_anim_name + '"\n\n'

	else:
		# Single frame — use simple Sprite2D
		var single_load = 4 + sfx_extra_steps
		tscn += '[gd_scene load_steps=' + str(single_load) + ' format=3]\n\n'

		# External resources
		tscn += '[ext_resource type="Script" path="' + vg_script_path + '" id="1"]\n'
		tscn += '[ext_resource type="Texture2D" path="' + sprite_rel_path + '" id="2"]\n\n'

		# Sub-resources: collision shape + hitbox shape. Hitbox = body size
		# (see note in animated branch above for tuning history).
		tscn += '[sub_resource type="RectangleShape2D" id="shape_1"]\n'
		tscn += 'size = Vector2(' + str(CELL_PX - 4) + ', ' + str(CELL_PX - 4) + ')\n\n'
		tscn += '[sub_resource type="RectangleShape2D" id="hitbox_shape"]\n'
		tscn += 'size = Vector2(' + str(CELL_PX - 4) + ', ' + str(CELL_PX - 4) + ')\n\n'

		# Per-sprite shader FX sub-resources (if set)
		if has_actor_shader:
			tscn += '[sub_resource type="Shader" id="sprite_shader"]\n'
			tscn += 'code = "' + actor_sfx_code.replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t") + '"\n\n'
			tscn += '[sub_resource type="ShaderMaterial" id="sprite_shader_mat"]\n'
			tscn += 'shader = SubResource("sprite_shader")\n'
			var sfx_params: Dictionary = actor.get("shader_params", {})
			for pkey in sfx_params:
				var pval = sfx_params[pkey]
				var pstr: String
				if pval is float or pval is int:
					var fv: float = float(pval)
					if fv == int(fv):
						pstr = str(int(fv)) + ".0"
					else:
						pstr = str(fv)
				else:
					pstr = str(pval)
				tscn += 'shader_parameter/' + pkey + ' = ' + pstr + '\n'
			tscn += '\n'

		# Root node
		tscn += '[node name="Actor_' + aname + '" type="' + base_class + '"]\n'
		tscn += 'script = ExtResource("1")\n'
		if atype == "Player":
			tscn += 'metadata/_groups = ["player"]\n'
		elif atype in ["Drone", "Sentry", "Zombie", "Boss", "Bat", "Tank"]:
			tscn += 'metadata/_groups = ["enemies"]\n'
		elif atype in ["NPC"]:
			tscn += 'metadata/_groups = ["npc"]\n'
		tscn += '\n'

		# Sprite2D child
		tscn += '[node name="Sprite2D" type="Sprite2D" parent="."]\n'
		if has_actor_shader:
			tscn += 'material = SubResource("sprite_shader_mat")\n'
		tscn += 'texture = ExtResource("2")\n\n'

	# CollisionShape2D child (physics body shape)
	tscn += '[node name="CollisionShape2D" type="CollisionShape2D" parent="."]\n'
	tscn += 'shape = SubResource("shape_1")\n\n'

	# Area2D hitbox for damage/interaction detection
	tscn += '[node name="Hitbox" type="Area2D" parent="."]\n'
	# Set collision layers: Player on layer 1, Enemies on layer 2
	if atype == "Player":
		tscn += 'collision_layer = 1\n'
		tscn += 'collision_mask = 2\n'
	elif atype in ["Drone", "Sentry", "Missile", "Zombie", "Boss", "Bat", "Tank", "Fireball"]:
		tscn += 'collision_layer = 2\n'
		tscn += 'collision_mask = 1\n'
	elif atype in ["Computer", "NPC"]:
		tscn += 'collision_layer = 4\n'
		tscn += 'collision_mask = 1\n'
	tscn += '\n'

	tscn += '[node name="HitboxShape" type="CollisionShape2D" parent="Hitbox"]\n'
	tscn += 'shape = SubResource("hitbox_shape")\n\n'

	# Connect Area2D signals
	tscn += '[connection signal="body_entered" from="Hitbox" to="." method="Hitbox_BodyEntered"]\n'
	tscn += '[connection signal="area_entered" from="Hitbox" to="." method="Hitbox_AreaEntered"]\n'

	_write_file(path, tscn)


func _generate_actor_vg(path: String, aname: String, actor: Dictionary, settings: Dictionary) -> void:
	# Preserve any user code from the previous build
	var preserved := _extract_user_code(path)

	var atype: String = actor.get("type", "Drone")
	var speed: float  = actor.get("max_speed", 200.0)
	var gravity: float = settings.get("gravity", 980)
	var grav_scale: float = actor.get("gravity_scale", 1.0)
	var max_hp: int   = actor.get("max_hp", 100)
	var damage: int   = actor.get("damage", 10)
	var score_val: int = actor.get("score_value", 100)
	var collision: String = actor.get("collision_mode", "Bounce")
	var death: String = actor.get("death_mode", "Respawn")
	var rebirth: float = actor.get("rebirth", 3.0)

	# Sound event mappings
	var actor_sounds: Dictionary = {
		"jump": actor.get("jump_sound", "(None)"),
		"hit": actor.get("hit_sound", "(None)"),
		"death": actor.get("death_sound", "(None)"),
		"shoot": actor.get("shoot_sound", "(None)"),
		"pickup": actor.get("pickup_sound", "(None)"),
		"stomp": actor.get("stomp_sound", "(None)"),
	}

	var code = ""
	code += "' Actor_" + aname + ".vg — " + atype + "\n"
	code += "' Generated by AGCK — fully editable in VG Code Editor!\n"
	code += "' Open in 2D Editor to adjust collisions & position.\n"
	code += "' Open sprite in Sprite Editor to draw your character.\n"
	code += "Option Explicit\n\n"

	# Common variables
	code += "' ─── Properties ───\n"
	code += "Dim Speed As Single\n"
	code += "Dim vx As Single\n"
	code += "Dim vy As Single\n"
	code += "Dim MaxHP As Integer\n"
	code += "Dim CurrentHP As Integer\n"
	code += "Dim Damage As Integer\n"
	code += "Dim ScoreValue As Integer\n"
	code += "Dim Gravity As Single\n"
	code += "Dim IsInvincible As Boolean\n"
	code += "Dim InvincibleTimer As Single\n"
	code += "Dim CurrentAnim As String\n"

	match atype:
		"Player", "TopHero":
			# TopHero shares Player physics — only the rendered sprite differs.
			code += "Dim JumpForce As Single\n"
			code += "Dim IsJumping As Boolean\n"
			code += "Dim on_ladder As Boolean\n\n"
			code += _gen_ready_sub(aname, speed, gravity * grav_scale, max_hp, damage, score_val, "player")
			code += _gen_player_physics(speed, gravity * grav_scale, collision, actor_sounds)
			code += _gen_collision_handler(atype, actor_sounds)
			code += _gen_damage_sub(death, rebirth, true, actor_sounds)

		"Runner":
			# Geometry-Dash-style auto-runner: constant horizontal velocity, jump-only input.
			code += "Dim JumpForce As Single\n"
			code += "Dim IsJumping As Boolean\n"
			code += "Dim AirRotation As Single\n\n"
			var jf: float = actor.get("jump_force", 520.0)
			var runner_init = "    JumpForce = " + _fstr(jf) + "\n"
			runner_init += "    IsJumping = False\n"
			runner_init += "    AirRotation = 0.0\n"
			code += _gen_ready_sub(aname, speed, gravity * grav_scale, max_hp, damage, score_val, "player", runner_init)
			code += _gen_runner_physics(speed, gravity * grav_scale, jf, actor_sounds)
			code += _gen_collision_handler(atype, actor_sounds)
			code += _gen_damage_sub(death, rebirth, true, actor_sounds)

		"Drone", "TopGoblin":
			var ai: String = actor.get("ai_behavior", "Patrol")
			var patrol_speed: float = actor.get("ai_patrol_speed", 80)
			code += "Dim Direction As Single\n"
			code += "Dim PatrolSpeed As Single\n"
			code += "' ─── Path Following (set via level editor) ───\n"
			code += "Dim PathX(20) As Single\n"
			code += "Dim PathY(20) As Single\n"
			code += "Dim PathCount As Integer\n"
			code += "Dim PathIndex As Integer\n"
			code += "Dim HasPath As Boolean\n\n"
			var drone_init = "    Direction = 1.0\n"
			drone_init += "    PatrolSpeed = " + _fstr(patrol_speed) + "\n"
			drone_init += "    PathCount = 0\n"
			drone_init += "    PathIndex = 0\n"
			drone_init += "    HasPath = False\n"
			code += _gen_ready_sub(aname, speed, gravity * grav_scale, max_hp, damage, score_val, "enemies", drone_init)
			code += _gen_add_path_point_sub()
			code += _gen_drone_physics(ai, patrol_speed, gravity * grav_scale)
			code += _gen_collision_handler(atype, actor_sounds)
			code += _gen_damage_sub(death, rebirth, false, actor_sounds)

		"Missile":
			code += "Dim MoveDirection As Vector2\n"
			code += "Dim LifeTime As Single\n\n"
			code += _gen_ready_sub(aname, speed, 0, max_hp, damage, score_val, "")
			code += _gen_missile_physics(speed)
			code += _gen_collision_handler(atype, actor_sounds)

		"Sentry":
			var patrol_speed: float = actor.get("ai_patrol_speed", 80)
			code += "Dim Direction As Single\n"
			code += "Dim PatrolSpeed As Single\n"
			code += "' ─── Path Following (set via level editor) ───\n"
			code += "Dim PathX(20) As Single\n"
			code += "Dim PathY(20) As Single\n"
			code += "Dim PathCount As Integer\n"
			code += "Dim PathIndex As Integer\n"
			code += "Dim HasPath As Boolean\n"
			var auto_shoot: bool = actor.get("auto_shoot", false)
			var fire_rate: float = actor.get("auto_shoot_interval", 1.0)
			if auto_shoot:
				code += "Dim ShootTimer As Single\n"
				code += "Dim FireRate As Single\n"
			code += "\n"
			var sentry_init = "    Direction = 1.0\n"
			sentry_init += "    PatrolSpeed = " + _fstr(patrol_speed) + "\n"
			sentry_init += "    PathCount = 0\n"
			sentry_init += "    PathIndex = 0\n"
			sentry_init += "    HasPath = False\n"
			if auto_shoot:
				sentry_init += "    FireRate = " + _fstr(fire_rate) + "\n"
				sentry_init += "    ShootTimer = 0.0\n"
			code += _gen_ready_sub(aname, speed, gravity * grav_scale, max_hp, damage, score_val, "enemies", sentry_init)
			code += _gen_add_path_point_sub()
			code += _gen_sentry_physics(patrol_speed, gravity * grav_scale, auto_shoot, fire_rate, actor_sounds)
			code += _gen_collision_handler(atype, actor_sounds)
			code += _gen_damage_sub(death, rebirth, false, actor_sounds)

		"Computer", "TopChest":
			code += "\n"
			code += _gen_ready_sub(aname, 0, 0, max_hp, damage, score_val, "")
			code += _gen_computer_interaction(death, score_val, actor_sounds)

		"Zombie", "Boss", "Tank":
			# Ground-based enemy AI — same structure as Drone
			var ai_gb: String = actor.get("ai_behavior", "Chase")
			var patrol_speed_gb: float = actor.get("ai_patrol_speed", 80)
			code += "Dim Direction As Single\n"
			code += "Dim PatrolSpeed As Single\n"
			code += "' ─── Path Following (set via level editor) ───\n"
			code += "Dim PathX(20) As Single\n"
			code += "Dim PathY(20) As Single\n"
			code += "Dim PathCount As Integer\n"
			code += "Dim PathIndex As Integer\n"
			code += "Dim HasPath As Boolean\n\n"
			var gb_init = "    Direction = 1.0\n"
			gb_init += "    PatrolSpeed = " + _fstr(patrol_speed_gb) + "\n"
			gb_init += "    PathCount = 0\n"
			gb_init += "    PathIndex = 0\n"
			gb_init += "    HasPath = False\n"
			code += _gen_ready_sub(aname, speed, gravity * grav_scale, max_hp, damage, score_val, "enemies", gb_init)
			code += _gen_add_path_point_sub()
			code += _gen_drone_physics(ai_gb, patrol_speed_gb, gravity * grav_scale)
			code += _gen_collision_handler(atype, actor_sounds)
			code += _gen_damage_sub(death, rebirth, false, actor_sounds)

		"Bat":
			# Flying enemy AI — like Drone but zero gravity
			var ai_bat: String = actor.get("ai_behavior", "Chase")
			var patrol_speed_bat: float = actor.get("ai_patrol_speed", 80)
			code += "Dim Direction As Single\n"
			code += "Dim PatrolSpeed As Single\n"
			code += "' ─── Path Following (set via level editor) ───\n"
			code += "Dim PathX(20) As Single\n"
			code += "Dim PathY(20) As Single\n"
			code += "Dim PathCount As Integer\n"
			code += "Dim PathIndex As Integer\n"
			code += "Dim HasPath As Boolean\n\n"
			var bat_init = "    Direction = 1.0\n"
			bat_init += "    PatrolSpeed = " + _fstr(patrol_speed_bat) + "\n"
			bat_init += "    PathCount = 0\n"
			bat_init += "    PathIndex = 0\n"
			bat_init += "    HasPath = False\n"
			code += _gen_ready_sub(aname, speed, 0, max_hp, damage, score_val, "enemies", bat_init)
			code += _gen_add_path_point_sub()
			code += _gen_drone_physics(ai_bat, patrol_speed_bat, 0)
			code += _gen_collision_handler(atype, actor_sounds)
			code += _gen_damage_sub(death, rebirth, false, actor_sounds)

		"NPC":
			# Friendly NPC — interactive, no movement
			code += "\n"
			code += _gen_ready_sub(aname, 0, 0, max_hp, damage, score_val, "npc")
			code += _gen_npc_interaction()

		"Fireball":
			# Flaming projectile — like Missile
			code += "Dim MoveDirection As Vector2\n"
			code += "Dim LifeTime As Single\n\n"
			code += _gen_ready_sub(aname, speed, 0, max_hp, damage, score_val, "")
			code += _gen_missile_physics(speed)
			code += _gen_collision_handler(atype, actor_sounds)

	# ── PlayAnimation helper (only when multiple animations exist) ──
	var anim_data_list: Array = actor.get("anim_data", [])
	if anim_data_list.size() > 1:
		code += "' ─── Animation Helper ─────────────────────\n"
		code += "' Available animations: "
		var anim_names_list: Array = []
		for ad in anim_data_list:
			anim_names_list.append(ad.get("name", "Idle"))
		code += ", ".join(anim_names_list) + "\n"
		code += "Sub PlayAnimation(animName As String)\n"
		code += "    If CurrentAnim <> animName Then\n"
		code += "        CurrentAnim = animName\n"
		code += "        Dim sprite As AnimatedSprite2D\n"
		code += "        sprite = GetNode(\"AnimatedSprite2D\")\n"
		code += "        Call sprite.play(animName)\n"
		code += "    End If\n"
		code += "End Sub\n\n"

	# ── User code section — preserved across rebuilds ──
	code += "' ─── Your Custom Code ─────────────────────\n"
	code += "' Add your own Subs and functions below.\n"
	code += "' This section is preserved when you rebuild from AGCK.\n"
	code += _user_code_block(aname + "_custom", "' (add your code here)\n", preserved)

	_write_file(path, code)


# ─── VG Code Templates ──────────────────────────────────────

## Generate a VG code snippet that calls PlaySFX_<name>() on Main scene.
## Returns empty string if sound is "(None)" or blank.
func _gen_play_sfx_call(sound_name: String, indent: String = "    ") -> String:
	if sound_name == "" or sound_name == "(None)":
		return ""
	var safe = _safe_id(sound_name)
	var s = indent + "Dim _snd As Node2D = GetTree().CurrentScene\n"
	s += indent + "If _snd <> Nothing And _snd.HasMethod(\"PlaySFX_" + safe + "\") Then\n"
	s += indent + "    _snd.PlaySFX_" + safe + "()\n"
	s += indent + "End If\n"
	return s

func _gen_ready_sub(aname: String, speed: float, gravity: float, hp: int, dmg: int, score: int, group: String = "", extra_init: String = "") -> String:
	var s = "Sub _Ready()\n"
	s += "    Speed = " + _fstr(speed) + "\n"
	s += "    Gravity = " + _fstr(gravity) + "\n"
	s += "    MaxHP = " + str(hp) + "\n"
	s += "    CurrentHP = MaxHP\n"
	s += "    Damage = " + str(dmg) + "\n"
	s += "    ScoreValue = " + str(score) + "\n"
	s += "    IsInvincible = False\n"
	s += "    InvincibleTimer = 0.0\n"
	s += "    CurrentAnim = \"Idle\"\n"
	if speed > 0:
		s += "    vx = 0.0\n"
		s += "    vy = 0.0\n"
	if group != "":
		s += "    AddToGroup(\"" + group + "\")\n"
	if extra_init != "":
		s += extra_init
	s += "End Sub\n\n"
	return s


func _gen_add_path_point_sub() -> String:
	var s = ""
	s += "' Called by level script to set waypoints for this actor\n"
	s += "Sub AddPathPoint(px As Single, py As Single)\n"
	s += "    If PathCount < 20 Then\n"
	s += "        PathX(PathCount) = px\n"
	s += "        PathY(PathCount) = py\n"
	s += "        PathCount = PathCount + 1\n"
	s += "        HasPath = True\n"
	s += "    End If\n"
	s += "End Sub\n\n"
	return s


func _gen_player_physics(speed: float, gravity: float, collision: String, actor_sounds: Dictionary = {}) -> String:
	var s = ""
	s += "Sub _PhysicsProcess(delta As Single)\n"
	s += "    ' Read current velocity from CharacterBody2D\n"
	s += "    vx = Me.velocity.x\n"
	s += "    vy = Me.velocity.y\n"
	s += "\n"
	# ── Ladder detection ──
	# A ladder is any node in the "ladder" group whose centre is within one
	# half-cell horizontally and one full-cell vertically of the player. When
	# overlapping, gravity is suppressed and ui_up/ui_down drive vy directly.
	s += "    ' Ladder detection — reset module-scoped flag each frame\n"
	s += "    on_ladder = False\n"
	s += "    Dim ladders As Variant = GetTree().GetNodesInGroup(\"ladder\")\n"
	s += "    Dim half_sq As Single = " + str(pow(CELL_PX / 2.0 + 2.0, 2)) + "\n"
	s += "    Dim full_sq As Single = " + str(pow(float(CELL_PX), 2)) + "\n"
	s += "    Dim hx As Single = Me.position.x\n"
	s += "    Dim hy As Single = Me.position.y\n"
	s += "    If ladders <> Nothing Then\n"
	s += "        Dim li As Integer\n"
	s += "        For li = 0 To ladders.size() - 1\n"
	s += "            Dim lnode As Variant = ladders.Get(li)\n"
	s += "            If lnode <> Nothing Then\n"
	s += "                Dim ldx As Single = lnode.global_position.x - hx\n"
	s += "                Dim ldy As Single = lnode.global_position.y - hy\n"
	s += "                Dim ldx2 As Single = ldx * ldx\n"
	s += "                Dim ldy2 As Single = ldy * ldy\n"
	s += "                If ldx2 < half_sq Then\n"
	s += "                    If ldy2 < full_sq Then\n"
	s += "                        on_ladder = True\n"
	s += "                    End If\n"
	s += "                End If\n"
	s += "            End If\n"
	s += "        Next\n"
	s += "    End If\n"
	s += "\n"
	s += "    Dim climb_speed As Single = " + _fstr(max(60.0, speed * 0.75)) + "\n"
	s += "    If on_ladder Then\n"
	s += "        ' On ladder — suppress gravity, climb with up/down\n"
	s += "        If Input.IsActionPressed(\"ui_up\") Then\n"
	s += "            vy = -climb_speed\n"
	s += "        ElseIf Input.IsActionPressed(\"ui_down\") Then\n"
	s += "            vy = climb_speed\n"
	s += "        Else\n"
	s += "            vy = 0\n"
	s += "        End If\n"
	s += "    Else\n"
	s += "        ' Apply gravity normally\n"
	s += "        vy = vy + Gravity * delta\n"
	s += "    End If\n"
	s += "\n"
	s += "    ' Horizontal movement\n"
	s += "    If Input.IsActionPressed(\"ui_left\") Then\n"
	s += "        vx = -Speed\n"
	s += "    ElseIf Input.IsActionPressed(\"ui_right\") Then\n"
	s += "        vx = Speed\n"
	s += "    Else\n"
	s += "        vx = 0\n"
	s += "    End If\n"
	s += "\n"
	s += "    ' Jumping (disabled while climbing a ladder)\n"
	s += "    If Input.IsActionJustPressed(\"ui_accept\") And IsOnFloor(Me) And Not on_ladder Then\n"
	s += "        vy = -400.0\n"
	var jump_sfx = _gen_play_sfx_call(actor_sounds.get("jump", "(None)"), "        ")
	if jump_sfx != "":
		s += jump_sfx
	s += "    End If\n"
	s += "\n"
	s += "    ' Write velocity back and move\n"
	s += "    SetVelocity Me, vx, vy\n"
	s += "    MoveAndSlide Me\n"
	s += "\n"
	s += "    ' Invincibility timer — blink and restore after damage\n"
	s += "    If IsInvincible Then\n"
	s += "        InvincibleTimer = InvincibleTimer - delta\n"
	s += "        If InvincibleTimer <= 0 Then\n"
	s += "            IsInvincible = False\n"
	s += "            Me.visible = True\n"
	s += "            Me.modulate = Color(1, 1, 1, 1)\n"
	s += "        Else\n"
	s += "            ' Blink effect\n"
	s += "            Me.visible = Not Me.visible\n"
	s += "        End If\n"
	s += "    End If\n"
	s += "\n"
	# Fall-off-map detection — if the player falls below the map, lose a life.
	# Use a generous flat threshold so this works for any level height up
	# to ~1500 cells. Per-actor scripts don't know the host level's height
	# at codegen time, so a fixed (very large) Y wins us tall-level support.
	var kill_y: int = 50000
	s += "    ' Fall-off-map detection\n"
	s += "    If Me.GlobalPosition.Y > " + str(kill_y) + " Then\n"
	s += "        Dim main As Node2D = GetTree().CurrentScene\n"
	s += "        If main <> Nothing And main.HasMethod(\"LoseLife\") Then\n"
	s += "            main.LoseLife()\n"
	s += "        End If\n"
	s += "    End If\n"
	s += "End Sub\n\n"
	return s


# ─── Runner physics (Geometry-Dash-style auto-runner) ──────────────────────
# Drives a Runner-type actor: constant rightward velocity, single-button jump,
# gravity always on, sprite rotates 360° per ~0.7s while airborne and snaps
# to the nearest 90° on landing for that satisfying GD "tumble" feel.
# Hold-to-rejump: as long as ui_accept is held and the runner is on the floor,
# it keeps re-launching every frame (matches GD's hold-jump cube behavior).
func _gen_runner_physics(speed: float, gravity: float, jump_force: float, actor_sounds: Dictionary = {}) -> String:
	var s = ""
	s += "Sub _PhysicsProcess(delta As Single)\n"
	s += "    ' Read current velocity\n"
	s += "    vx = Me.velocity.x\n"
	s += "    vy = Me.velocity.y\n"
	s += "\n"
	s += "    ' Auto-run: horizontal velocity is locked to Speed every frame.\n"
	s += "    ' No left/right input — this is the core Geometry-Dash mechanic.\n"
	s += "    vx = Speed\n"
	s += "\n"
	s += "    ' Gravity is always applied (no ladder logic for runner).\n"
	s += "    vy = vy + Gravity * delta\n"
	s += "\n"
	s += "    ' Jump on accept while on floor. Hold-to-rejump: every floor-contact\n"
	s += "    ' frame the button stays pressed will retrigger the launch.\n"
	s += "    If Input.IsActionPressed(\"ui_accept\") And IsOnFloor(Me) Then\n"
	s += "        vy = -" + _fstr(jump_force) + "\n"
	s += "        IsJumping = True\n"
	var jump_sfx = _gen_play_sfx_call(actor_sounds.get("jump", "(None)"), "        ")
	if jump_sfx != "":
		s += jump_sfx
	s += "    End If\n"
	s += "\n"
	s += "    ' Write velocity back and move\n"
	s += "    SetVelocity Me, vx, vy\n"
	s += "    MoveAndSlide Me\n"
	s += "\n"
	s += "    ' Cube rotation: spin while airborne, snap to nearest 90° on landing.\n"
	s += "    ' ~9 rad/s ≈ one full rotation per 0.7s — feels like classic GD.\n"
	s += "    If IsOnFloor(Me) Then\n"
	s += "        ' Snap rotation to nearest 90° (PI/2 rad) — the chunky landing pose.\n"
	s += "        Dim quarter As Single = 1.5707963\n"
	s += "        Dim r As Single = Me.rotation\n"
	s += "        Dim snap As Single = Round(r / quarter) * quarter\n"
	s += "        Me.rotation = snap\n"
	s += "        IsJumping = False\n"
	s += "    Else\n"
	s += "        Me.rotation = Me.rotation + 9.0 * delta\n"
	s += "    End If\n"
	s += "\n"
	s += "    ' Invincibility timer — visual blink after a near-miss\n"
	s += "    If IsInvincible Then\n"
	s += "        InvincibleTimer = InvincibleTimer - delta\n"
	s += "        If InvincibleTimer <= 0 Then\n"
	s += "            IsInvincible = False\n"
	s += "            Me.visible = True\n"
	s += "            Me.modulate = Color(1, 1, 1, 1)\n"
	s += "        Else\n"
	s += "            Me.visible = Not Me.visible\n"
	s += "        End If\n"
	s += "    End If\n"
	s += "\n"
	# Fall-off-map detection — same as Player; if cube falls below the map, it dies.
	# Use a generous flat threshold so this works for any level height.
	var kill_y: int = 50000
	s += "    ' Fall-off-map detection\n"
	s += "    If Me.GlobalPosition.Y > " + str(kill_y) + " Then\n"
	s += "        Dim main As Node2D = GetTree().CurrentScene\n"
	s += "        If main <> Nothing And main.HasMethod(\"LoseLife\") Then\n"
	s += "            main.LoseLife()\n"
	s += "        End If\n"
	s += "    End If\n"
	s += "End Sub\n\n"
	return s


func _gen_drone_physics(ai: String, patrol_speed: float, gravity: float) -> String:
	var s = ""
	s += "Sub _PhysicsProcess(delta As Single)\n"
	# ── Waypoint path mode: bypass all normal AI ──
	s += "    If HasPath And PathCount >= 2 Then\n"
	s += "        ' Follow waypoint path (overrides normal movement)\n"
	s += "        Dim tx As Single = PathX(PathIndex)\n"
	s += "        Dim ty As Single = PathY(PathIndex)\n"
	s += "        Dim dx As Single = tx - Me.GlobalPosition.X\n"
	s += "        Dim dy As Single = ty - Me.GlobalPosition.Y\n"
	s += "        Dim dist As Single = Sqr(dx * dx + dy * dy)\n"
	s += "        If dist < 4.0 Then\n"
	s += "            ' Reached waypoint — advance to next (loop)\n"
	s += "            PathIndex = PathIndex + 1\n"
	s += "            If PathIndex >= PathCount Then PathIndex = 0\n"
	s += "        Else\n"
	s += "            ' Move toward waypoint via direct position\n"
	s += "            Dim mx As Single = (dx / dist) * PatrolSpeed * delta\n"
	s += "            Dim my As Single = (dy / dist) * PatrolSpeed * delta\n"
	s += "            Me.GlobalPosition = Vector2(Me.GlobalPosition.X + mx, Me.GlobalPosition.Y + my)\n"
	s += "        End If\n"
	s += "        Exit Sub\n"
	s += "    End If\n\n"
	s += "    ' ── Normal AI movement ──\n"
	s += "    ' Read current velocity\n"
	s += "    vx = Me.velocity.x\n"
	s += "    vy = Me.velocity.y\n"
	s += "\n"
	s += "    ' Apply gravity\n"
	s += "    vy = vy + Gravity * delta\n"
	s += "\n"
	# Original AI behavior when no path set
	match ai:
		"Chase":
			s += "    ' Chase: move toward player\n"
			s += "    Dim player As Node2D = GetTree().GetFirstNodeInGroup(\"player\")\n"
			s += "    If player <> Nothing Then\n"
			s += "        If player.GlobalPosition.X < GlobalPosition.X Then\n"
			s += "            vx = -Speed\n"
			s += "        Else\n"
			s += "            vx = Speed\n"
			s += "        End If\n"
			s += "    Else\n"
			s += "        vx = PatrolSpeed * Direction\n"
			s += "    End If\n"
		"Flee":
			s += "    ' Flee: run from player\n"
			s += "    Dim player As Node2D = GetTree().GetFirstNodeInGroup(\"player\")\n"
			s += "    If player <> Nothing Then\n"
			s += "        If player.GlobalPosition.X < GlobalPosition.X Then\n"
			s += "            vx = Speed\n"
			s += "        Else\n"
			s += "            vx = -Speed\n"
			s += "        End If\n"
			s += "    Else\n"
			s += "        vx = PatrolSpeed * Direction\n"
			s += "    End If\n"
		_:  # Patrol, Wander, Guard
			s += "    ' Patrol: walk back and forth\n"
			s += "    vx = PatrolSpeed * Direction\n"
	s += "\n"
	s += "    ' Write velocity and move\n"
	s += "    SetVelocity Me, vx, vy\n"
	s += "    MoveAndSlide Me\n"
	s += "\n"
	s += "    ' Reverse at walls\n"
	s += "    If IsOnWall(Me) Then\n"
	s += "        Direction = -Direction\n"
	s += "    End If\n"
	s += "End Sub\n\n"
	return s


func _gen_missile_physics(speed: float) -> String:
	var s = ""
	s += "Sub _PhysicsProcess(delta As Single)\n"
	s += "    ' Missiles move in a straight line\n"
	s += "    Position = Position + MoveDirection * Speed * delta\n"
	s += "\n"
	s += "    ' Destroy after lifetime expires\n"
	s += "    LifeTime = LifeTime - delta\n"
	s += "    If LifeTime <= 0 Then\n"
	s += "        QueueFree()\n"
	s += "    End If\n"
	s += "End Sub\n\n"
	s += "Sub Launch(dir As Vector2)\n"
	s += "    MoveDirection = dir.Normalized()\n"
	s += "    LifeTime = 3.0\n"
	s += "End Sub\n\n"
	return s


func _gen_sentry_physics(patrol_speed: float, gravity: float, auto_shoot: bool, fire_rate: float, actor_sounds: Dictionary = {}) -> String:
	var s = ""
	s += "Sub _PhysicsProcess(delta As Single)\n"
	# ── Waypoint path mode: bypass all normal AI ──
	s += "    If HasPath And PathCount >= 2 Then\n"
	s += "        ' Follow waypoint path (overrides normal movement)\n"
	s += "        Dim tx As Single = PathX(PathIndex)\n"
	s += "        Dim ty As Single = PathY(PathIndex)\n"
	s += "        Dim dx As Single = tx - Me.GlobalPosition.X\n"
	s += "        Dim dy As Single = ty - Me.GlobalPosition.Y\n"
	s += "        Dim dist As Single = Sqr(dx * dx + dy * dy)\n"
	s += "        If dist < 4.0 Then\n"
	s += "            ' Reached waypoint — advance to next (loop)\n"
	s += "            PathIndex = PathIndex + 1\n"
	s += "            If PathIndex >= PathCount Then PathIndex = 0\n"
	s += "        Else\n"
	s += "            ' Move toward waypoint via direct position\n"
	s += "            Dim mx As Single = (dx / dist) * PatrolSpeed * delta\n"
	s += "            Dim my As Single = (dy / dist) * PatrolSpeed * delta\n"
	s += "            Me.GlobalPosition = Vector2(Me.GlobalPosition.X + mx, Me.GlobalPosition.Y + my)\n"
	s += "        End If\n"
	if auto_shoot:
		s += "\n"
		s += "        ' Auto-shoot timer (still active during path mode)\n"
		s += "        ShootTimer = ShootTimer + delta\n"
		s += "        If ShootTimer >= FireRate Then\n"
		s += "            ShootTimer = 0\n"
		# Play shoot sound
		var shoot_sfx_path = _gen_play_sfx_call(actor_sounds.get("shoot", "(None)"), "            ")
		if shoot_sfx_path != "":
			s += shoot_sfx_path
		s += "            ' Spawn a missile toward the player\n"
		s += "            Dim player As Node2D = GetTree().GetFirstNodeInGroup(\"player\")\n"
		s += "            If player <> Nothing Then\n"
		s += "                Dim dir As Vector2\n"
		s += "                dir = (player.GlobalPosition - Me.GlobalPosition).Normalized()\n"
		s += "                Dim bullet As CharacterBody2D = CharacterBody2D.New()\n"
		s += "                GetParent().AddChild(bullet)\n"
		s += "                bullet.GlobalPosition = Me.GlobalPosition\n"
		s += "                SetVelocity bullet, dir.x * 300.0, dir.y * 300.0\n"
		s += "                bullet.AddToGroup(\"enemies\")\n"
		s += "            End If\n"
		s += "        End If\n"
	s += "        Exit Sub\n"
	s += "    End If\n\n"
	s += "    ' ── Normal AI movement ──\n"
	s += "    ' Read current velocity\n"
	s += "    vx = Me.velocity.x\n"
	s += "    vy = Me.velocity.y\n"
	s += "\n"
	s += "    ' Apply gravity\n"
	s += "    vy = vy + Gravity * delta\n"
	s += "\n"
	s += "    ' Patrol back and forth\n"
	s += "    vx = PatrolSpeed * Direction\n"
	s += "\n"
	s += "    SetVelocity Me, vx, vy\n"
	s += "    MoveAndSlide Me\n"
	s += "\n"
	s += "    ' Reverse at walls\n"
	s += "    If IsOnWall(Me) Then\n"
	s += "        Direction = -Direction\n"
	s += "    End If\n"
	if auto_shoot:
		s += "\n"
		s += "    ' Auto-shoot timer\n"
		s += "    ShootTimer = ShootTimer + delta\n"
		s += "    If ShootTimer >= FireRate Then\n"
		s += "        ShootTimer = 0\n"
		# Play shoot sound
		var shoot_sfx = _gen_play_sfx_call(actor_sounds.get("shoot", "(None)"), "        ")
		if shoot_sfx != "":
			s += shoot_sfx
		s += "        ' Spawn a missile toward the player\n"
		s += "        Dim player As Node2D = GetTree().GetFirstNodeInGroup(\"player\")\n"
		s += "        If player <> Nothing Then\n"
		s += "            Dim dir As Vector2\n"
		s += "            dir = (player.GlobalPosition - Me.GlobalPosition).Normalized()\n"
		s += "            Dim bullet As CharacterBody2D = CharacterBody2D.New()\n"
		s += "            GetParent().AddChild(bullet)\n"
		s += "            bullet.GlobalPosition = Me.GlobalPosition\n"
		s += "            SetVelocity bullet, dir.x * 300.0, dir.y * 300.0\n"
		s += "            bullet.AddToGroup(\"enemies\")\n"
		s += "        End If\n"
		s += "    End If\n"
	s += "End Sub\n\n"
	return s


func _gen_damage_sub(death_mode: String, rebirth: float, is_player: bool = false, actor_sounds: Dictionary = {}) -> String:
	var s = ""
	s += "' Called when this actor takes damage\n"
	s += "Sub TakeDamage(amount As Integer)\n"
	if is_player:
		s += "    ' Skip if currently invincible (just took a hit)\n"
		s += "    If IsInvincible Then Exit Sub\n"
	s += "    CurrentHP = CurrentHP - amount\n"
	# Play hit sound effect
	var hit_sfx = _gen_play_sfx_call(actor_sounds.get("hit", "(None)"), "    ")
	if hit_sfx != "":
		s += hit_sfx
	if is_player:
		s += "    ' Trigger hit animation\n"
		s += "    Dim main As Node2D = GetTree().CurrentScene\n"
		s += "    If main <> Nothing And main.HasMethod(\"TriggerHeroAnim\") Then\n"
		s += "        main.TriggerHeroAnim(\"hit\")\n"
		s += "    End If\n"
		s += "    ' Brief invincibility after taking damage\n"
		s += "    IsInvincible = True\n"
		s += "    InvincibleTimer = 1.5\n"
		s += "    Me.modulate = Color(1, 1, 1, 0.5)\n"
	s += "    If CurrentHP <= 0 Then\n"
	# Play death sound effect
	var death_sfx = _gen_play_sfx_call(actor_sounds.get("death", "(None)"), "        ")
	if death_sfx != "":
		s += death_sfx
	if is_player:
		s += "        IsInvincible = False\n"
		s += "        Me.visible = True\n"
		s += "        Me.modulate = Color(1, 1, 1, 1)\n"
	match death_mode:
		"Destroy":
			if is_player:
				s += "        ' Tell game controller we lost a life\n"
				s += "        Dim main As Node2D = GetTree().CurrentScene\n"
				s += "        If main <> Nothing And main.HasMethod(\"LoseLife\") Then\n"
				s += "            main.LoseLife()\n"
				s += "        End If\n"
			s += "        QueueFree()\n"
		"GameOver":
			s += "        ' Game over\n"
			s += "        Dim main As Node2D = GetTree().CurrentScene\n"
			s += "        If main <> Nothing And main.HasMethod(\"GameOver\") Then\n"
			s += "            main.GameOver()\n"
			s += "        Else\n"
			s += "            GetTree().ReloadCurrentScene()\n"
			s += "        End If\n"
		_:  # Respawn
			if is_player:
				s += "        ' Tell game controller we lost a life\n"
				s += "        Dim main As Node2D = GetTree().CurrentScene\n"
				s += "        If main <> Nothing And main.HasMethod(\"LoseLife\") Then\n"
				s += "            main.LoseLife()\n"
				s += "        End If\n"
			s += "        ' Respawn — reset HP\n"
			s += "        CurrentHP = MaxHP\n"
	s += "    End If\n"
	s += "End Sub\n\n"
	return s


func _gen_computer_interaction(death_mode: String, score_val: int, actor_sounds: Dictionary = {}) -> String:
	var s = ""
	s += "' Computer objects respond to collisions (coins, keys, etc.)\n"
	s += "Sub Hitbox_BodyEntered(body As Node2D)\n"
	s += "    ' Check if the player touched us\n"
	s += "    If body.IsInGroup(\"player\") Then\n"
	# Play pickup sound
	var pickup_sfx = _gen_play_sfx_call(actor_sounds.get("pickup", "(None)"), "        ")
	if pickup_sfx != "":
		s += pickup_sfx
	if score_val > 0:
		s += "        ' Award points via the game controller\n"
		s += "        Dim main As Node2D = GetTree().CurrentScene\n"
		s += "        If main <> Nothing And main.HasMethod(\"AddScore\") Then\n"
		s += "            main.AddScore(ScoreValue)\n"
		s += "        End If\n"
	if death_mode == "Destroy":
		s += "        ' Collect and vanish\n"
		s += "        QueueFree()\n"
	else:
		s += "        ' Interact\n"
		s += "        ' TODO: Add your interaction logic here\n"
	s += "    End If\n"
	s += "End Sub\n\n"
	s += "Sub Hitbox_AreaEntered(area As Area2D)\n"
	s += "    ' Area-based interaction\n"
	s += "End Sub\n\n"
	return s


func _gen_npc_interaction() -> String:
	var s = ""
	s += "' NPC responds to player interaction\n"
	s += "Sub Hitbox_BodyEntered(body As Node2D)\n"
	s += "    If body.IsInGroup(\"player\") Then\n"
	s += "        ' Player is nearby — interact\n"
	s += "        ' Add your dialog or quest logic here\n"
	s += "    End If\n"
	s += "End Sub\n\n"
	s += "Sub Hitbox_AreaEntered(area As Area2D)\n"
	s += "    ' Area interaction\n"
	s += "End Sub\n\n"
	return s


func _gen_collision_handler(atype: String, actor_sounds: Dictionary = {}) -> String:
	var s = ""
	s += "' ─── Collision Handling ───\n"
	match atype:
		"Player":
			s += "Sub Hitbox_BodyEntered(body As Node2D)\n"
			s += "    If IsInvincible Then Exit Sub\n"
			s += "    ' Touched an enemy — take damage\n"
			s += "    If body.IsInGroup(\"enemies\") Then\n"
			s += "        ' Read the enemy's configured Damage value\n"
			s += "        TakeDamage(body.Damage)\n"
			s += "    End If\n"
			s += "End Sub\n\n"
			s += "Sub Hitbox_AreaEntered(area As Area2D)\n"
			s += "    If IsInvincible Then Exit Sub\n"
			s += "    Dim owner As Node = area.GetParent()\n"
			s += "    If owner <> Nothing And owner.IsInGroup(\"enemies\") Then\n"
			s += "        TakeDamage(owner.Damage)\n"
			s += "    End If\n"
			s += "End Sub\n\n"
		"Drone", "Sentry", "Zombie", "Boss", "Bat", "Tank":
			s += "Sub Hitbox_BodyEntered(body As Node2D)\n"
			s += "    ' Player jumped on us — take damage\n"
			s += "    If body.IsInGroup(\"player\") Then\n"
			s += "        ' Check if player is above (stomp)\n"
			s += "        If body.GlobalPosition.Y < GlobalPosition.Y - 8 Then\n"
			s += "            TakeDamage(MaxHP)  ' instant kill from stomp\n"
			# Play stomp sound
			var stomp_sfx = _gen_play_sfx_call(actor_sounds.get("stomp", "(None)"), "            ")
			if stomp_sfx != "":
				s += stomp_sfx
			s += "            ' Award score to game controller\n"
			s += "            Dim main As Node2D = GetTree().CurrentScene\n"
			s += "            If main <> Nothing And main.HasMethod(\"AddScore\") Then\n"
			s += "                main.AddScore(ScoreValue)\n"
			s += "            End If\n"
			s += "            ' Bounce the player up\n"
			s += "            SetVelocity body, body.velocity.x, -250.0\n"
			s += "        End If\n"
			s += "    End If\n"
			s += "End Sub\n\n"
			s += "Sub Hitbox_AreaEntered(area As Area2D)\n"
			s += "    ' Area interaction\n"
			s += "End Sub\n\n"
		"Missile", "Fireball":
			s += "Sub Hitbox_BodyEntered(body As Node2D)\n"
			s += "    If body.HasMethod(\"TakeDamage\") Then\n"
			s += "        body.TakeDamage(Damage)\n"
			s += "    End If\n"
			s += "    QueueFree()\n"
			s += "End Sub\n\n"
			s += "Sub Hitbox_AreaEntered(area As Area2D)\n"
			s += "    ' Area interaction\n"
			s += "End Sub\n\n"
	return s


# ═══════════════════════════════════════════════════════════════
# LEVEL SCENE GENERATION
# ═══════════════════════════════════════════════════════════════

func _generate_level_tscn(path: String, lvl: Dictionary, actors: Array, level_idx: int, level_indices: Array[int], output_dir: String) -> void:
	var grid: Array = lvl.get("grid", [])
	var placed_actors: Array = lvl.get("actors", [])
	var lvl_name = "Level_" + str(level_idx + 1).pad_zeros(2)
	var vg_path = path.replace(".tscn", ".vg")

	# Per-level grid dimensions — read from the dict if present, else fall
	# back to the actual array shape, else the historical 20×12 default.
	# Camera limits, ColorRect background size, and grid iteration bounds
	# all key off these. This is what allows levels to be longer/taller
	# than 20×12 without breaking the rest of the pipeline.
	var lvl_w: int = int(lvl.get("grid_w", 0))
	var lvl_h: int = int(lvl.get("grid_h", 0))
	if lvl_w <= 0:
		lvl_w = grid[0].size() if (grid.size() > 0 and grid[0] is Array) else GRID_W
	if lvl_h <= 0:
		lvl_h = grid.size() if grid.size() > 0 else GRID_H

	# ── Pass 1: Collect all unique tile textures used in this level ──
	# Key = "bt_ti" (e.g. "1_0"), value = relative path to tile PNG
	var tile_textures: Dictionary = {}   # "bt_ti" -> png_relative_path
	for y in range(grid.size()):
		var row = grid[y]
		for x in range(row.size()):
			var cell = row[x]
			var block_id: int = 0
			var tile_idx: int = 0
			if cell is Dictionary:
				block_id = cell.get("block_type", 0)
				tile_idx = cell.get("tile_index", 0)
			elif cell is int or cell is float:
				block_id = int(cell)
			if block_id <= 0:
				continue
			var key = str(block_id) + "_" + str(tile_idx)
			if not tile_textures.has(key):
				# Resolve tile name from tile_library, matching the PNG export naming
				var tname := ""
				if tile_library:
					tname = tile_library.get_tile_name(block_id, tile_idx)
				if tname.is_empty():
					tname = BLOCK_NAMES[block_id] + "_" + str(tile_idx)
				var safe = _safe_id(tname)
				var png_rel = "../sprites/tile_" + BLOCK_NAMES[block_id].to_lower() + "_" + safe + ".png"
				tile_textures[key] = png_rel

	# ── Count ext resources: 1 script + N actor scenes + M tile textures ──
	var actor_scenes: Dictionary = {}  # actor_id -> ext_resource_id
	var ext_id = 2  # 1 is the level script
	for pa in placed_actors:
		var aid: int = pa.get("actor_id", 0)
		if not actor_scenes.has(aid) and aid < actors.size():
			actor_scenes[aid] = ext_id
			ext_id += 1

	# Assign ext_resource IDs to tile textures
	var tile_ext_ids: Dictionary = {}  # "bt_ti" -> ext_resource_id
	for key in tile_textures:
		tile_ext_ids[key] = ext_id
		ext_id += 1

	# ── Pass 1b: Collect per-tile shader FX used in this level ──
	# Key = "bt_ti", value = {shader_fx, shader_params}
	var tile_shader_map: Dictionary = {}  # "bt_ti" -> {fx_name, fx_params}
	var tile_shader_fx_set: Dictionary = {}  # unique fx_name -> SPRITE_SHADER_CODES code
	if tile_library:
		for key in tile_textures:
			var parts = key.split("_")
			if parts.size() == 2:
				var bt = int(parts[0])
				var ti = int(parts[1])
				var sfx: String = tile_library.get_tile_shader_fx(bt, ti)
				if sfx != "(None)" and SPRITE_SHADER_CODES.has(sfx):
					tile_shader_map[key] = {
						"fx_name": sfx,
						"fx_params": tile_library.get_tile_shader_params(bt, ti),
					}
					tile_shader_fx_set[sfx] = SPRITE_SHADER_CODES[sfx]

	# ── Build the .tscn ──
	# We'll build body content first, then prepend the header at the end
	# (because we need to know total load_steps and sub_resources)

	var body = ""

	# Root Node2D
	body += '[node name="' + lvl_name + '" type="Node2D"]\n'
	body += 'script = ExtResource("1")\n\n'

	# ── Blocks ──
	var block_idx = 0
	var block_paths: Dictionary = lvl.get("block_paths", {})
	var moving_block_nodes: Array = []  # track {node_name, path_arr} for level script
	for y in range(grid.size()):
		var row = grid[y]
		for x in range(row.size()):
			var cell = row[x]
			var block_id: int = 0
			var tile_idx: int = 0
			if cell is Dictionary:
				block_id = cell.get("block_type", 0)
				tile_idx = cell.get("tile_index", 0)
			elif cell is int or cell is float:
				block_id = int(cell)
			if block_id <= 0:
				continue  # skip empty
			block_idx += 1
			var node_name = "Block_" + str(block_idx)
			var px = x * CELL_PX + CELL_PX / 2
			var py = y * CELL_PX + CELL_PX / 2
			var tex_key = str(block_id) + "_" + str(tile_idx)

			# Check if this block has a movement path
			var bp_key = str(x) + "," + str(y)
			var has_block_path: bool = block_paths.has(bp_key) and block_paths[bp_key].size() >= 2

			# Determine if block needs collision (Barrier, Deadly, Teleport, Switch).
			# Ladder (block_id == 2) is intentionally pass-through so the hero
			# can climb up/down through it — it's emitted as a Sprite2D + Area2D
			# in the "ladder" group and detected by the player physics each
			# frame (see _gen_player_physics).
			var needs_body = block_id in [1, 3, 5, 6]

			if needs_body:
				# StaticBody2D for all blocks (AnimatableBody2D has transform-revert
				# issues with direct .Position assignment in _PhysicsProcess)
				body += '[node name="' + node_name + '" type="StaticBody2D" parent="."]\n'
				body += 'position = Vector2(' + str(px) + ', ' + str(py) + ')\n'
				if has_block_path:
					moving_block_nodes.append({"node_name": node_name, "path_key": bp_key, "path_arr": block_paths[bp_key]})
				# Teleport, Switch & Deadly blocks are pass-through (player walks
				# into them and the child Area2D fires the trigger). For Deadly
				# this is critical: with a solid 32×32 body, the player would
				# bounce off the wall before ever reaching the inner DeadlyArea,
				# so spike contact never registered. Pass-through lets the
				# DeadlyArea detect real visual overlap.
				if block_id in [3, 5, 6]:
					body += 'collision_layer = 0\n'
					body += 'collision_mask = 0\n'
				body += 'metadata/block_type = ' + str(block_id) + '\n'
				body += 'metadata/block_name = "' + BLOCK_NAMES[block_id] + '"\n'
				if block_id == 3:
					body += 'metadata/_groups = ["deadly"]\n'
				elif block_id == 5:
					body += 'metadata/_groups = ["teleport"]\n'
				body += '\n'

				# Visual — Sprite2D with actual tile texture
				if tile_ext_ids.has(tex_key):
					body += '[node name="Visual" type="Sprite2D" parent="' + node_name + '"]\n'
					if tile_shader_map.has(tex_key):
						body += 'material = SubResource("tile_shader_mat_' + tile_shader_map[tex_key]["fx_name"] + '")\n'
					body += 'texture = ExtResource("' + str(tile_ext_ids[tex_key]) + '")\n'
					body += 'texture_filter = 0\n\n'
				else:
					# Fallback ColorRect if tile PNG somehow missing
					body += '[node name="Visual" type="ColorRect" parent="' + node_name + '"]\n'
					body += 'offset_left = ' + str(-CELL_PX / 2) + '\n'
					body += 'offset_top = ' + str(-CELL_PX / 2) + '\n'
					body += 'offset_right = ' + str(CELL_PX / 2) + '\n'
					body += 'offset_bottom = ' + str(CELL_PX / 2) + '\n'
					body += 'color = ' + _hex_to_tscn_color(BLOCK_COLORS_HEX[block_id]) + '\n\n'

				# Collision
				body += '[node name="Collision" type="CollisionShape2D" parent="' + node_name + '"]\n'
				body += 'shape = SubResource("block_shape")\n\n'

				# Teleport blocks get an Area2D for detection
				if block_id == 5:
					body += '[node name="TeleportArea" type="Area2D" parent="' + node_name + '"]\n'
					body += 'collision_layer = 4\n'
					body += 'collision_mask = 1\n\n'
					body += '[node name="TeleportShape" type="CollisionShape2D" parent="' + node_name + '/TeleportArea"]\n'
					body += 'shape = SubResource("block_shape")\n\n'

				# Deadly blocks get an Area2D for damage — shape is slightly larger
				# than the solid collision so body_entered fires on contact
				if block_id == 3:
					body += '[node name="DeadlyArea" type="Area2D" parent="' + node_name + '"]\n'
					body += 'collision_layer = 8\n'
					body += 'collision_mask = 1\n'
					body += 'monitorable = true\n'
					body += 'monitoring = true\n\n'
					body += '[node name="DeadlyShape" type="CollisionShape2D" parent="' + node_name + '/DeadlyArea"]\n'
					body += 'shape = SubResource("deadly_shape")\n\n'

				# Switch blocks get an Area2D for collectible/interaction
				if block_id == 6:
					body += '[node name="SwitchArea" type="Area2D" parent="' + node_name + '"]\n'
					body += 'collision_layer = 4\n'
					body += 'collision_mask = 1\n\n'
					body += '[node name="SwitchShape" type="CollisionShape2D" parent="' + node_name + '/SwitchArea"]\n'
					body += 'shape = SubResource("block_shape")\n\n'
			else:
				# Background (4) — Sprite2D, no collision
				# Ladder (2) — Sprite2D in "ladder" group; hero detects by proximity
				var ladder_group = ' groups=["ladder"]' if block_id == 2 else ''
				if tile_ext_ids.has(tex_key):
					body += '[node name="' + node_name + '" type="Sprite2D" parent="."' + ladder_group + ']\n'
					if tile_shader_map.has(tex_key):
						body += 'material = SubResource("tile_shader_mat_' + tile_shader_map[tex_key]["fx_name"] + '")\n'
					body += 'position = Vector2(' + str(px) + ', ' + str(py) + ')\n'
					body += 'texture = ExtResource("' + str(tile_ext_ids[tex_key]) + '")\n'
					body += 'texture_filter = 0\n'
				else:
					body += '[node name="' + node_name + '" type="ColorRect" parent="."' + ladder_group + ']\n'
					body += 'offset_left = ' + str(x * CELL_PX) + '\n'
					body += 'offset_top = ' + str(y * CELL_PX) + '\n'
					body += 'offset_right = ' + str(x * CELL_PX + CELL_PX) + '\n'
					body += 'offset_bottom = ' + str(y * CELL_PX + CELL_PX) + '\n'
					body += 'color = ' + _hex_to_tscn_color(BLOCK_COLORS_HEX[block_id]) + '\n'
				body += 'metadata/block_type = ' + str(block_id) + '\n'
				if block_id == 2:
					body += 'metadata/block_name = "Ladder"\n'
				body += '\n'

	# Actor instances — find the player to attach camera
	var player_inst_name: String = ""
	var actor_inst_idx = 0
	for pa in placed_actors:
		var aid: int = pa.get("actor_id", 0)
		if not actor_scenes.has(aid):
			continue
		actor_inst_idx += 1
		var px = pa.get("x", 0) * CELL_PX + CELL_PX / 2
		var py = pa.get("y", 0) * CELL_PX + CELL_PX / 2
		var aname = _safe_id(actors[aid].get("name", "Actor" + str(aid)))
		var inst_name = aname + "_" + str(actor_inst_idx)
		var actor_type = actors[aid].get("type", "Drone")

		body += '[node name="' + inst_name + '" parent="." instance=ExtResource("' + str(actor_scenes[aid]) + '")]\n'
		body += 'position = Vector2(' + str(px) + ', ' + str(py) + ')\n\n'

		# Track the player instance for camera attachment. Multiple actor
		# types are CharacterBody2D-derived player avatars; any of them
		# should get the follow-camera. Without this branch the Runner and
		# TopHero drifted off-camera the moment they moved.
		if (actor_type == "Player" or actor_type == "Runner"
				or actor_type == "TopHero" or actor_type == "Tank") \
				and player_inst_name.is_empty():
			player_inst_name = inst_name

	# Camera2D — attach to the player-like actor if found (follows actor),
	# else static at the level's center. "Player" is the classic platformer
	# hero; "Runner" (Geometry-Dash cube), "TopHero" (top-down hero), and
	# "Tank" (driving rigidbody) are also CharacterBody2D-derived player
	# avatars and need the camera to follow them too — prior to this fix
	# the camera fell back to static-at-center for every non-Player and
	# the player drifted off-screen as soon as they moved.
	if player_inst_name != "":
		body += '[node name="Camera2D" type="Camera2D" parent="' + player_inst_name + '"]\n'
		body += 'zoom = Vector2(1.5, 1.5)\n'
		body += 'position_smoothing_enabled = true\n'
		body += 'position_smoothing_speed = 5.0\n'
		body += 'drag_horizontal_enabled = true\n'
		body += 'drag_vertical_enabled = true\n'
		body += 'limit_left = 0\n'
		body += 'limit_top = 0\n'
		body += 'limit_right = ' + str(lvl_w * CELL_PX) + '\n'
		body += 'limit_bottom = ' + str(lvl_h * CELL_PX) + '\n\n'
	else:
		body += '[node name="Camera2D" type="Camera2D" parent="."]\n'
		body += 'position = Vector2(' + str(lvl_w * CELL_PX / 2) + ', ' + str(lvl_h * CELL_PX / 2) + ')\n'
		body += 'zoom = Vector2(1.5, 1.5)\n\n'

	# ── Build complete header with all ext_resources + sub_resources ──
	var tile_shader_sub_count: int = tile_shader_fx_set.size() * 2  # Shader + ShaderMaterial per unique effect
	var total_load_steps = ext_id + tile_shader_sub_count + 1  # ext resources + block_shape + deadly_shape + tile shaders
	var header = '[gd_scene load_steps=' + str(total_load_steps) + ' format=3]\n\n'

	# Ext resource: level script
	header += '[ext_resource type="Script" path="' + vg_path + '" id="1"]\n'

	# Ext resources: actor scenes
	for aid in actor_scenes:
		var aname = _safe_id(actors[aid].get("name", "Actor" + str(aid)))
		var actor_tscn_path = "../actors/Actor_" + aname + ".tscn"
		header += '[ext_resource type="PackedScene" path="' + actor_tscn_path + '" id="' + str(actor_scenes[aid]) + '"]\n'

	# Ext resources: tile textures
	for key in tile_ext_ids:
		header += '[ext_resource type="Texture2D" path="' + tile_textures[key] + '" id="' + str(tile_ext_ids[key]) + '"]\n'
	header += '\n'

	# Sub resource: collision shape
	header += '[sub_resource type="RectangleShape2D" id="block_shape"]\n'
	header += 'size = Vector2(' + str(CELL_PX) + ', ' + str(CELL_PX) + ')\n\n'

	# Deadly area shape — full cell (32×32). The Deadly StaticBody2D is now
	# pass-through (collision_layer=0), so the player physically enters the
	# tile and the Area2D's body_entered fires on real visual overlap with
	# the player's 28×28 hitbox. Two centered rects with these sizes overlap
	# whenever the player center is within 30 px of the spike center — i.e.
	# the moment any part of the sprite touches.
	header += '[sub_resource type="RectangleShape2D" id="deadly_shape"]\n'
	header += 'size = Vector2(' + str(CELL_PX) + ', ' + str(CELL_PX) + ')\n\n'

	# Sub resources: per-tile shader FX (one Shader + one ShaderMaterial per unique effect)
	for sfx_name in tile_shader_fx_set:
		var sfx_code: String = tile_shader_fx_set[sfx_name]
		var safe_sfx: String = _safe_id(sfx_name)
		header += '[sub_resource type="Shader" id="tile_shader_' + safe_sfx + '"]\n'
		header += 'code = "' + sfx_code.replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t") + '"\n\n'
		header += '[sub_resource type="ShaderMaterial" id="tile_shader_mat_' + sfx_name + '"]\n'
		header += 'shader = SubResource("tile_shader_' + safe_sfx + '")\n'
		# Apply default parameters from the first tile that uses this effect
		for tkey in tile_shader_map:
			if tile_shader_map[tkey]["fx_name"] == sfx_name:
				var sparams: Dictionary = tile_shader_map[tkey]["fx_params"]
				for pkey in sparams:
					var pval = sparams[pkey]
					var pstr: String
					if pval is float or pval is int:
						var fv: float = float(pval)
						if fv == int(fv):
							pstr = str(int(fv)) + ".0"
						else:
							pstr = str(fv)
					else:
						pstr = str(pval)
					header += 'shader_parameter/' + pkey + ' = ' + pstr + '\n'
				break
		header += '\n'

	_write_file(path, header + body)


func _generate_level_vg(path: String, lvl_name: String, lvl: Dictionary, actors: Array, level_indices: Array[int], output_dir: String, settings: Dictionary = {}) -> void:
	# Preserve any user code from the previous build
	var preserved := _extract_user_code(path)

	var friction: int = lvl.get("material_friction", 50)
	var elasticity: int = lvl.get("material_elasticity", 50)

	# Find the next level in the sequence
	var current_idx := -1
	for i in range(level_indices.size()):
		if "Level_" + str(level_indices[i] + 1).pad_zeros(2) == lvl_name:
			current_idx = i
			break

	var next_level_path := ""
	if current_idx >= 0 and current_idx + 1 < level_indices.size():
		var next_idx = level_indices[current_idx + 1]
		next_level_path = output_dir + "levels/Level_" + str(next_idx + 1).pad_zeros(2) + ".tscn"

	var code = ""
	code += "' " + lvl_name + ".vg — Level Controller\n"
	code += "' Generated by AGCK — customize freely!\n"
	code += "' Open in 2D Editor to move blocks & actors around.\n"
	code += "Option Explicit\n\n"

	code += "' ─── Level Properties ───\n"
	code += "Dim LevelName As String\n"
	code += "Dim Friction As Single\n"
	code += "Dim Elasticity As Single\n\n"

	# ── Module-level declarations for moving blocks ──
	var grid: Array = lvl.get("grid", [])
	var mblock_paths_decl: Dictionary = lvl.get("block_paths", {})
	var mblock_decl_idx = 0
	var mblock_decl_names: Array = []  # track names for later use
	for y_d in range(grid.size()):
		var row_d = grid[y_d]
		for x_d in range(row_d.size()):
			var cell_d = row_d[x_d]
			var block_id_d: int = 0
			if cell_d is Dictionary:
				block_id_d = cell_d.get("block_type", 0)
			elif cell_d is int or cell_d is float:
				block_id_d = int(cell_d)
			if block_id_d <= 0:
				continue
			mblock_decl_idx += 1
			var bp_key_d = str(x_d) + "," + str(y_d)
			if mblock_paths_decl.has(bp_key_d) and mblock_paths_decl[bp_key_d].size() >= 2:
				var bn = "Block_" + str(mblock_decl_idx)
				mblock_decl_names.append(bn)
				code += "' Moving block: " + bn + "\n"
				code += "Dim " + bn + " As StaticBody2D\n"
				code += "Dim " + bn + "_PathX(20) As Single\n"
				code += "Dim " + bn + "_PathY(20) As Single\n"
				code += "Dim " + bn + "_PathCount As Integer\n"
				code += "Dim " + bn + "_PathIndex As Integer\n\n"

	code += "Sub _Ready()\n"
	code += "    LevelName = \"" + lvl.get("name", lvl_name) + "\"\n"
	code += "    Friction = " + str(friction) + ".0\n"
	code += "    Elasticity = " + str(elasticity) + ".0\n"
	code += "\n"
	code += "    ' Wire teleport blocks to level transition\n"
	code += "    Dim child As Variant\n"
	code += "    For Each child In GetChildren()\n"
	code += "        If child.HasMeta(\"block_type\") Then\n"
	code += "            Dim bt As Integer = child.GetMeta(\"block_type\")\n"
	code += "            ' Teleport blocks (type 5) — wire Area2D signal\n"
	code += "            If bt = 5 Then\n"
	code += "                Dim area As Area2D = child.GetNodeOrNull(\"TeleportArea\")\n"
	code += "                If area <> Nothing Then\n"
	code += "                    area.Connect(\"body_entered\", \"Teleport_BodyEntered\")\n"
	code += "                End If\n"
	code += "            End If\n"
	code += "            ' Deadly blocks (type 3) — wire Area2D damage signal\n"
	code += "            If bt = 3 Then\n"
	code += "                Dim darea As Area2D = child.GetNodeOrNull(\"DeadlyArea\")\n"
	code += "                If darea <> Nothing Then\n"
	code += "                    darea.Connect(\"body_entered\", \"Deadly_BodyEntered\")\n"
	code += "                End If\n"
	code += "            End If\n"
	code += "            ' Switch blocks (type 6) — collectible/interactive\n"
	code += "            If bt = 6 Then\n"
	code += "                Dim sarea As Area2D = child.GetNodeOrNull(\"SwitchArea\")\n"
	code += "                If sarea <> Nothing Then\n"
	code += "                    sarea.Connect(\"body_entered\", \"Switch_BodyEntered\")\n"
	code += "                End If\n"
	code += "            End If\n"
	code += "        End If\n"
	code += "    Next\n"

	# ── Set waypoint paths for placed actors ──
	var placed_actors: Array = lvl.get("actors", [])
	var actor_inst_idx = 0
	for pa in placed_actors:
		var aid: int = pa.get("actor_id", 0)
		if aid >= actors.size():
			actor_inst_idx += 1
			continue
		var actor_type = actors[aid].get("type", "Drone")
		var aname = _safe_id(actors[aid].get("name", "Actor" + str(aid)))
		actor_inst_idx += 1
		var inst_name = aname + "_" + str(actor_inst_idx)
		var waypoints: Array = pa.get("path", [])
		if waypoints.size() >= 2 and actor_type in ["Drone", "Sentry", "Zombie", "Boss", "Bat", "Tank"]:
			code += "\n"
			code += "    ' Set waypoint path for " + inst_name + "\n"
			code += "    Dim " + inst_name + " As Node2D = GetNode(\"" + inst_name + "\")\n"
			for wp in waypoints:
				var wpx = wp["x"] if wp is Dictionary else wp.x
				var wpy = wp["y"] if wp is Dictionary else wp.y
				# Convert grid coords to pixel coords (center of cell)
				var px = wpx * CELL_PX + CELL_PX / 2
				var py = wpy * CELL_PX + CELL_PX / 2
				code += "    " + inst_name + ".AddPathPoint(" + _fstr(px) + ", " + _fstr(py) + ")\n"

	# ── Set waypoint paths for moving blocks ──
	var mblock_paths: Dictionary = lvl.get("block_paths", {})
	var mblock_idx = 0
	var mblock_grid_idx = 0
	for y in range(grid.size()):
		var row = grid[y]
		for x in range(row.size()):
			var cell = row[x]
			var block_id: int = 0
			if cell is Dictionary:
				block_id = cell.get("block_type", 0)
			elif cell is int or cell is float:
				block_id = int(cell)
			if block_id <= 0:
				continue
			mblock_grid_idx += 1
			var bp_key = str(x) + "," + str(y)
			if not mblock_paths.has(bp_key):
				continue
			var bp_arr: Array = mblock_paths[bp_key]
			if bp_arr.size() < 2:
				continue
			mblock_idx += 1
			var bnode_name = "Block_" + str(mblock_grid_idx)
			code += "\n"
			code += "    ' Moving block waypoints for " + bnode_name + "\n"
			code += "    " + bnode_name + " = GetNode(\"" + bnode_name + "\")\n"
			var bp_count = 0
			for wp in bp_arr:
				if bp_count >= 20:
					break
				var wpx = wp["x"] if wp is Dictionary else wp.x
				var wpy = wp["y"] if wp is Dictionary else wp.y
				var bpx = wpx * CELL_PX + CELL_PX / 2
				var bpy = wpy * CELL_PX + CELL_PX / 2
				code += "    " + bnode_name + "_PathX(" + str(bp_count) + ") = " + _fstr(bpx) + "\n"
				code += "    " + bnode_name + "_PathY(" + str(bp_count) + ") = " + _fstr(bpy) + "\n"
				bp_count += 1
			code += "    " + bnode_name + "_PathCount = " + str(bp_count) + "\n"

	code += "End Sub\n\n"

	code += "' Player touched a teleport block — go to next level\n"
	code += "Sub Teleport_BodyEntered(body As Node2D)\n"
	code += "    If body.IsInGroup(\"player\") Then\n"
	code += "        LevelComplete()\n"
	code += "    End If\n"
	code += "End Sub\n\n"

	code += "' Player touched a deadly block — take damage\n"
	code += "Sub Deadly_BodyEntered(body As Node2D)\n"
	code += "    If body.IsInGroup(\"player\") And body.HasMethod(\"TakeDamage\") Then\n"
	code += "        body.TakeDamage(" + str(settings.get("deadly_damage", 25)) + ")\n"
	code += "    End If\n"
	code += "End Sub\n\n"

	code += "' Player touched a switch/collectible block — award points and remove\n"
	code += "Sub Switch_BodyEntered(body As Node2D)\n"
	code += "    If body.IsInGroup(\"player\") Then\n"
	code += "        ' Award score to game controller\n"
	code += "        Dim main As Node2D = GetTree().CurrentScene\n"
	code += "        If main <> Nothing And main.HasMethod(\"AddScore\") Then\n"
	code += "            main.AddScore(50)\n"
	code += "        End If\n"
	code += "        ' Remove the switch block (collect it!)\n"
	code += "        Dim parent As Node = body\n"
	code += "        ' The area's parent is the StaticBody2D block\n"
	code += "        ' We get the block from the signal sender\n"
	code += "    End If\n"
	code += "End Sub\n\n"

	# ── Moving block physics (level-side _PhysicsProcess) ──
	var mblock_paths2: Dictionary = lvl.get("block_paths", {})
	var has_moving_blocks = false
	# Rebuild moving block list (same order as tscn block numbering)
	var mblock_list: Array = []
	var mblock_grid_idx2 = 0
	for y2 in range(grid.size()):
		var row2 = grid[y2]
		for x2 in range(row2.size()):
			var cell2 = row2[x2]
			var block_id2: int = 0
			if cell2 is Dictionary:
				block_id2 = cell2.get("block_type", 0)
			elif cell2 is int or cell2 is float:
				block_id2 = int(cell2)
			if block_id2 <= 0:
				continue
			mblock_grid_idx2 += 1
			var bp_key2 = str(x2) + "," + str(y2)
			if mblock_paths2.has(bp_key2) and mblock_paths2[bp_key2].size() >= 2:
				mblock_list.append("Block_" + str(mblock_grid_idx2))
				has_moving_blocks = true

	if has_moving_blocks:
		code += "' Moving platform physics\n"
		code += "Sub _PhysicsProcess(delta As Single)\n"
		code += "    Dim speed As Single = 60.0\n"
		for bnode_name in mblock_list:
			code += "    If " + bnode_name + "_PathCount >= 2 Then\n"
			code += "        Dim " + bnode_name + "_tx As Single = " + bnode_name + "_PathX(" + bnode_name + "_PathIndex)\n"
			code += "        Dim " + bnode_name + "_ty As Single = " + bnode_name + "_PathY(" + bnode_name + "_PathIndex)\n"
			code += "        Dim " + bnode_name + "_dx As Single = " + bnode_name + "_tx - " + bnode_name + ".Position.X\n"
			code += "        Dim " + bnode_name + "_dy As Single = " + bnode_name + "_ty - " + bnode_name + ".Position.Y\n"
			code += "        Dim " + bnode_name + "_dist As Single = Sqr(" + bnode_name + "_dx * " + bnode_name + "_dx + " + bnode_name + "_dy * " + bnode_name + "_dy)\n"
			code += "        If " + bnode_name + "_dist > 2.0 Then\n"
			code += "            Dim " + bnode_name + "_mx As Single = (" + bnode_name + "_dx / " + bnode_name + "_dist) * speed * delta\n"
			code += "            Dim " + bnode_name + "_my As Single = (" + bnode_name + "_dy / " + bnode_name + "_dist) * speed * delta\n"
			code += "            " + bnode_name + ".Position = Vector2(" + bnode_name + ".Position.X + " + bnode_name + "_mx, " + bnode_name + ".Position.Y + " + bnode_name + "_my)\n"
			code += "        Else\n"
			code += "            " + bnode_name + "_PathIndex = (" + bnode_name + "_PathIndex + 1) Mod " + bnode_name + "_PathCount\n"
			code += "        End If\n"
			code += "    End If\n"
		code += "End Sub\n\n"

	code += "' Called when the player reaches the exit / teleporter\n"
	code += "Sub LevelComplete()\n"
	if next_level_path != "":
		code += "    ' Tell the game controller to advance levels\n"
		code += "    Dim main As Node2D = GetTree().CurrentScene\n"
		code += "    If main <> Nothing And main.HasMethod(\"NextLevel\") Then\n"
		code += "        main.NextLevel()\n"
		code += "    End If\n"
	else:
		code += "    ' Last level — victory!\n"
		code += "    Dim main As Node2D = GetTree().CurrentScene\n"
		code += "    If main <> Nothing And main.HasMethod(\"NextLevel\") Then\n"
		code += "        main.NextLevel()\n"
		code += "    End If\n"
	code += "End Sub\n\n"

	# ── User code section — preserved across rebuilds ──
	code += "' ─── Your Custom Code ─────────────────────\n"
	code += "' Add your own Subs and functions below.\n"
	code += "' This section is preserved when you rebuild from AGCK.\n"
	code += _user_code_block(lvl_name + "_custom", "' (add your code here)\n", preserved)

	_write_file(path, code)


# ═══════════════════════════════════════════════════════════════
# MAIN SCENE + CONTROLLER
# ═══════════════════════════════════════════════════════════════

func _generate_main_tscn(path: String, settings: Dictionary, level_count: int, level_indices: Array[int], output_dir: String, sounds: Array, shader_layers: Array = []) -> void:
	var screen_w: int = settings.get("screen_width", 640)
	var screen_h: int = settings.get("screen_height", 480)
	var vg_path = path.replace(".tscn", ".vg")

	# Count ext resources: 1=script, 2+=level scenes, then sound files
	var ext_id := 2
	var first_level_ext_id := -1
	var level_ext_ids: Dictionary = {}  # level_index -> ext_id
	for li in level_indices:
		level_ext_ids[li] = ext_id
		if first_level_ext_id < 0:
			first_level_ext_id = ext_id
		ext_id += 1

	# Collect sound WAV ext resources
	var sound_ext_ids: Array[int] = []
	var sound_names: Array[String] = []
	var sound_exts: Array[String] = []  # file extension per sound
	for si in range(sounds.size()):
		var snd = sounds[si]
		var custom_wav: String = snd.get("custom_wav", "")
		var has_content: bool = not custom_wav.is_empty()
		if not has_content:
			for n in snd.get("voice1_notes", []):
				if n > 0:
					has_content = true
					break
		if not has_content:
			for n in snd.get("voice2_notes", []):
				if n > 0:
					has_content = true
					break
		if has_content:
			sound_ext_ids.append(ext_id)
			sound_names.append(_safe_id(snd.get("name", "Sound_" + str(si + 1))))
			var ext := "wav"
			if not custom_wav.is_empty():
				var cext = custom_wav.get_extension().to_lower()
				if not cext.is_empty():
					ext = cext
			sound_exts.append(ext)
			ext_id += 1
		else:
			sound_ext_ids.append(-1)
			sound_names.append("")
			sound_exts.append("")

	# Splash image ext resource (if enabled with custom image)
	var splash_ext_id := -1
	var splash_enabled: bool = settings.get("splash_enabled", false)
	var splash_image: String = settings.get("splash_image", "")
	if splash_enabled and not splash_image.is_empty():
		splash_ext_id = ext_id
		ext_id += 1

	var tscn = ""

	# Fullscreen runtime helper. We can't rely on the project.godot
	# window/size/mode entry alone because the editor's play-scene runner
	# launches the scene under the host editor's display settings, ignoring
	# the generated project.godot. Forcing the mode at _ready() works for
	# both editor previews and standalone exported builds. The helper also
	# binds F11 to toggle fullscreen at runtime so testers aren't trapped
	# in fullscreen with no exit (Esc alone doesn't exit Exclusive mode).
	var want_fullscreen: bool = bool(settings.get("fullscreen", false))
	# Always inject the helper — the F11 toggle is useful even when the
	# game starts windowed. The initial mode is set from `want_fullscreen`.
	var fs_extra_steps: int = 1

	# ── Count shader sub_resources so load_steps is correct ──
	var shader_sub_count := 0
	for si in range(shader_layers.size()):
		var sd = shader_layers[si]
		if not sd.get("enabled", true):
			continue
		var sname_check = sd.get("shader_name", "")
		if SHADER_CODES.has(sname_check) and not SHADER_CODES[sname_check].is_empty():
			shader_sub_count += 2   # Shader + ShaderMaterial per effect

	tscn += '[gd_scene load_steps=' + str(ext_id + shader_sub_count + fs_extra_steps) + ' format=3]\n\n'
	tscn += '[ext_resource type="Script" path="' + vg_path + '" id="1"]\n'

	# Level scene ext_resources
	for li in level_indices:
		var lvl_name = "Level_" + str(li + 1).pad_zeros(2)
		var lvl_path = "levels/" + lvl_name + ".tscn"
		tscn += '[ext_resource type="PackedScene" path="' + lvl_path + '" id="' + str(level_ext_ids[li]) + '"]\n'

	# Sound WAV ext_resources
	for si in range(sound_ext_ids.size()):
		if sound_ext_ids[si] >= 0:
			var snd_ext: String = sound_exts[si] if si < sound_exts.size() else "wav"
			tscn += '[ext_resource type="AudioStream" path="sounds/sfx_' + sound_names[si].to_lower() + '.' + snd_ext + '" id="' + str(sound_ext_ids[si]) + '"]\n'

	# Splash image ext_resource
	if splash_ext_id >= 0:
		tscn += '[ext_resource type="Texture2D" path="' + splash_image + '" id="' + str(splash_ext_id) + '"]\n'

	# ── Shader sub_resources (MUST come before [node] entries) ──
	var _shader_metas: Array = []   # collect {safe_name, sub_shader_id, sub_mat_id} for node pass
	var _s_idx := 0
	for si in range(shader_layers.size()):
		var sd = shader_layers[si]
		if not sd.get("enabled", true):
			continue
		var sname_s = sd.get("shader_name", "")
		var shader_code = SHADER_CODES.get(sname_s, "")
		if shader_code.is_empty():
			continue
		var safe_name = _safe_id(sname_s)
		var sub_shader_id = "shader_fx_" + str(_s_idx)
		var sub_mat_id = "shader_mat_" + str(_s_idx)

		tscn += '\n[sub_resource type="Shader" id="' + sub_shader_id + '"]\n'
		tscn += 'code = "' + shader_code.replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t") + '"\n'
		tscn += '\n[sub_resource type="ShaderMaterial" id="' + sub_mat_id + '"]\n'
		tscn += 'shader = SubResource("' + sub_shader_id + '")\n'
		# Set shader parameters (ensure floats keep .0 for .tscn format)
		var props = sd.get("properties", {})
		for pkey in props:
			var pval = props[pkey]
			var pstr: String
			if pval is float or pval is int:
				# Godot .tscn needs explicit float format for shader uniforms
				var fv: float = float(pval)
				if fv == int(fv):
					pstr = str(int(fv)) + ".0"
				else:
					pstr = str(fv)
			else:
				pstr = str(pval)
			tscn += 'shader_parameter/' + pkey + ' = ' + pstr + '\n'

		_shader_metas.append({
			"safe_name": safe_name,
			"sub_mat_id": sub_mat_id,
			"shader_data": sd,
			"idx": _s_idx,
		})
		_s_idx += 1

	tscn += '\n'

	# Fullscreen helper sub_resource. Tiny GDScript attached to a hidden
	# CanvasLayer child that (a) sets the initial window mode at _ready()
	# if the Fullscreen toggle is on, (b) toggles fullscreen on F11 every
	# launch, and (c) optionally shows an FPS counter in the top-right
	# corner when settings.show_fps is true. F3 toggles it at runtime.
	# Works in editor preview AND exported builds.
	var fs_initial_mode: String = "DisplayServer.WINDOW_MODE_FULLSCREEN" if want_fullscreen else "DisplayServer.WINDOW_MODE_WINDOWED"
	var fps_initial: String = "true" if bool(settings.get("show_fps", false)) else "false"
	tscn += '[sub_resource type="GDScript" id="fs_helper"]\n'
	var fs_src := "extends CanvasLayer\\n"
	fs_src += "var _fps_label: Label\\n"
	fs_src += "func _ready():\\n"
	fs_src += "\\tlayer = 100\\n"
	fs_src += "\\tDisplayServer.window_set_mode(" + fs_initial_mode + ")\\n"
	fs_src += "\\t_fps_label = Label.new()\\n"
	fs_src += "\\t_fps_label.text = \\\"FPS: --\\\"\\n"
	fs_src += "\\t_fps_label.add_theme_font_size_override(\\\"font_size\\\", 16)\\n"
	fs_src += "\\t_fps_label.add_theme_color_override(\\\"font_color\\\", Color(1, 1, 0))\\n"
	fs_src += "\\t_fps_label.add_theme_color_override(\\\"font_outline_color\\\", Color(0, 0, 0))\\n"
	fs_src += "\\t_fps_label.add_theme_constant_override(\\\"outline_size\\\", 4)\\n"
	fs_src += "\\t_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)\\n"
	fs_src += "\\t_fps_label.position = Vector2(-110, 6)\\n"
	fs_src += "\\t_fps_label.size = Vector2(100, 24)\\n"
	fs_src += "\\t_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT\\n"
	fs_src += "\\t_fps_label.visible = " + fps_initial + "\\n"
	fs_src += "\\tadd_child(_fps_label)\\n"
	fs_src += "func _process(_delta):\\n"
	fs_src += "\\tif _fps_label and _fps_label.visible:\\n"
	fs_src += "\\t\\t_fps_label.text = \\\"FPS: \\\" + str(Engine.get_frames_per_second())\\n"
	fs_src += "func _unhandled_input(event):\\n"
	fs_src += "\\tif event is InputEventKey and event.pressed and not event.echo:\\n"
	fs_src += "\\t\\tif event.keycode == KEY_F11:\\n"
	fs_src += "\\t\\t\\tvar m = DisplayServer.window_get_mode()\\n"
	fs_src += "\\t\\t\\tif m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:\\n"
	fs_src += "\\t\\t\\t\\tDisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)\\n"
	fs_src += "\\t\\t\\telse:\\n"
	fs_src += "\\t\\t\\t\\tDisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)\\n"
	fs_src += "\\t\\t\\tget_viewport().set_input_as_handled()\\n"
	fs_src += "\\t\\telif event.keycode == KEY_F3 and _fps_label:\\n"
	fs_src += "\\t\\t\\t_fps_label.visible = not _fps_label.visible\\n"
	fs_src += "\\t\\t\\tget_viewport().set_input_as_handled()\\n"
	tscn += 'script/source = "' + fs_src + '"\n\n'

	# Root Node2D (game controller)
	tscn += '[node name="Main" type="Node2D"]\n'
	tscn += 'script = ExtResource("1")\n\n'

	tscn += '[node name="_FullscreenInit" type="CanvasLayer" parent="."]\n'
	tscn += 'script = SubResource("fs_helper")\n\n'

	# Background color fill (behind everything)
	var bg_hex: String = settings.get("bg_color", "1a1a2e")
	tscn += '[node name="Background" type="ColorRect" parent="."]\n'
	tscn += 'z_index = -100\n'
	tscn += 'anchors_preset = 15\n'
	tscn += 'anchor_right = 1.0\n'
	tscn += 'anchor_bottom = 1.0\n'
	tscn += 'offset_right = ' + _fstr(GRID_W * CELL_PX) + '\n'
	tscn += 'offset_bottom = ' + _fstr(GRID_H * CELL_PX) + '\n'
	tscn += 'color = ' + _hex_to_tscn_color(bg_hex) + '\n\n'

	# LevelContainer — levels are instanced here
	tscn += '[node name="LevelContainer" type="Node2D" parent="."]\n\n'

	# Instance the starting level (respects start_level setting)
	var start_lvl_idx: int = clampi(settings.get("start_level", 1) - 1, 0, level_indices.size() - 1)
	var start_lvl_actual: int = level_indices[start_lvl_idx] if start_lvl_idx < level_indices.size() else 0
	var start_ext_id: int = level_ext_ids.get(start_lvl_actual, first_level_ext_id)
	if start_ext_id >= 0:
		tscn += '[node name="CurrentLevel" parent="LevelContainer" instance=ExtResource("' + str(start_ext_id) + '")]\n\n'

	# HUD CanvasLayer
	tscn += '[node name="HUD" type="CanvasLayer" parent="."]\n'
	tscn += 'layer = 10\n\n'

	# Score label
	tscn += '[node name="ScoreLabel" type="Label" parent="HUD"]\n'
	tscn += 'offset_left = 10.0\n'
	tscn += 'offset_top = 10.0\n'
	tscn += 'offset_right = 200.0\n'
	tscn += 'offset_bottom = 30.0\n'
	tscn += 'text = "Score: 0"\n\n'

	# Lives label
	tscn += '[node name="LivesLabel" type="Label" parent="HUD"]\n'
	tscn += 'offset_left = 10.0\n'
	tscn += 'offset_top = 32.0\n'
	tscn += 'offset_right = 200.0\n'
	tscn += 'offset_bottom = 52.0\n'
	tscn += 'text = "Lives: 3"\n\n'

	# Level name label
	tscn += '[node name="LevelLabel" type="Label" parent="HUD"]\n'
	tscn += 'anchors_preset = 1\n'
	tscn += 'anchor_left = 1.0\n'
	tscn += 'anchor_right = 1.0\n'
	tscn += 'offset_left = -200.0\n'
	tscn += 'offset_top = 10.0\n'
	tscn += 'offset_right = -10.0\n'
	tscn += 'offset_bottom = 30.0\n'
	tscn += 'horizontal_alignment = 2\n'
	tscn += 'text = "Level 1"\n\n'

	# ── Game Over Overlay (default, hidden) ──
	var go_style: String = settings.get("game_over_style", "Default")
	if go_style == "Default":
		tscn += '[node name="GameOverOverlay" type="CanvasLayer" parent="."]\n'
		tscn += 'layer = 50\n'
		tscn += 'visible = false\n'
		tscn += 'process_mode = 3\n\n'
		tscn += '[node name="Dim" type="ColorRect" parent="GameOverOverlay"]\n'
		tscn += 'anchors_preset = 15\n'
		tscn += 'anchor_right = 1.0\n'
		tscn += 'anchor_bottom = 1.0\n'
		tscn += 'grow_horizontal = 2\n'
		tscn += 'grow_vertical = 2\n'
		tscn += 'color = Color(0, 0, 0, 0.7)\n'
		tscn += 'mouse_filter = 2\n\n'
		# "GAME OVER" title
		tscn += '[node name="Title" type="Label" parent="GameOverOverlay"]\n'
		tscn += 'anchors_preset = 8\n'
		tscn += 'anchor_left = 0.5\n'
		tscn += 'anchor_top = 0.35\n'
		tscn += 'anchor_right = 0.5\n'
		tscn += 'anchor_bottom = 0.35\n'
		tscn += 'offset_left = -200.0\n'
		tscn += 'offset_top = -30.0\n'
		tscn += 'offset_right = 200.0\n'
		tscn += 'offset_bottom = 30.0\n'
		tscn += 'horizontal_alignment = 1\n'
		tscn += 'vertical_alignment = 1\n'
		tscn += 'text = "GAME OVER"\n'
		tscn += 'theme_override_font_sizes/font_size = 48\n\n'
		# Restart button
		tscn += '[node name="RestartBtn" type="Button" parent="GameOverOverlay"]\n'
		tscn += 'anchors_preset = 8\n'
		tscn += 'anchor_left = 0.5\n'
		tscn += 'anchor_top = 0.55\n'
		tscn += 'anchor_right = 0.5\n'
		tscn += 'anchor_bottom = 0.55\n'
		tscn += 'offset_left = -80.0\n'
		tscn += 'offset_top = -20.0\n'
		tscn += 'offset_right = 80.0\n'
		tscn += 'offset_bottom = 20.0\n'
		tscn += 'text = "RESTART"\n\n'

	# ── Main Menu Overlay (default, shown on start) ──
	var menu_style: String = settings.get("game_menu_style", "Default")
	if menu_style == "Default":
		var game_title: String = settings.get("game_title", "AGCK Game")
		tscn += '[node name="MainMenuOverlay" type="CanvasLayer" parent="."]\n'
		tscn += 'layer = 60\n'
		tscn += 'process_mode = 3\n\n'
		tscn += '[node name="Dim" type="ColorRect" parent="MainMenuOverlay"]\n'
		tscn += 'anchors_preset = 15\n'
		tscn += 'anchor_right = 1.0\n'
		tscn += 'anchor_bottom = 1.0\n'
		tscn += 'grow_horizontal = 2\n'
		tscn += 'grow_vertical = 2\n'
		tscn += 'color = Color(0.08, 0.08, 0.12, 0.95)\n\n'
		# Game title
		tscn += '[node name="Title" type="Label" parent="MainMenuOverlay"]\n'
		tscn += 'anchors_preset = 8\n'
		tscn += 'anchor_left = 0.5\n'
		tscn += 'anchor_top = 0.25\n'
		tscn += 'anchor_right = 0.5\n'
		tscn += 'anchor_bottom = 0.25\n'
		tscn += 'offset_left = -250.0\n'
		tscn += 'offset_top = -30.0\n'
		tscn += 'offset_right = 250.0\n'
		tscn += 'offset_bottom = 30.0\n'
		tscn += 'horizontal_alignment = 1\n'
		tscn += 'vertical_alignment = 1\n'
		tscn += 'text = "' + game_title.replace('"', '\\"') + '"\n'
		tscn += 'theme_override_font_sizes/font_size = 42\n\n'
		# PLAY button
		tscn += '[node name="PlayBtn" type="Button" parent="MainMenuOverlay"]\n'
		tscn += 'anchors_preset = 8\n'
		tscn += 'anchor_left = 0.5\n'
		tscn += 'anchor_top = 0.5\n'
		tscn += 'anchor_right = 0.5\n'
		tscn += 'anchor_bottom = 0.5\n'
		tscn += 'offset_left = -100.0\n'
		tscn += 'offset_top = -25.0\n'
		tscn += 'offset_right = 100.0\n'
		tscn += 'offset_bottom = 25.0\n'
		tscn += 'text = "PLAY"\n'
		tscn += 'theme_override_font_sizes/font_size = 28\n\n'
		# EXIT button
		tscn += '[node name="ExitBtn" type="Button" parent="MainMenuOverlay"]\n'
		tscn += 'anchors_preset = 8\n'
		tscn += 'anchor_left = 0.5\n'
		tscn += 'anchor_top = 0.65\n'
		tscn += 'anchor_right = 0.5\n'
		tscn += 'anchor_bottom = 0.65\n'
		tscn += 'offset_left = -100.0\n'
		tscn += 'offset_top = -20.0\n'
		tscn += 'offset_right = 100.0\n'
		tscn += 'offset_bottom = 20.0\n'
		tscn += 'text = "EXIT"\n'
		tscn += 'theme_override_font_sizes/font_size = 20\n\n'

	# ── Splash Screen Overlay (layer 70, above main menu) ──
	if splash_enabled:
		tscn += '[node name="SplashOverlay" type="CanvasLayer" parent="."]\n'
		tscn += 'layer = 70\n'
		tscn += 'process_mode = 3\n\n'
		# Splash dismiss timer — native Godot Timer (NOT VGTimer alias)
		# autostart=true so it fires even during pause (process_mode=3)
		var splash_dur_tscn: float = settings.get("splash_duration", 3.0)
		tscn += '[node name="SplashTimer" type="Timer" parent="SplashOverlay"]\n'
		tscn += 'wait_time = ' + str(splash_dur_tscn) + '\n'
		tscn += 'one_shot = true\n'
		tscn += 'process_mode = 3\n'
		tscn += 'autostart = true\n\n'
		# Full-screen dark background
		tscn += '[node name="Bg" type="ColorRect" parent="SplashOverlay"]\n'
		tscn += 'anchors_preset = 15\n'
		tscn += 'anchor_right = 1.0\n'
		tscn += 'anchor_bottom = 1.0\n'
		tscn += 'grow_horizontal = 2\n'
		tscn += 'grow_vertical = 2\n'
		tscn += 'color = Color(0.05, 0.05, 0.08, 1.0)\n\n'
		if splash_ext_id >= 0:
			# Custom splash image — centered TextureRect
			tscn += '[node name="SplashImage" type="TextureRect" parent="SplashOverlay"]\n'
			tscn += 'anchors_preset = 8\n'
			tscn += 'anchor_left = 0.5\n'
			tscn += 'anchor_top = 0.5\n'
			tscn += 'anchor_right = 0.5\n'
			tscn += 'anchor_bottom = 0.5\n'
			tscn += 'offset_left = -200.0\n'
			tscn += 'offset_top = -150.0\n'
			tscn += 'offset_right = 200.0\n'
			tscn += 'offset_bottom = 150.0\n'
			tscn += 'texture = ExtResource("' + str(splash_ext_id) + '")\n'
			tscn += 'expand_mode = 1\n'
			tscn += 'stretch_mode = 5\n\n'
		else:
			# Default splash — game title text
			var splash_title: String = settings.get("game_title", "AGCK Game")
			tscn += '[node name="SplashTitle" type="Label" parent="SplashOverlay"]\n'
			tscn += 'anchors_preset = 8\n'
			tscn += 'anchor_left = 0.5\n'
			tscn += 'anchor_top = 0.4\n'
			tscn += 'anchor_right = 0.5\n'
			tscn += 'anchor_bottom = 0.4\n'
			tscn += 'offset_left = -300.0\n'
			tscn += 'offset_top = -30.0\n'
			tscn += 'offset_right = 300.0\n'
			tscn += 'offset_bottom = 30.0\n'
			tscn += 'horizontal_alignment = 1\n'
			tscn += 'vertical_alignment = 1\n'
			tscn += 'text = "' + splash_title.replace('"', '\\"') + '"\n'
			tscn += 'theme_override_font_sizes/font_size = 52\n\n'
			tscn += '[node name="Subtitle" type="Label" parent="SplashOverlay"]\n'
			tscn += 'anchors_preset = 8\n'
			tscn += 'anchor_left = 0.5\n'
			tscn += 'anchor_top = 0.55\n'
			tscn += 'anchor_right = 0.5\n'
			tscn += 'anchor_bottom = 0.55\n'
			tscn += 'offset_left = -200.0\n'
			tscn += 'offset_top = -12.0\n'
			tscn += 'offset_right = 200.0\n'
			tscn += 'offset_bottom = 12.0\n'
			tscn += 'horizontal_alignment = 1\n'
			tscn += 'vertical_alignment = 1\n'
			tscn += 'text = "Made with AGCK"\n'
			tscn += 'theme_override_font_sizes/font_size = 16\n'
			tscn += 'theme_override_colors/font_color = Color(0.6, 0.6, 0.7, 0.8)\n\n'

	# Sound players — apply sfx_volume from game settings
	var sfx_vol_pct: float = float(settings.get("sfx_volume", 100))
	var sfx_vol_db: float = -60.0 if sfx_vol_pct <= 0 else (20.0 * log(sfx_vol_pct / 100.0) / log(10.0))
	for si in range(sound_ext_ids.size()):
		if sound_ext_ids[si] >= 0:
			tscn += '[node name="SFX_' + sound_names[si] + '" type="AudioStreamPlayer" parent="."]\n'
			tscn += 'stream = ExtResource("' + str(sound_ext_ids[si]) + '")\n'
			tscn += 'volume_db = ' + str(snapped(sfx_vol_db, 0.1)) + '\n\n'

	# Shader effect CanvasLayer + ColorRect nodes (sub_resources already emitted above)
	for sm in _shader_metas:
		var safe_name = sm["safe_name"]
		var sub_mat_id = sm["sub_mat_id"]
		var sd = sm["shader_data"]
		var sidx = sm["idx"]

		# CanvasLayer above everything
		tscn += '[node name="ShaderFX_' + safe_name + '_' + str(sidx) + '" type="CanvasLayer" parent="."]\n'
		tscn += 'layer = ' + str(100 + sidx) + '\n\n'

		# ColorRect — full screen or region
		var region_mode = sd.get("region_mode", "full_screen")
		var fx_parent = "ShaderFX_" + safe_name + "_" + str(sidx)
		tscn += '[node name="EffectRect" type="ColorRect" parent="' + fx_parent + '"]\n'
		tscn += 'material = SubResource("' + sub_mat_id + '")\n'
		tscn += 'mouse_filter = 2\n'
		if region_mode == "full_screen":
			tscn += 'anchors_preset = 15\n'
			tscn += 'anchor_right = 1.0\n'
			tscn += 'anchor_bottom = 1.0\n'
			tscn += 'grow_horizontal = 2\n'
			tscn += 'grow_vertical = 2\n'
		else:
			var rx = sd.get("region_x", 0)
			var ry = sd.get("region_y", 0)
			var rw = sd.get("region_w", 640)
			var rh = sd.get("region_h", 480)
			tscn += 'offset_left = ' + _fstr(rx) + '\n'
			tscn += 'offset_top = ' + _fstr(ry) + '\n'
			tscn += 'offset_right = ' + _fstr(rx + rw) + '\n'
			tscn += 'offset_bottom = ' + _fstr(ry + rh) + '\n'
		tscn += '\n'

	_write_file(path, tscn)


func _generate_main_vg(path: String, settings: Dictionary, actors: Array, level_count: int, level_indices: Array[int], output_dir: String, sounds: Array, levels: Array = []) -> void:
	# Preserve any user code from the previous build
	var preserved := _extract_user_code(path)

	var title: String = settings.get("game_title", "AGCK Game")
	var lives: int = settings.get("lives", 3)
	var gravity: int = settings.get("gravity", 980)
	var show_score: bool = settings.get("show_score", true)
	var show_lives: bool = settings.get("show_lives", true)

	# Build level paths array for the generated code
	var level_paths: Array[String] = []
	for li in level_indices:
		level_paths.append(output_dir + "levels/Level_" + str(li + 1).pad_zeros(2) + ".tscn")

	# Build sound names for generated code
	var valid_sound_names: Array[String] = []
	for si in range(sounds.size()):
		var snd = sounds[si]
		var has_content: bool = not snd.get("custom_wav", "").is_empty()
		if not has_content:
			for n in snd.get("voice1_notes", []):
				if n > 0:
					has_content = true
					break
		if not has_content:
			for n in snd.get("voice2_notes", []):
				if n > 0:
					has_content = true
					break
		if has_content:
			valid_sound_names.append(_safe_id(snd.get("name", "Sound_" + str(si + 1))))

	var code = ""
	code += "' Main.vg — Game Controller\n"
	code += "' Generated by AGCK — customize freely!\n"
	code += "' This is the main entry point for your game.\n"
	code += "Option Explicit\n\n"

	code += "' ─── Game State ───\n"
	code += "Dim GameTitle As String\n"
	code += "Dim Score As Integer\n"
	code += "Dim Lives As Integer\n"
	code += "Dim CurrentLevel As Integer\n"
	code += "Dim TotalLevels As Integer\n"
	code += "Dim IsGameOver As Boolean\n\n"

	# Level paths array
	code += "' ─── Level Paths (auto-generated) ───\n"
	code += "Dim LevelPaths As Array\n"
	code += "Dim DeathActions As Array\n"
	code += "Dim DeathTargets As Array\n\n"

	var start_level: int = clampi(settings.get("start_level", 1), 1, level_count)

	code += "Sub _Ready()\n"
	code += "    GameTitle = \"" + title + "\"\n"
	code += "    Score = 0\n"
	code += "    Lives = " + str(lives) + "\n"
	code += "    CurrentLevel = " + str(start_level) + "\n"
	code += "    TotalLevels = " + str(level_count) + "\n"
	code += "    IsGameOver = False\n"
	code += "\n"
	code += "    ' Initialize level paths\n"
	# Build Array(...) literal with all level paths
	var paths_args := ""
	for i in range(level_paths.size()):
		if i > 0:
			paths_args += ", "
		paths_args += "\"" + level_paths[i] + "\""
	code += "    LevelPaths = Array(" + paths_args + ")\n"

	# Death-action arrays — one entry per level matching LevelPaths order
	# Actions: 0=Restart Level, 1=Go To Level, 2=Lose Item, 3=End Game
	var da_args := ""
	var dt_args := ""
	for li in range(level_indices.size()):
		if li > 0:
			da_args += ", "
			dt_args += ", "
		var idx: int = level_indices[li]
		var da_str: String = "Restart Level"
		var dt_val: int = 1
		if idx >= 0 and idx < levels.size():
			da_str = levels[idx].get("death_action", "Restart Level")
			dt_val = levels[idx].get("death_action_target", 1)
		var da_code: int = 0
		match da_str:
			"Restart Level": da_code = 0
			"Go To Level":   da_code = 1
			"Lose Item":     da_code = 2
			"End Game":      da_code = 3
		da_args += str(da_code)
		dt_args += str(dt_val)
	code += "    DeathActions = Array(" + da_args + ")\n"
	code += "    DeathTargets = Array(" + dt_args + ")\n"
	code += "\n"
	code += "    ' Update HUD\n"
	if show_score:
		code += "    GetNode(\"HUD/ScoreLabel\").Text = \"Score: \" & Str(Score)\n"
	if show_lives:
		code += "    GetNode(\"HUD/LivesLabel\").Text = \"Lives: \" & Str(Lives)\n"
	code += "    GetNode(\"HUD/LevelLabel\").Text = \"Level \" & Str(CurrentLevel)\n"

	# Wire button signals for default game over and main menu
	var go_style: String = settings.get("game_over_style", "Default")
	var menu_style: String = settings.get("game_menu_style", "Default")
	if go_style == "Default":
		code += "    ' Wire Game Over restart button\n"
		code += "    Connect(GetNode(\"GameOverOverlay/RestartBtn\"), \"pressed\", \"RestartBtn_Click\")\n"
	if menu_style == "Default":
		code += "    ' Wire Main Menu buttons\n"
		code += "    Connect(GetNode(\"MainMenuOverlay/PlayBtn\"), \"pressed\", \"PlayBtn_Click\")\n"
		code += "    Connect(GetNode(\"MainMenuOverlay/ExitBtn\"), \"pressed\", \"ExitBtn_Click\")\n"
		code += "    ' Pause the game tree while menu is showing\n"
		code += "    GetTree().Paused = True\n"
	elif menu_style == "None":
		code += "    ' No main menu — start immediately\n"

	# ── Splash Screen ──
	var splash_enabled: bool = settings.get("splash_enabled", false)
	if splash_enabled:
		code += "\n"
		code += "    ' Show splash screen first, then reveal menu / start game\n"
		code += "    GetTree().Paused = True\n"
		if menu_style == "Default":
			code += "    GetNode(\"MainMenuOverlay\").visible = False\n"
		code += "    GetNode(\"SplashOverlay\").visible = True\n"
		code += "    ' Wire the splash dismiss timer (auto-started in .tscn)\n"
		code += "    Connect(GetNode(\"SplashOverlay/SplashTimer\"), \"timeout\", \"SplashTimer_Timeout\")\n"

	code += "End Sub\n\n"

	code += "' ─── Score System ───\n"
	code += "Sub AddScore(points As Integer)\n"
	code += "    Score = Score + points\n"
	if show_score:
		code += "    GetNode(\"HUD/ScoreLabel\").Text = \"Score: \" & Str(Score)\n"
	code += "End Sub\n\n"

	code += "' ─── Lives System ───\n"
	code += "Sub LoseLife()\n"
	code += "    Lives = Lives - 1\n"
	if show_lives:
		code += "    GetNode(\"HUD/LivesLabel\").Text = \"Lives: \" & Str(Lives)\n"
	code += "\n"
	code += "    ' Trigger death animation on hero\n"
	code += "    TriggerHeroAnim(\"death\")\n"
	code += "\n"
	code += "    If Lives <= 0 Then\n"
	code += "        GameOver()\n"
	code += "        Exit Sub\n"
	code += "    End If\n"
	code += "\n"
	code += "    ' Per-level death action (0=Restart, 1=GoToLevel, 2=LoseItem, 3=EndGame)\n"
	code += "    Dim action As Integer = DeathActions(CurrentLevel - 1)\n"
	code += "    Select Case action\n"
	code += "        Case 0  ' Restart Level\n"
	code += "            Dim container As Node2D = GetNode(\"LevelContainer\")\n"
	code += "            Dim child As Variant\n"
	code += "            For Each child In container.GetChildren()\n"
	code += "                container.RemoveChild(child)\n"
	code += "                child.QueueFree()\n"
	code += "            Next\n"
	code += "            Dim scene As PackedScene = Load(LevelPaths(CurrentLevel - 1))\n"
	code += "            If scene <> Nothing Then\n"
	code += "                Dim lvl As Node2D = scene.Instantiate()\n"
	code += "                container.AddChild(lvl)\n"
	code += "            End If\n"
	code += "        Case 1  ' Go To Level\n"
	code += "            GoToLevel(DeathTargets(CurrentLevel - 1))\n"
	code += "        Case 2  ' Lose Item (inventory placeholder)\n"
	code += "            ' TODO: Inventory system not yet implemented\n"
	code += "        Case 3  ' End Game\n"
	code += "            GameOver()\n"
	code += "    End Select\n"
	code += "End Sub\n\n"

	code += "' ─── Game Over ───\n"
	code += "Sub GameOver()\n"
	code += "    IsGameOver = True\n"
	var go_style2: String = settings.get("game_over_style", "Default")
	if go_style2 == "Default":
		code += "    ' Show the game over overlay\n"
		code += "    GetNode(\"GameOverOverlay\").visible = True\n"
		code += "    GetTree().Paused = True\n"
	else:
		# Custom — user provides their own scene/handling
		var custom_go: String = settings.get("game_over_custom_scene", "")
		if custom_go.is_empty():
			code += "    GetTree().ReloadCurrentScene()\n"
		else:
			code += "    GetTree().ChangeSceneToFile(\"" + custom_go + "\")\n"
	code += "End Sub\n\n"

	# ── Restart button handler ──
	if go_style2 == "Default":
		code += "Sub RestartBtn_Click()\n"
		code += "    GetTree().Paused = False\n"
		code += "    GetTree().ReloadCurrentScene()\n"
		code += "End Sub\n\n"

	# ── Main Menu handlers ──
	var menu_style2: String = settings.get("game_menu_style", "Default")
	if menu_style2 == "Default":
		code += "' ─── Main Menu ───\n"
		code += "Sub PlayBtn_Click()\n"
		code += "    GetNode(\"MainMenuOverlay\").visible = False\n"
		code += "    GetTree().Paused = False\n"
		code += "End Sub\n\n"
		code += "Sub ExitBtn_Click()\n"
		code += "    GetTree().Quit()\n"
		code += "End Sub\n\n"
		code += "Sub ShowMainMenu()\n"
		code += "    GetNode(\"MainMenuOverlay\").visible = True\n"
		code += "    GetTree().Paused = True\n"
		code += "End Sub\n\n"

	# ── Splash Screen handler ──
	var splash_on: bool = settings.get("splash_enabled", false)
	if splash_on:
		code += "' ─── Splash Screen ───\n"
		code += "Sub SplashTimer_Timeout()\n"
		code += "    GetNode(\"SplashOverlay\").visible = False\n"
		var menu_check: String = settings.get("game_menu_style", "Default")
		if menu_check == "Default":
			code += "    GetNode(\"MainMenuOverlay\").visible = True\n"
			# Tree stays paused — menu handles unpause
		elif menu_check == "None":
			code += "    GetTree().Paused = False\n"
		else:
			code += "    GetTree().Paused = False\n"
		code += "End Sub\n\n"

	# ── Hero Animation Trigger Helper ──
	var hero_death_anim: String = settings.get("hero_death_anim", "(None)")
	var hero_hit_anim: String = settings.get("hero_hit_anim", "(None)")
	code += "' ─── Animation Triggers ───\n"
	code += "Sub TriggerHeroAnim(trigger As String)\n"
	code += "    ' Find the hero (player) in the level and play an animation\n"
	code += "    Dim container As Node2D = GetNode(\"LevelContainer\")\n"
	code += "    Dim nodes As Variant = GetTree().GetNodesInGroup(\"player\")\n"
	code += "    If nodes <> Nothing Then\n"
	code += "        Dim i As Integer\n"
	code += "        For i = 0 To nodes.size() - 1\n"
	code += "            Dim hero As Variant = nodes[i]\n"
	code += "            If hero.HasMethod(\"PlayAnimation\") Then\n"
	code += "                Select Case trigger\n"
	if hero_death_anim != "(None)":
		code += "                    Case \"death\": hero.PlayAnimation(\"" + hero_death_anim + "\")\n"
	if hero_hit_anim != "(None)":
		code += "                    Case \"hit\": hero.PlayAnimation(\"" + hero_hit_anim + "\")\n"
	var hero_power_anim: String = settings.get("hero_power_loss_anim", "(None)")
	var hero_item_anim: String = settings.get("hero_item_loss_anim", "(None)")
	if hero_power_anim != "(None)":
		code += "                    Case \"power_loss\": hero.PlayAnimation(\"" + hero_power_anim + "\")\n"
	if hero_item_anim != "(None)":
		code += "                    Case \"item_loss\": hero.PlayAnimation(\"" + hero_item_anim + "\")\n"
	code += "                End Select\n"
	code += "            End If\n"
	code += "        Next\n"
	code += "    End If\n"
	code += "End Sub\n\n"

	code += "' ─── Level Progression ───\n"
	code += "Sub NextLevel()\n"
	code += "    CurrentLevel = CurrentLevel + 1\n"
	code += "    If CurrentLevel > TotalLevels Then\n"
	code += "        ' You win! All levels complete — loop back\n"
	code += "        CurrentLevel = 1\n"
	code += "    End If\n"
	code += "    GetNode(\"HUD/LevelLabel\").Text = \"Level \" & Str(CurrentLevel)\n"
	code += "\n"
	code += "    ' Load next level into the LevelContainer\n"
	code += "    Dim container As Node2D = GetNode(\"LevelContainer\")\n"
	code += "    ' Remove old level from tree immediately so its Camera2D is deactivated\n"
	code += "    Dim child As Variant\n"
	code += "    For Each child In container.GetChildren()\n"
	code += "        container.RemoveChild(child)\n"
	code += "        child.QueueFree()\n"
	code += "    Next\n"
	code += "    ' Load and instance the new level (its Camera2D auto-becomes current)\n"
	code += "    Dim scene As PackedScene = Load(LevelPaths(CurrentLevel - 1))\n"
	code += "    If scene <> Nothing Then\n"
	code += "        Dim lvl As Node2D = scene.Instantiate()\n"
	code += "        container.AddChild(lvl)\n"
	code += "    End If\n"
	code += "End Sub\n\n"

	# GoToLevel — jump directly to a specific level (1-based)
	code += "' ─── Jump To Level ───\n"
	code += "Sub GoToLevel(level As Integer)\n"
	code += "    If level < 1 Or level > TotalLevels Then Exit Sub\n"
	code += "    CurrentLevel = level\n"
	code += "    GetNode(\"HUD/LevelLabel\").Text = \"Level \" & Str(CurrentLevel)\n"
	code += "\n"
	code += "    ' Load level into the LevelContainer\n"
	code += "    Dim container As Node2D = GetNode(\"LevelContainer\")\n"
	code += "    ' Remove old level from tree immediately so its Camera2D is deactivated\n"
	code += "    Dim child As Variant\n"
	code += "    For Each child In container.GetChildren()\n"
	code += "        container.RemoveChild(child)\n"
	code += "        child.QueueFree()\n"
	code += "    Next\n"
	code += "    Dim scene As PackedScene = Load(LevelPaths(CurrentLevel - 1))\n"
	code += "    If scene <> Nothing Then\n"
	code += "        Dim lvl As Node2D = scene.Instantiate()\n"
	code += "        container.AddChild(lvl)\n"
	code += "    End If\n"
	code += "End Sub\n\n"

	# Sound playback functions (Task 1)
	if valid_sound_names.size() > 0:
		code += "' ─── Sound Effects ───\n"
		code += "' Play a sound by index (0-based)\n"
		code += "Sub PlaySound(index As Integer)\n"
		code += "    Select Case index\n"
		for i in range(valid_sound_names.size()):
			code += "        Case " + str(i) + ": GetNode(\"SFX_" + valid_sound_names[i] + "\").Play()\n"
		code += "    End Select\n"
		code += "End Sub\n\n"
		# Named convenience subs
		for i in range(valid_sound_names.size()):
			code += "Sub PlaySFX_" + valid_sound_names[i] + "()\n"
			code += "    GetNode(\"SFX_" + valid_sound_names[i] + "\").Play()\n"
			code += "End Sub\n\n"

	# ── User code section — preserved across rebuilds ──
	code += "' ─── Your Custom Code ─────────────────────\n"
	code += "' Add your own Subs and functions below.\n"
	code += "' This section is preserved when you rebuild from AGCK.\n"
	code += _user_code_block("Main_custom", "' (add your code here)\n", preserved)

	_write_file(path, code)


# ═══════════════════════════════════════════════════════════════
# SOUND WAV GENERATION
# ═══════════════════════════════════════════════════════════════

func _note_to_freq(val: int) -> float:
	if val <= 0:
		return 0.0
	return NOTE_BASE_HZ * pow(2.0, float(val - 1) / 12.0)


func _wave_sample(phase: float, waveform: int) -> float:
	match waveform:
		0:  # Square
			return 1.0 if phase < 0.5 else -1.0
		1:  # Triangle
			if phase < 0.25:
				return phase * 4.0
			elif phase < 0.75:
				return 2.0 - phase * 4.0
			else:
				return phase * 4.0 - 4.0
		2:  # Sawtooth
			return 2.0 * phase - 1.0
		3:  # Noise
			return randf_range(-1.0, 1.0)
	return 0.0


## Generate a WAV file from AGCK sound data (mirrors agck_sound_editor._generate_audio_stream)
func _generate_sound_wav(path: String, snd: Dictionary) -> void:
	var tempo: int = snd.get("tempo", 120)
	var beats_per_sec: float = float(tempo) / 60.0
	var note_dur: float = 1.0 / beats_per_sec
	var samples_per_note: int = int(float(SAMPLE_RATE) * note_dur)
	var total_samples: int = samples_per_note * NUM_NOTES
	var env_samples: int = maxi(1, int(float(SAMPLE_RATE) * float(ENVELOPE_MS) / 1000.0))

	var v1_notes: Array = snd.get("voice1_notes", [])
	var v2_notes: Array = snd.get("voice2_notes", [])
	var flt_notes: Array = snd.get("filter_notes", [])
	var v1_wave: int = snd.get("voice1_wave", 0)
	var v2_wave: int = snd.get("voice2_wave", 1)
	var flt_type: int = snd.get("filter_type", 0)
	var flt_q_pct: int = snd.get("filter_q", 50)

	var v1_active: bool = false
	var v2_active: bool = false
	var flt_active: bool = false
	for i in range(NUM_NOTES):
		if i < v1_notes.size() and v1_notes[i] > 0:
			v1_active = true
		if i < v2_notes.size() and v2_notes[i] > 0:
			v2_active = true
		if i < flt_notes.size() and flt_notes[i] > 0:
			flt_active = true

	if not v1_active and not v2_active:
		return

	var pcm = PackedByteArray()
	pcm.resize(total_samples * 2)

	# Read per-voice volumes (0-100) from sound data
	var v1_vol_pct: float = float(snd.get("voice1_volume", 80)) / 100.0
	var v2_vol_pct: float = float(snd.get("voice2_volume", 60)) / 100.0
	var v1_gain: float = v1_vol_pct * 0.55  # scale to max ~0.55 to avoid clipping
	var v2_gain: float = v2_vol_pct * 0.45

	var v1_phase: float = 0.0
	var v2_phase: float = 0.0
	var flt_prev: float = 0.0

	for ni in range(NUM_NOTES):
		var v1_freq: float = _note_to_freq(v1_notes[ni]) if v1_active and ni < v1_notes.size() else 0.0
		var v2_freq: float = _note_to_freq(v2_notes[ni]) if v2_active and ni < v2_notes.size() else 0.0
		var flt_cutoff: float = 0.0
		if flt_active and flt_type > 0 and ni < flt_notes.size() and flt_notes[ni] > 0:
			flt_cutoff = _note_to_freq(flt_notes[ni])

		for s in range(samples_per_note):
			var sample: float = 0.0

			if v1_freq > 0.0:
				sample += _wave_sample(v1_phase, v1_wave) * v1_gain
				v1_phase = fmod(v1_phase + v1_freq / float(SAMPLE_RATE), 1.0)

			if v2_freq > 0.0:
				sample += _wave_sample(v2_phase, v2_wave) * v2_gain
				v2_phase = fmod(v2_phase + v2_freq / float(SAMPLE_RATE), 1.0)

			if flt_cutoff > 0.0:
				var rc: float = 1.0 / (TAU * flt_cutoff)
				var dt: float = 1.0 / float(SAMPLE_RATE)
				var alpha: float = dt / (rc + dt)
				var lp: float = flt_prev + alpha * (sample - flt_prev)
				flt_prev = lp
				match flt_type:
					1:  sample = lp
					2:  sample = sample - lp
					3:
						var res: float = 0.1 + float(flt_q_pct) / 100.0 * 4.0
						sample = clampf((sample - lp) * res, -1.0, 1.0)
			else:
				flt_prev = sample

			var env: float = 1.0
			if s < env_samples:
				env = float(s) / float(env_samples)
			elif s > samples_per_note - env_samples:
				env = float(samples_per_note - s) / float(env_samples)
			sample *= env

			var pcm_val: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
			var off: int = (ni * samples_per_note + s) * 2
			pcm[off] = pcm_val & 0xFF
			pcm[off + 1] = (pcm_val >> 8) & 0xFF

	# Write standard WAV file (44-byte header + PCM data)
	_write_wav_file(path, pcm, SAMPLE_RATE)
	_log("  ✓ " + path.get_file(), "#8f8")


## Writes a standard WAV file with 16-bit mono PCM data.
func _write_wav_file(path: String, pcm: PackedByteArray, sample_rate: int) -> void:
	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var f = FileAccess.open(path, FileAccess.WRITE)
	if not f:
		push_error("AGCK: Cannot write WAV: " + path)
		return
	var data_size := pcm.size()
	var file_size := 36 + data_size
	# RIFF header
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(file_size)
	f.store_buffer("WAVE".to_ascii_buffer())
	# fmt sub-chunk
	f.store_buffer("fmt ".to_ascii_buffer())
	f.store_32(16)           # sub-chunk size
	f.store_16(1)            # PCM format
	f.store_16(1)            # mono
	f.store_32(sample_rate)
	f.store_32(sample_rate * 2)  # byte rate (16-bit mono)
	f.store_16(2)            # block align
	f.store_16(16)           # bits per sample
	# data sub-chunk
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data_size)
	f.store_buffer(pcm)
	f.close()


# ═══════════════════════════════════════════════════════════════
# SHADER EFFECT GENERATION
# ═══════════════════════════════════════════════════════════════

## The built-in shader library — matches agck_shader_editor.gd
## Only the code is needed here; the editor stores the full library.
const SHADER_CODES = {
	"CRT TV": "shader_type canvas_item;\nuniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;\nuniform float scanline_strength : hint_range(0.0, 1.0) = 0.3;\nuniform float curvature : hint_range(0.0, 0.1) = 0.02;\nvoid fragment() {\n\tvec2 uv = SCREEN_UV;\n\tvec2 dc = uv - 0.5;\n\tuv = uv + dc * dot(dc, dc) * curvature;\n\tvec4 color = texture(screen_texture, uv);\n\tfloat sl = sin(uv.y * 800.0) * 0.5 + 0.5;\n\tcolor.rgb *= 1.0 - scanline_strength * sl;\n\tCOLOR = color;\n}\n",
	"Pixelate": "shader_type canvas_item;\nuniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;\nuniform float pixel_size : hint_range(1.0, 32.0) = 4.0;\nvoid fragment() {\n\tvec2 size = vec2(textureSize(screen_texture, 0));\n\tvec2 uv = floor(SCREEN_UV * size / pixel_size) * pixel_size / size;\n\tCOLOR = texture(screen_texture, uv);\n}\n",
	"Blur": "shader_type canvas_item;\nuniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;\nuniform float blur_amount : hint_range(0.0, 5.0) = 1.0;\nvoid fragment() {\n\tvec2 ps = 1.0 / vec2(textureSize(screen_texture, 0));\n\tvec4 color = vec4(0.0);\n\tfor (int x = -2; x <= 2; x++) {\n\t\tfor (int y = -2; y <= 2; y++) {\n\t\t\tcolor += texture(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * ps * blur_amount);\n\t\t}\n\t}\n\tCOLOR = color / 25.0;\n}\n",
	"Glow": "shader_type canvas_item;\nuniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;\nuniform float glow_strength : hint_range(0.0, 2.0) = 0.5;\nuniform float threshold : hint_range(0.0, 1.0) = 0.5;\nvoid fragment() {\n\tvec4 color = texture(screen_texture, SCREEN_UV);\n\tvec2 ps = 1.0 / vec2(textureSize(screen_texture, 0));\n\tvec4 bloom = vec4(0.0);\n\tfor (int x = -3; x <= 3; x++) {\n\t\tfor (int y = -3; y <= 3; y++) {\n\t\t\tvec4 s = texture(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * ps * 2.0);\n\t\t\tfloat b = max(s.r, max(s.g, s.b));\n\t\t\tif (b > threshold) bloom += s;\n\t\t}\n\t}\n\tbloom /= 49.0;\n\tCOLOR = color + bloom * glow_strength;\n}\n",
	"Chromatic Aberration": "shader_type canvas_item;\nuniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;\nuniform float offset : hint_range(0.0, 10.0) = 2.0;\nvoid fragment() {\n\tvec2 ps = 1.0 / vec2(textureSize(screen_texture, 0));\n\tfloat r = texture(screen_texture, SCREEN_UV + vec2(offset, 0.0) * ps).r;\n\tfloat g = texture(screen_texture, SCREEN_UV).g;\n\tfloat b = texture(screen_texture, SCREEN_UV - vec2(offset, 0.0) * ps).b;\n\tCOLOR = vec4(r, g, b, 1.0);\n}\n",
	"Vignette": "shader_type canvas_item;\nuniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;\nuniform float strength : hint_range(0.0, 2.0) = 0.5;\nuniform float radius : hint_range(0.1, 1.0) = 0.75;\nvoid fragment() {\n\tvec4 color = texture(screen_texture, SCREEN_UV);\n\tfloat dist = distance(SCREEN_UV, vec2(0.5));\n\tfloat v = smoothstep(radius, radius - 0.3, dist);\n\tcolor.rgb *= mix(1.0 - strength, 1.0, v);\n\tCOLOR = color;\n}\n",
	"Sepia": "shader_type canvas_item;\nuniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;\nuniform float intensity : hint_range(0.0, 1.0) = 0.8;\nvoid fragment() {\n\tvec4 color = texture(screen_texture, SCREEN_UV);\n\tfloat grey = dot(color.rgb, vec3(0.299, 0.587, 0.114));\n\tvec3 sepia = vec3(grey) * vec3(1.2, 1.0, 0.8);\n\tcolor.rgb = mix(color.rgb, sepia, intensity);\n\tCOLOR = color;\n}\n",
	"Night Vision": "shader_type canvas_item;\nuniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;\nuniform float noise_amount : hint_range(0.0, 0.5) = 0.1;\nuniform float brightness : hint_range(0.5, 3.0) = 1.5;\nvoid fragment() {\n\tvec4 color = texture(screen_texture, SCREEN_UV);\n\tfloat grey = dot(color.rgb, vec3(0.299, 0.587, 0.114));\n\tfloat noise = fract(sin(dot(SCREEN_UV + vec2(TIME), vec2(12.9898, 78.233))) * 43758.5453);\n\tgrey += (noise - 0.5) * noise_amount;\n\tcolor.rgb = vec3(grey * 0.2, grey * brightness, grey * 0.2);\n\tCOLOR = color;\n}\n",
	"Water Ripple": "shader_type canvas_item;\nuniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;\nuniform float wave_speed : hint_range(0.5, 5.0) = 2.0;\nuniform float wave_amount : hint_range(0.0, 0.05) = 0.01;\nvoid fragment() {\n\tvec2 uv = SCREEN_UV;\n\tuv.x += sin(uv.y * 20.0 + TIME * wave_speed) * wave_amount;\n\tuv.y += cos(uv.x * 20.0 + TIME * wave_speed) * wave_amount;\n\tCOLOR = texture(screen_texture, uv);\n}\n",
	"Glitch": "shader_type canvas_item;\nuniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;\nuniform float glitch_strength : hint_range(0.0, 0.1) = 0.02;\nuniform float glitch_speed : hint_range(0.5, 10.0) = 3.0;\nvoid fragment() {\n\tvec2 uv = SCREEN_UV;\n\tfloat t = floor(TIME * glitch_speed);\n\tfloat r = fract(sin(t * 43758.5453) * 2.0);\n\tif (r > 0.85) {\n\t\tuv.x += (fract(sin(dot(vec2(t, uv.y * 10.0), vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * glitch_strength;\n\t}\n\tfloat cr = texture(screen_texture, uv + vec2(glitch_strength * r, 0.0)).r;\n\tfloat cg = texture(screen_texture, uv).g;\n\tfloat cb = texture(screen_texture, uv - vec2(glitch_strength * r, 0.0)).b;\n\tCOLOR = vec4(cr, cg, cb, 1.0);\n}\n",
}

## Per-sprite / per-tile shader FX codes — texture-space (operate on TEXTURE + UV)
const SPRITE_SHADER_CODES = {
	"Outline": "shader_type canvas_item;\nuniform float outline_width : hint_range(0.5, 4.0) = 1.0;\nvoid fragment() {\n\tvec4 col = texture(TEXTURE, UV);\n\tif (col.a < 0.1) {\n\t\tvec2 sz = TEXTURE_PIXEL_SIZE * outline_width;\n\t\tfloat a = texture(TEXTURE, UV + vec2(-sz.x, 0)).a + texture(TEXTURE, UV + vec2(sz.x, 0)).a + texture(TEXTURE, UV + vec2(0, -sz.y)).a + texture(TEXTURE, UV + vec2(0, sz.y)).a;\n\t\tif (a > 0.0) { col = vec4(1.0, 1.0, 1.0, 1.0); }\n\t}\n\tCOLOR = col;\n}\n",
	"Glow": "shader_type canvas_item;\nuniform float glow_size : hint_range(1.0, 8.0) = 3.0;\nvoid fragment() {\n\tvec4 col = texture(TEXTURE, UV);\n\tif (col.a < 0.1) {\n\t\tfloat a = 0.0;\n\t\tfor (float x = -1.0; x <= 1.0; x += 0.5) {\n\t\t\tfor (float y = -1.0; y <= 1.0; y += 0.5) {\n\t\t\t\ta += texture(TEXTURE, UV + vec2(x, y) * TEXTURE_PIXEL_SIZE * glow_size).a;\n\t\t\t}\n\t\t}\n\t\tif (a > 0.0) { col = vec4(1.0, 0.8, 0.2, min(a * 0.08, 0.6)); }\n\t} else {\n\t\tcol.rgb += vec3(0.15, 0.12, 0.04);\n\t}\n\tCOLOR = col;\n}\n",
	"Hologram": "shader_type canvas_item;\nuniform float scan_speed : hint_range(0.5, 5.0) = 2.0;\nuniform float scan_density : hint_range(10.0, 100.0) = 40.0;\nvoid fragment() {\n\tvec4 col = texture(TEXTURE, UV);\n\tif (col.a > 0.1) {\n\t\tfloat scan = sin((UV.y + TIME * scan_speed) * scan_density) * 0.5 + 0.5;\n\t\tcol.rgb = mix(col.rgb, vec3(0.2, 0.8, 1.0), 0.5);\n\t\tcol.a *= 0.7 + scan * 0.3;\n\t}\n\tCOLOR = col;\n}\n",
	"Flash": "shader_type canvas_item;\nuniform float flash_amount : hint_range(0.0, 1.0) = 0.0;\nvoid fragment() {\n\tvec4 col = texture(TEXTURE, UV);\n\tcol.rgb = mix(col.rgb, vec3(1.0), flash_amount);\n\tCOLOR = col;\n}\n",
	"Rainbow": "shader_type canvas_item;\nuniform float speed : hint_range(0.1, 5.0) = 1.0;\nuniform float saturation : hint_range(0.0, 1.0) = 0.5;\nvoid fragment() {\n\tvec4 col = texture(TEXTURE, UV);\n\tif (col.a > 0.1) {\n\t\tfloat h = fract(TIME * speed * 0.1 + UV.x * 0.5);\n\t\tvec3 rb = clamp(vec3(abs(h*6.0-3.0)-1.0, 2.0-abs(h*6.0-2.0), 2.0-abs(h*6.0-4.0)), 0.0, 1.0);\n\t\tcol.rgb = mix(col.rgb, rb, saturation);\n\t}\n\tCOLOR = col;\n}\n",
	"Shimmer": "shader_type canvas_item;\nuniform float shimmer_speed : hint_range(0.5, 5.0) = 2.0;\nuniform float shimmer_amount : hint_range(0.0, 1.0) = 0.3;\nvoid fragment() {\n\tvec4 col = texture(TEXTURE, UV);\n\tif (col.a > 0.1) {\n\t\tfloat sh = sin(UV.x * 20.0 + TIME * shimmer_speed) * sin(UV.y * 20.0 - TIME * shimmer_speed * 0.7);\n\t\tcol.rgb += sh * shimmer_amount;\n\t}\n\tCOLOR = col;\n}\n",
	"Dissolve": "shader_type canvas_item;\nuniform float amount : hint_range(0.0, 1.0) = 0.0;\nuniform float edge_width : hint_range(0.01, 0.2) = 0.05;\nvoid fragment() {\n\tvec4 col = texture(TEXTURE, UV);\n\tfloat noise = fract(sin(dot(UV, vec2(12.9898, 78.233))) * 43758.5453);\n\tif (noise < amount) { col.a = 0.0; }\n\telse if (noise < amount + edge_width) { col.rgb = vec3(1.0, 0.5, 0.0); }\n\tCOLOR = col;\n}\n",
	"Pixelate": "shader_type canvas_item;\nuniform float pixel_size : hint_range(2.0, 16.0) = 4.0;\nvoid fragment() {\n\tvec2 ts = 1.0 / TEXTURE_PIXEL_SIZE;\n\tvec2 uv = floor(UV * ts / pixel_size) * pixel_size / ts;\n\tCOLOR = texture(TEXTURE, uv);\n}\n",
}

## Generates a .gdshader file for a shader effect layer.
func _generate_shader_file(path: String, shader_data: Dictionary) -> void:
	var sname = shader_data.get("shader_name", "")
	var code = SHADER_CODES.get(sname, "")
	if code.is_empty():
		_log("  ⚠ Unknown shader: " + sname, "#ff8")
		return
	_write_file(path, code)
	_log("  ✓ " + path.get_file(), "#8f8")


# ═══════════════════════════════════════════════════════════════
# PROJECT.GODOT GENERATION (standalone playability)
# ═══════════════════════════════════════════════════════════════

## Generates a project.godot file so the built game can run standalone.
func _generate_project_godot(path: String, settings: Dictionary, output_dir: String) -> void:
	var title: String = settings.get("game_title", "AGCK Game")
	var screen_w: int = settings.get("screen_width", 640)
	var screen_h: int = settings.get("screen_height", 480)
	var bg_color: String = settings.get("background_color", "#1a1a2e")

	var godot = ""
	godot += '; Engine configuration file.\n'
	godot += '; Generated by AGCK (Arcade Game Construction Kit)\n\n'

	godot += '[application]\n\n'
	godot += 'config/name="' + title + '"\n'
	godot += 'run/main_scene="' + output_dir + 'Main.tscn"\n'
	godot += 'config/features=PackedStringArray("4.4")\n\n'

	godot += '[display]\n\n'
	godot += 'window/size/viewport_width=' + str(screen_w) + '\n'
	godot += 'window/size/viewport_height=' + str(screen_h) + '\n'
	# Honor the Display → Fullscreen toggle. When on, Godot's window/size/mode
	# = 3 (Exclusive Fullscreen); the viewport_width/height above still drive
	# the rendering resolution (with stretch mode 'canvas_items' + aspect
	# 'keep' the game letterboxes to the desktop). Default 0 = Windowed.
	var fullscreen: bool = bool(settings.get("fullscreen", false))
	if fullscreen:
		godot += 'window/size/mode=3\n'
	godot += 'window/stretch/mode="canvas_items"\n'
	godot += 'window/stretch/aspect="keep"\n\n'

	godot += '[rendering]\n\n'
	godot += 'environment/defaults/default_clear_color=Color("' + bg_color + '")\n\n'

	godot += '[input]\n\n'
	# Input bindings respect the per-game settings: keyboard, joystick, mouse, touch
	# can each be enabled independently and ALL active sources are bound at once.
	var kbd: bool = bool(settings.get("keyboard_enabled", true))
	var pad: bool = bool(settings.get("joystick_enabled", true))
	var mouse: bool = bool(settings.get("mouse_enabled", false))
	var touch: bool = bool(settings.get("touch_enabled", false))
	# Fail-safe: if user somehow disabled all four, fall back to keyboard so the game is still playable.
	if not (kbd or pad or mouse or touch):
		kbd = true
	godot += _emit_input_action("ui_left",   kbd, pad, mouse, touch, "left")
	godot += _emit_input_action("ui_right",  kbd, pad, mouse, touch, "right")
	godot += _emit_input_action("ui_up",     kbd, pad, mouse, touch, "up")
	godot += _emit_input_action("ui_down",   kbd, pad, mouse, touch, "down")
	godot += _emit_input_action("ui_accept", kbd, pad, mouse, touch, "accept")
	godot += '\n'

	_write_file(path, godot)
	_log("  ✓ project.godot (standalone game)", "#8f8")


# Per-action keycodes (Godot keycode constants: KEY_LEFT=4194319, KEY_RIGHT=4194321,
# KEY_UP=4194320, KEY_DOWN=4194322, KEY_SPACE=32, KEY_ENTER=4194309).
const _AGCK_KEYCODES := {
	"left":   4194319,
	"right":  4194321,
	"up":     4194320,
	"down":   4194322,
	"accept": 32,
}
# Joystick button indices (Godot JoyButton: 0=A/Cross, 11=DPad-Up, 12=Down, 13=Left, 14=Right).
const _AGCK_PAD_BUTTONS := {
	"left":   13,
	"right":  14,
	"up":     11,
	"down":   12,
	"accept": 0,
}
# Joystick axes for analog stick (LEFT_X=0, LEFT_Y=1). Direction sign: -1 = neg, 1 = pos.
const _AGCK_PAD_AXES := {
	"left":   {"axis": 0, "value": -1.0},
	"right":  {"axis": 0, "value":  1.0},
	"up":     {"axis": 1, "value": -1.0},
	"down":   {"axis": 1, "value":  1.0},
}


## Emit a project.godot input-action block uniting all enabled input sources.
## Mouse maps left-click → ui_accept only (movement actions skip mouse).
## Touch maps screen-touch → ui_accept only (movement uses on-screen buttons at runtime).
func _emit_input_action(action: String, kbd: bool, pad: bool, mouse: bool, touch: bool, kind: String) -> String:
	var events: Array[String] = []
	if kbd and _AGCK_KEYCODES.has(kind):
		var kc: int = _AGCK_KEYCODES[kind]
		events.append('Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":' + str(kc) + ',"physical_keycode":0,"key_label":0,"unicode":' + (str(kc) if kc < 256 else "0") + ',"location":0,"echo":false,"script":null)')
	if pad:
		# Digital D-pad / face button
		if _AGCK_PAD_BUTTONS.has(kind):
			var btn: int = _AGCK_PAD_BUTTONS[kind]
			events.append('Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":' + str(btn) + ',"pressure":0.0,"pressed":false,"script":null)')
		# Analog stick (movement only)
		if _AGCK_PAD_AXES.has(kind):
			var ax: Dictionary = _AGCK_PAD_AXES[kind]
			events.append('Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":-1,"axis":' + str(ax["axis"]) + ',"axis_value":' + str(ax["value"]) + ',"script":null)')
	if mouse and kind == "accept":
		# Left mouse button → accept (jump / fire / confirm)
		events.append('Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"button_index":1,"canceled":false,"double_click":false,"factor":1.0,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"script":null)')
	if touch and kind == "accept":
		# Any screen touch → accept
		events.append('Object(InputEventScreenTouch,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"index":0,"position":Vector2(0, 0),"pressed":false,"canceled":false,"double_tap":false,"script":null)')
	if events.is_empty():
		return ""
	var s := action + '={\n"deadzone": 0.5,\n"events": [' + ", ".join(events) + ']\n}\n'
	return s


# ═══════════════════════════════════════════════════════════════
# PROJECT MANIFEST
# ═══════════════════════════════════════════════════════════════

func _generate_manifest(path: String, game_data: Dictionary) -> void:
	var json = JSON.new()
	var text = json.stringify(game_data, "\t")
	_write_file(path, text)
	_log("  ✓ project.agck manifest", "#8f8")


# ═══════════════════════════════════════════════════════════════
# UTILITIES
# ═══════════════════════════════════════════════════════════════

## Extracts user-code sections from an existing .vg file before overwriting.
## Returns a Dictionary mapping section_name -> code_text.
## Looks for blocks delimited by:
##   '--- USER CODE: section_name ---
##   ...user code...
##   '--- END USER CODE ---
func _extract_user_code(path: String) -> Dictionary:
	var sections: Dictionary = {}
	if not FileAccess.file_exists(path):
		return sections
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return sections
	var text = file.get_as_text()
	file.close()

	var lines = text.split("\n")
	var current_section: String = ""
	var current_lines: PackedStringArray = PackedStringArray()

	for line in lines:
		var trimmed = line.strip_edges()
		if trimmed.begins_with("'--- USER CODE:") and trimmed.ends_with("---"):
			# Extract section name between "USER CODE:" and "---"
			var start = trimmed.find("USER CODE:") + 10
			var end = trimmed.rfind("---")
			current_section = trimmed.substr(start, end - start).strip_edges()
			current_lines = PackedStringArray()
		elif trimmed == "'--- END USER CODE ---" and current_section != "":
			sections[current_section] = "\n".join(current_lines)
			current_section = ""
		elif current_section != "":
			current_lines.append(line)

	return sections


## Generates a user-code block with delimiters.
## If preserved_sections contains code for this section, uses that;
## otherwise emits the default_code placeholder.
func _user_code_block(section_name: String, default_code: String, preserved: Dictionary) -> String:
	var s = "'--- USER CODE: " + section_name + " ---\n"
	if preserved.has(section_name) and preserved[section_name].strip_edges() != "":
		s += preserved[section_name] + "\n"
	else:
		s += default_code
		if not default_code.ends_with("\n"):
			s += "\n"
	s += "'--- END USER CODE ---\n"
	return s


func _write_file(path: String, content: String) -> bool:
	# Ensure directory exists
	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var f = FileAccess.open(path, FileAccess.WRITE)
	if not f:
		push_error("AGCK: Cannot write to " + path)
		_log("✗ Failed to write: " + path, "#ff4444")
		return false
	f.store_string(content)
	f.close()
	return true


## Convert a hex color string (e.g. "808c99") to .tscn Color(r, g, b, 1) format.
## Godot's .tscn resource parser does NOT accept Color("hex") — only Color(r,g,b,a).
func _hex_to_tscn_color(hex: String) -> String:
	var h = hex.strip_edges().lstrip("#")
	if h.length() < 6:
		h = h + "0".repeat(6 - h.length())
	var r = float(h.substr(0, 2).hex_to_int()) / 255.0
	var g = float(h.substr(2, 2).hex_to_int()) / 255.0
	var b = float(h.substr(4, 2).hex_to_int()) / 255.0
	return "Color(" + str(snappedf(r, 0.0001)) + ", " + str(snappedf(g, 0.0001)) + ", " + str(snappedf(b, 0.0001)) + ", 1)"


func _safe_id(name: String) -> String:
	# Convert to a valid identifier: replace spaces/special chars with _
	var result = ""
	for i in range(name.length()):
		var c = name[i]
		if c == " " or c == "-" or c == "." or c == "/" or c == "\\":
			result += "_"
		elif c.is_valid_identifier():
			result += c
		# skip other chars
	if result.is_empty():
		result = "unnamed"
	# Ensure doesn't start with digit
	if result[0].is_valid_int():
		result = "_" + result
	return result


func _fstr(val: float) -> String:
	# Format float for VB6 code
	if val == int(val):
		return str(int(val)) + ".0"
	return str(val)


func _level_is_empty(lvl: Dictionary) -> bool:
	var grid: Array = lvl.get("grid", [])
	for row in grid:
		for cell in row:
			if cell is Dictionary:
				if cell.get("block_type", 0) != 0:
					return false
			elif cell is int or cell is float:
				if int(cell) != 0:
					return false
	if lvl.get("actors", []).size() > 0:
		return false
	return true
