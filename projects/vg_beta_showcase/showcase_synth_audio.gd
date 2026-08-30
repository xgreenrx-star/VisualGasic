extends Node
## Runtime synth bass — zero audio files. Sawtooth arpeggio + kick synced to showcase BPM.

const SAMPLE_RATE := 44100.0
const BPM := 126.0
const NOTES := [110.0, 130.81, 146.83, 164.81, 146.83, 130.81]
# ~93 ms of audio max per frame — enough to recover from a hitch without blocking forever.
const MAX_FRAMES_PER_TICK := 4096

var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var synth_time: float = 0.0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	# Fill the generator buffer before the heavy 3D scene work each frame.
	process_priority = -10
	player = AudioStreamPlayer.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = SAMPLE_RATE
	generator.buffer_length = 0.15
	player.stream = generator
	player.volume_db = -10.0
	add_child(player)
	player.play()
	playback = player.get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_delta: float) -> void:
	if playback == null:
		return
	var frames_to_fill := mini(playback.get_frames_available(), MAX_FRAMES_PER_TICK)
	for _i in frames_to_fill:
		var sample := _next_sample()
		playback.push_frame(Vector2(sample, sample))
		synth_time += 1.0 / SAMPLE_RATE


func _next_sample() -> float:
	var beat_dur: float = 60.0 / BPM
	var beat_phase: float = fmod(synth_time, beat_dur) / beat_dur
	var sixteenth: int = int(floor(synth_time / (beat_dur * 0.25))) % NOTES.size()
	var freq: float = NOTES[sixteenth]

	var saw := fmod(synth_time * freq, 1.0) * 2.0 - 1.0
	var bass := saw * 0.14

	var pad_freq := 55.0
	var pad_raw := fmod(synth_time * pad_freq, 1.0)
	var pad := -1.0 if pad_raw >= 0.5 else 1.0
	bass += pad * 0.025

	var kick := 0.0
	if beat_phase < 0.12:
		var k := beat_phase / 0.12
		kick = sin(k * PI) * sin(k * PI * 8.0) * 0.35 * (1.0 - k)

	var hat := 0.0
	var hat_phase := fmod(synth_time, beat_dur * 0.5) / (beat_dur * 0.5)
	if hat_phase < 0.04:
		hat = (randf() * 2.0 - 1.0) * 0.04 * (1.0 - hat_phase / 0.04)

	return clampf(bass + kick + hat, -1.0, 1.0)
