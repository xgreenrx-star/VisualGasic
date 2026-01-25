#include "gasic_ai_controller.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void GasicAIController::_bind_methods() {
    ClassDB::bind_method(D_METHOD("start_chase", "target", "speed", "stop_dist"), &GasicAIController::start_chase);
    ClassDB::bind_method(D_METHOD("start_wander", "speed", "radius"), &GasicAIController::start_wander);
    ClassDB::bind_method(D_METHOD("start_patrol", "points", "speed", "loop"), &GasicAIController::start_patrol);
    ClassDB::bind_method(D_METHOD("stop"), &GasicAIController::stop);
}

GasicAIController::GasicAIController() {
    mode = IDLE;
    target_id = ObjectID();
    speed = 0.0;
    stop_distance = 0.0;
    
    wander_radius = 0.0;
    wander_timer = 0.0;
    current_patrol_index = 0;
    patrol_loop = false;
}

GasicAIController::~GasicAIController() {
}

void GasicAIController::_ready() {
    if (Engine::get_singleton()->is_editor_hint()) return;
    
    Node *parent = get_parent();
    if (parent) {
        Node2D *n2d = Object::cast_to<Node2D>(parent);
        if (n2d) {
            Vector2 p = n2d->get_global_position();
            start_origin = Vector3(p.x, p.y, 0);
        } else {
            Node3D *n3d = Object::cast_to<Node3D>(parent);
            if (n3d) start_origin = n3d->get_global_position();
        }
    }
}

void GasicAIController::start_chase(Object* target, double p_speed, double p_stop_dist) {
    if (target) {
        target_id = target->get_instance_id();
        speed = p_speed;
        stop_distance = p_stop_dist;
        mode = CHASE;
        set_physics_process(true);
    }
}

void GasicAIController::start_wander(double p_speed, double p_radius) {
    speed = p_speed;
    wander_radius = p_radius;
    mode = WANDER;
    
    // Capture origin if not yet set
    _ready(); 
    
    wander_timer = 0; // Force new point immediately
    set_physics_process(true);
}

void GasicAIController::start_patrol(Array p_points, double p_speed, bool p_loop) {
    patrol_points = p_points;
    speed = p_speed;
    patrol_loop = p_loop;
    
    if (patrol_points.size() > 0) {
        mode = PATROL;
        current_patrol_index = 0;
        set_physics_process(true);
    } else {
        stop();
    }
}

void GasicAIController::stop() {
    mode = IDLE;
    set_physics_process(false);
}

void GasicAIController::_physics_process(double delta) {
    if (Engine::get_singleton()->is_editor_hint()) return;
    if (mode == IDLE) return;
    
    // Check Parent (The entity to move)
    Node *parent = get_parent();
    if (!parent) return;

    // --- WANDER LOGIC ---
    if (mode == WANDER) {
        wander_timer -= delta;
        if (wander_timer <= 0) {
            // Pick new random point within radius of origin
            double ang = UtilityFunctions::randf() * 6.283185;
            double rad = UtilityFunctions::randf() * wander_radius;
            
            // Assume 2D for simplicity in mixed context, or use parent type
            Node2D *n2d = Object::cast_to<Node2D>(parent);
            if (n2d) {
                // 2D Wander
                wander_target = Vector3(start_origin.x + cos(ang) * rad, start_origin.y + sin(ang) * rad, 0);
            } else {
                // 3D Wander (XZ plane)
                wander_target = Vector3(start_origin.x + cos(ang) * rad, start_origin.y, start_origin.z + sin(ang) * rad);
            }
            wander_timer = 2.0 + UtilityFunctions::randf() * 2.0; // 2-4 seconds
        }
        
        // Move towards wander_target
        // ... (Re-use move logic below)
    }

    // --- PATROL LOGIC ---
    if (mode == PATROL) {
        if (current_patrol_index >= patrol_points.size()) {
            if (patrol_loop && patrol_points.size() > 0) {
                current_patrol_index = 0;
            } else {
                stop();
                return;
            }
        }
        
        // Target is current point
        Variant pt = patrol_points[current_patrol_index];
        if (pt.get_type() == Variant::VECTOR2) {
             Vector2 p = pt;
             wander_target = Vector3(p.x, p.y, 0);
        } else if (pt.get_type() == Variant::VECTOR3) {
             wander_target = (Vector3)pt;
        }
    }

    // --- EXECUTE MOVEMENT ---
    
    Vector3 dest_pos;
    bool has_dest = false;
    double current_stop_dist = 0.1; // Default low
    
    if (mode == CHASE) {
        Object *target_obj = ObjectDB::get_instance(target_id);
        if (!target_obj) { stop(); return; }
        
        Node2D *dest_2d = Object::cast_to<Node2D>(target_obj);
         if (dest_2d) {
             Vector2 p = dest_2d->get_global_position();
             dest_pos = Vector3(p.x, p.y, 0);
             has_dest = true;
         } else {
             Node3D *dest_3d = Object::cast_to<Node3D>(target_obj);
             if (dest_3d) {
                 dest_pos = dest_3d->get_global_position();
                 has_dest = true;
             }
         }
         current_stop_dist = stop_distance;
    } else if (mode == WANDER || mode == PATROL) {
        dest_pos = wander_target;
        has_dest = true;
        current_stop_dist = 5.0; // Reach threshold
    }
    
    if (!has_dest) return;

    // Apply Move
    Node2D *self_2d = Object::cast_to<Node2D>(parent);
    if (self_2d) {
        Vector2 my_pos = self_2d->get_global_position();
        Vector2 target_2d = Vector2(dest_pos.x, dest_pos.y);
        double dist = my_pos.distance_to(target_2d);
        
        if (dist > current_stop_dist) {
            Vector2 dir = (target_2d - my_pos).normalized();
            CharacterBody2D *cb2d = Object::cast_to<CharacterBody2D>(self_2d);
            if (cb2d) {
                cb2d->set_velocity(dir * speed);
                cb2d->move_and_slide();
            } else {
                self_2d->set_global_position(my_pos + (dir * speed * delta));
            }
        } else {
            // Reached
             CharacterBody2D *cb2d = Object::cast_to<CharacterBody2D>(self_2d);
             if (cb2d) { cb2d->set_velocity(Vector2()); cb2d->move_and_slide(); }
             
             if (mode == PATROL) {
                 current_patrol_index++; // Advance
             }
        }
    } else {
        // 3D
        Node3D *self_3d = Object::cast_to<Node3D>(parent);
        if (self_3d) {
             Vector3 my_pos = self_3d->get_global_position();
             double dist = my_pos.distance_to(dest_pos);
             
             if (dist > current_stop_dist) {
                 Vector3 dir = (dest_pos - my_pos).normalized();
                 CharacterBody3D *cb3d = Object::cast_to<CharacterBody3D>(self_3d);
                 if (cb3d) {
                     cb3d->set_velocity(dir * speed);
                     cb3d->move_and_slide();
                 } else {
                     self_3d->set_global_position(my_pos + (dir * speed * delta));
                 }
             } else {
                  CharacterBody3D *cb3d = Object::cast_to<CharacterBody3D>(self_3d);
                  if (cb3d) { cb3d->set_velocity(Vector3()); cb3d->move_and_slide(); }
                  if (mode == PATROL) current_patrol_index++;
             }
        }
    }
}
