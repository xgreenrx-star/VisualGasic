#include "vg_input_edge.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/templates/hash_set.hpp>

using namespace godot;

namespace {

uint64_t s_frame = UINT64_MAX;
HashSet<Key> s_down_at_frame_start;
HashSet<Key> s_tracked_keys;
HashSet<Key> s_seen_keys;

void sync_input_edge_frame() {
	Engine *engine = Engine::get_singleton();
	if (!engine) {
		return;
	}
	uint64_t frame = engine->get_process_frames();
	if (frame == s_frame) {
		return;
	}
	s_frame = frame;
	s_down_at_frame_start.clear();
	Input *input = Input::get_singleton();
	if (!input) {
		return;
	}
	for (Key key : s_tracked_keys) {
		if (input->is_key_pressed(key)) {
			s_down_at_frame_start.insert(key);
		}
	}
}

void track_key(Key p_key) {
	s_tracked_keys.insert(p_key);
	if (!s_seen_keys.has(p_key)) {
		s_seen_keys.insert(p_key);
		Input *input = Input::get_singleton();
		if (input && input->is_key_pressed(p_key)) {
			s_down_at_frame_start.insert(p_key);
		}
	}
}

} // namespace

bool VGInputEdge::is_key_just_pressed(Key p_key) {
	track_key(p_key);
	sync_input_edge_frame();
	Input *input = Input::get_singleton();
	if (!input) {
		return false;
	}
	bool now = input->is_key_pressed(p_key);
	return now && !s_down_at_frame_start.has(p_key);
}

bool VGInputEdge::is_key_just_released(Key p_key) {
	track_key(p_key);
	sync_input_edge_frame();
	Input *input = Input::get_singleton();
	if (!input) {
		return false;
	}
	bool now = input->is_key_pressed(p_key);
	return !now && s_down_at_frame_start.has(p_key);
}
