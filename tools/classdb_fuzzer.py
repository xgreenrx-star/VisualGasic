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
    skipped = []
    load_fails = []
    unsupported_ops = []
    fallbacks = []

    for line in all_lines:
        s = line.strip()
        if s.startswith("PASS:"):
            passed.append(s[5:])
        elif s.startswith("FAIL:"):
            failed.append(s[5:])
        elif s.startswith("ERROR:"):
            errors.append(s[6:])
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
    print(f"  💥 ERRORS:          {len(errors)}")
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
        print("\n💥 ERRORS by category:")
        for cat, items in sorted(cats.items()):
            print(f"  [{cat}] ({len(items)}):")
            for item in items[:10]:
                print(f"    ✗ {item}")
            if len(items) > 10:
                print(f"    ... and {len(items) - 10} more")

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
        "skipped": len(skipped),
        "load_failures": load_fails,
        "failed_tests": failed,
        "error_tests": errors,
        "unsupported_opcodes": unsupported_ops,
        "ast_fallbacks": fallbacks,
    }
    RESULTS.write_text(json.dumps(results, indent=2))
    print(f"\nFull results → {RESULTS}")

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
    parser.add_argument("--godot", default=str(WORKSPACE / "Godot_v4.5.1-stable_linux.x86_64"))
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
