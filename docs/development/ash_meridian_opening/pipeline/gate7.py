"""Gate 7 render driver.

Cursor's gate5 characters, posing, lip sync and cameras are reused as-is.
Only the sets change: gate2.build_room -> set_bar.build_room, and the voyage
is rendered in its own Blender process from set_voyage.build_voyage.

  blender -b -P gate7.py -- bar [--stills names...]
  blender -b -P gate7.py -- voyage [--stills names...]
"""
import math
import os
import sys

sys.path.insert(0, "/tmp/ash-opening-gate1")
sys.path.insert(0, "/tmp/ash-opening-gate7")

import bpy
from mathutils import Matrix, Vector

import gate2_still as g2
import gate3_motion as g3
import gate4_bar as g4
import gate5_talk as g5
import set_bar
import set_voyage

g2.build_room = set_bar.build_room
g4.END = g5.END

ROOT = "/tmp/ash-opening-gate7"
FRAMES = os.path.join(ROOT, "frames")
STILLS = "/home/Commodore/Documents/VisualGasic/docs/development/ash_meridian_opening/renders/gate7"
F = g4.frame_at
BAR_END = F(82.35) - 1
VOYAGE_END = F(g5.END) - 1


def args():
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def settings(samples):
    scene = g4.render_settings(samples)
    ev = scene.eevee
    ev.use_ssr = True
    ev.use_gtao = True
    ev.gtao_distance = 0.4
    ev.use_soft_shadows = True
    ev.shadow_cube_size = "1024"
    ev.shadow_cascade_size = "2048"
    ev.bloom_intensity = 0.05
    ev.bloom_threshold = 0.9
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    return scene


def bind(cuts):
    def switch(scene):
        chosen = cuts[0][1]
        for frame, cam in cuts:
            if scene.frame_current >= frame:
                chosen = cam
        scene.camera = chosen

    bpy.app.handlers.frame_change_pre.append(switch)
    bpy.context.scene.camera = cuts[0][1]


def focus(cam, target, fstop, rig=None, bone=None):
    cam.data.dof.use_dof = True
    cam.data.dof.aperture_fstop = fstop
    target = Vector(target)
    if rig is None:
        cam.data.dof.focus_distance = (target - cam.matrix_world.translation).length
        return
    eye = target + Vector((0, 0, 0.09))
    eye += (cam.matrix_world.translation - eye).normalized() * 0.07
    tracker = bpy.data.objects.new(f"Focus_{cam.name}", None)
    bpy.context.scene.collection.objects.link(tracker)
    tracker.parent = rig
    tracker.parent_type = "BONE"
    tracker.parent_bone = bone
    bpy.context.view_layer.update()
    tracker.matrix_world = Matrix.Translation(eye)
    cam.data.dof.focus_object = tracker


def render_stills(scene, shots, wanted):
    os.makedirs(STILLS, exist_ok=True)
    for name, frame, cam in shots:
        if wanted and name not in wanted:
            continue
        scene.frame_set(frame)
        scene.camera = cam
        scene.render.filepath = os.path.join(STILLS, f"preview_{name}.png")
        bpy.ops.render.render(write_still=True)
        print("STILL", scene.render.filepath, flush=True)


def bar(argv):
    mark, mark_mesh, jason, jason_mesh = g5.build()
    g5.lip_sync(mark_mesh, jason_mesh)
    cams = g4.cameras(mark, jason)
    bpy.context.view_layer.update()
    mark_head = g2.world_head(mark, "Bip01 Head")
    jason_bone = "FK-Head" if "FK-Head" in jason.pose.bones else "Bip01 Head"
    jason_head = g2.world_head(jason, jason_bone)
    focus(cams["mark"], mark_head, 2.8, mark, "Bip01 Head")
    focus(cams["jason"], jason_head, 2.8, jason, jason_bone)
    focus(cams["two"], mark_head, 5.6, mark, "Bip01 Head")
    focus(cams["cards"], Vector((-0.12, 0.18, 0.76)), 2.8)
    for cam in cams.values():
        cam.data.clip_end = 60
    scene = settings(16 if "--stills" in argv else 10)
    scene.eevee.use_volumetric_lights = True
    scene.eevee.volumetric_tile_size = "8"
    scene.eevee.volumetric_samples = 48
    scene.eevee.volumetric_end = 14.0
    if "--stills" in argv:
        wanted = {a for a in argv if a in ("two", "mark", "jason", "cards", "drinks", "room")}
        drinks = g4.add_cam("DrinksPreview", Vector((0.25, 0.55, 1.02)), Vector((-0.42, -0.22, 0.82)), 38)
        room = g4.add_cam("RoomPreview", Vector((1.9, 1.9, 1.75)), Vector((-0.6, -1.2, 1.1)), 70)
        for c in (drinks, room):
            c.data.clip_end = 60
        render_stills(scene, (
            ("drinks", F(9.0), drinks),
            ("room", F(9.0), room),
            ("two", 1, cams["two"]),
            ("mark", F(9.0), cams["mark"]),
            ("jason", F(25.0), cams["jason"]),
            ("cards", F(16.0), cams["cards"]),
        ), wanted)
        return
    g3.bake(mark)
    g3.bake(jason)
    for frame in (1, F(g5.END)):
        g3.key_all(mark, frame)
        g3.key_all(jason, frame)
    g4.nod_lines(mark, jason)
    bind([
        (F(0.0), cams["two"]),
        (F(15.2), cams["cards"]),
        (F(17.2), cams["two"]),
        (F(19.0), cams["mark"]),
        (F(24.0), cams["jason"]),
        (F(27.0), cams["mark"]),
        (F(39.0), cams["jason"]),
        (F(45.0), cams["mark"]),
        (F(50.51), cams["two"]),
        (F(64.51), cams["jason"]),
        (F(67.51), cams["mark"]),
    ])
    render_range(scene, 1, BAR_END)


def voyage(argv):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    cams = set_voyage.build_voyage()
    scene = settings(16 if "--stills" in argv else 12)
    scene.eevee.use_volumetric_lights = True
    scene.eevee.use_volumetric_shadows = False
    scene.eevee.volumetric_tile_size = "8"
    scene.eevee.volumetric_samples = 64
    scene.eevee.volumetric_start = 1.0
    scene.eevee.volumetric_end = 250000.0
    scene.eevee.volumetric_sample_distribution = 0.95
    if "--stills" in argv:
        shots = (
            ("depart", F(88.0), cams["depart"]),
            ("depart_pass", F(97.0), cams["depart"]),
            ("arrive", F(108.0), cams["arrive"]),
            ("arrive_close", F(116.0), cams["arrive_close"]),
            ("arrive_close_end", F(123.0), cams["arrive_close"]),
            ("approach", F(124.5), cams["approach"]),
            ("approach_deck", F(128.0), cams["approach"]),
            ("approach_mid", F(131.5), cams["approach"]),
            ("approach_under", F(135.5), cams["approach"]),
            ("approach_end", F(141.0), cams["approach"]),
        )
        wanted = [a for a in argv if any(n.startswith(a) for n, _, _ in shots)]
        for name, frame, cam in shots:
            if wanted and not any(name.startswith(w) for w in wanted):
                continue
            render_stills(scene, ((name, frame, cam),), set())
        return
    bind([
        (F(82.35), cams["depart"]),
        (F(100.35), cams["arrive"]),
        (F(114.5), cams["arrive_close"]),
        (F(123.35), cams["approach"]),
    ])
    render_range(scene, F(82.35), VOYAGE_END)


def render_range(scene, start, end):
    os.makedirs(FRAMES, exist_ok=True)
    first = int(os.environ.get("GATE7_FROM", start))
    scene.frame_start = max(start, first)
    scene.frame_end = end
    scene.frame_set(scene.frame_start)
    scene.render.use_overwrite = False
    scene.render.filepath = os.path.join(FRAMES, "f_####")
    bpy.ops.render.render(animation=True)
    print("DONE", start, end, flush=True)


if __name__ == "__main__":
    argv = args()
    if "voyage" in argv:
        voyage(argv)
    else:
        bar(argv)
