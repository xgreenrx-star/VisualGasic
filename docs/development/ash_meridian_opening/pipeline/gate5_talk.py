"""Jason is Rocketbox Male Adult 04. Mouths follow the bar lines.

Mark stays Male Adult 05. Both keep their viseme shapekeys. A subdivision
round-off stays on, but the unused facial keys are dropped so the render
does not subdivide all 176 shapes every frame.
"""
import json
import math
import os
import sys

import bpy
from mathutils import Quaternion, Vector

sys.path.insert(0, "/tmp/ash-opening-gate1")
import contact_sheets as sheets
import gate2_still as g2
import gate3_motion as g3
import gate4_bar as g4
import gate6_voyage as g6

OUT = "/home/Commodore/Documents/VisualGasic/docs/development/ash_meridian_opening/renders/gate6"
TIMELINE = "/home/Commodore/Documents/VisualGasic/samples/games/ash_meridian_part1/assets/opening_cinematic/timeline.json"
ENVELOPE = "/home/Commodore/Documents/VisualGasic/samples/games/ash_meridian_part1/assets/opening_cinematic/speech-envelope.json"
FPS = 24
END = 141.35
# Full mouth-close rolls the lower lip up over the upper one. A partial seal
# meets the lips without that inversion.
SEAL = 0.4
VISEMES = (
    "AA_VI_00_Sil", "AA_VI_01_PP", "AA_VI_02_FF", "AA_VI_03_TH",
    "AA_VI_04_DD", "AA_VI_05_KK", "AA_VI_06_CH", "AA_VI_07_SS",
    "AA_VI_08_nn", "AA_VI_09_RR", "AA_VI_10_aa", "AA_VI_11_E",
    "AA_VI_12_I", "AA_VI_13_O", "AA_VI_14_U",
)
OPEN = {"AA_VI_10_aa", "AA_VI_11_E", "AA_VI_12_I", "AA_VI_13_O", "AA_VI_14_U"}


def import_rocket(folder, fbx_name, prefix):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(folder, fbx_name))
    new = [obj for obj in bpy.data.objects if obj not in before]
    arm = next(obj for obj in new if obj.type == "ARMATURE")
    mesh = next(obj for obj in new if obj.type == "MESH")
    arm.name = prefix + "Arm"
    mesh.name = prefix + "Mesh"
    images = {}
    for name in os.listdir(folder):
        low = name.lower()
        if low.endswith(".tga") and "color" in low:
            images[low] = bpy.data.images.load(os.path.join(folder, name), check_existing=True)
    body = next(image for key, image in images.items() if "body" in key)
    head = next(image for key, image in images.items() if "head" in key)
    hair = next(image for key, image in images.items() if "opacity" in key)
    for slot in mesh.material_slots:
        mat = slot.material
        if mat is None or not mat.use_nodes:
            continue
        low = mat.name.lower()
        image = body
        alpha = False
        if "head" in low:
            image = head
        if "opacity" in low:
            image = hair
            alpha = True
        bsdf = next(node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        if alpha:
            mat.blend_method = "CLIP"
            mat.shadow_method = "CLIP"
            mat.node_tree.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    return arm, mesh


def fold_legs(arm):
    sheets.fold_world(arm, "Bip01 L Thigh", -math.radians(85))
    sheets.fold_world(arm, "Bip01 R Thigh", -math.radians(85))
    bpy.context.view_layer.update()
    sheets.fold_world(arm, "Bip01 L Calf", math.radians(80))
    sheets.fold_world(arm, "Bip01 R Calf", math.radians(80))
    bpy.context.view_layer.update()


def place_head(arm, target):
    head = g2.world_head(arm, "Bip01 Head")
    arm.location = arm.location + (Vector(target) - head)
    bpy.context.view_layer.update()


def hand_span(mesh_name, side):
    mesh_obj = bpy.data.objects[mesh_name]
    group = mesh_obj.vertex_groups[f"Bip01 {side} Hand"]
    deps = bpy.context.evaluated_depsgraph_get()
    ev = mesh_obj.evaluated_get(deps)
    mesh = ev.to_mesh()
    gi = group.index
    lo = 1e9
    hi = -1e9
    for vert in mesh.vertices:
        for slot in vert.groups:
            if slot.group == gi and slot.weight > 0.5:
                z = (ev.matrix_world @ vert.co).z
                lo = min(lo, z)
                hi = max(hi, z)
                break
    ev.to_mesh_clear()
    return lo, hi


def flatten_palms(arm, mesh_name):
    """Roll each palm until the hand mesh is thinnest against the table."""
    for side in ("L", "R"):
        pb = arm.pose.bones[f"Bip01 {side} Hand"]
        pb.rotation_mode = "QUATERNION"
        base = pb.rotation_quaternion.copy()
        best = None
        for angle in (0.0, 0.7, -0.7, 1.5, -1.5, 2.4, -2.4, 3.1416):
            pb.rotation_quaternion = base @ Quaternion((1.0, 0.0, 0.0), angle)
            bpy.context.view_layer.update()
            lo, hi = hand_span(mesh_name, side)
            if lo < 0.72:
                continue
            span = hi - lo
            if best is None or span < best[0]:
                best = (span, angle, lo, hi)
        angle = 0.0 if best is None else best[1]
        pb.rotation_quaternion = base @ Quaternion((1.0, 0.0, 0.0), angle)
        bpy.context.view_layer.update()
        print("PALM", side, "angle", round(angle, 2), "span", None if best is None else round(best[0], 3))


def palms_down(arm, mesh_name):
    """Turn a palm over when the hand bone's thin axis points at the ceiling.

    On this rig the local axis nearest world up is the palm normal. Rolling
    around local X only spins a flat hand, so the flip has to be about one of
    the other two axes.
    """
    del mesh_name
    for side in ("L", "R"):
        pb = arm.pose.bones[f"Bip01 {side} Hand"]
        pb.rotation_mode = "QUATERNION"

        def axes():
            bpy.context.view_layer.update()
            world = arm.matrix_world.to_3x3()
            return [(world @ axis).normalized() for axis in (pb.x_axis, pb.y_axis, pb.z_axis)]

        current = axes()
        palm = max(range(3), key=lambda index: abs(current[index].z))
        print("PALMDIR", arm.name, side, "XYZ"[palm], round(current[palm].z, 3))
        if current[palm].z <= 0.25:
            continue
        saved = pb.rotation_quaternion.copy()
        turned = False
        for other in (0, 1, 2):
            if other == palm:
                continue
            turn = (Quaternion((1.0, 0.0, 0.0), math.pi), Quaternion((0.0, 1.0, 0.0), math.pi), Quaternion((0.0, 0.0, 1.0), math.pi))[other]
            pb.rotation_quaternion = saved @ turn
            after = axes()
            print(" TRY", arm.name, side, "XYZ"[other], round(after[palm].z, 3))
            if after[palm].z < -0.25:
                print("FLIP", arm.name, side, "around", "XYZ"[other])
                turned = True
                break
        if not turned:
            pb.rotation_quaternion = saved
            bpy.context.view_layer.update()
        report_palm(arm, side)


def report_palm(arm, side):
    """Thumb-versus-finger cross. Right-hand palm-down points this cross upward."""
    def head(name):
        return arm.matrix_world @ arm.pose.bones[name].head

    wrist = head(f"Bip01 {side} Hand")
    finger = head(f"Bip01 {side} Finger2") - wrist
    thumb = head(f"Bip01 {side} Finger0") - wrist
    facing = finger.cross(thumb)
    print("FACING", arm.name, side, "z", round(facing.z, 4))


def smooth_talking(mesh_obj):
    """Round the cage, but keep the visemes and the lip-seal shape."""
    keep = set(VISEMES) | {"Basis", "AK_25_JawOpen", "AK_27_MouthClose"}
    if mesh_obj.data.shape_keys:
        for key in list(mesh_obj.data.shape_keys.key_blocks):
            if key.name not in keep:
                mesh_obj.shape_key_remove(key)
    bpy.context.view_layer.objects.active = mesh_obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.customdata_custom_splitnormals_clear()
    bpy.ops.object.mode_set(mode="OBJECT")
    for poly in mesh_obj.data.polygons:
        poly.use_smooth = True
    # The shipped normal maps point at a Windows path and never load. Plugged
    # into the shader they crease the face into the low-poly cage.
    mesh_obj.data.use_auto_smooth = False
    for slot in mesh_obj.material_slots:
        mat = slot.material
        if mat is None or not mat.use_nodes:
            continue
        bsdf = next(node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
        for link in list(mat.node_tree.links):
            if link.to_node == bsdf and link.to_socket.name == "Normal":
                mat.node_tree.links.remove(link)
    mod = mesh_obj.modifiers.new("RoundCage", "SUBSURF")
    mod.levels = 1
    mod.render_levels = 1
    armature = next(item for item in mesh_obj.modifiers if item.type == "ARMATURE")
    while mesh_obj.modifiers.find(mod.name) > mesh_obj.modifiers.find(armature.name):
        bpy.ops.object.modifier_move_up(modifier=mod.name)


def units(text):
    table = {
        "p": "AA_VI_01_PP", "b": "AA_VI_01_PP", "m": "AA_VI_01_PP",
        "f": "AA_VI_02_FF", "v": "AA_VI_02_FF",
        "t": "AA_VI_04_DD", "d": "AA_VI_04_DD", "l": "AA_VI_04_DD",
        "n": "AA_VI_08_nn",
        "k": "AA_VI_05_KK", "g": "AA_VI_05_KK", "c": "AA_VI_05_KK", "q": "AA_VI_05_KK",
        "j": "AA_VI_06_CH",
        "s": "AA_VI_07_SS", "z": "AA_VI_07_SS", "x": "AA_VI_07_SS",
        "r": "AA_VI_09_RR",
        "a": "AA_VI_10_aa",
        "e": "AA_VI_11_E",
        "i": "AA_VI_12_I", "y": "AA_VI_12_I",
        "o": "AA_VI_13_O",
        "u": "AA_VI_14_U", "w": "AA_VI_14_U",
    }
    digraph = {"th": "AA_VI_03_TH", "sh": "AA_VI_06_CH", "ch": "AA_VI_06_CH"}
    text = text.lower()
    out = []
    i = 0
    while i < len(text):
        pair = text[i:i + 2]
        if pair in digraph:
            out.append(digraph[pair])
            i += 2
            continue
        out.append(table.get(text[i], "AA_VI_00_Sil"))
        i += 1
    return out or ["AA_VI_00_Sil"]


def key_mouth(mesh, frame, active, amount):
    blocks = mesh.data.shape_keys.key_blocks
    # The basis shape holds the lips open, so a quiet frame has to hold the
    # silence viseme at full strength or the teeth stay visible.
    closed = amount < 0.08
    jaw = 0.0 if closed else (0.35 * amount if active in OPEN else 0.08 * amount)
    for name in VISEMES:
        block = blocks.get(name)
        if block is None:
            continue
        # Silence is a parted-lip shape on this rig, so a quiet frame stays on
        # the basis and the lip-seal key does the closing.
        block.value = 0.0 if closed else (amount if name == active else 0.0)
        block.keyframe_insert("value", frame=frame)
    seal = blocks.get("AK_27_MouthClose")
    if seal is not None:
        seal.value = SEAL if closed else 0.0
        seal.keyframe_insert("value", frame=frame)
    jaw_block = blocks.get("AK_25_JawOpen")
    if jaw_block is not None:
        jaw_block.value = jaw
        jaw_block.keyframe_insert("value", frame=frame)


def lip_sync(mark_mesh, jason_mesh):
    with open(TIMELINE, encoding="utf-8") as handle:
        lines = json.load(handle)["lines"]
    with open(ENVELOPE, encoding="utf-8") as handle:
        envelopes = json.load(handle)
    mouths = {"MARK": mark_mesh, "JASON": jason_mesh}
    for mesh in mouths.values():
        key_mouth(mesh, 1, "AA_VI_00_Sil", 0.0)
        key_mouth(mesh, g4.frame_at(END), "AA_VI_00_Sil", 0.0)
    for line in lines:
        if line["speaker"] not in mouths or line["shot"] not in ("table", "warning", "choice", "gift"):
            continue
        mesh = mouths[line["speaker"]]
        shapes = units(line["text"])
        env = envelopes[line["id"]]
        samples = env["samples"]
        hz = env["hz"]
        start = line["at"]
        span = max(line["seconds"], 0.2)
        frame = g4.frame_at(start)
        end_frame = g4.frame_at(start + span)
        # An apostrophe or a space in the middle of a loud word is not a
        # pause. Hold the last real viseme until the envelope actually drops.
        held = "AA_VI_11_E"
        while frame <= end_frame:
            local = (frame - 1) / FPS - start
            amount = 0.0
            index = int(local * hz)
            if 0 <= index < len(samples):
                amount = samples[index]
            shape_index = min(len(shapes) - 1, int(max(0.0, local) / span * len(shapes)))
            active = shapes[shape_index] if amount > 0.04 else "AA_VI_00_Sil"
            if amount >= 0.08 and active != "AA_VI_00_Sil":
                held = active
            key_mouth(mesh, frame, held if amount >= 0.08 else "AA_VI_00_Sil", amount)
            frame += 2
        key_mouth(mesh, end_frame + 2, "AA_VI_00_Sil", 0.0)


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mark, mark_mesh = import_rocket(
        "/tmp/ash-opening-gate1/rocketbox/male_adult_05",
        "Male_Adult_05_facial.fbx",
        "Mark",
    )
    jason, jason_mesh = import_rocket(
        "/tmp/ash-opening-gate1/rocketbox/male_adult_04",
        "Male_Adult_04_facial.fbx",
        "Jason",
    )
    for arm in (mark, jason):
        if arm.animation_data:
            arm.animation_data_clear()
        arm.scale = (0.01, 0.01, 0.01)
        fold_legs(arm)
    mark.rotation_euler.z += math.pi
    bpy.context.view_layer.update()
    place_head(mark, (0.0, -0.78, 1.16))
    place_head(jason, (0.0, 0.74, 1.16))
    g2.pose_mark_arms(mark, mark_mesh.name, g2.TABLE_FAR + 0.12)
    g2.pose_mark_arms(
        jason, jason_mesh.name, g2.TABLE_NEAR - 0.14,
        palm_rolls=(("L", 0.0), ("R", 0.0)), pitch=0.0,
    )
    flatten_palms(jason, jason_mesh.name)
    palms_down(mark, mark_mesh.name)
    palms_down(jason, jason_mesh.name)
    smooth_talking(mark_mesh)
    smooth_talking(jason_mesh)
    g2.build_room()
    g2.build_lights_and_camera(mark, jason)
    return mark, mark_mesh, jason, jason_mesh


def bind_all(cams):
    cuts = [
        (g4.frame_at(0.0), cams["two"]),
        (g4.frame_at(15.2), cams["cards"]),
        (g4.frame_at(17.2), cams["two"]),
        (g4.frame_at(19.0), cams["mark"]),
        (g4.frame_at(24.0), cams["jason"]),
        (g4.frame_at(27.0), cams["mark"]),
        (g4.frame_at(39.0), cams["jason"]),
        (g4.frame_at(45.0), cams["mark"]),
        (g4.frame_at(50.51), cams["two"]),
        (g4.frame_at(64.51), cams["jason"]),
        (g4.frame_at(67.51), cams["mark"]),
        (g4.frame_at(82.35), cams["depart"]),
        (g4.frame_at(100.35), cams["arrive"]),
        (g4.frame_at(123.35), cams["approach"]),
    ]

    def switch(scene):
        chosen = cuts[0][1]
        for frame, cam in cuts:
            if scene.frame_current >= frame:
                chosen = cam
        scene.camera = chosen

    bpy.app.handlers.frame_change_pre.append(switch)


def main():
    g4.END = END
    mark, mark_mesh, jason, jason_mesh = build()
    lip_sync(mark_mesh, jason_mesh)
    cams = g4.cameras(mark, jason)
    cams.update(g6.build_voyage())
    os.makedirs(OUT, exist_ok=True)
    g4.OUT = OUT
    if "--stills" in sys.argv:
        scene = g4.render_settings(16)
        scene.render.image_settings.file_format = "PNG"
        shots = (
            ("two", 1, "two"),
            ("mark", g4.frame_at(9.0), "mark"),
            ("jason", g4.frame_at(9.0), "jason"),
            ("depart", g4.frame_at(90.0), "depart"),
            ("arrive", g4.frame_at(110.0), "arrive"),
            ("approach", g4.frame_at(136.0), "approach"),
        )
        wanted = {arg for arg in sys.argv if arg in ("two", "mark", "jason", "depart", "arrive", "approach")}
        for name, frame, camera in shots:
            if wanted and name not in wanted:
                continue
            scene.frame_set(frame)
            scene.camera = cams[camera]
            path = os.path.join(OUT, f"preview_{name}.png")
            scene.render.filepath = path
            bpy.ops.render.render(write_still=True)
            print("STILL", path)
        return
    g3.bake(mark)
    g3.bake(jason)
    for frame in (1, g4.frame_at(END)):
        g3.key_all(mark, frame)
        g3.key_all(jason, frame)
    g4.nod_lines(mark, jason)
    bind_all(cams)
    scene = g4.render_settings(8)
    scene.frame_start = 1
    scene.frame_end = g4.frame_at(END) - 1
    scene.render.image_settings.file_format = "FFMPEG"
    scene.render.ffmpeg.format = "MPEG4"
    scene.render.ffmpeg.codec = "H264"
    scene.render.ffmpeg.constant_rate_factor = "MEDIUM"
    scene.render.ffmpeg.audio_codec = "NONE"
    path = os.path.join(OUT, "ash_meridian_opening_v05.mp4")
    scene.render.filepath = path
    bpy.ops.render.render(animation=True)
    print("WROTE", path)


if __name__ == "__main__":
    main()
