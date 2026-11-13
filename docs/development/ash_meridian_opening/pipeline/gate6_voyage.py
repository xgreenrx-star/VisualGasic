"""Departure, arrival, and the ring. The bar stays where it is.

The voyage sits well outside the bar cameras' clip range. Three shots:
the station as Jason's ship leaves, the ring filling the frame, then the
docking bay rotating into line with the ship.
"""
import math
import random

import bpy
from mathutils import Vector

import gate2_still as g2
import gate4_bar as g4

OFFSET = Vector((72.0, 28.0, 0.0))


def _shift(obj):
    obj.location = Vector(obj.location) + OFFSET
    return obj


def _empty(name, location):
    obj = bpy.data.objects.new(name, None)
    obj.location = Vector(location) + OFFSET
    bpy.context.scene.collection.objects.link(obj)
    return obj


def build_voyage():
    dark = g2.material("Hull", (0.07, 0.09, 0.1), 0.4, metal=0.45)
    panel = g2.material("Panel", (0.1, 0.14, 0.16), 0.5)
    cyan = g2.material("VoyageCyan", (0.25, 0.83, 0.88), 0.3, emit=3.0)
    amber = g2.material("VoyageAmber", (1.0, 0.55, 0.22), 0.35, emit=4.0)
    bay_mat = g2.material("Bay", (0.35, 0.75, 0.82), 0.25, emit=2.2)

    g2.box("StationCore", (0, 0, 1.2), (7.5, 2.6, 2.4), dark)
    g2.box("StationTower", (-2.2, -0.2, 3.6), (1.4, 1.4, 2.2), panel)
    g2.box("DockSpine", (0, 6.5, 0.35), (0.9, 7.5, 0.28), dark)
    for index, y in enumerate((2.2, 4.4, 6.6, 8.8)):
        g2.box(f"DockLight{index}", (0.55, y, 0.55), (0.04, 0.7, 0.03), cyan)
    g2.box("StationWindow", (0, 1.35, 2.05), (2.4, 0.06, 0.7), cyan)
    g2.box("StationRim", (0, 0, 2.45), (7.6, 2.7, 0.04), cyan)
    for name in ("StationCore", "StationTower", "DockSpine", "StationWindow", "StationRim"):
        _shift(bpy.data.objects[name])
    for index in range(4):
        _shift(bpy.data.objects[f"DockLight{index}"])

    ship = _empty("Ship", (0.0, 8.0, 0.55))
    hull = g2.box("ShipHull", (0, 0, 0), (1.1, 4.2, 0.55), dark)
    nose = g2.box("ShipNose", (0, 2.4, 0.02), (0.5, 0.9, 0.28), panel)
    engine = g2.box("ShipEngine", (0, -2.2, 0), (0.36, 0.22, 0.22), amber)
    strip = g2.box("ShipStrip", (0.58, 0.1, 0.3), (0.03, 3.4, 0.02), cyan)
    strip_b = g2.box("ShipStripB", (-0.58, 0.1, 0.3), (0.03, 3.4, 0.02), cyan)
    for part in (hull, nose, engine, strip, strip_b):
        part.parent = ship
        part.location = part.location  # already local once parented if we parent before world assign
    # Parenting after the parts were created at the origin keeps their
    # location as an offset from the ship empty, which is what we want.

    hub = _empty("RingHub", (0.0, 96.0, 2.0))
    bpy.ops.mesh.primitive_torus_add(
        major_radius=14.0,
        minor_radius=0.85,
        major_segments=72,
        minor_segments=12,
        location=(0, 0, 0),
    )
    ring = bpy.context.active_object
    ring.name = "Ring"
    ring.parent = hub
    ring.rotation_euler = (math.pi / 2.0, 0.0, 0.0)
    g2.assign(ring, dark)
    bpy.ops.mesh.primitive_torus_add(
        major_radius=13.15,
        minor_radius=0.06,
        major_segments=72,
        minor_segments=8,
        location=(0, 0, 0),
    )
    inner = bpy.context.active_object
    inner.name = "RingInner"
    inner.parent = hub
    inner.rotation_euler = (math.pi / 2.0, 0.0, 0.0)
    g2.assign(inner, cyan)
    bay = g2.box("RingBay", (0.0, -12.6, 0.0), (1.3, 0.22, 0.7), bay_mat)
    bay.parent = hub

    random.seed(7)
    star_mat = g2.material("Star", (0.85, 0.9, 0.95), 0.4, emit=3.0)
    for index in range(48):
        spot = Vector((
            random.uniform(-40, 40),
            random.uniform(-10, 80),
            random.uniform(-18, 28),
        ))
        star = g2.box(f"Star{index}", spot, (0.03, 0.03, 0.03), star_mat)
        _shift(star)

    g2.add_light("StationFill", (0.7, 0.78, 0.82), 140, tuple(OFFSET + Vector((8, 10, 6))), 6.0)
    g2.add_light("RingCyan", (0.3, 0.85, 0.95), 90, tuple(OFFSET + Vector((0, 70, 8))), 8.0)
    g2.add_light("ShipKey", (0.7, 0.75, 0.8), 40, tuple(OFFSET + Vector((4, 14, 3))), 2.5)

    depart = g4.add_cam(
        "DepartCam",
        OFFSET + Vector((7.0, 2.0, 2.6)),
        OFFSET + Vector((0.2, 14.0, 0.8)),
        36,
    )
    arrive = g4.add_cam(
        "ArriveCam",
        OFFSET + Vector((16.0, 48.0, 6.0)),
        OFFSET + Vector((0.0, 96.0, 2.0)),
        40,
    )
    approach = g4.add_cam(
        "ApproachCam",
        OFFSET + Vector((3.5, 72.0, 1.8)),
        OFFSET + Vector((0.0, 83.4, 2.0)),
        34,
    )
    for cam in (depart, arrive, approach):
        cam.data.clip_end = 250.0

    # The bay starts off to the side and swings around to face the ship.
    hub.rotation_euler.y = 1.15
    hub.keyframe_insert("rotation_euler", frame=g4.frame_at(100.35))
    hub.rotation_euler.y = 0.35
    hub.keyframe_insert("rotation_euler", frame=g4.frame_at(127.35))
    hub.rotation_euler.y = 0.0
    hub.keyframe_insert("rotation_euler", frame=g4.frame_at(135.35))

    ship.keyframe_insert("location", frame=g4.frame_at(82.35))
    ship.location = OFFSET + Vector((0.0, 28.0, 0.8))
    ship.keyframe_insert("location", frame=g4.frame_at(100.35))
    ship.location = OFFSET + Vector((0.0, 52.0, 1.3))
    ship.keyframe_insert("location", frame=g4.frame_at(123.35))
    ship.location = OFFSET + Vector((0.0, 70.0, 1.6))
    ship.keyframe_insert("location", frame=g4.frame_at(141.35))

    depart.keyframe_insert("location", frame=g4.frame_at(82.35))
    depart.keyframe_insert("rotation_euler", frame=g4.frame_at(82.35))
    depart.location = OFFSET + Vector((9.0, 8.0, 3.4))
    g4.aim(depart, OFFSET + Vector((0.6, 24.0, 1.2)))
    depart.keyframe_insert("location", frame=g4.frame_at(100.0))
    depart.keyframe_insert("rotation_euler", frame=g4.frame_at(100.0))

    return {"depart": depart, "arrive": arrive, "approach": approach}
