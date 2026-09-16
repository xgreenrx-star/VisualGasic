@tool
## Pixelify post-pass: reduces a high-res AI-generated image to a clean
## sprite-friendly pixel grid.
##
## Strategy:
##   1. Bilinear downscale to (target_w * 2, target_h * 2) for some smoothing.
##   2. Nearest-neighbor downscale to (target_w, target_h) — this snaps to a
##      crisp pixel grid.
##   3. Optional palette quantization: round each channel to N steps to give
##      a retro look.
##   4. Optional alpha-key: pixels whose RGB is close to a "background" color
##      become transparent (handy for getting sprite cutouts on white BGs).
##
## Returns a NEW Image; the original is untouched.
extends RefCounted

const Self := preload("res://addons/visual_gasic/plugins/vgaiart/pixelify.gd")

static func pixelify(
	src: Image,
	target_w: int,
	target_h: int,
	palette_steps: int = 0,
	alpha_key: Color = Color(0, 0, 0, 0),
	alpha_key_tolerance: float = 0.0
) -> Image:
	if src == null or src.is_empty():
		return src
	target_w = max(1, target_w)
	target_h = max(1, target_h)

	var out := Image.new()
	out.copy_from(src)
	if out.get_format() != Image.FORMAT_RGBA8:
		out.convert(Image.FORMAT_RGBA8)

	# Step 1: bilinear smoothing to 2x target.
	var mid_w := max(target_w * 2, 1)
	var mid_h := max(target_h * 2, 1)
	if out.get_width() > mid_w or out.get_height() > mid_h:
		out.resize(mid_w, mid_h, Image.INTERPOLATE_BILINEAR)

	# Step 2: nearest-neighbor snap to target.
	out.resize(target_w, target_h, Image.INTERPOLATE_NEAREST)

	# Step 3: palette quantization (per-channel posterize).
	if palette_steps > 1:
		_posterize(out, palette_steps)

	# Step 4: alpha-key cutout.
	if alpha_key_tolerance > 0.0:
		_alpha_key(out, alpha_key, alpha_key_tolerance)

	return out


static func _posterize(img: Image, steps: int) -> void:
	var levels := max(2, steps)
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			c.r = round(c.r * (levels - 1)) / float(levels - 1)
			c.g = round(c.g * (levels - 1)) / float(levels - 1)
			c.b = round(c.b * (levels - 1)) / float(levels - 1)
			img.set_pixel(x, y, c)


static func _alpha_key(img: Image, key: Color, tolerance: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var t2 := tolerance * tolerance
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var dr := c.r - key.r
			var dg := c.g - key.g
			var db := c.b - key.b
			if dr * dr + dg * dg + db * db <= t2:
				c.a = 0.0
				img.set_pixel(x, y, c)
