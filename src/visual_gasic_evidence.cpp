#include "visual_gasic_evidence.h"

#include "visual_gasic_ast.h"
#include "visual_gasic_script.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/engine_debugger.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/hashing_context.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/variant/callable_method_pointer.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>

#include <mutex>

using namespace godot;

std::atomic<bool> vg_evidence_recording_flag{false};

namespace {

std::mutex g_mutex;
bool g_quit_armed = false;

// Godot containers must not be process-lifetime globals. Constructing them
// while the extension loads crashes before the engine finishes initializing.
struct RingState {
	bool recording = false;
	int capacity = 512;
	int dropped = 0;
	int64_t next_seq = 0;
	int64_t started_ticks = 0;
	String run_id;
	PackedStringArray watch_display;
	HashSet<String> watch;
	Array events;
	Array scripts;
	HashMap<String, int> script_index;
	bool saw_worker = false;
	bool autostarted = false;
};

RingState *g_state = nullptr;

RingState &state() {
	if (g_state == nullptr) {
		g_state = new RingState();
	}
	return *g_state;
}

const char *k_limit_module = "Only module-level variables are watched. A local that shadows a watched name is ignored.";
const char *k_limit_line = "Executing line numbers come from debug_state.current_line. Bytecode sets that field from OP_DEBUG_LINE before the debugger gate. A missing line is unknown (line 0, location_known false).";
const char *k_limit_value = "Value capture does not call user code. Strings longer than 120 characters are truncated. Arrays and dictionaries are recorded as type and size only.";
const char *k_limit_callback = "Callback resolved flags check procedures declared in the same script.";
const char *k_limit_worker = "Parallel worker assignments are not recorded.";
const char *k_limit_autostart = "Recording started because vg/evidence/runtime_ring is enabled and the game was launched from the editor debugger.";

int clamp_capacity(int p_capacity) {
	if (p_capacity < 64) {
		return 64;
	}
	if (p_capacity > 4096) {
		return 4096;
	}
	return p_capacity;
}

String read_vg_version() {
	const String path = "res://addons/visual_gasic/plugin.cfg";
	if (!FileAccess::file_exists(path)) {
		return "unknown";
	}
	String text = FileAccess::get_file_as_string(path);
	const String key = "version=\"";
	int at = text.find(key);
	if (at < 0) {
		return "unknown";
	}
	int start = at + key.length();
	int end = text.find("\"", start);
	if (end < 0) {
		return "unknown";
	}
	return text.substr(start, end - start);
}

String read_godot_version() {
	Engine *engine = Engine::get_singleton();
	if (engine == nullptr) {
		return "unknown";
	}
	Dictionary info = engine->get_version_info();
	Variant value = info.get("string", Variant());
	if (value.get_type() != Variant::STRING) {
		return "unknown";
	}
	String text = value;
	if (text.is_empty()) {
		return "unknown";
	}
	return text;
}

String hash_source(const String &p_source) {
	Ref<HashingContext> ctx;
	ctx.instantiate();
	ctx->start(HashingContext::HASH_SHA256);
	ctx->update(p_source.to_utf8_buffer());
	return ctx->finish().hex_encode();
}

Variant capture_value(const Variant &p_value) {
	switch (p_value.get_type()) {
		case Variant::STRING: {
			String text = p_value;
			if (text.length() <= 120) {
				return p_value;
			}
			Dictionary boxed;
			boxed["value"] = text.substr(0, 120);
			boxed["truncated"] = true;
			return boxed;
		}
		case Variant::ARRAY: {
			Dictionary boxed;
			boxed["type"] = "Array";
			boxed["size"] = Array(p_value).size();
			return boxed;
		}
		case Variant::DICTIONARY: {
			Dictionary boxed;
			boxed["type"] = "Dictionary";
			boxed["size"] = Dictionary(p_value).size();
			return boxed;
		}
		case Variant::PACKED_BYTE_ARRAY: {
			Dictionary boxed;
			boxed["type"] = "PackedByteArray";
			boxed["size"] = PackedByteArray(p_value).size();
			return boxed;
		}
		case Variant::PACKED_INT32_ARRAY: {
			Dictionary boxed;
			boxed["type"] = "PackedInt32Array";
			boxed["size"] = PackedInt32Array(p_value).size();
			return boxed;
		}
		case Variant::PACKED_INT64_ARRAY: {
			Dictionary boxed;
			boxed["type"] = "PackedInt64Array";
			boxed["size"] = PackedInt64Array(p_value).size();
			return boxed;
		}
		case Variant::PACKED_FLOAT32_ARRAY: {
			Dictionary boxed;
			boxed["type"] = "PackedFloat32Array";
			boxed["size"] = PackedFloat32Array(p_value).size();
			return boxed;
		}
		case Variant::PACKED_FLOAT64_ARRAY: {
			Dictionary boxed;
			boxed["type"] = "PackedFloat64Array";
			boxed["size"] = PackedFloat64Array(p_value).size();
			return boxed;
		}
		case Variant::PACKED_STRING_ARRAY: {
			Dictionary boxed;
			boxed["type"] = "PackedStringArray";
			boxed["size"] = PackedStringArray(p_value).size();
			return boxed;
		}
		case Variant::PACKED_VECTOR2_ARRAY: {
			Dictionary boxed;
			boxed["type"] = "PackedVector2Array";
			boxed["size"] = PackedVector2Array(p_value).size();
			return boxed;
		}
		case Variant::PACKED_VECTOR3_ARRAY: {
			Dictionary boxed;
			boxed["type"] = "PackedVector3Array";
			boxed["size"] = PackedVector3Array(p_value).size();
			return boxed;
		}
		case Variant::PACKED_COLOR_ARRAY: {
			Dictionary boxed;
			boxed["type"] = "PackedColorArray";
			boxed["size"] = PackedColorArray(p_value).size();
			return boxed;
		}
		case Variant::OBJECT: {
			Object *obj = p_value;
			Dictionary boxed;
			if (obj == nullptr) {
				boxed["class"] = "";
				boxed["instance_id"] = (int64_t)0;
				return boxed;
			}
			boxed["class"] = obj->get_class();
			boxed["instance_id"] = (int64_t)obj->get_instance_id();
			return boxed;
		}
		default:
			return p_value;
	}
}

void collect_locals(VisualGasic::Statement *p_stmt, HashSet<String> &r_names) {
	if (p_stmt == nullptr) {
		return;
	}
	using namespace VisualGasic;
	switch (p_stmt->type) {
		case STMT_DIM:
			r_names.insert(static_cast<DimStatement *>(p_stmt)->variable_name.to_lower());
			break;
		case STMT_IF: {
			IfStatement *stmt = static_cast<IfStatement *>(p_stmt);
			for (int i = 0; i < stmt->then_branch.size(); i++) {
				collect_locals(stmt->then_branch[i], r_names);
			}
			for (int i = 0; i < stmt->else_branch.size(); i++) {
				collect_locals(stmt->else_branch[i], r_names);
			}
			break;
		}
		case STMT_FOR: {
			ForStatement *stmt = static_cast<ForStatement *>(p_stmt);
			r_names.insert(stmt->variable_name.to_lower());
			for (int i = 0; i < stmt->body.size(); i++) {
				collect_locals(stmt->body[i], r_names);
			}
			break;
		}
		case STMT_WHILE: {
			WhileStatement *stmt = static_cast<WhileStatement *>(p_stmt);
			for (int i = 0; i < stmt->body.size(); i++) {
				collect_locals(stmt->body[i], r_names);
			}
			break;
		}
		case STMT_DO: {
			DoStatement *stmt = static_cast<DoStatement *>(p_stmt);
			for (int i = 0; i < stmt->body.size(); i++) {
				collect_locals(stmt->body[i], r_names);
			}
			break;
		}
		case STMT_FOR_EACH: {
			ForEachStatement *stmt = static_cast<ForEachStatement *>(p_stmt);
			r_names.insert(stmt->variable_name.to_lower());
			if (!stmt->index_variable_name.is_empty()) {
				r_names.insert(stmt->index_variable_name.to_lower());
			}
			for (int i = 0; i < stmt->body.size(); i++) {
				collect_locals(stmt->body[i], r_names);
			}
			break;
		}
		case STMT_SELECT: {
			SelectStatement *stmt = static_cast<SelectStatement *>(p_stmt);
			for (int i = 0; i < stmt->cases.size(); i++) {
				CaseBlock *block = stmt->cases[i];
				if (block == nullptr) {
					continue;
				}
				for (int j = 0; j < block->body.size(); j++) {
					collect_locals(block->body[j], r_names);
				}
			}
			break;
		}
		default:
			break;
	}
}

bool is_module_level(VisualGasicScript *p_script, VisualGasic::SubDefinition *p_proc, const String &p_name) {
	if (p_script == nullptr || p_script->ast_root == nullptr) {
		return false;
	}
	String key = p_name.to_lower();
	if (p_proc != nullptr) {
		for (int i = 0; i < p_proc->parameters.size(); i++) {
			if (p_proc->parameters[i].name.to_lower() == key) {
				return false;
			}
		}
		HashSet<String> locals;
		for (int i = 0; i < p_proc->statements.size(); i++) {
			collect_locals(p_proc->statements[i], locals);
		}
		if (locals.has(key)) {
			return false;
		}
	}
	for (int i = 0; i < p_script->ast_root->variables.size(); i++) {
		VisualGasic::VariableDefinition *var_def = p_script->ast_root->variables[i];
		if (var_def != nullptr && var_def->name.to_lower() == key) {
			return true;
		}
	}
	return false;
}

bool procedure_exists(VisualGasicScript *p_script, const String &p_name) {
	if (p_script == nullptr || p_script->ast_root == nullptr) {
		return false;
	}
	for (int i = 0; i < p_script->ast_root->subs.size(); i++) {
		VisualGasic::SubDefinition *sub = p_script->ast_root->subs[i];
		if (sub != nullptr && sub->name.nocasecmp_to(p_name) == 0) {
			return true;
		}
	}
	return false;
}

void remember_watch_name(const String &p_name) {
	String trimmed = p_name.strip_edges();
	if (trimmed.is_empty()) {
		return;
	}
	String key = trimmed.to_lower();
	if (state().watch.has(key)) {
		return;
	}
	state().watch.insert(key);
	state().watch_display.push_back(trimmed);
}

void read_watch_variant(const Variant &p_value) {
	if (p_value.get_type() == Variant::PACKED_STRING_ARRAY) {
		PackedStringArray names = p_value;
		for (int i = 0; i < names.size(); i++) {
			remember_watch_name(names[i]);
		}
		return;
	}
	if (p_value.get_type() == Variant::ARRAY) {
		Array names = p_value;
		for (int i = 0; i < names.size(); i++) {
			remember_watch_name(String(names[i]));
		}
	}
}

void load_project_defaults(int &r_capacity, bool &r_have_watch) {
	ProjectSettings *settings = ProjectSettings::get_singleton();
	if (settings == nullptr) {
		return;
	}
	if (settings->has_setting("vg/evidence/runtime_ring_capacity")) {
		r_capacity = clamp_capacity((int)settings->get_setting("vg/evidence/runtime_ring_capacity"));
	}
	if (settings->has_setting("vg/evidence/watch")) {
		read_watch_variant(settings->get_setting("vg/evidence/watch"));
		r_have_watch = true;
	}
}

void clear_run_locked() {
	state().events.clear();
	state().scripts.clear();
	state().script_index.clear();
	state().dropped = 0;
	state().next_seq = 0;
	state().started_ticks = 0;
	state().run_id = "";
	state().saw_worker = false;
	state().autostarted = false;
}

void touch_script_locked(VisualGasicScript *p_script, const char *p_engine) {
	if (p_script == nullptr) {
		return;
	}
	String path = p_script->get_path();
	String key = path.is_empty() ? String("mem:") + String::num_int64((int64_t)(uintptr_t)p_script) : path;
	if (state().script_index.has(key)) {
		int index = state().script_index[key];
		Dictionary row = state().scripts[index];
		row["engine"] = String(p_engine);
		state().scripts[index] = row;
		return;
	}
	Dictionary row;
	row["path"] = path;
	row["content_hash"] = hash_source(p_script->_get_source_code());
	row["engine"] = String(p_engine);
	state().scripts.push_back(row);
	state().script_index[key] = state().scripts.size() - 1;
}

Dictionary begin_event_locked(VisualGasicScript *p_script, VisualGasic::SubDefinition *p_proc, int p_line, const char *p_engine, const String &p_kind) {
	touch_script_locked(p_script, p_engine);
	Dictionary event;
	event["seq"] = state().next_seq;
	state().next_seq += 1;
	event["kind"] = p_kind;
	event["engine"] = String(p_engine);
	event["script_path"] = p_script != nullptr ? p_script->get_path() : String();
	event["script_hash"] = "";
	if (p_script != nullptr) {
		String path = p_script->get_path();
		String key = path.is_empty() ? String("mem:") + String::num_int64((int64_t)(uintptr_t)p_script) : path;
		if (state().script_index.has(key)) {
			Dictionary row = state().scripts[state().script_index[key]];
			event["script_hash"] = row["content_hash"];
		}
	}
	event["procedure"] = p_proc != nullptr ? p_proc->name : String();
	if (p_line > 0) {
		event["line"] = p_line;
		event["location_known"] = true;
	} else {
		event["line"] = 0;
		event["location_known"] = false;
	}
	Time *clock = Time::get_singleton();
	event["ticks_msec"] = clock != nullptr ? (int64_t)clock->get_ticks_msec() : (int64_t)0;
	return event;
}

void push_event_locked(const Dictionary &p_event) {
	if (state().events.size() >= state().capacity) {
		state().events.remove_at(0);
		state().dropped += 1;
	}
	state().events.push_back(p_event);
}

Array standing_limitations() {
	Array notes;
	notes.push_back(String(k_limit_module));
	notes.push_back(String(k_limit_line));
	notes.push_back(String(k_limit_value));
	notes.push_back(String(k_limit_callback));
	if (state().saw_worker) {
		notes.push_back(String(k_limit_worker));
	}
	if (state().autostarted) {
		notes.push_back(String(k_limit_autostart));
	}
	return notes;
}

bool recording_and_main_thread() {
	if (!vg_evidence_recording()) {
		return false;
	}
	if (vg_evidence_on_worker_thread()) {
		std::lock_guard<std::mutex> lock(g_mutex);
		state().saw_worker = true;
		return false;
	}
	return true;
}

} // namespace

void vg_evidence_on_scene_quit() {
	bool should_send = false;
	{
		std::lock_guard<std::mutex> lock(g_mutex);
		should_send = g_state != nullptr && (state().recording || state().events.size() > 0);
	}
	if (should_send) {
		EngineDebugger *debugger = EngineDebugger::get_singleton();
		if (debugger != nullptr && debugger->is_active()) {
			Dictionary snap = vg_evidence_snapshot();
			Array msg;
			msg.push_back(snap);
			debugger->send_message("visualgasic:evidence_data", msg);
		}
	}
	vg_evidence_stop();
}

bool vg_evidence_autostart_decision(bool p_setting_enabled, bool p_debugger_active) {
	return p_setting_enabled && p_debugger_active;
}

static bool g_autostart_done = false;

void vg_evidence_maybe_autostart() {
	if (g_autostart_done || vg_evidence_recording()) {
		return;
	}
	bool setting_on = false;
	ProjectSettings *settings = ProjectSettings::get_singleton();
	if (settings != nullptr && settings->has_setting("vg/evidence/runtime_ring")) {
		setting_on = (bool)settings->get_setting("vg/evidence/runtime_ring");
	}
	bool debugger_active = false;
	EngineDebugger *debugger = EngineDebugger::get_singleton();
	if (debugger != nullptr && debugger->is_active()) {
		debugger_active = true;
	}
	if (!vg_evidence_autostart_decision(setting_on, debugger_active)) {
		return;
	}
	g_autostart_done = true;
	vg_evidence_start(Dictionary());
	std::lock_guard<std::mutex> lock(g_mutex);
	state().autostarted = true;
}

String vg_evidence_start(const Dictionary &p_config) {
	std::lock_guard<std::mutex> lock(g_mutex);
	vg_evidence_recording_flag.store(false, std::memory_order_relaxed);
	state().recording = false;
	clear_run_locked();
	state().watch.clear();
	state().watch_display = PackedStringArray();
	int capacity = 512;
	bool have_watch = false;
	load_project_defaults(capacity, have_watch);
	if (p_config.has("capacity")) {
		capacity = (int)p_config["capacity"];
	}
	if (p_config.has("watch")) {
		state().watch.clear();
		state().watch_display = PackedStringArray();
		read_watch_variant(p_config["watch"]);
	}
	state().capacity = clamp_capacity(capacity);
	Time *clock = Time::get_singleton();
	state().started_ticks = clock != nullptr ? (int64_t)clock->get_ticks_msec() : (int64_t)0;
	state().next_seq = 1;
	static int64_t run_serial = 0;
	run_serial += 1;
	state().run_id = String("run-") + String::num_int64(run_serial);
	state().recording = true;
	vg_evidence_recording_flag.store(true, std::memory_order_relaxed);
	return state().run_id;
}

void vg_evidence_stop() {
	std::lock_guard<std::mutex> lock(g_mutex);
	vg_evidence_recording_flag.store(false, std::memory_order_relaxed);
	if (g_state == nullptr) {
		return;
	}
	state().recording = false;
	clear_run_locked();
	state().watch.clear();
	state().watch_display = PackedStringArray();
	state().capacity = 512;
}

Dictionary vg_evidence_snapshot() {
	std::lock_guard<std::mutex> lock(g_mutex);
	Dictionary snap;
	snap["schema"] = "behavior-run/1";
	snap["run_id"] = state().run_id;
	snap["started_ticks_msec"] = state().started_ticks;
	snap["vg_version"] = read_vg_version();
	snap["godot_version"] = read_godot_version();
	snap["recording"] = state().recording;
	snap["capacity"] = state().capacity;
	snap["dropped"] = state().dropped;
	snap["next_seq"] = state().next_seq;
	Array watch;
	for (int i = 0; i < state().watch_display.size(); i++) {
		watch.push_back(state().watch_display[i]);
	}
	snap["watch"] = watch;
	snap["scripts"] = state().scripts.duplicate(true);
	snap["events"] = state().events.duplicate(true);
	snap["limitations"] = standing_limitations();
	return snap;
}

void vg_evidence_arm_scene_quit(godot::Node *p_node) {
	if (g_quit_armed || p_node == nullptr || !p_node->is_inside_tree()) {
		return;
	}
	SceneTree *tree = p_node->get_tree();
	if (tree == nullptr) {
		return;
	}
	Window *root = tree->get_root();
	if (root == nullptr) {
		return;
	}
	Error err = root->connect("tree_exiting", callable_mp_static(vg_evidence_on_scene_quit));
	if (err == OK) {
		g_quit_armed = true;
	}
}

void vg_evidence_note_module_write(VisualGasicScript *p_script, VisualGasic::SubDefinition *p_proc, int p_line, const char *p_engine, const String &p_name, const Variant &p_old_value, const Variant &p_new_value) {
	if (!recording_and_main_thread()) {
		return;
	}
	String key = p_name.to_lower();
	{
		std::lock_guard<std::mutex> lock(g_mutex);
		if (!state().recording || !state().watch.has(key)) {
			return;
		}
	}
	if (!is_module_level(p_script, p_proc, p_name)) {
		return;
	}
	std::lock_guard<std::mutex> lock(g_mutex);
	if (!state().recording || !state().watch.has(key)) {
		return;
	}
	Dictionary event = begin_event_locked(p_script, p_proc, p_line, p_engine, "watched_write");
	event["variable"] = p_name;
	event["old"] = capture_value(p_old_value);
	event["new"] = capture_value(p_new_value);
	push_event_locked(event);
}

void vg_evidence_note_fired(VisualGasicScript *p_script, VisualGasic::SubDefinition *p_proc, int p_line, const char *p_engine, const String &p_section, const String &p_variable, const String &p_operator, const Variant &p_target, const Variant &p_old_value, const Variant &p_new_value, int p_declared_line, const Vector<String> &p_callbacks, bool p_deferred) {
	if (!recording_and_main_thread()) {
		return;
	}
	Array callbacks;
	for (int i = 0; i < p_callbacks.size(); i++) {
		Dictionary row;
		row["name"] = p_callbacks[i];
		row["resolved"] = procedure_exists(p_script, p_callbacks[i]);
		callbacks.push_back(row);
	}
	std::lock_guard<std::mutex> lock(g_mutex);
	if (!state().recording) {
		return;
	}
	Dictionary event = begin_event_locked(p_script, p_proc, p_line, p_engine, "whenever_fired");
	event["section"] = p_section;
	event["variable"] = p_variable;
	event["operator"] = p_operator;
	event["target"] = p_target;
	event["old"] = capture_value(p_old_value);
	event["new"] = capture_value(p_new_value);
	event["declared_line"] = p_declared_line;
	event["callbacks"] = callbacks;
	event["deferred"] = p_deferred;
	push_event_locked(event);
}

void vg_evidence_note_suppressed(VisualGasicScript *p_script, VisualGasic::SubDefinition *p_proc, int p_line, const char *p_engine, const String &p_section, const String &p_variable, const String &p_reason) {
	if (!recording_and_main_thread()) {
		return;
	}
	std::lock_guard<std::mutex> lock(g_mutex);
	if (!state().recording) {
		return;
	}
	Dictionary event = begin_event_locked(p_script, p_proc, p_line, p_engine, "whenever_suppressed");
	event["section"] = p_section;
	event["variable"] = p_variable;
	event["reason"] = p_reason;
	push_event_locked(event);
}

void vg_evidence_note_missing(VisualGasicScript *p_script, VisualGasic::SubDefinition *p_proc, int p_line, const char *p_engine, const String &p_section, const String &p_callback) {
	if (!recording_and_main_thread()) {
		return;
	}
	std::lock_guard<std::mutex> lock(g_mutex);
	if (!state().recording) {
		return;
	}
	Dictionary event = begin_event_locked(p_script, p_proc, p_line, p_engine, "callback_missing");
	event["section"] = p_section;
	event["callback"] = p_callback;
	push_event_locked(event);
}
