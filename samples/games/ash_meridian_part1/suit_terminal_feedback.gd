extends Node2D

var clock := 0.0
var flashes: Dictionary = {}
var key_rects: Dictionary = {}
var font := SystemFont.new()
var speech_count := -1
var orac_playing := false
var speech_glow := 0.0
var attack_seen := 0
var reaction := 0.0
var last_chirp := -10.0
var mode := ""
var previous_score := Vector2i(-1, -1)
var chatter_count := 0
var face_view: SubViewport
var defender: Node2D
var orac_view: SubViewport
var display_elapsed := 0.0
var previous_display_mode := ""
var defender_voice: Node

func setup_displays() -> void:
	defender_voice = load("res://suit_defender_voice.gd").new()
	defender_voice.name = "DefenderSpeech"
	add_child(defender_voice)
	orac_view = load("res://suit_orac_display.gd").new()
	add_child(orac_view)
	face_view = SubViewport.new()
	face_view.size = Vector2i(300, 330)
	face_view.transparent_bg = true
	face_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(face_view)
	defender = load("res://suit_detailed_face.gd").new()
	defender.name = "DetailedNarceanFace"
	face_view.add_child(defender)

func _ready() -> void:
	font.font_names = PackedStringArray(["DejaVu Sans Mono", "monospace"])
	setup_displays()
	var rows := ["1234567890-=", "QWERTYUIOP[]", "ASDFGHJKL;'#", "ZXCVBNM,./<>"]
	for row in range(rows.size()):
		for column in range(rows[row].length()):
			key_rects[rows[row].unicode_at(column)] = Rect2(289 + (row % 2) * 2 + column * 31, 415 + row * 17, 29, 17)
	for item in [[KEY_SPACE, Rect2(376, 484, 173, 16)], [KEY_ENTER, Rect2(593, 484, 74, 16)], [KEY_BACKSPACE, Rect2(552, 484, 38, 16)], [KEY_SHIFT, Rect2(328, 484, 45, 16)], [KEY_F1, Rect2(290, 484, 35, 16)], [KEY_LEFT, Rect2(367, 390, 23, 17)], [KEY_RIGHT, Rect2(392, 390, 23, 17)], [KEY_UP, Rect2(417, 390, 23, 17)], [KEY_DOWN, Rect2(442, 390, 23, 17)]]:
		key_rects[item[0]] = item[1]

func _input(event: InputEvent) -> void:
	if not get_parent().is_visible_in_tree() or not event is InputEventKey:
		return
	var code: int = event.keycode
	if event.pressed and not event.echo and code in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A]:
		var game := get_parent().get_parent()
		game.call("NoteCode", code)
		if game.get("dev_on"):
			get_parent().get("loader_entry").release_focus()
			game.queue_redraw()
			get_viewport().set_input_as_handled()
			return
	if code == KEY_QUOTEDBL:
		code = KEY_APOSTROPHE
	if key_rects.has(code) and event.pressed:
		flashes[code] = 0.16
	if event.shift_pressed:
		flashes[KEY_SHIFT] = 0.16

func _process(delta: float) -> void:
	var ring := get_parent()
	if not ring.is_visible_in_tree():
		defender_voice.call("advance", 0.0, true)
		return
	var voice_paused: bool = ring.get("audio_paused") or ring.get("help_open")
	if ring.get("loader_step") > 0:
		defender_voice.call("reset_round")
	else:
		defender_voice.call("advance", delta, voice_paused)
	clock += delta
	speech_glow = maxf(0, speech_glow - delta)
	reaction = maxf(0, reaction - delta)
	for code in flashes.keys():
		flashes[code] = maxf(0, flashes[code] - delta)
	var speech: Object = ring.get_parent().get("speech")
	if speech != null:
		var audible := str(speech.get("playing_speaker")).to_upper() == "ORAC"
		if speech.get("backend") == "native":
			audible = audible and DisplayServer.tts_is_speaking()
		elif not speech.get("capture_only"):
			audible = audible and speech.get("player").playing
		if audible and (not orac_playing or speech_count != speech.get("spoken_count")):
			chirp()
		orac_playing = audible
		speech_count = speech.get("spoken_count")
		if audible:
			speech_glow = 0.4
	var defending: int = ring.get("defense_step")
	if defending != attack_seen:
		attack_seen = defending
		reaction = 0.8
	var current_score := Vector2i(ring.call("score", 1), ring.call("score", -1))
	if current_score != previous_score:
		previous_score = current_score
		reaction = 0.8
	mode = "ORAC" if ring.get("loader_step") > 0 else "DEFENDER"
	display_elapsed += delta
	if mode != previous_display_mode or display_elapsed >= 0.05:
		previous_display_mode = mode
		display_elapsed = fmod(display_elapsed, 0.05)
		update_displays()
	queue_redraw()

func update_displays() -> void:
	var ring := get_parent()
	var reduced: bool = ring.get("reduced_motion")
	if mode == "ORAC":
		orac_view.call("animate", clock, speech_glow, reduced)
	else:
		defender.call("set_reduced_motion", reduced)
		var level: float = defender_voice.call("mouth_level")
		defender.call("set_mode", "talk" if level > 0 and not reduced else "idle")
		defender.call("set_voice_level", level if not reduced else 0.0)
		defender.call("set_expression", defender_voice.get("emotion") if defender_voice.get("emotion_left") > 0 else "idle")
		defender.call("set_time", clock)
		defender.queue_redraw()
		face_view.render_target_update_mode = SubViewport.UPDATE_ONCE

func chirp() -> void:
	if clock - last_chirp < 2:
		return
	last_chirp = clock
	chatter_count += 1
	get_parent().call("play_feedback", "drone_chirp", 1.35, -29.0)

func label_at(text: String, position: Vector2, colour: Color, size: int = 12) -> void:
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)

func _draw() -> void:
	for code in flashes:
		if flashes[code] <= 0 and not Input.is_key_pressed(code):
			continue
		var rect: Rect2 = key_rects[code]
		draw_rect(rect.grow(-1), Color(0.035, 0.065, 0.045, 0.9))
		draw_rect(Rect2(rect.position + Vector2(2, 4), rect.size - Vector2(4, 5)), Color(0.3, 0.36, 0.28))
		draw_line(rect.position + Vector2(3, 4), rect.position + Vector2(rect.size.x - 3, 4), Color(0.65, 0.72, 0.55), 1)
		var legend := OS.get_keycode_string(code)
		if code == KEY_BACKSPACE:
			legend = "DEL"
		label_at(legend, rect.position + Vector2(5, 13), Color(0.9, 0.93, 0.8), 8)
	var reduced: bool = get_parent().get("reduced_motion")
	var colour := Color(0.35, 0.8, 0.83)
	draw_rect(Rect2(721, 75, 218, 350), Color(0.015, 0.035, 0.045, 0.92))
	label_at("SUIT / RECEIVE ONLY", Vector2(733, 97), colour, 12)
	draw_line(Vector2(733, 108), Vector2(927, 108), colour * 0.4)
	if mode == "ORAC":
		draw_core(colour)
	else:
		draw_defender()

func draw_core(colour: Color) -> void:
	draw_texture_rect(orac_view.get_texture(), Rect2(722, 117, 216, 226), false)
	label_at("ORAC / LOGIC CORE", Vector2(744, 360), colour)
	label_at("VOICE ACTIVE" if speech_glow > 0 else "MONITORING REPLIES", Vector2(741, 382), colour * 0.8, 11)
	label_at("NO PROGRAMMER TX PATH", Vector2(735, 405), colour * 0.6, 10)

func draw_defender() -> void:
	var ring := get_parent()
	var colour := Color(0.5, 0.87, 0.95)
	draw_texture_rect(face_view.get_texture(), Rect2(730, 117, 200, 230), false)
	label_at("TARGET / SECURITY", Vector2(742, 360), colour)
	label_at(str(ring.get("stage")), Vector2(777, 382), colour, 12)
	label_at("P %02d    DEF %02d" % [ring.call("score", 1), ring.call("score", -1)], Vector2(756, 405), colour, 12)
