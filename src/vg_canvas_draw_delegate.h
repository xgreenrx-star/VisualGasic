#ifndef VG_CANVAS_DRAW_DELEGATE_H
#define VG_CANVAS_DRAW_DELEGATE_H

#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/templates/vector.hpp>

class VisualGasicInstance;

namespace godot {

/// For .vg on a VGASIC helper Node under a Node2D root: Godot only sends
/// NOTIFICATION_DRAW to CanvasItem owners. This child forwards _Draw to those scripts.
class VGCanvasDrawDelegate : public Node2D {
	GDCLASS(VGCanvasDrawDelegate, Node2D)

protected:
	static void _bind_methods();

public:
	static constexpr const char *NODE_NAME = "__VGDrawDelegate";

	static VGCanvasDrawDelegate *ensure_on(CanvasItem *p_canvas);
	void add_instance(VisualGasicInstance *p_instance);
	void remove_instance(VisualGasicInstance *p_instance);
	void _draw() override;

private:
	Vector<VisualGasicInstance *> _instances;
};

} // namespace godot

#endif
