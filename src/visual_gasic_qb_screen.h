#ifndef VISUAL_GASIC_QB_SCREEN_H
#define VISUAL_GASIC_QB_SCREEN_H

#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/variant/variant.hpp>

class VisualGasicInstance;

// Scene-root type for QB SCREEN games. Narcea scaffolds often emit
// `[node name="Pong" type="QbScreen"]`. Without a registered class Godot
// fails with "Cannot get class 'QbScreen'" and Screen/PSet never attach.
// Behaviorally identical to Node2D — the framebuffer Sprite2D child is
// still created at runtime by Screen N.
class QbScreen : public godot::Node2D {
	GDCLASS(QbScreen, Node2D);

protected:
	static void _bind_methods() {}
};

// QuickBASIC framebuffer commands (SCREEN, PSET, LINE, CIRCLE, PAINT,
// GET/PUT, PLAY, INKEY$, POINT). These are engine builtins. IDE plugins
// cannot register parser keywords, and Import only adds Subs.
namespace VGQbScreen {
bool handle_statement(VisualGasicInstance *instance, const godot::String &method, const godot::Array &args, bool &r_found);
bool handle_expr(VisualGasicInstance *instance, const godot::String &method, const godot::Array &args, godot::Variant &r_ret, bool &r_handled);
void note_input(VisualGasicInstance *instance, const godot::Variant &event);
void note_console_print(VisualGasicInstance *instance, const godot::String &text, bool newline);
void present(VisualGasicInstance *instance);
void dispose(VisualGasicInstance *instance);
}

#endif
