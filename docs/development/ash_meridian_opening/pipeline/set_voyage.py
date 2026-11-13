"""Gate 7 voyage: hangar departure, the Narcean ring, the docking approach.

Scale is the point of these shots. The ship is ~6 units nose to tail. The
planet has a radius of 1000 units and the ring circles it at 1500, so the
ring is roughly 500 ships across its band's circumference per degree. The
ship always sits near the lens and the ring far away, so it reads tiny.

The station set sits 30000 units from the planet, outside every camera's
clip range, so the sets never see each other.
"""
import math
import random

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

import gate4_bar as g4
import set_bar as sb
import set_narcea as nar

STATION = Vector((30000.0, 0.0, 0.0))
R_RING = 1500.0
R_PLANET = 1000.0
BAND_HALF = 70.0
BAND_IN = R_RING - 6.0
BAND_OUT = R_RING + 6.0
RING_TILT = Euler((math.radians(-22), math.radians(8), 0.0))


def _link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def empty(name, location=(0, 0, 0), parent=None):
    obj = _link(bpy.data.objects.new(name, None))
    obj.location = location
    if parent is not None:
        obj.parent = parent
    return obj


def mesh_obj(name, bm, mat, smooth=False, angle=40):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        for poly in me.polygons:
            poly.use_smooth = True
        me.use_auto_smooth = True
        me.auto_smooth_angle = math.radians(angle)
    me.materials.append(mat)
    return _link(bpy.data.objects.new(name, me))


def parented_box(name, parent, location, size, mat, rot=(0, 0, 0), bevel=0.0):
    obj = sb.rounded_box(name, (0, 0, 0), size, mat, bevel=bevel) if bevel else sb.g2.box(name, (0, 0, 0), size, mat)
    obj.parent = parent
    obj.location = location
    obj.rotation_euler = rot
    return obj


def strut(name, parent, p0, p1, thick, mat):
    p0, p1 = Vector(p0), Vector(p1)
    obj = sb.g2.box(name, (0, 0, 0), (thick, (p1 - p0).length, thick), mat)
    obj.parent = parent
    obj.location = (p0 + p1) / 2
    obj.rotation_euler = (p1 - p0).to_track_quat("Y", "Z").to_euler()
    return obj


def loft(name, sections, mat):
    """Sections are (y, [(x, z), ...]) with equal point counts; ends capped."""
    bm = bmesh.new()
    rings = [[bm.verts.new((x, y, z)) for x, z in pts] for y, pts in sections]
    n = len(rings[0])
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_obj(name, bm, mat, smooth=True, angle=35)


def hexa(w, h, top=0.55, bot=0.75):
    """Flattened six-sided hull section, slightly keeled."""
    return [(w, 0.0), (w * top, h), (-w * top, h), (-w, 0.0), (-w * bot, -h * 0.8), (w * bot, -h * 0.8)]


def ship_materials():
    if "ShipHull" in bpy.data.materials:
        return {k: bpy.data.materials[v] for k, v in (
            ("hull", "ShipHull"), ("dark", "ShipDark"), ("cyan", "ShipCyan"), ("amber", "ShipAmber"),
            ("canopy", "ShipCanopy"), ("plume", "ShipPlume"))}
    hull = sb.grime_mat("ShipHull", (0.16, 0.18, 0.2), rough=(0.25, 0.5), scale=3, metal=0.7,
                        seam=(0.35, 0.35, 0.35), seam_scale=(0.6, 0.3))
    dark = sb.grime_mat("ShipDark", (0.025, 0.03, 0.035), rough=(0.35, 0.6), scale=6, metal=0.6)
    cyan = sb.emit_mat("ShipCyan", (0.25, 0.83, 0.88), 6.0)
    amber = sb.emit_mat("ShipAmber", (1.0, 0.55, 0.22), 12.0)
    canopy = sb.liquid_mat("ShipCanopy", (0.03, 0.12, 0.14), glow=0.6, alpha=1.0)
    canopy.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.02
    mat, nt, out = sb.node_mat("ShipPlume")
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.6
    inv = nt.nodes.new("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 1.0
    nt.links.new(lw.outputs["Facing"], inv.inputs[1])
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (1.0, 0.5, 0.18, 1)
    em.inputs["Strength"].default_value = 6.0
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    add = nt.nodes.new("ShaderNodeAddShader")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(inv.outputs[0], mix.inputs["Fac"])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(tr.outputs[0], add.inputs[0])
    nt.links.new(em.outputs[0], add.inputs[1])
    nt.links.new(add.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    mat.blend_method = "BLEND"
    mat.shadow_method = "NONE"
    return {"hull": hull, "dark": dark, "cyan": cyan, "amber": amber, "canopy": canopy, "plume": mat}


def build_ship(name, scale=1.0, plume=True):
    """Sleek delta courier. Forward is +Y, ~6 units long at scale 1."""
    m = ship_materials()
    root = empty(name)
    body = loft(name + "Body", [
        (-3.0, hexa(0.55, 0.32)),
        (-2.2, hexa(0.75, 0.42)),
        (-0.6, hexa(0.8, 0.46)),
        (1.0, hexa(0.55, 0.36)),
        (2.3, hexa(0.24, 0.17)),
        (3.0, hexa(0.04, 0.03)),
    ], m["hull"])
    body.parent = root
    bm = bmesh.new()
    pts = [(0.62, -2.5), (3.1, -2.95), (3.15, -2.55), (0.7, 0.9)]
    for side in (1, -1):
        top = [bm.verts.new((side * x, y, 0.035)) for x, y in pts]
        bot = [bm.verts.new((side * x, y, -0.06)) for x, y in pts]
        bm.faces.new(top)
        bm.faces.new(list(reversed(bot)))
        for i in range(4):
            bm.faces.new((top[i], top[(i + 1) % 4], bot[(i + 1) % 4], bot[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    wings = mesh_obj(name + "Wings", bm, m["hull"])
    wings.parent = root
    for side in (1, -1):
        strut(f"{name}LeadEdge{side}", root, (side * 0.72, 0.85, 0.0), (side * 3.12, -2.55, 0.0), 0.03, m["cyan"])
        parented_box(f"{name}FinTip{side}", root, (side * 3.13, -2.75, 0.18), (0.05, 0.42, 0.36), m["dark"])
        strut(f"{name}Spine{side}", root, (side * 0.32, 1.9, 0.2), (side * 0.6, -2.9, 0.4), 0.025, m["cyan"])
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.24, depth=1.25, rotation=(math.pi / 2, 0, 0))
        eng = bpy.context.active_object
        eng.name = f"{name}Engine{side}"
        sb.g2.assign(eng, m["dark"])
        eng.parent = root
        eng.location = (side * 0.5, -2.75, -0.12)
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.18, depth=0.03, rotation=(math.pi / 2, 0, 0))
        glow = bpy.context.active_object
        glow.name = f"{name}Exhaust{side}"
        sb.g2.assign(glow, m["amber"])
        glow.parent = root
        glow.location = (side * 0.5, -3.38, -0.12)
        if plume:
            bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=0.17, radius2=0.02, depth=1.6,
                                            rotation=(math.pi / 2, 0, 0))
            cone = bpy.context.active_object
            cone.name = f"{name}Plume{side}"
            sb.g2.assign(cone, m["plume"])
            cone.parent = root
            cone.location = (side * 0.5, -4.2, -0.12)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1.0)
    canopy = bpy.context.active_object
    canopy.name = name + "Canopy"
    sb.g2.assign(canopy, m["canopy"])
    bpy.ops.object.shade_smooth()
    canopy.parent = root
    canopy.location = (0, 1.05, 0.33)
    canopy.scale = (0.3, 0.95, 0.2)
    parented_box(name + "Belly", root, (0, -0.5, -0.36), (0.5, 2.6, 0.08), m["dark"])
    parented_box(name + "NavL", root, (-3.13, -2.4, 0.0), (0.06, 0.06, 0.06), sb.emit_mat(name + "Red", (1, 0.1, 0.05), 20))
    parented_box(name + "NavR", root, (3.13, -2.4, 0.0), (0.06, 0.06, 0.06), sb.emit_mat(name + "Green", (0.1, 1, 0.3), 20))
    root.scale = (scale, scale, scale)
    return root


def oct_points(radius, offset=math.radians(22.5)):
    return [(radius * math.cos(offset + k * math.pi / 4), radius * math.sin(offset + k * math.pi / 4)) for k in range(8)]


def oct_ring(name, r_in, r_out, y0, y1, mat, origin):
    bm = bmesh.new()
    inner = oct_points(r_in)
    outer = oct_points(r_out)
    loops = []
    for y in (y0, y1):
        loops.append([bm.verts.new((x, y, z)) for x, z in outer])
        loops.append([bm.verts.new((x, y, z)) for x, z in inner])
    o0, i0, o1, i1 = loops
    for i in range(8):
        j = (i + 1) % 8
        bm.faces.new((o0[i], o0[j], i0[j], i0[i]))
        bm.faces.new((o1[i], i1[i], i1[j], o1[j]))
        bm.faces.new((o0[i], o1[i], o1[j], o0[j]))
        bm.faces.new((i0[i], i0[j], i1[j], i1[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = mesh_obj(name, bm, mat)
    obj.location = origin
    return obj


def oct_prism(name, radius, y0, y1, mat, origin):
    bm = bmesh.new()
    a = [bm.verts.new((x, y0, z)) for x, z in oct_points(radius)]
    b = [bm.verts.new((x, y1, z)) for x, z in oct_points(radius)]
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    for i in range(8):
        j = (i + 1) % 8
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = mesh_obj(name, bm, mat)
    obj.location = origin
    return obj


def build_station(m):
    """Octagonal hangar mouth in a station face; the tunnel runs along -Y."""
    O = STATION
    R = 9.0
    hull = sb.grime_mat("StationHull", (0.05, 0.065, 0.075), rough=(0.3, 0.7), scale=0.15, metal=0.55,
                        seam=(0.3, 0.3, 0.3), seam_scale=(6.0, 3.0))
    trim = sb.grime_mat("StationTrim", (0.02, 0.025, 0.03), rough=(0.3, 0.6), scale=1, metal=0.7)
    tunnel = sb.grime_mat("TunnelPanel", (0.06, 0.075, 0.085), rough=(0.2, 0.55), scale=0.5, metal=0.6,
                          seam=(0.25, 0.25, 0.25), seam_scale=(2.0, 1.2))
    cyan = sb.emit_mat("StationCyan", (0.25, 0.83, 0.88), 5.0)
    amber = sb.emit_mat("StationAmber", (1.0, 0.55, 0.22), 8.0)
    window_a = sb.emit_mat("StationWindowA", (1.0, 0.62, 0.3), 2.5)
    window_c = sb.emit_mat("StationWindowC", (0.4, 0.85, 0.95), 2.0)

    face = sb.g2.box("StationFace", O + Vector((0, -4.0, 6.0)), (140, 8, 80), hull)
    cutter = oct_prism("HangarCutter", R, -20, 6, trim, O)
    cutter.hide_render = True
    cutter.display_type = "WIRE"
    mod = face.modifiers.new("Hangar", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = cutter
    oct_ring("HangarFrame", R, R + 1.6, -0.2, 1.4, trim, O)
    oct_ring("HangarTrim", R - 0.02, R + 0.08, 1.4, 1.5, cyan, O)
    oct_ring("HangarInnerTrim", R - 0.02, R + 0.02, -8.0, -7.8, cyan, O)
    for k, (x, z) in enumerate(oct_points(R + 0.8)):
        sb.g2.box(f"HangarMarker{k}", O + Vector((x, 1.45, z)), (0.7, 0.1, 0.7), amber)
    a = R * math.cos(math.radians(22.5))
    side = 2 * R * math.sin(math.radians(22.5))
    for k in range(8):
        th = k * math.pi / 4
        rot = (0, math.pi / 2 - th, 0)
        panel = sb.g2.box(f"TunnelWall{k}", O + Vector((a * math.cos(th) * 1.02, -45.0, a * math.sin(th) * 1.02)),
                          (side, 90, 0.3), tunnel)
        panel.rotation_euler = rot
        if k in (2, 6):
            for i in range(12):
                lamp = sb.g2.box(f"TunnelLamp{k}_{i}", O + Vector((a * math.cos(th) * 0.99, -6.0 - i * 7.0, a * math.sin(th) * 0.99)),
                                 (side * 0.5, 1.6, 0.05), cyan if k == 6 else amber)
                lamp.rotation_euler = rot
    for i in range(12):
        oct_ring(f"TunnelRib{i}", R - 0.5, R + 0.3, -4.0 - i * 7.0, -3.4 - i * 7.0, trim, O)
    sb.g2.box("TunnelEnd", O + Vector((0, -88, 0)), (20, 1, 20), window_a)
    sign_plate = sb.g2.box("DepartSignPlate", O + Vector((0, 0.15, R + 4.2)), (11.0, 0.3, 2.6), trim)
    sb.text("DepartSign", "DEPARTURES", O + Vector((0, 0.35, R + 4.65)), (math.pi / 2, 0, math.pi), 1.25, cyan, extrude=0.03)
    sb.text("DepartBay", "07", O + Vector((0, 0.35, R + 3.35)), (math.pi / 2, 0, math.pi), 1.0, amber, extrude=0.03)
    rnd = random.Random(11)
    for i in range(70):
        x = rnd.uniform(-66, 66)
        z = rnd.uniform(-32, 44)
        if abs(x) < R + 3 and -R - 3 < z < R + 7:
            continue
        w, h, d = rnd.uniform(1, 9), rnd.uniform(0.6, 5), rnd.uniform(0.3, 2.5)
        sb.g2.box(f"Greeble{i}", O + Vector((x, d / 2, z)), (w, d, h), trim if i % 3 else hull)
    for i in range(46):
        x = rnd.uniform(-60, 60)
        z = rnd.uniform(-28, 40)
        if abs(x) < R + 4 and -R - 4 < z < R + 8:
            continue
        sb.g2.box(f"StationWin{i}", O + Vector((x, 0.06, z)), (rnd.uniform(0.6, 3.0), 0.05, 0.35),
                  window_a if rnd.random() < 0.6 else window_c)
    for i, x in enumerate((-40, -20, 20, 40)):
        sb.g2.box(f"FaceLine{i}", O + Vector((x, 0.08, 6)), (0.12, 0.05, 80), trim)
    sb.g2.box("FaceCyanLine", O + Vector((0, 0.1, R + 9)), (120, 0.05, 0.12), cyan)
    for i, z in enumerate((-14.0, -40.0, -72.0)):
        bay_light = bpy.data.lights.new(f"TunnelLight{i}", "POINT")
        bay_light.color = (0.45, 0.85, 0.95) if i != 2 else (1.0, 0.6, 0.3)
        bay_light.energy = 25000
        bay_light.shadow_soft_size = 2.0
        lo = _link(bpy.data.objects.new(f"TunnelLight{i}", bay_light))
        lo.location = O + Vector((0, z, 2.0))
    sb.add_area("FaceFill", (0.4, 0.75, 0.9), 40000, O + Vector((30, 40, 30)), (30, 30))
    bpy.data.objects["FaceFill"].rotation_euler = Vector((O + Vector((0, 0, 0)) - (O + Vector((30, 40, 30))))).to_track_quat("-Z", "Y").to_euler()
    ship = build_ship("ShipDepart", scale=1.0)
    return ship


def ring_band(name, r0, r1, z0, z1, mat, segs=720):
    bm = bmesh.new()
    prof = [(r0, z0), (r1, z0), (r1, z1), (r0, z1)]
    loops = []
    for s in range(segs):
        a = 2 * math.pi * s / segs
        c, si = math.cos(a), math.sin(a)
        loops.append([bm.verts.new((r * si, -r * c, z)) for r, z in prof])
    for s in range(segs):
        a, b = loops[s], loops[(s + 1) % segs]
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_obj(name, bm, mat, smooth=True, angle=30)


def planet_material():
    mat, nt, out = sb.node_mat("Planet")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (1 / R_PLANET,) * 3
    nt.links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    warp = nt.nodes.new("ShaderNodeTexNoise")
    warp.inputs["Scale"].default_value = 2.2
    warp.inputs["Detail"].default_value = 6
    nt.links.new(mapping.outputs[0], warp.inputs["Vector"])
    warped = nt.nodes.new("ShaderNodeVectorMath")
    warped.operation = "MULTIPLY_ADD"
    warped.inputs[1].default_value = (0.35, 0.35, 0.35)
    nt.links.new(warp.outputs["Color"], warped.inputs[0])
    nt.links.new(mapping.outputs[0], warped.inputs[2])
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = 5.0
    nt.links.new(warped.outputs[0], vor.inputs["Vector"])
    vein = nt.nodes.new("ShaderNodeMapRange")
    vein.inputs["From Min"].default_value = 0.0
    vein.inputs["From Max"].default_value = 0.035
    vein.inputs["To Min"].default_value = 1.0
    vein.inputs["To Max"].default_value = 0.0
    nt.links.new(vor.outputs["Distance"], vein.inputs["Value"])
    fine = nt.nodes.new("ShaderNodeTexNoise")
    fine.inputs["Scale"].default_value = 9.0
    fine.inputs["Detail"].default_value = 12
    fine.inputs["Roughness"].default_value = 0.6
    nt.links.new(warped.outputs[0], fine.inputs["Vector"])
    base = nt.nodes.new("ShaderNodeValToRGB")
    base.color_ramp.elements[0].position = 0.35
    base.color_ramp.elements[0].color = (0.2, 0.13, 0.075, 1)
    base.color_ramp.elements[1].position = 0.7
    base.color_ramp.elements[1].color = (0.5, 0.37, 0.23, 1)
    nt.links.new(fine.outputs["Fac"], base.inputs["Fac"])
    veined = nt.nodes.new("ShaderNodeMixRGB")
    veined.inputs["Color2"].default_value = (0.08, 0.045, 0.025, 1)
    nt.links.new(vein.outputs[0], veined.inputs["Fac"])
    nt.links.new(base.outputs["Color"], veined.inputs["Color1"])
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Specular"].default_value = 0.2
    nt.links.new(veined.outputs[0], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    return mat


def atmosphere_material():
    mat, nt, out = sb.node_mat("Atmosphere")
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.5
    curve = nt.nodes.new("ShaderNodeMath")
    curve.operation = "POWER"
    curve.inputs[1].default_value = 3.0
    nt.links.new(lw.outputs["Facing"], curve.inputs[0])
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (0.75, 0.55, 0.35, 1)
    em.inputs["Strength"].default_value = 1.2
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    add = nt.nodes.new("ShaderNodeAddShader")
    nt.links.new(tr.outputs[0], add.inputs[0])
    nt.links.new(em.outputs[0], add.inputs[1])
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(curve.outputs[0], mix.inputs["Fac"])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(add.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    mat.blend_method = "BLEND"
    mat.shadow_method = "NONE"
    mat.show_transparent_back = False
    return mat


def ring_air_material():
    """The ring's own air, seen edge-on from far out as a pale glow on the inner face."""
    mat, nt, out = sb.node_mat("RingAir")
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.6
    curve = nt.nodes.new("ShaderNodeMath")
    curve.operation = "POWER"
    curve.inputs[1].default_value = 2.0
    nt.links.new(lw.outputs["Facing"], curve.inputs[0])
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (0.45, 0.65, 0.85, 1)
    em.inputs["Strength"].default_value = 0.9
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    add = nt.nodes.new("ShaderNodeAddShader")
    nt.links.new(tr.outputs[0], add.inputs[0])
    nt.links.new(em.outputs[0], add.inputs[1])
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(curve.outputs[0], mix.inputs["Fac"])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(add.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    mat.blend_method = "BLEND"
    mat.shadow_method = "NONE"
    mat.show_transparent_back = False
    return mat


def ring_hull_material():
    mat = sb.grime_mat("RingHull", (0.07, 0.085, 0.095), rough=(0.25, 0.6), scale=0.08, metal=0.6,
                       seam=(0.3, 0.3, 0.3), seam_scale=(9.0, 4.0))
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    coord = [n for n in nt.nodes if n.bl_idname == "ShaderNodeTexCoord"][0]
    # Unroll the band: u = arc length, v = height across the band.
    sxyz = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(coord.outputs["Object"], sxyz.inputs[0])
    neg = nt.nodes.new("ShaderNodeMath")
    neg.operation = "MULTIPLY"
    neg.inputs[1].default_value = -1.0
    nt.links.new(sxyz.outputs["Y"], neg.inputs[0])
    ang = nt.nodes.new("ShaderNodeMath")
    ang.operation = "ARCTAN2"
    nt.links.new(sxyz.outputs["X"], ang.inputs[0])
    nt.links.new(neg.outputs[0], ang.inputs[1])
    arc = nt.nodes.new("ShaderNodeMath")
    arc.operation = "MULTIPLY"
    arc.inputs[1].default_value = R_RING
    nt.links.new(ang.outputs[0], arc.inputs[0])
    unrolled = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(arc.outputs[0], unrolled.inputs["X"])
    nt.links.new(sxyz.outputs["Z"], unrolled.inputs["Y"])
    for link in list(nt.links):
        if link.from_node == coord and link.to_node != sxyz:
            target = link.to_socket
            nt.links.remove(link)
            nt.links.new(unrolled.outputs[0], target)
    coord = None
    win = nt.nodes.new("ShaderNodeTexBrick")
    win.offset = 0.5
    win.inputs["Color1"].default_value = (0, 0, 0, 1)
    win.inputs["Color2"].default_value = (1, 1, 1, 1)
    win.inputs["Mortar Size"].default_value = 0.0
    win.inputs["Bias"].default_value = 0.0
    win.inputs["Scale"].default_value = 1.0
    win.inputs["Brick Width"].default_value = 5.0
    win.inputs["Row Height"].default_value = 2.5
    nt.links.new(unrolled.outputs[0], win.inputs["Vector"])
    sep = nt.nodes.new("ShaderNodeSeparateColor") if hasattr(bpy.types, "ShaderNodeSeparateColor") else nt.nodes.new("ShaderNodeSeparateRGB")
    nt.links.new(win.outputs["Color"], sep.inputs[0])
    gate = nt.nodes.new("ShaderNodeMapRange")
    gate.inputs["From Min"].default_value = 0.97
    gate.inputs["From Max"].default_value = 0.975
    nt.links.new(sep.outputs[0], gate.inputs["Value"])
    bsdf.inputs["Emission"].default_value = (1.0, 0.6, 0.28, 1)
    nt.links.new(gate.outputs["Result"], bsdf.inputs["Emission Strength"])
    return mat


def build_ring_system():
    planet_mat = planet_material()
    bpy.ops.mesh.primitive_uv_sphere_add(segments=192, ring_count=96, radius=R_PLANET)
    planet = bpy.context.active_object
    planet.name = "Planet"
    bpy.ops.object.shade_smooth()
    sb.g2.assign(planet, planet_mat)
    planet.rotation_euler = (0.3, 0.2, 0.0)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=192, ring_count=96, radius=R_PLANET * 1.022)
    atmo = bpy.context.active_object
    atmo.name = "Atmosphere"
    bpy.ops.object.shade_smooth()
    sb.g2.assign(atmo, atmosphere_material())

    tilt = empty("RingTilt")
    tilt.rotation_euler = RING_TILT
    spin = empty("RingSpin", parent=tilt)
    hull = ring_hull_material()
    trim = sb.grime_mat("RingTrim", (0.02, 0.025, 0.03), rough=(0.3, 0.6), scale=0.3, metal=0.7)
    cyan = sb.emit_mat("RingCyan", (0.25, 0.83, 0.88), 6.0)
    amber = sb.emit_mat("RingAmber", (1.0, 0.55, 0.22), 10.0)
    band = ring_band("RingBand", BAND_IN, BAND_OUT, -BAND_HALF, BAND_HALF, hull)
    band.parent = spin
    for i, z in enumerate((-BAND_HALF - 0.5, BAND_HALF + 0.5)):
        e = ring_band(f"RingEdge{i}", BAND_OUT - 0.2, BAND_OUT + 0.8, z - 0.5, z + 0.5, cyan, segs=720)
        e.parent = spin
        r = ring_band(f"RingLip{i}", BAND_IN - 1.5, BAND_OUT + 0.4, z - 1.2 if i == 0 else z - 0.2,
                      z + 0.2 if i == 0 else z + 1.2, trim, segs=720)
        r.parent = spin
    wall = sb.grime_mat("RingWall", (0.03, 0.035, 0.04), rough=(0.3, 0.6), scale=0.3, metal=0.6)
    for i, z in enumerate((-BAND_HALF, BAND_HALF)):
        w = ring_band(f"RingWall{i}", BAND_IN - 24.0, BAND_IN, z - 1.0, z + 1.0, wall)
        w.parent = spin
        c = ring_band(f"RingWallTop{i}", BAND_IN - 24.6, BAND_IN - 23.6, z - 1.3, z + 1.3, cyan)
        c.parent = spin
    air = ring_band("RingAir", BAND_IN - 9.0, BAND_IN - 0.5, -BAND_HALF + 1.2, BAND_HALF - 1.2, ring_air_material())
    air.parent = spin
    for k in range(48):
        a = 2 * math.pi * k / 48 + math.radians(3.75)
        pivot = empty(f"PylonPivot{k}", parent=spin)
        pivot.rotation_euler = (0, 0, a)
        parented_box(f"Pylon{k}", pivot, (0, -(BAND_OUT + 9), 0), (7, 18, 96), trim)
        parented_box(f"PylonLight{k}", pivot, (0, -(BAND_OUT + 18.2), 47), (2.2, 0.6, 1.2), amber if k % 4 == 0 else cyan)
        parented_box(f"PylonFoot{k}", pivot, (0, -(BAND_OUT + 1), 0), (16, 3, 62), trim)
    return tilt, spin, hull, trim, cyan, amber


def star_world():
    world = bpy.data.worlds.new("Space")
    bpy.context.scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputWorld")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = 180
    vor.inputs["Randomness"].default_value = 1.0
    nt.links.new(coord.outputs["Generated"], vor.inputs["Vector"])
    size = nt.nodes.new("ShaderNodeMapRange")
    size.inputs["From Min"].default_value = 0.0
    size.inputs["From Max"].default_value = 0.13
    size.inputs["To Min"].default_value = 1.0
    size.inputs["To Max"].default_value = 0.0
    nt.links.new(vor.outputs["Distance"], size.inputs["Value"])
    sep = nt.nodes.new("ShaderNodeSeparateRGB")
    nt.links.new(vor.outputs["Color"], sep.inputs[0])
    keep = nt.nodes.new("ShaderNodeMapRange")
    keep.inputs["From Min"].default_value = 0.82
    keep.inputs["From Max"].default_value = 1.0
    keep.inputs["To Min"].default_value = 0.0
    keep.inputs["To Max"].default_value = 6.0
    nt.links.new(sep.outputs[0], keep.inputs["Value"])
    star = nt.nodes.new("ShaderNodeMath")
    star.operation = "MULTIPLY"
    nt.links.new(size.outputs[0], star.inputs[0])
    nt.links.new(keep.outputs[0], star.inputs[1])
    neb = nt.nodes.new("ShaderNodeTexNoise")
    neb.inputs["Scale"].default_value = 1.6
    neb.inputs["Detail"].default_value = 6
    nt.links.new(coord.outputs["Generated"], neb.inputs["Vector"])
    neb_ramp = nt.nodes.new("ShaderNodeValToRGB")
    neb_ramp.color_ramp.elements[0].position = 0.5
    neb_ramp.color_ramp.elements[0].color = (0.0015, 0.002, 0.003, 1)
    neb_ramp.color_ramp.elements[1].position = 0.8
    neb_ramp.color_ramp.elements[1].color = (0.012, 0.02, 0.028, 1)
    nt.links.new(neb.outputs["Fac"], neb_ramp.inputs["Fac"])
    starc = nt.nodes.new("ShaderNodeMixRGB")
    starc.blend_type = "ADD"
    starc.inputs["Fac"].default_value = 1.0
    tint = nt.nodes.new("ShaderNodeMixRGB")
    tint.blend_type = "MULTIPLY"
    tint.inputs["Fac"].default_value = 1.0
    tint.inputs["Color2"].default_value = (0.85, 0.92, 1.0, 1)
    nt.links.new(star.outputs[0], tint.inputs["Color1"])
    nt.links.new(neb_ramp.outputs["Color"], starc.inputs["Color1"])
    nt.links.new(tint.outputs[0], starc.inputs["Color2"])
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.inputs["Strength"].default_value = 1.0
    nt.links.new(starc.outputs[0], bg.inputs["Color"])
    nt.links.new(bg.outputs[0], out.inputs["Surface"])
    return world


def look_at(obj, loc, tgt, up):
    f = (Vector(tgt) - Vector(loc)).normalized()
    r = f.cross(Vector(up)).normalized()
    u = r.cross(f)
    obj.location = loc
    obj.rotation_euler = Matrix((r, u, -f)).transposed().to_euler()


def ease(t):
    return t * t * (3 - 2 * t)


def build_voyage():
    """Builds all three space sets. Returns cameras by shot name."""
    star_world()
    m = ship_materials()
    ship_d = build_station(m)
    tilt, spin, hull, trim, cyan, amber = build_ring_system()
    F = g4.frame_at

    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 6.0
    sun_data.color = (1.0, 0.93, 0.85)
    sun_data.angle = math.radians(0.6)
    sun_data.shadow_cascade_max_distance = 400
    sun = _link(bpy.data.objects.new("Sun", sun_data))

    def sun_from(direction, frame):
        sun.rotation_euler = (-Vector(direction)).to_track_quat("-Z", "Y").to_euler()
        sun.keyframe_insert("rotation_euler", frame=frame)

    sun_from((-0.6, -0.35, 0.72), F(82.35))
    sun_from((0.82, 0.42, 0.38), F(100.35))
    for fc in sun.animation_data.action.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "CONSTANT"

    # Departure: the courier slides out of the tunnel, then the camera pans as it passes.
    O = STATION
    t0, t1, t2 = 82.35, 90.5, 100.35

    def ship_d_at(t):
        if t <= t1:
            return O + Vector((0.0, -60.0 + 58.0 * ease((t - t0) / (t1 - t0)), -2.0))
        u = (t - t1) / (t2 - t1)
        return O + Vector((0.0, -2.0 + 70.0 * u * u + 14.0 * u, -2.0 + 9.0 * u * u))

    depart = g4.add_cam("DepartCam", O + Vector((15.5, 34.0, 1.0)), O, 40)
    depart.data.clip_start = 0.3
    depart.data.clip_end = 3000
    t = t0
    while t <= t2 + 0.01:
        f = F(t)
        p = ship_d_at(t)
        ship_d.location = p
        ship_d.keyframe_insert("location", frame=f)
        u = max(0.0, (t - 86.0) / (t2 - 86.0))
        depart.location = O + Vector((15.5 + 8.0 * u, 34.0 + 4.0 * u, 1.0 + 2.0 * u))
        focus = (O + Vector((0, 0, 4.4))).lerp(p + Vector((0, 2.5, 2.2)), min(1.0, 0.3 + 0.7 * ease(min(1.0, (t - t0) / 10.0))))
        g4.aim(depart, focus)
        depart.keyframe_insert("location", frame=f)
        depart.keyframe_insert("rotation_euler", frame=f)
        t += 0.5

    # Arrival wide: the ring and planet seen from far out, the ship tiny near the lens.
    world_of = lambda local: tilt.matrix_world @ Vector(local)
    bpy.context.view_layer.update()
    cam_a0 = Vector((260.0, -4700.0, 520.0))
    arrive = g4.add_cam("ArriveCam", cam_a0, Vector((0, 0, -60)), 38)
    arrive.data.clip_start = 1.0
    arrive.data.clip_end = 20000
    ship_a = build_ship("ShipArrive", scale=1.0)
    look = (Vector((0, 0, -60)) - cam_a0).normalized()
    right = look.cross(Vector((0, 0, 1))).normalized()
    up = right.cross(look)
    for t, push in ((100.35, 0.0), (114.5, 1.0)):
        f = F(t)
        arrive.location = cam_a0 + look * (220.0 * push)
        g4.aim(arrive, Vector((0, 0, -60)))
        arrive.keyframe_insert("location", frame=f)
        arrive.keyframe_insert("rotation_euler", frame=f)
        ship_a.location = cam_a0 + look * (70.0 + 245.0 * push) + right * 11.0 - up * 7.5
        ship_a.rotation_euler = look.to_track_quat("Y", "Z").to_euler()
        ship_a.keyframe_insert("location", frame=f)
        ship_a.keyframe_insert("rotation_euler", frame=f)

    # The arrival glimpse keeps the whole ring small; it turns slowly.
    for t, a in ((100.35, 0.0), (114.5, 0.012)):
        spin.rotation_euler = (0, 0, a)
        spin.keyframe_insert("rotation_euler", frame=F(t))
    for fc in spin.animation_data.action.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"

    # Close shots switch to the ring section at true scale (set_narcea).
    def path_b(u):
        return -64000.0 + 9000.0 * u, -13600.0 + 300.0 * u, 7600.0 - 1400.0 * u

    def path_c(u):
        k = ease(u) * 0.35 + u * 0.65
        return -7000.0 + 9500.0 * k, -9500.0 + 400.0 * u + 60.0 * math.sin(u * 5.0), 150.0 + 3250.0 * (1.0 - u) ** 1.7

    end_s, end_x, _ = path_c(1.0)
    before = [o for o in bpy.data.objects if o.type != "CAMERA" and o.name != "Sun"]
    mega = nar.build(path_c, end_s, end_x)
    ship_b = build_ship("ShipRingHigh", scale=1.0)
    ship_c = build_ship("ShipDescent", scale=1.0)
    for root in (ship_b, ship_c):
        mega += [root] + list(root.children_recursive)
    t_cut = F(114.5)
    for o in before:
        o.hide_render = False
        o.keyframe_insert("hide_render", frame=1)
        o.hide_render = True
        o.keyframe_insert("hide_render", frame=t_cut)
    for o in mega:
        o.hide_render = True
        o.keyframe_insert("hide_render", frame=1)
        o.hide_render = False
        o.keyframe_insert("hide_render", frame=t_cut)

    def fly(ship, cam, path, t0, t1, cam_off, aim):
        t = t0
        while t <= t1 + 1e-6:
            u = (t - t0) / (t1 - t0)
            s, x, alt = path(u)
            p = nar.surf(s, x, alt)
            du = 0.004
            ahead = nar.surf(*path(min(1.0, u + du)))
            behind = nar.surf(*path(max(0.0, u - du)))
            heading = (ahead - behind).normalized()
            right = heading.cross(nar.up_at(s)).normalized()
            up = right.cross(heading)
            ship.location = p
            ship.rotation_euler = heading.to_track_quat("Y", "Z").to_euler()
            ship.keyframe_insert("location", frame=F(t))
            ship.keyframe_insert("rotation_euler", frame=F(t))
            loc = p + heading * cam_off[0] + up * cam_off[1] + right * cam_off[2]
            tgt = p + heading * aim[0] + up * aim[1] + right * aim[2]
            look_at(cam, loc, tgt, up)
            cam.keyframe_insert("location", frame=F(t))
            cam.keyframe_insert("rotation_euler", frame=F(t))
            t += 0.5

    # Above the open top: one retaining wall on the left, the band running on into haze.
    close = g4.add_cam("ArriveCloseCam", Vector((0, 0, 0)), Vector((0, 1, 0)), 36)
    close.data.clip_start = 1.0
    close.data.clip_end = 400000
    fly(ship_b, close, path_b, 114.5, 123.4, (-13.0, 4.0, 6.0), (400.0, -150.0, -260.0))

    # Descent: through the high deck, under the low deck, out over the yard to the first gate.
    approach = g4.add_cam("ApproachCam", Vector((0, 0, 0)), Vector((0, 1, 0)), 40)
    approach.data.clip_start = 1.0
    approach.data.clip_end = 400000
    fly(ship_c, approach, path_c, 123.35, 141.4, (-17.0, 4.5, 0.0), (300.0, -20.0, 0.0))

    sun_from((0.5, 0.82, 0.16), F(114.5))
    sun_from((-0.25, 0.3, 0.92), F(123.35))
    for t, e, c in ((82.35, 6.0, (1.0, 0.93, 0.85)), (114.5, 1.8, (1.0, 0.72, 0.5)), (123.35, 0.35, (0.6, 0.72, 1.0))):
        sun_data.energy = e
        sun_data.color = c
        sun_data.keyframe_insert("energy", frame=F(t))
        sun_data.keyframe_insert("color", frame=F(t))
    for action in (sun.animation_data.action, sun_data.animation_data.action):
        for fc in action.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "CONSTANT"
    return {"depart": depart, "arrive": arrive, "arrive_close": close, "approach": approach}
