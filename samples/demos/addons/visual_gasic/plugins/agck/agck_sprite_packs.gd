@tool
## AGCK Sprite Packs — built-in CC0 procedural sprite library.
##
## Each pack is a named character/object with one or more named animations
## (Idle, Walk, Jump, Hop, Fly, Spin, ...). Frames are 24×24 to match
## ACTOR_SPRITE_SIZE so they drop straight into `tile_library.update_actor_anims`.
##
## Adding a new pack: append a dict to PACKS, write a `_gen_<id>()` generator
## that returns `{anim_name: [Image, ...]}`, and dispatch in `generate_anims()`.
class_name AGCKSpritePacks
extends RefCounted

const SIZE = 24
const TRANSPARENT = Color(0, 0, 0, 0)
const BLACK = Color(0.05, 0.05, 0.10)

# ─── Pack manifest ───────────────────────────────────────────
## Each entry: {id, name, kind, tint (preview), subtitle}
##   kind: "humanoid" | "walker" | "blob" | "flyer" | "pickup" | "powerup"
const PACKS: Array = [
	{"id": "knight",   "name": "Knight Hero",       "kind": "humanoid", "tint": Color(0.30, 0.55, 1.00), "subtitle": "Platformer protagonist (Idle / Walk / Jump)"},
	{"id": "goomba",   "name": "Mushroom Stomper",  "kind": "walker",   "tint": Color(0.55, 0.35, 0.20), "subtitle": "Walking enemy, ledge-aware (Walk)"},
	{"id": "slime",    "name": "Bouncy Slime",      "kind": "blob",     "tint": Color(0.30, 0.85, 0.40), "subtitle": "Squishing enemy (Idle / Hop)"},
	{"id": "skeleton", "name": "Skeleton",          "kind": "walker",   "tint": Color(0.92, 0.92, 0.85), "subtitle": "Undead foot-soldier (Idle / Walk)"},
	{"id": "vampbat",  "name": "Vampire Bat",       "kind": "flyer",    "tint": Color(0.55, 0.30, 0.65), "subtitle": "Flapping flyer (Fly)"},
	{"id": "coin",     "name": "Spinning Coin",     "kind": "pickup",   "tint": Color(1.00, 0.85, 0.20), "subtitle": "Rotating coin pickup (Idle 4f)"},
	{"id": "mushroom", "name": "Power-Up Mushroom", "kind": "powerup",  "tint": Color(0.95, 0.20, 0.20), "subtitle": "Mario-style power-up (Idle)"},
	{"id": "star",     "name": "Star Power-Up",     "kind": "powerup",  "tint": Color(1.00, 0.90, 0.30), "subtitle": "Sparkly invincibility star (Idle 4f)"},
]


# ═══════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════

static func get_pack(pack_id: String) -> Dictionary:
	for p in PACKS:
		if p.get("id", "") == pack_id:
			return p
	return {}


## Generate the full {anim_name: [Image,...]} dict for a pack.
static func generate_anims(pack_id: String) -> Dictionary:
	match pack_id:
		"knight":   return _gen_knight()
		"goomba":   return _gen_goomba()
		"slime":    return _gen_slime()
		"skeleton": return _gen_skeleton()
		"vampbat":  return _gen_vampbat()
		"coin":     return _gen_coin()
		"mushroom": return _gen_mushroom()
		"star":     return _gen_star()
	return {}


## Animation-data list that matches the pack (for actor.anim_data sync).
static func anim_data_for(pack_id: String) -> Array:
	var anims := generate_anims(pack_id)
	var out: Array = []
	for k in anims.keys():
		out.append({"name": String(k), "speed": 8, "loop": (String(k) != "Jump")})
	return out


## Thumbnail texture (first frame of first anim).
static func get_thumbnail(pack_id: String) -> ImageTexture:
	var anims := generate_anims(pack_id)
	if anims.size() == 0:
		return null
	var first: Array = anims[anims.keys()[0]]
	if first.size() == 0:
		return null
	return ImageTexture.create_from_image(first[0])


# ═══════════════════════════════════════════════════════════════
# PIXEL HELPERS
# ═══════════════════════════════════════════════════════════════

static func _new_img() -> Image:
	var img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(TRANSPARENT)
	return img


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < SIZE and y < SIZE:
		img.set_pixel(x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


static func _circle(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	var r2 := r * r
	for yy in range(cy - r, cy + r + 1):
		for xx in range(cx - r, cx + r + 1):
			var dx := xx - cx
			var dy := yy - cy
			if dx * dx + dy * dy <= r2:
				_px(img, xx, yy, c)


static func _ring(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	var r2 := r * r
	var inner := (r - 1) * (r - 1)
	for yy in range(cy - r, cy + r + 1):
		for xx in range(cx - r, cx + r + 1):
			var dx := xx - cx
			var dy := yy - cy
			var d2 := dx * dx + dy * dy
			if d2 <= r2 and d2 > inner:
				_px(img, xx, yy, c)


static func _outline_left_right(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	_rect(img, x, y, 1, h, c)
	_rect(img, x + w - 1, y, 1, h, c)


# ═══════════════════════════════════════════════════════════════
# PACK GENERATORS
# ═══════════════════════════════════════════════════════════════

# ── KNIGHT ──────────────────────────────────────────────────
static func _gen_knight() -> Dictionary:
	return {
		"Idle": [_knight(0), _knight(1)],
		"Walk": [_knight(0), _knight(2), _knight(0), _knight(3)],
		"Jump": [_knight(4)],
	}


static func _knight(phase: int) -> Image:
	var img = _new_img()
	var body = Color(0.30, 0.55, 1.00)
	var armor = body.darkened(0.30)
	var plume = Color(0.95, 0.50, 0.20)
	var skin = Color(0.95, 0.80, 0.65)
	var sword = Color(0.88, 0.90, 0.96)
	var hilt = Color(0.50, 0.30, 0.10)
	var boot = Color(0.18, 0.13, 0.08)
	var bob := 1 if phase == 1 else 0          # idle 2nd frame bobs down
	var leg_l := 0
	var leg_r := 0
	if phase == 2:
		leg_l = 1; leg_r = -1                  # walk frame A
	if phase == 3:
		leg_l = -1; leg_r = 1                  # walk frame B
	var jumping := phase == 4
	var oy := -bob if not jumping else -2      # jump rises 2px

	# Plume
	_rect(img, 11, 1 + oy, 2, 3, plume)
	# Helmet
	_rect(img, 8, 3 + oy, 8, 5, armor)
	# Face slit
	_rect(img, 10, 5 + oy, 4, 1, skin)
	_px(img, 10, 5 + oy, BLACK)
	_px(img, 13, 5 + oy, BLACK)
	# Body / chestplate
	_rect(img, 8, 8 + oy, 8, 5, body)
	_rect(img, 8, 8 + oy, 8, 1, armor)         # shoulder line
	_rect(img, 11, 11 + oy, 2, 1, armor)       # belt buckle
	# Sword (right side)
	_rect(img, 16, 7 + oy, 1, 6, sword)
	_rect(img, 15, 12 + oy, 3, 1, hilt)
	# Shield (left)
	_rect(img, 6, 9 + oy, 2, 4, body.darkened(0.1))
	_rect(img, 6, 9 + oy, 2, 1, armor)
	# Legs
	if jumping:
		_rect(img, 9, 13, 2, 3, armor)         # legs tucked
		_rect(img, 13, 13, 2, 3, armor)
		_rect(img, 9, 16, 6, 1, boot)
	else:
		_rect(img, 9, 13 + leg_l, 2, 3, armor)
		_rect(img, 13, 13 + leg_r, 2, 3, armor)
		_rect(img, 9, 16 + leg_l, 3, 1, boot)
		_rect(img, 12, 16 + leg_r, 3, 1, boot)
	return img


# ── GOOMBA / MUSHROOM-STOMPER ──────────────────────────────
static func _gen_goomba() -> Dictionary:
	return {
		"Idle": [_goomba(0)],
		"Walk": [_goomba(0), _goomba(1)],
	}


static func _goomba(phase: int) -> Image:
	var img = _new_img()
	var cap = Color(0.55, 0.35, 0.20)
	var cap_dk = cap.darkened(0.25)
	var body = Color(0.85, 0.70, 0.50)
	var foot = Color(0.20, 0.13, 0.08)
	var leg_l := 0 if phase == 0 else 1
	var leg_r := 1 if phase == 0 else 0

	# Cap top (rounded-ish)
	_rect(img, 4, 4, 16, 7, cap)
	_rect(img, 6, 3, 12, 1, cap)
	_rect(img, 8, 2, 8, 1, cap)
	_rect(img, 4, 10, 16, 1, cap_dk)            # underside shadow
	# Eyes (angry brows)
	_rect(img, 8, 6, 3, 2, Color.WHITE)
	_rect(img, 13, 6, 3, 2, Color.WHITE)
	_px(img, 9, 7, BLACK)
	_px(img, 14, 7, BLACK)
	_rect(img, 8, 5, 3, 1, BLACK)               # left brow
	_rect(img, 13, 5, 3, 1, BLACK)              # right brow
	# Mouth (frown)
	_rect(img, 10, 9, 4, 1, BLACK)
	_px(img, 9, 10, BLACK)
	_px(img, 14, 10, BLACK)
	# Body
	_rect(img, 7, 11, 10, 5, body)
	# Feet
	_rect(img, 5, 16 + leg_l, 5, 3, foot)
	_rect(img, 14, 16 + leg_r, 5, 3, foot)
	return img


# ── SLIME ──────────────────────────────────────────────────
static func _gen_slime() -> Dictionary:
	return {
		"Idle": [_slime(0), _slime(1)],
		"Hop":  [_slime(2), _slime(3), _slime(2), _slime(0)],
	}


static func _slime(phase: int) -> Image:
	var img = _new_img()
	var body = Color(0.30, 0.85, 0.40)
	var dark = body.darkened(0.30)
	var shine = Color(0.85, 1.00, 0.85)
	# 0 = neutral, 1 = squashed (idle 2nd), 2 = stretched up (hop apex), 3 = stretched horiz (hop start)
	var top_y := 8
	var bot_y := 19
	var left_x := 4
	var right_x := 19
	match phase:
		1:
			top_y = 11; bot_y = 19; left_x = 3; right_x = 20
		2:
			top_y = 5; bot_y = 18; left_x = 6; right_x = 17
		3:
			top_y = 9; bot_y = 19; left_x = 2; right_x = 21
	# Body fill
	for y in range(top_y, bot_y + 1):
		var t: float = float(y - top_y) / max(1.0, float(bot_y - top_y))
		var w := int(lerp(float(right_x - left_x) * 0.6, float(right_x - left_x), t))
		var cx := (left_x + right_x) / 2
		_rect(img, cx - w / 2, y, w, 1, body)
	# Outline-ish darker bottom
	_rect(img, left_x + 2, bot_y, right_x - left_x - 4, 1, dark)
	# Eyes
	var eye_y := top_y + 3
	_px(img, left_x + 4, eye_y, BLACK)
	_px(img, right_x - 4, eye_y, BLACK)
	_px(img, left_x + 4, eye_y - 1, Color.WHITE)
	_px(img, right_x - 4, eye_y - 1, Color.WHITE)
	# Shine highlight
	_px(img, left_x + 3, top_y + 1, shine)
	_px(img, left_x + 4, top_y + 1, shine)
	return img


# ── SKELETON ──────────────────────────────────────────────
static func _gen_skeleton() -> Dictionary:
	return {
		"Idle": [_skeleton(0), _skeleton(1)],
		"Walk": [_skeleton(0), _skeleton(2), _skeleton(0), _skeleton(3)],
	}


static func _skeleton(phase: int) -> Image:
	var img = _new_img()
	var bone = Color(0.92, 0.92, 0.85)
	var bone_dk = bone.darkened(0.25)
	var bob := 1 if phase == 1 else 0
	var leg_l := 0
	var leg_r := 0
	if phase == 2: leg_l = 1; leg_r = -1
	if phase == 3: leg_l = -1; leg_r = 1
	var oy := -bob

	# Skull
	_circle(img, 12, 5 + oy, 4, bone)
	_rect(img, 8, 5 + oy, 9, 4, bone)
	# Eye sockets
	_rect(img, 9, 5 + oy, 2, 2, BLACK)
	_rect(img, 13, 5 + oy, 2, 2, BLACK)
	# Teeth
	_rect(img, 10, 8 + oy, 5, 1, BLACK)
	_px(img, 11, 8 + oy, bone)
	_px(img, 13, 8 + oy, bone)
	# Spine + ribcage
	_rect(img, 11, 10 + oy, 2, 5, bone)
	_rect(img, 8, 11 + oy, 9, 1, bone)         # shoulders
	_rect(img, 9, 13 + oy, 7, 1, bone_dk)      # rib
	_rect(img, 9, 14 + oy, 7, 1, bone_dk)      # rib
	# Arms (sword right)
	_rect(img, 7, 11 + oy, 1, 4, bone)
	_rect(img, 17, 11 + oy, 1, 4, bone)
	_rect(img, 18, 8 + oy, 1, 7, Color(0.75, 0.75, 0.85))   # sword blade
	# Legs
	_rect(img, 10, 15 + leg_l, 2, 4, bone)
	_rect(img, 13, 15 + leg_r, 2, 4, bone)
	return img


# ── VAMPIRE BAT ────────────────────────────────────────────
static func _gen_vampbat() -> Dictionary:
	return {
		"Fly": [_vampbat(0), _vampbat(1), _vampbat(2), _vampbat(1)],
	}


static func _vampbat(wing_phase: int) -> Image:
	var img = _new_img()
	var body = Color(0.32, 0.18, 0.40)
	var wing = Color(0.55, 0.30, 0.65)
	var wing_dk = wing.darkened(0.3)
	var fang = Color.WHITE

	# Body
	_circle(img, 12, 12, 3, body)
	_rect(img, 11, 9, 3, 2, body)              # head/ears base
	_px(img, 10, 8, body)                       # left ear tip
	_px(img, 14, 8, body)                       # right ear tip
	# Eyes (red glow)
	_px(img, 11, 11, Color(1, 0.3, 0.3))
	_px(img, 13, 11, Color(1, 0.3, 0.3))
	# Fangs
	_px(img, 11, 13, fang)
	_px(img, 13, 13, fang)
	# Wings — phase 0 = up, 1 = mid, 2 = down
	match wing_phase:
		0:
			_rect(img, 4, 7, 5, 4, wing)
			_rect(img, 15, 7, 5, 4, wing)
			_rect(img, 6, 6, 3, 1, wing_dk)
			_rect(img, 15, 6, 3, 1, wing_dk)
		1:
			_rect(img, 3, 11, 6, 3, wing)
			_rect(img, 15, 11, 6, 3, wing)
			_rect(img, 3, 13, 6, 1, wing_dk)
			_rect(img, 15, 13, 6, 1, wing_dk)
		2:
			_rect(img, 4, 14, 5, 4, wing)
			_rect(img, 15, 14, 5, 4, wing)
			_rect(img, 6, 17, 3, 1, wing_dk)
			_rect(img, 15, 17, 3, 1, wing_dk)
	return img


# ── COIN (4-frame spin) ────────────────────────────────────
static func _gen_coin() -> Dictionary:
	return {
		"Idle": [_coin(0), _coin(1), _coin(2), _coin(1)],
	}


static func _coin(phase: int) -> Image:
	var img = _new_img()
	var gold = Color(1.00, 0.85, 0.20)
	var gold_dk = gold.darkened(0.30)
	var gold_lt = Color(1.00, 1.00, 0.55)
	# phase 0 = full circle, 1 = ellipse 3/4, 2 = thin sliver (edge-on)
	match phase:
		0:
			_circle(img, 12, 12, 7, gold)
			_ring(img, 12, 12, 7, gold_dk)
			# $ symbol
			_rect(img, 11, 8, 2, 9, gold_dk)
			_rect(img, 9, 10, 6, 1, gold_dk)
			_rect(img, 9, 14, 6, 1, gold_dk)
			_px(img, 9, 9, gold_lt)
			_px(img, 10, 8, gold_lt)
		1:
			_rect(img, 8, 6, 9, 13, gold)
			_outline_left_right(img, 8, 6, 9, 13, gold_dk)
			_rect(img, 8, 6, 9, 1, gold_dk)
			_rect(img, 8, 18, 9, 1, gold_dk)
			_rect(img, 11, 9, 3, 7, gold_dk)
		2:
			_rect(img, 11, 6, 3, 13, gold)
			_rect(img, 11, 6, 3, 1, gold_dk)
			_rect(img, 11, 18, 3, 1, gold_dk)
			_rect(img, 12, 7, 1, 11, gold_lt)
	return img


# ── MUSHROOM POWER-UP ─────────────────────────────────────
static func _gen_mushroom() -> Dictionary:
	return {
		"Idle": [_mushroom_frame()],
	}


static func _mushroom_frame() -> Image:
	var img = _new_img()
	var cap = Color(0.95, 0.20, 0.20)
	var cap_dk = cap.darkened(0.30)
	var spot = Color.WHITE
	var stem = Color(0.98, 0.95, 0.85)
	var stem_dk = Color(0.75, 0.70, 0.55)

	# Cap (rounded)
	_rect(img, 4, 6, 16, 6, cap)
	_rect(img, 5, 5, 14, 1, cap)
	_rect(img, 7, 4, 10, 1, cap)
	_rect(img, 9, 3, 6, 1, cap)
	_rect(img, 4, 11, 16, 1, cap_dk)           # underside shadow
	# White spots
	_circle(img, 8, 7, 1, spot)
	_circle(img, 15, 8, 2, spot)
	_circle(img, 11, 5, 1, spot)
	# Stem / face
	_rect(img, 7, 12, 10, 7, stem)
	_rect(img, 7, 18, 10, 1, stem_dk)
	# Eyes
	_rect(img, 9, 14, 2, 3, BLACK)
	_rect(img, 13, 14, 2, 3, BLACK)
	_px(img, 10, 14, Color.WHITE)
	_px(img, 14, 14, Color.WHITE)
	return img


# ── STAR POWER-UP ─────────────────────────────────────────
static func _gen_star() -> Dictionary:
	return {
		"Idle": [_star(0), _star(1), _star(2), _star(1)],
	}


static func _star(phase: int) -> Image:
	var img = _new_img()
	var yellow = Color(1.00, 0.90, 0.30)
	var yellow_dk = yellow.darkened(0.30)
	var sparkle = Color.WHITE

	# Star body (5-point approx)
	_rect(img, 10, 3, 4, 4, yellow)
	_rect(img, 8, 5, 8, 4, yellow)
	_rect(img, 4, 8, 16, 4, yellow)
	_rect(img, 6, 12, 12, 3, yellow)
	_rect(img, 4, 15, 4, 4, yellow)
	_rect(img, 16, 15, 4, 4, yellow)
	_rect(img, 9, 15, 6, 2, yellow)
	# Outline
	_rect(img, 10, 3, 4, 1, yellow_dk)
	_rect(img, 4, 8, 16, 1, yellow_dk)
	_rect(img, 4, 18, 4, 1, yellow_dk)
	_rect(img, 16, 18, 4, 1, yellow_dk)
	# Eyes
	_rect(img, 9, 9, 2, 3, BLACK)
	_rect(img, 13, 9, 2, 3, BLACK)
	_px(img, 10, 9, Color.WHITE)
	_px(img, 14, 9, Color.WHITE)
	# Sparkle (rotating)
	match phase:
		0:
			_px(img, 2, 4, sparkle)
			_px(img, 21, 14, sparkle)
		1:
			_px(img, 22, 5, sparkle)
			_px(img, 1, 13, sparkle)
		2:
			_px(img, 12, 1, sparkle)
			_px(img, 22, 20, sparkle)
	return img
