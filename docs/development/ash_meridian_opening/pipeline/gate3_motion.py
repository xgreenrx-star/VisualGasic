"""Gate 3 hold. Same seated pose as the still, with a small nod on each line.

Eight seconds, 960x540, 24 fps. Line 01 (Mark) at 2s, line 02 (Jason) at 6s.
Hands stay where the still planted them.
"""
import os
import sys

import bpy
from mathutils import Quaternion

sys.path.insert(0, "/tmp/ash-opening-gate1")
import contact_sheets as sheets
import gate2_still as g2

OUT = "/home/Commodore/Documents/VisualGasic/docs/development/ash_meridian_opening/renders/gate3"
FPS = 24
FRAMES = 8 * FPS


def build():
    sheets.load_snow()
    sheets.hide_junk()
    sheets.sit_snow()
    jason = bpy.data.objects["RIG-Snow"]
    jason.pose.bones["FK-Head"].rotation_euler = (0.12, 0.0, 0.0)
    bpy.context.view_layer.update()
    g2.drop_review_props()
    g2.import_mark()
    mark = bpy.data.objects["Bip01"]
    if mark.animation_data:
        mark.animation_data_clear()
    sheets.sit_rocket()
    g2.drop_review_props()
    mark.scale = (0.01, 0.01, 0.01)
    mark.rotation_euler.z += 3.14159265
    bpy.context.view_layer.update()
    head = g2.world_head(mark, "Bip01 Head")
    mark.location = mark.location + (g2.Vector((0.0, -0.78, 1.16)) - head)
    bpy.context.view_layer.update()
    g2.pose_mark_arms(mark)
    g2.shift_wrists(
        jason,
        ["IK-MSTR-Wrist.L", "IK-MSTR-Wrist.R"],
        g2.Vector((0.0, g2.TABLE_NEAR, g2.TABLE_TOP + 0.02)),
    )
    sheets.hide_junk()
    g2.build_room()
    g2.build_lights_and_camera(mark, jason)
    return mark, jason


def bake(arm):
    """Write the visual pose into the keyable channels before it is keyed."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for bone in arm.data.bones:
        bone.select = True
    bpy.ops.pose.visual_transform_apply()
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()


def key_all(arm, frame):
    for pb in arm.pose.bones:
        pb.keyframe_insert("location", frame=frame)
        if pb.rotation_mode == "QUATERNION":
            pb.keyframe_insert("rotation_quaternion", frame=frame)
        else:
            pb.keyframe_insert("rotation_euler", frame=frame)


def nod(arm, bone, frame, delta):
    pb = arm.pose.bones[bone]
    if pb.rotation_mode == "QUATERNION":
        pb.rotation_quaternion = pb.rotation_quaternion @ Quaternion((1.0, 0.0, 0.0), delta)
        pb.keyframe_insert("rotation_quaternion", frame=frame)
    else:
        pb.rotation_euler.x += delta
        pb.keyframe_insert("rotation_euler", frame=frame)


def main():
    mark, jason = build()
    before = g2.hand_cloud("L")
    bake(mark)
    after = g2.hand_cloud("L")
    print("BAKE DRIFT", round((after - before).length, 4))
    key_all(mark, 1)
    key_all(jason, 1)
    # Mark's line starts at 2s. A short nod, then back to the hold.
    nod(mark, "Bip01 Head", 64, 0.07)
    key_all(mark, 96)
    # Jason answers at 6s.
    nod(jason, "FK-Head", 158, 0.06)
    key_all(jason, 180)
    key_all(mark, FRAMES)
    key_all(jason, FRAMES)
    bpy.context.scene.frame_set(120)
    bpy.context.view_layer.update()
    held = g2.hand_cloud("L")
    print("HOLD", tuple(round(c, 3) for c in held), "drift", round((held - before).length, 4))
    table = bpy.data.objects["TableTop"]
    print("TABLE", tuple(round(c, 3) for c in table.dimensions), "at", tuple(round(c, 3) for c in table.location))
    if "--check" in sys.argv:
        return
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 960
    scene.render.resolution_y = 540
    scene.render.resolution_percentage = 100
    scene.render.fps = FPS
    scene.frame_start = 1
    scene.frame_end = FRAMES
    scene.eevee.taa_render_samples = 8
    scene.eevee.use_bloom = True
    scene.eevee.bloom_intensity = 0.035
    scene.eevee.bloom_threshold = 0.85
    scene.view_settings.view_transform = "Filmic"
    scene.view_settings.look = "Medium Contrast"
    scene.render.image_settings.file_format = "FFMPEG"
    scene.render.ffmpeg.format = "MPEG4"
    scene.render.ffmpeg.codec = "H264"
    scene.render.ffmpeg.constant_rate_factor = "MEDIUM"
    scene.render.ffmpeg.audio_codec = "NONE"
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "ash_meridian_opening_poker_motion_v01.mp4")
    scene.render.filepath = path
    bpy.ops.render.render(animation=True)
    print("WROTE", path)


if __name__ == "__main__":
    main()
