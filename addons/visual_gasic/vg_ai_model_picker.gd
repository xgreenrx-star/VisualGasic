@tool
extends AcceptDialog
## First-run model picker & downloader for the AI Help panel.
##
## Shows a curated list of Ollama models with hardware-aware recommendations
## (based on system RAM and CPU core count). Downloads the chosen model via
## Ollama's /api/pull endpoint with live progress.

# ---------------------------------------------------------------------------
# Curated model catalog — sorted from smallest to largest.
# Sizes are approximate on-disk and approximate peak RAM usage.
# ---------------------------------------------------------------------------
const MODEL_CATALOG := [
	{
		"id": "qwen2.5-coder:1.5b",
		"label": "Qwen 2.5 Coder — 1.5B",
		"desc": "Smallest & fastest. Good for quick syntax lookups, less thorough.",
		"disk_gb": 1.0,
		"ram_gb": 2.5,
		"speed": "⚡⚡⚡ Fast",
	},
	{
		"id": "qwen2.5-coder:3b",
		"label": "Qwen 2.5 Coder — 3B",
		"desc": "Balanced. Handles most coding questions reasonably.",
		"disk_gb": 2.0,
		"ram_gb": 4.0,
		"speed": "⚡⚡ Moderate",
	},
	{
		"id": "qwen2.5-coder:7b",
		"label": "Qwen 2.5 Coder — 7B (default)",
		"desc": "Recommended. Best quality for code assistance.",
		"disk_gb": 4.7,
		"ram_gb": 8.0,
		"speed": "⚡ Slower on CPU",
	},
	{
		"id": "qwen2.5-coder:14b",
		"label": "Qwen 2.5 Coder — 14B",
		"desc": "High-quality reasoning. Needs a lot of RAM or a GPU.",
		"disk_gb": 9.0,
		"ram_gb": 16.0,
		"speed": "🐢 Slow on CPU",
	},
	{
		"id": "llama3.2:3b",
		"label": "Llama 3.2 — 3B",
		"desc": "General-purpose. Good for explanations and doc writing.",
		"disk_gb": 2.0,
		"ram_gb": 4.0,
		"speed": "⚡⚡ Moderate",
	},
	{
		"id": "llama3.2:1b",
		"label": "Llama 3.2 — 1B",
		"desc": "Tiny general-purpose. Very fast but limited reasoning.",
		"disk_gb": 1.3,
		"ram_gb": 2.0,
		"speed": "⚡⚡⚡ Fast",
	},
]

signal model_installed(model_id: String)

var _list: ItemList
var _info_label: RichTextLabel
var _install_btn: Button
var _close_btn: Button
var _progress: ProgressBar
var _progress_label: Label
var _pull_http: HTTPClient
var _pull_poll: Timer
var _pull_buf := ""
var _pulling_model := ""
var _installed_models: Array = []  # Array of model name strings
var _recommended_id := ""

func _init() -> void:
	title = "AI Models"
	min_size = Vector2(640, 480)
	_build_ui()
	_populate_list()

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var header := Label.new()
	header.text = "Choose an AI model to download. Recommendations are based on your hardware."
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(header)

	var hw_label := Label.new()
	hw_label.text = _describe_hardware()
	hw_label.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	root.add_child(hw_label)

	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 280
	root.add_child(split)

	_list = ItemList.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size = Vector2(260, 0)
	_list.item_selected.connect(_on_item_selected)
	split.add_child(_list)

	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.fit_content = false
	_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_label.custom_minimum_size = Vector2(320, 0)
	_info_label.text = "[color=gray]Select a model to see details.[/color]"
	split.add_child(_info_label)

	_progress_label = Label.new()
	_progress_label.text = ""
	root.add_child(_progress_label)

	_progress = ProgressBar.new()
	_progress.visible = false
	_progress.min_value = 0
	_progress.max_value = 100
	root.add_child(_progress)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 8)
	root.add_child(btn_row)

	_install_btn = Button.new()
	_install_btn.text = "📥 Download Selected"
	_install_btn.disabled = true
	_install_btn.pressed.connect(_on_install_pressed)
	btn_row.add_child(_install_btn)

	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.pressed.connect(func(): hide())
	btn_row.add_child(_close_btn)

	# Hide the built-in "OK" button — we have our own Close
	get_ok_button().visible = false

## Called by the AI Help panel to update which models are already installed.
func set_installed_models(names: Array) -> void:
	_installed_models = names
	_populate_list()

func _populate_list() -> void:
	if _list == null:
		return
	_list.clear()
	var ram_gb := _get_system_ram_gb()
	var best_idx := -1
	var best_ram := 0.0
	for i in MODEL_CATALOG.size():
		var m: Dictionary = MODEL_CATALOG[i]
		var installed := _is_installed(m.id)
		var label_text: String = m.label
		if installed:
			label_text = "✓ " + label_text + "  [installed]"
		# Recommend the largest model that fits comfortably in RAM (leaving 4GB headroom)
		if (m.ram_gb as float) <= ram_gb - 4.0 and (m.ram_gb as float) > best_ram:
			best_ram = m.ram_gb
			best_idx = i
		_list.add_item(label_text)
	if best_idx >= 0:
		_recommended_id = MODEL_CATALOG[best_idx].id
		_list.set_item_custom_bg_color(best_idx, Color(0.2, 0.4, 0.2, 0.6))
		_list.set_item_tooltip(best_idx, "Recommended for your hardware")

func _is_installed(model_id: String) -> bool:
	for name in _installed_models:
		# Ollama names are usually exact, but also match by base (e.g. "qwen2.5-coder")
		if String(name) == model_id:
			return true
	return false

func _on_item_selected(idx: int) -> void:
	if idx < 0 or idx >= MODEL_CATALOG.size():
		return
	var m: Dictionary = MODEL_CATALOG[idx]
	var installed := _is_installed(m.id)
	var rec := " [color=#88ff88](recommended for you)[/color]" if m.id == _recommended_id else ""
	var txt := "[b]%s[/b]%s\n\n" % [m.label, rec]
	txt += "%s\n\n" % m.desc
	txt += "[b]Download size:[/b] ~%.1f GB\n" % m.disk_gb
	txt += "[b]RAM needed:[/b] ~%.1f GB\n" % m.ram_gb
	txt += "[b]Speed:[/b] %s\n" % m.speed
	txt += "[b]Model ID:[/b] [color=cyan]%s[/color]\n\n" % m.id
	if installed:
		txt += "[color=#88ff88]✓ Already installed.[/color] Select from the model dropdown to use it."
		_install_btn.text = "✓ Installed"
		_install_btn.disabled = true
	else:
		_install_btn.text = "📥 Download %s" % m.label
		_install_btn.disabled = _pulling_model != ""
	_info_label.text = txt

func _on_install_pressed() -> void:
	var idx := _list.get_selected_items()
	if idx.is_empty():
		return
	var m: Dictionary = MODEL_CATALOG[idx[0]]
	_start_pull(m.id)

# ---------------------------------------------------------------------------
# Pull (download) via Ollama's /api/pull — streams NDJSON progress
# ---------------------------------------------------------------------------
func _start_pull(model_id: String) -> void:
	_pulling_model = model_id
	_install_btn.disabled = true
	_close_btn.disabled = true
	_progress.visible = true
	_progress.value = 0
	_progress_label.text = "Starting download of %s..." % model_id
	_pull_buf = ""

	_pull_http = HTTPClient.new()
	var err := _pull_http.connect_to_host("127.0.0.1", 11434)
	if err != OK:
		_pull_failed("Could not connect to Ollama: " + error_string(err))
		return

	if _pull_poll == null:
		_pull_poll = Timer.new()
		_pull_poll.wait_time = 0.1
		_pull_poll.autostart = false
		_pull_poll.timeout.connect(_on_pull_poll)
		add_child(_pull_poll)
	_pull_phase = 1
	_pull_poll.start()

var _pull_phase := 0

func _on_pull_poll() -> void:
	if _pull_http == null:
		return
	_pull_http.poll()
	var status := _pull_http.get_status()

	if _pull_phase == 1:  # Connecting
		if status == HTTPClient.STATUS_CONNECTED:
			var body := JSON.stringify({"name": _pulling_model, "stream": true})
			var err := _pull_http.request(HTTPClient.METHOD_POST, "/api/pull",
				PackedStringArray(["Content-Type: application/json"]), body)
			if err != OK:
				_pull_failed("Failed to start download: " + error_string(err))
				return
			_pull_phase = 2
		elif status != HTTPClient.STATUS_CONNECTING and status != HTTPClient.STATUS_RESOLVING:
			_pull_failed("Connection failed (status=%d)" % status)
	elif _pull_phase == 2:  # Waiting for response
		if _pull_http.has_response():
			var code := _pull_http.get_response_code()
			if code != 200:
				_pull_failed("Ollama returned HTTP %d" % code)
				return
			_pull_phase = 3
		elif status != HTTPClient.STATUS_REQUESTING and status != HTTPClient.STATUS_CONNECTED:
			_pull_failed("Lost connection while waiting for response")
	elif _pull_phase == 3:  # Reading streaming JSON
		if status == HTTPClient.STATUS_BODY:
			var chunk := _pull_http.read_response_body_chunk()
			if chunk.size() > 0:
				_pull_buf += chunk.get_string_from_utf8()
				while _pull_buf.find("\n") >= 0:
					var nl := _pull_buf.find("\n")
					var line := _pull_buf.left(nl).strip_edges()
					_pull_buf = _pull_buf.substr(nl + 1)
					if line.is_empty() or line[0] != "{":
						continue
					_process_pull_line(line)
		elif status == HTTPClient.STATUS_DISCONNECTED or status == HTTPClient.STATUS_CONNECTION_ERROR:
			_pull_succeeded()

func _process_pull_line(line: String) -> void:
	var json = JSON.parse_string(line)
	if json == null or typeof(json) != TYPE_DICTIONARY:
		return
	if json.has("error"):
		_pull_failed(String(json["error"]))
		return
	var status_text: String = json.get("status", "")
	var total: float = float(json.get("total", 0))
	var completed: float = float(json.get("completed", 0))
	if total > 0 and completed >= 0:
		var pct := (completed / total) * 100.0
		_progress.value = pct
		var mb_done := completed / 1048576.0
		var mb_total := total / 1048576.0
		_progress_label.text = "%s — %.0f / %.0f MB (%.0f%%)" % [status_text, mb_done, mb_total, pct]
	elif not status_text.is_empty():
		_progress_label.text = status_text
	if status_text == "success":
		_pull_succeeded()

func _pull_succeeded() -> void:
	if _pull_poll:
		_pull_poll.stop()
	if _pull_http:
		_pull_http.close()
		_pull_http = null
	_progress.value = 100
	_progress_label.text = "✓ %s installed successfully." % _pulling_model
	_install_btn.disabled = false
	_close_btn.disabled = false
	var just_installed := _pulling_model
	_pulling_model = ""
	if not _installed_models.has(just_installed):
		_installed_models.append(just_installed)
	_populate_list()
	model_installed.emit(just_installed)

func _pull_failed(msg: String) -> void:
	if _pull_poll:
		_pull_poll.stop()
	if _pull_http:
		_pull_http.close()
		_pull_http = null
	_progress.visible = false
	_progress_label.text = "[color=red]✗ Download failed: %s[/color]" % msg
	_install_btn.disabled = false
	_close_btn.disabled = false
	_pulling_model = ""

# ---------------------------------------------------------------------------
# Hardware detection
# ---------------------------------------------------------------------------
func _get_system_ram_gb() -> float:
	# OS.get_memory_info() returns a dict with "physical" (total bytes) in Godot 4
	var info := OS.get_memory_info()
	var physical: int = info.get("physical", 0)
	if physical > 0:
		return float(physical) / (1024.0 * 1024.0 * 1024.0)
	return 8.0  # Fallback

func _has_nvidia_gpu() -> bool:
	# Simple check via /proc on Linux; best-effort only
	if OS.has_feature("linux"):
		return FileAccess.file_exists("/proc/driver/nvidia/version")
	return false

func _describe_hardware() -> String:
	var ram_gb := _get_system_ram_gb()
	var cores := OS.get_processor_count()
	var gpu_note := "  •  NVIDIA GPU detected" if _has_nvidia_gpu() else "  •  CPU-only"
	return "System: %.0f GB RAM  •  %d cores%s" % [ram_gb, cores, gpu_note]
