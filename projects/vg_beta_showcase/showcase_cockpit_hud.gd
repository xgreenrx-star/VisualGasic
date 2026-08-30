extends Control
## 2D Star Fox-style cockpit overlay — frame, reticle, consoles; demo on center screen.

const COL_FRAME := Color(0.06, 0.07, 0.09, 0.94)
const COL_FRAME_EDGE := Color(0.55, 0.58, 0.62, 0.98)
const COL_CONSOLE := Color(0.12, 0.13, 0.16, 0.97)
const COL_CONSOLE_HI := Color(0.22, 0.24, 0.28, 0.98)
const COL_CYAN := Color(0.15, 0.82, 1.0)
const COL_CYAN_DIM := Color(0.08, 0.42, 0.62, 0.85)
const COL_BTN := Color(0.12, 0.55, 0.92, 0.95)
const COL_BTN_HI := Color(0.35, 0.78, 1.0, 1.0)

var demo_monitor: TextureRect
var demo_mat: ShaderMaterial
var hud_fade: float = 1.0
var reticle_t: float = 0.0
var zoom_u: float = 0.0
var _viewport_hooked: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_demo_monitor()
	call_deferred("_sync_viewport_size")


func _enter_tree() -> void:
	call_deferred("_sync_viewport_size")
	if not _viewport_hooked and get_viewport():
		get_viewport().size_changed.connect(_sync_viewport_size)
		_viewport_hooked = true


func _sync_viewport_size() -> void:
	var vp := get_viewport_rect().size
	if vp.x < 32.0 or vp.y < 32.0:
		return
	position = Vector2.ZERO
	size = vp
	_layout_demo_monitor()
	queue_redraw()


func _build_demo_monitor() -> void:
	demo_monitor = TextureRect.new()
	demo_monitor.name = "DemoMonitor"
	demo_monitor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	demo_monitor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	demo_monitor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	demo_mat = ShaderMaterial.new()
	demo_mat.shader = load("res://shaders/cockpit_screen_ui.gdshader")
	demo_mat.set_shader_parameter("crt_mix", 1.0)
	demo_mat.set_shader_parameter("scan", 0.55)
	demo_mat.set_shader_parameter("glow", 0.95)
	demo_mat.set_shader_parameter("preview_dim", 0.9)
	demo_monitor.material = demo_mat
	demo_monitor.z_index = 2
	add_child(demo_monitor)
	_layout_demo_monitor()


func set_demo_texture(tex: Texture2D) -> void:
	if demo_mat:
		demo_mat.set_shader_parameter("screen_tex", tex)
	if demo_monitor:
		demo_monitor.texture = tex


func set_hud_fade(v: float) -> void:
	hud_fade = clampf(v, 0.0, 1.0)
	modulate.a = hud_fade
	queue_redraw()


func set_zoom_progress(u: float) -> void:
	zoom_u = clampf(u, 0.0, 1.0)
	hud_fade = 1.0 - smoothstep(0.25, 0.85, zoom_u)
	modulate.a = hud_fade
	_layout_demo_monitor()
	queue_redraw()


func set_crt_mix(v: float) -> void:
	if demo_mat:
		demo_mat.set_shader_parameter("crt_mix", v)


func set_crt_glow(v: float) -> void:
	if demo_mat:
		demo_mat.set_shader_parameter("glow", v)


func get_demo_monitor_global_rect() -> Rect2:
	if demo_monitor:
		return demo_monitor.get_global_rect()
	return Rect2()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_viewport_size()


func _process(delta: float) -> void:
	reticle_t += delta
	queue_redraw()


func _layout_demo_monitor() -> void:
	if not demo_monitor:
		return
	var vp := size
	if vp.x < 32.0 or vp.y < 32.0:
		return

	# Center main screen on lower console (reference layout).
	var base := Rect2(vp.x * 0.31, vp.y * 0.58, vp.x * 0.38, vp.y * 0.22)
	if zoom_u > 0.001:
		var full := Rect2(Vector2.ZERO, vp)
		var eased := smoothstep(0.0, 1.0, zoom_u)
		var pos := base.position.lerp(full.position, eased)
		var sz := base.size.lerp(full.size, eased)
		demo_monitor.set_position(pos)
		demo_monitor.set_size(sz)
	else:
		demo_monitor.set_position(base.position)
		demo_monitor.set_size(base.size)


func _draw() -> void:
	var vp := size
	if vp.x < 32.0:
		return
	var fade := hud_fade
	if fade < 0.01 and zoom_u < 0.99:
		return

	_draw_canopy_frame(vp, fade)
	_draw_reticle(vp, fade)
	if zoom_u < 0.65:
		_draw_console(vp, fade)
		_draw_side_panels(vp, fade)


func _draw_canopy_frame(vp: Vector2, fade: float) -> void:
	var top_l := Vector2(vp.x * 0.02, 0.0)
	var top_r := Vector2(vp.x * 0.98, 0.0)
	var mid_l := Vector2(vp.x * 0.34, vp.y * 0.42)
	var mid_r := Vector2(vp.x * 0.66, vp.y * 0.42)
	var bot_l := Vector2(vp.x * 0.18, vp.y * 0.56)
	var bot_r := Vector2(vp.x * 0.82, vp.y * 0.56)

	var pillar_w := maxf(vp.x * 0.028, 8.0)
	_draw_quad_filled([top_l, mid_l, bot_l, bot_l + Vector2(-pillar_w, pillar_w * 0.4)], COL_FRAME * Color(1, 1, 1, fade))
	_draw_quad_filled([top_r, mid_r, bot_r, bot_r + Vector2(pillar_w, pillar_w * 0.4)], COL_FRAME * Color(1, 1, 1, fade))

	# Upper rail + glare strip.
	draw_line(top_l, top_r, COL_FRAME_EDGE * Color(1, 1, 1, fade * 0.7), 2.0)
	draw_line(mid_l, mid_r, COL_FRAME_EDGE * Color(1, 1, 1, fade * 0.35), 1.0)


func _draw_reticle(vp: Vector2, fade: float) -> void:
	if zoom_u > 0.5:
		return
	var c := Vector2(vp.x * 0.5, vp.y * 0.28)
	var pulse := 0.85 + sin(reticle_t * 3.2) * 0.15
	var col := COL_CYAN * Color(1, 1, 1, fade * pulse)
	var dim := COL_CYAN_DIM * Color(1, 1, 1, fade * 0.65)

	var r_outer := vp.x * 0.075
	var r_inner := r_outer * 0.42
	_draw_arc_poly(c, r_outer, -PI * 0.78, -PI * 0.22, col, 2.0)
	_draw_arc_poly(c, r_outer, PI * 0.22, PI * 0.78, col, 2.0)
	_draw_arc_poly(c, r_inner, 0.0, TAU, dim, 1.5)

	# Wing brackets (Star Fox triangles simplified as chevrons).
	var wing_y := c.y
	var wing_span := vp.x * 0.11
	for side in [-1, 1]:
		var sx := float(side)
		var tip := c + Vector2(sx * wing_span, 0.0)
		var a := c + Vector2(sx * wing_span * 0.55, -10.0)
		var b := c + Vector2(sx * wing_span * 0.55, 10.0)
		draw_colored_polygon(PackedVector2Array([tip, a, b]), col)

	# Crosshair center.
	draw_line(c + Vector2(-14, 0), c + Vector2(14, 0), col, 2.0)
	draw_line(c + Vector2(0, -14), c + Vector2(0, 14), col, 2.0)
	draw_circle(c, 3.0, col)

	# Orientation bars (SNES cockpit HUD).
	var bar_w := 4.0
	var bar_h := vp.y * 0.09
	draw_rect(Rect2(8.0, c.y - bar_h * 0.5, bar_w, bar_h), dim)
	draw_rect(Rect2(vp.x - 8.0 - bar_w, c.y - bar_h * 0.5, bar_w, bar_h), dim)
	draw_rect(Rect2(c.x - bar_h * 0.35, 10.0, bar_h * 0.7, bar_w), dim)
	draw_rect(Rect2(c.x - bar_h * 0.35, vp.y * 0.52, bar_h * 0.7, bar_w), dim)


func _draw_console(vp: Vector2, fade: float) -> void:
	var y0 := vp.y * 0.54
	var h := vp.y - y0
	var body := Rect2(0.0, y0, vp.x, h)
	draw_rect(body, COL_CONSOLE * Color(1, 1, 1, fade))

	# Angled upper lip.
	var lip := PackedVector2Array([
		Vector2(0.0, y0),
		Vector2(vp.x, y0),
		Vector2(vp.x * 0.92, y0 + h * 0.06),
		Vector2(vp.x * 0.08, y0 + h * 0.06),
	])
	draw_colored_polygon(lip, COL_CONSOLE_HI * Color(1, 1, 1, fade))

	# Side button banks (3×3 glowing squares).
	_draw_button_grid(Vector2(vp.x * 0.06, y0 + h * 0.18), vp.x * 0.11, fade)
	_draw_button_grid(Vector2(vp.x * 0.83, y0 + h * 0.18), vp.x * 0.11, fade)

	# Left / right auxiliary screens.
	_draw_aux_screen(Rect2(vp.x * 0.17, y0 + h * 0.14, vp.x * 0.12, h * 0.34), fade, true)
	_draw_aux_screen(Rect2(vp.x * 0.71, y0 + h * 0.14, vp.x * 0.12, h * 0.34), fade, false)

	# Monitor bezel (demo TextureRect sits inside).
	var mon := Rect2(vp.x * 0.31, vp.y * 0.58, vp.x * 0.38, vp.y * 0.22)
	draw_rect(mon.grow(6.0), COL_FRAME_EDGE * Color(1, 1, 1, fade * 0.85))
	draw_rect(mon.grow(2.0), Color(0.04, 0.05, 0.07, fade))

	# Stick + throttle silhouettes.
	var stick_c := Vector2(vp.x * 0.5, y0 + h * 0.78)
	draw_circle(stick_c, 10.0, Color(0.05, 0.05, 0.06, fade))
	draw_circle(stick_c + Vector2(0, -16), 7.0, Color(0.75, 0.12, 0.12, fade))
	draw_rect(Rect2(vp.x * 0.22, y0 + h * 0.72, 14.0, h * 0.18), COL_FRAME_EDGE * Color(1, 1, 1, fade * 0.5))


func _draw_side_panels(vp: Vector2, fade: float) -> void:
	# Lower side rails.
	var y := vp.y * 0.56
	draw_rect(Rect2(0.0, y, vp.x * 0.14, vp.y - y), COL_FRAME * Color(1, 1, 1, fade * 0.55))
	draw_rect(Rect2(vp.x * 0.86, y, vp.x * 0.14, vp.y - y), COL_FRAME * Color(1, 1, 1, fade * 0.55))


func _draw_button_grid(origin: Vector2, width: float, fade: float) -> void:
	var cell := width / 3.2
	for row in 3:
		for col in 3:
			var r := Rect2(origin.x + float(col) * cell, origin.y + float(row) * cell, cell * 0.82, cell * 0.82)
			var hi := (row + col) % 2 == 0
			var col_c := COL_BTN_HI if hi else COL_BTN
			draw_rect(r, col_c * Color(1, 1, 1, fade * (0.75 if hi else 0.55)))


func _draw_aux_screen(rect: Rect2, fade: float, radar: bool) -> void:
	draw_rect(rect, Color(0.03, 0.05, 0.08, fade))
	draw_rect(rect.grow(-2.0), COL_CYAN_DIM * Color(1, 1, 1, fade * 0.35))
	if radar:
		var c := rect.get_center()
		draw_arc(c, rect.size.x * 0.32, 0.0, TAU, 24, COL_CYAN * Color(1, 1, 1, fade * 0.5), 1.0)
		draw_line(c, c + Vector2(rect.size.x * 0.28, 0.0), COL_CYAN * Color(1, 1, 1, fade * 0.7), 1.0)
	else:
		var t := "%02d %02d %02d %02d" % [
			int(reticle_t * 3.0) % 60,
			int(reticle_t * 7.0) % 60,
			int(reticle_t * 1.3) % 99,
			int(reticle_t * 2.1) % 99,
		]
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(8, 22), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COL_CYAN * Color(1, 1, 1, fade))


func _draw_quad_filled(points: Array, col: Color) -> void:
	var packed := PackedVector2Array()
	for p in points:
		packed.append(p as Vector2)
	draw_colored_polygon(packed, col)


func _draw_arc_poly(center: Vector2, radius: float, from: float, to: float, col: Color, width: float) -> void:
	var steps := 16
	var pts := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / float(steps)
		var a := lerpf(from, to, t)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	for i in pts.size() - 1:
		draw_line(pts[i], pts[i + 1], col, width)
