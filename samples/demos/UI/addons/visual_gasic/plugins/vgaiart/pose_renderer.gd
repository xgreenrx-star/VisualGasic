@tool
## Procedural OpenPose-style skeleton renderer.
##
## Renders a stick figure on a black background using the canonical
## OpenPose 18-joint color scheme so the ControlNet OpenPose model
## (control_v11p_sd15_openpose) accepts it directly with module="none".
##
## Joint indices follow OpenPose body_18:
##   0 nose, 1 neck,
##   2 r_shoulder, 3 r_elbow, 4 r_wrist,
##   5 l_shoulder, 6 l_elbow, 7 l_wrist,
##   8 r_hip,      9 r_knee,  10 r_ankle,
##   11 l_hip,    12 l_knee,  13 l_ankle,
##   14 r_eye,    15 l_eye,   16 r_ear, 17 l_ear
##
## A keypoint of Vector2(-1, -1) means "joint not visible — skip".
## Keypoints are normalized 0..1 in image space (x right, y down).
class_name VGAIArtPoseRenderer
extends RefCounted

# Standard OpenPose joint colors (RGB).
const JOINT_COLORS := [
	Color8(255,   0,   0),  # 0  nose
	Color8(255,  85,   0),  # 1  neck
	Color8(255, 170,   0),  # 2  r_shoulder
	Color8(255, 255,   0),  # 3  r_elbow
	Color8(170, 255,   0),  # 4  r_wrist
	Color8( 85, 255,   0),  # 5  l_shoulder
	Color8(  0, 255,   0),  # 6  l_elbow
	Color8(  0, 255,  85),  # 7  l_wrist
	Color8(  0, 255, 170),  # 8  r_hip
	Color8(  0, 255, 255),  # 9  r_knee
	Color8(  0, 170, 255),  # 10 r_ankle
	Color8(  0,  85, 255),  # 11 l_hip
	Color8(  0,   0, 255),  # 12 l_knee
	Color8( 85,   0, 255),  # 13 l_ankle
	Color8(170,   0, 255),  # 14 r_eye
	Color8(255,   0, 255),  # 15 l_eye
	Color8(255,   0, 170),  # 16 r_ear
	Color8(255,   0,  85),  # 17 l_ear
]

# Limb pairs (a, b, color_index_in_JOINT_COLORS-ish).
# Colors here are the standard OpenPose limb colors.
const LIMBS := [
	[1, 2, Color8(255,   0,   0)],  # neck → r_shoulder
	[2, 3, Color8(255,  85,   0)],  # r_shoulder → r_elbow
	[3, 4, Color8(255, 170,   0)],  # r_elbow → r_wrist
	[1, 5, Color8(255, 255,   0)],  # neck → l_shoulder
	[5, 6, Color8(170, 255,   0)],  # l_shoulder → l_elbow
	[6, 7, Color8( 85, 255,   0)],  # l_elbow → l_wrist
	[1, 8, Color8(  0, 255,   0)],  # neck → r_hip
	[8, 9, Color8(  0, 255,  85)],  # r_hip → r_knee
	[9, 10, Color8( 0, 255, 170)],  # r_knee → r_ankle
	[1, 11, Color8( 0, 255, 255)],  # neck → l_hip
	[11, 12, Color8(0, 170, 255)],  # l_hip → l_knee
	[12, 13, Color8(0,  85, 255)],  # l_knee → l_ankle
	[1, 0, Color8(  0,   0, 255)],  # neck → nose
	[0, 14, Color8(85,  0, 255)],   # nose → r_eye
	[0, 15, Color8(170, 0, 255)],   # nose → l_eye
	[14, 16, Color8(255, 0, 255)],  # r_eye → r_ear
	[15, 17, Color8(255, 0, 170)],  # l_eye → l_ear
]


## Render a skeleton from normalized keypoints.
##
## keypoints: Array[Vector2] of length 18. Use Vector2(-1, -1) to skip.
## w, h: output image size in pixels.
## limb_thickness: thickness in pixels for bones.
## joint_radius: radius in pixels for joint dots.
static func render(keypoints: Array, w: int, h: int,
		limb_thickness: int = 4, joint_radius: int = 4) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color.BLACK)

	# Convert normalized keypoints to pixel coordinates once.
	var pts: Array = []
	pts.resize(JOINT_COLORS.size())
	for i in JOINT_COLORS.size():
		if i < keypoints.size():
			var kp: Vector2 = keypoints[i]
			if kp.x < 0.0 or kp.y < 0.0:
				pts[i] = null
			else:
				pts[i] = Vector2(kp.x * w, kp.y * h)
		else:
			pts[i] = null

	# Draw bones first.
	for limb in LIMBS:
		var a_idx: int = limb[0]
		var b_idx: int = limb[1]
		var col: Color = limb[2]
		var a = pts[a_idx]
		var b = pts[b_idx]
		if a == null or b == null:
			continue
		_draw_thick_line(img, a, b, col, limb_thickness)

	# Joints on top.
	for i in pts.size():
		if pts[i] == null:
			continue
		_draw_disc(img, pts[i], joint_radius, JOINT_COLORS[i])

	return img


## Bresenham line stamped with a small filled disc per pixel — gives
## consistent thickness without antialiasing artifacts that confuse
## the OpenPose ControlNet model.
static func _draw_thick_line(img: Image, a: Vector2, b: Vector2, col: Color, thickness: int) -> void:
	var x0: int = int(round(a.x))
	var y0: int = int(round(a.y))
	var x1: int = int(round(b.x))
	var y1: int = int(round(b.y))
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	var r: int = max(1, thickness / 2)
	while true:
		_draw_disc(img, Vector2(x0, y0), r, col)
		if x0 == x1 and y0 == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


static func _draw_disc(img: Image, center: Vector2, r: int, col: Color) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var cx: int = int(round(center.x))
	var cy: int = int(round(center.y))
	var r2: int = r * r
	for dy in range(-r, r + 1):
		var y: int = cy + dy
		if y < 0 or y >= h:
			continue
		for dx in range(-r, r + 1):
			var x: int = cx + dx
			if x < 0 or x >= w:
				continue
			if dx * dx + dy * dy <= r2:
				img.set_pixel(x, y, col)


## Convenience: render to base64 PNG string for direct A1111 API use.
static func render_b64(keypoints: Array, w: int, h: int,
		limb_thickness: int = 4, joint_radius: int = 4) -> String:
	var img := render(keypoints, w, h, limb_thickness, joint_radius)
	var png_bytes := img.save_png_to_buffer()
	return Marshalls.raw_to_base64(png_bytes)
