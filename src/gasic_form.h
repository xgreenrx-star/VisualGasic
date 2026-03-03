#ifndef GASIC_FORM_H
#define GASIC_FORM_H

#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/button.hpp>
#include <godot_cpp/classes/line_edit.hpp>
#include <godot_cpp/classes/text_edit.hpp>
#include <godot_cpp/classes/check_box.hpp>
#include <godot_cpp/classes/check_button.hpp>
#include <godot_cpp/classes/option_button.hpp>
#include <godot_cpp/classes/spin_box.hpp>
#include <godot_cpp/classes/h_slider.hpp>
#include <godot_cpp/classes/v_slider.hpp>
#include <godot_cpp/classes/h_scroll_bar.hpp>
#include <godot_cpp/classes/v_scroll_bar.hpp>
#include <godot_cpp/classes/progress_bar.hpp>
#include <godot_cpp/classes/tree.hpp>
#include <godot_cpp/classes/rich_text_label.hpp>
#include <godot_cpp/classes/tab_container.hpp>
#include <godot_cpp/classes/label.hpp>
#include <godot_cpp/classes/script.hpp>
#include <godot_cpp/classes/input_event.hpp>

using namespace godot;

class GasicForm : public Control {
    GDCLASS(GasicForm, Control);

protected:
    static void _bind_methods();

public:
    GasicForm();
    ~GasicForm();

    void _ready() override;
    
private:
    void wire_events(Node* node);
    void _on_control_gui_input(const Ref<InputEvent> &p_event, Node *p_control);
};

#endif
