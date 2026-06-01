@tool
extends "res://addons/visual_gasic/vg_plugin_base.gd"

const SETTINGS_PREFIX := "vg/gdai/"
const DEFAULT_SETTINGS := {
	"enabled": true,
	"provider": "openai",
	"api_key": "",
	"endpoint": "https://api.openai.com/v1",
	"model": "gpt-4.1-mini",
	"embedding_model": "text-embedding-3-large",
	"temperature": 0.7,
	"max_tokens": 256,
	"top_p": 1.0,
	"n": 1,
}

var _enabled_checkbox: CheckBox
var _provider_picker: OptionButton
var _provider_info_label: Label
var _api_key_field: LineEdit
var _endpoint_field: LineEdit
var _model_field: LineEdit
var _embedding_model_field: LineEdit
var _max_tokens_field: SpinBox
var _temperature_field: SpinBox
var _top_p_field: SpinBox
var _n_field: SpinBox
var _asset_name_field: LineEdit
var _asset_type_field: LineEdit
var _status_label: Label
var _result_label: Label
var _history_log: TextEdit

func get_plugin_name() -> String:
	return "GDAI"

func get_toolbar_icon() -> String:
	return "🤖"

func get_toolbar_color() -> Color:
	return Color(0.14, 0.25, 0.45)

func get_toolbar_tooltip() -> String:
	return "Configure GDAI and run sample prompts"

func _build_ui() -> void:
	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(520, 520)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = "GDAI Integration"
	title.add_theme_font_size_override("font_size", 18)
	container.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Configure your model provider, save the project settings, and run AI helpers from the IDE."
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	container.add_child(subtitle)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.custom_minimum_size = Vector2(520, 0)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_FILL
	container.add_child(grid)

	_enabled_checkbox = CheckBox.new()
	_enabled_checkbox.text = "Enable GDAI"
	grid.add_child(_enabled_checkbox)
	grid.add_child(Control.new())

	grid.add_child(_make_label("Provider:"))
	_provider_picker = OptionButton.new()
	_provider_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_provider_picker.connect("item_selected", Callable(self, "_on_provider_selected"))
	grid.add_child(_provider_picker)

	grid.add_child(_make_label("API Key:"))
	_api_key_field = LineEdit.new()
	_api_key_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_api_key_field.secret = true
	grid.add_child(_api_key_field)

	grid.add_child(_make_label("Endpoint:"))
	_endpoint_field = LineEdit.new()
	_endpoint_field.placeholder_text = "https://api.openai.com/v1"
	_endpoint_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_endpoint_field)

	grid.add_child(_make_label("Model:"))
	_model_field = LineEdit.new()
	_model_field.placeholder_text = "gpt-4.1-mini"
	_model_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_model_field)

	grid.add_child(_make_label("Embedding model:"))
	_embedding_model_field = LineEdit.new()
	_embedding_model_field.placeholder_text = "text-embedding-3-large"
	_embedding_model_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_embedding_model_field)

	grid.add_child(_make_label("Max tokens:"))
	_max_tokens_field = SpinBox.new()
	_max_tokens_field.min_value = 1
	_max_tokens_field.max_value = 2048
	_max_tokens_field.step = 1
	_max_tokens_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_max_tokens_field)

	grid.add_child(_make_label("Temperature:"))
	_temperature_field = SpinBox.new()
	_temperature_field.min_value = 0.0
	_temperature_field.max_value = 2.0
	_temperature_field.step = 0.05
	_temperature_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_temperature_field)

	grid.add_child(_make_label("Top P:"))
	_top_p_field = SpinBox.new()
	_top_p_field.min_value = 0.0
	_top_p_field.max_value = 1.0
	_top_p_field.step = 0.05
	_top_p_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_top_p_field)

	grid.add_child(_make_label("N responses:"))
	_n_field = SpinBox.new()
	_n_field.min_value = 1
	_n_field.max_value = 5
	_n_field.step = 1
	_n_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_n_field)

	_provider_info_label = Label.new()
	_provider_info_label.add_theme_color_override("font_color", Color(0.65, 0.8, 1.0))
	_provider_info_label.custom_minimum_size = Vector2(520, 42)
	container.add_child(_provider_info_label)

	var helper_label := Label.new()
	helper_label.text = "AI Helpers"
	helper_label.add_theme_font_size_override("font_size", 14)
	container.add_child(helper_label)

	var asset_grid := GridContainer.new()
	asset_grid.columns = 2
	asset_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	asset_grid.size_flags_vertical = Control.SIZE_FILL

	container.add_child(asset_grid)

	asset_grid.add_child(_make_label("Asset name:"))
	_asset_name_field = LineEdit.new()
	_asset_name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	asset_grid.add_child(_asset_name_field)

	asset_grid.add_child(_make_label("Asset type:"))
	_asset_type_field = LineEdit.new()
	_asset_type_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	asset_grid.add_child(_asset_type_field)

	var action_row := HBoxContainer.new()
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(action_row)

	var save_btn := Button.new()
	save_btn.text = "Save & Initialize"
	save_btn.pressed.connect(_on_save_pressed)
	action_row.add_child(save_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reset Defaults"
	reset_btn.pressed.connect(_on_reset_defaults_pressed)
	action_row.add_child(reset_btn)

	var test_btn := Button.new()
	test_btn.text = "Test Connection"
	test_btn.pressed.connect(_on_test_connection_pressed)
	action_row.add_child(test_btn)

	var quick_row := HBoxContainer.new()
	quick_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(quick_row)

	var complete_btn := Button.new()
	complete_btn.text = "Run quick prompt"
	complete_btn.pressed.connect(_on_complete_pressed)
	quick_row.add_child(complete_btn)

	var chat_btn := Button.new()
	chat_btn.text = "Run chat prompt"
	chat_btn.pressed.connect(_on_chat_pressed)
	quick_row.add_child(chat_btn)

	var comment_btn := Button.new()
	comment_btn.text = "Generate comment"
	comment_btn.pressed.connect(_on_generate_comment_pressed)
	quick_row.add_child(comment_btn)

	var asset_btn := Button.new()
	asset_btn.text = "Generate asset description"
	asset_btn.pressed.connect(_on_generate_asset_description_pressed)
	quick_row.add_child(asset_btn)

	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	container.add_child(_status_label)

	_history_log = TextEdit.new()
	_history_log.editable = false
	_history_log.custom_minimum_size = Vector2(520, 140)
	_history_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(_history_log)

	_result_label = Label.new()
	_result_label.text = ""
	container.add_child(_result_label)

	_view.add_child(container)
	_initialize_provider_options()
	_load_settings()
	_update_provider_info()
	GDAI.initialize_from_project_settings()
	_update_status("Ready.")

func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_FILL
	return label

func _initialize_provider_options() -> void:
	_provider_picker.clear()
	for provider_id in GDAI.supported_providers():
		var info = GDAI.get_provider_info(provider_id)
		var idx = _provider_picker.get_item_count()
		_provider_picker.add_item(info.get("display_name", provider_id))
		_provider_picker.set_item_metadata(idx, provider_id)

func _load_settings() -> void:
	for key in DEFAULT_SETTINGS.keys():
		var path = SETTINGS_PREFIX + key
		if not ProjectSettings.has_setting(path):
			ProjectSettings.set_initial_value(path, DEFAULT_SETTINGS[key])

	_enabled_checkbox.set_pressed(ProjectSettings.get_setting(SETTINGS_PREFIX + "enabled", DEFAULT_SETTINGS["enabled"]))
	var provider_value = ProjectSettings.get_setting(SETTINGS_PREFIX + "provider", DEFAULT_SETTINGS["provider"])
	_select_provider(str(provider_value))
	_api_key_field.text = str(ProjectSettings.get_setting(SETTINGS_PREFIX + "api_key", DEFAULT_SETTINGS["api_key"]))
	_endpoint_field.text = str(ProjectSettings.get_setting(SETTINGS_PREFIX + "endpoint", DEFAULT_SETTINGS["endpoint"]))
	_model_field.text = str(ProjectSettings.get_setting(SETTINGS_PREFIX + "model", DEFAULT_SETTINGS["model"]))
	_embedding_model_field.text = str(ProjectSettings.get_setting(SETTINGS_PREFIX + "embedding_model", DEFAULT_SETTINGS["embedding_model"]))
	_max_tokens_field.value = float(ProjectSettings.get_setting(SETTINGS_PREFIX + "max_tokens", DEFAULT_SETTINGS["max_tokens"]))
	_temperature_field.value = float(ProjectSettings.get_setting(SETTINGS_PREFIX + "temperature", DEFAULT_SETTINGS["temperature"]))
	_top_p_field.value = float(ProjectSettings.get_setting(SETTINGS_PREFIX + "top_p", DEFAULT_SETTINGS["top_p"]))
	_n_field.value = float(ProjectSettings.get_setting(SETTINGS_PREFIX + "n", DEFAULT_SETTINGS["n"]))
	_asset_name_field.text = ""
	_asset_type_field.text = ""
	_asset_name_field.text = ""
	_asset_type_field.text = ""

func _save_settings() -> void:
	var config := _build_config()
	var validation = GDAI.validate_config(config)
	if not validation.get("valid", false):
		_update_status(validation.get("error", "Invalid configuration."), true)
		return

	GDAI.save_project_settings(config)
	GDAI.initialize(config)
	_update_status("GDAI configuration saved and initialized.")
	_append_history("Settings", "Saved provider %s." % config["provider"])

func _build_config() -> Dictionary:
	return {
		"enabled": _enabled_checkbox.pressed,
		"provider": _get_selected_provider_id(),
		"api_key": _api_key_field.text.strip_edges(),
		"endpoint": _endpoint_field.text.strip_edges(),
		"model": _model_field.text.strip_edges(),
		"embedding_model": _embedding_model_field.text.strip_edges(),
		"temperature": _temperature_field.value,
		"max_tokens": int(_max_tokens_field.value),
		"top_p": _top_p_field.value,
		"n": int(_n_field.value),
	}

func _get_selected_provider_id() -> String:
	var idx = _provider_picker.selected
	if idx < 0:
		return DEFAULT_SETTINGS["provider"]
	return String(_provider_picker.get_item_metadata(idx))

func _select_provider(provider_id: String) -> void:
	for i in range(_provider_picker.get_item_count()):
		if String(_provider_picker.get_item_metadata(i)) == provider_id:
			_provider_picker.select(i)
			return
	_provider_picker.select(0)

func _on_provider_selected(index: int) -> void:
	_update_provider_info()

func _update_provider_info() -> void:
	var provider_id = _get_selected_provider_id()
	var info = GDAI.get_provider_info(provider_id)
	if info.size() == 0:
		_provider_info_label.text = "Unknown provider selected."
		return
	_provider_info_label.text = "%s — %s" % [info.get("display_name", provider_id), info.get("description", "")]

func _validate_settings() -> bool:
	var config = _build_config()
	var validation = GDAI.validate_config(config)
	if not validation.get("valid", false):
		_update_status(validation.get("error", "Invalid configuration."), true)
		return false
	return true

func _on_save_pressed() -> void:
	_save_settings()

func _on_reset_defaults_pressed() -> void:
	_enabled_checkbox.set_pressed(DEFAULT_SETTINGS["enabled"])
	_select_provider(str(DEFAULT_SETTINGS["provider"]))
	_api_key_field.text = str(DEFAULT_SETTINGS["api_key"])
	_endpoint_field.text = str(DEFAULT_SETTINGS["endpoint"])
	_model_field.text = str(DEFAULT_SETTINGS["model"])
	_embedding_model_field.text = str(DEFAULT_SETTINGS["embedding_model"])
	_max_tokens_field.value = float(DEFAULT_SETTINGS["max_tokens"])
	_temperature_field.value = float(DEFAULT_SETTINGS["temperature"])
	_top_p_field.value = float(DEFAULT_SETTINGS["top_p"])
	_n_field.value = float(DEFAULT_SETTINGS["n"])
	_update_provider_info()
	_update_status("Reset to default GDAI settings.")

func _on_test_connection_pressed() -> void:
	_save_settings()
	if not GDAI.is_enabled():
		_update_status("GDAI is disabled, cannot test connection.", true)
		return
	_status_label.text = "Testing provider connection..."
	var test_result := await GDAI.complete("Respond with the single word 'pong' to verify GDAI connectivity.")
	if GDAI.has_error():
		_update_status("Connection failed: %s" % GDAI.get_last_error(), true)
		_append_history("Test", "Failed: %s" % GDAI.get_last_error())
		return
	_append_history("Test", test_result)
	_update_status("Connection successful.")

func _on_complete_pressed() -> void:
	if not _validate_settings():
		return
	_save_settings()
	_status_label.text = "Running quick prompt..."
	var result := await GDAI.complete("Write a one-sentence game title for a neon cyberpunk arcade shooter.")
	if GDAI.has_error():
		_update_status("Prompt failed: %s" % GDAI.get_last_error(), true)
		return
	_result_label.text = "Complete result: %s" % result
	_append_history("Prompt", result)
	_update_status("Prompt completed.")

func _on_chat_pressed() -> void:
	if not _validate_settings():
		return
	_save_settings()
	_status_label.text = "Running chat prompt..."
	var response := await GDAI.chat([
		{"role": "system", "content": "You are a helpful game-writing assistant."},
		{"role": "user", "content": "Generate a short intro line for an arcade boss."},
	])
	if GDAI.has_error():
		_update_status("Chat failed: %s" % GDAI.get_last_error(), true)
		return
	_result_label.text = "Chat response: %s" % response
	_append_history("Chat", response)
	_update_status("Chat prompt completed.")

func _get_active_code_edit():
	if _host_plugin and _host_plugin.has_method("_get_active_code_edit"):
		return _host_plugin._get_active_code_edit()
	return null

func _on_generate_comment_pressed() -> void:
	if not _validate_settings():
		return
	_save_settings()
	var code_edit = _get_active_code_edit()
	if not code_edit:
		_update_status("No active code editor available.", true)
		return
	var file_path = code_edit.get_file_path()
	if file_path == "" or not file_path.ends_with(".vg"):
		_update_status("Active file is not a .vg source file.", true)
		return
	var snippet = code_edit.get_selected_text().strip_edges()
	if snippet == "":
		snippet = code_edit.get_text()
	var prompt = "Review the following VisualGasic code and return a concise comment or docstring header that describes the code's purpose. Do not include any explanation outside the comment.\n\n" + snippet
	_status_label.text = "Generating comment..."
	var result := await GDAI.complete(prompt, _build_options())
	if GDAI.has_error():
		_update_status("Comment generation failed: %s" % GDAI.get_last_error(), true)
		return
	_result_label.text = "Comment result: %s" % result
	_append_history("Comment", result)
	_update_status("Comment generation completed.")

func _on_generate_asset_description_pressed() -> void:
	if not _validate_settings():
		return
	_save_settings()
	var asset_name = _asset_name_field.text.strip_edges()
	var asset_type = _asset_type_field.text.strip_edges()
	if asset_name == "":
		asset_name = "Game asset"
	if asset_type == "":
		asset_type = "game object"
	var prompt = "Write a short descriptive name and a concise asset description for a %s named '%s'." % [asset_type, asset_name]
	_status_label.text = "Generating asset description..."
	var result := await GDAI.complete(prompt, _build_options())
	if GDAI.has_error():
		_update_status("Asset description failed: %s" % GDAI.get_last_error(), true)
		return
	_result_label.text = "Asset description: %s" % result
	_append_history("Asset", result)
	_update_status("Asset description generated.")

func _build_options() -> Dictionary:
	return {
		"max_tokens": int(_max_tokens_field.value),
		"temperature": float(_temperature_field.value),
		"top_p": float(_top_p_field.value),
		"n": int(_n_field.value),
	}

func _append_history(title: String, message: String) -> void:
	var timestamp = ""
	_history_log.text += "[%s] %s\n%s\n\n" % [title, timestamp, message]
	_history_log.scroll_vertical = _history_log.get_line_count()

func _update_status(text: String = "", is_error: bool = false) -> void:
	if text != "":
		_status_label.text = text
		var status_color = Color(0.4, 0.9, 0.4)
		if is_error:
			status_color = Color(0.9, 0.4, 0.4)
		_status_label.add_theme_color_override("font_color", status_color)
	return
