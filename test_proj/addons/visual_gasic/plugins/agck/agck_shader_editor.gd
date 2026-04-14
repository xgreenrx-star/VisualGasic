@tool
## AGCK Shader Editor — visual post-processing effects for your game
##
## Apply screen-space shader effects (CRT, Blur, Glow, Pixelate, etc.)
## to your entire game or specific screen regions.
## 10 built-in effects with adjustable properties and live preview.
## Kid-friendly: every control has a helpful tooltip!
extends VBoxContainer

# ─── Theme Colors (shared with other AGCK editors) ───────────
const BG_COLOR  = Color(0.11, 0.11, 0.14)
const HEADER_BG = Color(0.16, 0.16, 0.20)
const CARD_BG   = Color(0.14, 0.14, 0.18)
const WHITE     = Color(1.0, 1.0, 1.0)
const LABEL_CLR = Color(0.85, 0.85, 0.90)
const ACCENT    = Color(0.45, 0.70, 1.0)
const DIM       = Color(0.65, 0.65, 0.70)

const MAX_SHADERS = 8

signal data_changed

# ─── State ────────────────────────────────────────────────────
var shaders: Array = []            # Active shader layer instances
var selected_shader: int = -1      # Currently selected index

# ─── Shader Library ──────────────────────────────────────────
# Populated in _init_shader_library()
# Each entry: { name, icon, description, tooltip, code, uniforms[] }
var _shader_library: Array = []

# ─── UI References ────────────────────────────────────────────
var _card_container: VBoxContainer
var _detail_scroll: ScrollContainer
var _detail_panel: VBoxContainer
var _add_btn: Button
var _remove_btn: Button
var _preview_rect: TextureRect
var _preview_material: ShaderMaterial
var _sample_texture: ImageTexture
var _props_container: VBoxContainer


# ═══════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	_build_ui()


# ═══════════════════════════════════════════════════════════════
# BUILD UI
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	_init_shader_library()
	_generate_sample_texture()

	name = "ShaderEditor"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical   = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 0)

	# ── Background
	var bg = StyleBoxFlat.new()
	bg.bg_color = BG_COLOR
	var bg_panel = PanelContainer.new()
	bg_panel.add_theme_stylebox_override("panel", bg)
	bg_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg_panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	add_child(bg_panel)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 6)
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	bg_panel.add_child(root_vbox)

	# ── Header bar
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root_vbox.add_child(header)

	var title = Label.new()
	title.text = "🎨 Shader Effects"
	title.label_settings = _ls(14, WHITE)
	title.add_theme_color_override("font_color", WHITE)
	title.tooltip_text = "Add cool visual effects to your game!\nEffects are layered on top of your game screen."
	header.add_child(title)

	header.add_child(_spacer())

	_add_btn = Button.new()
	_add_btn.text = "+ Add Effect"
	_add_btn.tooltip_text = "Add a new shader effect layer (up to " + str(MAX_SHADERS) + ")"
	_add_btn.add_theme_font_size_override("font_size", 11)
	_add_btn.pressed.connect(_add_shader)
	header.add_child(_add_btn)

	_remove_btn = Button.new()
	_remove_btn.text = "- Remove"
	_remove_btn.tooltip_text = "Remove the selected shader effect"
	_remove_btn.add_theme_font_size_override("font_size", 11)
	_remove_btn.pressed.connect(_remove_shader)
	header.add_child(_remove_btn)

	# ── Main split: cards (left) + detail (right)
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 6)
	main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(main_hbox)

	# ── Left: card gallery (fixed width)
	var left_panel_bg = PanelContainer.new()
	var lp_style = StyleBoxFlat.new()
	lp_style.bg_color = BG_COLOR
	left_panel_bg.add_theme_stylebox_override("panel", lp_style)
	left_panel_bg.custom_minimum_size = Vector2(200, 0)
	left_panel_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(left_panel_bg)

	var left_scroll = ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var ls_bg = StyleBoxFlat.new()
	ls_bg.bg_color = BG_COLOR
	left_scroll.add_theme_stylebox_override("panel", ls_bg)
	left_panel_bg.add_child(left_scroll)

	_card_container = VBoxContainer.new()
	_card_container.add_theme_constant_override("separation", 4)
	_card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(_card_container)

	# ── Right: detail panel (expandable)
	var right_panel_bg = PanelContainer.new()
	var rp_style = StyleBoxFlat.new()
	rp_style.bg_color = BG_COLOR
	right_panel_bg.add_theme_stylebox_override("panel", rp_style)
	right_panel_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel_bg.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(right_panel_bg)

	_detail_scroll = ScrollContainer.new()
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var rs_bg = StyleBoxFlat.new()
	rs_bg.bg_color = BG_COLOR
	_detail_scroll.add_theme_stylebox_override("panel", rs_bg)
	right_panel_bg.add_child(_detail_scroll)

	_detail_panel = VBoxContainer.new()
	_detail_panel.add_theme_constant_override("separation", 6)
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.add_child(_detail_panel)

	_rebuild_cards()
	_rebuild_detail()


# ═══════════════════════════════════════════════════════════════
# SHADER LIBRARY — 10 built-in effects
# ═══════════════════════════════════════════════════════════════

func _init_shader_library() -> void:
	_shader_library.clear()

	# ── 1. CRT TV ──
	var crt = "shader_type canvas_item;\n"
	crt += "uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;\n"
	crt += "uniform float scanline_strength : hint_range(0.0, 1.0) = 0.3;\n"
	crt += "uniform float curvature : hint_range(0.0, 0.1) = 0.02;\n"
	crt += "void fragment() {\n"
	crt += "\tvec2 uv = SCREEN_UV;\n"
	crt += "\tvec2 dc = uv - 0.5;\n"
	crt += "\tuv = uv + dc * dot(dc, dc) * curvature;\n"
	crt += "\tvec4 color = texture(screen_texture, uv);\n"
	crt += "\tfloat sl = sin(uv.y * 800.0) * 0.5 + 0.5;\n"
	crt += "\tcolor.rgb *= 1.0 - scanline_strength * sl;\n"
	crt += "\tCOLOR = color;\n"
	crt += "}\n"
	_shader_library.append({
		"name": "CRT TV", "icon": "📺",
		"description": "Retro CRT television with scanlines and screen curvature",
		"tooltip": "Makes your game look like it's playing on an old TV!",
		"code": crt,
		"uniforms": [
			{"name": "scanline_strength", "label": "Scanlines", "type": "float", "default": 0.3, "min": 0.0, "max": 1.0, "step": 0.05, "tooltip": "How dark the horizontal TV lines are"},
			{"name": "curvature", "label": "Screen Curve", "type": "float", "default": 0.02, "min": 0.0, "max": 0.1, "step": 0.005, "tooltip": "How curved the screen edges look (like a real old TV)"},
		]
	})

	# ── 2. Pixelate ──
	var pix = "shader_type canvas_item;\n"
	pix += "uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;\n"
	pix += "uniform float pixel_size : hint_range(1.0, 32.0) = 4.0;\n"
	pix += "void fragment() {\n"
	pix += "\tvec2 size = vec2(textureSize(screen_texture, 0));\n"
	pix += "\tvec2 uv = floor(SCREEN_UV * size / pixel_size) * pixel_size / size;\n"
	pix += "\tCOLOR = texture(screen_texture, uv);\n"
	pix += "}\n"
	_shader_library.append({
		"name": "Pixelate", "icon": "🟩",
		"description": "Chunky pixel mosaic — makes everything look more blocky",
		"tooltip": "Makes your game look super chunky and retro!",
		"code": pix,
		"uniforms": [
			{"name": "pixel_size", "label": "Pixel Size", "type": "float", "default": 4.0, "min": 1.0, "max": 32.0, "step": 1.0, "tooltip": "How big each chunky pixel block is (bigger = more blocky)"},
		]
	})

	# ── 3. Blur ──
	var blur = "shader_type canvas_item;\n"
	blur += "uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;\n"
	blur += "uniform float blur_amount : hint_range(0.0, 5.0) = 1.0;\n"
	blur += "void fragment() {\n"
	blur += "\tvec2 ps = 1.0 / vec2(textureSize(screen_texture, 0));\n"
	blur += "\tvec4 color = vec4(0.0);\n"
	blur += "\tfor (int x = -2; x <= 2; x++) {\n"
	blur += "\t\tfor (int y = -2; y <= 2; y++) {\n"
	blur += "\t\t\tcolor += texture(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * ps * blur_amount);\n"
	blur += "\t\t}\n"
	blur += "\t}\n"
	blur += "\tCOLOR = color / 25.0;\n"
	blur += "}\n"
	_shader_library.append({
		"name": "Blur", "icon": "🌫️",
		"description": "Soft gaussian blur — makes everything look dreamy",
		"tooltip": "Makes your game look soft and blurry like a dream!",
		"code": blur,
		"uniforms": [
			{"name": "blur_amount", "label": "Blur Strength", "type": "float", "default": 1.0, "min": 0.0, "max": 5.0, "step": 0.1, "tooltip": "How blurry everything gets (higher = more blurry)"},
		]
	})

	# ── 4. Glow / Bloom ──
	var glow = "shader_type canvas_item;\n"
	glow += "uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;\n"
	glow += "uniform float glow_strength : hint_range(0.0, 2.0) = 0.5;\n"
	glow += "uniform float threshold : hint_range(0.0, 1.0) = 0.5;\n"
	glow += "void fragment() {\n"
	glow += "\tvec4 color = texture(screen_texture, SCREEN_UV);\n"
	glow += "\tvec2 ps = 1.0 / vec2(textureSize(screen_texture, 0));\n"
	glow += "\tvec4 bloom = vec4(0.0);\n"
	glow += "\tfor (int x = -3; x <= 3; x++) {\n"
	glow += "\t\tfor (int y = -3; y <= 3; y++) {\n"
	glow += "\t\t\tvec4 s = texture(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * ps * 2.0);\n"
	glow += "\t\t\tfloat b = max(s.r, max(s.g, s.b));\n"
	glow += "\t\t\tif (b > threshold) bloom += s;\n"
	glow += "\t\t}\n"
	glow += "\t}\n"
	glow += "\tbloom /= 49.0;\n"
	glow += "\tCOLOR = color + bloom * glow_strength;\n"
	glow += "}\n"
	_shader_library.append({
		"name": "Glow", "icon": "✨",
		"description": "Bright areas bloom and glow outward",
		"tooltip": "Makes bright parts of your game shimmer and glow!",
		"code": glow,
		"uniforms": [
			{"name": "glow_strength", "label": "Glow Power", "type": "float", "default": 0.5, "min": 0.0, "max": 2.0, "step": 0.1, "tooltip": "How strong the glowing effect is"},
			{"name": "threshold", "label": "Brightness Cutoff", "type": "float", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.05, "tooltip": "How bright a pixel needs to be before it glows"},
		]
	})

	# ── 5. Chromatic Aberration ──
	var chrom = "shader_type canvas_item;\n"
	chrom += "uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;\n"
	chrom += "uniform float offset : hint_range(0.0, 10.0) = 2.0;\n"
	chrom += "void fragment() {\n"
	chrom += "\tvec2 ps = 1.0 / vec2(textureSize(screen_texture, 0));\n"
	chrom += "\tfloat r = texture(screen_texture, SCREEN_UV + vec2(offset, 0.0) * ps).r;\n"
	chrom += "\tfloat g = texture(screen_texture, SCREEN_UV).g;\n"
	chrom += "\tfloat b = texture(screen_texture, SCREEN_UV - vec2(offset, 0.0) * ps).b;\n"
	chrom += "\tCOLOR = vec4(r, g, b, 1.0);\n"
	chrom += "}\n"
	_shader_library.append({
		"name": "Chromatic Aberration", "icon": "🌈",
		"description": "RGB color channels split apart at the edges",
		"tooltip": "Splits red, green, and blue apart — like a broken lens!",
		"code": chrom,
		"uniforms": [
			{"name": "offset", "label": "Color Split", "type": "float", "default": 2.0, "min": 0.0, "max": 10.0, "step": 0.5, "tooltip": "How far apart the red/green/blue colors split"},
		]
	})

	# ── 6. Vignette ──
	var vig = "shader_type canvas_item;\n"
	vig += "uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;\n"
	vig += "uniform float strength : hint_range(0.0, 2.0) = 0.5;\n"
	vig += "uniform float radius : hint_range(0.1, 1.0) = 0.75;\n"
	vig += "void fragment() {\n"
	vig += "\tvec4 color = texture(screen_texture, SCREEN_UV);\n"
	vig += "\tfloat dist = distance(SCREEN_UV, vec2(0.5));\n"
	vig += "\tfloat v = smoothstep(radius, radius - 0.3, dist);\n"
	vig += "\tcolor.rgb *= mix(1.0 - strength, 1.0, v);\n"
	vig += "\tCOLOR = color;\n"
	vig += "}\n"
	_shader_library.append({
		"name": "Vignette", "icon": "🔲",
		"description": "Dark shadow around the edges of the screen",
		"tooltip": "Darkens the edges of the screen for a cinematic look!",
		"code": vig,
		"uniforms": [
			{"name": "strength", "label": "Darkness", "type": "float", "default": 0.5, "min": 0.0, "max": 2.0, "step": 0.1, "tooltip": "How dark the edges get"},
			{"name": "radius", "label": "Edge Size", "type": "float", "default": 0.75, "min": 0.1, "max": 1.0, "step": 0.05, "tooltip": "How far the dark shadow reaches from the edges"},
		]
	})

	# ── 7. Sepia ──
	var sep = "shader_type canvas_item;\n"
	sep += "uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;\n"
	sep += "uniform float intensity : hint_range(0.0, 1.0) = 0.8;\n"
	sep += "void fragment() {\n"
	sep += "\tvec4 color = texture(screen_texture, SCREEN_UV);\n"
	sep += "\tfloat grey = dot(color.rgb, vec3(0.299, 0.587, 0.114));\n"
	sep += "\tvec3 sepia = vec3(grey) * vec3(1.2, 1.0, 0.8);\n"
	sep += "\tcolor.rgb = mix(color.rgb, sepia, intensity);\n"
	sep += "\tCOLOR = color;\n"
	sep += "}\n"
	_shader_library.append({
		"name": "Sepia", "icon": "📜",
		"description": "Old-timey brownish photo tint",
		"tooltip": "Makes your game look like an old photograph!",
		"code": sep,
		"uniforms": [
			{"name": "intensity", "label": "Old-Timey Amount", "type": "float", "default": 0.8, "min": 0.0, "max": 1.0, "step": 0.05, "tooltip": "How much of the old photo look to apply"},
		]
	})

	# ── 8. Night Vision ──
	var nv = "shader_type canvas_item;\n"
	nv += "uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;\n"
	nv += "uniform float noise_amount : hint_range(0.0, 0.5) = 0.1;\n"
	nv += "uniform float brightness : hint_range(0.5, 3.0) = 1.5;\n"
	nv += "void fragment() {\n"
	nv += "\tvec4 color = texture(screen_texture, SCREEN_UV);\n"
	nv += "\tfloat grey = dot(color.rgb, vec3(0.299, 0.587, 0.114));\n"
	nv += "\tfloat noise = fract(sin(dot(SCREEN_UV + vec2(TIME), vec2(12.9898, 78.233))) * 43758.5453);\n"
	nv += "\tgrey += (noise - 0.5) * noise_amount;\n"
	nv += "\tcolor.rgb = vec3(grey * 0.2, grey * brightness, grey * 0.2);\n"
	nv += "\tCOLOR = color;\n"
	nv += "}\n"
	_shader_library.append({
		"name": "Night Vision", "icon": "🌙",
		"description": "Green-tinted military night vision with static noise",
		"tooltip": "See in the dark like a secret agent with night-vision goggles!",
		"code": nv,
		"uniforms": [
			{"name": "noise_amount", "label": "Static Noise", "type": "float", "default": 0.1, "min": 0.0, "max": 0.5, "step": 0.02, "tooltip": "How much TV static / grain to add"},
			{"name": "brightness", "label": "Green Glow", "type": "float", "default": 1.5, "min": 0.5, "max": 3.0, "step": 0.1, "tooltip": "How bright the green night-vision glow is"},
		]
	})

	# ── 9. Water Ripple ──
	var rip = "shader_type canvas_item;\n"
	rip += "uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;\n"
	rip += "uniform float wave_speed : hint_range(0.5, 5.0) = 2.0;\n"
	rip += "uniform float wave_amount : hint_range(0.0, 0.05) = 0.01;\n"
	rip += "void fragment() {\n"
	rip += "\tvec2 uv = SCREEN_UV;\n"
	rip += "\tuv.x += sin(uv.y * 20.0 + TIME * wave_speed) * wave_amount;\n"
	rip += "\tuv.y += cos(uv.x * 20.0 + TIME * wave_speed) * wave_amount;\n"
	rip += "\tCOLOR = texture(screen_texture, uv);\n"
	rip += "}\n"
	_shader_library.append({
		"name": "Water Ripple", "icon": "🌊",
		"description": "Wavy water-like distortion that animates over time",
		"tooltip": "Makes your game look like you're seeing it through water!",
		"code": rip,
		"uniforms": [
			{"name": "wave_speed", "label": "Wave Speed", "type": "float", "default": 2.0, "min": 0.5, "max": 5.0, "step": 0.25, "tooltip": "How fast the waves move"},
			{"name": "wave_amount", "label": "Wave Size", "type": "float", "default": 0.01, "min": 0.0, "max": 0.05, "step": 0.002, "tooltip": "How big and wiggly the waves are"},
		]
	})

	# ── 10. Glitch ──
	var gli = "shader_type canvas_item;\n"
	gli += "uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;\n"
	gli += "uniform float glitch_strength : hint_range(0.0, 0.1) = 0.02;\n"
	gli += "uniform float glitch_speed : hint_range(0.5, 10.0) = 3.0;\n"
	gli += "void fragment() {\n"
	gli += "\tvec2 uv = SCREEN_UV;\n"
	gli += "\tfloat t = floor(TIME * glitch_speed);\n"
	gli += "\tfloat r = fract(sin(t * 43758.5453) * 2.0);\n"
	gli += "\tif (r > 0.85) {\n"
	gli += "\t\tuv.x += (fract(sin(dot(vec2(t, uv.y * 10.0), vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * glitch_strength;\n"
	gli += "\t}\n"
	gli += "\tfloat cr = texture(screen_texture, uv + vec2(glitch_strength * r, 0.0)).r;\n"
	gli += "\tfloat cg = texture(screen_texture, uv).g;\n"
	gli += "\tfloat cb = texture(screen_texture, uv - vec2(glitch_strength * r, 0.0)).b;\n"
	gli += "\tCOLOR = vec4(cr, cg, cb, 1.0);\n"
	gli += "}\n"
	_shader_library.append({
		"name": "Glitch", "icon": "⚡",
		"description": "Random digital glitch artifacts — screen tears and color splits",
		"tooltip": "Makes your game look like it's glitching out! Great for damage effects!",
		"code": gli,
		"uniforms": [
			{"name": "glitch_strength", "label": "Glitch Power", "type": "float", "default": 0.02, "min": 0.0, "max": 0.1, "step": 0.005, "tooltip": "How strong the glitch effect is"},
			{"name": "glitch_speed", "label": "Glitch Speed", "type": "float", "default": 3.0, "min": 0.5, "max": 10.0, "step": 0.5, "tooltip": "How fast the glitches happen"},
		]
	})


# ═══════════════════════════════════════════════════════════════
# ADD / REMOVE SHADER LAYERS
# ═══════════════════════════════════════════════════════════════

func _add_shader() -> void:
	if shaders.size() >= MAX_SHADERS:
		return
	# Show a popup menu listing all available shader types
	var popup = PopupMenu.new()
	popup.name = "AddShaderPopup"
	# Apply dark popup theme — see POPUP_THEME_FIX.md (Linux X11 fix)
	_apply_dark_popup(popup)
	for li in range(_shader_library.size()):
		var lib = _shader_library[li]
		popup.add_item(lib.get("icon", "🎨") + " " + lib["name"], li)
	popup.id_pressed.connect(func(id):
		_add_shader_of_type(id)
		popup.queue_free()
	)
	popup.popup_hide.connect(func():
		popup.queue_free()
	)
	add_child(popup)
	# Position near the Add button
	var btn_rect = _add_btn.get_global_rect()
	popup.popup(Rect2i(Vector2i(int(btn_rect.position.x), int(btn_rect.end.y)), Vector2i(220, 0)))


func _add_shader_of_type(lib_idx: int) -> void:
	if shaders.size() >= MAX_SHADERS:
		return
	if lib_idx < 0 or lib_idx >= _shader_library.size():
		return
	var lib = _shader_library[lib_idx]
	var new_shader = {
		"shader_name": lib["name"],
		"enabled": true,
		"region_mode": "full_screen",
		"region_x": 0, "region_y": 0, "region_w": 640, "region_h": 480,
		"properties": {},
	}
	for u in lib["uniforms"]:
		new_shader["properties"][u["name"]] = u["default"]
	shaders.append(new_shader)
	selected_shader = shaders.size() - 1
	_rebuild_cards()
	_rebuild_detail()
	data_changed.emit()


func _remove_shader() -> void:
	if selected_shader < 0 or selected_shader >= shaders.size():
		return
	# Confirmation dialog
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Remove this shader effect?\nThis cannot be undone."
	dialog.title = "Remove Shader"
	dialog.confirmed.connect(func():
		shaders.remove_at(selected_shader)
		if selected_shader >= shaders.size():
			selected_shader = shaders.size() - 1
		_rebuild_cards()
		_rebuild_detail()
		data_changed.emit()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(280, 100))


# ═══════════════════════════════════════════════════════════════
# CARD GALLERY (left panel)
# ═══════════════════════════════════════════════════════════════

func _rebuild_cards() -> void:
	for ch in _card_container.get_children():
		ch.queue_free()

	if shaders.size() == 0:
		# ── Show clickable gallery of all available effects ──
		var title = Label.new()
		title.text = "Click an effect to add it:"
		title.label_settings = _ls(11, ACCENT)
		title.add_theme_color_override("font_color", ACCENT)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_card_container.add_child(title)
		for li in range(_shader_library.size()):
			var lib = _shader_library[li]
			var card = _card(Color(0.20, 0.22, 0.30))
			card.tooltip_text = lib.get("tooltip", lib.get("description", ""))
			var lib_idx = li
			card.gui_input.connect(func(ev):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					_add_shader_of_type(lib_idx)
			)
			_card_container.add_child(card)
			var hb = HBoxContainer.new()
			hb.add_theme_constant_override("separation", 6)
			card.add_child(hb)
			var icon = Label.new()
			icon.text = lib.get("icon", "🎨")
			icon.label_settings = _ls(14, WHITE)
			icon.add_theme_color_override("font_color", WHITE)
			hb.add_child(icon)
			var nm = Label.new()
			nm.text = lib["name"]
			nm.label_settings = _ls(11, WHITE)
			nm.add_theme_color_override("font_color", WHITE)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nm.clip_text = true
			hb.add_child(nm)
			var plus = Label.new()
			plus.text = "+"
			plus.label_settings = _ls(12, ACCENT)
			plus.add_theme_color_override("font_color", ACCENT)
			hb.add_child(plus)
		return

	for i in range(shaders.size()):
		var s = shaders[i]
		var sname = s.get("shader_name", "Unknown")
		var enabled = s.get("enabled", true)

		# Find the library entry for the icon
		var icon_str = "🎨"
		for lib in _shader_library:
			if lib["name"] == sname:
				icon_str = lib.get("icon", "🎨")
				break

		var card = _card(CARD_BG if i != selected_shader else Color(0.22, 0.28, 0.40))
		card.tooltip_text = "Click to select and edit this shader effect"
		var idx = i
		card.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				selected_shader = idx
				_rebuild_cards()
				_rebuild_detail()
		)
		_card_container.add_child(card)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		card.add_child(hbox)

		# Index label
		var idx_lbl = Label.new()
		idx_lbl.text = str(i + 1) + "."
		idx_lbl.label_settings = _ls(11, LABEL_CLR)
		idx_lbl.add_theme_color_override("font_color", LABEL_CLR)
		idx_lbl.custom_minimum_size.x = 18
		hbox.add_child(idx_lbl)

		# Icon + name
		var name_lbl = Label.new()
		name_lbl.text = icon_str + " " + sname
		var nm_clr = WHITE if enabled else DIM
		name_lbl.label_settings = _ls(11, nm_clr)
		name_lbl.add_theme_color_override("font_color", nm_clr)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.clip_text = true
		hbox.add_child(name_lbl)

		# Enabled indicator
		if not enabled:
			var off_lbl = Label.new()
			off_lbl.text = "OFF"
			off_lbl.label_settings = _ls(9, Color(0.7, 0.3, 0.3))
			hbox.add_child(off_lbl)

	_add_btn.disabled = shaders.size() >= MAX_SHADERS
	_remove_btn.disabled = shaders.size() == 0


# ═══════════════════════════════════════════════════════════════
# DETAIL PANEL (right panel)
# ═══════════════════════════════════════════════════════════════

func _rebuild_detail() -> void:
	for ch in _detail_panel.get_children():
		ch.queue_free()

	if selected_shader < 0 or selected_shader >= shaders.size():
		# ── Rich welcome / showcase panel ──
		var welcome_card = _card(Color(0.16, 0.18, 0.24))
		_detail_panel.add_child(welcome_card)
		var wvbox = VBoxContainer.new()
		wvbox.add_theme_constant_override("separation", 8)
		welcome_card.add_child(wvbox)
		var wtitle = Label.new()
		wtitle.text = "✨ Visual Effects Gallery"
		wtitle.label_settings = _ls(14, ACCENT)
		wtitle.add_theme_color_override("font_color", ACCENT)
		wtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wvbox.add_child(wtitle)
		var wdesc = Label.new()
		wdesc.text = "Add cool visual effects to your game!\nClick any effect on the left to add it.\nYou can stack up to 8 effects at once."
		wdesc.label_settings = _ls(11, WHITE)
		wdesc.add_theme_color_override("font_color", WHITE)
		wdesc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wdesc.autowrap_mode = TextServer.AUTOWRAP_WORD
		wvbox.add_child(wdesc)
		var sep = HSeparator.new()
		sep.add_theme_color_override("separator", Color(0.30, 0.30, 0.38))
		wvbox.add_child(sep)
		# Mini preview grid of all effects
		for lib in _shader_library:
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			wvbox.add_child(row)
			var ico = Label.new()
			ico.text = lib.get("icon", "🎨")
			ico.label_settings = _ls(16, WHITE)
			ico.add_theme_color_override("font_color", WHITE)
			ico.custom_minimum_size.x = 28
			row.add_child(ico)
			var info_vb = VBoxContainer.new()
			info_vb.add_theme_constant_override("separation", 0)
			info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(info_vb)
			var nm = Label.new()
			nm.text = lib["name"]
			nm.label_settings = _ls(11, WHITE)
			nm.add_theme_color_override("font_color", WHITE)
			info_vb.add_child(nm)
			var dd = Label.new()
			dd.text = lib.get("description", "")
			dd.label_settings = _ls(9, LABEL_CLR)
			dd.add_theme_color_override("font_color", LABEL_CLR)
			dd.autowrap_mode = TextServer.AUTOWRAP_WORD
			info_vb.add_child(dd)
		return

	var s = shaders[selected_shader]
	var sname = s.get("shader_name", "Unknown")
	var lib_entry = null
	for lib in _shader_library:
		if lib["name"] == sname:
			lib_entry = lib
			break

	# ── Effect Type selector ──
	var type_card = _card(CARD_BG)
	_detail_panel.add_child(type_card)
	var type_vbox = VBoxContainer.new()
	type_vbox.add_theme_constant_override("separation", 4)
	type_card.add_child(type_vbox)

	var type_hdr = Label.new()
	type_hdr.text = "🎨 Effect Type"
	type_hdr.label_settings = _ls(12, ACCENT)
	type_hdr.add_theme_color_override("font_color", ACCENT)
	type_vbox.add_child(type_hdr)

	var type_opt = OptionButton.new()
	type_opt.tooltip_text = "Choose which visual effect to use"
	for lib in _shader_library:
		type_opt.add_item(lib["icon"] + " " + lib["name"])
	# Select current
	for li in range(_shader_library.size()):
		if _shader_library[li]["name"] == sname:
			type_opt.select(li)
			break
	_style_option(type_opt)
	type_opt.item_selected.connect(func(idx):
		var new_name = _shader_library[idx]["name"]
		s["shader_name"] = new_name
		# Reset properties to new shader defaults
		s["properties"] = {}
		for u in _shader_library[idx]["uniforms"]:
			s["properties"][u["name"]] = u["default"]
		_rebuild_cards()
		_rebuild_detail()
		data_changed.emit()
	)
	type_vbox.add_child(type_opt)

	# Description
	if lib_entry:
		var desc_lbl = Label.new()
		desc_lbl.text = lib_entry.get("description", "")
		desc_lbl.label_settings = _ls(10, LABEL_CLR)
		desc_lbl.add_theme_color_override("font_color", LABEL_CLR)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		type_vbox.add_child(desc_lbl)

	# ── Enabled toggle ──
	var enable_hbox = HBoxContainer.new()
	enable_hbox.add_theme_constant_override("separation", 8)
	type_vbox.add_child(enable_hbox)
	var enable_lbl = Label.new()
	enable_lbl.text = "Enabled:"
	enable_lbl.label_settings = _ls(11, LABEL_CLR)
	enable_lbl.add_theme_color_override("font_color", LABEL_CLR)
	enable_hbox.add_child(enable_lbl)
	var enable_chk = CheckButton.new()
	enable_chk.button_pressed = s.get("enabled", true)
	enable_chk.tooltip_text = "Turn this effect on or off"
	enable_chk.toggled.connect(func(v):
		s["enabled"] = v
		_rebuild_cards()
		_update_preview()
		data_changed.emit()
	)
	enable_hbox.add_child(enable_chk)

	# ── Region selector ──
	var region_card = _card(CARD_BG)
	_detail_panel.add_child(region_card)
	var region_vbox = VBoxContainer.new()
	region_vbox.add_theme_constant_override("separation", 4)
	region_card.add_child(region_vbox)

	var region_hdr = Label.new()
	region_hdr.text = "📐 Screen Region"
	region_hdr.label_settings = _ls(12, ACCENT)
	region_hdr.add_theme_color_override("font_color", ACCENT)
	region_hdr.tooltip_text = "Choose where the effect appears on screen"
	region_vbox.add_child(region_hdr)

	var region_hint = Label.new()
	region_hint.text = "Where should this effect show on screen?"
	region_hint.label_settings = _ls(10, LABEL_CLR)
	region_hint.add_theme_color_override("font_color", LABEL_CLR)
	region_vbox.add_child(region_hint)

	var region_mode = s.get("region_mode", "full_screen")
	var full_btn = Button.new()
	full_btn.text = "🖥️ Full Screen"
	full_btn.tooltip_text = "The effect covers the entire game screen"
	full_btn.toggle_mode = true
	full_btn.button_pressed = (region_mode == "full_screen")
	full_btn.add_theme_font_size_override("font_size", 11)
	region_vbox.add_child(full_btn)

	var part_btn = Button.new()
	part_btn.text = "✂️ Part of Screen"
	part_btn.tooltip_text = "The effect only covers part of the game screen (you pick the rectangle)"
	part_btn.toggle_mode = true
	part_btn.button_pressed = (region_mode == "rectangle")
	part_btn.add_theme_font_size_override("font_size", 11)
	region_vbox.add_child(part_btn)

	var rect_box = VBoxContainer.new()
	rect_box.add_theme_constant_override("separation", 2)
	rect_box.visible = (region_mode == "rectangle")
	region_vbox.add_child(rect_box)

	full_btn.pressed.connect(func():
		s["region_mode"] = "full_screen"
		full_btn.button_pressed = true
		part_btn.button_pressed = false
		rect_box.visible = false
		_update_preview()
		data_changed.emit()
	)
	part_btn.pressed.connect(func():
		s["region_mode"] = "rectangle"
		full_btn.button_pressed = false
		part_btn.button_pressed = true
		rect_box.visible = true
		_update_preview()
		data_changed.emit()
	)

	# Rectangle inputs (x, y, w, h)
	var fields = [
		{"key": "region_x", "label": "X Position", "tooltip": "Left edge of the effect area (in pixels)", "max": 1920},
		{"key": "region_y", "label": "Y Position", "tooltip": "Top edge of the effect area (in pixels)", "max": 1080},
		{"key": "region_w", "label": "Width", "tooltip": "How wide the effect area is (in pixels)", "max": 1920},
		{"key": "region_h", "label": "Height", "tooltip": "How tall the effect area is (in pixels)", "max": 1080},
	]
	for f in fields:
		var rh = HBoxContainer.new()
		rh.add_theme_constant_override("separation", 4)
		rect_box.add_child(rh)
		var rl = Label.new()
		rl.text = f["label"] + ":"
		rl.label_settings = _ls(10, LABEL_CLR)
		rl.add_theme_color_override("font_color", LABEL_CLR)
		rl.custom_minimum_size.x = 75
		rl.tooltip_text = f["tooltip"]
		rh.add_child(rl)
		var spin = SpinBox.new()
		spin.min_value = 0
		spin.max_value = f["max"]
		spin.step = 1
		spin.value = s.get(f["key"], 0)
		spin.tooltip_text = f["tooltip"]
		spin.add_theme_font_size_override("font_size", 10)
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fkey = f["key"]
		spin.value_changed.connect(func(v): s[fkey] = int(v); _update_preview(); data_changed.emit())
		rh.add_child(spin)

	# ── Properties panel ──
	if lib_entry and lib_entry["uniforms"].size() > 0:
		var props_card = _card(CARD_BG)
		_detail_panel.add_child(props_card)
		var props_vbox = VBoxContainer.new()
		props_vbox.add_theme_constant_override("separation", 6)
		props_card.add_child(props_vbox)

		var props_hdr = Label.new()
		props_hdr.text = "⚙️ Properties"
		props_hdr.label_settings = _ls(12, ACCENT)
		props_hdr.add_theme_color_override("font_color", ACCENT)
		props_hdr.tooltip_text = "Adjust these sliders to change how the effect looks"
		props_vbox.add_child(props_hdr)

		_props_container = props_vbox

		for u in lib_entry["uniforms"]:
			_build_property_row(props_vbox, s, u)

	# ── Live Preview ──
	var preview_card = _card(CARD_BG)
	_detail_panel.add_child(preview_card)
	var preview_vbox = VBoxContainer.new()
	preview_vbox.add_theme_constant_override("separation", 4)
	preview_card.add_child(preview_vbox)

	var preview_hdr = Label.new()
	preview_hdr.text = "👁️ Live Preview"
	preview_hdr.label_settings = _ls(12, ACCENT)
	preview_hdr.add_theme_color_override("font_color", ACCENT)
	preview_hdr.tooltip_text = "This shows what the effect looks like in real-time!"
	preview_vbox.add_child(preview_hdr)

	# Use a layered container so region clipping is visible
	var preview_container = Control.new()
	preview_container.custom_minimum_size = Vector2(240, 180)
	preview_container.clip_contents = true
	preview_vbox.add_child(preview_container)

	# Base sample image (always full)
	var base_rect = TextureRect.new()
	base_rect.texture = _sample_texture
	base_rect.custom_minimum_size = Vector2(240, 180)
	base_rect.size = Vector2(240, 180)
	base_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_container.add_child(base_rect)

	# Shader overlay (positioned/sized to region)
	_preview_rect = TextureRect.new()
	_preview_rect.texture = _sample_texture
	_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_container.add_child(_preview_rect)

	# Region outline (shows where the rectangle is)
	var region_outline = ReferenceRect.new()
	region_outline.name = "RegionOutline"
	region_outline.editor_only = false
	region_outline.border_color = Color(1.0, 1.0, 0.3, 0.8)
	region_outline.border_width = 1.5
	region_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	region_outline.visible = false
	preview_container.add_child(region_outline)

	_update_preview()


# ═══════════════════════════════════════════════════════════════
# PROPERTY CONTROLS (auto-generated from shader uniforms)
# ═══════════════════════════════════════════════════════════════

func _build_property_row(parent: VBoxContainer, shader_data: Dictionary, uniform: Dictionary) -> void:
	var u_name = uniform["name"]
	var u_label = uniform.get("label", u_name)
	var u_type = uniform.get("type", "float")
	var u_default = uniform.get("default", 0.0)
	var u_min = uniform.get("min", 0.0)
	var u_max = uniform.get("max", 1.0)
	var u_step = uniform.get("step", 0.01)
	var u_tooltip = uniform.get("tooltip", "")

	var props = shader_data.get("properties", {})
	var current_val = props.get(u_name, u_default)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var lbl = Label.new()
	lbl.text = u_label + ":"
	lbl.label_settings = _ls(10, LABEL_CLR)
	lbl.add_theme_color_override("font_color", LABEL_CLR)
	lbl.custom_minimum_size.x = 100
	lbl.tooltip_text = u_tooltip
	row.add_child(lbl)

	if u_type == "float":
		var slider = HSlider.new()
		slider.min_value = u_min
		slider.max_value = u_max
		slider.step = u_step
		slider.value = current_val
		slider.tooltip_text = u_tooltip
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.x = 100
		row.add_child(slider)

		var val_lbl = Label.new()
		val_lbl.text = "%.2f" % current_val
		val_lbl.label_settings = _ls(10, WHITE)
		val_lbl.add_theme_color_override("font_color", WHITE)
		val_lbl.custom_minimum_size.x = 40
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_lbl)

		slider.value_changed.connect(func(v):
			props[u_name] = v
			shader_data["properties"] = props
			val_lbl.text = "%.2f" % v
			_update_preview()
			data_changed.emit()
		)

		# Reset button
		var reset_btn = Button.new()
		reset_btn.text = "↺"
		reset_btn.tooltip_text = "Reset to default (" + str(u_default) + ")"
		reset_btn.add_theme_font_size_override("font_size", 10)
		reset_btn.pressed.connect(func():
			slider.value = u_default
		)
		row.add_child(reset_btn)

	elif u_type == "int":
		var spin = SpinBox.new()
		spin.min_value = u_min
		spin.max_value = u_max
		spin.step = u_step
		spin.value = current_val
		spin.tooltip_text = u_tooltip
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(func(v):
			props[u_name] = int(v)
			shader_data["properties"] = props
			_update_preview()
			data_changed.emit()
		)
		row.add_child(spin)

	elif u_type == "bool":
		var chk = CheckButton.new()
		chk.button_pressed = bool(current_val)
		chk.tooltip_text = u_tooltip
		chk.toggled.connect(func(v):
			props[u_name] = v
			shader_data["properties"] = props
			_update_preview()
			data_changed.emit()
		)
		row.add_child(chk)


# ═══════════════════════════════════════════════════════════════
# LIVE PREVIEW
# ═══════════════════════════════════════════════════════════════

func _generate_sample_texture() -> void:
	# Generate a sample image (checkerboard + colored blocks)
	# to preview shader effects on
	var w := 240
	var h := 180
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)

	# Dark blue gradient background
	for y in range(h):
		for x in range(w):
			var t = float(y) / float(h)
			var c = Color(0.08 + t * 0.05, 0.08 + t * 0.02, 0.15 + t * 0.1)
			img.set_pixel(x, y, c)

	# Checkerboard ground (bottom third)
	var ground_y := h * 2 / 3
	for y in range(ground_y, h):
		for x in range(w):
			var cx = int(x / 16) % 2
			var cy = int(y / 16) % 2
			if (cx + cy) % 2 == 0:
				img.set_pixel(x, y, Color(0.3, 0.35, 0.25))
			else:
				img.set_pixel(x, y, Color(0.25, 0.30, 0.20))

	# Blue sky rectangle (top left)
	for y in range(20, 60):
		for x in range(20, 100):
			img.set_pixel(x, y, Color(0.3, 0.5, 0.9))

	# Red enemy rectangle
	for y in range(ground_y - 24, ground_y):
		for x in range(160, 184):
			img.set_pixel(x, y, Color(0.85, 0.25, 0.25))

	# Green player rectangle
	for y in range(ground_y - 28, ground_y):
		for x in range(60, 80):
			img.set_pixel(x, y, Color(0.3, 0.8, 0.4))

	# Yellow coin
	var coin_cx := 120
	var coin_cy := ground_y - 40
	for y in range(maxi(0, coin_cy - 8), mini(h, coin_cy + 8)):
		for x in range(maxi(0, coin_cx - 8), mini(w, coin_cx + 8)):
			if (x - coin_cx) * (x - coin_cx) + (y - coin_cy) * (y - coin_cy) <= 64:
				img.set_pixel(x, y, Color(1.0, 0.85, 0.2))

	# White stars (bright points for glow testing)
	var stars = [Vector2i(30, 15), Vector2i(80, 10), Vector2i(150, 20), Vector2i(200, 8), Vector2i(210, 35)]
	for star in stars:
		if star.x < w and star.y < h:
			img.set_pixel(star.x, star.y, Color.WHITE)
			if star.x + 1 < w:
				img.set_pixel(star.x + 1, star.y, Color(0.8, 0.8, 0.9))
			if star.y + 1 < h:
				img.set_pixel(star.x, star.y + 1, Color(0.8, 0.8, 0.9))

	_sample_texture = ImageTexture.create_from_image(img)


func _make_preview_code(code: String) -> String:
	# Convert screen-space shader to texture-space for preview
	var preview = code.replace(
		"uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;",
		""
	)
	preview = preview.replace("texture(screen_texture, SCREEN_UV)", "texture(TEXTURE, UV)")
	preview = preview.replace("texture(screen_texture,", "texture(TEXTURE,")
	preview = preview.replace("SCREEN_UV", "UV")
	preview = preview.replace("textureSize(screen_texture, 0)", "textureSize(TEXTURE, 0)")
	# Remove leftover screen_texture references
	preview = preview.replace("screen_texture", "TEXTURE")
	return preview


func _update_preview() -> void:
	if not is_instance_valid(_preview_rect):
		return
	if selected_shader < 0 or selected_shader >= shaders.size():
		_preview_rect.material = null
		_preview_rect.size = Vector2(240, 180)
		_preview_rect.position = Vector2.ZERO
		_hide_region_outline()
		return

	var s = shaders[selected_shader]
	if not s.get("enabled", true):
		_preview_rect.material = null
		_preview_rect.size = Vector2(240, 180)
		_preview_rect.position = Vector2.ZERO
		_hide_region_outline()
		return

	var sname = s.get("shader_name", "")
	var lib_entry = null
	for lib in _shader_library:
		if lib["name"] == sname:
			lib_entry = lib
			break
	if not lib_entry:
		_preview_rect.material = null
		_preview_rect.size = Vector2(240, 180)
		_preview_rect.position = Vector2.ZERO
		_hide_region_outline()
		return

	# Create shader and material for preview
	var shader = Shader.new()
	var preview_code = _make_preview_code(lib_entry["code"])
	shader.code = preview_code

	var mat = ShaderMaterial.new()
	mat.shader = shader

	# Set uniform values from properties
	var props = s.get("properties", {})
	for u in lib_entry["uniforms"]:
		var val = props.get(u["name"], u["default"])
		mat.set_shader_parameter(u["name"], val)

	_preview_rect.material = mat

	# ── Position/size the shader rect based on region mode ──
	var region_mode = s.get("region_mode", "full_screen")
	if region_mode == "full_screen":
		_preview_rect.position = Vector2.ZERO
		_preview_rect.size = Vector2(240, 180)
		_preview_rect.custom_minimum_size = Vector2(240, 180)
		_hide_region_outline()
	else:
		# Scale region from game coords to preview coords
		# Preview is 240×180, game screen is typically 640×480
		var game_w := 640.0
		var game_h := 480.0
		var preview_w := 240.0
		var preview_h := 180.0
		var sx = preview_w / game_w
		var sy = preview_h / game_h

		var rx = float(s.get("region_x", 0)) * sx
		var ry = float(s.get("region_y", 0)) * sy
		var rw = float(s.get("region_w", 640)) * sx
		var rh = float(s.get("region_h", 480)) * sy

		_preview_rect.position = Vector2(rx, ry)
		_preview_rect.size = Vector2(rw, rh)
		_preview_rect.custom_minimum_size = Vector2(rw, rh)
		_show_region_outline(rx, ry, rw, rh)


func _hide_region_outline() -> void:
	if not is_instance_valid(_preview_rect):
		return
	var parent = _preview_rect.get_parent()
	if parent:
		var outline = parent.get_node_or_null("RegionOutline")
		if outline:
			outline.visible = false


func _show_region_outline(x: float, y: float, w: float, h: float) -> void:
	if not is_instance_valid(_preview_rect):
		return
	var parent = _preview_rect.get_parent()
	if parent:
		var outline = parent.get_node_or_null("RegionOutline")
		if outline:
			outline.position = Vector2(x, y)
			outline.size = Vector2(w, h)
			outline.visible = true


# ═══════════════════════════════════════════════════════════════
# SERIALIZATION
# ═══════════════════════════════════════════════════════════════

func get_data() -> Array:
	return shaders.duplicate(true)


func set_data(data) -> void:
	if data is Array:
		shaders = data.duplicate(true) if data != null else []
	else:
		shaders = []
	selected_shader = 0 if shaders.size() > 0 else -1
	_rebuild_cards()
	_rebuild_detail()


# ═══════════════════════════════════════════════════════════════
# UI HELPERS (shared pattern with other AGCK editors)
# ═══════════════════════════════════════════════════════════════

func _ls(size: int, color: Color) -> LabelSettings:
	var ls = LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = 0
	ls.font_outline_color = Color.TRANSPARENT
	return ls


func _card(bg_color: Color) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(6)
	style.content_margin_left   = 8
	style.content_margin_right  = 8
	style.content_margin_top    = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return panel


func _spacer() -> Control:
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sp


## Linux X11 popup fix — DO NOT use transparent viewports for popups.
## Transparent ARGB visuals cause font rendering to break on X11 compositors
## (text becomes invisible or unreadable). Instead, use an opaque window with
## a dark Theme covering PopupMenu + Window + Panel type names, plus direct
## theme_override calls for highest priority.
## See POPUP_THEME_FIX.md for the full explanation.
func _apply_dark_popup(popup: PopupMenu) -> void:
	if not is_instance_valid(popup):
		return
	popup.transparent = false
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.15, 0.15, 0.19, 1.0)
	ps.set_corner_radius_all(0)
	ps.content_margin_left = 6; ps.content_margin_right = 6
	ps.content_margin_top = 4;  ps.content_margin_bottom = 4
	ps.border_width_bottom = 1; ps.border_width_top = 1
	ps.border_width_left = 1;   ps.border_width_right = 1
	ps.border_color = Color(0.30, 0.30, 0.35)
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(0.25, 0.35, 0.55)
	hs.set_corner_radius_all(3)
	hs.content_margin_left = 6; hs.content_margin_right = 6
	hs.content_margin_top = 2;  hs.content_margin_bottom = 2
	var t := Theme.new()
	for type_name in ["PopupMenu", "PopupPanel", "Panel", "Control", "Window"]:
		t.set_stylebox("panel", type_name, ps)
	t.set_stylebox("hover", "PopupMenu", hs)
	t.set_color("font_color", "PopupMenu", LABEL_CLR)
	t.set_color("font_hover_color", "PopupMenu", WHITE)
	t.set_color("font_disabled_color", "PopupMenu", DIM)
	t.set_color("font_separator_color", "PopupMenu", DIM)
	t.set_color("font_accelerator_color", "PopupMenu", DIM)
	t.set_color("font_outline_color", "PopupMenu", Color.TRANSPARENT)
	popup.theme = t
	popup.add_theme_stylebox_override("panel", ps)
	popup.add_theme_stylebox_override("hover", hs)
	popup.add_theme_color_override("font_color", LABEL_CLR)
	popup.add_theme_color_override("font_hover_color", WHITE)
	popup.add_theme_color_override("font_disabled_color", DIM)
	popup.add_theme_color_override("font_separator_color", DIM)
	popup.add_theme_color_override("font_accelerator_color", DIM)
	popup.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	for c in popup.get_children(true):
		if c is Control:
			c.add_theme_stylebox_override("panel", ps)
			c.queue_redraw()


func _style_option(opt: OptionButton) -> void:
	opt.add_theme_font_size_override("font_size", 11)
	opt.flat = true
	opt.add_theme_color_override("font_color", LABEL_CLR)
	opt.add_theme_color_override("font_hover_color", WHITE)
	opt.add_theme_color_override("font_pressed_color", WHITE)
	opt.add_theme_color_override("font_focus_color", LABEL_CLR)
	# Dark popup — OPAQUE window (transparent=true breaks Linux X11 compositors)
	# See POPUP_THEME_FIX.md for the full explanation.
	var popup := opt.get_popup()
	if popup:
		_apply_dark_popup(popup)
		if not popup.has_meta("_agck_popup_styled"):
			popup.set_meta("_agck_popup_styled", true)
			popup.about_to_popup.connect(func():
				_apply_dark_popup(popup)
				_apply_dark_popup.call_deferred(popup)
			)
			popup.visibility_changed.connect(func():
				if popup.visible:
					_apply_dark_popup(popup)
			)
