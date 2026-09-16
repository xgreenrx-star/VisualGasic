extends Node
## Sequential Lucid MP3 playlist — per-scene lists via start_playlist().

const MUSIC_DIR := "res://music/lucid"
const VOLUME_DB := -4.0
const BUS_NAME := "LucidMusic"

const TRACK_141427 := "20260829_141427.mp3"
const TRACK_141450_1 := "20260829_141450 (1).mp3"
const TRACK_141450_2 := "20260829_141450 (2).mp3"
const TRACK_141450_3 := "20260829_141450 (3).mp3"
const TRACK_141450_4 := "20260829_141450 (4).mp3"
const TRACK_141450_5 := "20260829_141450 (5).mp3"
const TRACK_141450_6 := "20260829_141450 (6).mp3"

# Default / About — weakest opener (141427) deferred to the end.
const PLAYLIST_DEFAULT: PackedStringArray = [
	TRACK_141450_1,
	TRACK_141450_2,
	TRACK_141450_3,
	TRACK_141450_4,
	TRACK_141450_5,
	TRACK_141450_6,
	TRACK_141427,
]

# Neon Runner (dash) — (6) first, then base 141450 track if the segment continues.
const PLAYLIST_DASH: PackedStringArray = [
	TRACK_141450_6,
	TRACK_141450_1,
]

# End card — start on 141450 (1), keep cycling for a longer finish hold.
const PLAYLIST_END: PackedStringArray = [
	TRACK_141450_1,
	TRACK_141450_2,
	TRACK_141450_3,
	TRACK_141450_4,
	TRACK_141450_5,
	TRACK_141450_6,
	TRACK_141427,
]

var bus_index := -1

var _player: AudioStreamPlayer
var _tracks: PackedStringArray = PackedStringArray()
var _track_idx := 0
var _active := false
var _loop_playlist := true


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_ensure_player()


func start() -> void:
	start_default()


func start_default() -> void:
	start_playlist(PLAYLIST_DEFAULT, true)


func start_playlist(file_names: PackedStringArray, loop: bool = true) -> void:
	if DisplayServer.get_name() == "headless":
		return
	_ensure_player()
	if _player == null:
		return
	_tracks = _resolve_playlist(file_names)
	if _tracks.is_empty():
		push_warning("LucidMusicPlayer: empty playlist")
		return
	_loop_playlist = loop
	_track_idx = 0
	_active = true
	_play_track(0)


func stop() -> void:
	_active = false
	if _player:
		_player.stop()


func is_active() -> bool:
	return _active


func is_playing() -> bool:
	return _active and _player != null and _player.playing


func _ensure_player() -> void:
	if _player != null:
		return
	if _tracks.is_empty():
		_tracks = _resolve_playlist(PLAYLIST_DEFAULT)
	if _tracks.is_empty():
		push_warning("LucidMusicPlayer: no tracks in %s" % MUSIC_DIR)
		return
	_player = AudioStreamPlayer.new()
	_player.name = "LucidMusic"
	_player.volume_db = VOLUME_DB
	_player.finished.connect(_on_track_finished)
	bus_index = _ensure_bus()
	_player.bus = BUS_NAME
	add_child(_player)


func _resolve_playlist(file_names: PackedStringArray) -> PackedStringArray:
	var tracks: PackedStringArray = PackedStringArray()
	for file_name in file_names:
		var path := MUSIC_DIR.path_join(file_name)
		if FileAccess.file_exists(path):
			tracks.append(path)
		else:
			push_warning("LucidMusicPlayer: missing playlist track %s" % path)
	return tracks


func _ensure_bus() -> int:
	for i in AudioServer.bus_count:
		if AudioServer.get_bus_name(i) == BUS_NAME:
			return i
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, BUS_NAME)
	var analyzer := AudioEffectSpectrumAnalyzer.new()
	analyzer.buffer_length = 0.08
	analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_512
	AudioServer.add_bus_effect(idx, analyzer)
	return idx


func _play_track(idx: int) -> void:
	if _player == null or _tracks.is_empty():
		return
	_track_idx = posmod(idx, _tracks.size())
	var stream: AudioStream = load(_tracks[_track_idx])
	if stream == null:
		push_warning("LucidMusicPlayer: failed to load %s" % _tracks[_track_idx])
		return
	_player.stream = stream
	_player.play()


func _on_track_finished() -> void:
	if not _active:
		return
	var next := _track_idx + 1
	if next >= _tracks.size():
		if _loop_playlist:
			_play_track(0)
		return
	_play_track(next)
