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
#include <godot_cpp/variant/quaternion.hpp>

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

// Index into GODOT_TYPE_CONSTRUCTORS (+1), so the VM can resolve a name once
// per call site and construct by kind afterwards.  0 = not a constructor.
enum GodotCtorKind : int8_t {
    GODOT_CTOR_NONE = 0,
    GODOT_CTOR_VECTOR2,
    GODOT_CTOR_VECTOR2I,
    GODOT_CTOR_VECTOR3,
    GODOT_CTOR_VECTOR3I,
    GODOT_CTOR_VECTOR4,
    GODOT_CTOR_VECTOR4I,
    GODOT_CTOR_RECT2,
    GODOT_CTOR_RECT2I,
    GODOT_CTOR_COLOR,
    GODOT_CTOR_TRANSFORM2D,
    GODOT_CTOR_TRANSFORM3D,
    GODOT_CTOR_BASIS,
    GODOT_CTOR_QUATERNION,
    GODOT_CTOR_PLANE,
    GODOT_CTOR_AABB,
};

// Case-insensitive name → kind.  One nocasecmp_to per table entry; no
// to_lower() temporary.
inline GodotCtorKind godot_type_constructor_kind(const String& name) {
    for (int i = 0; GODOT_TYPE_CONSTRUCTORS[i]; ++i) {
        if (name.nocasecmp_to(GODOT_TYPE_CONSTRUCTORS[i]) == 0) {
            return (GodotCtorKind)(i + 1);
        }
    }
    return GODOT_CTOR_NONE;
}

// Helper to check if a name is a known Godot type constructor (case-insensitive)
inline bool is_godot_type_constructor(const String& name) {
    return godot_type_constructor_kind(name) != GODOT_CTOR_NONE;
}

// Construct a Godot built-in by resolved kind.
// Returns Variant() (NIL) if the kind is unknown or construction fails
inline Variant construct_godot_type_by_kind(GodotCtorKind kind, const Array& args) {
    if (kind == GODOT_CTOR_VECTOR2) {
        if (args.size() == 1 && args[0].get_type() == Variant::VECTOR2I) {
            return Vector2((Vector2i)args[0]);
        }
        if (args.size() == 1 && args[0].get_type() == Variant::VECTOR2) {
            return (Vector2)args[0];
        }
        if (args.size() >= 2) return Vector2((float)args[0], (float)args[1]);
        if (args.size() == 1) return Vector2((float)args[0], (float)args[0]);
        return Vector2();
    }
    if (kind == GODOT_CTOR_VECTOR2I) {
        if (args.size() == 1 && args[0].get_type() == Variant::VECTOR2) {
            return Vector2i((Vector2)args[0]);
        }
        if (args.size() == 1 && args[0].get_type() == Variant::VECTOR2I) {
            return (Vector2i)args[0];
        }
        if (args.size() >= 2) return Vector2i((int)args[0], (int)args[1]);
        if (args.size() == 1) return Vector2i((int)args[0], (int)args[0]);
        return Vector2i();
    }
    
    if (kind == GODOT_CTOR_VECTOR3) {
        if (args.size() >= 3) return Vector3((float)args[0], (float)args[1], (float)args[2]);
        if (args.size() >= 2) return Vector3((float)args[0], (float)args[1], 0.0f);
        if (args.size() == 1) return Vector3((float)args[0], (float)args[0], (float)args[0]);
        return Vector3();
    }
    if (kind == GODOT_CTOR_VECTOR3I) {
        if (args.size() >= 3) return Vector3i((int)args[0], (int)args[1], (int)args[2]);
        if (args.size() >= 2) return Vector3i((int)args[0], (int)args[1], 0);
        if (args.size() == 1) return Vector3i((int)args[0], (int)args[0], (int)args[0]);
        return Vector3i();
    }
    
    if (kind == GODOT_CTOR_VECTOR4) {
        if (args.size() >= 4) return Vector4((float)args[0], (float)args[1], (float)args[2], (float)args[3]);
        if (args.size() >= 3) return Vector4((float)args[0], (float)args[1], (float)args[2], 0.0f);
        if (args.size() >= 2) return Vector4((float)args[0], (float)args[1], 0.0f, 0.0f);
        if (args.size() == 1) return Vector4((float)args[0], (float)args[0], (float)args[0], (float)args[0]);
        return Vector4();
    }
    if (kind == GODOT_CTOR_VECTOR4I) {
        if (args.size() >= 4) return Vector4i((int)args[0], (int)args[1], (int)args[2], (int)args[3]);
        if (args.size() >= 3) return Vector4i((int)args[0], (int)args[1], (int)args[2], 0);
        if (args.size() >= 2) return Vector4i((int)args[0], (int)args[1], 0, 0);
        if (args.size() == 1) return Vector4i((int)args[0], (int)args[0], (int)args[0], (int)args[0]);
        return Vector4i();
    }
    
    if (kind == GODOT_CTOR_RECT2) {
        if (args.size() == 2 && args[0].get_type() == Variant::VECTOR2 && args[1].get_type() == Variant::VECTOR2) {
            return Rect2((Vector2)args[0], (Vector2)args[1]);
        }
        if (args.size() >= 4) return Rect2((float)args[0], (float)args[1], (float)args[2], (float)args[3]);
        return Rect2();
    }
    if (kind == GODOT_CTOR_RECT2I) {
        if (args.size() == 2 && args[0].get_type() == Variant::VECTOR2I && args[1].get_type() == Variant::VECTOR2I) {
            return Rect2i((Vector2i)args[0], (Vector2i)args[1]);
        }
        if (args.size() >= 4) return Rect2i((int)args[0], (int)args[1], (int)args[2], (int)args[3]);
        return Rect2i();
    }
    
    if (kind == GODOT_CTOR_COLOR) {
        if (args.size() >= 4) return Color((float)args[0], (float)args[1], (float)args[2], (float)args[3]);
        if (args.size() >= 3) return Color((float)args[0], (float)args[1], (float)args[2], 1.0f);
        if (args.size() >= 1) {
            float v = (float)args[0];
            return Color(v, v, v, 1.0f);
        }
        return Color();
    }
    
    if (kind == GODOT_CTOR_TRANSFORM2D) {
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
    
    if (kind == GODOT_CTOR_TRANSFORM3D) {
        // Transform3D() — identity; Transform3D(basis, origin)
        if (args.size() == 2 && args[0].get_type() == Variant::BASIS && args[1].get_type() == Variant::VECTOR3) {
            return Transform3D((Basis)args[0], (Vector3)args[1]);
        }
        return Transform3D();
    }
    
    if (kind == GODOT_CTOR_BASIS) {
        // Basis() identity; Basis(quaternion); Basis(axis, angle); Basis(x, y, z)
        if (args.size() == 1 && args[0].get_type() == Variant::QUATERNION) {
            return Basis((Quaternion)args[0]);
        }
        if (args.size() == 2 && args[0].get_type() == Variant::VECTOR3) {
            return Basis((Vector3)args[0], (float)args[1]);
        }
        if (args.size() == 3 && args[0].get_type() == Variant::VECTOR3 && args[1].get_type() == Variant::VECTOR3 && args[2].get_type() == Variant::VECTOR3) {
            return Basis((Vector3)args[0], (Vector3)args[1], (Vector3)args[2]);
        }
        return Basis();
    }
    
    if (kind == GODOT_CTOR_QUATERNION) {
        // Quaternion() — identity; Quaternion(x, y, z, w)
        if (args.size() >= 4) return Quaternion((float)args[0], (float)args[1], (float)args[2], (float)args[3]);
        if (args.size() >= 3) return Quaternion((float)args[0], (float)args[1], (float)args[2], 1.0f);
        return Quaternion();
    }
    
    if (kind == GODOT_CTOR_PLANE) {
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
    
    if (kind == GODOT_CTOR_AABB) {
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

// Helper to construct a Godot type by name from an array of arguments
// Returns Variant() (NIL) if the type is unknown or construction fails
inline Variant construct_godot_type(const String& name, const Array& args) {
    return construct_godot_type_by_kind(godot_type_constructor_kind(name), args);
}

// Godot Dictionary keys are typed: int 0 and float 0.0 do not match.
// VG numeric values are often floats. A whole-number float shares the int key
// so Dictionary.has(0) from GDScript finds a VG write of 0.0. Non-integral
// floats stay floats. The same helper must run on lookup (get/has/erase).
inline Variant vg_dictionary_key(const Variant &key) {
    if (key.get_type() != Variant::FLOAT) {
        return key;
    }
    const double v = (double)key;
    // 2^53 is the last exact integer width of a double.
    if (!(v >= -9007199254740992.0 && v <= 9007199254740992.0)) {
        return key;
    }
    const int64_t as_int = (int64_t)v;
    if ((double)as_int != v) {
        return key;
    }
    return Variant(as_int);
}

// Dictionary.set/get/has/erase and the VB Add/Remove/Exists/Item names all
// take the key as the first argument. Indexing already normalizes keys;
// these method names must use the same key or Set/Erase create a second entry.
inline bool vg_dictionary_method_uses_key(const String &method) {
    const String m = method.to_lower();
    return m == "has" || m == "get" || m == "erase" || m == "set" ||
            m == "add" || m == "remove" || m == "exists" || m == "item";
}

// Godot rejects int/bool arithmetic and compares. VB treats True as -1 and
// False as 0. NIL add/sub/mul still propagates Nothing. NIL relational
// compares stay unresolved so a missing value is not treated as zero.
inline bool vg_vb_numeric(const Variant &v, double &out) {
    switch (v.get_type()) {
        case Variant::INT:
            out = (double)(int64_t)v;
            return true;
        case Variant::FLOAT:
            out = (double)v;
            return true;
        case Variant::BOOL:
            out = (bool)v ? -1.0 : 0.0;
            return true;
        default:
            return false;
    }
}

inline bool vg_evaluate_vb_numeric(Variant::Operator op, const Variant &a, const Variant &b, Variant &result) {
    if ((op == Variant::OP_ADD || op == Variant::OP_SUBTRACT || op == Variant::OP_MULTIPLY) &&
            (a.get_type() == Variant::NIL || b.get_type() == Variant::NIL)) {
        result = Variant();
        return true;
    }
    double da = 0.0;
    double db = 0.0;
    if (!vg_vb_numeric(a, da) || !vg_vb_numeric(b, db)) {
        return false;
    }
    switch (op) {
        case Variant::OP_EQUAL: result = (da == db); return true;
        case Variant::OP_NOT_EQUAL: result = (da != db); return true;
        case Variant::OP_LESS: result = (da < db); return true;
        case Variant::OP_LESS_EQUAL: result = (da <= db); return true;
        case Variant::OP_GREATER: result = (da > db); return true;
        case Variant::OP_GREATER_EQUAL: result = (da >= db); return true;
        case Variant::OP_ADD: result = (da + db); return true;
        case Variant::OP_SUBTRACT: result = (da - db); return true;
        case Variant::OP_MULTIPLY: result = (da * db); return true;
        case Variant::OP_DIVIDE: result = (db == 0.0 ? 0.0 : da / db); return true;
        default: return false;
    }
}

// VB `/` operands: Double division with the Error 11 zero check.  Anything
// else (Vector2/3/4, Color, Vector*i, Transform*, ...) is a Godot type, and
// `/` on those is Godot's own component-wise division — see
// vg_divide_non_scalar.  NIL is a VB scalar here (Nothing / 2 is 0).
inline bool vg_is_vb_scalar(Variant::Type t) {
    return t == Variant::NIL || t == Variant::BOOL || t == Variant::INT ||
            t == Variant::FLOAT || t == Variant::STRING;
}

// a / b through Godot's operator table when at least one operand is not a
// VB scalar.  False when Godot has no such operator (the caller then keeps
// its previous behaviour).  Shared by the AST walker and the bytecode VM so
// `Vector3(1, 2, 3) / 2` and `v / Vector3(2, 4, 3)` agree on every tier.
inline bool vg_divide_non_scalar(const Variant &a, const Variant &b, Variant &result) {
    bool valid = false;
    Variant::evaluate(Variant::OP_DIVIDE, a, b, result, valid);
    return valid;
}

#endif  // VISUAL_GASIC_GODOT_CTORS_H
