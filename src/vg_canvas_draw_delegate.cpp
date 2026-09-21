#include "vg_canvas_draw_delegate.h"
#include "visual_gasic_instance.h"

using namespace godot;

void VGCanvasDrawDelegate::_bind_methods() {}

VGCanvasDrawDelegate *VGCanvasDrawDelegate::ensure_on(CanvasItem *p_canvas) {
	Node *host = Object::cast_to<Node>(p_canvas);
	if (!host) {
		return nullptr;
	}
	Node *existing = host->get_node_or_null(NodePath(NODE_NAME));
	if (existing) {
		return Object::cast_to<VGCanvasDrawDelegate>(existing);
	}
	VGCanvasDrawDelegate *del = memnew(VGCanvasDrawDelegate);
	del->set_name(StringName(NODE_NAME));
	del->set_z_index(-4096);
	host->add_child(del);
	return del;
}

void VGCanvasDrawDelegate::add_instance(VisualGasicInstance *p_instance) {
	if (!p_instance) {
		return;
	}
	for (int i = 0; i < _instances.size(); i++) {
		if (_instances[i] == p_instance) {
			return;
		}
	}
	_instances.push_back(p_instance);
	queue_redraw();
}

void VGCanvasDrawDelegate::remove_instance(VisualGasicInstance *p_instance) {
	for (int i = 0; i < _instances.size(); i++) {
		if (_instances[i] == p_instance) {
			_instances.remove_at(i);
			break;
		}
	}
}

void VGCanvasDrawDelegate::_draw() {
	for (int i = 0; i < _instances.size(); i++) {
		VisualGasicInstance *inst = _instances[i];
		if (inst) {
			inst->run_canvas_draw_handlers();
		}
	}
}
