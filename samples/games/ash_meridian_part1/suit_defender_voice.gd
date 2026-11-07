extends Node

const VOICE_PATH := "res://assets/audio/sfx/alien_murmur.ogg"
# Same measured 20 Hz source envelope used by the Undercity holograms.
const ENVELOPE := "752121124667762123433003566765101578612444321000000000000000001333211224332100234331012234331015889730022434321023443200234343201233332003443001343200246887641000000003330233203577"
# Source offset, source duration, pitch: edited Narcean phrases, never subtitles.
const PHRASES := {
	"threat": [
		[[0.0, 0.65, 0.86], [2.4, 0.8, 0.82], [6.8, 0.65, 0.91]],
		[[4.5, 0.5, 0.9], [0.8, 0.8, 0.84], [7.6, 0.65, 0.8]]
	],
	"insult": [
		[[1.0, 0.5, 1.06], [3.4, 0.5, 0.92], [0.0, 0.4, 0.82]],
		[[6.0, 0.5, 1.12], [4.5, 0.6, 0.9]]
	],
	"shock": [
		[[3.4, 0.25, 1.4], [0.0, 0.4, 1.24], [7.5, 0.45, 1.1]],
		[[1.2, 0.3, 1.35], [6.0, 0.55, 1.18]]
	],
	"curse": [
		[[6.8, 0.4, 1.16], [3.4, 0.35, 1.24], [0.0, 0.6, 0.8]],
		[[0.8, 0.3, 1.3], [4.5, 0.45, 1.1], [7.5, 0.7, 0.86]]
	],
	"boast": [
		[[2.4, 0.7, 0.84], [6.0, 0.6, 0.9], [0.0, 0.7, 0.78]],
		[[4.5, 0.65, 0.85], [7.5, 0.7, 0.8]]
	]
}

var player: AudioStreamPlayer
var counts: Dictionary = {}
var segments: Array = []
var segment_index := -1
var segment_left := 0.0
var segment_duration := 0.0
var cooldown := 0.0
var emotion_left := 0.0
var emotion := "idle"
var last_intent := ""
var phrase_count := 0
var active_round := false
var shocked := false
var cursed := false

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.name = "NarceanDefenderVoice"
	player.stream = load(VOICE_PATH)
	player.bus = "SFX"
	add_child(player)
	if player.stream == null:
		push_error("Cannot load Narcean defender voice: " + VOICE_PATH)

func ring() -> Node:
	return get_parent().get_parent()

func reset_round() -> void:
	stop_voice()
	active_round = false
	shocked = false
	cursed = false
	cooldown = 0
	last_intent = ""
	emotion = "idle"
	emotion_left = 0

func stop_voice() -> void:
	player.stop()
	segments = []
	segment_index = -1
	segment_left = 0

func begin_round() -> void:
	active_round = true
	say("threat", true)

func acquired(player_score: int, stolen: bool) -> void:
	if not active_round:
		return
	if player_score >= 7 and not cursed:
		cursed = true
		say("curse", true)
	elif (player_score >= 4 or stolen) and not shocked:
		shocked = true
		say("shock", true)

func result(stage: String) -> void:
	active_round = false
	say("curse" if stage == "WIN" else "shock" if stage == "TIE" else "boast", true)

func say(intent: String, urgent: bool = false) -> bool:
	if not PHRASES.has(intent):
		push_error("Unknown Narcean defender intent: " + intent)
		return false
	if not urgent and (cooldown > 0 or not segments.is_empty()):
		return false
	stop_voice()
	var index: int = counts.get(intent, 0)
	counts[intent] = index + 1
	last_intent = intent
	emotion = intent
	emotion_left = 2.8
	cooldown = 4
	if not ring().get_parent().get("opt_orac_voice") or player.stream == null:
		return true
	segments = PHRASES[intent][index % PHRASES[intent].size()]
	phrase_count += 1
	start_segment(0)
	return true

func start_segment(index: int) -> void:
	if index >= segments.size():
		stop_voice()
		return
	segment_index = index
	var segment: Array = segments[index]
	player.pitch_scale = segment[2]
	segment_duration = float(segment[1]) / player.pitch_scale
	segment_left = segment_duration
	# Start audibly even when the board takes longer than one syllable to draw.
	player.volume_db = voice_volume()
	player.play(segment[0])

func voice_volume() -> float:
	var speech: Object = ring().get_parent().get("speech")
	return -12.0 if speech != null and speech.call("busy") else -3.0

func advance(delta: float, paused: bool) -> void:
	if not ring().get_parent().get("opt_orac_voice"):
		stop_voice()
	player.stream_paused = paused
	if paused:
		return
	cooldown = maxf(0, cooldown - delta)
	emotion_left = maxf(0, emotion_left - delta)
	if segments.is_empty():
		return
	segment_left -= delta
	if segment_left <= 0:
		start_segment(segment_index + 1)
		return
	var fade := clampf(minf(segment_duration - segment_left, segment_left) / 0.035, 0.003, 1)
	player.volume_db = voice_volume() + linear_to_db(fade)

func mouth_level() -> float:
	if not player.playing or player.stream_paused or segments.is_empty():
		return 0
	var position := player.get_playback_position()
	var index := clampi(int(position * 20), 0, ENVELOPE.length() - 1)
	return float(ENVELOPE.unicode_at(index) - 48) / 9 * 0.85
