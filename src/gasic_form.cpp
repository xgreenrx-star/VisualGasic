#include "gasic_form.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/script.hpp>
#include <godot_cpp/classes/base_button.hpp>
#include <godot_cpp/classes/timer.hpp>
#include <godot_cpp/classes/item_list.hpp>
#include <godot_cpp/classes/text_edit.hpp>
#include <godot_cpp/classes/option_button.hpp>
#include <godot_cpp/classes/spin_box.hpp>
#include <godot_cpp/classes/range.hpp>
#include <godot_cpp/classes/tree.hpp>
#include <godot_cpp/classes/rich_text_label.hpp>
#include <godot_cpp/classes/tab_container.hpp>
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
    
    Ref<Script> script = get_script();
    if (!script.is_valid()) return;
    
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
        
        // =====================================================================
        // VB6 Event Wiring — maps Godot signals to VB6-style Sub names
        // =====================================================================

        // --- BaseButton: Button, CheckBox, CheckButton, OptionButton ---
        if (child->is_class("BaseButton")) {
            // Click event (pressed signal — no args)
            String click_method = name + "_Click";
            if (has_method(click_method)) {
                child->connect("pressed", Callable(this, click_method));
                UtilityFunctions::print("GasicForm: Wired ", name, ".Click");
            }
            // MouseDown / MouseUp
            String mouse_down = name + "_MouseDown";
            if (has_method(mouse_down)) {
                child->connect("button_down", Callable(this, mouse_down));
            }
            String mouse_up = name + "_MouseUp";
            if (has_method(mouse_up)) {
                child->connect("button_up", Callable(this, mouse_up));
            }
        }

        // --- CheckBox / CheckButton toggled → Value_Change ---
        if (child->is_class("CheckBox") || child->is_class("CheckButton")) {
            String change_method = name + "_Change";
            if (has_method(change_method)) {
                child->connect("toggled", Callable(this, change_method));
                UtilityFunctions::print("GasicForm: Wired ", name, ".Change (toggled)");
            }
        }

        // --- OptionButton (ComboBox) → Click already handled above ---
        if (child->is_class("OptionButton")) {
            String change_method = name + "_Change";
            if (has_method(change_method)) {
                child->connect("item_selected", Callable(this, change_method));
                UtilityFunctions::print("GasicForm: Wired ", name, ".Change (item_selected)");
            }
        }

        // --- LineEdit (TextBox) ---
        if (child->is_class("LineEdit")) {
            String change_method = name + "_Change";
            if (has_method(change_method)) {
                child->connect("text_changed", Callable(this, change_method));
                UtilityFunctions::print("GasicForm: Wired ", name, ".Change");
            }
            String keypress_method = name + "_KeyPress";
            if (has_method(keypress_method)) {
                child->connect("text_submitted", Callable(this, keypress_method));
            }
            String gotfocus = name + "_GotFocus";
            if (has_method(gotfocus)) {
                child->connect("focus_entered", Callable(this, gotfocus));
            }
            String lostfocus = name + "_LostFocus";
            if (has_method(lostfocus)) {
                child->connect("focus_exited", Callable(this, lostfocus));
            }
        }

        // --- TextEdit (TextArea) ---
        if (child->is_class("TextEdit")) {
            String change_method = name + "_Change";
            if (has_method(change_method)) {
                child->connect("text_changed", Callable(this, change_method));
                UtilityFunctions::print("GasicForm: Wired ", name, ".Change");
            }
            String gotfocus = name + "_GotFocus";
            if (has_method(gotfocus)) {
                child->connect("focus_entered", Callable(this, gotfocus));
            }
            String lostfocus = name + "_LostFocus";
            if (has_method(lostfocus)) {
                child->connect("focus_exited", Callable(this, lostfocus));
            }
        }

        // --- Range controls: Slider, ScrollBar, SpinBox, ProgressBar ---
        if (child->is_class("Range")) {
            // Change (value_changed) — all Range subclasses
            String change_method = name + "_Change";
            if (has_method(change_method)) {
                child->connect("value_changed", Callable(this, change_method));
                UtilityFunctions::print("GasicForm: Wired ", name, ".Change (value_changed)");
            }
            // Scroll (for scrollbars specifically)
            if (child->is_class("HScrollBar") || child->is_class("VScrollBar")) {
                String scroll_method = name + "_Scroll";
                if (has_method(scroll_method)) {
                    child->connect("value_changed", Callable(this, scroll_method));
                }
            }
        }

        // --- Timer ---
        if (child->is_class("Timer")) {
            String timer_method = name + "_Timer";
            if (has_method(timer_method)) {
                child->connect("timeout", Callable(this, timer_method));
                UtilityFunctions::print("GasicForm: Wired ", name, ".Timer");
            }
        }

        // --- ItemList (ListBox) ---
        if (child->is_class("ItemList")) {
            ItemList* list = Object::cast_to<ItemList>(child);

            // FileListBox / DirListBox emulation by name convention
            if (name.begins_with("Dir")) {
                Ref<DirAccess> d = DirAccess::open("res://");
                if (d.is_valid()) {
                    list->clear();
                    PackedStringArray dirs = d->get_directories();
                    for(const String& dir : dirs) {
                        list->add_item(dir);
                    }
                }
            }
            else if (name.begins_with("File")) {
                Ref<DirAccess> d = DirAccess::open("res://");
                if (d.is_valid()) {
                    list->clear();
                    PackedStringArray files = d->get_files();
                    for(const String& f : files) {
                        list->add_item(f);
                    }
                }
            }

            // Click → item_selected
            String click_method = name + "_Click";
            if (has_method(click_method)) {
                child->connect("item_selected", Callable(this, click_method));
                UtilityFunctions::print("GasicForm: Wired ", name, ".Click (item_selected)");
            }
            // DblClick → item_activated
            String dblclick_method = name + "_DblClick";
            if (has_method(dblclick_method)) {
                child->connect("item_activated", Callable(this, dblclick_method));
            }
        }

        // --- Tree (TreeView) ---
        if (child->is_class("Tree")) {
            String click_method = name + "_Click";
            if (has_method(click_method)) {
                child->connect("item_selected", Callable(this, click_method));
                UtilityFunctions::print("GasicForm: Wired ", name, ".Click (item_selected)");
            }
            String dblclick_method = name + "_DblClick";
            if (has_method(dblclick_method)) {
                child->connect("item_activated", Callable(this, dblclick_method));
            }
            String expand_method = name + "_Expand";
            if (has_method(expand_method)) {
                child->connect("item_collapsed", Callable(this, expand_method));
            }
        }

        // --- RichTextLabel ---
        if (child->is_class("RichTextLabel")) {
            String click_method = name + "_Click";
            if (has_method(click_method)) {
                child->connect("meta_clicked", Callable(this, click_method));
            }
        }

        // --- TabContainer ---
        if (child->is_class("TabContainer")) {
            String click_method = name + "_Click";
            if (has_method(click_method)) {
                child->connect("tab_changed", Callable(this, click_method));
                UtilityFunctions::print("GasicForm: Wired ", name, ".Click (tab_changed)");
            }
        }

        // --- Universal Focus events for any Control ---
        if (child->is_class("Control")) {
            // GotFocus / LostFocus (only if not already wired above)
            String gotfocus = name + "_GotFocus";
            if (has_method(gotfocus) && !child->is_connected("focus_entered", Callable(this, gotfocus))) {
                child->connect("focus_entered", Callable(this, gotfocus));
            }
            String lostfocus = name + "_LostFocus";
            if (has_method(lostfocus) && !child->is_connected("focus_exited", Callable(this, lostfocus))) {
                child->connect("focus_exited", Callable(this, lostfocus));
            }
            // MouseEnter / MouseExit
            String mouse_enter = name + "_MouseMove";
            if (has_method(mouse_enter)) {
                child->connect("mouse_entered", Callable(this, mouse_enter));
            }
        }

        // Recurse into children (for Panels, GroupBoxes, etc.)
        wire_events(child);
    }
}
