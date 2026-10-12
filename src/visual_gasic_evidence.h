#ifndef VISUAL_GASIC_EVIDENCE_H
#define VISUAL_GASIC_EVIDENCE_H

#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/templates/vector.hpp>
#include <atomic>

class VisualGasicScript;
namespace godot {
class Node;
}
namespace VisualGasic {
struct SubDefinition;
}

// Hot path: one relaxed load. False unless vg_evidence_start() is active.
extern std::atomic<bool> vg_evidence_recording_flag;

inline bool vg_evidence_recording() {
	return vg_evidence_recording_flag.load(std::memory_order_relaxed);
}

bool vg_evidence_on_worker_thread();

godot::String vg_evidence_start(const godot::Dictionary &p_config);
godot::Dictionary vg_evidence_snapshot();
void vg_evidence_stop();

// True only when the project setting is on and this process is a debugger session.
// Headless tests call this directly; EngineDebugger cannot be faked.
bool vg_evidence_autostart_decision(bool p_setting_enabled, bool p_debugger_active);
// Once per process, before the first script's module init. No-op unless the decision is true.
void vg_evidence_maybe_autostart();

void vg_evidence_arm_scene_quit(godot::Node *p_node);

void vg_evidence_note_module_write(VisualGasicScript *p_script, VisualGasic::SubDefinition *p_proc, int p_line, const char *p_engine, const godot::String &p_name, const godot::Variant &p_old_value, const godot::Variant &p_new_value);

void vg_evidence_note_fired(VisualGasicScript *p_script, VisualGasic::SubDefinition *p_proc, int p_line, const char *p_engine, const godot::String &p_section, const godot::String &p_variable, const godot::String &p_operator, const godot::Variant &p_target, const godot::Variant &p_old_value, const godot::Variant &p_new_value, int p_declared_line, const godot::Vector<godot::String> &p_callbacks);

void vg_evidence_note_suppressed(VisualGasicScript *p_script, VisualGasic::SubDefinition *p_proc, int p_line, const char *p_engine, const godot::String &p_section, const godot::String &p_variable, const godot::String &p_reason);

void vg_evidence_note_missing(VisualGasicScript *p_script, VisualGasic::SubDefinition *p_proc, int p_line, const char *p_engine, const godot::String &p_section, const godot::String &p_callback);

#endif
