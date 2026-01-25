#include "gasic_form.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/script.hpp>
#include <godot_cpp/classes/base_button.hpp>
#include <godot_cpp/classes/timer.hpp>
#include <godot_cpp/classes/item_list.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void GasicForm::_bind_methods() {
    // No exposed methods for now, logic happens in _ready
}

GasicForm::GasicForm() {
}

GasicForm::~GasicForm() {
}

void GasicForm::_ready() {
    if (Engine::get_singleton()->is_editor_hint()) return;
    
    // Auto-Wire Logic
    // Scan all children.
    // If we have a script attached to THIS form, we connect children signals to it.
    
    Ref<Script> script = get_script();
    if (!script.is_valid()) return;

    // Get Script Instance (Owner of the script)
    // Wait, get_script returns the Script Resource.
    // Signals need to be connected to the Object (this).
    // The ScriptInstance handles method calls on 'this'.
    // So 'this' is the target.
    // We just need to check if the method (Sub) exists on 'this' (via script).
    
    wire_events(this);

    // Call Form_Load if present
    if (has_method("Form_Load")) {
        call("Form_Load");
    }
}

void GasicForm::wire_events(Node* root) {
    TypedArray<Node> children = root->get_children();
    for(int i=0; i<children.size(); i++) {
        Node* child = Object::cast_to<Node>(children[i]);
        if (!child) continue;
        
        String name = child->get_name();
        if (name.is_empty()) continue;
        
        // Auto-Bind: Inject control as variable into BASIC scope
        set(name, child);
        
        // Define common mappings
        struct SigMap { String signal; String suffix; };
        // VB6 naming convention: Name_Signal (e.g. Command1_Click)
        
        // Determine type and relevant signals
        if (child->is_class("BaseButton")) { // Button, CheckBox, etc.
             // Click -> _Click
             String method = name + "_Click";
             if (has_method(method)) {
                 child->connect("pressed", Callable(this, method));
                 UtilityFunctions::print("GasicForm: Wired ", name, " Click event");
             }
        }
        
        if (child->is_class("LineEdit")) {
             // Change -> _Change
             String method = name + "_Change";
             // LineEdit text_changed passes a string.
             // If our SUB doesn't take args, it might fail?
             // VisualGasicInstance::call wraps args. 
             // If Sub takes no args, extra args are ignored? 
             // Let's assume standard VB6 Change takes no args usually?
             // Actually, Change event in VB6 typically fires on update.
             if (has_method(method)) {
                 // But Signal has argument (new_text).
                 // We need to ensure call handles argument mismatch gracefuly or user defines Sub Text1_Change(txt).
                 child->connect("text_changed", Callable(this, method));
                 UtilityFunctions::print("GasicForm: Wired ", name, " Change event");
             }
        }

        if (child->is_class("Timer")) {
             // Timer -> _Timer
             String method = name + "_Timer";
             if (has_method(method)) {
                 child->connect("timeout", Callable(this, method));
                 UtilityFunctions::print("GasicForm: Wired ", name, " Timer event");
             }
        }
        
        if (child->is_class("ItemList")) {
             ItemList* list = Object::cast_to<ItemList>(child);
             
             // FileListBox / DirListBox emulation by name convention
             if (name.begins_with("Dir")) {
                 Ref<DirAccess> d = DirAccess::open("res://"); // Start at root
                 if (d.is_valid()) {
                     list->clear();
                     PackedStringArray dirs = d->get_directories();
                     for(const String& dir : dirs) {
                         list->add_item(dir);
                     }
                 }
             }
             else if (name.begins_with("File")) {
                 Ref<DirAccess> d = DirAccess::open("res://"); // Start at root
                 if (d.is_valid()) {
                     list->clear();
                     PackedStringArray files = d->get_files();
                     for(const String& f : files) {
                         list->add_item(f);
                     }
                 }
             }

             // Click -> _Click (item_selected / item_activated)
             String method = name + "_Click";
             if (has_method(method)) {
                  child->connect("item_selected", Callable(this, method));
             }
        }
        
        // Recurse? VB6 forms are flat, but Godot is tree.
        // Let's recurse to find nested buttons in Panels.
        wire_events(child);
    }
}
