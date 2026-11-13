"""Gate 4 bar exchange. Lines 01-15, same seated pose, four cameras.

Draft: 960x540, 24 fps, 8 samples. Hands stay planted. Each speaker nods
on their line. Departure and the ring are not in this cut.
"""
import json
import os
import sys

import bpy
from mathutils import Quaternion, Vector

sys.path.insert(0, "/tmp/ash-opening-gate1")
import gate3_motion as g3

OUT = "/home/Commodore/Documents/VisualGasic/docs/development/ash_meridian_opening/renders/gate4"
TIMELINE = "/home/Commodore/Documents/VisualGasic/samples/games/ash_meridian_part1/assets/opening_cinematic/timeline.json"
FPS = 24
END = 82.0


def frame_at(seconds):
    return int(round(seconds * FPS)) + 1


def aim(cam, target):
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()


def add_cam(name, location, target, fov):
    data = bpy.data.cameras.new(name)
    data.sensor_fit = "VERTICAL"
    data.angle = fov * 3.14159265 / 180.0
    data.clip_start = 0.02
    data.clip_end = 40
    obj = bpy.data.objects.new(name, data)
    obj.location = location
    bpy.context.scene.collection.objects.link(obj)
    aim(obj, target)
    return obj


def cameras(mark, jason):
    mark_head = g3.g2.world_head(mark, "Bip01 Head")
    jason_bone = "FK-Head" if "FK-Head" in jason.pose.bones else "Bip01 Head"
    jason_head = g3.g2.world_head(jason, jason_bone)
    two = bpy.context.scene.camera
    # Drift the master two-shot a little closer across the exchange.
    start = two.location.copy()
    start_rot = two.rotation_euler.copy()
    two.keyframe_insert("location", frame=1)
    two.keyframe_insert("rotation_euler", frame=1)
    two.location = jason_head + (start - jason_head) * 0.86
    aim(two, mark_head + Vector((0.0, 0.08, -0.02)))
    two.keyframe_insert("location", frame=frame_at(END))
    two.keyframe_insert("rotation_euler", frame=frame_at(END))
    two.location = start
    two.rotation_euler = start_rot
    bpy.context.scene.frame_set(1)
    mark_cam = add_cam(
        "MarkCam",
        mark_head + Vector((-0.38, 0.62, 0.04)),
        mark_head + Vector((0.02, 0.04, -0.01)),
        28,
    )
    jason_cam = add_cam(
        "JasonCam",
        jason_head + Vector((0.32, -0.72, 0.05)),
        jason_head + Vector((0.0, 0.04, -0.02)),
        30,
    )
    cards = add_cam(
        "CardCam",
        Vector((-0.02, 0.58, 1.05)),
        Vector((-0.12, 0.18, 0.76)),
        34,
    )
    return {"two": two, "mark": mark_cam, "jason": jason_cam, "cards": cards}


def nod_lines(mark, jason):
    with open(TIMELINE, encoding="utf-8") as handle:
        lines = json.load(handle)["lines"]
    for line in lines:
        if line["shot"] not in ("table", "warning", "choice", "gift"):
            continue
        if line["speaker"] == "MARK":
            arm, bone = mark, "Bip01 Head"
        else:
            arm = jason
            bone = "FK-Head" if "FK-Head" in jason.pose.bones else "Bip01 Head"
        start = frame_at(line["at"])
        end = frame_at(line["at"] + min(line["seconds"], 1.6))
        pb = arm.pose.bones[bone]
        if pb.rotation_mode == "QUATERNION":
            rest = pb.rotation_quaternion.copy()
            pb.keyframe_insert("rotation_quaternion", frame=start)
            pb.rotation_quaternion = rest @ Quaternion((1.0, 0.0, 0.0), 0.06)
            pb.keyframe_insert("rotation_quaternion", frame=(start + end) // 2)
            pb.rotation_quaternion = rest.copy()
            pb.keyframe_insert("rotation_quaternion", frame=end)
        else:
            rest = pb.rotation_euler.copy()
            pb.keyframe_insert("rotation_euler", frame=start)
            pb.rotation_euler.x = rest.x + 0.05
            pb.keyframe_insert("rotation_euler", frame=(start + end) // 2)
            pb.rotation_euler = rest.copy()
            pb.keyframe_insert("rotation_euler", frame=end)


def bind(cams):
    cuts = [
        (frame_at(0.0), cams["two"]),
        (frame_at(15.2), cams["cards"]),
        (frame_at(17.2), cams["two"]),
        (frame_at(19.0), cams["mark"]),
        (frame_at(24.0), cams["jason"]),
        (frame_at(27.0), cams["mark"]),
        (frame_at(39.0), cams["jason"]),
        (frame_at(45.0), cams["mark"]),
        (frame_at(50.51), cams["two"]),
        (frame_at(64.51), cams["jason"]),
        (frame_at(67.51), cams["mark"]),
    ]

    def switch(scene):
        chosen = cuts[0][1]
        for frame, cam in cuts:
            if scene.frame_current >= frame:
                chosen = cam
        scene.camera = chosen

    bpy.app.handlers.frame_change_pre.append(switch)
    return switch


def render_settings(samples):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 960
    scene.render.resolution_y = 540
    scene.render.resolution_percentage = 100
    scene.render.fps = FPS
    scene.eevee.taa_render_samples = samples
    scene.eevee.use_bloom = True
    scene.eevee.bloom_intensity = 0.035
    scene.eevee.bloom_threshold = 0.85
    scene.view_settings.view_transform = "Filmic"
    scene.view_settings.look = "Medium Contrast"
    os.makedirs(OUT, exist_ok=True)
    return scene


def stills(cams):
    scene = render_settings(16)
    scene.render.image_settings.file_format = "PNG"
    scene.frame_set(1)
    for name in ("two", "mark", "jason", "cards"):
        scene.camera = cams[name]
        path = os.path.join(OUT, f"preview_{name}.png")
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        print("STILL", path)


def main():
    mark, jason = g3.build()
    cams = cameras(mark, jason)
    if "--stills" in sys.argv:
        stills(cams)
        return
    g3.bake(mark)
    g3.key_all(mark, 1)
    g3.key_all(jason, 1)
    g3.key_all(mark, frame_at(END))
    g3.key_all(jason, frame_at(END))
    nod_lines(mark, jason)
    bind(cams)
    scene = render_settings(8)
    scene.frame_start = 1
    scene.frame_end = frame_at(END) - 1
    scene.render.image_settings.file_format = "FFMPEG"
    scene.render.ffmpeg.format = "MPEG4"
    scene.render.ffmpeg.codec = "H264"
    scene.render.ffmpeg.constant_rate_factor = "MEDIUM"
    scene.render.ffmpeg.audio_codec = "NONE"
    path = os.path.join(OUT, "ash_meridian_opening_bar_v02.mp4")
    scene.render.filepath = path
    bpy.ops.render.render(animation=True)
    print("WROTE", path)


if __name__ == "__main__":
    main()
