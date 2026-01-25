#ifndef GASIC_AI_CONTROLLER_H
#define GASIC_AI_CONTROLLER_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/character_body2d.hpp>
#include <godot_cpp/classes/character_body3d.hpp>
#include <godot_cpp/classes/object.hpp>

using namespace godot;

class GasicAIController : public Node {
    GDCLASS(GasicAIController, Node);

public:
    enum AIMode {
        IDLE,
        CHASE,
        FLEE,
        WANDER,
        PATROL
    };

private:
    AIMode mode;
    ObjectID target_id;
    double speed;
    double stop_distance;
    
    // Wander State
    Vector3 start_origin; // Used for 2D and 3D
    double wander_radius;
    Vector3 wander_target;
    double wander_timer;
    
    // Patrol State
    Array patrol_points;
    int current_patrol_index;
    bool patrol_loop;

protected:
    static void _bind_methods();

public:
    GasicAIController();
    ~GasicAIController();

    void _physics_process(double delta) override;
    void _ready() override; // To capture start pos

    void start_chase(Object* target, double p_speed, double p_stop_dist);
    void start_wander(double p_speed, double p_radius);
    void start_patrol(Array p_points, double p_speed, bool p_loop);
    void stop();
};

#endif
