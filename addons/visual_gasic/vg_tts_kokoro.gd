@tool
extends RefCounted
## Shared Kokoro-82M / Sherpa-ONNX lookup for Narcea and games.
##
## Runtime and the English voice pack live outside the git tree:
##   Linux:  ~/.local/share/visual_gasic/tts
##   macOS:  ~/Library/Application Support/visual_gasic/tts
##   Windows: %LOCALAPPDATA%/VisualGasic/tts
##
## Install with scripts/install_kokoro.sh or scripts/install_kokoro.ps1.

const MODEL_DIR_NAME := "kokoro-en-v0_19"
const WRAPPER_UNIX := "vg-tts"
const WRAPPER_WIN := "vg-tts.cmd"

const SPEAKER_IDS := {
	"af": 0,
	"af_bella": 1,
	"af_nicole": 2,
	"af_sarah": 3,
	"af_sky": 4,
	"am_adam": 5,
	"am_michael": 6,
	"bf_emma": 7,
	"bf_isabella": 8,
	"bm_george": 9,
	"bm_lewis": 10,
}

const PERSONA_SPEAKERS := {
	"default": "af_bella",
	"bob": "am_michael",
	"skippy": "bm_lewis",
	"orac": "bm_george",
	"hal": "am_adam",
	"narcea": "af_nicole",
}


static func cache_dir() -> String:
	if OS.has_feature("windows"):
		var local := OS.get_environment("LOCALAPPDATA")
		if local.is_empty():
			local = OS.get_environment("USERPROFILE").path_join("AppData/Local")
		return local.path_join("VisualGasic/tts")
	var home := OS.get_environment("HOME")
	if OS.get_name() == "macOS":
		return home.path_join("Library/Application Support/visual_gasic/tts")
	return home.path_join(".local/share/visual_gasic/tts")


static func wrapper_path() -> String:
	var root := cache_dir()
	if OS.has_feature("windows"):
		return root.path_join(WRAPPER_WIN)
	return root.path_join(WRAPPER_UNIX)


static func model_dir() -> String:
	return cache_dir().path_join("models").path_join(MODEL_DIR_NAME)


static func is_ready() -> bool:
	return FileAccess.file_exists(wrapper_path()) and FileAccess.file_exists(model_onnx())


static func model_onnx() -> String:
	return model_dir().path_join("model.onnx")


static func model_voices() -> String:
	return model_dir().path_join("voices.bin")


static func model_tokens() -> String:
	return model_dir().path_join("tokens.txt")


static func model_data_dir() -> String:
	return model_dir().path_join("espeak-ng-data")


static func speaker_id(name: String) -> int:
	var key := name.strip_edges().to_lower()
	if SPEAKER_IDS.has(key):
		return int(SPEAKER_IDS[key])
	if PERSONA_SPEAKERS.has(key):
		return int(SPEAKER_IDS[PERSONA_SPEAKERS[key]])
	match key:
		"jason":
			return int(SPEAKER_IDS["am_adam"])
		"rob":
			return int(SPEAKER_IDS["am_michael"])
		"orac":
			return int(SPEAKER_IDS["bm_george"])
	return int(SPEAKER_IDS["bm_george"])


static func build_args(text: String, wav_path: String, speaker: String, speed: float) -> PackedStringArray:
	var sid := speaker_id(speaker)
	var rate := clampf(speed, 0.5, 2.0)
	return PackedStringArray([
		"--kokoro-model=" + model_onnx(),
		"--kokoro-voices=" + model_voices(),
		"--kokoro-tokens=" + model_tokens(),
		"--kokoro-data-dir=" + model_data_dir(),
		"--num-threads=2",
		"--sid=" + str(sid),
		"--speed=" + str(rate),
		"--output-filename=" + wav_path,
		text,
	])


static func daemon_wrapper() -> String:
	if OS.has_feature("windows"):
		return cache_dir().path_join("vg-tts-daemon.cmd")
	return cache_dir().path_join("vg-tts-daemon")


static func queue_dir() -> String:
	return cache_dir().path_join("queue")


static func daemon_available() -> bool:
	return FileAccess.file_exists(daemon_wrapper()) and is_ready()


static func daemon_pid_path() -> String:
	return queue_dir().path_join("pid")


static func daemon_ready_path() -> String:
	return queue_dir().path_join("ready")


static func daemon_is_running() -> bool:
	var path := daemon_pid_path()
	if not FileAccess.file_exists(path):
		return false
	var pid := int(FileAccess.get_file_as_string(path).strip_edges())
	return pid > 0 and OS.is_process_running(pid)


static func ensure_daemon() -> bool:
	if not daemon_available():
		return false
	DirAccess.make_dir_recursive_absolute(queue_dir())
	if daemon_is_running():
		return true
	var args := PackedStringArray([
		model_onnx(),
		model_voices(),
		model_tokens(),
		model_data_dir(),
		queue_dir(),
	])
	var pid := OS.create_process(daemon_wrapper(), args, false)
	return pid > 0


static func submit_job(text: String, wav_path: String, speaker: String, speed: float, silence: float) -> String:
	if text.strip_edges().is_empty() or wav_path.is_empty():
		return ""
	if not ensure_daemon():
		return ""
	DirAccess.make_dir_recursive_absolute(queue_dir())
	var stem := queue_dir().path_join("j%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	var body := "sid=%d\nspeed=%s\nsilence=%s\nout=%s\ntext=%s\n" % [
		speaker_id(speaker),
		str(clampf(speed, 0.5, 2.0)),
		str(clampf(silence, 0.02, 1.0)),
		wav_path,
		text.replace("\n", " ").strip_edges(),
	]
	var tmp := stem + ".tmp"
	var req := stem + ".req"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(body)
	file.close()
	var err := DirAccess.rename_absolute(tmp, req)
	if err != OK:
		DirAccess.remove_absolute(tmp)
		file = FileAccess.open(req, FileAccess.WRITE)
		if file == null:
			return ""
		file.store_string(body)
		file.close()
	return stem


static func job_status(stem: String) -> int:
	if stem.is_empty():
		return -1
	if FileAccess.file_exists(stem + ".ok"):
		DirAccess.remove_absolute(stem + ".ok")
		DirAccess.remove_absolute(stem + ".req")
		return 1
	if FileAccess.file_exists(stem + ".err"):
		DirAccess.remove_absolute(stem + ".err")
		DirAccess.remove_absolute(stem + ".req")
		return -1
	return 0


static func cancel_job(stem: String) -> void:
	if stem.is_empty():
		return
	DirAccess.remove_absolute(stem + ".req")
	DirAccess.remove_absolute(stem + ".tmp")
	DirAccess.remove_absolute(stem + ".ok")
	DirAccess.remove_absolute(stem + ".err")
