"""Gate 7 bar dressing. Replaces gate2_still.build_room.

Keeps Cursor's table footprint (TABLE_TOP / NEAR / FAR), chairs and cards so
the solved hand poses still land on the felt. Everything else is new: lathe
glassware with liquid, a backlit back-bar, the dock window, a front wall so
the Jason close-up no longer looks into a void, ceiling ducts and room haze.
"""
import math
import random

import bmesh
import bpy
from mathutils import Vector

import gate2_still as g2

TABLE_TOP = g2.TABLE_TOP
ROOM = 3.2
CEIL = 2.9


def _link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def lathe(name, profile, mat, location, segs=40, smooth_angle=50.0):
    """Revolve a (radius, z) profile around Z. Closed when it starts/ends on the axis."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        if r <= 1e-6:
            rings.append([bm.verts.new((0.0, 0.0, z))])
        else:
            rings.append([
                bm.verts.new((r * math.cos(2 * math.pi * i / segs), r * math.sin(2 * math.pi * i / segs), z))
                for i in range(segs)
            ])
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        if len(a) == 1:
            for i in range(segs):
                bm.faces.new((a[0], b[i], b[(i + 1) % segs]))
        elif len(b) == 1:
            for i in range(segs):
                bm.faces.new((a[i], a[(i + 1) % segs], b[0]))
        else:
            for i in range(segs):
                bm.faces.new((a[i], a[(i + 1) % segs], b[(i + 1) % segs], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    me.use_auto_smooth = True
    me.auto_smooth_angle = math.radians(smooth_angle)
    obj = _link(bpy.data.objects.new(name, me))
    obj.location = location
    me.materials.append(mat)
    return obj


def node_mat(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    for node in list(nt.nodes):
        nt.nodes.remove(node)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    return mat, nt, out


def glass_mat(name, tint=(0.85, 0.95, 0.95), strength=0.08, rough=0.04):
    """Eevee-friendly glass: transparent body, glossy rim via Fresnel."""
    mat, nt, out = node_mat(name)
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.18
    ramp = nt.nodes.new("ShaderNodeMapRange")
    ramp.inputs["To Min"].default_value = strength
    ramp.inputs["To Max"].default_value = 0.95
    nt.links.new(lw.outputs["Fresnel"], ramp.inputs["Value"])
    transp = nt.nodes.new("ShaderNodeBsdfTransparent")
    transp.inputs["Color"].default_value = (*tint, 1)
    gloss = nt.nodes.new("ShaderNodeBsdfPrincipled")
    gloss.inputs["Base Color"].default_value = (tint[0] * 0.2, tint[1] * 0.2, tint[2] * 0.2, 1)
    gloss.inputs["Roughness"].default_value = rough
    gloss.inputs["Specular"].default_value = 0.9
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(ramp.outputs["Result"], mix.inputs["Fac"])
    nt.links.new(transp.outputs[0], mix.inputs[1])
    nt.links.new(gloss.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    mat.blend_method = "BLEND"
    mat.shadow_method = "NONE"
    mat.show_transparent_back = False
    return mat


def liquid_mat(name, color, glow=0.6, alpha=1.0):
    """Spirits read as lit from inside when a light sits behind them."""
    mat, nt, out = node_mat(name)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = 0.05
    bsdf.inputs["Specular"].default_value = 0.7
    bsdf.inputs["Emission"].default_value = (*color, 1)
    bsdf.inputs["Emission Strength"].default_value = glow
    bsdf.inputs["Alpha"].default_value = alpha
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    if alpha < 1.0:
        mat.blend_method = "BLEND"
        mat.shadow_method = "NONE"
        mat.show_transparent_back = False
    return mat


def grime_mat(name, color, rough=(0.45, 0.85), scale=6.0, metal=0.0, seam=None, seam_scale=(1.0, 1.0)):
    """Base color with noise grime and optional plate seams (brick texture)."""
    mat, nt, out = node_mat(name)
    coord = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = 8.0
    nt.links.new(coord.outputs["Object"], noise.inputs["Vector"])
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Metallic"].default_value = metal
    rmap = nt.nodes.new("ShaderNodeMapRange")
    rmap.inputs["To Min"].default_value = rough[0]
    rmap.inputs["To Max"].default_value = rough[1]
    nt.links.new(noise.outputs["Fac"], rmap.inputs["Value"])
    nt.links.new(rmap.outputs["Result"], bsdf.inputs["Roughness"])
    cmix = nt.nodes.new("ShaderNodeMixRGB")
    cmix.blend_type = "MULTIPLY"
    cmix.inputs["Color1"].default_value = (*color, 1)
    cramp = nt.nodes.new("ShaderNodeMapRange")
    cramp.inputs["To Min"].default_value = 0.55
    cramp.inputs["To Max"].default_value = 1.25
    nt.links.new(noise.outputs["Fac"], cramp.inputs["Value"])
    cmix.inputs["Fac"].default_value = 1.0
    nt.links.new(cramp.outputs["Result"], cmix.inputs["Color2"])
    color_out = cmix.outputs[0]
    if seam is not None:
        brick = nt.nodes.new("ShaderNodeTexBrick")
        brick.offset = 0.0
        brick.inputs["Color1"].default_value = (1, 1, 1, 1)
        brick.inputs["Color2"].default_value = (1, 1, 1, 1)
        brick.inputs["Mortar"].default_value = (*seam, 1)
        brick.inputs["Scale"].default_value = 1.0
        brick.inputs["Mortar Size"].default_value = 0.006
        brick.inputs["Brick Width"].default_value = seam_scale[0]
        brick.inputs["Row Height"].default_value = seam_scale[1]
        nt.links.new(coord.outputs["Object"], brick.inputs["Vector"])
        smix = nt.nodes.new("ShaderNodeMixRGB")
        smix.blend_type = "MULTIPLY"
        smix.inputs["Fac"].default_value = 1.0
        nt.links.new(color_out, smix.inputs["Color1"])
        nt.links.new(brick.outputs["Color"], smix.inputs["Color2"])
        color_out = smix.outputs[0]
    nt.links.new(color_out, bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    return mat


def emit_mat(name, color, strength):
    mat, nt, out = node_mat(name)
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*color, 1)
    em.inputs["Strength"].default_value = strength
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return mat


def text(name, body, location, rotation, size, mat, extrude=0.004, align="CENTER"):
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = body
    curve.size = size
    curve.extrude = extrude
    curve.align_x = align
    curve.align_y = "CENTER"
    try:
        curve.font = bpy.data.fonts.load("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", check_existing=True)
    except RuntimeError:
        pass
    obj = _link(bpy.data.objects.new(name, curve))
    obj.location = location
    obj.rotation_euler = rotation
    curve.materials.append(mat)
    return obj


def rounded_box(name, location, size, mat, bevel=0.004):
    obj = g2.box(name, location, size, mat)
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = bevel
    mod.segments = 2
    return obj


def tumbler(name, location, glass, liquid, fill=0.45, ice=2, ice_mat=None, r=0.037, h=0.085):
    base = 0.012
    wall = 0.0035
    profile = [
        (0.0, 0.0), (r - 0.003, 0.0), (r, 0.003), (r, h), (r - wall, h),
        (r - wall, base + 0.002), (r - wall - 0.004, base), (0.0, base),
    ]
    obj = lathe(name, profile, glass, location, segs=48, smooth_angle=35)
    if fill <= 0.0:
        return obj
    level = base + (h - base) * fill
    lr = r - wall - 0.0004
    lathe(name + "Liquid", [(0.0, base + 0.0005), (lr - 0.003, base + 0.0005), (lr, base + 0.004),
                            (lr, level - 0.002), (lr - 0.002, level), (0.0, level - 0.0008)],
          liquid, location, segs=40)
    rnd = random.Random(name)
    for i in range(ice):
        cube = rounded_box(
            f"{name}Ice{i}",
            Vector(location) + Vector((rnd.uniform(-0.01, 0.01), rnd.uniform(-0.01, 0.01), level - 0.004 + i * 0.006)),
            (0.022, 0.022, 0.02),
            ice_mat,
            bevel=0.004,
        )
        cube.rotation_euler = (rnd.uniform(-0.4, 0.4), rnd.uniform(-0.4, 0.4), rnd.uniform(0, 1.5))
    return obj


BOTTLE_SHAPES = {
    "whiskey": [(0, 0), (0.96, 0), (1.0, 0.03), (1.0, 0.62), (0.92, 0.70), (0.45, 0.78), (0.34, 0.84),
                (0.34, 0.97), (0.38, 0.975), (0.38, 1.0), (0, 1.0)],
    "wine": [(0, 0), (0.96, 0), (1.0, 0.03), (1.0, 0.56), (0.9, 0.66), (0.42, 0.76), (0.27, 0.84),
             (0.27, 0.98), (0.31, 0.985), (0.31, 1.0), (0, 1.0)],
    "squat": [(0, 0), (1.0, 0), (1.06, 0.05), (1.06, 0.48), (0.95, 0.58), (0.45, 0.64), (0.36, 0.7),
              (0.36, 0.92), (0.42, 0.93), (0.42, 1.0), (0, 1.0)],
    "flask": [(0, 0), (0.92, 0), (1.0, 0.04), (1.0, 0.66), (0.7, 0.74), (0.32, 0.79), (0.3, 0.95),
              (0.36, 0.96), (0.36, 1.0), (0, 1.0)],
}


def bottle(name, location, kind, radius, height, glass, liquid, fill, cap_mat, label_mat=None):
    shape = BOTTLE_SHAPES[kind]
    profile = [(r * radius, z * height) for r, z in shape]
    lathe(name, profile, glass, location, segs=36, smooth_angle=55)
    level = max(0.05, min(0.6, fill)) * height
    inner = [(0, 0.012), (radius * 0.9, 0.012), (radius * 0.9, level), (0, level)]
    lathe(name + "Liquid", inner, liquid, location, segs=28)
    cap_z = shape[-3][1] * height
    lathe(name + "Cap", [(0, cap_z), (radius * 0.4, cap_z), (radius * 0.4, height + 0.003), (0, height + 0.003)],
          cap_mat, location, segs=20)
    if label_mat is not None:
        lz0, lz1 = height * 0.22, height * 0.5
        lr = radius * (1.06 if kind == "squat" else 1.0) + 0.0008
        lathe(name + "Label", [(lr, lz0), (lr, lz1), (lr - 0.0004, lz1), (lr - 0.0004, lz0), (lr, lz0)],
              label_mat, location, segs=36)


def chip_stack(name, location, count, color, edge):
    mat = g2.material(name + "Mat", color, 0.35)
    rnd = random.Random(name)
    for i in range(count):
        lathe(f"{name}{i}", [(0, 0), (0.019, 0), (0.0195, 0.0015), (0.0195, 0.0025), (0.019, 0.0034), (0, 0.0034)],
              mat if i % 3 else edge,
              Vector(location) + Vector((rnd.uniform(-0.0012, 0.0012), rnd.uniform(-0.0012, 0.0012), i * 0.0034)),
              segs=24)


def build_room():
    felt = grime_mat("Felt", (0.018, 0.05, 0.055), rough=(0.75, 0.95), scale=40)
    wood = grime_mat("Wood", (0.07, 0.05, 0.036), rough=(0.4, 0.7), scale=12)
    cyan = emit_mat("CyanEdge", (0.25, 0.83, 0.88), 3.0)
    cyan_dim = emit_mat("CyanDim", (0.25, 0.83, 0.88), 0.9)
    amber = emit_mat("Amber", (1.0, 0.55, 0.22), 4.0)
    amber_soft = emit_mat("AmberSoft", (1.0, 0.52, 0.2), 1.6)
    dark = grime_mat("Dark", (0.014, 0.017, 0.02), rough=(0.5, 0.8), scale=8, metal=0.3)
    deck = grime_mat("Deck", (0.022, 0.026, 0.03), rough=(0.18, 0.7), scale=3, metal=0.5,
                     seam=(0.15, 0.15, 0.15), seam_scale=(1.2, 0.6))
    wall = grime_mat("Wall", (0.03, 0.045, 0.052), rough=(0.45, 0.85), scale=4, metal=0.25,
                     seam=(0.25, 0.25, 0.25), seam_scale=(0.9, 0.75))
    metal = grime_mat("Metal", (0.3, 0.32, 0.34), rough=(0.25, 0.5), scale=20, metal=0.85)
    glass = glass_mat("Glass")
    ice = glass_mat("Ice", tint=(0.92, 0.97, 1.0), strength=0.22, rough=0.12)
    whiskey = liquid_mat("Whiskey", (0.2, 0.055, 0.008), glow=0.1)
    window_glass = glass_mat("WindowGlass", tint=(0.6, 0.8, 0.85), strength=0.03, rough=0.02)

    g2.box("Floor", (0, 0, -0.02), (2 * ROOM, 2 * ROOM, 0.04), deck)
    g2.box("BackWall", (0, -ROOM, CEIL / 2), (2 * ROOM, 0.08, CEIL), wall)
    g2.box("FrontWall", (0, ROOM, CEIL / 2), (2 * ROOM, 0.08, CEIL), wall)
    g2.box("RightWall", (ROOM, 0, CEIL / 2), (0.08, 2 * ROOM, CEIL), wall)
    win_y0, win_y1, win_z0, win_z1 = -1.9, 0.7, 0.85, 2.25
    g2.box("LeftWallLow", (-ROOM, 0, win_z0 / 2), (0.08, 2 * ROOM, win_z0), wall)
    g2.box("LeftWallHigh", (-ROOM, 0, (win_z1 + CEIL) / 2), (0.08, 2 * ROOM, CEIL - win_z1), wall)
    g2.box("LeftWallBack", (-ROOM, (-ROOM + win_y0) / 2, (win_z0 + win_z1) / 2), (0.08, win_y0 + ROOM, win_z1 - win_z0), wall)
    g2.box("LeftWallFront", (-ROOM, (ROOM + win_y1) / 2, (win_z0 + win_z1) / 2), (0.08, ROOM - win_y1, win_z1 - win_z0), wall)
    g2.box("Ceiling", (0, 0, CEIL + 0.02), (2 * ROOM, 2 * ROOM, 0.04), dark)

    for i, x in enumerate([-2.6 + 0.65 * k for k in range(9)]):
        g2.box(f"BackRib{i}", (x, -ROOM + 0.07, CEIL / 2), (0.07, 0.07, CEIL), dark)
    for i, y in enumerate((-2.6, -2.2, 1.3, 1.95, 2.6)):
        g2.box(f"LeftRib{i}", (-ROOM + 0.07, y, CEIL / 2), (0.07, 0.07, CEIL), dark)
    g2.box("BackLine", (-1.0, -ROOM + 0.11, 2.48), (4.2, 0.01, 0.012), cyan_dim)
    g2.box("LeftLine", (-ROOM + 0.11, -0.6, 2.48), (0.01, 5.0, 0.012), cyan_dim)
    g2.box("Skirting", (0, -ROOM + 0.08, 0.05), (2 * ROOM, 0.04, 0.1), dark)

    for i, (y, r) in enumerate(((-1.6, 0.11), (-1.25, 0.07), (1.4, 0.13))):
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=2 * ROOM, location=(0, y, CEIL - r - 0.04),
                                            rotation=(0, math.pi / 2, 0))
        duct = bpy.context.active_object
        duct.name = f"Duct{i}"
        g2.assign(duct, metal)
    g2.box("CableTray", (0, 0.6, CEIL - 0.12), (2 * ROOM, 0.3, 0.03), dark)

    # Cursor's felt footprint, so the solved hands still land on it.
    g2.box("TableTop", (0, -0.065, TABLE_TOP - 0.02), (1.15, 0.97, 0.035), felt)
    g2.box("TableRail", (0, -0.065, TABLE_TOP - 0.042), (1.2, 1.02, 0.04), wood)
    g2.box("TableApron", (0, -0.065, TABLE_TOP - 0.1), (1.08, 0.9, 0.08), dark)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.07, depth=0.6, location=(0, -0.065, 0.36))
    g2.assign(bpy.context.active_object, metal)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.32, depth=0.03, location=(0, -0.065, 0.015))
    g2.assign(bpy.context.active_object, metal)
    g2.box("CyanNear", (0, 0.452, TABLE_TOP - 0.035), (1.2, 0.008, 0.008), cyan)
    g2.box("CyanFar", (0, -0.582, TABLE_TOP - 0.035), (1.2, 0.008, 0.008), cyan)

    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.42, radius2=0.16, depth=0.16,
                                    location=(0, -0.065, 2.12), rotation=(0, 0, math.pi / 4))
    shade = bpy.context.active_object
    shade.name = "PendantShade"
    shade.scale = (1.35, 0.85, 1.0)
    g2.assign(shade, dark)
    g2.box("PendantGlow", (0, -0.065, 2.045), (0.62, 0.36, 0.01), amber_soft)
    g2.box("PendantStrip", (0, -0.065, 2.04), (0.4, 0.01, 0.006), amber)
    g2.box("PendantRod", (0, -0.065, 2.5), (0.015, 0.015, 0.75), metal)

    g2.playing_cards()
    tumbler("MarkGlass", (-0.40, -0.08, TABLE_TOP), glass, whiskey, fill=0.38, ice=2, ice_mat=ice)
    tumbler("JasonGlass", (0.43, 0.2, TABLE_TOP), glass, whiskey, fill=0.2, ice=1, ice_mat=ice)
    label = grime_mat("Label", (0.55, 0.47, 0.34), rough=(0.6, 0.9), scale=60)
    cap = g2.material("CapGold", (0.55, 0.38, 0.12), 0.3, metal=0.9)
    bottle_glass = glass_mat("BottleGlass", tint=(0.9, 0.85, 0.7), strength=0.06)
    bottle("TableBottle", (-0.49, -0.40, TABLE_TOP), "whiskey", 0.038, 0.27, bottle_glass, whiskey, 0.35, cap, label)
    chip_white = g2.material("ChipWhite", (0.8, 0.78, 0.72), 0.4)
    chip_red = g2.material("ChipRed", (0.45, 0.04, 0.04), 0.4)
    chip_teal = g2.material("ChipTeal", (0.02, 0.25, 0.28), 0.4)
    chip_stack("ChipsA", (0.27, 0.05, TABLE_TOP), 9, (0.45, 0.04, 0.04), chip_white)
    chip_stack("ChipsB", (0.32, 0.09, TABLE_TOP), 6, (0.02, 0.25, 0.28), chip_white)
    chip_stack("ChipsC", (-0.3, -0.3, TABLE_TOP), 4, (0.8, 0.78, 0.72), chip_red)
    chip_stack("ChipsD", (-0.05, 0.0, TABLE_TOP), 7, (0.45, 0.04, 0.04), chip_teal)
    deck_back = g2.material("DeckBack", (0.06, 0.14, 0.16), 0.5)
    rounded_box("CardDeck", (0.06, -0.3, TABLE_TOP + 0.009), (0.064, 0.09, 0.018), deck_back, bevel=0.003).rotation_euler.z = 0.3
    device = rounded_box("Device", (0.18, -0.12, TABLE_TOP + 0.006), (0.09, 0.05, 0.01), metal, bevel=0.003)
    g2.box("DeviceScreen", device.location + Vector((-0.008, 0, 0.0052)), (0.06, 0.036, 0.001), cyan_dim)
    g2.box("DeviceLamp", device.location + Vector((0.034, 0, 0.0055)), (0.006, 0.006, 0.002), amber)

    for name, at, back in (("MarkChair", (-0.05, -0.95), -0.18), ("JasonChair", (0.05, 0.95), 0.18)):
        rounded_box(name, (at[0], at[1], 0.42), (0.46, 0.44, 0.05), dark, bevel=0.01)
        rounded_box(name + "Back", (at[0], at[1] + back, 0.75), (0.44, 0.04, 0.55), dark, bevel=0.012)
        g2.box(name + "Post", (at[0], at[1], 0.2), (0.05, 0.05, 0.4), metal)

    build_backbar(dark, metal, cyan, amber, wood, glass)
    build_dock_window(win_y0, win_y1, win_z0, win_z1, window_glass, dark, metal, cyan, cyan_dim, amber)
    build_front_wall(dark, metal, wood, cyan, cyan_dim, amber, glass, whiskey)
    build_right_wall(dark, metal, cyan_dim, amber, amber_soft)
    build_haze()


def build_backbar(dark, metal, cyan, amber, wood, glass):
    """Wall cabinet behind Mark: lit back panel, three glass shelves of bottles."""
    x0, x1 = 0.45, 2.95
    cx = (x0 + x1) / 2
    w = x1 - x0
    y = -ROOM + 0.2
    g2.box("BackbarCabinet", (cx, y + 0.08, 0.48), (w, 0.5, 0.96), dark)
    g2.box("BackbarTop", (cx, y + 0.1, 0.975), (w + 0.04, 0.56, 0.03), wood)
    for i in range(4):
        g2.box(f"BackbarDoorSeam{i}", (x0 + w * (i + 1) / 5, y + 0.335, 0.48), (0.006, 0.004, 0.8), metal)
    g2.box("BackbarKick", (cx, y + 0.34, 0.06), (w, 0.01, 0.01), amber)
    panel = emit_mat("BackbarPanel", (1.0, 0.55, 0.22), 0.32)
    g2.box("BackbarPanel", (cx, -ROOM + 0.13, 1.6), (w, 0.01, 1.22), panel)
    g2.box("BackbarFrameL", (x0, y, 1.6), (0.05, 0.3, 1.3), dark)
    g2.box("BackbarFrameR", (x1, y, 1.6), (0.05, 0.3, 1.3), dark)
    g2.box("BackbarFrameT", (cx, y, 2.27), (w + 0.05, 0.3, 0.06), dark)
    shelf_glass = glass_mat("ShelfGlass", tint=(0.7, 0.9, 0.9), strength=0.15)
    rnd = random.Random(23)
    tints = [
        ("amber", (0.9, 0.75, 0.55), (0.62, 0.27, 0.05)),
        ("green", (0.35, 0.6, 0.4), (0.2, 0.35, 0.08)),
        ("clear", (0.95, 0.97, 0.97), (0.85, 0.85, 0.8)),
        ("brown", (0.5, 0.32, 0.18), (0.35, 0.12, 0.03)),
        ("blue", (0.35, 0.55, 0.75), (0.15, 0.35, 0.55)),
    ]
    glass_cache = {}
    liquid_cache = {}
    labels = [g2.material(f"BarLabel{i}", c, 0.7) for i, c in enumerate(
        ((0.55, 0.47, 0.34), (0.08, 0.08, 0.09), (0.45, 0.08, 0.06), (0.75, 0.72, 0.66), (0.12, 0.2, 0.22)))]
    caps = [g2.material(f"BarCap{i}", c, 0.35, metal=0.8) for i, c in enumerate(
        ((0.55, 0.38, 0.12), (0.05, 0.05, 0.05), (0.35, 0.36, 0.38)))]
    index = 0
    for s, z in enumerate((1.08, 1.5, 1.9)):
        g2.box(f"Shelf{s}", (cx, y + 0.02, z - 0.008), (w - 0.06, 0.24, 0.012), shelf_glass)
        g2.box(f"ShelfEdge{s}", (cx, y + 0.142, z - 0.008), (w - 0.06, 0.004, 0.006), cyan)
        g2.box(f"ShelfLed{s}", (cx, -ROOM + 0.16, z + 0.004), (w - 0.06, 0.012, 0.006), amber)
        x = x0 + 0.1
        while x < x1 - 0.12:
            kind = rnd.choice(("whiskey", "whiskey", "wine", "squat", "flask"))
            tint_name, gtint, ltint = rnd.choice(tints)
            radius = rnd.uniform(0.032, 0.045) if kind != "squat" else rnd.uniform(0.04, 0.05)
            height = rnd.uniform(0.24, 0.33) if kind != "squat" else rnd.uniform(0.18, 0.22)
            if tint_name not in glass_cache:
                glass_cache[tint_name] = glass_mat(f"BarGlass_{tint_name}", tint=gtint, strength=0.1)
                liquid_cache[tint_name] = liquid_mat(f"BarLiquid_{tint_name}", ltint, glow=0.9)
            x += radius
            bottle(f"BarBottle{index}", (x, y + rnd.uniform(-0.05, 0.05), z), kind, radius, height,
                   glass_cache[tint_name], liquid_cache[tint_name], rnd.uniform(0.15, 0.6),
                   rnd.choice(caps), rnd.choice(labels) if rnd.random() < 0.7 else None)
            x += radius + rnd.uniform(0.012, 0.05)
            index += 1
    for i in range(5):
        lathe(f"RackGlass{i}", [(0, 0.085), (0.034, 0.085), (0.037, 0.0), (0.033, 0.0), (0.03, 0.073), (0, 0.073)],
              glass, (x0 + 0.25 + i * 0.09, y + 0.2, 0.99), segs=32)
    add_area("BackbarSpill", (1.0, 0.58, 0.26), 10, (cx, -ROOM + 0.45, 1.6), (w, 1.2), rot=(math.radians(90), 0, 0))


def build_dock_window(y0, y1, z0, z1, window_glass, dark, metal, cyan, cyan_dim, amber):
    """DOCK / 07: a viewport onto the berth, with a ship parked in the dark."""
    x = -ROOM
    cy = (y0 + y1) / 2
    cz = (z0 + z1) / 2
    g2.box("WindowGlass", (x, cy, cz), (0.01, y1 - y0, z1 - z0), window_glass)
    g2.box("WindowSill", (x + 0.06, cy, z0 - 0.02), (0.14, y1 - y0 + 0.1, 0.04), metal)
    for i, yy in enumerate((y0, cy, y1)):
        g2.box(f"Mullion{i}", (x + 0.03, yy, cz), (0.05, 0.05, z1 - z0), dark)
    g2.box("WindowHead", (x + 0.03, cy, z1), (0.05, y1 - y0 + 0.05, 0.05), dark)
    text("DockStencil", "DOCK / 07", (x + 0.03, y0 + 0.42, z1 - 0.12), (math.pi / 2, 0, math.pi / 2), 0.07, cyan_dim)
    bay_dark = grime_mat("BayDark", (0.02, 0.03, 0.035), rough=(0.3, 0.7), scale=0.6, metal=0.4)
    g2.box("BayFloor", (x - 9, cy, -1.6), (18, 16, 0.2), bay_dark)
    g2.box("BayFar", (x - 18, cy, 3), (0.2, 16, 10), bay_dark)
    g2.box("BayRoof", (x - 9, cy, 7.5), (18, 16, 0.2), bay_dark)
    g2.box("BaySideA", (x - 9, cy - 8, 3), (18, 0.2, 10), bay_dark)
    g2.box("BaySideB", (x - 9, cy + 8, 3), (18, 0.2, 10), bay_dark)
    for i in range(7):
        g2.box(f"BayLight{i}", (x - 2.0 - i * 2.2, cy - 2.6, -1.45), (0.9, 0.05, 0.03), cyan)
        g2.box(f"BayLightB{i}", (x - 2.0 - i * 2.2, cy + 2.6, -1.45), (0.9, 0.05, 0.03), cyan)
    for i in range(4):
        g2.box(f"Gantry{i}", (x - 3.5 - i * 4.0, cy, 5.5), (0.25, 14, 0.4), dark)
        g2.box(f"GantryLamp{i}", (x - 3.5 - i * 4.0, cy + 1.5, 5.25), (0.12, 0.4, 0.04), amber)
    import set_voyage
    ship = set_voyage.build_ship("DockShip", scale=0.85)
    ship.location = (x - 7.0, cy + 0.3, 0.75)
    g2.box("DockCradle", (x - 7.0, cy + 0.3, -0.45), (1.6, 0.9, 2.2), dark)
    g2.box("DockCradleLine", (x - 6.18, cy + 0.3, 0.55), (0.02, 0.92, 0.02), cyan)
    for i, zz in enumerate((0.4, 1.6, 2.8, 4.0)):
        g2.box(f"BayFarLine{i}", (x - 17.85, cy, zz), (0.02, 14, 0.04), cyan if i % 2 == 0 else cyan_dim)
    for i, yy in enumerate((-5.0, -2.0, 2.6, 5.6)):
        g2.box(f"BayFarRib{i}", (x - 17.8, cy + yy, 3), (0.1, 0.25, 10), metal)
    ship.rotation_euler = (0, 0, math.radians(70))
    add_area("BayKey", (0.4, 0.85, 0.95), 900, (x - 6, cy - 1, 5), (5, 5))
    add_area("WindowSpill", (0.35, 0.75, 0.85), 15, (x + 0.15, cy, cz), (y1 - y0, z1 - z0),
             rot=(0, math.radians(-90), 0))


def build_front_wall(dark, metal, wood, cyan, cyan_dim, amber, glass, whiskey):
    """Behind Jason: a booth, the amber BAR sign, the door and a dead wall screen."""
    y = ROOM - 0.04
    neon = emit_mat("NeonAmber", (1.0, 0.45, 0.15), 9.0)
    plate = g2.material("SignPlate", (0.02, 0.02, 0.025), 0.4, metal=0.5)
    g2.box("SignPlate", (-1.0, y - 0.03, 1.85), (0.9, 0.02, 0.36), plate)
    text("BarSign", "BAR", (-1.0, y - 0.05, 1.85), (math.pi / 2, 0, 0), 0.26, neon, extrude=0.008)
    add_point("SignGlow", (1.0, 0.48, 0.18), 18, (-1.0, y - 0.35, 1.85), 0.3)
    for i, bx in enumerate((-2.3, -1.0)):
        rounded_box(f"BoothSeat{i}", (bx, y - 0.35, 0.42), (1.1, 0.55, 0.12), wood, bevel=0.02)
        rounded_box(f"BoothBack{i}", (bx, y - 0.1, 0.85), (1.1, 0.14, 0.8), wood, bevel=0.03)
    rounded_box("BoothTable", (-1.65, y - 0.9, 0.74), (1.2, 0.6, 0.04), dark, bevel=0.01)
    g2.box("BoothTablePost", (-1.65, y - 0.9, 0.37), (0.08, 0.08, 0.72), metal)
    g2.box("BoothEdge", (-1.65, y - 1.2, 0.74), (1.2, 0.006, 0.006), cyan_dim)
    tumbler("BoothGlass", (-1.4, y - 0.95, 0.76), glass, whiskey, fill=0.12, ice=0)
    tumbler("BoothGlassB", (-1.9, y - 0.82, 0.76), glass, whiskey, fill=0.0, ice=0)
    g2.box("Door", (1.55, y - 0.02, 1.05), (1.0, 0.04, 2.1), dark)
    g2.box("DoorFrameL", (1.03, y - 0.05, 1.08), (0.03, 0.03, 2.16), cyan_dim)
    g2.box("DoorFrameR", (2.07, y - 0.05, 1.08), (0.03, 0.03, 2.16), cyan_dim)
    g2.box("DoorFrameT", (1.55, y - 0.05, 2.16), (1.07, 0.03, 0.03), cyan_dim)
    g2.box("DoorPanel", (1.55, y - 0.05, 1.1), (0.12, 0.01, 0.2), amber)
    screen = emit_mat("WallScreen", (0.25, 0.55, 0.6), 0.35)
    g2.box("ScreenBezel", (0.35, y - 0.03, 1.6), (0.8, 0.03, 0.48), dark)
    g2.box("Screen", (0.35, y - 0.05, 1.6), (0.72, 0.01, 0.4), screen)
    text("ScreenText", "NO SIGNAL", (0.35, y - 0.06, 1.6), (math.pi / 2, 0, 0), 0.06, cyan_dim)


def build_right_wall(dark, metal, cyan_dim, amber, amber_soft):
    """Pipe run, a machine glowing in the corner, a second small table."""
    x = ROOM - 0.04
    for z in (0.35, 2.55):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.05, depth=2 * ROOM, location=(x - 0.1, 0, z),
                                            rotation=(math.pi / 2, 0, 0))
        g2.assign(bpy.context.active_object, metal)
    rounded_box("Machine", (x - 0.35, 1.9, 0.9), (0.6, 0.7, 1.8), dark, bevel=0.02)
    g2.box("MachineFace", (x - 0.66, 1.9, 1.15), (0.01, 0.5, 0.7), amber_soft)
    g2.box("MachineSlot", (x - 0.66, 1.9, 0.6), (0.01, 0.3, 0.04), amber)
    rounded_box("SideTable", (x - 0.55, -1.2, 0.74), (0.7, 0.7, 0.04), dark, bevel=0.01)
    g2.box("SideTablePost", (x - 0.55, -1.2, 0.37), (0.07, 0.07, 0.72), metal)
    g2.box("SideLine", (x - 0.06, -0.6, 2.48), (0.01, 4.0, 0.012), cyan_dim)


def build_haze():
    """Thin room haze so the practicals and rim light read in the air."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, CEIL / 2))
    vol = bpy.context.active_object
    vol.name = "Haze"
    vol.scale = (2 * ROOM - 0.1, 2 * ROOM - 0.1, CEIL - 0.05)
    mat, nt, out = node_mat("HazeMat")
    pv = nt.nodes.new("ShaderNodeVolumePrincipled")
    pv.inputs["Density"].default_value = 0.014
    pv.inputs["Color"].default_value = (0.55, 0.7, 0.78, 1)
    pv.inputs["Anisotropy"].default_value = 0.45
    nt.links.new(pv.outputs[0], out.inputs["Volume"])
    vol.data.materials.append(mat)
    light = bpy.data.lights.new("PendantCone", "SPOT")
    light.color = (1.0, 0.62, 0.3)
    light.energy = 60
    light.spot_size = math.radians(70)
    light.spot_blend = 0.6
    light.shadow_soft_size = 0.2
    obj = _link(bpy.data.objects.new("PendantCone", light))
    obj.location = (0, -0.065, 2.03)


def add_area(name, color, energy, location, size, rot=(0, 0, 0)):
    light = bpy.data.lights.new(name, "AREA")
    light.shape = "RECTANGLE"
    light.size, light.size_y = size
    light.color = color
    light.energy = energy
    obj = _link(bpy.data.objects.new(name, light))
    obj.location = location
    obj.rotation_euler = rot
    return obj


def add_point(name, color, energy, location, radius):
    light = bpy.data.lights.new(name, "POINT")
    light.color = color
    light.energy = energy
    light.shadow_soft_size = radius
    obj = _link(bpy.data.objects.new(name, light))
    obj.location = location
    return obj
