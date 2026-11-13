"""Narcea at true scale: the inner face of the ring, seen from the Ash.

The far glimpse in set_voyage shows the whole ring as a small object. Once the
Ash is close, that model cannot carry the scale, so the close shots use this
section instead. The ring radius here is 250000 units against a ship of about
6 units. Locally the floor sits at z = 0 near the origin and curves up along +Y
and -Y. The ring axis runs along X at height R_BIG. The band is 30000 units wide
between two retaining walls 4500 units tall. Spin presses the air against the
floor; the walls hold it at the edges; the top is open to space.

Arc length s along the floor maps to angle s / R_BIG. Altitude is measured
toward the ring axis.
"""
import math
import random

import bmesh
import bpy
from mathutils import Vector

import set_bar as sb

R_BIG = 250000.0
HALF_W = 15000.0
WALL_H = 4500.0
AIR_H = 1300.0
S_MIN, S_MAX = -80000.0, 160000.0


def surf(s, x, alt):
    th = s / R_BIG
    r = R_BIG - alt
    return Vector((x, r * math.sin(th), R_BIG - r * math.cos(th)))


def up_at(s):
    th = s / R_BIG
    return Vector((0.0, -math.sin(th), math.cos(th)))


def fwd_at(s):
    th = s / R_BIG
    return Vector((0.0, math.cos(th), math.sin(th)))


def _obj(name, bm, mat):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if mat is not None:
        ob.data.materials.append(mat)
    return ob


def arc_sheet(name, alt, x0, x1, s0, s1, nx, ns, mat, uv=False):
    bm = bmesh.new()
    rows = []
    for i in range(ns + 1):
        s = s0 + (s1 - s0) * i / ns
        rows.append([bm.verts.new(surf(s, x0 + (x1 - x0) * j / nx, alt)) for j in range(nx + 1)])
    for i in range(ns):
        for j in range(nx):
            bm.faces.new((rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]))
    return _obj(name, bm, mat)


def wall_sheet(name, x, h0, h1, s0, s1, nh, ns, mat):
    bm = bmesh.new()
    rows = []
    for i in range(ns + 1):
        s = s0 + (s1 - s0) * i / ns
        rows.append([bm.verts.new(surf(s, x, h0 + (h1 - h0) * j / nh)) for j in range(nh + 1)])
    for i in range(ns):
        for j in range(nh):
            bm.faces.new((rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]))
    return _obj(name, bm, mat)


def add_box(bm, s, x, alt, size, yaw=0.0):
    """Adds a box standing on the floor, aligned to the local surface frame."""
    c = surf(s, x, alt)
    u, f = up_at(s), fwd_at(s)
    r = f.cross(u)
    cy, sy = math.cos(yaw), math.sin(yaw)
    rx, fy = r * cy + f * sy, f * cy - r * sy
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    vs = [bm.verts.new(c + rx * (dx * hx) + fy * (dy * hy) + u * (dz * hz))
          for dx in (-1, 1) for dy in (-1, 1) for dz in (-1, 1)]
    for q in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
        bm.faces.new([vs[k] for k in q])


def _m(nt, op, a, b=None, clamp=False):
    n = nt.nodes.new("ShaderNodeMath")
    n.operation = op
    n.use_clamp = clamp
    for i, v in enumerate((a, b)):
        if v is None:
            continue
        if isinstance(v, (int, float)):
            n.inputs[i].default_value = v
        else:
            nt.links.new(v, n.inputs[i])
    return n.outputs[0]


def _range(nt, v, a, b, c=0.0, d=1.0):
    n = nt.nodes.new("ShaderNodeMapRange")
    n.inputs["From Min"].default_value = a
    n.inputs["From Max"].default_value = b
    n.inputs["To Min"].default_value = c
    n.inputs["To Max"].default_value = d
    nt.links.new(v, n.inputs["Value"])
    return n.outputs[0]


def _xyz(nt, vec):
    n = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(vec, n.inputs[0])
    return n.outputs


def _noise(nt, vec, scale, detail=6.0, rough=0.55):
    n = nt.nodes.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = detail
    n.inputs["Roughness"].default_value = rough
    nt.links.new(vec, n.inputs["Vector"])
    return n.outputs["Fac"]


def _grid(nt, coord, spacing, width):
    """1 on grid lines of the given spacing, 0 between them."""
    x, y = _xyz(nt, coord)[0], _xyz(nt, coord)[1]
    lines = []
    for c in (x, y):
        p = _m(nt, "PINGPONG", _m(nt, "MULTIPLY", c, 1.0 / spacing), 0.5)
        lines.append(_range(nt, p, 0.0, width / spacing, 1.0, 0.0))
    return _m(nt, "MAXIMUM", lines[0], lines[1])


def floor_mat(end_s, end_x):
    mat, nt, out = sb.node_mat("NarceaFloor")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    pos = geo.outputs["Position"]
    district = _range(nt, _noise(nt, pos, 0.00012, 4.0), 0.55, 0.68)
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = 1.0 / 70.0
    nt.links.new(pos, vor.inputs["Vector"])
    dot = _range(nt, vor.outputs["Distance"], 0.0, 0.09, 1.0, 0.0)
    keep = _range(nt, _xyz(nt, vor.outputs["Color"])[0], 0.8, 0.82)
    lamps = _m(nt, "MULTIPLY", _m(nt, "MULTIPLY", dot, keep), district)
    cam = nt.nodes.new("ShaderNodeCameraData")
    far = _range(nt, cam.outputs["View Distance"], 4000.0, 22000.0, 1.0, 0.12)
    grid = _m(nt, "MULTIPLY", _grid(nt, pos, 520.0, 5.0), _m(nt, "MULTIPLY", district, _m(nt, "MULTIPLY", far, 0.6)))
    # The Backlight Yard: a tighter, brighter grid where the descent ends.
    yard_c = Vector((end_x, end_s + 4200.0, 0.0))
    d = nt.nodes.new("ShaderNodeVectorMath")
    d.operation = "DISTANCE"
    d.inputs[1].default_value = yard_c
    nt.links.new(pos, d.inputs[0])
    yard = _range(nt, d.outputs["Value"], 2600.0, 3600.0, 1.0, 0.0)
    ygrid = _m(nt, "MULTIPLY", _grid(nt, pos, 160.0, 2.2), _m(nt, "MULTIPLY", yard, 2.5))
    cyan = _m(nt, "MAXIMUM", grid, ygrid)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tone = _range(nt, _noise(nt, pos, 0.0011, 5.0), 0.3, 0.7, 0.006, 0.02)
    tone_rgb = nt.nodes.new("ShaderNodeCombineRGB")
    for i in range(3):
        nt.links.new(tone, tone_rgb.inputs[i])
    nt.links.new(tone_rgb.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.75
    em_c = nt.nodes.new("ShaderNodeEmission")
    em_c.inputs["Color"].default_value = (0.2, 0.85, 0.95, 1)
    nt.links.new(_m(nt, "MULTIPLY", cyan, 3.0), em_c.inputs["Strength"])
    em_a = nt.nodes.new("ShaderNodeEmission")
    em_a.inputs["Color"].default_value = (1.0, 0.55, 0.22, 1)
    nt.links.new(_m(nt, "MULTIPLY", lamps, 14.0), em_a.inputs["Strength"])
    add1 = nt.nodes.new("ShaderNodeAddShader")
    nt.links.new(bsdf.outputs[0], add1.inputs[0])
    nt.links.new(em_c.outputs[0], add1.inputs[1])
    add2 = nt.nodes.new("ShaderNodeAddShader")
    nt.links.new(add1.outputs[0], add2.inputs[0])
    nt.links.new(em_a.outputs[0], add2.inputs[1])
    nt.links.new(add2.outputs[0], out.inputs["Surface"])
    return mat


def wall_mat():
    mat, nt, out = sb.node_mat("NarceaWall")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    pos = geo.outputs["Position"]
    # Altitude from the ring axis: R_BIG - |(y, z - R_BIG)|.
    _, y, z = _xyz(nt, pos)
    zr = _m(nt, "SUBTRACT", z, R_BIG)
    rad = _m(nt, "SQRT", _m(nt, "ADD", _m(nt, "MULTIPLY", y, y), _m(nt, "MULTIPLY", zr, zr)))
    alt = _m(nt, "SUBTRACT", R_BIG, rad)
    stripe = _range(nt, _m(nt, "PINGPONG", _m(nt, "MULTIPLY", alt, 1.0 / 900.0), 0.5), 0.0, 0.006, 1.0, 0.0)
    top = _range(nt, alt, WALL_H - 60.0, WALL_H - 10.0)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (0.02, 0.024, 0.028, 1)
    bsdf.inputs["Metallic"].default_value = 0.6
    bsdf.inputs["Roughness"].default_value = 0.45
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (0.2, 0.85, 0.95, 1)
    nt.links.new(_m(nt, "ADD", _m(nt, "MULTIPLY", stripe, 1.2), _m(nt, "MULTIPLY", top, 8.0)), em.inputs["Strength"])
    add = nt.nodes.new("ShaderNodeAddShader")
    nt.links.new(bsdf.outputs[0], add.inputs[0])
    nt.links.new(em.outputs[0], add.inputs[1])
    nt.links.new(add.outputs[0], out.inputs["Surface"])
    return mat


def air_mat(density=1.6e-4):
    """Exponential air against the floor, held between the walls."""
    mat, nt, out = sb.node_mat("NarceaAir")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    x, y, z = _xyz(nt, geo.outputs["Position"])
    zr = _m(nt, "SUBTRACT", z, R_BIG)
    rad = _m(nt, "SQRT", _m(nt, "ADD", _m(nt, "MULTIPLY", y, y), _m(nt, "MULTIPLY", zr, zr)))
    alt = _m(nt, "MAXIMUM", _m(nt, "SUBTRACT", R_BIG, rad), 0.0)
    fall = _m(nt, "POWER", math.e, _m(nt, "DIVIDE", alt, -AIR_H))
    held = _range(nt, _m(nt, "ABSOLUTE", x), HALF_W - 200.0, HALF_W, 1.0, 0.0)
    roof = _range(nt, alt, WALL_H - 600.0, WALL_H, 1.0, 0.0)
    dens = _m(nt, "MULTIPLY", _m(nt, "MULTIPLY", fall, held), _m(nt, "MULTIPLY", roof, density))
    vol = nt.nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Color"].default_value = (0.42, 0.55, 0.7, 1)
    vol.inputs["Absorption Color"].default_value = (0.0, 0.0, 0.0, 1)
    # Emission scaled by density: deep haze tends to this colour, not to white.
    vol.inputs["Emission Color"].default_value = (0.03, 0.045, 0.07, 1)
    nt.links.new(dens, vol.inputs["Density"])
    nt.links.new(dens, vol.inputs["Emission Strength"])
    nt.links.new(vol.outputs[0], out.inputs["Volume"])
    return mat


def cloud_mat(name, scale, cover, color, glow, opacity, sprite=False):
    mat, nt, out = sb.node_mat(name)
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    pos = geo.outputs["Position"]
    warp = _noise(nt, pos, scale * 0.35, 3.0)
    wv = nt.nodes.new("ShaderNodeVectorMath")
    wv.operation = "MULTIPLY_ADD"
    nt.links.new(pos, wv.inputs[0])
    wv.inputs[1].default_value = (1.0, 0.25, 1.0)
    nt.links.new(warp, wv.inputs[2])
    stretched = nt.nodes.new("ShaderNodeVectorMath")
    stretched.operation = "MULTIPLY"
    stretched.inputs[1].default_value = (1.0, 0.55, 1.0)
    nt.links.new(wv.outputs[0], stretched.inputs[0])
    n = _noise(nt, stretched.outputs[0], scale, 8.0, 0.6)
    alpha = _range(nt, n, cover, cover + 0.22)
    cam = nt.nodes.new("ShaderNodeCameraData")
    near = _range(nt, cam.outputs["View Distance"], 30.0, 260.0)
    alpha = _m(nt, "MULTIPLY", alpha, near)
    if sprite:
        uv = nt.nodes.new("ShaderNodeUVMap")
        c = nt.nodes.new("ShaderNodeVectorMath")
        c.operation = "DISTANCE"
        c.inputs[1].default_value = (0.5, 0.5, 0.0)
        nt.links.new(uv.outputs[0], c.inputs[0])
        edge = _range(nt, c.outputs["Value"], 0.15, 0.5, 1.0, 0.0)
        alpha = _m(nt, "MULTIPLY", alpha, _m(nt, "MULTIPLY", edge, edge))
    alpha = _m(nt, "MULTIPLY", alpha, opacity)
    diff = nt.nodes.new("ShaderNodeBsdfDiffuse")
    diff.inputs["Color"].default_value = (*color, 1)
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*color, 1)
    em.inputs["Strength"].default_value = glow
    add = nt.nodes.new("ShaderNodeAddShader")
    nt.links.new(diff.outputs[0], add.inputs[0])
    nt.links.new(em.outputs[0], add.inputs[1])
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(alpha, mix.inputs["Fac"])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(add.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    mat.blend_method = "BLEND"
    mat.shadow_method = "NONE"
    mat.show_transparent_back = True
    mat.use_backface_culling = False
    return mat


def cloud_sprites(name, path, count, seed, mat):
    """Soft cloud cards around the descent path. path(u) -> (s, x, alt)."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    for _ in range(count):
        u = rnd.uniform(0.05, 1.12)
        s, x, alt = path(min(u, 1.0))
        s += (u - min(u, 1.0)) * 9000.0 + rnd.uniform(-500, 900)
        side = rnd.choice((-1, 1)) * rnd.uniform(60, 1600)
        alt_c = rnd.choice((1250.0, 1250.0, 2450.0, 2450.0, alt, 420.0, 700.0))
        alt_c += rnd.uniform(-180, 180)
        size = rnd.uniform(260, 1000) if alt_c > 900 else rnd.uniform(150, 420)
        c = surf(s, x + side, alt_c)
        f, up = fwd_at(s), up_at(s)
        yaw = rnd.uniform(-0.6, 0.6)
        r = f.cross(up)
        axis_r = r * math.cos(yaw) + f * math.sin(yaw)
        axis_u = up * 0.42
        vs = [bm.verts.new(c + axis_r * (dx * size) + axis_u * (dy * size)) for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        face = bm.faces.new(vs)
        for loop, co in zip(face.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
            loop[uvl].uv = co
    return _obj(name, bm, mat)


def gate(name, s, x, alt, radius, minor, mat):
    bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=minor, major_segments=96, minor_segments=10)
    ob = bpy.context.active_object
    ob.name = name
    ob.location = surf(s, x, alt)
    ob.rotation_euler = Vector((0, 0, 1)).rotation_difference(fwd_at(s)).to_euler()
    ob.data.materials.append(mat)
    return ob


def build(path_c, end_s, end_x):
    """Builds the ring section. path_c(u) gives the final descent as (s, x, alt)."""
    objs = []
    floor = arc_sheet("NarceaFloor", 0.0, -HALF_W - 200, HALF_W + 200, S_MIN, S_MAX, 60, 960, floor_mat(end_s, end_x))
    objs.append(floor)
    wm = wall_mat()
    for i, x in enumerate((-HALF_W, HALF_W)):
        objs.append(wall_sheet(f"NarceaWall{i}", x, -50.0, WALL_H, S_MIN, S_MAX, 12, 960, wm))
    lamp = sb.emit_mat("NarceaWallLamp", (1.0, 0.55, 0.22), 30.0)
    bm = bmesh.new()
    s = S_MIN
    while s < S_MAX:
        for x in (-HALF_W + 40, HALF_W - 40):
            add_box(bm, s, x, WALL_H + 30, (80, 80, 60))
        s += 3000.0
    objs.append(_obj("NarceaWallLamps", bm, lamp))

    hi = cloud_mat("CloudDeckHigh", 0.00045, 0.5, (0.36, 0.42, 0.5), 0.35, 0.85)
    lo = cloud_mat("CloudDeckLow", 0.0007, 0.56, (0.26, 0.31, 0.38), 0.25, 0.75)
    objs.append(arc_sheet("CloudHighA", 2550.0, -HALF_W, HALF_W, S_MIN, S_MAX, 30, 480, hi))
    objs.append(arc_sheet("CloudHighB", 2350.0, -HALF_W, HALF_W, S_MIN, S_MAX, 30, 480, hi))
    objs.append(arc_sheet("CloudLowA", 1320.0, -HALF_W, HALF_W, -30000, S_MAX, 30, 480, lo))
    objs.append(arc_sheet("CloudLowB", 1150.0, -HALF_W, HALF_W, -30000, S_MAX, 30, 480, lo))
    ceiling = cloud_mat("CloudCeiling", 0.00035, 0.16, (0.13, 0.15, 0.19), 0.18, 1.0)
    objs.append(arc_sheet("CloudCeiling", 1700.0, -HALF_W, HALF_W, -2000, S_MAX, 30, 480, ceiling))
    puffs = cloud_mat("CloudPuffs", 0.0022, 0.42, (0.3, 0.36, 0.44), 0.3, 0.8, sprite=True)
    objs.append(cloud_sprites("CloudPuffs", path_c, 420, 11, puffs))

    yard_dark = sb.grime_mat("YardBlock", (0.025, 0.03, 0.035), rough=(0.4, 0.7), scale=0.02, metal=0.5)
    yard_edge = sb.emit_mat("YardEdge", (0.2, 0.85, 0.95), 7.0)
    yard_amber = sb.emit_mat("YardAmber", (1.0, 0.55, 0.22), 12.0)
    rnd = random.Random(23)
    bm_b, bm_e, bm_a = bmesh.new(), bmesh.new(), bmesh.new()
    for _ in range(260):
        s = end_s + 4200.0 + rnd.uniform(-3000, 3000)
        x = end_x + rnd.uniform(-3000, 3000)
        if abs(x - end_x) < 220 and s < end_s + 2500:
            continue
        w, d, h = rnd.uniform(40, 220), rnd.uniform(40, 220), rnd.uniform(12, 140)
        add_box(bm_b, s, x, h / 2, (w, d, h))
        for dx, dy, sx, sy in ((0, d / 2, w, 3), (0, -d / 2, w, 3), (w / 2, 0, 3, d), (-w / 2, 0, 3, d)):
            add_box(bm_e, s + dy, x + dx, h + 1.5, (sx, sy, 3))
        if rnd.random() < 0.3:
            add_box(bm_a, s, x, h + 8, (6, 6, 6))
    objs.append(_obj("YardBlocks", bm_b, yard_dark))
    objs.append(_obj("YardEdges", bm_e, yard_edge))
    objs.append(_obj("YardLamps", bm_a, yard_amber))

    orange = sb.emit_mat("GateOrange", (1.0, 0.5, 0.15), 9.0)
    cyan = sb.emit_mat("GateCyan", (0.3, 0.9, 1.0), 6.0)
    objs.append(gate("GateOrange", end_s + 520.0, end_x + 15.0, 172.0, 34.0, 1.1, orange))
    for i, (ds, dx, da, r) in enumerate(((900, -48, 16, 15), (1050, 22, -6, 11), (1200, -12, 26, 10), (1450, 40, 8, 12))):
        objs.append(gate(f"GateCyan{i}", end_s + ds, end_x + dx, 175.0 + da, r, 0.8, cyan))

    bpy.ops.mesh.primitive_cube_add(size=1.0)
    air = bpy.context.active_object
    air.name = "NarceaAir"
    bm = bmesh.new()
    bm.from_mesh(air.data)
    for v in bm.verts:
        v.co = Vector((v.co.x * 2 * (HALF_W + 400), 40000.0 + v.co.y * 2 * 125000.0, 26000.0 + v.co.z * 2 * 27000.0))
    bm.to_mesh(air.data)
    bm.free()
    air.data.materials.append(air_mat())
    objs.append(air)
    return objs
