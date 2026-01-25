#ifndef GASIC_FORM_H
#define GASIC_FORM_H

#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/button.hpp>
#include <godot_cpp/classes/line_edit.hpp>
#include <godot_cpp/classes/check_box.hpp>
#include <godot_cpp/classes/label.hpp>
#include <godot_cpp/classes/script.hpp>

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
};

#endif
