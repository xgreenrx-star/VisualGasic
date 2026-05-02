extends SceneTree

func _initialize() -> void:
	print("=== GDSFX smoke test ===")
	var synth = load("res://addons/visual_gasic/plugins/gdsfx/gdsfx_synth.gd").new()
	print("Default param count: ", synth.params.size())
	# Generate default sound
	var buf: PackedFloat32Array = synth.generate_sound()
	print("Default buffer: %d samples (%.3fs)" % [buf.size(), buf.size() / 44100.0])
	if buf.size() == 0:
		push_error("Empty buffer for defaults")
		quit(1)
		return

	# Try every preset
	var ok := true
	for tpl in synth.TEMPLATES:
		var method: String = tpl[1]
		seed(42)
		synth.call(method)
		var b: PackedFloat32Array = synth.generate_sound()
		if b.size() == 0:
			push_error("Empty buffer for: " + method)
			ok = false
			continue
		var peak := 0.0
		for s in b:
			peak = max(peak, abs(s))
		print("  %-22s  %6d samples  peak=%.3f" % [method, b.size(), peak])

	# Try every wave type as a default sound
	for wname in synth.WAVE_NAMES:
		synth.reset_params(false)
		synth.set_param("waveType", synth.WAVE_NAMES[wname], false)
		var b: PackedFloat32Array = synth.generate_sound()
		print("  wave=%-10s  %6d samples" % [wname, b.size()])

	# WAV stream
	var stream: AudioStreamWAV = synth.to_audio_stream_wav()
	print("AudioStreamWAV: data=%d bytes, mix_rate=%d" % [stream.data.size(), stream.mix_rate])

	print("=== %s ===" % ("OK" if ok else "FAIL"))
	quit(0 if ok else 1)
