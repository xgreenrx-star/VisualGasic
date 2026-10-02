extends Node
## Procedural footstep beeps for Vector Crypt.
## Main.vg calls Step(0) / Step(1) for left/right while walking.
## No audio files — we synthesize short WAV thumps in memory.

var _player: AudioStreamPlayer
var _streams: Array = []

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = -10.0
	add_child(_player)
	# Two slightly different pitches so left/right feel distinct.
	_streams.append(_thump(90.0, 0.07))
	_streams.append(_thump(74.0, 0.065))

func Step(side: int) -> void:
	if _streams.is_empty():
		return
	var i := 0
	if side != 0:
		i = 1
	_player.stream = _streams[i]
	_player.play()

## Build a tiny mono WAV: decaying sine at `freq` for `dur` seconds.
func _thump(freq: float, dur: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var k := 0
	while k < n:
		var t := float(k) / float(rate)
		var env := 1.0 - (t / dur)
		env = env * env
		var s := sin(TAU * freq * t) * env
		s += sin(TAU * freq * 2.05 * t) * env * 0.35
		var sample := int(clampf(s, -1.0, 1.0) * 14000.0)
		data[k * 2] = sample & 255
		data[k * 2 + 1] = (sample >> 8) & 255
		k += 1
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
