extends SceneTree

const DEST := "res://assets/audio/departure/"
const RATE := 22050
var speech: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST)) != OK:
		push_error("Cannot create departure audio directory")
		quit(1)
		return
	if "--ambience-only" in OS.get_cmdline_user_args():
		quit(0 if _bake_effects() else 1)
		return
	var preview := Node3D.new()
	preview.set_script(load("res://level1_departure.vg"))
	root.add_child(preview)
	preview.call("EnsureInit")
	var captions: Array = preview.get("radio_lines").duplicate()
	for shot in range(3):
		preview.set("shot", shot)
		for second: float in [0.0, 7.1, 15.1] if shot == 2 else ([0.0, 4.1, 13.1] if shot == 1 else [0.0, 5.1, 10.1]):
			preview.set("shot_elapsed", second)
			captions.append(preview.call("caption"))
	speech = Node.new()
	speech.set_script(load("res://flight_speech.vg"))
	root.add_child(speech)
	speech.call("configure", true)
	if speech.get("backend") != "kokoro":
		push_error("Bake requires the installed local Kokoro voice service")
		quit(1)
		return
	var manifest: Array = []
	for i in range(captions.size()):
		var caption: String = captions[i]
		var speaker := "jason"
		if caption.begins_with("ORAC:"):
			speaker = "Orac"
		elif caption.begins_with("BUYER"):
			speaker = "bm_lewis"
		elif caption.begins_with("STATION"):
			speaker = "am_michael"
		var text := caption.substr(caption.find(":") + 1).strip_edges()
		var path := DEST + "voice_%03d.ogg" % i
		speech.set("voice", speaker)
		speech.call("say", text, 0)
		var deadline := Time.get_ticks_msec() + 60000
		var player: AudioStreamPlayer = speech.get("player")
		while not player.playing and Time.get_ticks_msec() < deadline:
			speech.call("tick", false)
			await process_frame
		if not player.playing:
			push_error("Speech bake failed: " + caption + " / " + str(speech.get("last_error")))
			quit(1)
			return
		var wav: AudioStreamWAV = player.stream
		if not _encode(wav, path):
			quit(1)
			return
		manifest.append({"caption": caption, "speaker": speaker, "audio": path, "seconds": wav.get_length()})
		speech.call("stop")
		print("BAKED ", i + 1, "/", captions.size(), " ", caption)
	if not _bake_effects():
		quit(1)
		return
	var file := FileAccess.open(DEST + "voices.json", FileAccess.WRITE)
	if file == null:
		push_error("Cannot write departure voice manifest")
		quit(1)
		return
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	speech.free()
	preview.free()
	print("DEPARTURE_AUDIO_BAKED=", manifest.size())
	quit(0)

func _bake_effects() -> bool:
	for kind: String in ["station", "engines", "static", "jump", "berth", "transition", "call", "close"]:
		if not _encode(_synthesize(kind), DEST + kind + ".ogg"):
			return false
	return true

func _encode(wav: AudioStreamWAV, path: String) -> bool:
	var temporary := ProjectSettings.globalize_path(path.trim_suffix(".ogg") + ".wav")
	if wav.save_to_wav(temporary) != OK:
		push_error("Cannot save baked WAV: " + temporary)
		return false
	var output: Array = []
	var status := OS.execute("ffmpeg", ["-hide_banner", "-loglevel", "error", "-y", "-i", temporary,
		"-c:a", "libvorbis", "-q:a", "5", ProjectSettings.globalize_path(path)], output, true)
	DirAccess.remove_absolute(temporary)
	if status != 0:
		push_error("Audio encode failed: " + str(output))
	return status == 0

func _synthesize(kind: String) -> AudioStreamWAV:
	var seconds := 48.0 if kind == "station" else (6.0 if kind in ["engines", "static"] else 1.5)
	var count := roundi(seconds * RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 15112026
	var smooth_noise := 0.0
	var chords := [[130.81, 164.81, 196.0, 246.94], [110.0, 164.81, 196.0, 246.94],
		[87.31, 130.81, 174.61, 220.0], [98.0, 146.83, 196.0, 246.94]]
	for i in range(count):
		var t := float(i) / RATE
		var value := 0.0
		var noise := rng.randf_range(-1.0, 1.0)
		smooth_noise = lerpf(smooth_noise, noise, 0.03)
		if kind == "station":
			var section := int(t / 12) % 4
			var mix_factor := smoothstep(10.0, 12.0, fmod(t, 12.0))
			for note in range(4):
				var frequency: float = chords[section][note]
				var next: float = chords[(section + 1) % 4][note]
				value += (sin(TAU * frequency * t) * (1.0 - mix_factor) + sin(TAU * next * t) * mix_factor) * 0.04
				value += sin(TAU * frequency * 1.002 * t) * (1.0 - mix_factor) * 0.012
			var notes := [523.25, 659.25, 783.99, 987.77, 783.99, 659.25, 587.33, 659.25]
			var beat := fmod(t, 1.5)
			value += sin(TAU * notes[int(t / 1.5) % 8] * t) * exp(-beat * 3.8) * 0.065
		elif kind == "engines":
			value = smooth_noise * 0.3 + sin(TAU * 55 * t) * 0.15 + sin(TAU * 83 * t) * 0.07
		elif kind == "static":
			value = noise * 0.12 + (noise * 0.4 if absf(noise) > 0.985 else 0.0)
		elif kind == "call":
			value = (sin(TAU * 660 * t) + sin(TAU * 880 * t)) * 0.12 if fmod(t, 0.5) < 0.2 else 0.0
		elif kind == "jump":
			value = smooth_noise * 0.5 + sin(TAU * (80 * t + 160 * t * t)) * 0.16
		else:
			var frequency := 440.0 if kind == "close" else (523.25 if kind == "berth" else 330.0)
			value = sin(TAU * frequency * t) * exp(-t * 6) * 0.3
		value *= minf(t * 20, 1) * minf((seconds - t) * 20, 1)
		bytes.encode_s16(i * 2, roundi(clampf(value, -0.95, 0.95) * 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	return wav
