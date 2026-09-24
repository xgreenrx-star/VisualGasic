#include "vg_input_edge.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/templates/hash_set.hpp>

using namespace godot;

namespace {

uint64_t s_frame = UINT64_MAX;
HashSet<Key> s_tracked_keys;
HashSet<Key> s_pressed_end_of_prev_frame;
HashSet<Key> s_pressed_this_frame;

void sync_frame() {
	Engine *engine = Engine::get_singleton();
	if (!engine) {
		return;
	}
	uint64_t frame = engine->get_process_frames();
	Input *input = Input::get_singleton();
	if (!input) {
		return;
	}
	if (frame != s_frame) {
		if (s_frame != UINT64_MAX) {
			s_pressed_end_of_prev_frame = s_pressed_this_frame;
		}
		s_frame = frame;
		s_pressed_this_frame.clear();
	}
	for (Key key : s_tracked_keys) {
		if (input->is_key_pressed(key)) {
			s_pressed_this_frame.insert(key);
		}
	}
}

void track_key(Key p_key) {
	s_tracked_keys.insert(p_key);
}

} // namespace

bool VGInputEdge::is_key_just_pressed(Key p_key) {
	track_key(p_key);
	sync_frame();
	return s_pressed_this_frame.has(p_key) && !s_pressed_end_of_prev_frame.has(p_key);
}

bool VGInputEdge::is_key_just_released(Key p_key) {
	track_key(p_key);
	sync_frame();
	return !s_pressed_this_frame.has(p_key) && s_pressed_end_of_prev_frame.has(p_key);
}
