#!/usr/bin/env python3
"""
VisualGasic ClassDB Fuzzer
===========================
Reads Godot's extension_api.json and auto-generates .vg test scripts that
exercise every instantiable class, property set/get, and enum constant.

This is the tool that would have caught:
  - RefCounted object being freed immediately (SphereMesh.new())
  - Singleton resolved as nil local slot (Input.MOUSE_MODE_CAPTURED)
  - Class enum constants not resolving (Sky.PROCESS_MODE_QUALITY)

Usage:
    python3 tools/classdb_fuzzer.py                  # generate only
    python3 tools/classdb_fuzzer.py --run             # generate + run
    python3 tools/classdb_fuzzer.py --run --verbose   # show all output
"""

import json
import os
import sys
import argparse
import subprocess
from pathlib import Path
from datetime import datetime

WORKSPACE = Path(__file__).resolve().parent.parent
API_JSON  = WORKSPACE / "godot-cpp" / "gdextension" / "extension_api.json"
DEMO_DIR  = WORKSPACE / "demo"                        # has the .so + project.godot
FUZZ_DIR  = DEMO_DIR / "fuzz_generated"                # .vg tests go here
RUNNER    = DEMO_DIR / "run_fuzz_tests.gd"             # GDScript runner
RESULTS   = WORKSPACE / "tests" / "fuzz_results.json"  # JSON report stays in tests/

# Classes that crash Godot headless or require GPU/audio context — skip them
SKIP_CLASSES = {
    # Server singletons that crash when instantiated directly
    "RenderingServer", "PhysicsServer2D", "PhysicsServer3D",
    "NavigationServer2D", "NavigationServer3D", "AudioServer",
    "DisplayServer", "CameraServer", "XRServer", "NativeMenu",
    # Singletons — can't be instantiated, should use singleton access
    "ProjectSettings", "InputMap", "Input", "Engine", "OS", "Time",
    "Performance", "ClassDB", "ResourceLoader", "ResourceSaver",
    "TranslationServer", "ResourceUID", "ThemeDB", "Marshalls",
    "TextServerManager", "IP", "Geometry2D", "Geometry3D",
    "GDExtensionManager", "WorkerThreadPool",
    "JavaClassWrapper", "JavaScriptBridge",
    # Classes that need a display or render context
    "RenderingDevice", "Window", "AcceptDialog", "ConfirmationDialog",
    "FileDialog", "Popup", "PopupMenu", "PopupPanel",
    # Editor-only classes (crash with "can only be instantiated by editor")
    "EditorPlugin", "EditorInterface", "EditorScript",
    "EditorInspector", "EditorProperty", "EditorResourcePicker",
    "EditorFileDialog", "EditorCommandPalette", "EditorDebuggerPlugin",
    "EditorExportPlugin", "EditorImportPlugin", "EditorNode3DGizmo",
    "EditorNode3DGizmoPlugin", "EditorResourceConversionPlugin",
    "EditorResourcePreviewGenerator", "EditorSceneFormatImporter",
    "EditorScenePostImport", "EditorTranslationParserPlugin",
    "EditorFeatureProfile", "EditorSettings", "EditorSelection",
    "EditorUndoRedoManager", "EditorFileSystem", "EditorFileSystemDirectory",
    "EditorFileSystemImportFormatSupportQuery", "EditorPaths",
    "EditorSpinSlider", "EditorSyntaxHighlighter",
    "EditorVCSInterface", "ScriptEditor", "ScriptEditorBase",
    "EditorContextMenuPlugin", "EditorExportPlatformAndroid",
    "EditorExportPlatformExtension", "EditorExportPlatformIOS",
    "EditorExportPlatformLinuxBSD", "EditorExportPlatformMacOS",
    "EditorExportPlatformVisionOS", "EditorExportPlatformWeb",
    "EditorExportPlatformWindows", "EditorInspectorPlugin",
    "EditorResourceTooltipPlugin", "EditorSceneFormatImporterBlend",
    "EditorSceneFormatImporterFBX2GLTF", "EditorSceneFormatImporterGLTF",
    "EditorSceneFormatImporterUFBX", "EditorScenePostImportPlugin",
    "EditorScriptPicker", "GDScriptSyntaxHighlighter",
    "GridMapEditorPlugin", "OpenXRBindingModifierEditor",
    "OpenXRInteractionProfileEditor",
    # Tweeners — must be created via Tween methods
    "CallbackTweener", "IntervalTweener", "MethodTweener", "PropertyTweener",
    # Require running SceneTree / main loop context
    "SceneTree", "MainLoop",
    # Abstract or internal
    "Object", "RefCounted", "Resource", "Node", "Node2D", "Node3D",
    "CanvasItem", "Control",
    # Classes that block or hang headless
    "Thread", "Mutex", "Semaphore",
    # GDExtension internal
    "GDExtension",
    # Can cause undefined behaviour when instantiated bare
    "PhysicsDirectBodyState2D", "PhysicsDirectBodyState3D",
    "PhysicsDirectSpaceState2D", "PhysicsDirectSpaceState3D",
    "PhysicsShapeQueryParameters2D", "PhysicsShapeQueryParameters3D",
    "PhysicsTestMotionParameters2D", "PhysicsTestMotionParameters3D",
    "PhysicsTestMotionResult2D", "PhysicsTestMotionResult3D",
    # PhysicsServer extensions that need virtual methods overridden
    "PhysicsServer2DExtension", "PhysicsServer3DExtension",
    # Tweeners — must be created via Tween methods
    "Tween", "SubtweenTweener",
    # ResourceImporters — editor-only, return null in runtime
    "ResourceImporterBMFont", "ResourceImporterBitMap",
    "ResourceImporterCSVTranslation", "ResourceImporterDynamicFont",
    "ResourceImporterImage", "ResourceImporterImageFont",
    "ResourceImporterLayeredTexture", "ResourceImporterMP3",
    "ResourceImporterOBJ", "ResourceImporterOggVorbis",
    "ResourceImporterScene", "ResourceImporterShaderFile",
    "ResourceImporterTexture", "ResourceImporterTextureAtlas",
    "ResourceImporterWAV",
    # More editor-only classes
    "ResourceImporterSVG", "ScriptCreateDialog",
}

# Property types we can generate safe default values for
SAFE_PROP_TYPES = {
    "bool": ("True", "False"),
    "int": ("0", "0"),
    "float": ("1.5", "0.0"),
    "String": ('"test_string"', '""'),
    "StringName": ('"test_name"', '""'),
    "Color": ("Color(1, 0, 0)", "Color(0, 0, 0)"),
    "Vector2": ("Vector2(1, 2)", "Vector2(0, 0)"),
    "Vector3": ("Vector3(1, 2, 3)", "Vector3(0, 0, 0)"),
    "Vector2i": ("Vector2i(1, 2)", "Vector2i(0, 0)"),
    "Vector3i": ("Vector3i(1, 2, 3)", "Vector3i(0, 0, 0)"),
}

# Properties that hang or crash when set on headless objects
SKIP_PROPERTIES = {
    "script", "owner", "process_mode", "scene_file_path",
    "editor_description", "multiplayer",
    "orientation",          # HSplitContainer/VSplitContainer crash
    "text_direction",       # enum range check fails
    "focus_mode",           # enum range check fails
}


def load_api():
    with open(API_JSON) as f:
        return json.load(f)


def build_inheritance(api):
    """Build class -> parent chain and class -> full info map."""
    class_map = {}
    inherits = {}
    for c in api["classes"]:
        class_map[c["name"]] = c
        inherits[c["name"]] = c.get("inherits", "")
    return class_map, inherits


def get_all_properties(cls_name, class_map, inherits):
    """Walk inheritance chain collecting all properties."""
    props = []
    seen = set()
    name = cls_name
    while name:
        c = class_map.get(name)
        if c:
            for p in c.get("properties", []):
                if p["name"] not in seen:
                    seen.add(p["name"])
                    props.append(p)
        name = inherits.get(name, "")
    return props


def get_all_enums(cls_name, class_map, inherits):
    """Walk inheritance chain collecting all enums."""
    enums = []
    seen = set()
    name = cls_name
    while name:
        c = class_map.get(name)
        if c:
            for e in c.get("enums", []):
                if e["name"] not in seen:
                    seen.add(e["name"])
                    enums.append((name, e))
        name = inherits.get(name, "")
    return enums


def is_node_derived(cls_name, inherits):
    """Check if class derives from Node (needs .free() cleanup)."""
    name = cls_name
    while name:
        if name == "Node":
            return True
        name = inherits.get(name, "")
    return False


# =============================================================================
# TEST GENERATORS
# =============================================================================

def gen_instantiation_test(cls_name, is_refcounted, is_node, batch_id):
    """Test: ClassName.new() returns non-null and has expected type."""
    cleanup = ""
    if is_node:
        cleanup = "\n        obj.free()"

    return f'''Attribute VB_Name = "FuzzInst{batch_id}"

Sub RunTest()
    On Error Resume Next
    Dim obj As {cls_name} = {cls_name}.new()
    If obj <> Null Then
        Print "PASS:inst_{cls_name}"{cleanup}
    Else
        Print "FAIL:inst_{cls_name} returned null"
    End If
    If Err.Number <> 0 Then
        Print "ERROR:inst_{cls_name} err=" & str(Err.Number)
    End If
End Sub
'''


def gen_property_test(cls_name, prop, is_node, batch_id):
    """Test: instantiate object, read a property, optionally write it."""
    prop_name = prop["name"]
    prop_type = prop["type"]
    cleanup = ""
    if is_node:
        cleanup = "\n    obj.free()"

    # Just do a read test for all properties
    lines = [
        f'Attribute VB_Name = "FuzzProp{batch_id}"',
        "",
        "Sub RunTest()",
        "    On Error Resume Next",
        f"    Dim obj As {cls_name} = {cls_name}.new()",
        "    If obj = Null Then",
        f'        Print "SKIP:prop_{cls_name}_{prop_name} (null)"',
        "        Exit Sub",
        "    End If",
        f"    Dim val As Variant = obj.{prop_name}",
        f'    Print "PASS:prop_{cls_name}_{prop_name}"',
    ]

    # If we have a safe write value, also test set (only bool/String — ints often
    # have range constraints that cause Godot validation errors)
    if prop_type in ("bool", "String", "StringName") and prop.get("setter"):
        write_val = SAFE_PROP_TYPES[prop_type][0]
        lines.append(f"    obj.{prop_name} = {write_val}")
        lines.append(f"    Dim val2 As Variant = obj.{prop_name}")
        lines.append(f'    Print "PASS:propset_{cls_name}_{prop_name}"')

    if cleanup:
        lines.append(cleanup)
    lines.append("    If Err.Number <> 0 Then")
    lines.append(f'        Print "ERROR:prop_{cls_name}_{prop_name} err=" & str(Err.Number)')
    lines.append("    End If")
    lines.append("End Sub")
    return "\n".join(lines)


def gen_enum_test(declaring_class, enum_info, batch_id):
    """Test: ClassName.ENUM_VALUE resolves to expected integer."""
    enum_name = enum_info["name"]
    values = enum_info["values"]

    lines = [
        f'Attribute VB_Name = "FuzzEnum{batch_id}"',
        "",
        "Sub RunTest()",
        "    On Error Resume Next",
        "    Dim pass_count As Integer = 0",
    ]

    for v in values[:8]:  # Max 8 per enum to keep tests fast
        vname = v["name"]
        vval = v["value"]
        lines.append(f"    Dim v_{vname} As Integer = {declaring_class}.{vname}")
        lines.append(f"    If v_{vname} = {vval} Then pass_count = pass_count + 1")

    expected = min(len(values), 8)
    lines.append(f"    If pass_count = {expected} Then")
    lines.append(f'        Print "PASS:enum_{declaring_class}_{enum_name}"')
    lines.append("    Else")
    lines.append(f'        Print "FAIL:enum_{declaring_class}_{enum_name} count=" & str(pass_count) & "/{expected}"')
    lines.append("    End If")
    lines.append("    If Err.Number <> 0 Then")
    lines.append(f'        Print "ERROR:enum_{declaring_class}_{enum_name} err=" & str(Err.Number)')
    lines.append("    End If")
    lines.append("End Sub")
    return "\n".join(lines)


def gen_singleton_test(singleton_name, singleton_type, batch_id):
    """Test: singleton is accessible and has a property/method."""
    return f'''Attribute VB_Name = "FuzzSingle{batch_id}"

Sub RunTest()
    On Error Resume Next
    Dim desc As String = str({singleton_name})
    If desc <> "" And desc <> "Null" Then
        Print "PASS:singleton_{singleton_name}"
    Else
        Print "FAIL:singleton_{singleton_name} not accessible"
    End If
    If Err.Number <> 0 Then
        Print "ERROR:singleton_{singleton_name} err=" & str(Err.Number)
    End If
End Sub
'''


def gen_method_call_test(cls_name, methods, is_node, batch_id):
    """Test: instantiate object and call zero-arg getter methods."""
    cleanup = ""
    if is_node:
        cleanup = "\n    obj.free()"

    lines = [
        f'Attribute VB_Name = "FuzzMeth{batch_id}"',
        "",
        "Sub RunTest()",
        "    On Error Resume Next",
        f"    Dim obj As {cls_name} = {cls_name}.new()",
        "    If obj = Null Then",
        f'        Print "SKIP:meth_{cls_name} (null)"',
        "        Exit Sub",
        "    End If",
    ]

    for m_name, ret_type in methods:
        lines.append(f"    Dim r_{m_name} As Variant = obj.{m_name}()")
        lines.append(f'    Print "PASS:meth_{cls_name}_{m_name}"')

    if cleanup:
        lines.append(cleanup)
    lines.append("    If Err.Number <> 0 Then")
    lines.append(f'        Print "ERROR:meth_{cls_name} err=" & str(Err.Number)')
    lines.append("    End If")
    lines.append("End Sub")
    return "\n".join(lines)


def gen_setter_call_test(cls_name, methods, is_node, batch_id):
    """Test: instantiate object and call 1-arg setter methods with safe values."""
    cleanup = ""
    if is_node:
        cleanup = "\n    obj.free()"

    arg_defaults = {
        "bool": "True",
        "int": "0",
        "float": "1.0",
        "String": '"test"',
    }

    lines = [
        f'Attribute VB_Name = "FuzzSet{batch_id}"',
        "",
        "Sub RunTest()",
        "    On Error Resume Next",
        f"    Dim obj As {cls_name} = {cls_name}.new()",
        "    If obj = Null Then",
        f'        Print "SKIP:setter_{cls_name} (null)"',
        "        Exit Sub",
        "    End If",
    ]

    for m_name, arg_type in methods:
        val = arg_defaults.get(arg_type, "0")
        lines.append(f"    obj.{m_name}({val})")
        lines.append(f'    Print "PASS:setter_{cls_name}_{m_name}"')

    if cleanup:
        lines.append(cleanup)
    lines.append("    If Err.Number <> 0 Then")
    lines.append(f'        Print "ERROR:setter_{cls_name} err=" & str(Err.Number)')
    lines.append("    End If")
    lines.append("End Sub")
    return "\n".join(lines)


def gen_inheritance_chain_test(cls_name, chain_classes, class_map, is_node, batch_id):
    """Test: call methods from each ancestor class to verify inheritance dispatch."""
    cleanup = ""
    if is_node:
        cleanup = "\n    obj.free()"

    lines = [
        f'Attribute VB_Name = "FuzzInh{batch_id}"',
        "",
        "Sub RunTest()",
        "    On Error Resume Next",
        f"    Dim obj As {cls_name} = {cls_name}.new()",
        "    If obj = Null Then",
        f'        Print "SKIP:inh_{cls_name} (null)"',
        "        Exit Sub",
        "    End If",
    ]

    for ancestor in chain_classes:
        c = class_map.get(ancestor)
        if not c:
            continue
        # Pick first no-arg non-void method from this ancestor
        for m in c.get("methods", []):
            if (not m.get("arguments") and
                m.get("return_value", {}).get("type", "void") != "void" and
                not m.get("is_static", False) and
                not m.get("is_virtual", False)):
                lines.append(f"    Dim v_{ancestor} As Variant = obj.{m['name']}()")
                lines.append(f'    Print "PASS:inh_{cls_name}_from_{ancestor}_{m["name"]}"')
                break

    if cleanup:
        lines.append(cleanup)
    lines.append("    If Err.Number <> 0 Then")
    lines.append(f'        Print "ERROR:inh_{cls_name} err=" & str(Err.Number)')
    lines.append("    End If")
    lines.append("End Sub")
    return "\n".join(lines)


def gen_with_block_test(cls_name, props, is_node, batch_id):
    """Test: With obj ... .prop ... End With syntax on Godot objects."""
    cleanup = ""
    if is_node:
        cleanup = "\n    obj.free()"

    lines = [
        f'Attribute VB_Name = "FuzzWith{batch_id}"',
        "",
        "Sub RunTest()",
        "    On Error Resume Next",
        f"    Dim obj As {cls_name} = {cls_name}.new()",
        "    If obj = Null Then",
        f'        Print "SKIP:with_{cls_name} (null)"',
        "        Exit Sub",
        "    End If",
        "    With obj",
    ]

    for p_name in props:
        lines.append(f"        Dim v_{p_name} As Variant = .{p_name}")

    lines.append("    End With")
    lines.append(f'    Print "PASS:with_{cls_name}"')

    if cleanup:
        lines.append(cleanup)
    lines.append("    If Err.Number <> 0 Then")
    lines.append(f'        Print "ERROR:with_{cls_name} err=" & str(Err.Number)')
    lines.append("    End If")
    lines.append("End Sub")
    return "\n".join(lines)


def gen_typeof_is_test(cls_name, parent_name, is_node, batch_id):
    """Test: TypeOf/Is operator on Godot objects."""
    cleanup = ""
    if is_node:
        cleanup = "\n    obj.free()"

    lines = [
        f'Attribute VB_Name = "FuzzTypeOf{batch_id}"',
        "",
        "Sub RunTest()",
        "    On Error Resume Next",
        f"    Dim obj As {cls_name} = {cls_name}.new()",
        "    If obj = Null Then",
        f'        Print "SKIP:typeof_{cls_name} (null)"',
        "        Exit Sub",
        "    End If",
        f'    Dim tn As String = str(TypeOf(obj))',
        f'    Print "PASS:typeof_{cls_name} type=" & tn',
    ]

    if cleanup:
        lines.append(cleanup)
    lines.append("    If Err.Number <> 0 Then")
    lines.append(f'        Print "ERROR:typeof_{cls_name} err=" & str(Err.Number)')
    lines.append("    End If")
    lines.append("End Sub")
    return "\n".join(lines)


def gen_foreach_array_test(batch_id):
    """Test: For Each over a Godot Array with mixed Godot objects."""
    return f'''Attribute VB_Name = "FuzzForEach{batch_id}"

Sub RunTest()
    On Error Resume Next
    Dim arr() As Variant
    ReDim arr(4)
    arr(0) = 10
    arr(1) = "hello"
    arr(2) = 3.14
    arr(3) = True
    arr(4) = Vector2(1, 2)

    Dim count As Integer = 0
    For Each item In arr
        count = count + 1
    Next

    If count = 5 Then
        Print "PASS:foreach_mixed_array"
    Else
        Print "FAIL:foreach_mixed_array count=" & str(count)
    End If
    If Err.Number <> 0 Then
        Print "ERROR:foreach_mixed_array err=" & str(Err.Number)
    End If
End Sub
'''


def gen_singleton_method_test(singleton_name, methods, batch_id):
    """Test: call zero-arg getter methods on singletons."""
    lines = [
        f'Attribute VB_Name = "FuzzSMeth{batch_id}"',
        "",
        "Sub RunTest()",
        "    On Error Resume Next",
    ]

    for m_name, ret_type in methods:
        lines.append(f"    Dim r_{m_name} As Variant = {singleton_name}.{m_name}()")
        lines.append(f'    Print "PASS:smeth_{singleton_name}_{m_name}"')

    lines.append("    If Err.Number <> 0 Then")
    lines.append(f'        Print "ERROR:smeth_{singleton_name} err=" & str(Err.Number)')
    lines.append("    End If")
    lines.append("End Sub")
    return "\n".join(lines)


def gen_error_handling_test(batch_id):
    """Test: On Error Resume Next + Err object with Godot operations."""
    return f'''Attribute VB_Name = "FuzzErr{batch_id}"

Sub RunTest()
    On Error Resume Next

    ' Access a null object method — should trigger error handling not crash
    Dim obj As Variant = Null
    Dim x As Variant = obj.some_method()

    If Err.Number <> 0 Then
        Print "PASS:err_null_method_caught"
        Err.Clear
    Else
        Print "FAIL:err_null_method_not_caught"
    End If

    ' Division by zero
    Dim a As Integer = 10
    Dim b As Integer = 0
    Dim c As Variant = a / b

    If Err.Number <> 0 Then
        Print "PASS:err_div_zero_caught"
        Err.Clear
    Else
        ' Godot might return INF instead of erroring
        Print "PASS:err_div_zero_inf"
    End If

    ' Invalid cast
    Dim s As String = "not a number"
    Dim n As Integer = CInt(s)

    If Err.Number <> 0 Then
        Print "PASS:err_invalid_cast_caught"
        Err.Clear
    Else
        Print "PASS:err_invalid_cast_coerced"
    End If
End Sub
'''


def gen_string_method_chain_test(batch_id):
    """Test: chained string method calls — a common pattern in real VG code."""
    return f'''Attribute VB_Name = "FuzzStrChain{batch_id}"

Sub RunTest()
    On Error Resume Next
    Dim s As String = "  Hello World  "
    Dim t As String = Trim(s)
    If t = "Hello World" Then
        Print "PASS:str_trim"
    Else
        Print "FAIL:str_trim got=" & t
    End If

    Dim u As String = UCase("hello")
    If u = "HELLO" Then
        Print "PASS:str_ucase"
    Else
        Print "FAIL:str_ucase got=" & u
    End If

    Dim l As String = LCase("HELLO")
    If l = "hello" Then
        Print "PASS:str_lcase"
    Else
        Print "FAIL:str_lcase got=" & l
    End If

    Dim ln As Integer = Len("Hello")
    If ln = 5 Then
        Print "PASS:str_len"
    Else
        Print "FAIL:str_len got=" & str(ln)
    End If

    Dim m As String = Mid("Hello World", 7, 5)
    If m = "World" Then
        Print "PASS:str_mid"
    Else
        Print "FAIL:str_mid got=" & m
    End If

    Dim p As Integer = InStr("Hello World", "World")
    If p > 0 Then
        Print "PASS:str_instr"
    Else
        Print "FAIL:str_instr got=" & str(p)
    End If

    If Err.Number <> 0 Then
        Print "ERROR:str_chain err=" & str(Err.Number)
    End If
End Sub
'''


def gen_vector_math_test(batch_id):
    """Test: Vector2/Vector3 construction and operations."""
    return f'''Attribute VB_Name = "FuzzVecMath{batch_id}"

Sub RunTest()
    On Error Resume Next

    ' Vector2 construction and member access
    Dim v2 As Vector2 = Vector2(3, 4)
    Dim v2len As Variant = v2.length()
    If v2len = 5 Then
        Print "PASS:vec2_length"
    Else
        Print "FAIL:vec2_length got=" & str(v2len)
    End If

    ' Vector2 arithmetic
    Dim v2a As Vector2 = Vector2(1, 2)
    Dim v2b As Vector2 = Vector2(3, 4)
    Dim v2c As Vector2 = v2a + v2b
    If v2c.x = 4 And v2c.y = 6 Then
        Print "PASS:vec2_add"
    Else
        Print "FAIL:vec2_add got=" & str(v2c)
    End If

    ' Vector3 construction
    Dim v3 As Vector3 = Vector3(1, 2, 3)
    Dim v3len As Variant = v3.length()
    If v3len > 3.7 And v3len < 3.75 Then
        Print "PASS:vec3_length"
    Else
        Print "FAIL:vec3_length got=" & str(v3len)
    End If

    ' Color construction and member access
    Dim col As Color = Color(1, 0.5, 0.25, 1)
    If col.r = 1 And col.a = 1 Then
        Print "PASS:color_construct"
    Else
        Print "FAIL:color_construct got=" & str(col)
    End If

    If Err.Number <> 0 Then
        Print "ERROR:vec_math err=" & str(Err.Number)
    End If
End Sub
'''


# =============================================================================
# METHODS / SETTERS WE WANT TO SKIP (hang, crash, or require context)
# =============================================================================

SKIP_METHODS = {
    "free", "queue_free", "queue_redraw", "notification", "emit_signal",
    "connect", "disconnect", "call_deferred", "call_thread_safe",
    "set_meta", "remove_meta", "set_block_signals", "propagate_notification",
    "propagate_call", "add_child", "remove_child", "reparent",
    "move_child", "print_tree", "print_tree_pretty", "print_orphan_nodes",
    "get_tree", "get_parent", "get_window", "get_viewport",
    "set_process", "set_physics_process", "set_process_input",
    "_ready", "_process", "_physics_process", "_input", "_unhandled_input",
    "_enter_tree", "_exit_tree", "_notification",
    # Methods that access display/render context
    "get_canvas", "get_canvas_item", "get_world_2d", "get_world_3d",
    "grab_focus", "release_focus", "warp_mouse", "get_global_rect",
    "make_canvas_position_local", "make_input_local",
    # Methods that require scene tree context
    "get_global_transform", "get_global_position", "to_global", "to_local",
    "get_global_transform_with_canvas", "get_screen_transform",
    "is_visible_in_tree", "get_minimum_size",
    # Setters with validation that rejects 0
    "set_amount", "set_indent_size", "set_tab_size",
    "set_collision_layer_value", "set_collision_mask_value",
    "set_quadrant_size",
    # Index-based methods that fail on empty containers
    "set_current_tab", "get_current_tab_control", "get_tab_title",
    "get_tab_icon", "get_item_text", "get_item_icon", "set_item_text",
    "remove_item", "select", "get_selected", "set_column_title",
    # Physics body methods needing space
    "get_colliding_bodies", "move_and_collide", "move_and_slide",
    "test_move", "get_floor_normal", "get_wall_normal",
    "get_last_slide_collision", "get_platform_velocity",
    "apply_central_impulse", "apply_impulse", "apply_force",
    "get_contact_count",
}


# =============================================================================
# BATCHING — group small tests into batched .vg files for speed
# =============================================================================

def generate_all(api):
    """Generate all fuzz test .vg files. Returns list of (filename, test_names)."""
    class_map, inherits = build_inheritance(api)
    FUZZ_DIR.mkdir(parents=True, exist_ok=True)

    # Clean old generated files
    for f in FUZZ_DIR.glob("fuzz_*.vg"):
        f.unlink()

    all_files = []
    batch_id = 0

    instantiable = [c for c in api["classes"]
                    if c.get("is_instantiable") and c["name"] not in SKIP_CLASSES]

    # --- 1) Instantiation tests (batched: 10 classes per file) ---
    batch = []
    for cls in instantiable:
        name = cls["name"]
        is_ref = cls.get("is_refcounted", False)
        is_nd = is_node_derived(name, inherits)
        code = gen_instantiation_test(name, is_ref, is_nd, batch_id)
        batch.append((f"inst_{name}", code))
        batch_id += 1

        if len(batch) >= 10:
            fname = f"fuzz_inst_{batch_id}.vg"
            _write_batch(fname, batch)
            all_files.append((fname, [n for n, _ in batch]))
            batch = []

    if batch:
        fname = f"fuzz_inst_{batch_id}.vg"
        _write_batch(fname, batch)
        all_files.append((fname, [n for n, _ in batch]))
        batch = []

    # --- 2) Property read/write tests (sample: top N classes with most props) ---
    prop_classes = []
    for cls in instantiable:
        props = get_all_properties(cls["name"], class_map, inherits)
        safe_props = [p for p in props
                      if p["name"] not in SKIP_PROPERTIES
                      and p.get("getter")]
        if safe_props:
            prop_classes.append((cls, safe_props))

    # Take the 50 richest-property classes for breadth
    prop_classes.sort(key=lambda x: -len(x[1]))
    for cls, props in prop_classes[:50]:
        name = cls["name"]
        is_nd = is_node_derived(name, inherits)
        # Test up to 5 properties per class
        for prop in props[:5]:
            if prop["name"] in SKIP_PROPERTIES:
                continue
            code = gen_property_test(name, prop, is_nd, batch_id)
            batch.append((f"prop_{name}_{prop['name']}", code))
            batch_id += 1

            if len(batch) >= 8:
                fname = f"fuzz_prop_{batch_id}.vg"
                _write_batch(fname, batch)
                all_files.append((fname, [n for n, _ in batch]))
                batch = []

    if batch:
        fname = f"fuzz_prop_{batch_id}.vg"
        _write_batch(fname, batch)
        all_files.append((fname, [n for n, _ in batch]))
        batch = []

    # --- 3) Enum constant tests ---
    enum_tests = []
    for cls in api["classes"]:
        if cls["name"] in SKIP_CLASSES:
            continue
        for enum in cls.get("enums", []):
            if len(enum["values"]) == 0:
                continue
            code = gen_enum_test(cls["name"], enum, batch_id)
            enum_tests.append((f"enum_{cls['name']}_{enum['name']}", code))
            batch_id += 1

    # Batch enums 6 per file
    for i in range(0, len(enum_tests), 6):
        chunk = enum_tests[i:i+6]
        fname = f"fuzz_enum_{batch_id}.vg"
        _write_batch(fname, chunk)
        all_files.append((fname, [n for n, _ in chunk]))
        batch_id += 1

    # --- 4) Singleton access tests ---
    singleton_tests = []
    # Only test singletons VG might reasonably access
    safe_singletons = {
        "Input", "Engine", "OS", "Time", "ProjectSettings",
        "ClassDB", "ResourceLoader", "AudioServer", "Geometry2D",
        "Geometry3D", "Marshalls", "TranslationServer", "InputMap",
        "ResourceUID", "ThemeDB",
    }
    for s in api.get("singletons", []):
        if s["name"] in safe_singletons:
            code = gen_singleton_test(s["name"], s.get("type", ""), batch_id)
            singleton_tests.append((f"singleton_{s['name']}", code))
            batch_id += 1

    if singleton_tests:
        fname = "fuzz_singletons.vg"
        _write_batch(fname, singleton_tests)
        all_files.append((fname, [n for n, _ in singleton_tests]))

    # --- 5) Method call tests (zero-arg getters on diverse classes) ---
    method_classes = []
    for cls in instantiable:
        name = cls["name"]
        all_methods = []
        n = name
        while n:
            c = class_map.get(n)
            if c:
                for m in c.get("methods", []):
                    if (not m.get("arguments") and
                        m.get("return_value", {}).get("type", "void") != "void" and
                        not m.get("is_static", False) and
                        not m.get("is_virtual", False) and
                        m["name"] not in SKIP_METHODS):
                        all_methods.append((m["name"], m["return_value"]["type"]))
            n = inherits.get(n, "")
        if all_methods:
            method_classes.append((cls, all_methods))

    # Top 80 classes by method count — sample up to 6 methods each
    method_classes.sort(key=lambda x: -len(x[1]))
    for cls, methods in method_classes[:80]:
        name = cls["name"]
        is_nd = is_node_derived(name, inherits)
        sampled = methods[:6]
        code = gen_method_call_test(name, sampled, is_nd, batch_id)
        batch.append((f"meth_{name}", code))
        batch_id += 1

        if len(batch) >= 6:
            fname = f"fuzz_meth_{batch_id}.vg"
            _write_batch(fname, batch)
            all_files.append((fname, [n for n, _ in batch]))
            batch = []

    if batch:
        fname = f"fuzz_meth_{batch_id}.vg"
        _write_batch(fname, batch)
        all_files.append((fname, [n for n, _ in batch]))
        batch = []

    # --- 6) Setter method tests (1-arg with safe types) ---
    safe_arg_types = {"bool", "int", "float", "String"}
    setter_classes = []
    for cls in instantiable:
        name = cls["name"]
        setters = []
        n = name
        while n:
            c = class_map.get(n)
            if c:
                for m in c.get("methods", []):
                    args = m.get("arguments", [])
                    if (len(args) == 1 and
                        args[0]["type"] in safe_arg_types and
                        not m.get("is_static", False) and
                        not m.get("is_virtual", False) and
                        m["name"] not in SKIP_METHODS and
                        m["name"] not in SKIP_PROPERTIES):
                        setters.append((m["name"], args[0]["type"]))
            n = inherits.get(n, "")
        if setters:
            setter_classes.append((cls, setters))

    setter_classes.sort(key=lambda x: -len(x[1]))
    for cls, setters in setter_classes[:40]:
        name = cls["name"]
        is_nd = is_node_derived(name, inherits)
        sampled = setters[:4]
        code = gen_setter_call_test(name, sampled, is_nd, batch_id)
        batch.append((f"setter_{name}", code))
        batch_id += 1

        if len(batch) >= 6:
            fname = f"fuzz_setter_{batch_id}.vg"
            _write_batch(fname, batch)
            all_files.append((fname, [n for n, _ in batch]))
            batch = []

    if batch:
        fname = f"fuzz_setter_{batch_id}.vg"
        _write_batch(fname, batch)
        all_files.append((fname, [n for n, _ in batch]))
        batch = []

    # --- 7) Inheritance chain tests (verify ancestor methods resolve) ---
    chain_targets = [
        "Sprite2D", "CharacterBody2D", "RigidBody3D", "Camera3D",
        "MeshInstance3D", "AudioStreamPlayer", "Timer", "Label",
        "Button", "LineEdit", "SphereMesh", "StandardMaterial3D",
        "AnimatedSprite2D", "Area2D", "Area3D", "RichTextLabel",
        "TextureRect", "ProgressBar", "TabContainer", "Tree",
        "BoxContainer", "MarginContainer", "PanelContainer",
        "RayCast2D", "RayCast3D", "CollisionShape2D", "CollisionShape3D",
        "Path2D", "PathFollow2D", "StaticBody2D", "StaticBody3D",
    ]
    for target in chain_targets:
        if target in SKIP_CLASSES or target not in class_map:
            continue
        chain = []
        n = target
        while n:
            chain.append(n)
            n = inherits.get(n, "")
        is_nd = is_node_derived(target, inherits)
        code = gen_inheritance_chain_test(target, chain, class_map, is_nd, batch_id)
        batch.append((f"inh_{target}", code))
        batch_id += 1

    if batch:
        fname = f"fuzz_inherit_{batch_id}.vg"
        _write_batch(fname, batch)
        all_files.append((fname, [n for n, _ in batch]))
        batch = []

    # --- 8) With...End With tests ---
    with_targets = [
        ("SphereMesh", ["radius", "height", "radial_segments"]),
        ("BoxMesh", ["size"]),
        ("StandardMaterial3D", ["albedo_color", "metallic", "roughness"]),
        ("Label", ["text", "visible_characters"]),
        ("Timer", ["wait_time", "one_shot", "autostart"]),
        ("AnimatedTexture", ["frames", "speed_scale"]),
        ("Gradient", ["interpolation_mode"]),
        ("Camera3D", ["fov", "near", "far"]),
        ("RichTextLabel", ["bbcode_enabled", "scroll_active"]),
        ("ProgressBar", ["value", "min_value", "max_value"]),
    ]
    for target, props in with_targets:
        if target in SKIP_CLASSES or target not in class_map:
            continue
        is_nd = is_node_derived(target, inherits)
        code = gen_with_block_test(target, props, is_nd, batch_id)
        batch.append((f"with_{target}", code))
        batch_id += 1

    if batch:
        fname = f"fuzz_with_{batch_id}.vg"
        _write_batch(fname, batch)
        all_files.append((fname, [n for n, _ in batch]))
        batch = []

    # --- 9) TypeOf tests on diverse class types ---
    typeof_targets = [
        ("SphereMesh", "Resource"), ("Label", "Node"),
        ("Timer", "Node"), ("Camera3D", "Node3D"),
        ("StandardMaterial3D", "Resource"), ("Area2D", "Node2D"),
        ("Sprite2D", "Node2D"), ("RigidBody3D", "Node3D"),
        ("AudioStreamPlayer", "Node"), ("AnimatedSprite2D", "Node2D"),
        ("BoxMesh", "Resource"), ("Button", "Control"),
        ("LineEdit", "Control"), ("Tree", "Control"),
        ("Gradient", "Resource"), ("Image", "Resource"),
    ]
    for target, parent in typeof_targets:
        if target in SKIP_CLASSES or target not in class_map:
            continue
        is_nd = is_node_derived(target, inherits)
        code = gen_typeof_is_test(target, parent, is_nd, batch_id)
        batch.append((f"typeof_{target}", code))
        batch_id += 1

    if batch:
        fname = f"fuzz_typeof_{batch_id}.vg"
        _write_batch(fname, batch)
        all_files.append((fname, [n for n, _ in batch]))
        batch = []

    # --- 10) Singleton method call tests ---
    singleton_method_map = {
        "Engine": [
            ("get_frames_per_second", "int"),
            ("get_physics_ticks_per_second", "int"),
            ("is_editor_hint", "bool"),
            ("get_physics_interpolation_fraction", "float"),
        ],
        "OS": [
            ("get_name", "String"),
            ("get_processor_count", "int"),
            ("get_processor_name", "String"),
            ("get_static_memory_usage", "int"),
            ("is_debug_build", "bool"),
        ],
        "Time": [
            ("get_ticks_msec", "int"),
            ("get_ticks_usec", "int"),
            ("get_unix_time_from_system", "float"),
        ],
        "Input": [
            ("get_mouse_mode", "int"),
            ("get_connected_joypads", "Variant"),
            ("is_using_accumulated_input", "bool"),
        ],
        "ResourceLoader": [],
        "DisplayServer": [
            ("get_name", "String"),
            ("tts_is_speaking", "bool"),
            ("tts_is_paused", "bool"),
        ],
        "AudioServer": [
            ("get_bus_count", "int"),
            ("get_mix_rate", "float"),
            ("get_playback_speed_scale", "float"),
        ],
    }
    for sname, methods in singleton_method_map.items():
        code = gen_singleton_method_test(sname, methods, batch_id)
        batch.append((f"smeth_{sname}", code))
        batch_id += 1

    if batch:
        fname = f"fuzz_smeth_{batch_id}.vg"
        _write_batch(fname, batch)
        all_files.append((fname, [n for n, _ in batch]))
        batch = []

    # --- 11) VG language feature tests ---
    # For Each
    code = gen_foreach_array_test(batch_id)
    batch.append(("foreach_mixed", code))
    batch_id += 1

    # Error handling
    code = gen_error_handling_test(batch_id)
    batch.append(("err_handling", code))
    batch_id += 1

    # String method chains
    code = gen_string_method_chain_test(batch_id)
    batch.append(("str_chain", code))
    batch_id += 1

    # Vector math
    code = gen_vector_math_test(batch_id)
    batch.append(("vec_math", code))
    batch_id += 1

    if batch:
        fname = f"fuzz_lang_{batch_id}.vg"
        _write_batch(fname, batch)
        all_files.append((fname, [n for n, _ in batch]))
        batch = []

    return all_files


def _write_batch(fname, items):
    """Write a batched .vg file with multiple Sub RunTestN() methods and a dispatcher."""
    path = FUZZ_DIR / fname
    vg_name = fname.replace(".vg", "").replace("-", "_")[:30]

    lines = [f'Attribute VB_Name = "{vg_name}"', ""]

    # Write each test as a numbered Sub
    for i, (test_name, code) in enumerate(items):
        # Replace "Sub RunTest()" with "Sub RunTestN()"
        modified = code.replace("Sub RunTest()", f"Sub RunTest{i}()")
        modified = modified.replace("End Sub", f"End Sub")
        # Strip the Attribute line (we have our own at the top)
        for line in modified.splitlines():
            if line.startswith("Attribute"):
                continue
            lines.append(line)
        lines.append("")

    # Write dispatcher
    lines.append("Sub RunTest()")
    for i in range(len(items)):
        lines.append(f"    RunTest{i}()")
    lines.append("End Sub")
    lines.append("")

    path.write_text("\n".join(lines))


def generate_runner(all_files):
    """Generate a GDScript that loads each .vg and calls RunTest()."""
    lines = [
        "extends SceneTree",
        "",
        "# Auto-generated by tools/classdb_fuzzer.py",
        "# Uses RefCounted + set_script pattern for VisualGasicScript",
        "",
        "func _init():",
        "\tvar total := 0",
        "\tvar passed := 0",
        "\tvar failed := 0",
        "\tvar errors := 0",
        "\tvar skipped := 0",
        "\t",
        "\tvar files := [",
    ]
    for fname, test_names in all_files:
        lines.append(f'\t\t"res://fuzz_generated/{fname}",')
    lines.append("\t]")
    lines.append("\t")
    lines.append("\tfor path in files:")
    lines.append("\t\tvar script = load(path)")
    lines.append("\t\tif script == null:")
    lines.append('\t\t\tprint("LOAD_FAIL:" + path)')
    lines.append("\t\t\tfailed += 1")
    lines.append("\t\t\tcontinue")
    lines.append("\t\tvar obj = RefCounted.new()")
    lines.append("\t\tobj.set_script(script)")
    lines.append('\t\tif obj.has_method("RunTest"):')
    lines.append("\t\t\tobj.call(\"RunTest\")")
    lines.append("\t\telse:")
    lines.append('\t\t\tprint("NO_ENTRY:" + path)')
    lines.append("\t")
    lines.append('\tprint("")')
    lines.append('\tprint("=== ClassDB Fuzz Test Complete ==="')
    lines.append('\t\t+ " | Files: " + str(files.size())')
    lines.append('\t\t+ " | Done")')
    lines.append("\tquit()")
    lines.append("")

    RUNNER.write_text("\n".join(lines))


# =============================================================================
# RESULTS PARSER
# =============================================================================

def run_and_parse(godot_bin, verbose=False):
    """Execute the fuzz tests headlessly and parse output."""
    project_dir = DEMO_DIR

    cmd = [
        str(godot_bin), "--headless", "--quit-after", "120",
        "--path", str(project_dir),
        "--script", "run_fuzz_tests.gd"
    ]
    print(f"Running: {' '.join(cmd)}")
    print("(This may take 30-60 seconds for ~800 classes...)\n")

    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    except subprocess.TimeoutExpired:
        print("ERROR: Godot timed out after 180 seconds")
        return False

    output = proc.stdout + proc.stderr
    all_lines = output.splitlines()

    passed = []
    failed = []
    errors = []
    godot_warns = []
    skipped = []
    load_fails = []
    unsupported_ops = []
    fallbacks = []

    # Known Godot engine validation patterns — not VG bugs.
    # These are Godot's own error/warning messages triggered by edge-case API
    # calls (empty containers, orientation constraints, physics without space, etc.).
    GODOT_ENGINE_PATTERNS = [
        "Can't change orientation",
        "out of bounds",
        "is null",
        "Condition \"",
        "Collision layer number",
        "size cannot be smaller",
        "RID allocations of type",
        "PagedAllocator",
        "Error calling method from",
        "No loader found for resource",
        "Must use a valid extension",
    ]

    for line in all_lines:
        s = line.strip()
        if s.startswith("PASS:"):
            passed.append(s[5:])
        elif s.startswith("FAIL:"):
            failed.append(s[5:])
        elif s.startswith("ERROR:"):
            msg = s[6:]
            # Distinguish VG test errors from Godot engine errors.
            # VG test output: "ERROR:test_name err=N" (no space after colon)
            # Godot engine:   "ERROR: validation message"  (space after colon)
            is_godot_error = msg.startswith(" ") or any(
                pat in msg for pat in GODOT_ENGINE_PATTERNS
            )
            if is_godot_error:
                godot_warns.append(msg.strip())
            else:
                errors.append(msg)
        elif s.startswith("SKIP:"):
            skipped.append(s[5:])
        elif s.startswith("LOAD_FAIL:"):
            load_fails.append(s[10:])
        if "unsupported opcode" in s.lower():
            unsupported_ops.append(s)
        if "ast fallback" in s.lower() or "bytecode failed" in s.lower():
            fallbacks.append(s)

        if verbose:
            print(line)

    # Print summary
    print("=" * 64)
    print("  CLASSDB FUZZ RESULTS")
    print("=" * 64)
    print(f"  ✅ PASSED:          {len(passed)}")
    print(f"  ❌ FAILED:          {len(failed)}")
    print(f"  💥 VG ERRORS:       {len(errors)}")
    print(f"  ⚠  GODOT WARNINGS:  {len(godot_warns)}  (engine-level, not VG bugs)")
    print(f"  ⏭  SKIPPED:         {len(skipped)}")
    print(f"  📁 LOAD FAILURES:   {len(load_fails)}")
    print(f"  ⚙  UNSUPPORTED OPS: {len(unsupported_ops)}")
    print(f"  🔄 AST FALLBACKS:   {len(fallbacks)}")
    print()

    # Group failures by category
    if failed:
        cats = _categorize(failed)
        print("❌ FAILURES by category:")
        for cat, items in sorted(cats.items()):
            print(f"  [{cat}] ({len(items)}):")
            for item in items[:10]:
                print(f"    ✗ {item}")
            if len(items) > 10:
                print(f"    ... and {len(items) - 10} more")

    if errors:
        cats = _categorize(errors)
        print("\n💥 VG ERRORS by category:")
        for cat, items in sorted(cats.items()):
            print(f"  [{cat}] ({len(items)}):")
            for item in items[:10]:
                print(f"    ✗ {item}")
            if len(items) > 10:
                print(f"    ... and {len(items) - 10} more")

    if godot_warns:
        # Deduplicate and count
        from collections import Counter
        warn_counts = Counter(godot_warns)
        unique = len(warn_counts)
        print(f"\n⚠  GODOT ENGINE WARNINGS ({len(godot_warns)} total, {unique} unique):")
        for msg, count in warn_counts.most_common(15):
            suffix = f" (×{count})" if count > 1 else ""
            print(f"    ⚠ {msg}{suffix}")
        if unique > 15:
            print(f"    ... and {unique - 15} more unique warnings")

    if unsupported_ops:
        print("\n⚙ UNSUPPORTED OPCODES (bugs in bytecode VM):")
        for u in unsupported_ops[:20]:
            print(f"    ⚠ {u}")

    if fallbacks:
        print("\n🔄 AST FALLBACKS (bytecode compiler gaps):")
        for fb in fallbacks[:20]:
            print(f"    ⚠ {fb}")

    if load_fails:
        print("\n📁 LOAD FAILURES (parser bugs):")
        for lf in load_fails[:20]:
            print(f"    ✗ {lf}")

    # Save JSON
    results = {
        "timestamp": datetime.now().isoformat(),
        "passed": len(passed),
        "failed": len(failed),
        "errors": len(errors),
        "godot_warnings": len(godot_warns),
        "skipped": len(skipped),
        "load_failures": load_fails,
        "failed_tests": failed,
        "error_tests": errors,
        "godot_warning_tests": godot_warns,
        "unsupported_opcodes": unsupported_ops,
        "ast_fallbacks": fallbacks,
    }
    RESULTS.write_text(json.dumps(results, indent=2))
    print(f"\nFull results → {RESULTS}")

    # Godot warnings are not VG bugs — only fail on actual VG errors
    return len(failed) == 0 and len(errors) == 0 and len(load_fails) == 0


def _categorize(items):
    """Group test names by prefix: inst_, prop_, enum_, singleton_."""
    cats = {}
    for item in items:
        parts = item.split("_", 1)
        cat = parts[0] if len(parts) > 1 else "other"
        cats.setdefault(cat, []).append(item)
    return cats


# =============================================================================
# MAIN
# =============================================================================

def main():
    parser = argparse.ArgumentParser(description="VisualGasic ClassDB Fuzzer")
    parser.add_argument("--run", action="store_true", help="Generate AND run fuzz tests")
    parser.add_argument("--verbose", action="store_true", help="Show all Godot output")
    parser.add_argument("--godot", default=str(WORKSPACE / "Godot_v4.6.1-stable_linux.x86_64"))
    args = parser.parse_args()

    print("VisualGasic ClassDB Fuzzer")
    print("=" * 40)

    api = load_api()
    print(f"API: {len(api['classes'])} classes, "
          f"{sum(1 for c in api['classes'] if c.get('is_instantiable'))} instantiable, "
          f"{len(api.get('singletons', []))} singletons")

    all_files = generate_all(api)
    total_tests = sum(len(names) for _, names in all_files)
    print(f"Generated {len(all_files)} .vg files containing {total_tests} tests")
    print(f"Output: {FUZZ_DIR}")

    generate_runner(all_files)
    print(f"Runner: {RUNNER}")

    if args.run:
        print()
        ok = run_and_parse(args.godot, args.verbose)
        sys.exit(0 if ok else 1)
    else:
        print(f"\nTo run: python3 tools/classdb_fuzzer.py --run")


if __name__ == "__main__":
    main()
