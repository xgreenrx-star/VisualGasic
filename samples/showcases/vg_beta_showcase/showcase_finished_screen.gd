extends Control
## End-of-showcase card — centered copy, Lucid credit scroller, faint rippling banner.

const LUCID_URL := (
	"https://m.soundcloud.com/daquavious-b"
	+ "?ref=clipboard&p=a&c=1&si=6e8356bfcda04f2e8acb75596c73ff32"
	+ "&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing"
)
const BANNER_TEX := preload("res://assets/lucid/lucid_banner.jpg")
const RIPPLE_SHADER := preload("res://shaders/lucid_banner_ripple.gdshader")
const VIGNETTE_SHADER := preload("res://shaders/screen_vignette.gdshader")
const SCROLLER_TEXT := (
	"  ★  SPECIAL THANKS TO LUCID  ★  ORIGINAL MUSIC FOR THIS DEMO  ★  "
	+ "SUPPORT, GUIDANCE, AND ALL THE HELP  ★  prodby.lucid  ★  "
)
const TOP_BAND_H := 52.0
const BADGE_W := 278.0
const RIPPLE_CYCLE_SEC := 3.25
const RIPPLE_MIN := 0.34

var _t := 0.0
var _banner_mat: ShaderMaterial
var _scroller: Label
var _scroller_width := 0.0
var _scroller_clip: Control


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_build_layers()


func _build_layers() -> void:
	var base := ColorRect.new()
	base.set_anchors_preset(PRESET_FULL_RECT)
	base.mouse_filter = MOUSE_FILTER_IGNORE
	base.color = Color(0.015, 0.018, 0.03, 1.0)
	add_child(base)

	var banner := TextureRect.new()
	banner.set_anchors_preset(PRESET_FULL_RECT)
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	banner.texture = BANNER_TEX
	banner.mouse_filter = MOUSE_FILTER_IGNORE
	_banner_mat = ShaderMaterial.new()
	_banner_mat.shader = RIPPLE_SHADER
	_banner_mat.set_shader_parameter("banner_alpha", 0.18)
	_banner_mat.set_shader_parameter("ripple_strength", 0.0)
	banner.material = _banner_mat
	add_child(banner)

	var vignette := ColorRect.new()
	vignette.set_anchors_preset(PRESET_FULL_RECT)
	vignette.mouse_filter = MOUSE_FILTER_IGNORE
	vignette.color = Color(1.0, 1.0, 1.0, 1.0)
	var vignette_mat := ShaderMaterial.new()
	vignette_mat.shader = VIGNETTE_SHADER
	vignette_mat.set_shader_parameter("tint", Color(0.008, 0.012, 0.028, 1.0))
	vignette_mat.set_shader_parameter("inner", 0.36)
	vignette_mat.set_shader_parameter("outer", 0.96)
	vignette_mat.set_shader_parameter("strength", 0.92)
	vignette_mat.set_shader_parameter("aspect", 1280.0 / 720.0)
	vignette.material = vignette_mat
	add_child(vignette)

	_build_scroller()
	_build_center_card()


func _build_scroller() -> void:
	var band := ColorRect.new()
	band.set_anchors_preset(PRESET_TOP_WIDE)
	band.offset_bottom = TOP_BAND_H
	band.mouse_filter = MOUSE_FILTER_IGNORE
	band.color = Color(0.02, 0.04, 0.08, 0.82)
	add_child(band)

	var badge_back := ColorRect.new()
	badge_back.set_anchors_preset(PRESET_TOP_LEFT)
	badge_back.offset_right = BADGE_W
	badge_back.offset_bottom = TOP_BAND_H
	badge_back.mouse_filter = MOUSE_FILTER_IGNORE
	badge_back.color = Color(0.015, 0.025, 0.045, 0.96)
	add_child(badge_back)

	var badge := Label.new()
	badge.text = "SHOWCASE COMPLETE"
	badge.set_anchors_preset(PRESET_CENTER_LEFT)
	badge.offset_left = 16.0
	badge.add_theme_font_size_override("font_size", 20)
	badge.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	badge.mouse_filter = MOUSE_FILTER_IGNORE
	badge_back.add_child(badge)

	var divider := ColorRect.new()
	divider.set_anchors_preset(PRESET_TOP_LEFT)
	divider.offset_left = BADGE_W
	divider.offset_right = BADGE_W + 2.0
	divider.offset_bottom = TOP_BAND_H
	divider.mouse_filter = MOUSE_FILTER_IGNORE
	divider.color = Color(0.35, 0.98, 1.0, 0.38)
	add_child(divider)

	_scroller_clip = Control.new()
	_scroller_clip.set_anchors_preset(PRESET_TOP_WIDE)
	_scroller_clip.offset_left = BADGE_W + 6.0
	_scroller_clip.offset_bottom = TOP_BAND_H
	_scroller_clip.clip_contents = true
	_scroller_clip.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_scroller_clip)

	_scroller = Label.new()
	_scroller.text = SCROLLER_TEXT + SCROLLER_TEXT
	_scroller.add_theme_font_size_override("font_size", 22)
	_scroller.add_theme_color_override("font_color", Color(0.35, 0.98, 1.0, 0.95))
	_scroller.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scroller.position = Vector2(0.0, 12.0)
	_scroller.mouse_filter = MOUSE_FILTER_IGNORE
	_scroller_clip.add_child(_scroller)
	await get_tree().process_frame
	_scroller_width = _scroller.get_minimum_size().x * 0.5


func _build_center_card() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	center.offset_top = 40.0
	center.offset_bottom = -40.0
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)

	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 18)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(card)

	var title := Label.new()
	title.text = "VISUAL GASIC 5.4.0-BETA1"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.98, 0.92, 0.62))
	card.add_child(title)

	var end_line := Label.new()
	end_line.text = "END OF SHOWCASE"
	end_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_line.add_theme_font_size_override("font_size", 42)
	end_line.add_theme_color_override("font_color", Color(1.0, 0.98, 0.88))
	card.add_child(end_line)

	var prompt := Label.new()
	prompt.text = "Press P To Play Vector Storm"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 24)
	prompt.add_theme_color_override("font_color", Color(0.72, 0.88, 1.0))
	card.add_child(prompt)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	card.add_child(spacer)

	var lucid_head := Label.new()
	lucid_head.text = "DEMO SOUNDTRACK BY LUCID"
	lucid_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lucid_head.add_theme_font_size_override("font_size", 20)
	lucid_head.add_theme_color_override("font_color", Color(0.45, 0.98, 0.82))
	card.add_child(lucid_head)

	var lucid_body := Label.new()
	lucid_body.text = "Thank you for the music, support, and all your help on this release."
	lucid_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lucid_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lucid_body.custom_minimum_size = Vector2(720, 0)
	lucid_body.add_theme_font_size_override("font_size", 17)
	lucid_body.add_theme_color_override("font_color", Color(0.78, 0.86, 0.98))
	card.add_child(lucid_body)

	var link := RichTextLabel.new()
	link.bbcode_enabled = true
	link.fit_content = true
	link.scroll_active = false
	link.custom_minimum_size = Vector2(640, 36)
	link.add_theme_font_size_override("normal_font_size", 22)
	link.text = (
		"[center][color=#66ffcc][url=%s]prodby.lucid[/url][/color][/center]"
		% LUCID_URL
	)
	link.meta_clicked.connect(_on_link_clicked)
	card.add_child(link)


func _on_link_clicked(meta: Variant) -> void:
	var url := str(meta)
	if url.begins_with("http"):
		OS.shell_open(url)


func _process(delta: float) -> void:
	_t += delta
	if _scroller and _scroller_width > 1.0:
		var speed := 118.0
		var x := fmod(-_t * speed, _scroller_width)
		_scroller.position.x = x
		var pulse := 0.72 + 0.28 * sin(_t * 4.6)
		_scroller.modulate = Color(0.35 * pulse, 0.98 * pulse, 1.0 * pulse, 0.92)
	if _banner_mat:
		var phase := _t * TAU / RIPPLE_CYCLE_SEC
		var ripple := lerpf(RIPPLE_MIN, 1.0, 0.5 + 0.5 * sin(phase))
		_banner_mat.set_shader_parameter("ripple_time", _t)
		_banner_mat.set_shader_parameter("ripple_strength", ripple)
