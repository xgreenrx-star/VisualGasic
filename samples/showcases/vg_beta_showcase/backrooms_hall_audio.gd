extends Node
## Procedural hallway ambience — 60 Hz hum + demo-index portal bleed (SoundGen-style sine stack).
## Skipped entirely when DisplayServer is headless (CI smoke).

const SAMPLE_RATE := 44100.0
const MAX_FRAMES := 2048

var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var synth_time := 0.0
var bleed_gain := 0.0
var bleed_freq := 110.0

const BLEED_FREQS := [130.0, 146.0, 98.0, 110.0, 120.0, 155.0, 164.0]


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	process_priority = -5
	player = AudioStreamPlayer.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = SAMPLE_RATE
	generator.buffer_length = 0.12
	player.stream = generator
	player.volume_db = -9.0
	add_child(player)
	player.play()
	playback = player.get_stream_playback() as AudioStreamGeneratorPlayback


func set_portal_bleed(amount: float, demo_index: int) -> void:
	bleed_gain = clampf(amount, 0.0, 1.0) * 0.24
	bleed_freq = BLEED_FREQS[demo_index % BLEED_FREQS.size()]


func _process(_delta: float) -> void:
	if playback == null:
		return
	var frames_to_fill := mini(playback.get_frames_available(), MAX_FRAMES)
	for _i in frames_to_fill:
		var sample := _next_sample()
		playback.push_frame(Vector2(sample, sample))
		synth_time += 1.0 / SAMPLE_RATE


func _next_sample() -> float:
	var hum60 := sin(synth_time * TAU * 60.0) * 0.034
	var hum120 := sin(synth_time * TAU * 120.0) * 0.017
	var noise := (randf() * 2.0 - 1.0) * 0.011
	var buzz := sin(synth_time * TAU * 7200.0) * 0.0035 * (0.82 + randf() * 0.36)
	var bleed := 0.0
	if bleed_gain > 0.001:
		bleed = sin(synth_time * TAU * bleed_freq) * bleed_gain
		bleed += sin(synth_time * TAU * bleed_freq * 1.997) * bleed_gain * 0.38
		bleed += sin(synth_time * TAU * bleed_freq * 0.5) * bleed_gain * 0.18
	return clampf(hum60 + hum120 + noise + buzz + bleed, -1.0, 1.0)
