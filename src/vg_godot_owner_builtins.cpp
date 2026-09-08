#include "vg_godot_owner_builtins.h"

#include <cstring>
#include <godot_cpp/classes/canvas_item.hpp>
#include <godot_cpp/classes/character_body2d.hpp>
#include <godot_cpp/classes/display_server.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/viewport.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace {

Node *owner_node(VisualGasicInstance *instance) {
	if (!instance) {
		return nullptr;
	}
	return Object::cast_to<Node>(instance->get_owner());
}

SceneTree *owner_tree(VisualGasicInstance *instance) {
	Node *n = owner_node(instance);
	if (!n || !n->is_inside_tree()) {
		return nullptr;
	}
	return n->get_tree();
}

void emit_on_owner(Object *obj, const Array &args) {
	if (!obj || args.is_empty()) {
		return;
	}
	StringName sig = StringName(String(args[0]));
	const int n = args.size() - 1;
	if (n <= 0) {
		obj->emit_signal(sig);
	} else if (n == 1) {
		obj->emit_signal(sig, args[1]);
	} else if (n == 2) {
		obj->emit_signal(sig, args[1], args[2]);
	} else if (n == 3) {
		obj->emit_signal(sig, args[1], args[2], args[3]);
	} else if (n == 4) {
		obj->emit_signal(sig, args[1], args[2], args[3], args[4]);
	} else {
		Array tail;
		for (int i = 1; i < args.size(); i++) {
			tail.push_back(args[i]);
		}
		obj->emit_signal(sig, tail);
	}
}

Vector2 read_vec2_args(const Array &args) {
	if (args.size() == 1 && args[0].get_type() == Variant::VECTOR2) {
		return args[0];
	}
	if (args.size() >= 2) {
		return Vector2((float)args[0], (float)args[1]);
	}
	return Vector2();
}

} // namespace

bool VGGodotOwnerBuiltins::try_call(VisualGasicInstance *instance, const String &p_method, const Array &p_args, bool &r_handled, Variant &r_ret) {
	r_handled = false;
	r_ret = Variant();
	if (!instance) {
		return false;
	}

	const CharString _utf8 = p_method.to_lower().utf8();
	const char *m = _utf8.get_data() ? _utf8.get_data() : "";
#define M(lit) (std::strcmp(m, lit) == 0)

	// ── Engine / Input (no owner node required) ──
	Node *node_early = owner_node(instance);
	if (M("getdeltatime") || M("get_delta_time")) {
		r_handled = true;
		if (node_early) {
			r_ret = node_early->get_process_delta_time();
		} else {
			r_ret = 0.0;
		}
		return true;
	}
	if (M("getphysicsdeltatime") || M("get_physics_delta_time")) {
		r_handled = true;
		if (node_early) {
			r_ret = node_early->get_physics_process_delta_time();
		} else if (Engine::get_singleton()) {
			double tps = Engine::get_singleton()->get_physics_ticks_per_second();
			r_ret = tps > 0.0 ? (1.0 / tps) : 0.0;
		} else {
			r_ret = 0.0;
		}
		return true;
	}
	if (M("getfps")) {
		r_handled = true;
		r_ret = Engine::get_singleton() ? (int64_t)Engine::get_singleton()->get_frames_per_second() : (int64_t)0;
		return true;
	}
	if (M("iseditorhint") || M("is_editor_hint")) {
		r_handled = true;
		r_ret = Engine::get_singleton() ? Engine::get_singleton()->is_editor_hint() : false;
		return true;
	}
	if (M("getengineversion") || M("get_engine_version")) {
		r_handled = true;
		if (Engine::get_singleton()) {
			r_ret = Engine::get_singleton()->get_version_info();
		}
		return true;
	}
	if (M("getactionstrength") && p_args.size() >= 1) {
		r_handled = true;
		r_ret = Input::get_singleton()->get_action_strength(String(p_args[0]));
		return true;
	}
	if (M("getlastmousevelocity")) {
		r_handled = true;
		r_ret = Input::get_singleton()->get_last_mouse_velocity();
		return true;
	}
	if (M("movetoward") && p_args.size() >= 3) {
		r_handled = true;
		r_ret = Math::move_toward((float)(double)p_args[0], (float)(double)p_args[1], (float)(double)p_args[2]);
		return true;
	}
	if (M("loadscene") && p_args.size() >= 1) {
		r_handled = true;
		String path = String(p_args[0]);
		if (!path.begins_with("res://") && !path.begins_with("user://")) {
			path = "res://" + path;
		}
		r_ret = ResourceLoader::get_singleton()->load(path);
		return true;
	}

	Node *node = owner_node(instance);
	SceneTree *tree = owner_tree(instance);

	if (M("getglobalmouseposition") || M("get_global_mouse_position")) {
		r_handled = true;
		if (node && node->is_inside_tree()) {
			CanvasItem *ci = Object::cast_to<CanvasItem>(node);
			if (ci) {
				r_ret = ci->get_global_mouse_position();
			} else {
				Viewport *vp = node->get_viewport();
				r_ret = vp ? vp->get_mouse_position() : Vector2();
			}
		} else {
			r_ret = DisplayServer::get_singleton()->mouse_get_position();
		}
		return true;
	}

	if (!node) {
		return false;
	}

	// ── Scene / node tree ──
	if ((M("gettree") || M("get_tree")) && tree) {
		r_handled = true;
		r_ret = tree;
		return true;
	}
	if (M("getparent") || M("get_parent")) {
		r_handled = true;
		r_ret = node->get_parent();
		return true;
	}
	if ((M("hasnode") || M("has_node")) && p_args.size() >= 1) {
		r_handled = true;
		r_ret = node->has_node(NodePath(String(p_args[0])));
		return true;
	}
	if ((M("getnode") || M("get_node")) && p_args.size() >= 1) {
		r_handled = true;
		if (node->is_inside_tree()) {
			r_ret = node->get_node_or_null(NodePath(String(p_args[0])));
		} else {
			r_ret = Variant();
		}
		return true;
	}
	if (M("getchildren") || M("get_children")) {
		r_handled = true;
		Array out;
		TypedArray<Node> kids = node->get_children();
		for (int i = 0; i < kids.size(); i++) {
			out.push_back(kids[i]);
		}
		r_ret = out;
		return true;
	}
	if ((M("findchild") || M("find_child")) && p_args.size() >= 1) {
		r_handled = true;
		bool recursive = p_args.size() >= 2 ? (bool)p_args[1] : true;
		r_ret = node->find_child(String(p_args[0]), recursive, false);
		return true;
	}
	if ((M("getroot") || M("get_root")) && tree) {
		r_handled = true;
		r_ret = tree->get_root();
		return true;
	}
	if ((M("getcurrentscene") || M("get_current_scene")) && tree) {
		r_handled = true;
		r_ret = tree->get_current_scene();
		return true;
	}
	if ((M("reloadcurrentscene") || M("reload_current_scene")) && tree) {
		r_handled = true;
		r_ret = (int64_t)tree->reload_current_scene();
		return true;
	}

	// ── Node lifecycle ──
	if (M("removechild") || M("remove_child")) {
		if (p_args.size() >= 1) {
			r_handled = true;
			Node *child = Object::cast_to<Node>(p_args[0]);
			if (child) {
				node->remove_child(child);
			}
			return true;
		}
	}
	if (M("queuefree") || M("queue_free")) {
		r_handled = true;
		if (p_args.size() >= 1) {
			Node *target = Object::cast_to<Node>(p_args[0]);
			if (target) {
				target->queue_free();
			}
		} else {
			node->queue_free();
		}
		return true;
	}
	if (M("hide")) {
		r_handled = true;
		if (CanvasItem *ci = Object::cast_to<CanvasItem>(node)) {
			ci->hide();
		}
		return true;
	}
	if (M("show")) {
		r_handled = true;
		if (CanvasItem *ci = Object::cast_to<CanvasItem>(node)) {
			ci->show();
		}
		return true;
	}
	if (M("setprocess") || M("set_process")) {
		if (p_args.size() >= 1) {
			r_handled = true;
			node->set_process((bool)p_args[0]);
			return true;
		}
	}
	if (M("emitsignal") || M("emit_signal")) {
		if (p_args.size() >= 1) {
			r_handled = true;
			emit_on_owner(node, p_args);
			return true;
		}
	}

	// ── Node2D transform ──
	if (Node2D *n2 = Object::cast_to<Node2D>(node)) {
		if (M("getposition") || M("get_position")) {
			r_handled = true;
			r_ret = n2->get_position();
			return true;
		}
		if ((M("setposition") || M("set_position")) && p_args.size() >= 1) {
			r_handled = true;
			n2->set_position(read_vec2_args(p_args));
			return true;
		}
		if (M("getglobalposition") || M("get_global_position")) {
			r_handled = true;
			r_ret = n2->get_global_position();
			return true;
		}
		if ((M("setglobalposition") || M("set_global_position")) && p_args.size() >= 1) {
			r_handled = true;
			n2->set_global_position(read_vec2_args(p_args));
			return true;
		}
		if (M("getrotation") || M("get_rotation")) {
			r_handled = true;
			r_ret = n2->get_rotation();
			return true;
		}
		if ((M("setrotation") || M("set_rotation")) && p_args.size() >= 1) {
			r_handled = true;
			n2->set_rotation((float)(double)p_args[0]);
			return true;
		}
		if (M("getscale") || M("get_scale")) {
			r_handled = true;
			r_ret = n2->get_scale();
			return true;
		}
		if ((M("setscale") || M("set_scale")) && p_args.size() >= 1) {
			r_handled = true;
			n2->set_scale(read_vec2_args(p_args));
			return true;
		}
	}

	if (CanvasItem *ci = Object::cast_to<CanvasItem>(node)) {
		if (M("getmodulate") || M("get_modulate")) {
			r_handled = true;
			r_ret = ci->get_modulate();
			return true;
		}
		if ((M("setmodulate") || M("set_modulate")) && p_args.size() >= 1) {
			r_handled = true;
			ci->set_modulate(p_args[0]);
			return true;
		}
		if (M("isvisible") || M("is_visible")) {
			r_handled = true;
			r_ret = ci->is_visible();
			return true;
		}
		if ((M("setvisible") || M("set_visible")) && p_args.size() >= 1) {
			r_handled = true;
			ci->set_visible((bool)p_args[0]);
			return true;
		}
	}

	// ── CharacterBody2D physics (owner must be a physics body) ──
	if (CharacterBody2D *body = Object::cast_to<CharacterBody2D>(node)) {
		if (M("getvelocity") || M("get_velocity")) {
			r_handled = true;
			r_ret = body->get_velocity();
			return true;
		}
		if ((M("setvelocity") || M("set_velocity")) && p_args.size() >= 1) {
			r_handled = true;
			if (p_args[0].get_type() == Variant::VECTOR2) {
				body->set_velocity(p_args[0]);
			} else if (p_args.size() >= 2) {
				body->set_velocity(Vector2((float)p_args[0], (float)p_args[1]));
			}
			return true;
		}
		if ((M("moveandcollide") || M("move_and_collide")) && p_args.size() >= 1) {
			r_handled = true;
			Vector2 motion = p_args[0].get_type() == Variant::VECTOR2 ? (Vector2)p_args[0] : Vector2((float)p_args[0], (float)p_args[1]);
			r_ret = body->move_and_collide(motion);
			return true;
		}
		if (M("moveandslide") || M("move_and_slide")) {
			r_handled = true;
			body->move_and_slide();
			r_ret = body->is_on_floor() || body->is_on_wall() || body->is_on_ceiling();
			return true;
		}
		if (M("isonfloor") || M("is_on_floor")) {
			r_handled = true;
			r_ret = body->is_on_floor();
			return true;
		}
		if (M("isonwall") || M("is_on_wall")) {
			r_handled = true;
			r_ret = body->is_on_wall();
			return true;
		}
		if (M("isonceiling") || M("is_on_ceiling")) {
			r_handled = true;
			r_ret = body->is_on_ceiling();
			return true;
		}
	}

#undef M
	return false;
}
