#ifndef VISUAL_GASIC_GODOT_CTORS_H
#define VISUAL_GASIC_GODOT_CTORS_H

// Shared list of Godot built-in type constructors recognized by both
// the compiler (OP_NEW_OBJECT emission) and the VM/AST evaluators.
//
// Used by:
// - src/visual_gasic_compiler.cpp (line ~9056, BINARY_OP phase 5)
// - src/visual_gasic_instance_bytecode_vm.cpp (OP_NEW_OBJECT handler fallback)
// - src/visual_gasic_instance_evaluate.inc (AST tree-walk evaluator)
// - src/visual_gasic_expression_evaluator.cpp (expression evaluator)

#include <godot_cpp/variant/variant.hpp>

// Godot built-in types that can be constructed via type-constructor syntax
// (e.g., Vector2(x, y), Rect2i(x, y, w, h), Color(r, g, b, a))
static const char* GODOT_TYPE_CONSTRUCTORS[] = {
    "vector2",
    "vector2i",
    "vector3",
    "vector3i",
    "vector4",
    "vector4i",
    "rect2",
    "rect2i",
    "color",
    "transform2d",
    "transform3d",
    "basis",
    "quaternion",
    "plane",
    "aabb",
    nullptr  // sentinel
};

// Helper to check if a name is a known Godot type constructor (case-insensitive)
inline bool is_godot_type_constructor(const String& name) {
    String name_lower = name.to_lower();
    for (int i = 0; GODOT_TYPE_CONSTRUCTORS[i]; ++i) {
        if (name_lower == GODOT_TYPE_CONSTRUCTORS[i]) {
            return true;
        }
    }
    return false;
}

// Helper to construct a Godot type by name from an array of arguments
// Returns Variant() (NIL) if the type is unknown or construction fails
inline Variant construct_godot_type(const String& name, const Array& args) {
    String name_lower = name.to_lower();
    
    if (name_lower == "vector2") {
        if (args.size() >= 2) return Vector2((float)args[0], (float)args[1]);
        if (args.size() == 1) return Vector2((float)args[0], (float)args[0]);
        return Vector2();
    }
    if (name_lower == "vector2i") {
        if (args.size() >= 2) return Vector2i((int)args[0], (int)args[1]);
        if (args.size() == 1) return Vector2i((int)args[0], (int)args[0]);
        return Vector2i();
    }
    
    if (name_lower == "vector3") {
        if (args.size() >= 3) return Vector3((float)args[0], (float)args[1], (float)args[2]);
        if (args.size() >= 2) return Vector3((float)args[0], (float)args[1], 0.0f);
        if (args.size() == 1) return Vector3((float)args[0], (float)args[0], (float)args[0]);
        return Vector3();
    }
    if (name_lower == "vector3i") {
        if (args.size() >= 3) return Vector3i((int)args[0], (int)args[1], (int)args[2]);
        if (args.size() >= 2) return Vector3i((int)args[0], (int)args[1], 0);
        if (args.size() == 1) return Vector3i((int)args[0], (int)args[0], (int)args[0]);
        return Vector3i();
    }
    
    if (name_lower == "vector4") {
        if (args.size() >= 4) return Vector4((float)args[0], (float)args[1], (float)args[2], (float)args[3]);
        if (args.size() >= 3) return Vector4((float)args[0], (float)args[1], (float)args[2], 0.0f);
        if (args.size() >= 2) return Vector4((float)args[0], (float)args[1], 0.0f, 0.0f);
        if (args.size() == 1) return Vector4((float)args[0], (float)args[0], (float)args[0], (float)args[0]);
        return Vector4();
    }
    if (name_lower == "vector4i") {
        if (args.size() >= 4) return Vector4i((int)args[0], (int)args[1], (int)args[2], (int)args[3]);
        if (args.size() >= 3) return Vector4i((int)args[0], (int)args[1], (int)args[2], 0);
        if (args.size() >= 2) return Vector4i((int)args[0], (int)args[1], 0, 0);
        if (args.size() == 1) return Vector4i((int)args[0], (int)args[0], (int)args[0], (int)args[0]);
        return Vector4i();
    }
    
    if (name_lower == "rect2") {
        if (args.size() >= 4) return Rect2((float)args[0], (float)args[1], (float)args[2], (float)args[3]);
        if (args.size() >= 2) {
            Vector2 pos((float)args[0], (float)args[1]);
            Vector2 size = args.size() >= 4 ? Vector2((float)args[2], (float)args[3]) : Vector2();
            return Rect2(pos, size);
        }
        return Rect2();
    }
    if (name_lower == "rect2i") {
        if (args.size() >= 4) return Rect2i((int)args[0], (int)args[1], (int)args[2], (int)args[3]);
        if (args.size() >= 2) {
            Vector2i pos((int)args[0], (int)args[1]);
            Vector2i size = args.size() >= 4 ? Vector2i((int)args[2], (int)args[3]) : Vector2i();
            return Rect2i(pos, size);
        }
        return Rect2i();
    }
    
    if (name_lower == "color") {
        if (args.size() >= 4) return Color((float)args[0], (float)args[1], (float)args[2], (float)args[3]);
        if (args.size() >= 3) return Color((float)args[0], (float)args[1], (float)args[2], 1.0f);
        if (args.size() >= 1) {
            float v = (float)args[0];
            return Color(v, v, v, 1.0f);
        }
        return Color();
    }
    
    if (name_lower == "transform2d") {
        // Transform2D() — default; Transform2D(rotation, position)
        if (args.size() >= 2) {
            float rot = (float)args[0];
            Vector2 pos((float)args[1], args.size() >= 3 ? (float)args[2] : 0.0f);
            Transform2D t;
            t.set_rotation(rot);
            t.set_origin(pos);
            return t;
        }
        return Transform2D();
    }
    
    if (name_lower == "transform3d") {
        // Transform3D() — identity; Transform3D(basis, origin)
        if (args.size() >= 3) {
            // Assume basis params are 9 floats for now; simplified
            // Real usage: typically Transform3D() with no args
            return Transform3D();
        }
        return Transform3D();
    }
    
    if (name_lower == "basis") {
        // Basis() — identity; Basis(x, y, z) axes
        if (args.size() >= 3) {
            Vector3 x((float)args[0], args.size() > 3 ? (float)args[3] : 0.0f, args.size() > 6 ? (float)args[6] : 0.0f);
            Vector3 y((float)args[1], args.size() > 4 ? (float)args[4] : 0.0f, args.size() > 7 ? (float)args[7] : 0.0f);
            Vector3 z((float)args[2], args.size() > 5 ? (float)args[5] : 0.0f, args.size() > 8 ? (float)args[8] : 0.0f);
            return Basis(x, y, z);
        }
        return Basis();
    }
    
    if (name_lower == "quaternion") {
        // Quaternion() — identity; Quaternion(x, y, z, w)
        if (args.size() >= 4) return Quaternion((float)args[0], (float)args[1], (float)args[2], (float)args[3]);
        if (args.size() >= 3) return Quaternion((float)args[0], (float)args[1], (float)args[2], 1.0f);
        return Quaternion();
    }
    
    if (name_lower == "plane") {
        // Plane() — at origin; Plane(normal, d) or Plane(a, b, c, d)
        if (args.size() >= 4) return Plane((float)args[0], (float)args[1], (float)args[2], (float)args[3]);
        if (args.size() >= 2) {
            // Assume Vector3 normal + distance
            Vector3 normal((float)args[0], args.size() > 1 ? (float)args[1] : 0.0f, args.size() > 2 ? (float)args[2] : 0.0f);
            float d = (float)args[args.size() >= 3 ? 3 : 1];
            return Plane(normal, d);
        }
        return Plane();
    }
    
    if (name_lower == "aabb") {
        // AABB() — at origin; AABB(position, size)
        if (args.size() >= 4) {
            Vector3 pos((float)args[0], (float)args[1], (float)args[2]);
            Vector3 size((float)args[3], args.size() > 4 ? (float)args[4] : 0.0f, args.size() > 5 ? (float)args[5] : 0.0f);
            return AABB(pos, size);
        }
        if (args.size() >= 2) {
            Vector3 pos((float)args[0], args.size() > 1 ? (float)args[1] : 0.0f, args.size() > 2 ? (float)args[2] : 0.0f);
            Vector3 size((float)args[3], args.size() > 4 ? (float)args[4] : 0.0f, args.size() > 5 ? (float)args[5] : 0.0f);
            return AABB(pos, size);
        }
        return AABB();
    }
    
    // Unknown type
    return Variant();
}

#endif  // VISUAL_GASIC_GODOT_CTORS_H
