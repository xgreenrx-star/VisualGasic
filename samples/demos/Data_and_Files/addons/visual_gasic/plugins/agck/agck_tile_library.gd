@tool
## AGCK Tile Library — procedural pixel-art tile & actor sprite generator
##
## Generates and manages a library of 18×18 pixel-art tiles organized
## by block type, plus actor character sprites. Tiles are editable:
## double-click opens them in an inline sprite editor. Edited tiles
## replace the originals for full WYSIWYG.
extends RefCounted

# ─── Constants ───────────────────────────────────────────────
## Native procgen art canvas. All built-in tile/actor draws are calibrated
## against these sizes; the user-facing "Tile Size" / "Actor Frame Size"
## settings are render targets that art is scaled to at build time.
const TILE_SIZE = 18   # Kenney-compatible pixel art resolution
const ACTOR_SPRITE_SIZE = 24  # Actor sprites slightly larger

# ─── Project-Configurable Render Sizes ──────────────────────
## Project-level tile size (game-runtime cell pixels). Driven by AGCK
## settings; the level grid, builder backend and HUD all scale to this.
var tile_render_size: int = 32
## Project-level default actor frame size. Per-actor `frame_size` overrides
## (stored on `actor_sprites[idx]["frame_size"]`) take precedence over this.
var actor_frame_size: int = 32

## Available preset sizes for the settings UI dropdowns.
const SIZE_PRESETS: Array[int] = [8, 16, 24, 32, 48, 64, 96, 128]


## Returns the effective frame size for an actor: per-actor override if set,
## otherwise the project default.
func get_actor_frame_size(actor_index: int) -> int:
	var spr = actor_sprites.get(actor_index, {})
	var override = spr.get("frame_size", 0)
	if typeof(override) == TYPE_INT and override > 0:
		return int(override)
	return actor_frame_size


## Set per-actor frame size override. Pass 0 to clear.
func set_actor_frame_size(actor_index: int, size: int) -> void:
	if not actor_sprites.has(actor_index):
		actor_sprites[actor_index] = {}
	if size <= 0:
		actor_sprites[actor_index].erase("frame_size")
	else:
		actor_sprites[actor_index]["frame_size"] = size

# Block categories matching the level editor
const BLOCK_EMPTY      = 0
const BLOCK_BARRIER    = 1
const BLOCK_LADDER     = 2
const BLOCK_DEADLY     = 3
const BLOCK_BACKGROUND = 4
const BLOCK_TELEPORT   = 5
const BLOCK_SWITCH     = 6
const BLOCK_GOAL       = 7

const BLOCK_NAMES = ["Empty", "Barrier", "Ladder", "Deadly", "Background", "Teleport", "Switch", "Goal"]

# Base colors per block type (used for tinting/outlines)
const BLOCK_COLORS = [
	Color(0.12, 0.12, 0.14),  # Empty
	Color(0.50, 0.55, 0.60),  # Barrier — grey/steel
	Color(0.30, 0.75, 0.30),  # Ladder — green
	Color(0.85, 0.20, 0.20),  # Deadly — red
	Color(0.25, 0.40, 0.60),  # Background — blue
	Color(0.65, 0.30, 0.85),  # Teleport — purple
	Color(0.90, 0.80, 0.20),  # Switch — yellow
	Color(0.95, 0.75, 0.15),  # Goal — gold (level exit / flagpole)
]

# Actor type colors
const ACTOR_TYPE_COLORS = {
	"Player":   Color(0.30, 0.75, 0.95),
	"Drone":    Color(0.85, 0.30, 0.30),
	"Missile":  Color(0.95, 0.60, 0.15),
	"Sentry":   Color(0.70, 0.40, 0.90),
	"Computer": Color(0.40, 0.80, 0.40),
	"Zombie":   Color(0.45, 0.65, 0.30),
	"Boss":     Color(0.80, 0.20, 0.50),
	"Bat":      Color(0.50, 0.35, 0.55),
	"NPC":      Color(0.85, 0.70, 0.45),
	"Tank":     Color(0.40, 0.50, 0.35),
	"Fireball": Color(1.00, 0.45, 0.10),
	# Top-down view variants — see _draw_top_*_sprite. Used by Top-Down RPG / Maze templates
	# so those genres get visually distinct (not side-view) actor art.
	"TopHero":    Color(0.30, 0.80, 0.95),
	"TopGoblin":  Color(0.55, 0.80, 0.30),
	"TopChest":   Color(0.85, 0.65, 0.20),
	# Runner — Geometry-Dash-style auto-running cube. Drives _gen_runner_physics.
	"Runner":     Color(0.20, 0.85, 1.00),
}

# ─── Data ────────────────────────────────────────────────────
# tiles[block_type] = Array of { "name": String, "image": Image, "texture": ImageTexture }
var tiles: Dictionary = {}
# actor_sprites[actor_index] = { "name": String, "type": String,
#   "anims": { "Idle": [Image,...], "Walk": [Image,...], ... },
#   "frames": [Image, ...] (=first anim's frames, backward compat),
#   "image": Image (=first frame thumbnail), "texture": ImageTexture }
var actor_sprites: Dictionary = {}

# Flag: has the library been generated?
var _initialized: bool = false


# ═══════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════

## Initialize the library with procedurally generated tiles
func initialize() -> void:
	if _initialized:
		return
	_generate_all_tiles()
	_initialized = true


## Get all tiles for a given block type
func get_tiles_for_type(block_type: int) -> Array:
	if not tiles.has(block_type):
		return []
	return tiles[block_type]


## Get a specific tile's texture
func get_tile_texture(block_type: int, tile_index: int) -> ImageTexture:
	if not tiles.has(block_type):
		return null
	var arr: Array = tiles[block_type]
	if tile_index < 0 or tile_index >= arr.size():
		return null
	return arr[tile_index].get("texture", null)


## Get a specific tile's image (for editing)
func get_tile_image(block_type: int, tile_index: int) -> Image:
	if not tiles.has(block_type):
		return null
	var arr: Array = tiles[block_type]
	if tile_index < 0 or tile_index >= arr.size():
		return null
	return arr[tile_index].get("image", null)


## Get a specific tile's name
func get_tile_name(block_type: int, tile_index: int) -> String:
	if not tiles.has(block_type):
		return ""
	var arr: Array = tiles[block_type]
	if tile_index < 0 or tile_index >= arr.size():
		return ""
	return arr[tile_index].get("name", "")


## Get tile count for a block type
func get_tile_count(block_type: int) -> int:
	if not tiles.has(block_type):
		return 0
	return tiles[block_type].size()


## Get a tile's shader FX name (e.g. "Glow", "(None)")
func get_tile_shader_fx(block_type: int, tile_index: int) -> String:
	if not tiles.has(block_type):
		return "(None)"
	var arr: Array = tiles[block_type]
	if tile_index < 0 or tile_index >= arr.size():
		return "(None)"
	return arr[tile_index].get("shader_fx", "(None)")


## Get a tile's shader FX parameters
func get_tile_shader_params(block_type: int, tile_index: int) -> Dictionary:
	if not tiles.has(block_type):
		return {}
	var arr: Array = tiles[block_type]
	if tile_index < 0 or tile_index >= arr.size():
		return {}
	return arr[tile_index].get("shader_params", {})


## Is this tile a one-way platform? (player can jump up through it but
## lands on top — Mario / Donkey Kong / Celeste-style "thin platform"). Set
## via the optional flag in `_add_tile_ex` at tile-generation time.
func get_tile_one_way(block_type: int, tile_index: int) -> bool:
	if not tiles.has(block_type):
		return false
	var arr: Array = tiles[block_type]
	if tile_index < 0 or tile_index >= arr.size():
		return false
	return arr[tile_index].get("one_way", false)


## Is this tile a Mario-style ?-block? Solid barrier that spawns a coin
## when bumped from below. Set via the `is_question` flag in `_add_tile_ex`.
func get_tile_is_question(block_type: int, tile_index: int) -> bool:
	if not tiles.has(block_type):
		return false
	var arr: Array = tiles[block_type]
	if tile_index < 0 or tile_index >= arr.size():
		return false
	return arr[tile_index].get("is_question", false)


## Set a tile's shader FX and parameters
func set_tile_shader_fx(block_type: int, tile_index: int, fx_name: String, fx_params: Dictionary = {}) -> void:
	if not tiles.has(block_type):
		return
	var arr: Array = tiles[block_type]
	if tile_index < 0 or tile_index >= arr.size():
		return
	arr[tile_index]["shader_fx"] = fx_name
	arr[tile_index]["shader_params"] = fx_params


## Update a tile's image (after inline editing)
func update_tile(block_type: int, tile_index: int, new_image: Image) -> void:
	if not tiles.has(block_type):
		return
	var arr: Array = tiles[block_type]
	if tile_index < 0 or tile_index >= arr.size():
		return
	# Resize to TILE_SIZE if needed
	if new_image.get_width() != TILE_SIZE or new_image.get_height() != TILE_SIZE:
		new_image = new_image.duplicate()
		new_image.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
	arr[tile_index]["image"] = new_image
	arr[tile_index]["texture"] = ImageTexture.create_from_image(new_image)


## Add a custom tile to a block type (returns the new index)
func add_custom_tile(block_type: int, name: String, image: Image) -> int:
	if not tiles.has(block_type):
		tiles[block_type] = []
	if image.get_width() != TILE_SIZE or image.get_height() != TILE_SIZE:
		image = image.duplicate()
		image.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
	var tex = ImageTexture.create_from_image(image)
	tiles[block_type].append({"name": name, "image": image, "texture": tex})
	return tiles[block_type].size() - 1


## Is this tile from the most recent import wave? Drives the "NEW"
## watermark badge in the palette UI. Cleared by `clear_new_marks` (called
## at the start of every new import wave) or when the tile is moved.
func get_tile_is_new(block_type: int, tile_index: int) -> bool:
	if not tiles.has(block_type):
		return false
	var arr: Array = tiles[block_type]
	if tile_index < 0 or tile_index >= arr.size():
		return false
	return arr[tile_index].get("is_new", false)


## Mark / unmark a tile's "newly imported" flag.
func set_tile_is_new(block_type: int, tile_index: int, value: bool) -> void:
	if not tiles.has(block_type):
		return
	var arr: Array = tiles[block_type]
	if tile_index < 0 or tile_index >= arr.size():
		return
	if value:
		arr[tile_index]["is_new"] = true
	else:
		arr[tile_index].erase("is_new")


## Strip the "is_new" flag from every tile in every bucket. Called at the
## start of each import wave so only the freshly imported tiles get the
## NEW badge.
func clear_new_marks() -> void:
	for bt in tiles.keys():
		var arr: Array = tiles[bt]
		for rec in arr:
			if typeof(rec) == TYPE_DICTIONARY and rec.has("is_new"):
				rec.erase("is_new")


## Bulk-move a set of tiles from one block-type bucket to another.
##
## `src_indices` are indices into the source bucket as they exist NOW.
## Returns a remap dict: { old_src_idx : {"bt": int, "idx": int}, ... } that
## describes where every tile in the source bucket ends up afterward
## (both the moved ones and the surviving ones, which get compacted).
##
## Same-bucket moves are a no-op (returned remap is identity).
func bulk_move_tiles(src_bt: int, src_indices: Array, dst_bt: int) -> Dictionary:
	var remap: Dictionary = {}
	if src_bt == dst_bt:
		var n: int = get_tile_count(src_bt)
		for i in range(n):
			remap[i] = {"bt": src_bt, "idx": i}
		return remap
	var pop_result := _pop_tiles(src_bt, src_indices, dst_bt)
	remap = pop_result["remap"]
	if not tiles.has(dst_bt):
		tiles[dst_bt] = []
	for rec in pop_result["items"]:
		# Moving a tile counts as "the user has acknowledged it" — drop
		# the freshly-imported NEW badge.
		if typeof(rec) == TYPE_DICTIONARY and rec.has("is_new"):
			rec.erase("is_new")
		tiles[dst_bt].append(rec)
	return remap


## Remove `src_indices` from `tiles[src_bt]` and return them.
##
## Returns:
##   { "items": Array of tile records (in ascending src_idx order),
##     "remap": Dictionary mapping every original src_idx to where it
##              ended up — moved tiles map to {"bt": dst_bt_hint,
##              "idx": <next slot>}, survivors map to {"bt": src_bt,
##              "idx": <compacted>}.
##     "moved_indices": Array of src indices that were removed,
##                      ascending (for callers that want to know).
##   }
##
## `dst_bt_hint` is just used to fill the remap's `bt` for moved tiles —
## callers that aren't moving into another tile bucket (e.g. tile→actor)
## can ignore that part of the remap.
func _pop_tiles(src_bt: int, src_indices: Array, dst_bt_hint: int) -> Dictionary:
	var remap: Dictionary = {}
	var items: Array = []
	if not tiles.has(src_bt) or src_indices.is_empty():
		var n2: int = get_tile_count(src_bt)
		for i in range(n2):
			remap[i] = {"bt": src_bt, "idx": i}
		return {"remap": remap, "items": items, "moved_indices": []}

	var moved_set: Dictionary = {}
	for i in src_indices:
		moved_set[int(i)] = true
	var moved_asc: Array = moved_set.keys()
	moved_asc.sort()

	var src_arr: Array = tiles[src_bt]
	var src_count: int = src_arr.size()
	var dst_count: int = get_tile_count(dst_bt_hint)

	var dst_running: int = dst_count
	var stay_running: int = 0
	for old_i in range(src_count):
		if moved_set.has(old_i):
			remap[old_i] = {"bt": dst_bt_hint, "idx": dst_running}
			dst_running += 1
		else:
			remap[old_i] = {"bt": src_bt, "idx": stay_running}
			stay_running += 1

	# Capture items in ascending src order (so remap idx values line up),
	# then pop in descending order so earlier-index removals don't shift
	# the indices we're still about to pop.
	for old_i in moved_asc:
		if old_i >= 0 and old_i < src_arr.size():
			items.append(src_arr[old_i])
	var moved_desc: Array = moved_asc.duplicate()
	moved_desc.reverse()
	for old_i in moved_desc:
		if old_i >= 0 and old_i < src_arr.size():
			src_arr.remove_at(old_i)

	return {"remap": remap, "items": items, "moved_indices": moved_asc}


## Add `image` as a brand-new actor at the next available index.
##
## Returns the new actor index. Caller is responsible for keeping its own
## parallel `actor_names` / `actor_types` arrays in sync — those live in the
## level editor, not the library.
##
## The image is wrapped as a single-frame "Idle" anim resized to
## ACTOR_SPRITE_SIZE. This isn't a full-quality character sprite (no walk
## cycle etc.) but it's enough to PLACE on the level and visually identify.
func add_tile_as_actor(image: Image, actor_name: String, actor_type: String) -> int:
	# Find next free actor index (actor_sprites is sparse; use max+1).
	var next_idx: int = 0
	for k in actor_sprites.keys():
		if typeof(k) == TYPE_INT and int(k) >= next_idx:
			next_idx = int(k) + 1
	add_tile_as_actor_at(next_idx, image, actor_name, actor_type)
	return next_idx


## Same as `add_tile_as_actor` but writes at a caller-supplied index. Used
## by the level editor so its `actor_names`/`actor_types` arrays stay in
## lockstep with `actor_sprites` keys.
func add_tile_as_actor_at(actor_index: int, image: Image, actor_name: String, actor_type: String) -> void:
	var img := image
	if img.get_width() != ACTOR_SPRITE_SIZE or img.get_height() != ACTOR_SPRITE_SIZE:
		img = img.duplicate()
		img.resize(ACTOR_SPRITE_SIZE, ACTOR_SPRITE_SIZE, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	actor_sprites[actor_index] = {
		"name": actor_name,
		"type": actor_type,
		"anims": {"Idle": [img]},
		"frames": [img],
		"image": img,
		"texture": tex,
	}


## Remove `src_indices` from `tiles[src_bt]` and discard them entirely.
## Returns the same remap dict shape as `bulk_move_tiles` so callers can
## fix up references in placed cells. Removed tiles map to {"bt": -1,
## "idx": -1} so callers can detect dead refs.
func remove_tiles(src_bt: int, src_indices: Array) -> Dictionary:
	var pop_result := _pop_tiles(src_bt, src_indices, src_bt)
	# Rewrite the "moved" entries to sentinel — they're gone, not relocated.
	var moved_set: Dictionary = {}
	for i in pop_result["moved_indices"]:
		moved_set[int(i)] = true
	var remap: Dictionary = pop_result["remap"]
	for k in remap.keys():
		if moved_set.has(k):
			remap[k] = {"bt": -1, "idx": -1}
	return remap


## Get actor sprite texture (thumbnail of first frame)
func get_actor_texture(actor_index: int) -> ImageTexture:
	if not actor_sprites.has(actor_index):
		return null
	return actor_sprites[actor_index].get("texture", null)


## Get actor sprite image — first frame (for thumbnails / backward compat)
func get_actor_image(actor_index: int) -> Image:
	if not actor_sprites.has(actor_index):
		return null
	var anims: Dictionary = actor_sprites[actor_index].get("anims", {})
	if anims.size() > 0:
		var first_anim: Array = anims[anims.keys()[0]]
		if first_anim.size() > 0:
			return first_anim[0]
	var frames: Array = actor_sprites[actor_index].get("frames", [])
	if frames.size() > 0:
		return frames[0]
	return actor_sprites[actor_index].get("image", null)


## Get a frame from a specific named animation
func get_actor_anim_frame(actor_index: int, anim_name: String, frame_index: int) -> Image:
	if not actor_sprites.has(actor_index):
		return null
	var anims: Dictionary = actor_sprites[actor_index].get("anims", {})
	if anims.has(anim_name):
		var frames: Array = anims[anim_name]
		if frame_index >= 0 and frame_index < frames.size():
			return frames[frame_index]
	return null


## Get frame from default (first) animation — backward compat
func get_actor_frame(actor_index: int, frame_index: int) -> Image:
	if not actor_sprites.has(actor_index):
		return null
	var anims: Dictionary = actor_sprites[actor_index].get("anims", {})
	if anims.size() > 0:
		var first_frames: Array = anims[anims.keys()[0]]
		if frame_index >= 0 and frame_index < first_frames.size():
			return first_frames[frame_index]
	var frames: Array = actor_sprites[actor_index].get("frames", [])
	if frame_index >= 0 and frame_index < frames.size():
		return frames[frame_index]
	return null


## Get total frame count of default (first) animation
func get_actor_frame_count(actor_index: int) -> int:
	if not actor_sprites.has(actor_index):
		return 0
	var anims: Dictionary = actor_sprites[actor_index].get("anims", {})
	if anims.size() > 0:
		return anims[anims.keys()[0]].size()
	return actor_sprites[actor_index].get("frames", []).size()


## Get frames from the default (first) animation — backward compat
func get_actor_frames(actor_index: int) -> Array:
	if not actor_sprites.has(actor_index):
		return []
	var anims: Dictionary = actor_sprites[actor_index].get("anims", {})
	if anims.size() > 0:
		return anims[anims.keys()[0]]
	return actor_sprites[actor_index].get("frames", [])


## Get full animations dictionary { name: [Image,...], ... }
func get_actor_anims(actor_index: int) -> Dictionary:
	if not actor_sprites.has(actor_index):
		return {}
	var anims: Dictionary = actor_sprites[actor_index].get("anims", {})
	if anims.size() == 0:
		# Migrate flat frames to anims
		var frames: Array = actor_sprites[actor_index].get("frames", [])
		if frames.size() > 0:
			anims = {"Idle": frames}
			actor_sprites[actor_index]["anims"] = anims
	return anims


## Get ordered list of animation names
func get_actor_anim_names(actor_index: int) -> Array:
	var anims := get_actor_anims(actor_index)
	return anims.keys()


## Get frames for a specific named animation
func get_actor_anim_frames(actor_index: int, anim_name: String) -> Array:
	var anims := get_actor_anims(actor_index)
	if anims.has(anim_name):
		return anims[anim_name]
	return []


## Generate/regenerate an actor sprite by type
func ensure_actor_sprite(actor_index: int, actor_name: String, actor_type: String) -> void:
	if actor_sprites.has(actor_index):
		if actor_sprites[actor_index].get("type", "") == actor_type:
			# Migrate legacy formats to anims dict
			if not actor_sprites[actor_index].has("anims") or actor_sprites[actor_index]["anims"].size() == 0:
				var old_frames = actor_sprites[actor_index].get("frames", [])
				if old_frames.size() > 0:
					actor_sprites[actor_index]["anims"] = {"Idle": old_frames}
				else:
					var old_img = actor_sprites[actor_index].get("image", null)
					if old_img:
						actor_sprites[actor_index]["anims"] = {"Idle": [old_img]}
					else:
						var c = ACTOR_TYPE_COLORS.get(actor_type, Color(0.5, 0.5, 0.5))
						actor_sprites[actor_index]["anims"] = {"Idle": [_generate_character_sprite(actor_type, c)]}
				actor_sprites[actor_index]["frames"] = actor_sprites[actor_index]["anims"]["Idle"]
			return
	var color = ACTOR_TYPE_COLORS.get(actor_type, Color(0.5, 0.5, 0.5))
	var anims = _generate_character_animations(actor_type, color)
	var first_key: String = anims.keys()[0]
	var first_frames: Array = anims[first_key]
	var first_img: Image = first_frames[0]
	var tex = ImageTexture.create_from_image(first_img)
	actor_sprites[actor_index] = {
		"name": actor_name,
		"type": actor_type,
		"anims": anims,
		"frames": first_frames,
		"image": first_img,
		"texture": tex,
	}


## Update an actor's sprite image (frame 0 of first anim — backward compat)
func update_actor_sprite(actor_index: int, new_image: Image) -> void:
	if not actor_sprites.has(actor_index):
		return
	if new_image.get_width() != ACTOR_SPRITE_SIZE or new_image.get_height() != ACTOR_SPRITE_SIZE:
		new_image = new_image.duplicate()
		new_image.resize(ACTOR_SPRITE_SIZE, ACTOR_SPRITE_SIZE, Image.INTERPOLATE_NEAREST)
	var anims: Dictionary = actor_sprites[actor_index].get("anims", {})
	if anims.size() == 0:
		actor_sprites[actor_index]["anims"] = {"Idle": [new_image]}
	else:
		var first_key: String = anims.keys()[0]
		if anims[first_key].size() == 0:
			actor_sprites[actor_index]["anims"][first_key] = [new_image]
		else:
			actor_sprites[actor_index]["anims"][first_key][0] = new_image
	actor_sprites[actor_index]["frames"] = actor_sprites[actor_index]["anims"][actor_sprites[actor_index]["anims"].keys()[0]]
	actor_sprites[actor_index]["image"] = new_image
	actor_sprites[actor_index]["texture"] = ImageTexture.create_from_image(new_image)


## Replace ALL frames for the first animation (backward compat)
func update_actor_frames(actor_index: int, frames: Array) -> void:
	var anims := get_actor_anims(actor_index)
	var first_key: String = "Idle" if anims.size() == 0 else anims.keys()[0]
	var clean_frames := _clean_frames(frames)
	if clean_frames.size() == 0:
		return
	if not actor_sprites.has(actor_index):
		return
	if not actor_sprites[actor_index].has("anims"):
		actor_sprites[actor_index]["anims"] = {}
	actor_sprites[actor_index]["anims"][first_key] = clean_frames
	_refresh_actor_thumbnail(actor_index)


## Replace the FULL animations dictionary { name: [Image,...], ... }
func update_actor_anims(actor_index: int, anims: Dictionary) -> void:
	if not actor_sprites.has(actor_index):
		return
	var clean: Dictionary = {}
	for anim_name in anims:
		var cleaned := _clean_frames(anims[anim_name])
		if cleaned.size() > 0:
			clean[anim_name] = cleaned
	if clean.size() == 0:
		return
	actor_sprites[actor_index]["anims"] = clean
	_refresh_actor_thumbnail(actor_index)


## Ensure all frames are correct size
func _clean_frames(frames: Array) -> Array:
	var clean: Array = []
	for f in frames:
		var img: Image = f
		if img.get_width() != ACTOR_SPRITE_SIZE or img.get_height() != ACTOR_SPRITE_SIZE:
			img = img.duplicate()
			img.resize(ACTOR_SPRITE_SIZE, ACTOR_SPRITE_SIZE, Image.INTERPOLATE_NEAREST)
		clean.append(img)
	return clean


## Refresh thumbnail image+texture from first frame of first anim
func _refresh_actor_thumbnail(actor_index: int) -> void:
	if not actor_sprites.has(actor_index):
		return
	var anims: Dictionary = actor_sprites[actor_index].get("anims", {})
	if anims.size() == 0:
		return
	var first_frames: Array = anims[anims.keys()[0]]
	actor_sprites[actor_index]["frames"] = first_frames
	if first_frames.size() > 0:
		actor_sprites[actor_index]["image"] = first_frames[0]
		actor_sprites[actor_index]["texture"] = ImageTexture.create_from_image(first_frames[0])


## Get total tile count across all types
func get_total_tile_count() -> int:
	var total = 0
	for bt in tiles:
		total += tiles[bt].size()
	return total


# ═══════════════════════════════════════════════════════════════
# PROCEDURAL TILE GENERATION
# ═══════════════════════════════════════════════════════════════

func _generate_all_tiles() -> void:
	tiles.clear()
	# Empty type gets no tiles (it's the eraser)
	tiles[BLOCK_EMPTY] = []

	# Barrier tiles (solid walls/floors/platforms)
	tiles[BLOCK_BARRIER] = []
	_gen_barrier_tiles()

	# Ladder tiles
	tiles[BLOCK_LADDER] = []
	_gen_ladder_tiles()

	# Deadly tiles (spikes, lava, etc.)
	tiles[BLOCK_DEADLY] = []
	_gen_deadly_tiles()

	# Background tiles (decorative)
	tiles[BLOCK_BACKGROUND] = []
	_gen_background_tiles()

	# Teleport tiles
	tiles[BLOCK_TELEPORT] = []
	_gen_teleport_tiles()

	# Switch tiles
	tiles[BLOCK_SWITCH] = []
	_gen_switch_tiles()

	# Goal tiles (level-exit flag / door / castle gate)
	tiles[BLOCK_GOAL] = []
	_gen_goal_tiles()


# ─── Barrier Tiles ───────────────────────────────────────────

func _gen_barrier_tiles() -> void:
	var S = TILE_SIZE
	var base = BLOCK_COLORS[BLOCK_BARRIER]

	# 1. Solid stone block
	var img = _create_tile()
	_fill_rect(img, 0, 0, S, S, base)
	_draw_border(img, base.darkened(0.3))
	# Brick pattern: horizontal mortar lines
	var mortar = base.darkened(0.4)
	for y in [4, 9, 14]:
		for x in range(S):
			img.set_pixel(x, y, mortar)
	# Vertical mortar (offset per row)
	for x in [4, 13]:
		for y in range(0, 4):
			img.set_pixel(x, y, mortar)
	for x in [8]:
		for y in range(5, 9):
			img.set_pixel(x, y, mortar)
	for x in [4, 13]:
		for y in range(10, 14):
			img.set_pixel(x, y, mortar)
	for x in [8]:
		for y in range(15, S):
			img.set_pixel(x, y, mortar)
	_add_tile(BLOCK_BARRIER, "Brick Wall", img)

	# 2. Stone platform (flat top, rounded)
	img = _create_tile()
	_fill_rect(img, 0, 2, S, S - 2, base.darkened(0.1))
	_fill_rect(img, 0, 0, S, 3, base.lightened(0.15))
	_draw_border(img, base.darkened(0.35))
	# Subtle cracks
	for y in [6, 11]:
		for x in range(3, 8):
			img.set_pixel(x, y, base.darkened(0.2))
	_add_tile(BLOCK_BARRIER, "Stone Platform", img)

	# 3. Dirt block
	img = _create_tile()
	var dirt = Color(0.45, 0.32, 0.18)
	_fill_rect(img, 0, 0, S, S, dirt)
	# Grass top
	var grass = Color(0.28, 0.62, 0.22)
	_fill_rect(img, 0, 0, S, 4, grass)
	for x in range(S):
		if (x + 1) % 3 == 0:
			img.set_pixel(x, 4, grass.darkened(0.15))
	# Speckles in dirt
	_scatter_pixels(img, 5, S - 1, dirt.lightened(0.15), 8)
	_scatter_pixels(img, 5, S - 1, dirt.darkened(0.15), 6)
	_draw_border(img, dirt.darkened(0.3))
	_add_tile(BLOCK_BARRIER, "Grass & Dirt", img)

	# 4. Metal plate
	img = _create_tile()
	var metal = Color(0.55, 0.58, 0.65)
	_fill_rect(img, 0, 0, S, S, metal)
	# Rivets in corners
	var rivet = metal.lightened(0.3)
	for pos in [Vector2i(2, 2), Vector2i(S-3, 2), Vector2i(2, S-3), Vector2i(S-3, S-3)]:
		img.set_pixel(pos.x, pos.y, rivet)
		img.set_pixel(pos.x + 1, pos.y, rivet)
		img.set_pixel(pos.x, pos.y + 1, rivet)
		img.set_pixel(pos.x + 1, pos.y + 1, rivet)
	# Center cross pattern
	for i in range(6, 12):
		img.set_pixel(i, S / 2, metal.darkened(0.15))
		img.set_pixel(S / 2, i, metal.darkened(0.15))
	_draw_border(img, metal.darkened(0.35))
	_add_tile(BLOCK_BARRIER, "Metal Plate", img)

	# 5. Ice block
	img = _create_tile()
	var ice = Color(0.65, 0.82, 0.95)
	_fill_rect(img, 0, 0, S, S, ice)
	# Shine streaks
	for y in range(3, 8):
		img.set_pixel(3, y, ice.lightened(0.25))
	for y in range(6, 12):
		img.set_pixel(7, y, ice.lightened(0.2))
	# Frost crystals
	_scatter_pixels(img, 0, S - 1, ice.lightened(0.15), 10)
	_draw_border(img, ice.darkened(0.2))
	_add_tile(BLOCK_BARRIER, "Ice Block", img)

	# 6. Wood plank
	img = _create_tile()
	var wood = Color(0.55, 0.38, 0.20)
	_fill_rect(img, 0, 0, S, S, wood)
	# Grain lines
	for y in [3, 7, 11, 15]:
		for x in range(S):
			img.set_pixel(x, y, wood.darkened(0.12))
	# Knot
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var px = 12 + dx
			var py = 9 + dy
			if px >= 0 and px < S and py >= 0 and py < S:
				img.set_pixel(px, py, wood.darkened(0.25))
	_draw_border(img, wood.darkened(0.35))
	_add_tile(BLOCK_BARRIER, "Wood Plank", img)

	# 7. Sand block
	img = _create_tile()
	var sand = Color(0.82, 0.72, 0.48)
	_fill_rect(img, 0, 0, S, S, sand)
	_scatter_pixels(img, 0, S - 1, sand.lightened(0.12), 12)
	_scatter_pixels(img, 0, S - 1, sand.darkened(0.10), 8)
	_draw_border(img, sand.darkened(0.25))
	_add_tile(BLOCK_BARRIER, "Sand Block", img)

	# 8. Cobblestone — irregular rounded stones
	img = _create_tile()
	var cobble = Color(0.45, 0.43, 0.40)
	_fill_rect(img, 0, 0, S, S, cobble)
	var cmort = cobble.darkened(0.30)
	_fill_rect(img, 1, 1, 7, 5, cobble.lightened(0.08))
	_fill_rect(img, 9, 1, 8, 4, cobble.darkened(0.05))
	_fill_rect(img, 0, 7, 5, 5, cobble.darkened(0.08))
	_fill_rect(img, 6, 6, 6, 5, cobble.lightened(0.05))
	_fill_rect(img, 13, 6, 5, 6, cobble.darkened(0.03))
	_fill_rect(img, 1, 13, 8, 4, cobble.lightened(0.06))
	_fill_rect(img, 10, 13, 7, 4, cobble.darkened(0.06))
	for x in range(S):
		img.set_pixel(x, 0, cmort); img.set_pixel(x, 6, cmort); img.set_pixel(x, 12, cmort)
	for y in range(0, 6): img.set_pixel(8, y, cmort)
	for y in range(6, 12): img.set_pixel(5, y, cmort); img.set_pixel(12, y, cmort)
	for y in range(12, S): img.set_pixel(9, y, cmort)
	_add_tile(BLOCK_BARRIER, "Cobblestone", img)

	# 9. Castle Wall — large stone blocks with mortar
	img = _create_tile()
	var castle = Color(0.42, 0.40, 0.38)
	_fill_rect(img, 0, 0, S, S, castle)
	var cmort2 = castle.darkened(0.35)
	_fill_rect(img, 1, 1, 8, 8, castle.lightened(0.06))
	_fill_rect(img, 10, 1, 7, 8, castle.darkened(0.04))
	_fill_rect(img, 1, 10, 5, 7, castle.darkened(0.06))
	_fill_rect(img, 7, 10, 5, 7, castle.lightened(0.04))
	_fill_rect(img, 13, 10, 4, 7, castle.darkened(0.02))
	for x in range(S): img.set_pixel(x, 0, cmort2); img.set_pixel(x, 9, cmort2)
	for y in range(0, 9): img.set_pixel(0, y, cmort2); img.set_pixel(9, y, cmort2)
	for y in range(9, S): img.set_pixel(0, y, cmort2); img.set_pixel(6, y, cmort2); img.set_pixel(12, y, cmort2)
	_draw_border(img, castle.darkened(0.4))
	_add_tile(BLOCK_BARRIER, "Castle Wall", img)

	# 10. Mossy Stone — grey stone with green moss patches
	img = _create_tile()
	var mstone = Color(0.48, 0.48, 0.45)
	_fill_rect(img, 0, 0, S, S, mstone)
	_draw_border(img, mstone.darkened(0.3))
	_scatter_pixels(img, 0, S - 1, mstone.lightened(0.08), 8)
	var moss = Color(0.25, 0.50, 0.18)
	_fill_rect(img, 0, 14, 6, 4, moss)
	_fill_rect(img, 12, 0, 6, 5, moss.darkened(0.1))
	_fill_rect(img, 0, 0, 4, 3, moss.lightened(0.05))
	for pos in [Vector2i(7, 15), Vector2i(8, 16), Vector2i(14, 5), Vector2i(3, 3)]:
		if pos.x < S and pos.y < S: img.set_pixel(pos.x, pos.y, moss.lightened(0.15))
	_add_tile(BLOCK_BARRIER, "Mossy Stone", img)

	# 11. Steel Girder — I-beam cross section
	img = _create_tile()
	var girder = Color(0.50, 0.52, 0.58)
	_fill_rect(img, 0, 0, S, S, Color(0.20, 0.20, 0.25))
	# Top flange
	_fill_rect(img, 1, 1, S - 2, 4, girder)
	_fill_rect(img, 1, 1, S - 2, 1, girder.lightened(0.2))
	# Web (vertical center)
	_fill_rect(img, 6, 5, 6, 8, girder.darkened(0.08))
	# Bottom flange
	_fill_rect(img, 1, 13, S - 2, 4, girder)
	_fill_rect(img, 1, 16, S - 2, 1, girder.darkened(0.15))
	# Rivets
	var riv = girder.lightened(0.3)
	for pos in [Vector2i(3, 2), Vector2i(14, 2), Vector2i(3, 15), Vector2i(14, 15)]:
		img.set_pixel(pos.x, pos.y, riv)
	_add_tile(BLOCK_BARRIER, "Steel Girder", img)

	# 12. Concrete — modern flat with hairline cracks
	img = _create_tile()
	var conc = Color(0.62, 0.60, 0.58)
	_fill_rect(img, 0, 0, S, S, conc)
	var crack = conc.darkened(0.18)
	for y in range(3, 10): img.set_pixel(5 + (y % 2), y, crack)
	for y in range(8, 15): img.set_pixel(12 - (y % 3), y, crack)
	img.set_pixel(6, 10, crack); img.set_pixel(7, 11, crack)
	_scatter_pixels(img, 0, S - 1, conc.lightened(0.06), 6)
	_scatter_pixels(img, 0, S - 1, conc.darkened(0.06), 6)
	_draw_border(img, conc.darkened(0.2))
	_add_tile(BLOCK_BARRIER, "Concrete", img)

	# 13. Marble — white/cream with grey veins
	img = _create_tile()
	var marble = Color(0.88, 0.86, 0.82)
	_fill_rect(img, 0, 0, S, S, marble)
	var vein = Color(0.62, 0.60, 0.58)
	for i in range(S):
		var vy = 3 + (i * 7 + 2) % 5
		if vy < S: img.set_pixel(i, vy, vein)
		var vy2 = 10 + (i * 5 + 3) % 4
		if vy2 < S: img.set_pixel(i, vy2, vein)
	var shine = marble.lightened(0.12)
	_fill_rect(img, 2, 2, 3, 1, shine)
	_fill_rect(img, 13, 1, 2, 1, shine)
	_draw_border(img, marble.darkened(0.15))
	_add_tile(BLOCK_BARRIER, "Marble", img)

	# 14. Glass Block — translucent blue with highlight
	img = _create_tile()
	var glass = Color(0.55, 0.72, 0.85, 0.85)
	_fill_rect(img, 0, 0, S, S, glass)
	_draw_border(img, Color(0.40, 0.55, 0.70))
	# Inner border
	_fill_rect(img, 2, 2, S - 4, S - 4, glass.lightened(0.08))
	# Shine streak
	for i in range(5):
		img.set_pixel(3 + i, 3 + i, Color(0.90, 0.95, 1.0, 0.9))
		img.set_pixel(4 + i, 3 + i, Color(0.90, 0.95, 1.0, 0.7))
	_add_tile(BLOCK_BARRIER, "Glass Block", img)

	# 15. Chain Link Fence — diamond mesh pattern
	img = _create_tile()
	var fence_bg = Color(0.30, 0.42, 0.55)
	_fill_rect(img, 0, 0, S, S, fence_bg)
	var wire = Color(0.60, 0.62, 0.65)
	for y in range(S):
		for x in range(S):
			if (x + y) % 4 == 0 or (x - y + 20) % 4 == 0:
				img.set_pixel(x, y, wire)
	# Posts at edges
	_fill_rect(img, 0, 0, 2, S, Color(0.50, 0.52, 0.55))
	_fill_rect(img, S - 2, 0, 2, S, Color(0.50, 0.52, 0.55))
	_add_tile(BLOCK_BARRIER, "Chain Link", img)

	# ─── Question Block ─────────────────────────────────────────
	# Mario-style "?" block — solid barrier tile that, when bumped from
	# below by the player, awards a coin (and turns gray / "used"). The
	# `is_question` flag flows into the level builder so it knows to emit
	# a QuestionArea Area2D and wire the bump signal.
	img = _create_tile()
	var qb_yellow = Color(0.95, 0.75, 0.18)
	var qb_dark = Color(0.65, 0.45, 0.05)
	var qb_hl = Color(1.0, 0.92, 0.45)
	# Body
	_fill_rect(img, 0, 0, S, S, qb_yellow)
	# Beveled border
	for x in range(S):
		img.set_pixel(x, 0, qb_hl)
		img.set_pixel(x, S - 1, qb_dark)
	for y in range(S):
		img.set_pixel(0, y, qb_hl)
		img.set_pixel(S - 1, y, qb_dark)
	# "?" glyph drawn as pixel pattern (centered ~5×9)
	# rows are y from top; using TILE_SIZE 18, draw at x=6..12, y=3..14
	var q = qb_dark
	# Top arc
	img.set_pixel(7, 3, q); img.set_pixel(8, 3, q); img.set_pixel(9, 3, q); img.set_pixel(10, 3, q)
	img.set_pixel(6, 4, q); img.set_pixel(11, 4, q)
	img.set_pixel(11, 5, q)
	img.set_pixel(10, 6, q)
	img.set_pixel(9, 7, q)
	img.set_pixel(8, 8, q)
	img.set_pixel(8, 9, q)
	# Gap
	# Dot
	img.set_pixel(8, 12, q); img.set_pixel(8, 13, q)
	# Corner studs (Mario brick stud look)
	img.set_pixel(2, 2, qb_hl); img.set_pixel(S - 3, 2, qb_hl)
	img.set_pixel(2, S - 3, qb_dark); img.set_pixel(S - 3, S - 3, qb_dark)
	_add_tile_ex(BLOCK_BARRIER, "Question Block", img, {"is_question": true})

	# Used (already-bumped) variant — gray, for visual reference. Authors
	# can place this directly if they want pre-spent ?-blocks.
	img = _create_tile()
	var ub_gray = Color(0.55, 0.50, 0.45)
	var ub_dark = Color(0.30, 0.27, 0.24)
	var ub_hl = Color(0.75, 0.70, 0.65)
	_fill_rect(img, 0, 0, S, S, ub_gray)
	for x in range(S):
		img.set_pixel(x, 0, ub_hl)
		img.set_pixel(x, S - 1, ub_dark)
	for y in range(S):
		img.set_pixel(0, y, ub_hl)
		img.set_pixel(S - 1, y, ub_dark)
	# Bolt heads in corners
	img.set_pixel(3, 3, ub_dark); img.set_pixel(4, 3, ub_dark)
	img.set_pixel(S - 5, 3, ub_dark); img.set_pixel(S - 4, 3, ub_dark)
	img.set_pixel(3, S - 4, ub_dark); img.set_pixel(4, S - 4, ub_dark)
	img.set_pixel(S - 5, S - 4, ub_dark); img.set_pixel(S - 4, S - 4, ub_dark)
	_add_tile(BLOCK_BARRIER, "Used Block", img)

	# ─── One-Way Platforms ──────────────────────────────────────
	# Thin platforms the player can jump up through but land on top of.
	# The `one_way` flag flows through the builder to set
	# `one_way_collision = true` on the tile's CollisionShape2D.
	# Mario / Celeste / Hollow Knight all rely on these as a Tier-1
	# platforming primitive.

	# One-way wooden platform — visible top plank only, transparent below
	img = _create_tile()
	# Top plank
	var ow_plank = Color(0.55, 0.38, 0.20)
	_fill_rect(img, 0, 0, S, 5, ow_plank)
	# Wood grain
	for x in range(S):
		if x % 4 == 0: img.set_pixel(x, 1, ow_plank.darkened(0.2))
		if x % 5 == 2: img.set_pixel(x, 3, ow_plank.darkened(0.3))
	# Top highlight
	for x in range(S): img.set_pixel(x, 0, ow_plank.lightened(0.25))
	# Bottom edge shadow
	for x in range(S): img.set_pixel(x, 4, ow_plank.darkened(0.4))
	_add_tile_ex(BLOCK_BARRIER, "One-Way Wood", img, {"one_way": true})

	# One-way grass platform — green grassy thin platform
	img = _create_tile()
	var ow_dirt = Color(0.45, 0.30, 0.18)
	var ow_grass = Color(0.30, 0.70, 0.25)
	_fill_rect(img, 0, 0, S, 6, ow_dirt)
	_fill_rect(img, 0, 0, S, 3, ow_grass)
	# Grass blades highlight
	for x in [1, 4, 8, 11, 14, 16]:
		if x < S: img.set_pixel(x, 0, ow_grass.lightened(0.3))
	# Bottom edge
	for x in range(S): img.set_pixel(x, 5, ow_dirt.darkened(0.3))
	_add_tile_ex(BLOCK_BARRIER, "One-Way Grass", img, {"one_way": true})

	# One-way cloud platform — fluffy white cloud (kid-friendly)
	img = _create_tile()
	var ow_cloud = Color(0.95, 0.97, 1.0)
	var ow_cloud_shadow = Color(0.75, 0.80, 0.90)
	# Cloud body
	_fill_rect(img, 1, 1, S - 2, 5, ow_cloud)
	# Bumpy top
	for x in [3, 7, 11, 14]:
		if x < S - 1:
			img.set_pixel(x, 0, ow_cloud)
			img.set_pixel(x + 1, 0, ow_cloud)
	# Bottom shadow
	for x in range(1, S - 1): img.set_pixel(x, 5, ow_cloud_shadow)
	_add_tile_ex(BLOCK_BARRIER, "One-Way Cloud", img, {"one_way": true})


# ─── Ladder Tiles ────────────────────────────────────────────

func _gen_ladder_tiles() -> void:
	var S = TILE_SIZE
	var base = BLOCK_COLORS[BLOCK_LADDER]

	# 1. Wood ladder
	var img = _create_tile()
	var brown = Color(0.50, 0.35, 0.18)
	# Rails
	_fill_rect(img, 2, 0, 3, S, brown)
	_fill_rect(img, S - 5, 0, 3, S, brown)
	# Rungs
	for y in [3, 8, 13]:
		_fill_rect(img, 2, y, S - 4, 2, brown.lightened(0.1))
	_add_tile(BLOCK_LADDER, "Wood Ladder", img)

	# 2. Metal ladder
	img = _create_tile()
	var gray = Color(0.55, 0.58, 0.65)
	_fill_rect(img, 3, 0, 2, S, gray)
	_fill_rect(img, S - 5, 0, 2, S, gray)
	for y in [2, 7, 12]:
		_fill_rect(img, 3, y, S - 6, 2, gray.lightened(0.15))
	_add_tile(BLOCK_LADDER, "Metal Ladder", img)

	# 3. Vine/rope
	img = _create_tile()
	var vine = Color(0.22, 0.55, 0.18)
	# Twisting vine
	for y in range(S):
		var cx = S / 2 + int(sin(y * 0.8) * 2)
		for dx in range(-1, 2):
			var px = cx + dx
			if px >= 0 and px < S:
				img.set_pixel(px, y, vine)
	# Leaves
	for y in [3, 9, 15]:
		for dx in range(3):
			var px = S / 2 + 2 + dx
			if px < S:
				img.set_pixel(px, y, vine.lightened(0.2))
	_add_tile(BLOCK_LADDER, "Vine", img)

	# 4. Rope — thick twisted hemp rope
	img = _create_tile()
	var rope = Color(0.60, 0.48, 0.28)
	for y in range(S):
		var cx_r = S / 2 + int(sin(y * 1.2) * 1)
		for dx in range(-2, 3):
			var px = cx_r + dx
			if px >= 0 and px < S:
				var c = rope if absi(dx) < 2 else rope.darkened(0.15)
				img.set_pixel(px, y, c)
	# Twist marks
	for y in [2, 6, 10, 14]:
		var cx_t = S / 2 + int(sin(y * 1.2) * 1)
		if cx_t >= 1 and cx_t < S - 1:
			img.set_pixel(cx_t - 1, y, rope.lightened(0.15))
			img.set_pixel(cx_t + 1, y, rope.darkened(0.2))
	_add_tile(BLOCK_LADDER, "Rope", img)

	# 5. Chain — metal chain links
	img = _create_tile()
	var chain = Color(0.55, 0.55, 0.60)
	var chain_hi = chain.lightened(0.2)
	var chain_dk = chain.darkened(0.25)
	# Alternating oval links
	for link_y in [1, 7, 13]:
		# Each link is 6px tall oval
		_draw_circle_outline(img, S / 2, link_y + 3, 3, chain)
		_fill_rect(img, S / 2 - 1, link_y, 3, 1, chain_hi)
		_fill_rect(img, S / 2 - 1, link_y + 5, 3, 1, chain_dk)
	_add_tile(BLOCK_LADDER, "Chain", img)

	# 6. Bamboo Ladder — green bamboo poles with rungs
	img = _create_tile()
	var bamboo = Color(0.45, 0.62, 0.28)
	# Vertical poles
	_fill_rect(img, 3, 0, 3, S, bamboo)
	_fill_rect(img, S - 6, 0, 3, S, bamboo)
	# Pole highlights
	for y in range(S):
		img.set_pixel(4, y, bamboo.lightened(0.12))
		img.set_pixel(S - 5, y, bamboo.lightened(0.12))
	# Nodes (bamboo joints)
	for y in [0, 6, 12]:
		_fill_rect(img, 2, y, 5, 1, bamboo.darkened(0.2))
		_fill_rect(img, S - 7, y, 5, 1, bamboo.darkened(0.2))
	# Rungs
	for y in [3, 9, 15]:
		_fill_rect(img, 5, y, S - 10, 2, bamboo.darkened(0.1))
	_add_tile(BLOCK_LADDER, "Bamboo Ladder", img)

	# 7. Stone Steps — chunky carved stone steps
	img = _create_tile()
	var step_stone = Color(0.55, 0.55, 0.58)
	for i in range(4):
		var sy = i * 4 + 1
		_fill_rect(img, 1, sy, S - 2, 3, step_stone)
		_fill_rect(img, 1, sy, S - 2, 1, step_stone.lightened(0.2))
		_fill_rect(img, 1, sy + 2, S - 2, 1, step_stone.darkened(0.25))
	_add_tile(BLOCK_LADDER, "Stone Steps", img)

	# 8. Bone Ladder — pale bone-rails with rib rungs
	img = _create_tile()
	var bone = Color(0.92, 0.90, 0.78)
	_fill_rect(img, 2, 0, 2, S, bone)
	_fill_rect(img, S - 4, 0, 2, S, bone)
	# Knobby ends
	_fill_circle(img, 3, 1, 2, bone)
	_fill_circle(img, S - 3, 1, 2, bone)
	_fill_circle(img, 3, S - 2, 2, bone)
	_fill_circle(img, S - 3, S - 2, 2, bone)
	for y in [4, 9, 14]:
		_fill_rect(img, 4, y, S - 8, 1, bone.darkened(0.15))
	_add_tile(BLOCK_LADDER, "Bone Ladder", img)

	# 9. Tech Ladder — sci-fi cyan with glowing rungs
	img = _create_tile()
	var tech_dk = Color(0.18, 0.22, 0.28)
	var tech_glow = Color(0.30, 0.85, 1.00)
	_fill_rect(img, 2, 0, 3, S, tech_dk)
	_fill_rect(img, S - 5, 0, 3, S, tech_dk)
	for y in range(S):
		img.set_pixel(3, y, tech_dk.lightened(0.2))
		img.set_pixel(S - 4, y, tech_dk.lightened(0.2))
	for y in [3, 8, 13]:
		_fill_rect(img, 5, y, S - 10, 2, tech_glow)
		_fill_rect(img, 5, y - 1, S - 10, 1, tech_glow.darkened(0.3))
	_add_tile(BLOCK_LADDER, "Tech Ladder", img)

	# 10. Web — spider web stretched corner-to-corner
	img = _create_tile()
	var web = Color(0.85, 0.85, 0.90, 0.95)
	# Diagonals
	for i in range(S):
		img.set_pixel(i, i, web)
		img.set_pixel(i, S - 1 - i, web)
	# Vertical + horizontal centerlines
	for i in range(S):
		img.set_pixel(S / 2, i, web)
		img.set_pixel(i, S / 2, web)
	# Concentric rings
	for r in [3, 6]:
		_draw_circle_outline(img, S / 2, S / 2, r, web.darkened(0.05))
	_add_tile(BLOCK_LADDER, "Spider Web", img)

	# 11. Ice Ladder — translucent blue-white rungs
	img = _create_tile()
	var ice = Color(0.75, 0.92, 1.00)
	_fill_rect(img, 3, 0, 2, S, ice)
	_fill_rect(img, S - 5, 0, 2, S, ice)
	for y in range(S):
		img.set_pixel(3, y, ice.lightened(0.15))
	for y in [3, 8, 13]:
		_fill_rect(img, 3, y, S - 6, 2, ice.lightened(0.2))
		# Sparkle
		img.set_pixel(S / 2 + (1 if y % 2 == 0 else -1), y, Color(1, 1, 1))
	_add_tile(BLOCK_LADDER, "Ice Ladder", img)

	# 12. Climbing Net — woven rope mesh
	img = _create_tile()
	var net = Color(0.50, 0.40, 0.22)
	# Horizontal strands
	for y in [2, 6, 10, 14]:
		_fill_rect(img, 0, y, S, 1, net)
	# Vertical strands
	for x in [2, 6, 10, 14]:
		_fill_rect(img, x, 0, 1, S, net)
	# Knots
	for y in [2, 6, 10, 14]:
		for x in [2, 6, 10, 14]:
			img.set_pixel(x, y, net.lightened(0.15))
	_add_tile(BLOCK_LADDER, "Climbing Net", img)


# ─── Deadly Tiles ────────────────────────────────────────────

func _gen_deadly_tiles() -> void:
	var S = TILE_SIZE
	var base = BLOCK_COLORS[BLOCK_DEADLY]

	# 1. Spike pit (spikes pointing up)
	var img = _create_tile()
	var spike_clr = Color(0.75, 0.18, 0.18)
	# Base
	_fill_rect(img, 0, S - 4, S, 4, spike_clr.darkened(0.3))
	# Spikes
	for sx in [2, 6, 10, 14]:
		for h in range(10):
			var w = maxi(1, 3 - h / 3)
			for dx in range(-w / 2, w / 2 + 1):
				var px = sx + dx
				var py = S - 5 - h
				if px >= 0 and px < S and py >= 0:
					img.set_pixel(px, py, spike_clr.lightened(float(h) * 0.02))
	_add_tile(BLOCK_DEADLY, "Spikes Up", img)

	# 2. Lava pool
	img = _create_tile()
	var lava = Color(0.95, 0.35, 0.05)
	_fill_rect(img, 0, 0, S, S, lava)
	# Darker swirls
	_scatter_pixels(img, 0, S - 1, lava.darkened(0.25), 15)
	# Bright spots
	_scatter_pixels(img, 0, S - 1, Color(1.0, 0.7, 0.2), 8)
	_draw_border(img, lava.darkened(0.4))
	_add_tile(BLOCK_DEADLY, "Lava", img)

	# 3. Electric fence
	img = _create_tile()
	var elec = Color(0.9, 0.9, 0.15)
	# Posts
	_fill_rect(img, 1, 0, 2, S, Color(0.45, 0.45, 0.50))
	_fill_rect(img, S - 3, 0, 2, S, Color(0.45, 0.45, 0.50))
	# Wires with zaps
	for y in [4, 9, 14]:
		for x in range(3, S - 3):
			img.set_pixel(x, y, elec)
		# Spark
		img.set_pixel(S / 2, y - 1, Color(1, 1, 0.8))
		img.set_pixel(S / 2, y + 1, Color(1, 1, 0.8))
	_add_tile(BLOCK_DEADLY, "Electric Fence", img)

	# 4. Acid pool
	img = _create_tile()
	var acid = Color(0.40, 0.85, 0.15)
	_fill_rect(img, 0, 0, S, S, acid)
	_scatter_pixels(img, 0, S - 1, acid.lightened(0.2), 10)
	_scatter_pixels(img, 0, S - 1, acid.darkened(0.15), 8)
	# Bubbles
	for pos in [Vector2i(5, 4), Vector2i(12, 8), Vector2i(8, 14)]:
		img.set_pixel(pos.x, pos.y, Color(0.7, 1.0, 0.5, 0.9))
		img.set_pixel(pos.x + 1, pos.y, Color(0.7, 1.0, 0.5, 0.9))
		img.set_pixel(pos.x, pos.y + 1, Color(0.7, 1.0, 0.5, 0.9))
	_draw_border(img, acid.darkened(0.3))
	_add_tile(BLOCK_DEADLY, "Acid Pool", img)

	# 5. Fire
	img = _create_tile()
	# Dark base
	_fill_rect(img, 0, S - 3, S, 3, Color(0.3, 0.1, 0.0))
	# Flame shapes
	var flame_colors = [Color(0.9, 0.2, 0.0), Color(1.0, 0.5, 0.0), Color(1.0, 0.8, 0.1)]
	for fx in [3, 7, 11, 15]:
		for h in range(12):
			var w = maxi(1, 3 - h / 4)
			var ci = mini(h / 4, 2)
			for dx in range(-w / 2, w / 2 + 1):
				var px = fx + dx
				var py = S - 4 - h
				if px >= 0 and px < S and py >= 0:
					img.set_pixel(px, py, flame_colors[ci])
	_add_tile(BLOCK_DEADLY, "Fire", img)

	# 6. Saw Blade — spinning circular saw
	img = _create_tile()
	var saw_bg = Color(0.15, 0.12, 0.12)
	_fill_rect(img, 0, 0, S, S, saw_bg)
	var saw_metal = Color(0.65, 0.68, 0.72)
	_fill_circle(img, S / 2, S / 2, 7, saw_metal)
	_fill_circle(img, S / 2, S / 2, 2, Color(0.40, 0.42, 0.45))
	# Teeth around edge
	for angle_i in range(8):
		var ax = S / 2 + int(cos(angle_i * PI / 4.0) * 8)
		var ay = S / 2 + int(sin(angle_i * PI / 4.0) * 8)
		if ax >= 0 and ax < S and ay >= 0 and ay < S:
			img.set_pixel(ax, ay, saw_metal.lightened(0.2))
	# Center bolt
	img.set_pixel(S / 2, S / 2, Color(0.30, 0.30, 0.35))
	_add_tile(BLOCK_DEADLY, "Saw Blade", img)

	# 7. Poison Gas — green toxic cloud
	img = _create_tile()
	var gas_bg = Color(0.12, 0.18, 0.08)
	_fill_rect(img, 0, 0, S, S, gas_bg)
	var gas = Color(0.35, 0.70, 0.15, 0.7)
	_fill_circle(img, 5, 8, 4, gas)
	_fill_circle(img, 12, 6, 5, gas.lightened(0.1))
	_fill_circle(img, 8, 13, 3, gas.darkened(0.1))
	_fill_circle(img, 14, 12, 3, gas)
	# Skull icon in center
	var skull = Color(0.80, 0.85, 0.70)
	_fill_circle(img, S / 2, 7, 2, skull)
	img.set_pixel(S / 2 - 1, 7, Color(0.1, 0.1, 0.0))
	img.set_pixel(S / 2 + 1, 7, Color(0.1, 0.1, 0.0))
	_add_tile(BLOCK_DEADLY, "Poison Gas", img)

	# 8. Thorns — spiky bramble plants
	img = _create_tile()
	var thorn_bg = Color(0.12, 0.08, 0.05)
	_fill_rect(img, 0, 0, S, S, thorn_bg)
	var thorn_stem = Color(0.28, 0.45, 0.15)
	var thorn_spike = Color(0.55, 0.30, 0.12)
	# Horizontal stems
	for y in [5, 10, 15]:
		for x in range(S): img.set_pixel(x, y, thorn_stem)
	# Vertical stems
	for x in [4, 9, 14]:
		for y in range(S): img.set_pixel(x, y, thorn_stem)
	# Thorns at intersections
	for pos in [Vector2i(4, 5), Vector2i(9, 5), Vector2i(14, 5), Vector2i(4, 10), Vector2i(9, 10), Vector2i(14, 10), Vector2i(4, 15), Vector2i(9, 15), Vector2i(14, 15)]:
		for d in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
			var tp = pos + d
			if tp.x >= 0 and tp.x < S and tp.y >= 0 and tp.y < S:
				img.set_pixel(tp.x, tp.y, thorn_spike)
	_add_tile(BLOCK_DEADLY, "Thorns", img)

	# 9. Hot Coals — glowing ember bed
	img = _create_tile()
	var coal_base = Color(0.20, 0.08, 0.02)
	_fill_rect(img, 0, 0, S, S, coal_base)
	var ember1 = Color(0.85, 0.25, 0.02)
	var ember2 = Color(1.0, 0.55, 0.08)
	var ember3 = Color(1.0, 0.80, 0.20)
	_scatter_pixels(img, 0, S - 1, ember1, 20)
	_scatter_pixels(img, 0, S - 1, ember2, 12)
	_scatter_pixels(img, 0, S - 1, ember3, 6)
	# Brighter glow centers
	for pos in [Vector2i(4, 6), Vector2i(11, 4), Vector2i(7, 12), Vector2i(14, 13)]:
		img.set_pixel(pos.x, pos.y, Color(1.0, 0.9, 0.4))
	_draw_border(img, coal_base.darkened(0.3))
	_add_tile(BLOCK_DEADLY, "Hot Coals", img)

	# 10. Laser Beam — vertical red energy beam
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.08, 0.02, 0.02))
	var laser_glow = Color(0.60, 0.05, 0.05, 0.4)
	_fill_rect(img, S / 2 - 4, 0, 9, S, laser_glow)
	var laser_core = Color(1.0, 0.15, 0.10)
	_fill_rect(img, S / 2 - 1, 0, 3, S, laser_core)
	var laser_hot = Color(1.0, 0.70, 0.65)
	for y in range(S): img.set_pixel(S / 2, y, laser_hot)
	# Spark particles
	for pos in [Vector2i(5, 3), Vector2i(12, 8), Vector2i(4, 14), Vector2i(13, 5)]:
		img.set_pixel(pos.x, pos.y, Color(1.0, 0.5, 0.4, 0.6))
	_add_tile(BLOCK_DEADLY, "Laser Beam", img)


# ─── Background Tiles ───────────────────────────────────────

func _gen_background_tiles() -> void:
	var S = TILE_SIZE
	var base = BLOCK_COLORS[BLOCK_BACKGROUND]

	# 1. Sky gradient
	var img = _create_tile()
	for y in range(S):
		var t = float(y) / float(S)
		var sky = Color(0.35 + t * 0.15, 0.55 + t * 0.1, 0.85 - t * 0.15)
		for x in range(S):
			img.set_pixel(x, y, sky)
	_add_tile(BLOCK_BACKGROUND, "Sky", img)

	# 2. Cloud
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.45, 0.60, 0.85))
	var cloud = Color(0.92, 0.94, 0.98)
	# Cloud puffs
	_fill_circle(img, 6, 10, 4, cloud)
	_fill_circle(img, 11, 8, 5, cloud)
	_fill_circle(img, 15, 10, 3, cloud)
	_add_tile(BLOCK_BACKGROUND, "Cloud", img)

	# 3. Stars / night sky
	img = _create_tile()
	var night = Color(0.05, 0.05, 0.15)
	_fill_rect(img, 0, 0, S, S, night)
	var star = Color(0.95, 0.95, 0.8)
	for pos in [Vector2i(3, 2), Vector2i(10, 5), Vector2i(15, 1), Vector2i(7, 12),
				Vector2i(1, 8), Vector2i(14, 14), Vector2i(5, 16)]:
		if pos.x < S and pos.y < S:
			img.set_pixel(pos.x, pos.y, star)
	_add_tile(BLOCK_BACKGROUND, "Night Sky", img)

	# 4. Water
	img = _create_tile()
	var water = Color(0.15, 0.35, 0.65)
	_fill_rect(img, 0, 0, S, S, water)
	# Wave lines
	for y in [4, 10, 16]:
		for x in range(S):
			var wave_y = y + int(sin(x * 0.7) * 1)
			if wave_y >= 0 and wave_y < S:
				img.set_pixel(x, wave_y, water.lightened(0.2))
	_add_tile(BLOCK_BACKGROUND, "Water", img)

	# 5. Cave wall
	img = _create_tile()
	var cave = Color(0.22, 0.18, 0.15)
	_fill_rect(img, 0, 0, S, S, cave)
	_scatter_pixels(img, 0, S - 1, cave.lightened(0.08), 12)
	_scatter_pixels(img, 0, S - 1, cave.darkened(0.08), 10)
	_draw_border(img, cave.darkened(0.2))
	_add_tile(BLOCK_BACKGROUND, "Cave Wall", img)

	# 6. Trees/forest
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.15, 0.30, 0.12))
	# Tree trunk
	_fill_rect(img, 7, 10, 4, 8, Color(0.40, 0.28, 0.15))
	# Canopy
	_fill_circle(img, 9, 7, 6, Color(0.20, 0.50, 0.15))
	_fill_circle(img, 6, 9, 4, Color(0.25, 0.55, 0.18))
	_fill_circle(img, 12, 9, 4, Color(0.22, 0.48, 0.16))
	_add_tile(BLOCK_BACKGROUND, "Forest", img)

	# 7. Sunset Sky — warm orange/pink gradient
	img = _create_tile()
	for y in range(S):
		var t = float(y) / float(S)
		var sun_c = Color(0.95 - t * 0.35, 0.45 - t * 0.20, 0.25 + t * 0.15)
		for x in range(S): img.set_pixel(x, y, sun_c)
	# Sun disc near top
	_fill_circle(img, S / 2, 5, 3, Color(1.0, 0.85, 0.40))
	_add_tile(BLOCK_BACKGROUND, "Sunset", img)

	# 8. Mountains — mountain silhouette
	img = _create_tile()
	var mtn_sky = Color(0.35, 0.50, 0.72)
	_fill_rect(img, 0, 0, S, S, mtn_sky)
	var mtn_clr = Color(0.25, 0.30, 0.35)
	# Mountain 1 (tall)
	for h in range(12):
		var w = h + 1
		var base_y = 17 - h
		_fill_rect(img, 5 - w / 2, base_y, w, 1, mtn_clr)
	# Mountain 2 (shorter)
	var mtn2 = mtn_clr.lightened(0.08)
	for h in range(8):
		var w = h + 1
		var base_y = 17 - h
		_fill_rect(img, 13 - w / 2, base_y, w, 1, mtn2)
	# Snow caps
	img.set_pixel(5, 6, Color(0.90, 0.92, 0.95))
	img.set_pixel(4, 7, Color(0.90, 0.92, 0.95))
	img.set_pixel(6, 7, Color(0.90, 0.92, 0.95))
	_add_tile(BLOCK_BACKGROUND, "Mountains", img)

	# 9. Dungeon Wall — dark rough stone background
	img = _create_tile()
	var dung = Color(0.15, 0.13, 0.12)
	_fill_rect(img, 0, 0, S, S, dung)
	_scatter_pixels(img, 0, S - 1, dung.lightened(0.06), 10)
	_scatter_pixels(img, 0, S - 1, dung.darkened(0.04), 8)
	# Cracks
	var d_crack = dung.darkened(0.15)
	for y in range(4, 9): img.set_pixel(7 + (y % 2), y, d_crack)
	for y in range(11, 16): img.set_pixel(12, y, d_crack)
	# Torch sconce shadow
	_fill_rect(img, 8, 3, 2, 3, Color(0.22, 0.18, 0.12))
	img.set_pixel(9, 2, Color(0.95, 0.65, 0.15))
	_add_tile(BLOCK_BACKGROUND, "Dungeon Wall", img)

	# 10. Ocean Deep — deep blue gradient with light rays
	img = _create_tile()
	for y in range(S):
		var t = float(y) / float(S)
		var ocean = Color(0.05 + t * 0.05, 0.15 + t * 0.05, 0.45 - t * 0.15)
		for x in range(S): img.set_pixel(x, y, ocean)
	# Light shafts
	for y in range(S):
		var lx1 = 4 + y / 3
		var lx2 = 12 - y / 4
		if lx1 < S: img.set_pixel(lx1, y, Color(0.20, 0.35, 0.60, 0.4))
		if lx2 >= 0 and lx2 < S: img.set_pixel(lx2, y, Color(0.20, 0.35, 0.60, 0.3))
	# Bubbles
	for pos in [Vector2i(6, 10), Vector2i(13, 6), Vector2i(3, 4)]:
		img.set_pixel(pos.x, pos.y, Color(0.30, 0.50, 0.70, 0.5))
	_add_tile(BLOCK_BACKGROUND, "Ocean Deep", img)

	# 11. City Skyline — building silhouettes at dusk
	img = _create_tile()
	var dusk = Color(0.18, 0.12, 0.25)
	_fill_rect(img, 0, 0, S, S, dusk)
	# Sky gradient top
	for y in range(6):
		var t = float(y) / 6.0
		for x in range(S): img.set_pixel(x, y, Color(0.25 + t * 0.1, 0.15 - t * 0.05, 0.35 - t * 0.1))
	var bldg = Color(0.08, 0.06, 0.12)
	_fill_rect(img, 0, 8, 4, 10, bldg)
	_fill_rect(img, 5, 6, 3, 12, bldg)
	_fill_rect(img, 9, 10, 3, 8, bldg)
	_fill_rect(img, 13, 7, 5, 11, bldg)
	# Lit windows
	var window = Color(0.90, 0.80, 0.35)
	for pos in [Vector2i(1, 10), Vector2i(1, 13), Vector2i(6, 8), Vector2i(6, 11), Vector2i(10, 12), Vector2i(14, 9), Vector2i(14, 12), Vector2i(16, 10)]:
		if pos.x < S and pos.y < S: img.set_pixel(pos.x, pos.y, window)
	_add_tile(BLOCK_BACKGROUND, "City Skyline", img)

	# 12. Moon — crescent moon in dark sky
	img = _create_tile()
	var moon_sky = Color(0.04, 0.04, 0.12)
	_fill_rect(img, 0, 0, S, S, moon_sky)
	_fill_circle(img, S / 2, S / 2, 6, Color(0.90, 0.88, 0.78))
	# Dark crescent cutout
	_fill_circle(img, S / 2 + 3, S / 2 - 2, 5, moon_sky)
	# Stars
	var m_star = Color(0.85, 0.85, 0.75)
	for pos in [Vector2i(2, 3), Vector2i(15, 2), Vector2i(1, 14), Vector2i(16, 12), Vector2i(3, 9)]:
		if pos.x < S and pos.y < S: img.set_pixel(pos.x, pos.y, m_star)
	_add_tile(BLOCK_BACKGROUND, "Moon", img)

	# 13. Storm Clouds — dark grey clouds with lightning
	img = _create_tile()
	var storm_sky = Color(0.18, 0.20, 0.28)
	_fill_rect(img, 0, 0, S, S, storm_sky)
	var dark_cloud = Color(0.25, 0.27, 0.32)
	_fill_circle(img, 5, 6, 4, dark_cloud)
	_fill_circle(img, 10, 5, 5, dark_cloud.lightened(0.05))
	_fill_circle(img, 15, 7, 3, dark_cloud)
	# Lightning bolt
	var bolt = Color(1.0, 0.95, 0.60)
	for pos in [Vector2i(9, 9), Vector2i(8, 10), Vector2i(9, 11), Vector2i(10, 11), Vector2i(9, 12), Vector2i(8, 13), Vector2i(9, 14)]:
		if pos.x < S and pos.y < S: img.set_pixel(pos.x, pos.y, bolt)
	_add_tile(BLOCK_BACKGROUND, "Storm Clouds", img)

	# 14. Starfield — dense colorful star field
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.02, 0.02, 0.06))
	var star_colors = [Color(1.0, 1.0, 0.95), Color(0.8, 0.85, 1.0), Color(1.0, 0.9, 0.7), Color(0.7, 0.8, 1.0)]
	for i in range(18):
		var sx = (i * 7 + 3) % S
		var sy = (i * 11 + 5) % S
		var sc = star_colors[i % star_colors.size()]
		img.set_pixel(sx, sy, sc)
	# Bright stars (2px)
	for pos in [Vector2i(4, 3), Vector2i(13, 8), Vector2i(7, 14)]:
		img.set_pixel(pos.x, pos.y, Color(1.0, 1.0, 0.9))
		if pos.x + 1 < S: img.set_pixel(pos.x + 1, pos.y, Color(0.8, 0.8, 0.7))
	_add_tile(BLOCK_BACKGROUND, "Starfield", img)

	# 15. Cloudy Sky — soft pastel clouds on blue
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.50, 0.78, 0.96))
	var cloud_c = Color(1.0, 1.0, 1.0)
	_fill_circle(img, 4, 6, 3, cloud_c)
	_fill_circle(img, 7, 5, 3, cloud_c)
	_fill_circle(img, 10, 7, 3, cloud_c)
	_fill_circle(img, 14, 12, 2, cloud_c)
	_fill_circle(img, S - 3, 11, 2, cloud_c)
	_add_tile(BLOCK_BACKGROUND, "Cloudy Sky", img)

	# 16. Distant Hills — rolling green hills under blue
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.58, 0.82, 0.95))
	var hill_a = Color(0.30, 0.55, 0.30)
	var hill_b = Color(0.22, 0.45, 0.22)
	# Far hills
	for x in range(S):
		var y_far = 10 - int(sin(float(x) * 0.5) * 1.5)
		for y in range(y_far, S):
			img.set_pixel(x, y, hill_b)
	# Near hills
	for x in range(S):
		var y_near = 13 - int(sin(float(x) * 0.9 + 1.0) * 1.5)
		for y in range(y_near, S):
			img.set_pixel(x, y, hill_a)
	_add_tile(BLOCK_BACKGROUND, "Hills", img)

	# 17. Stained Glass — colorful diamond panes with lead lines
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.10, 0.08, 0.12))
	var panes = [
		Color(0.80, 0.20, 0.30),
		Color(0.20, 0.50, 0.85),
		Color(0.30, 0.75, 0.40),
		Color(0.95, 0.80, 0.25),
	]
	for y in range(S):
		for x in range(S):
			var idx = ((x / 4) + (y / 4)) % panes.size()
			img.set_pixel(x, y, panes[idx])
	# Lead grid lines
	for i in range(S):
		if i % 4 == 0:
			for x in range(S): img.set_pixel(x, i, Color(0.10, 0.08, 0.12))
			for y in range(S): img.set_pixel(i, y, Color(0.10, 0.08, 0.12))
	_add_tile(BLOCK_BACKGROUND, "Stained Glass", img)

	# 18. Cave Wall — dark mottled rock with cracks
	img = _create_tile()
	var cave_c = Color(0.18, 0.16, 0.20)
	_fill_rect(img, 0, 0, S, S, cave_c)
	# Rock specks
	for i in range(40):
		var rx = (i * 13 + 5) % S
		var ry = (i * 7 + 3) % S
		var bright = (i % 3 == 0)
		img.set_pixel(rx, ry, cave_c.lightened(0.18) if bright else cave_c.darkened(0.4))
	# Cracks
	for j in range(0, S, 3):
		img.set_pixel(j, (j * 2) % S, cave_c.darkened(0.6))
	_add_tile(BLOCK_BACKGROUND, "Cave Wall", img)


# ─── Teleport Tiles ──────────────────────────────────────────

func _gen_teleport_tiles() -> void:
	var S = TILE_SIZE
	var base = BLOCK_COLORS[BLOCK_TELEPORT]

	# 1. Portal ring
	var img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.08, 0.05, 0.15))
	var portal = Color(0.60, 0.25, 0.85)
	# Outer ring
	_draw_circle_outline(img, S / 2, S / 2, 7, portal)
	_draw_circle_outline(img, S / 2, S / 2, 6, portal.lightened(0.2))
	# Center glow
	_fill_circle(img, S / 2, S / 2, 3, portal.lightened(0.4))
	_add_tile(BLOCK_TELEPORT, "Portal", img)

	# 2. Warp pad
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.10, 0.08, 0.18))
	# Platform base
	_fill_rect(img, 2, S - 4, S - 4, 4, base.darkened(0.3))
	# Glowing arrows pointing up
	for y in range(2, S - 5):
		var cx = S / 2
		if y < 6:
			for dx in range(-(6 - y), 7 - y):
				var px = cx + dx
				if px >= 0 and px < S:
					img.set_pixel(px, y, base.lightened(0.3))
		else:
			for dx in [-2, -1, 0, 1, 2]:
				var px = cx + dx
				if px >= 0 and px < S:
					img.set_pixel(px, y, base)
	_add_tile(BLOCK_TELEPORT, "Warp Pad", img)

	# 3. Magic door
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.10, 0.08, 0.15))
	# Door frame
	_fill_rect(img, 3, 2, S - 6, S - 2, base.darkened(0.2))
	_fill_rect(img, 5, 4, S - 10, S - 4, Color(0.20, 0.10, 0.35))
	# Sparkles
	for pos in [Vector2i(7, 6), Vector2i(11, 10), Vector2i(9, 13)]:
		if pos.x < S and pos.y < S:
			img.set_pixel(pos.x, pos.y, Color(0.9, 0.7, 1.0))
	_add_tile(BLOCK_TELEPORT, "Magic Door", img)

	# 4. Vortex — swirling spiral pattern
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.05, 0.02, 0.12))
	var vort_colors = [base, base.lightened(0.15), base.lightened(0.3), base.lightened(0.45)]
	# Spiral rings
	for r in range(2, 8):
		var ci = r % vort_colors.size()
		_draw_circle_outline(img, S / 2, S / 2, r, vort_colors[ci])
	# Brightest center
	_fill_circle(img, S / 2, S / 2, 1, Color(0.90, 0.70, 1.0))
	_add_tile(BLOCK_TELEPORT, "Vortex", img)

	# 5. Star Gate — star-shaped gateway
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.06, 0.04, 0.14))
	var sg_clr = Color(0.50, 0.30, 0.80)
	# Octagon frame
	_fill_rect(img, 4, 1, 10, 1, sg_clr)
	_fill_rect(img, 4, S - 2, 10, 1, sg_clr)
	_fill_rect(img, 1, 4, 1, 10, sg_clr)
	_fill_rect(img, S - 2, 4, 1, 10, sg_clr)
	# Diagonal corners
	for pos in [Vector2i(2, 2), Vector2i(3, 3), Vector2i(S - 3, 2), Vector2i(S - 4, 3), Vector2i(2, S - 3), Vector2i(3, S - 4), Vector2i(S - 3, S - 3), Vector2i(S - 4, S - 4)]:
		img.set_pixel(pos.x, pos.y, sg_clr)
	# Inner glow
	_fill_circle(img, S / 2, S / 2, 4, Color(0.30, 0.15, 0.55))
	_fill_circle(img, S / 2, S / 2, 2, Color(0.55, 0.35, 0.85))
	img.set_pixel(S / 2, S / 2, Color(0.85, 0.70, 1.0))
	_add_tile(BLOCK_TELEPORT, "Star Gate", img)

	# 6. Teleport Beam — vertical energy column
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.06, 0.04, 0.12))
	var beam_glow = Color(0.40, 0.20, 0.65, 0.3)
	_fill_rect(img, S / 2 - 5, 0, 11, S, beam_glow)
	var beam_mid = Color(0.55, 0.30, 0.80, 0.6)
	_fill_rect(img, S / 2 - 3, 0, 7, S, beam_mid)
	var beam_core = Color(0.75, 0.55, 0.95)
	_fill_rect(img, S / 2 - 1, 0, 3, S, beam_core)
	for y in range(S): img.set_pixel(S / 2, y, Color(0.90, 0.80, 1.0))
	# Sparkle particles
	for pos in [Vector2i(4, 3), Vector2i(13, 7), Vector2i(5, 12), Vector2i(12, 15)]:
		if pos.x < S and pos.y < S: img.set_pixel(pos.x, pos.y, Color(0.85, 0.70, 1.0, 0.5))
	_add_tile(BLOCK_TELEPORT, "Teleport Beam", img)


# ─── Switch Tiles ────────────────────────────────────────────

func _gen_switch_tiles() -> void:
	var S = TILE_SIZE
	var base = BLOCK_COLORS[BLOCK_SWITCH]

	# 1. Lever switch
	var img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.12, 0.12, 0.14))
	# Base plate
	_fill_rect(img, 3, S - 5, S - 6, 4, Color(0.40, 0.42, 0.48))
	# Lever arm
	_fill_rect(img, S / 2 - 1, 4, 2, S - 8, base)
	# Knob
	_fill_circle(img, S / 2, 4, 2, base.lightened(0.3))
	_add_tile(BLOCK_SWITCH, "Lever", img)

	# 2. Button (pressure plate)
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.12, 0.12, 0.14))
	_fill_rect(img, 2, S - 4, S - 4, 3, base)
	_fill_rect(img, 3, S - 5, S - 6, 1, base.lightened(0.2))
	_add_tile(BLOCK_SWITCH, "Button", img)

	# 3. Crystal switch
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.10, 0.10, 0.14))
	# Crystal shape (diamond)
	var cx = S / 2
	var cy = S / 2
	for dy in range(-5, 6):
		var w = 5 - absi(dy)
		for dx in range(-w, w + 1):
			var px = cx + dx
			var py = cy + dy
			if px >= 0 and px < S and py >= 0 and py < S:
				var brightness = 1.0 - float(absi(dx) + absi(dy)) / 10.0
				img.set_pixel(px, py, base.lightened(brightness * 0.3))
	_add_tile(BLOCK_SWITCH, "Crystal", img)

	# 4. Key
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.10, 0.10, 0.14))
	var gold = Color(0.90, 0.75, 0.20)
	# Key head (circle)
	_fill_circle(img, 6, 6, 3, gold)
	_fill_circle(img, 6, 6, 1, Color(0.10, 0.10, 0.14))  # keyhole
	# Key shaft
	_fill_rect(img, 8, 5, 6, 2, gold)
	# Key teeth
	img.set_pixel(12, 7, gold)
	img.set_pixel(13, 7, gold)
	img.set_pixel(14, 7, gold)
	img.set_pixel(12, 8, gold)
	img.set_pixel(14, 8, gold)
	_add_tile(BLOCK_SWITCH, "Key", img)

	# 5. Treasure Chest — openable wooden chest
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.10, 0.10, 0.14))
	var chest = Color(0.55, 0.35, 0.15)
	# Body
	_fill_rect(img, 2, 8, 14, 8, chest)
	# Lid (slightly lighter)
	_fill_rect(img, 2, 5, 14, 4, chest.lightened(0.1))
	# Metal bands
	var band = Color(0.70, 0.65, 0.25)
	_fill_rect(img, 2, 7, 14, 1, band)
	_fill_rect(img, 2, 12, 14, 1, band)
	# Lock
	img.set_pixel(S / 2, 8, Color(0.85, 0.78, 0.25))
	img.set_pixel(S / 2, 9, Color(0.85, 0.78, 0.25))
	# Highlights
	_fill_rect(img, 3, 6, 4, 1, chest.lightened(0.2))
	_draw_border(img, chest.darkened(0.4))
	_add_tile(BLOCK_SWITCH, "Treasure Chest", img)

	# 6. Coin — shiny gold coin
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.10, 0.10, 0.14))
	var coin_g = Color(0.90, 0.78, 0.22)
	_fill_circle(img, S / 2, S / 2, 6, coin_g)
	_draw_circle_outline(img, S / 2, S / 2, 6, coin_g.darkened(0.25))
	_fill_circle(img, S / 2, S / 2, 4, coin_g.lightened(0.1))
	# Dollar sign
	for y in range(S / 2 - 3, S / 2 + 4):
		if y >= 0 and y < S: img.set_pixel(S / 2, y, coin_g.darkened(0.2))
	for x in range(S / 2 - 2, S / 2 + 3):
		if x >= 0 and x < S:
			img.set_pixel(x, S / 2 - 1, coin_g.darkened(0.2))
			img.set_pixel(x, S / 2 + 1, coin_g.darkened(0.2))
	# Shine
	img.set_pixel(S / 2 - 3, S / 2 - 3, Color(1.0, 1.0, 0.85))
	_add_tile(BLOCK_SWITCH, "Coin", img)

	# 7. Heart — red heart pickup
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.10, 0.10, 0.14))
	var heart = Color(0.90, 0.18, 0.22)
	# Two top bumps
	_fill_circle(img, S / 2 - 3, 6, 3, heart)
	_fill_circle(img, S / 2 + 2, 6, 3, heart)
	# Triangle bottom
	for dy in range(8):
		var w = 8 - dy
		_fill_rect(img, S / 2 - w / 2, 8 + dy, w, 1, heart)
	# Shine highlight
	img.set_pixel(S / 2 - 3, 5, heart.lightened(0.35))
	img.set_pixel(S / 2 - 4, 6, heart.lightened(0.25))
	_add_tile(BLOCK_SWITCH, "Heart", img)

	# 8. Star — golden star collectible
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.10, 0.10, 0.14))
	var star_c = Color(0.95, 0.85, 0.20)
	# Five-pointed star approximation
	# Top point
	_fill_rect(img, S / 2 - 1, 2, 3, 3, star_c)
	# Middle wide bar
	_fill_rect(img, 2, 5, S - 4, 4, star_c)
	# Lower notch (cut-out sides to make star shape)
	_fill_rect(img, 4, 9, S - 8, 3, star_c)
	# Bottom two points
	_fill_rect(img, 3, 12, 3, 4, star_c)
	_fill_rect(img, S - 6, 12, 3, 4, star_c)
	# Cut out the inner gaps to approximate star shape
	_fill_rect(img, S / 2 - 2, 12, 5, 4, Color(0.10, 0.10, 0.14))
	# Shine
	img.set_pixel(S / 2, 3, star_c.lightened(0.3))
	img.set_pixel(S / 2 - 1, 6, star_c.lightened(0.2))
	_add_tile(BLOCK_SWITCH, "Star", img)


# ─── Goal Tiles (level exit / flagpole / castle gate) ────────
#
# When the player touches any Goal tile, the level immediately
# completes and advances to the next level (or shows the Victory
# screen on the last level). Multiple visual variants let creators
# pick a theme — Mario-style flagpole, exit door, castle gate,
# treasure star — without changing gameplay.

func _gen_goal_tiles() -> void:
	var S = TILE_SIZE
	var base = BLOCK_COLORS[BLOCK_GOAL]  # gold

	# 1. Flagpole — classic Mario-style: tall pole + golden flag
	var img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.45, 0.70, 0.95))  # sky blue
	# Pole
	for y in range(S):
		img.set_pixel(S / 2, y, Color(0.85, 0.85, 0.90))
		img.set_pixel(S / 2 + 1, y, Color(0.65, 0.65, 0.72))
	# Top knob
	_fill_circle(img, S / 2, 1, 1, Color(0.95, 0.85, 0.20))
	# Flag (triangular, points right)
	for fy in range(3, 9):
		var width = 9 - fy + 3  # tapered
		for fx in range(width):
			var px = S / 2 + 2 + fx
			if px < S:
				img.set_pixel(px, fy, base)
	# Flag border
	for fy in range(3, 9):
		img.set_pixel(S / 2 + 2, fy, base.darkened(0.25))
	_add_tile(BLOCK_GOAL, "Flagpole", img)

	# 2. Exit Door — wooden door with golden trim
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.10, 0.08, 0.12))
	var door_brown = Color(0.45, 0.28, 0.15)
	# Door body
	_fill_rect(img, 3, 2, S - 6, S - 2, door_brown)
	# Vertical planks
	for y in range(2, S):
		img.set_pixel(7, y, door_brown.darkened(0.3))
		img.set_pixel(11, y, door_brown.darkened(0.3))
	# Golden trim
	for y in range(2, S):
		img.set_pixel(3, y, base)
		img.set_pixel(S - 4, y, base)
	for x in range(3, S - 3):
		img.set_pixel(x, 2, base)
	# Door knob
	img.set_pixel(S - 6, S / 2, base.lightened(0.3))
	img.set_pixel(S - 6, S / 2 + 1, base.darkened(0.2))
	# "EXIT" arrow (small)
	for x in range(6, 12):
		img.set_pixel(x, 5, base.lightened(0.4))
	_add_tile(BLOCK_GOAL, "Exit Door", img)

	# 3. Castle Gate — stone arch with golden portcullis
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.10, 0.10, 0.14))
	var stone = Color(0.55, 0.52, 0.50)
	# Stone arch frame
	_fill_rect(img, 1, 4, S - 2, S - 4, stone)
	# Arch interior (dark)
	_fill_rect(img, 4, 6, S - 8, S - 6, Color(0.08, 0.06, 0.10))
	# Top of arch — rounded
	for x in range(4, S - 4):
		var dist = absi(x - S / 2)
		if dist >= 4: img.set_pixel(x, 4, stone)
	img.set_pixel(S / 2, 3, stone)
	img.set_pixel(S / 2 - 1, 3, stone)
	img.set_pixel(S / 2 + 1, 3, stone)
	# Stone block lines
	for x in range(2, S - 2):
		img.set_pixel(x, 8, stone.darkened(0.3))
		img.set_pixel(x, 12, stone.darkened(0.3))
	# Golden portcullis bars
	for y in range(6, S):
		img.set_pixel(6, y, base)
		img.set_pixel(9, y, base)
		img.set_pixel(12, y, base)
	# Crossbar
	for x in range(4, S - 4):
		img.set_pixel(x, 10, base.darkened(0.2))
	_add_tile(BLOCK_GOAL, "Castle Gate", img)

	# 4. Star Goal — a giant golden star (Super Mario style end-card)
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.10, 0.05, 0.20))
	var star_c = base
	# 5-point star shape
	for y in range(S):
		for x in range(S):
			var dx = x - S / 2
			var dy = y - S / 2
			var d = sqrt(float(dx * dx + dy * dy))
			if d < 7.5:
				# Star spikes via angle modulation
				var ang = atan2(float(dy), float(dx))
				var spike = sin(ang * 5.0 + PI / 2.0) * 1.5 + 6.0
				if d <= spike:
					img.set_pixel(x, y, star_c)
				elif d <= spike + 1.0:
					img.set_pixel(x, y, star_c.darkened(0.25))
	# Center sparkle
	img.set_pixel(S / 2, S / 2, Color(1.0, 1.0, 0.85))
	img.set_pixel(S / 2 - 1, S / 2 - 1, star_c.lightened(0.3))
	_add_tile(BLOCK_GOAL, "Star Goal", img)

	# 5. Trophy — golden cup on pedestal
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.08, 0.06, 0.12))
	# Pedestal
	_fill_rect(img, 4, S - 3, S - 8, 3, Color(0.35, 0.25, 0.18))
	_fill_rect(img, 5, S - 5, S - 10, 2, Color(0.45, 0.32, 0.22))
	# Cup body
	_fill_rect(img, 5, 4, S - 10, 8, base)
	# Cup rim highlight
	for x in range(5, S - 5):
		img.set_pixel(x, 4, base.lightened(0.35))
	# Handles
	img.set_pixel(4, 6, base.darkened(0.15))
	img.set_pixel(4, 7, base.darkened(0.15))
	img.set_pixel(S - 5, 6, base.darkened(0.15))
	img.set_pixel(S - 5, 7, base.darkened(0.15))
	# Stem
	_fill_rect(img, S / 2 - 1, 12, 2, 2, base.darkened(0.2))
	# Sparkle
	img.set_pixel(S / 2, 6, Color(1.0, 1.0, 0.9))
	_add_tile(BLOCK_GOAL, "Trophy", img)

	# 6. Treasure Chest — wooden chest with golden lock
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.10, 0.07, 0.10))
	var chest_w = Color(0.50, 0.32, 0.16)
	# Chest body
	_fill_rect(img, 2, 7, S - 4, S - 8, chest_w)
	# Lid
	_fill_rect(img, 2, 4, S - 4, 4, chest_w.lightened(0.15))
	# Plank lines
	for y in [9, 12, 15]:
		_fill_rect(img, 2, y, S - 4, 1, chest_w.darkened(0.3))
	# Iron bands
	for x in [3, S - 4]:
		_fill_rect(img, x, 4, 1, S - 5, base.darkened(0.2))
	# Lock
	_fill_rect(img, S / 2 - 1, 6, 3, 4, base)
	img.set_pixel(S / 2, 7, base.darkened(0.3))
	# Sparkles around chest
	img.set_pixel(2, 3, base.lightened(0.4))
	img.set_pixel(S - 3, 2, base.lightened(0.4))
	_add_tile(BLOCK_GOAL, "Treasure Chest", img)

	# 7. Crystal — large faceted gem
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.06, 0.05, 0.12))
	var crystal = Color(0.45, 0.85, 1.00)
	# Diamond/crystal shape
	for y in range(2, S - 2):
		var half = 0
		if y < S / 2: half = y - 1
		else: half = (S - 3) - y
		half = clampi(half, 1, 7)
		for dx in range(-half, half + 1):
			var px = S / 2 + dx
			if px >= 0 and px < S:
				var c = crystal
				if dx < 0: c = crystal.lightened(0.2)
				elif dx > 1: c = crystal.darkened(0.25)
				img.set_pixel(px, y, c)
	# Highlight
	img.set_pixel(S / 2 - 1, 4, Color(1, 1, 1))
	img.set_pixel(S / 2, 5, Color(1, 1, 1, 0.8))
	_add_tile(BLOCK_GOAL, "Crystal", img)

	# 8. Heart Goal — pixel-art heart (princess-rescued vibe)
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.10, 0.05, 0.12))
	var heart = Color(0.95, 0.25, 0.40)
	# Two top humps
	_fill_circle(img, 5, 6, 3, heart)
	_fill_circle(img, S - 6, 6, 3, heart)
	# Bottom triangle
	for y in range(6, S - 2):
		var w = (S - 4) - (y - 6) * 2
		var x0 = (S - w) / 2
		_fill_rect(img, x0, y, w, 1, heart)
	# Highlight
	img.set_pixel(4, 5, heart.lightened(0.3))
	img.set_pixel(5, 4, heart.lightened(0.3))
	_add_tile(BLOCK_GOAL, "Heart", img)

	# 9. Crown — royal golden crown
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.10, 0.07, 0.12))
	# Band
	_fill_rect(img, 2, 11, S - 4, 4, base)
	# Three spikes
	for spike_x in [3, S / 2 - 1, S - 5]:
		for h in range(5):
			var w = 3 - h / 2
			_fill_rect(img, spike_x, 11 - h - 1, w, 1, base)
	# Gem
	img.set_pixel(S / 2, 13, Color(0.95, 0.20, 0.25))
	img.set_pixel(S / 2 - 1, 13, base.lightened(0.3))
	img.set_pixel(S / 2 + 1, 13, base.lightened(0.3))
	# Top tip jewels
	img.set_pixel(4, 7, Color(0.30, 0.85, 1.00))
	img.set_pixel(S / 2, 6, Color(0.95, 0.20, 0.25))
	img.set_pixel(S - 4, 7, Color(0.45, 0.95, 0.40))
	_add_tile(BLOCK_GOAL, "Crown", img)

	# 10. Portal Goal — swirling teal-gold gateway
	img = _create_tile()
	_fill_rect(img, 0, 0, S, S, Color(0.05, 0.05, 0.10))
	var swirl_a = Color(0.20, 0.85, 0.85)
	var swirl_b = base
	# Concentric rings, alternating
	for r in range(7, 0, -1):
		var c = swirl_a if r % 2 == 0 else swirl_b
		_draw_circle_outline(img, S / 2, S / 2, r, c)
	# Center bright
	img.set_pixel(S / 2, S / 2, Color(1, 1, 0.85))
	# Sparkle dots
	img.set_pixel(3, 3, swirl_b.lightened(0.4))
	img.set_pixel(S - 4, S - 4, swirl_b.lightened(0.4))
	img.set_pixel(S - 4, 3, swirl_a.lightened(0.3))
	img.set_pixel(3, S - 4, swirl_a.lightened(0.3))
	_add_tile(BLOCK_GOAL, "Portal Goal", img)


# ═══════════════════════════════════════════════════════════════
# ACTOR SPRITE GENERATION
# ═══════════════════════════════════════════════════════════════

func _generate_character_sprite(actor_type: String, color: Color) -> Image:
	var S = ACTOR_SPRITE_SIZE
	var img = Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)

	match actor_type:
		"Player":
			_draw_player_sprite(img, S, color)
		"Drone":
			_draw_drone_sprite(img, S, color)
		"Missile":
			_draw_missile_sprite(img, S, color)
		"Sentry":
			_draw_sentry_sprite(img, S, color)
		"Computer":
			_draw_computer_sprite(img, S, color)
		"Zombie":
			_draw_zombie_sprite(img, S, color)
		"Boss":
			_draw_boss_sprite(img, S, color)
		"Bat":
			_draw_bat_sprite(img, S, color)
		"NPC":
			_draw_npc_sprite(img, S, color)
		"Tank":
			_draw_tank_sprite(img, S, color)
		"Fireball":
			_draw_fireball_sprite(img, S, color)
		"TopHero":
			_draw_top_hero_sprite(img, S, color)
		"TopGoblin":
			_draw_top_goblin_sprite(img, S, color)
		"TopChest":
			_draw_top_chest_sprite(img, S, color)
		"Runner":
			_draw_runner_sprite(img, S, color)
		_:
			_draw_drone_sprite(img, S, color)
	return img


## Generate all named animations for an actor type.
## Returns Dictionary { anim_name: [Image, ...] }.
## Original five types get a single-frame Idle; new types get multi-frame anims.
func _generate_character_animations(actor_type: String, color: Color) -> Dictionary:
	match actor_type:
		"Zombie":
			return _gen_zombie_anims(color)
		"Boss":
			return _gen_boss_anims(color)
		"Bat":
			return _gen_bat_anims(color)
		"NPC":
			return _gen_npc_anims(color)
		"Tank":
			return _gen_tank_anims(color)
		"Fireball":
			return _gen_fireball_anims(color)
		_:
			return {"Idle": [_generate_character_sprite(actor_type, color)]}


func _draw_player_sprite(img: Image, S: int, color: Color) -> void:
	# Platformer hero character
	var cx = S / 2
	# Head
	_img_fill_circle(img, cx, 5, 4, color.lightened(0.15))
	# Eyes
	img.set_pixel(cx - 2, 4, Color.WHITE)
	img.set_pixel(cx + 1, 4, Color.WHITE)
	img.set_pixel(cx - 2, 5, Color(0.1, 0.1, 0.2))
	img.set_pixel(cx + 1, 5, Color(0.1, 0.1, 0.2))
	# Body
	_img_fill_rect(img, cx - 3, 9, 7, 7, color)
	# Belt
	_img_fill_rect(img, cx - 3, 13, 7, 1, color.darkened(0.3))
	# Legs
	_img_fill_rect(img, cx - 3, 16, 3, 5, color.darkened(0.15))
	_img_fill_rect(img, cx + 1, 16, 3, 5, color.darkened(0.15))
	# Feet
	_img_fill_rect(img, cx - 4, 20, 4, 2, color.darkened(0.3))
	_img_fill_rect(img, cx + 1, 20, 4, 2, color.darkened(0.3))
	# Arms
	_img_fill_rect(img, cx - 5, 10, 2, 5, color.darkened(0.1))
	_img_fill_rect(img, cx + 4, 10, 2, 5, color.darkened(0.1))


func _draw_drone_sprite(img: Image, S: int, color: Color) -> void:
	# Flying enemy with wings
	var cx = S / 2
	# Body (oval)
	_img_fill_circle(img, cx, S / 2, 5, color)
	# Eyes (angry)
	img.set_pixel(cx - 2, S / 2 - 1, Color(1.0, 0.9, 0.2))
	img.set_pixel(cx + 1, S / 2 - 1, Color(1.0, 0.9, 0.2))
	# Wings
	_img_fill_rect(img, 1, S / 2 - 3, 4, 2, color.lightened(0.2))
	_img_fill_rect(img, S - 5, S / 2 - 3, 4, 2, color.lightened(0.2))
	# Teeth/fangs
	img.set_pixel(cx - 1, S / 2 + 3, Color.WHITE)
	img.set_pixel(cx + 1, S / 2 + 3, Color.WHITE)


func _draw_missile_sprite(img: Image, S: int, color: Color) -> void:
	# Bullet/projectile
	var cx = S / 2
	var cy = S / 2
	# Elongated body (horizontal)
	_img_fill_rect(img, 4, cy - 2, S - 8, 5, color)
	# Nose cone
	for dx in range(4):
		for dy in range(-2 + dx, 3 - dx):
			var px = S - 4 + dx
			var py = cy + dy
			if px < S and py >= 0 and py < S:
				img.set_pixel(px, py, color.lightened(0.1))
	# Tail fins
	_img_fill_rect(img, 2, cy - 4, 3, 2, color.darkened(0.2))
	_img_fill_rect(img, 2, cy + 3, 3, 2, color.darkened(0.2))
	# Exhaust
	img.set_pixel(1, cy, Color(1.0, 0.5, 0.0))
	img.set_pixel(0, cy, Color(1.0, 0.8, 0.2))


func _draw_sentry_sprite(img: Image, S: int, color: Color) -> void:
	# Turret/sentry
	var cx = S / 2
	# Base
	_img_fill_rect(img, cx - 5, S - 6, 11, 5, color.darkened(0.2))
	# Turret body
	_img_fill_rect(img, cx - 3, S - 12, 7, 7, color)
	# Gun barrel
	_img_fill_rect(img, cx + 4, S - 10, 6, 2, color.darkened(0.1))
	# Eye/sensor
	_img_fill_circle(img, cx, S - 9, 2, Color(1.0, 0.3, 0.3))
	# Antenna
	img.set_pixel(cx, S - 14, color.lightened(0.3))
	img.set_pixel(cx, S - 15, color.lightened(0.3))
	img.set_pixel(cx - 1, S - 16, Color(1.0, 0.2, 0.2))
	img.set_pixel(cx + 1, S - 16, Color(1.0, 0.2, 0.2))


func _draw_computer_sprite(img: Image, S: int, color: Color) -> void:
	# Collectible item (gem/coin shape)
	var cx = S / 2
	var cy = S / 2
	# Diamond shape
	for dy in range(-6, 7):
		var w = 6 - absi(dy)
		for dx in range(-w, w + 1):
			var px = cx + dx
			var py = cy + dy
			if px >= 0 and px < S and py >= 0 and py < S:
				var brightness = 1.0 - float(absi(dx) + absi(dy)) / 12.0
				img.set_pixel(px, py, color.lightened(brightness * 0.35))
	# Sparkle
	img.set_pixel(cx - 2, cy - 3, Color(1, 1, 0.9))
	img.set_pixel(cx + 3, cy - 1, Color(1, 1, 0.9))


func _draw_zombie_sprite(img: Image, S: int, color: Color) -> void:
	# Shambling undead figure
	var cx = S / 2
	# Head (slightly tilted via offset)
	_img_fill_circle(img, cx + 1, 5, 4, color.lightened(0.05))
	# Hollow eyes
	img.set_pixel(cx - 1, 4, Color(0.1, 0.0, 0.0))
	img.set_pixel(cx + 2, 4, Color(0.1, 0.0, 0.0))
	img.set_pixel(cx - 1, 5, Color(0.1, 0.0, 0.0))
	img.set_pixel(cx + 2, 5, Color(0.1, 0.0, 0.0))
	# Jagged mouth
	for x in range(cx - 2, cx + 3):
		img.set_pixel(x, 7, Color(0.15, 0.0, 0.0))
	# Torn body
	_img_fill_rect(img, cx - 3, 9, 7, 7, color.darkened(0.1))
	# Tattered edges
	img.set_pixel(cx - 3, 15, Color.TRANSPARENT)
	img.set_pixel(cx + 3, 14, Color.TRANSPARENT)
	# Arms (one reaching forward)
	_img_fill_rect(img, cx - 6, 10, 3, 2, color.darkened(0.15))
	_img_fill_rect(img, cx + 4, 9, 4, 2, color.darkened(0.15))
	# Legs (shambling stance)
	_img_fill_rect(img, cx - 3, 16, 3, 5, color.darkened(0.2))
	_img_fill_rect(img, cx + 1, 16, 3, 6, color.darkened(0.2))
	# Bone showing through
	img.set_pixel(cx - 1, 12, Color(0.85, 0.82, 0.75))
	img.set_pixel(cx, 13, Color(0.85, 0.82, 0.75))


func _draw_boss_sprite(img: Image, S: int, color: Color) -> void:
	# Large menacing boss with horns and cape
	var cx = S / 2
	# Horns
	img.set_pixel(cx - 4, 1, color.darkened(0.3))
	img.set_pixel(cx - 5, 0, color.darkened(0.3))
	img.set_pixel(cx + 3, 1, color.darkened(0.3))
	img.set_pixel(cx + 4, 0, color.darkened(0.3))
	# Large head
	_img_fill_circle(img, cx, 5, 4, color)
	# Glowing red eyes
	img.set_pixel(cx - 2, 4, Color(1.0, 0.2, 0.1))
	img.set_pixel(cx + 1, 4, Color(1.0, 0.2, 0.1))
	# Fanged mouth
	img.set_pixel(cx - 1, 7, Color.WHITE)
	img.set_pixel(cx + 1, 7, Color.WHITE)
	# Wide body (bulky)
	_img_fill_rect(img, cx - 5, 9, 11, 8, color.darkened(0.05))
	# Chest plate / emblem
	_img_fill_rect(img, cx - 2, 10, 5, 3, color.lightened(0.15))
	img.set_pixel(cx, 11, Color(1.0, 0.3, 0.2))
	# Cape flowing behind (wider silhouette)
	_img_fill_rect(img, cx - 6, 10, 2, 10, color.darkened(0.25))
	_img_fill_rect(img, cx + 5, 10, 2, 10, color.darkened(0.25))
	# Thick legs
	_img_fill_rect(img, cx - 4, 17, 4, 5, color.darkened(0.15))
	_img_fill_rect(img, cx + 1, 17, 4, 5, color.darkened(0.15))
	# Feet
	_img_fill_rect(img, cx - 5, 21, 5, 2, color.darkened(0.3))
	_img_fill_rect(img, cx + 1, 21, 5, 2, color.darkened(0.3))


func _draw_bat_sprite(img: Image, S: int, color: Color) -> void:
	# Flying bat creature
	var cx = S / 2
	var cy = S / 2
	# Small round body
	_img_fill_circle(img, cx, cy, 3, color)
	# Ears
	img.set_pixel(cx - 2, cy - 4, color.lightened(0.1))
	img.set_pixel(cx + 1, cy - 4, color.lightened(0.1))
	img.set_pixel(cx - 2, cy - 3, color)
	img.set_pixel(cx + 1, cy - 3, color)
	# Beady eyes
	img.set_pixel(cx - 1, cy - 1, Color(1.0, 0.3, 0.2))
	img.set_pixel(cx + 1, cy - 1, Color(1.0, 0.3, 0.2))
	# Fangs
	img.set_pixel(cx - 1, cy + 2, Color(0.9, 0.9, 0.85))
	img.set_pixel(cx + 1, cy + 2, Color(0.9, 0.9, 0.85))
	# Left wing (spread out)
	_img_fill_rect(img, 1, cy - 2, 4, 1, color.lightened(0.08))
	_img_fill_rect(img, 0, cy - 1, 5, 1, color.lightened(0.05))
	_img_fill_rect(img, 1, cy, 4, 1, color.darkened(0.05))
	_img_fill_rect(img, 2, cy + 1, 3, 1, color.darkened(0.1))
	# Right wing
	_img_fill_rect(img, S - 5, cy - 2, 4, 1, color.lightened(0.08))
	_img_fill_rect(img, S - 5, cy - 1, 5, 1, color.lightened(0.05))
	_img_fill_rect(img, S - 5, cy, 4, 1, color.darkened(0.05))
	_img_fill_rect(img, S - 5, cy + 1, 3, 1, color.darkened(0.1))
	# Wing tips (jagged)
	img.set_pixel(0, cy - 2, color.darkened(0.15))
	img.set_pixel(S - 1, cy - 2, color.darkened(0.15))


func _draw_npc_sprite(img: Image, S: int, color: Color) -> void:
	# Friendly NPC / villager with hat
	var cx = S / 2
	# Hat brim
	_img_fill_rect(img, cx - 4, 2, 9, 2, color.darkened(0.2))
	# Hat top
	_img_fill_rect(img, cx - 2, 0, 5, 3, color.darkened(0.15))
	# Head
	var skin = Color(0.85, 0.72, 0.55)
	_img_fill_circle(img, cx, 6, 3, skin)
	# Friendly eyes
	img.set_pixel(cx - 1, 5, Color(0.2, 0.3, 0.5))
	img.set_pixel(cx + 1, 5, Color(0.2, 0.3, 0.5))
	# Smile
	img.set_pixel(cx - 1, 7, Color(0.6, 0.3, 0.2))
	img.set_pixel(cx, 8, Color(0.6, 0.3, 0.2))
	img.set_pixel(cx + 1, 7, Color(0.6, 0.3, 0.2))
	# Body (tunic/shirt)
	_img_fill_rect(img, cx - 3, 9, 7, 7, color)
	# Belt
	_img_fill_rect(img, cx - 3, 13, 7, 1, color.darkened(0.25))
	img.set_pixel(cx, 13, Color(0.80, 0.70, 0.25))
	# Legs (pants)
	var pants = color.darkened(0.2)
	_img_fill_rect(img, cx - 3, 16, 3, 5, pants)
	_img_fill_rect(img, cx + 1, 16, 3, 5, pants)
	# Shoes
	_img_fill_rect(img, cx - 4, 20, 4, 2, Color(0.35, 0.22, 0.12))
	_img_fill_rect(img, cx + 1, 20, 4, 2, Color(0.35, 0.22, 0.12))
	# Arms at sides
	_img_fill_rect(img, cx - 5, 10, 2, 5, skin)
	_img_fill_rect(img, cx + 4, 10, 2, 5, skin)


# ─── Top-down view sprites ─────────────────────────────────────────────────
# These render as if seen from directly above (bird's-eye perspective). Used by
# the Top-Down RPG and Maze templates so those genres don't reuse side-view art.

func _draw_top_hero_sprite(img: Image, S: int, color: Color) -> void:
	# Hero seen from above: round body with a directional triangle (facing down/south).
	var cx = S / 2
	var cy = S / 2
	# Cape / cloak ring
	_img_fill_circle(img, cx, cy, 8, color.darkened(0.35))
	# Body / tunic
	_img_fill_circle(img, cx, cy, 6, color)
	# Head (tan circle in middle)
	var skin = Color(0.92, 0.78, 0.60)
	_img_fill_circle(img, cx, cy, 3, skin)
	# Hair tuft showing direction (small dark cap on the "front")
	_img_fill_rect(img, cx - 2, cy + 2, 4, 1, Color(0.30, 0.20, 0.10))
	# Direction indicator — a small triangle of pixels pointing south (the facing).
	img.set_pixel(cx, cy + 4, color.lightened(0.4))
	img.set_pixel(cx - 1, cy + 4, color.lightened(0.4))
	img.set_pixel(cx + 1, cy + 4, color.lightened(0.4))
	# Sword/staff sticking out to one side
	_img_fill_rect(img, cx + 6, cy - 1, 3, 1, Color(0.85, 0.85, 0.90))


func _draw_top_goblin_sprite(img: Image, S: int, color: Color) -> void:
	# Small monster from above: blob body, two ears/horns, eyes near front edge.
	var cx = S / 2
	var cy = S / 2
	# Body (blobby circle)
	_img_fill_circle(img, cx, cy, 5, color)
	# Two pointed ears at the back (north)
	_img_fill_rect(img, cx - 4, cy - 5, 2, 2, color.darkened(0.25))
	_img_fill_rect(img, cx + 2, cy - 5, 2, 2, color.darkened(0.25))
	# Glowing eyes near the south "front" edge
	img.set_pixel(cx - 2, cy + 2, Color(1.0, 0.85, 0.20))
	img.set_pixel(cx + 1, cy + 2, Color(1.0, 0.85, 0.20))
	# Belly highlight
	_img_fill_rect(img, cx - 1, cy, 3, 1, color.lightened(0.20))


func _draw_top_chest_sprite(img: Image, S: int, color: Color) -> void:
	# Treasure chest viewed from above: rectangular wood with metal bands and lock.
	var cx = S / 2
	var cy = S / 2
	# Outer wood box
	_img_fill_rect(img, cx - 6, cy - 5, 12, 11, color.darkened(0.30))
	# Inner wood
	_img_fill_rect(img, cx - 5, cy - 4, 10, 9, color)
	# Metal band across the lid
	_img_fill_rect(img, cx - 6, cy - 1, 12, 2, Color(0.40, 0.30, 0.15))
	# Center lock plate
	_img_fill_rect(img, cx - 1, cy - 1, 3, 3, Color(0.85, 0.75, 0.30))
	# Keyhole
	img.set_pixel(cx, cy, Color(0.10, 0.08, 0.05))


func _draw_runner_sprite(img: Image, S: int, color: Color) -> void:
	# Geometry-Dash-style 8-bit "cube": chunky square with neon outline, inner
	# highlight, and a single visor/eye band. Rotates as a whole sprite while
	# airborne (rotation handled in _gen_runner_physics — sprite art stays
	# upright-symmetric so rotation reads cleanly).
	var cx = S / 2
	var cy = S / 2
	# Slightly inset outer border (2px from edge) so rotated frames don't clip.
	var ox: int = cx - 9
	var oy: int = cy - 9
	var sz: int = 18
	# Neon outer ring (bright)
	_img_fill_rect(img, ox, oy, sz, sz, color.lightened(0.4))
	# Body fill (mid)
	_img_fill_rect(img, ox + 1, oy + 1, sz - 2, sz - 2, color)
	# Inner panel (darkened, 2px in from body) — the recessed face plate
	_img_fill_rect(img, ox + 4, oy + 4, sz - 8, sz - 8, color.darkened(0.30))
	# Top-left highlight pixel cluster (chunky pixel-art shading)
	_img_fill_rect(img, ox + 1, oy + 1, 3, 1, color.lightened(0.55))
	_img_fill_rect(img, ox + 1, oy + 1, 1, 3, color.lightened(0.55))
	# Bottom-right shadow strip
	_img_fill_rect(img, ox + sz - 4, oy + sz - 2, 3, 1, color.darkened(0.50))
	_img_fill_rect(img, ox + sz - 2, oy + sz - 4, 1, 3, color.darkened(0.50))
	# Visor / eye band — horizontal slit on the face plate (the cube's "face")
	_img_fill_rect(img, ox + 5, cy - 1, sz - 10, 2, Color(0.95, 0.95, 1.00))
	# Two pixel pupils inside the visor for character
	img.set_pixel(ox + 6, cy, Color(0.10, 0.10, 0.20))
	img.set_pixel(ox + sz - 7, cy, Color(0.10, 0.10, 0.20))


func _draw_tank_sprite(img: Image, S: int, color: Color) -> void:
	# Armored tank / mech vehicle
	var cx = S / 2
	# Turret barrel (pointing right)
	_img_fill_rect(img, cx + 2, 6, 8, 2, color.darkened(0.15))
	# Turret dome
	_img_fill_circle(img, cx, 7, 4, color.lightened(0.05))
	# Viewport/sensor
	img.set_pixel(cx - 1, 6, Color(0.2, 0.8, 0.3))
	img.set_pixel(cx, 6, Color(0.2, 0.8, 0.3))
	# Hull body (wider)
	_img_fill_rect(img, 1, 11, S - 2, 6, color)
	# Armor plates
	_img_fill_rect(img, 2, 11, 5, 1, color.lightened(0.1))
	_img_fill_rect(img, 8, 11, 5, 1, color.lightened(0.1))
	_img_fill_rect(img, 14, 11, 3, 1, color.lightened(0.1))
	# Tracks
	var track = Color(0.25, 0.25, 0.28)
	_img_fill_rect(img, 0, 17, S, 4, track)
	# Track wheels
	for wx in [3, 8, 13]:
		_img_fill_circle(img, wx, 19, 2, Color(0.35, 0.35, 0.38))
		img.set_pixel(wx, 19, track)
	# Track tread marks
	for x in range(0, S, 3):
		img.set_pixel(x, 17, track.lightened(0.15))
		img.set_pixel(x, 20, track.lightened(0.15))
	# Exhaust pipe
	img.set_pixel(1, 10, Color(0.35, 0.35, 0.38))
	img.set_pixel(1, 9, Color(0.4, 0.4, 0.4))


func _draw_fireball_sprite(img: Image, S: int, color: Color) -> void:
	# Flaming projectile
	var cx = S / 2
	var cy = S / 2
	# Outer flame (yellow-orange)
	var outer = Color(1.0, 0.65, 0.10)
	_img_fill_circle(img, cx, cy, 7, outer)
	# Middle flame
	var mid_f = Color(1.0, 0.45, 0.05)
	_img_fill_circle(img, cx, cy, 5, mid_f)
	# Core (hot white-yellow)
	var core = Color(1.0, 0.90, 0.50)
	_img_fill_circle(img, cx, cy, 3, core)
	# Brightest center
	_img_fill_circle(img, cx, cy, 1, Color(1.0, 1.0, 0.85))
	# Flame wisps (trailing left)
	img.set_pixel(cx - 7, cy - 2, outer)
	img.set_pixel(cx - 8, cy, Color(1.0, 0.5, 0.0, 0.6))
	img.set_pixel(cx - 7, cy + 2, outer)
	img.set_pixel(cx - 6, cy - 4, Color(1.0, 0.6, 0.1, 0.4))
	img.set_pixel(cx - 6, cy + 4, Color(1.0, 0.6, 0.1, 0.4))
	# Sparks
	for pos in [Vector2i(cx - 9, cy - 1), Vector2i(cx - 8, cy + 3), Vector2i(cx - 10, cy)]:
		if pos.x >= 0 and pos.x < S and pos.y >= 0 and pos.y < S:
			img.set_pixel(pos.x, pos.y, Color(1.0, 0.8, 0.3, 0.5))


# ═══════════════════════════════════════════════════════════════
# MULTI-FRAME ANIMATION GENERATORS
# ═══════════════════════════════════════════════════════════════

# ---- ZOMBIE: Idle (2-frame sway) + Walk (4-frame shamble) ----
func _gen_zombie_anims(color: Color) -> Dictionary:
	var S = ACTOR_SPRITE_SIZE
	var idle1 = _draw_zombie_frame(S, color, 1, 0, 0)
	var idle2 = _draw_zombie_frame(S, color, -1, 0, 0)
	var w1 = _draw_zombie_frame(S, color, 1, 1, 1)
	var w2 = _draw_zombie_frame(S, color, 0, 2, 0)
	var w3 = _draw_zombie_frame(S, color, -1, 3, -1)
	var w4 = _draw_zombie_frame(S, color, 0, 0, 0)
	return {"Idle": [idle1, idle2], "Walk": [w1, w2, w3, w4]}

func _draw_zombie_frame(S: int, color: Color, head_ox: int, leg_phase: int, arm_oy: int) -> Image:
	var img = Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var cx = S / 2
	# Head (swaying via offset)
	_img_fill_circle(img, cx + head_ox, 5, 4, color.lightened(0.05))
	# Hollow eyes
	img.set_pixel(cx - 1 + head_ox, 4, Color(0.1, 0.0, 0.0))
	img.set_pixel(cx + 2 + head_ox, 4, Color(0.1, 0.0, 0.0))
	img.set_pixel(cx - 1 + head_ox, 5, Color(0.1, 0.0, 0.0))
	img.set_pixel(cx + 2 + head_ox, 5, Color(0.1, 0.0, 0.0))
	# Jagged mouth
	for x in range(cx - 2 + head_ox, cx + 3 + head_ox):
		if x >= 0 and x < S:
			img.set_pixel(x, 7, Color(0.15, 0.0, 0.0))
	# Torn body
	_img_fill_rect(img, cx - 3, 9, 7, 7, color.darkened(0.1))
	img.set_pixel(cx - 3, 15, Color.TRANSPARENT)
	img.set_pixel(cx + 3, 14, Color.TRANSPARENT)
	# Bone showing through
	img.set_pixel(cx - 1, 12, Color(0.85, 0.82, 0.75))
	img.set_pixel(cx, 13, Color(0.85, 0.82, 0.75))
	# Arms (one reaching forward, offset vertically)
	_img_fill_rect(img, cx - 6, 10 + arm_oy, 3, 2, color.darkened(0.15))
	_img_fill_rect(img, cx + 4, 9 - arm_oy, 4, 2, color.darkened(0.15))
	# Legs (shambling phases)
	match leg_phase:
		0: # standing
			_img_fill_rect(img, cx - 3, 16, 3, 5, color.darkened(0.2))
			_img_fill_rect(img, cx + 1, 16, 3, 6, color.darkened(0.2))
		1: # left forward
			_img_fill_rect(img, cx - 4, 16, 3, 6, color.darkened(0.2))
			_img_fill_rect(img, cx + 1, 17, 3, 4, color.darkened(0.2))
		2: # together
			_img_fill_rect(img, cx - 2, 16, 5, 5, color.darkened(0.2))
		3: # right forward
			_img_fill_rect(img, cx - 3, 17, 3, 4, color.darkened(0.2))
			_img_fill_rect(img, cx, 16, 3, 6, color.darkened(0.2))
	return img


# ---- BOSS: Idle (2-frame pulse) + Attack (3-frame strike) ----
func _gen_boss_anims(color: Color) -> Dictionary:
	var S = ACTOR_SPRITE_SIZE
	var idle1 = _draw_boss_frame(S, color, false, 0)
	var idle2 = _draw_boss_frame(S, color, true, 0)
	var atk1 = _draw_boss_frame(S, color, true, 1)
	var atk2 = _draw_boss_frame(S, color, true, 2)
	var atk3 = _draw_boss_frame(S, color, false, 3)
	return {"Idle": [idle1, idle2], "Attack": [atk1, atk2, atk3]}

func _draw_boss_frame(S: int, color: Color, glow: bool, atk_phase: int) -> Image:
	var img = Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var cx = S / 2
	# Horns
	img.set_pixel(cx - 4, 1, color.darkened(0.3))
	img.set_pixel(cx - 5, 0, color.darkened(0.3))
	img.set_pixel(cx + 3, 1, color.darkened(0.3))
	img.set_pixel(cx + 4, 0, color.darkened(0.3))
	# Large head
	_img_fill_circle(img, cx, 5, 4, color)
	# Eyes (glow brighter on pulse)
	var eye_c = Color(1.0, 0.5, 0.2) if glow else Color(1.0, 0.2, 0.1)
	img.set_pixel(cx - 2, 4, eye_c)
	img.set_pixel(cx + 1, 4, eye_c)
	# Fangs
	img.set_pixel(cx - 1, 7, Color.WHITE)
	img.set_pixel(cx + 1, 7, Color.WHITE)
	# Wide body
	_img_fill_rect(img, cx - 5, 9, 11, 8, color.darkened(0.05))
	# Chest emblem (pulses)
	var emblem_c = color.lightened(0.35) if glow else color.lightened(0.15)
	_img_fill_rect(img, cx - 2, 10, 5, 3, emblem_c)
	var gem_c = Color(1.0, 0.6, 0.3) if glow else Color(1.0, 0.3, 0.2)
	img.set_pixel(cx, 11, gem_c)
	# Cape
	_img_fill_rect(img, cx - 6, 10, 2, 10, color.darkened(0.25))
	_img_fill_rect(img, cx + 5, 10, 2, 10, color.darkened(0.25))
	# Arms (vary by attack phase)
	match atk_phase:
		0: # arms at sides
			_img_fill_rect(img, cx - 7, 10, 2, 5, color.darkened(0.1))
			_img_fill_rect(img, cx + 6, 10, 2, 5, color.darkened(0.1))
		1: # right arm raised
			_img_fill_rect(img, cx - 7, 10, 2, 5, color.darkened(0.1))
			_img_fill_rect(img, cx + 6, 5, 2, 5, color.darkened(0.1))
		2: # right arm forward (striking)
			_img_fill_rect(img, cx - 7, 10, 2, 5, color.darkened(0.1))
			_img_fill_rect(img, cx + 7, 9, 5, 2, color.darkened(0.1))
		3: # both arms wide (recovery)
			_img_fill_rect(img, cx - 8, 9, 3, 3, color.darkened(0.1))
			_img_fill_rect(img, cx + 6, 9, 3, 3, color.darkened(0.1))
	# Thick legs
	_img_fill_rect(img, cx - 4, 17, 4, 5, color.darkened(0.15))
	_img_fill_rect(img, cx + 1, 17, 4, 5, color.darkened(0.15))
	# Feet
	_img_fill_rect(img, cx - 5, 21, 5, 2, color.darkened(0.3))
	_img_fill_rect(img, cx + 1, 21, 5, 2, color.darkened(0.3))
	return img


# ---- BAT: Idle (2-frame flap) + Fly (3-frame wing cycle) ----
func _gen_bat_anims(color: Color) -> Dictionary:
	var S = ACTOR_SPRITE_SIZE
	var idle1 = _draw_bat_frame(S, color, 0)
	var idle2 = _draw_bat_frame(S, color, 2)
	var fly1 = _draw_bat_frame(S, color, 0)
	var fly2 = _draw_bat_frame(S, color, 1)
	var fly3 = _draw_bat_frame(S, color, 2)
	return {"Idle": [idle1, idle2], "Fly": [fly1, fly2, fly3]}

func _draw_bat_frame(S: int, color: Color, wing_phase: int) -> Image:
	var img = Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var cx = S / 2
	var cy = S / 2
	# Small round body
	_img_fill_circle(img, cx, cy, 3, color)
	# Ears
	img.set_pixel(cx - 2, cy - 4, color.lightened(0.1))
	img.set_pixel(cx + 1, cy - 4, color.lightened(0.1))
	img.set_pixel(cx - 2, cy - 3, color)
	img.set_pixel(cx + 1, cy - 3, color)
	# Beady eyes
	img.set_pixel(cx - 1, cy - 1, Color(1.0, 0.3, 0.2))
	img.set_pixel(cx + 1, cy - 1, Color(1.0, 0.3, 0.2))
	# Fangs
	img.set_pixel(cx - 1, cy + 2, Color(0.9, 0.9, 0.85))
	img.set_pixel(cx + 1, cy + 2, Color(0.9, 0.9, 0.85))
	# Wings vary by phase
	match wing_phase:
		0: # wings up
			_img_fill_rect(img, 1, cy - 4, 5, 1, color.lightened(0.08))
			_img_fill_rect(img, 0, cy - 3, 6, 1, color.lightened(0.05))
			_img_fill_rect(img, 1, cy - 2, 5, 1, color.darkened(0.05))
			_img_fill_rect(img, S - 6, cy - 4, 5, 1, color.lightened(0.08))
			_img_fill_rect(img, S - 6, cy - 3, 6, 1, color.lightened(0.05))
			_img_fill_rect(img, S - 6, cy - 2, 5, 1, color.darkened(0.05))
			img.set_pixel(0, cy - 4, color.darkened(0.15))
			img.set_pixel(S - 1, cy - 4, color.darkened(0.15))
		1: # wings level
			_img_fill_rect(img, 1, cy - 2, 4, 1, color.lightened(0.08))
			_img_fill_rect(img, 0, cy - 1, 5, 1, color.lightened(0.05))
			_img_fill_rect(img, 1, cy, 4, 1, color.darkened(0.05))
			_img_fill_rect(img, S - 5, cy - 2, 4, 1, color.lightened(0.08))
			_img_fill_rect(img, S - 5, cy - 1, 5, 1, color.lightened(0.05))
			_img_fill_rect(img, S - 5, cy, 4, 1, color.darkened(0.05))
			img.set_pixel(0, cy - 2, color.darkened(0.15))
			img.set_pixel(S - 1, cy - 2, color.darkened(0.15))
		2: # wings down
			_img_fill_rect(img, 1, cy, 4, 1, color.lightened(0.08))
			_img_fill_rect(img, 0, cy + 1, 5, 1, color.lightened(0.05))
			_img_fill_rect(img, 1, cy + 2, 4, 1, color.darkened(0.05))
			_img_fill_rect(img, 2, cy + 3, 3, 1, color.darkened(0.1))
			_img_fill_rect(img, S - 5, cy, 4, 1, color.lightened(0.08))
			_img_fill_rect(img, S - 5, cy + 1, 5, 1, color.lightened(0.05))
			_img_fill_rect(img, S - 5, cy + 2, 4, 1, color.darkened(0.05))
			_img_fill_rect(img, S - 5, cy + 3, 3, 1, color.darkened(0.1))
			img.set_pixel(0, cy, color.darkened(0.15))
			img.set_pixel(S - 1, cy, color.darkened(0.15))
	return img


# ---- NPC: Idle (2-frame bob) + Walk (4-frame stride) ----
func _gen_npc_anims(color: Color) -> Dictionary:
	var S = ACTOR_SPRITE_SIZE
	var idle1 = _draw_npc_frame(S, color, 0, 0)
	var idle2 = _draw_npc_frame(S, color, -1, 0)
	var w1 = _draw_npc_frame(S, color, 0, 1)
	var w2 = _draw_npc_frame(S, color, 0, 2)
	var w3 = _draw_npc_frame(S, color, 0, 3)
	var w4 = _draw_npc_frame(S, color, 0, 0)
	return {"Idle": [idle1, idle2], "Walk": [w1, w2, w3, w4]}

func _draw_npc_frame(S: int, color: Color, head_oy: int, leg_phase: int) -> Image:
	var img = Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var cx = S / 2
	# Hat brim
	_img_fill_rect(img, cx - 4, 2 + head_oy, 9, 2, color.darkened(0.2))
	# Hat top
	_img_fill_rect(img, cx - 2, 0 + head_oy, 5, 3, color.darkened(0.15))
	# Head
	var skin = Color(0.85, 0.72, 0.55)
	_img_fill_circle(img, cx, 6 + head_oy, 3, skin)
	# Friendly eyes
	img.set_pixel(cx - 1, 5 + head_oy, Color(0.2, 0.3, 0.5))
	img.set_pixel(cx + 1, 5 + head_oy, Color(0.2, 0.3, 0.5))
	# Smile
	img.set_pixel(cx - 1, 7 + head_oy, Color(0.6, 0.3, 0.2))
	img.set_pixel(cx, 8 + head_oy, Color(0.6, 0.3, 0.2))
	img.set_pixel(cx + 1, 7 + head_oy, Color(0.6, 0.3, 0.2))
	# Body (tunic/shirt)
	_img_fill_rect(img, cx - 3, 9, 7, 7, color)
	# Belt
	_img_fill_rect(img, cx - 3, 13, 7, 1, color.darkened(0.25))
	img.set_pixel(cx, 13, Color(0.80, 0.70, 0.25))
	# Arms
	_img_fill_rect(img, cx - 5, 10, 2, 5, skin)
	_img_fill_rect(img, cx + 4, 10, 2, 5, skin)
	# Legs (vary by phase)
	var pants = color.darkened(0.2)
	var shoe = Color(0.35, 0.22, 0.12)
	match leg_phase:
		0: # standing
			_img_fill_rect(img, cx - 3, 16, 3, 5, pants)
			_img_fill_rect(img, cx + 1, 16, 3, 5, pants)
			_img_fill_rect(img, cx - 4, 20, 4, 2, shoe)
			_img_fill_rect(img, cx + 1, 20, 4, 2, shoe)
		1: # left forward
			_img_fill_rect(img, cx - 4, 16, 3, 6, pants)
			_img_fill_rect(img, cx + 1, 17, 3, 4, pants)
			_img_fill_rect(img, cx - 5, 21, 4, 2, shoe)
			_img_fill_rect(img, cx + 1, 20, 4, 2, shoe)
		2: # together (passing)
			_img_fill_rect(img, cx - 2, 16, 5, 5, pants)
			_img_fill_rect(img, cx - 3, 20, 7, 2, shoe)
		3: # right forward
			_img_fill_rect(img, cx - 3, 17, 3, 4, pants)
			_img_fill_rect(img, cx, 16, 3, 6, pants)
			_img_fill_rect(img, cx - 4, 20, 4, 2, shoe)
			_img_fill_rect(img, cx, 21, 4, 2, shoe)
	return img


# ---- TANK: Idle (1 frame) + Drive (3-frame tread cycle) ----
func _gen_tank_anims(color: Color) -> Dictionary:
	var S = ACTOR_SPRITE_SIZE
	var idle = _draw_tank_frame(S, color, 0)
	var d1 = _draw_tank_frame(S, color, 0)
	var d2 = _draw_tank_frame(S, color, 1)
	var d3 = _draw_tank_frame(S, color, 2)
	return {"Idle": [idle], "Drive": [d1, d2, d3]}

func _draw_tank_frame(S: int, color: Color, tread_offset: int) -> Image:
	var img = Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var cx = S / 2
	# Turret barrel
	_img_fill_rect(img, cx + 2, 6, 8, 2, color.darkened(0.15))
	# Turret dome
	_img_fill_circle(img, cx, 7, 4, color.lightened(0.05))
	# Viewport/sensor
	img.set_pixel(cx - 1, 6, Color(0.2, 0.8, 0.3))
	img.set_pixel(cx, 6, Color(0.2, 0.8, 0.3))
	# Hull body
	_img_fill_rect(img, 1, 11, S - 2, 6, color)
	# Armor plates
	_img_fill_rect(img, 2, 11, 5, 1, color.lightened(0.1))
	_img_fill_rect(img, 8, 11, 5, 1, color.lightened(0.1))
	_img_fill_rect(img, 14, 11, 3, 1, color.lightened(0.1))
	# Tracks
	var track = Color(0.25, 0.25, 0.28)
	_img_fill_rect(img, 0, 17, S, 4, track)
	# Track wheels
	for wx in [3, 8, 13]:
		_img_fill_circle(img, wx, 19, 2, Color(0.35, 0.35, 0.38))
		img.set_pixel(wx, 19, track)
	# Animated tread marks (shift with offset)
	for x in range(0, S, 3):
		var tx = (x + tread_offset) % S
		if tx >= 0 and tx < S:
			img.set_pixel(tx, 17, track.lightened(0.15))
			img.set_pixel(tx, 20, track.lightened(0.15))
	# Exhaust pipe
	img.set_pixel(1, 10, Color(0.35, 0.35, 0.38))
	img.set_pixel(1, 9, Color(0.4, 0.4, 0.4))
	# Exhaust puffs when driving
	if tread_offset > 0:
		img.set_pixel(0, 8, Color(0.5, 0.5, 0.5, 0.4))
		if tread_offset == 2:
			img.set_pixel(0, 7, Color(0.45, 0.45, 0.45, 0.3))
	return img


# ---- FIREBALL: Idle (3-frame flicker) ----
func _gen_fireball_anims(color: Color) -> Dictionary:
	var S = ACTOR_SPRITE_SIZE
	var f1 = _draw_fireball_frame(S, color, 0)
	var f2 = _draw_fireball_frame(S, color, 1)
	var f3 = _draw_fireball_frame(S, color, 2)
	return {"Idle": [f1, f2, f3]}

func _draw_fireball_frame(S: int, color: Color, flicker: int) -> Image:
	var img = Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var cx = S / 2
	var cy = S / 2
	# Outer flame (size varies by flicker)
	var outer = Color(1.0, 0.65, 0.10)
	var outer_r = 7 if flicker != 1 else 6
	_img_fill_circle(img, cx, cy, outer_r, outer)
	# Middle flame
	var mid_f = Color(1.0, 0.45, 0.05)
	var mid_r = 5 if flicker != 2 else 4
	_img_fill_circle(img, cx, cy, mid_r, mid_f)
	# Core (hot white-yellow)
	var core = Color(1.0, 0.90, 0.50)
	var core_r = 3 if flicker == 0 else 2
	_img_fill_circle(img, cx, cy, core_r, core)
	# Brightest center
	_img_fill_circle(img, cx, cy, 1, Color(1.0, 1.0, 0.85))
	# Flame wisps (trailing — different positions per flicker)
	match flicker:
		0:
			img.set_pixel(cx - 7, cy - 2, outer)
			img.set_pixel(cx - 8, cy, Color(1.0, 0.5, 0.0, 0.6))
			img.set_pixel(cx - 7, cy + 2, outer)
			img.set_pixel(cx - 6, cy - 4, Color(1.0, 0.6, 0.1, 0.4))
			img.set_pixel(cx - 6, cy + 4, Color(1.0, 0.6, 0.1, 0.4))
		1:
			img.set_pixel(cx - 6, cy - 3, outer)
			img.set_pixel(cx - 7, cy + 1, Color(1.0, 0.5, 0.0, 0.6))
			img.set_pixel(cx - 6, cy + 3, outer)
			img.set_pixel(cx - 5, cy - 5, Color(1.0, 0.6, 0.1, 0.4))
			img.set_pixel(cx + 5, cy - 3, Color(1.0, 0.6, 0.1, 0.35))
		2:
			img.set_pixel(cx - 7, cy - 1, outer)
			img.set_pixel(cx - 7, cy + 3, Color(1.0, 0.5, 0.0, 0.6))
			img.set_pixel(cx - 8, cy, outer)
			img.set_pixel(cx + 4, cy + 5, Color(1.0, 0.6, 0.1, 0.35))
			img.set_pixel(cx - 5, cy + 5, Color(1.0, 0.6, 0.1, 0.4))
	# Sparks (different positions per flicker)
	var spark_offsets = [
		[Vector2i(cx - 9, cy - 1), Vector2i(cx - 8, cy + 3), Vector2i(cx - 10, cy)],
		[Vector2i(cx - 8, cy - 2), Vector2i(cx - 9, cy + 1), Vector2i(cx + 7, cy - 2)],
		[Vector2i(cx - 9, cy), Vector2i(cx - 7, cy + 4), Vector2i(cx + 6, cy + 3)],
	]
	for pos in spark_offsets[flicker]:
		if pos.x >= 0 and pos.x < S and pos.y >= 0 and pos.y < S:
			img.set_pixel(pos.x, pos.y, Color(1.0, 0.8, 0.3, 0.5))
	return img


# ═══════════════════════════════════════════════════════════════
# DRAWING HELPERS
# ═══════════════════════════════════════════════════════════════

func _create_tile() -> Image:
	var img = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	return img


func _add_tile(block_type: int, name: String, img: Image) -> void:
	var tex = ImageTexture.create_from_image(img)
	tiles[block_type].append({"name": name, "image": img, "texture": tex})


## Variant of _add_tile that accepts extra metadata flags (e.g. one_way).
## Keeps the common path (name + image) zero-overhead while letting
## special tiles like One-Way Platforms carry runtime hints.
func _add_tile_ex(block_type: int, name: String, img: Image, opts: Dictionary) -> void:
	var tex = ImageTexture.create_from_image(img)
	var entry := {"name": name, "image": img, "texture": tex}
	for k in opts.keys():
		entry[k] = opts[k]
	tiles[block_type].append(entry)


func _fill_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for py in range(maxi(0, y), mini(img.get_height(), y + h)):
		for px in range(maxi(0, x), mini(img.get_width(), x + w)):
			img.set_pixel(px, py, color)


func _draw_border(img: Image, color: Color) -> void:
	var w = img.get_width()
	var h = img.get_height()
	for i in range(w):
		img.set_pixel(i, 0, color)
		img.set_pixel(i, h - 1, color)
	for i in range(h):
		img.set_pixel(0, i, color)
		img.set_pixel(w - 1, i, color)


func _fill_circle(img: Image, cx: int, cy: int, r: int, color: Color) -> void:
	var w = img.get_width()
	var h = img.get_height()
	for y in range(maxi(0, cy - r), mini(h, cy + r + 1)):
		for x in range(maxi(0, cx - r), mini(w, cx + r + 1)):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
				img.set_pixel(x, y, color)


func _draw_circle_outline(img: Image, cx: int, cy: int, r: int, color: Color) -> void:
	var w = img.get_width()
	var h = img.get_height()
	for y in range(maxi(0, cy - r), mini(h, cy + r + 1)):
		for x in range(maxi(0, cx - r), mini(w, cx + r + 1)):
			var d2 = (x - cx) * (x - cx) + (y - cy) * (y - cy)
			if d2 <= r * r and d2 >= (r - 1) * (r - 1):
				img.set_pixel(x, y, color)


func _scatter_pixels(img: Image, y_min: int, y_max: int, color: Color, count: int) -> void:
	var w = img.get_width()
	# Deterministic scatter using a simple hash
	for i in range(count):
		var px = (i * 7 + 3) % w
		var py = y_min + ((i * 13 + 5) % (y_max - y_min + 1))
		if px >= 0 and px < w and py >= 0 and py < img.get_height():
			img.set_pixel(px, py, color)


# Helpers for actor sprite drawing (same as above but with explicit img param)
func _img_fill_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	_fill_rect(img, x, y, w, h, color)


func _img_fill_circle(img: Image, cx: int, cy: int, r: int, color: Color) -> void:
	_fill_circle(img, cx, cy, r, color)


# ═══════════════════════════════════════════════════════════════
# SERIALIZATION
# ═══════════════════════════════════════════════════════════════

## Serialize the tile library to a Dictionary for saving
func get_data() -> Dictionary:
	var data: Dictionary = {}
	# Serialize tile images as base64 PNG
	var tile_data: Dictionary = {}
	for bt in tiles:
		var arr: Array = []
		for t in tiles[bt]:
			var png_buf = t["image"].save_png_to_buffer()
			var entry: Dictionary = {
				"name": t["name"],
				"png": Marshalls.raw_to_base64(png_buf),
			}
			# Persist per-tile shader FX if set
			var sfx: String = t.get("shader_fx", "(None)")
			if sfx != "(None)":
				entry["shader_fx"] = sfx
				entry["shader_params"] = t.get("shader_params", {})
			arr.append(entry)
		tile_data[bt] = arr
	data["tiles"] = tile_data

	# Serialize actor sprites (with named animations)
	var actor_data: Dictionary = {}
	for ai in actor_sprites:
		var spr = actor_sprites[ai]
		var anims: Dictionary = spr.get("anims", {})
		# Migrate flat frames if no anims dict yet
		if anims.size() == 0:
			var old_frames: Array = spr.get("frames", [])
			if old_frames.size() == 0 and spr.has("image"):
				old_frames = [spr["image"]]
			if old_frames.size() > 0:
				anims = {"Idle": old_frames}
		# Serialize each animation as { name: [base64_png, ...] }
		var anims_data: Dictionary = {}
		for anim_name in anims:
			var frame_pngs: Array = []
			for fr in anims[anim_name]:
				frame_pngs.append(Marshalls.raw_to_base64(fr.save_png_to_buffer()))
			anims_data[anim_name] = frame_pngs
		actor_data[ai] = {
			"name": spr.get("name", ""),
			"type": spr.get("type", ""),
			"anims_data": anims_data,
			"frame_size": int(spr.get("frame_size", 0)),
		}
	data["actor_sprites"] = actor_data
	data["tile_render_size"] = tile_render_size
	data["actor_frame_size"] = actor_frame_size
	return data


## Deserialize the tile library from saved data.
## Uses a MERGE strategy: generated (built-in) tiles are kept as the base,
## saved tiles overwrite matching names (preserving user edits), and any
## saved tiles with no built-in match are appended (user-created custom tiles).
## This ensures newly-added built-in tiles always appear even when loading
## an older project file that predates them.
func set_data(data: Dictionary) -> void:
	# Ensure the full built-in tile set exists before merging
	if not _initialized:
		_generate_all_tiles()
		_initialized = true

	# Restore project-level render sizes (if present)
	if data.has("tile_render_size"):
		var trs := int(data["tile_render_size"])
		if trs >= 4 and trs <= 512:
			tile_render_size = trs
	if data.has("actor_frame_size"):
		var afs := int(data["actor_frame_size"])
		if afs >= 4 and afs <= 512:
			actor_frame_size = afs

	if data.has("tiles"):
		var tile_data = data["tiles"]
		for bt_str in tile_data:
			var bt = int(bt_str) if bt_str is String else bt_str
			# Build a lookup of saved tiles keyed by name
			var saved_by_name: Dictionary = {}
			for td in tile_data[bt_str]:
				saved_by_name[td["name"]] = td

			# Walk the existing generated tiles and overlay saved versions
			var existing: Array = tiles.get(bt, [])
			var merged: Array = []
			var used_names: Dictionary = {}
			for gen_tile in existing:
				var tname: String = gen_tile["name"]
				if saved_by_name.has(tname):
					# Saved version exists — use saved image (preserves user edits)
					var td = saved_by_name[tname]
					var png_buf = Marshalls.base64_to_raw(td["png"])
					var img = Image.new()
					img.load_png_from_buffer(png_buf)
					var tex = ImageTexture.create_from_image(img)
					var entry: Dictionary = {"name": tname, "image": img, "texture": tex}
					# Restore per-tile shader FX
					if td.has("shader_fx"):
						entry["shader_fx"] = td["shader_fx"]
						entry["shader_params"] = td.get("shader_params", {})
					merged.append(entry)
				else:
					# New built-in tile not in saved data — keep generated version
					merged.append(gen_tile)
				used_names[tname] = true

			# Append any saved tiles that are NOT in the generated set
			# (user-created custom tiles)
			for td in tile_data[bt_str]:
				if not used_names.has(td["name"]):
					var png_buf = Marshalls.base64_to_raw(td["png"])
					var img = Image.new()
					img.load_png_from_buffer(png_buf)
					var tex = ImageTexture.create_from_image(img)
					var entry: Dictionary = {"name": td["name"], "image": img, "texture": tex}
					# Restore per-tile shader FX
					if td.has("shader_fx"):
						entry["shader_fx"] = td["shader_fx"]
						entry["shader_params"] = td.get("shader_params", {})
					merged.append(entry)

			tiles[bt] = merged

	if data.has("actor_sprites"):
		var actor_data = data["actor_sprites"]
		for ai_str in actor_data:
			var ai = int(ai_str) if ai_str is String else ai_str
			var sd = actor_data[ai_str]
			var anims: Dictionary = {}
			# New named-animation format (v5+)
			if sd.has("anims_data"):
				for anim_name in sd["anims_data"]:
					var frame_list: Array = []
					for fp in sd["anims_data"][anim_name]:
						var png_buf = Marshalls.base64_to_raw(fp)
						var img = Image.new()
						img.load_png_from_buffer(png_buf)
						frame_list.append(img)
					if frame_list.size() > 0:
						anims[anim_name] = frame_list
			# Legacy multi-frame format (v4)
			elif sd.has("frame_pngs"):
				var frames: Array = []
				for fp in sd["frame_pngs"]:
					var png_buf = Marshalls.base64_to_raw(fp)
					var img = Image.new()
					img.load_png_from_buffer(png_buf)
					frames.append(img)
				if frames.size() > 0:
					anims["Idle"] = frames
			# Legacy single-image format (v3)
			elif sd.has("png"):
				var png_buf = Marshalls.base64_to_raw(sd["png"])
				var img = Image.new()
				img.load_png_from_buffer(png_buf)
				anims["Idle"] = [img]
			# Ensure at least one anim
			if anims.size() == 0:
				var blank = Image.create(ACTOR_SPRITE_SIZE, ACTOR_SPRITE_SIZE, false, Image.FORMAT_RGBA8)
				anims["Idle"] = [blank]
			var first_frames: Array = anims[anims.keys()[0]]
			var first_img: Image = first_frames[0]
			var tex = ImageTexture.create_from_image(first_img)
			actor_sprites[ai] = {
				"name": sd.get("name", ""),
				"type": sd.get("type", ""),
				"anims": anims,
				"frames": first_frames,
				"image": first_img,
				"texture": tex,
			}
			var fs_override := int(sd.get("frame_size", 0))
			if fs_override > 0:
				actor_sprites[ai]["frame_size"] = fs_override


# ═══════════════════════════════════════════════════════════════
# SPRITE BRIDGE — reimport edited build PNGs back into library
# ═══════════════════════════════════════════════════════════════

# Tracks the last-known modification times of exported sprites so we
# only reimport files that the user actually touched in an external
# editor or VG's Sprite Editor.
var _export_mtimes: Dictionary = {}  # path -> int (unix time)


## Record modification timestamps for all exported sprite PNGs.
## Call this right after a successful build so the bridge knows
## the "clean" state of each file.
func stamp_exported_sprites(sprites_dir: String) -> void:
	_export_mtimes.clear()
	if not DirAccess.dir_exists_absolute(sprites_dir):
		return
	var dir := DirAccess.open(sprites_dir)
	if not dir:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".png"):
			var full_path := sprites_dir + fname
			_export_mtimes[full_path] = FileAccess.get_modified_time(full_path)
		fname = dir.get_next()
	dir.list_dir_end()


## Scan the build sprites directory for PNGs that have been modified
## since the last build and reimport them into the tile library.
## Returns the number of sprites reimported.
func reimport_changed_sprites(sprites_dir: String, actors: Array) -> int:
	if _export_mtimes.is_empty():
		return 0
	if not DirAccess.dir_exists_absolute(sprites_dir):
		return 0

	var count := 0
	var dir := DirAccess.open(sprites_dir)
	if not dir:
		return 0
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".png"):
			var full_path := sprites_dir + fname
			var old_mtime: int = _export_mtimes.get(full_path, 0)
			var cur_mtime: int = FileAccess.get_modified_time(full_path)
			if cur_mtime > old_mtime and old_mtime > 0:
				# File was modified — reimport it
				var img := Image.new()
				if img.load(full_path) == OK:
					# Determine if this is an actor sprite (spr_*) or tile sprite (tile_*)
					if fname.begins_with("spr_"):
						_reimport_actor_sprite(fname, img, actors)
						count += 1
					elif fname.begins_with("tile_"):
						_reimport_tile_sprite(fname, img)
						count += 1
				# Update recorded mtime
				_export_mtimes[full_path] = cur_mtime
		fname = dir.get_next()
	dir.list_dir_end()
	return count


## Reimport an actor sprite PNG back into actor_sprites.
## Handles both single-frame, horizontal sprite-sheet, and per-animation PNGs.
func _reimport_actor_sprite(fname: String, img: Image, actors: Array) -> void:
	# filename patterns:
	#   spr_<actorname>.png            — single animation (legacy)
	#   spr_<actorname>_<animname>.png — named animation
	var base := fname.trim_prefix("spr_").trim_suffix(".png")
	# Try to detect per-animation pattern: base_animname
	var anim_suffix := ""
	for i in range(actors.size()):
		var aname: String = actors[i].get("name", "Actor" + str(i))
		var safe := aname.replace(" ", "_").replace("-", "_").replace(".", "_")
		if base.to_lower().begins_with(safe.to_lower() + "_"):
			anim_suffix = base.substr(safe.length() + 1)
			base = safe
			break
		elif safe.to_lower() == base.to_lower():
			break
	for i in range(actors.size()):
		var aname: String = actors[i].get("name", "Actor" + str(i))
		var safe := aname.replace(" ", "_").replace("-", "_").replace(".", "_")
		if safe.to_lower() == base.to_lower():
			var w := img.get_width()
			var h := img.get_height()
			var frames: Array = []
			# Detect sprite sheet: width is a multiple of height
			if w > h and w % h == 0:
				var frame_count := w / h
				for fi in range(frame_count):
					var fr := Image.create(h, h, false, img.get_format())
					fr.blit_rect(img, Rect2i(fi * h, 0, h, h), Vector2i.ZERO)
					fr.resize(ACTOR_SPRITE_SIZE, ACTOR_SPRITE_SIZE, Image.INTERPOLATE_NEAREST)
					frames.append(fr)
			else:
				var lib_img := img.duplicate()
				lib_img.resize(ACTOR_SPRITE_SIZE, ACTOR_SPRITE_SIZE, Image.INTERPOLATE_NEAREST)
				frames = [lib_img]
			if anim_suffix != "":
				# Per-animation reimport: find matching animation name
				var anims := get_actor_anims(i)
				var found := false
				for an in anims:
					if an.to_lower() == anim_suffix.to_lower():
						anims[an] = frames
						found = true
						break
				if not found:
					# Capitalize first letter for new animation
					var new_name := anim_suffix.substr(0, 1).to_upper() + anim_suffix.substr(1)
					anims[new_name] = frames
				update_actor_anims(i, anims)
			else:
				# Legacy single-file reimport: update first animation
				update_actor_frames(i, frames)
			print("AGCK TileLib: Reimported actor sprite for ", aname, (" [" + anim_suffix + "]" if anim_suffix != "" else ""))
			return


## Reimport a tile sprite PNG back into the tile library.
func _reimport_tile_sprite(fname: String, img: Image) -> void:
	# filename pattern: tile_<blocktype>_<tilename>.png
	var base := fname.trim_prefix("tile_").trim_suffix(".png")
	for bt in range(1, BLOCK_NAMES.size()):
		var prefix: String = BLOCK_NAMES[bt].to_lower() + "_"
		if base.begins_with(prefix):
			var tile_name := base.trim_prefix(prefix)
			# Find matching tile in library
			if tiles.has(bt):
				for ti in range(tiles[bt].size()):
					var safe: String = tiles[bt][ti]["name"].replace(" ", "_").replace("-", "_")
					if safe.to_lower() == tile_name.to_lower():
						var lib_img := img.duplicate()
						lib_img.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
						update_tile(bt, ti, lib_img)
						print("AGCK TileLib: Reimported tile ", tiles[bt][ti]["name"])
						return
