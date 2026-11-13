"""Gate 2 poker still. Mark is Rocketbox Male Adult 05. Jason is Snow."""
import math
import os
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

sys.path.insert(0, "/tmp/ash-opening-gate1")
import contact_sheets as sheets

OUT = "/home/Commodore/Documents/VisualGasic/docs/development/ash_meridian_opening/renders/gate2"
os.makedirs(OUT, exist_ok=True)
TABLE_TOP = 0.75
TABLE_NEAR = 0.36
TABLE_FAR = -0.36


def world_head(arm, name):
    pb = arm.pose.bones[name]
    return arm.matrix_world @ pb.head


def world_tail(arm, name):
    pb = arm.pose.bones[name]
    return arm.matrix_world @ pb.tail


def point_bone(arm, name, target):
    pb = arm.pose.bones[name]
    bpy.context.view_layer.update()
    world = arm.matrix_world @ pb.matrix
    head = world.translation.copy()
    desired = target - head
    if desired.length < 1e-4:
        return
    y_axis = world.col[1].xyz.normalized()
    rot = y_axis.rotation_difference(desired.normalized()).to_matrix().to_4x4()
    world = Matrix.Translation(head) @ rot @ Matrix.Translation(-head) @ world
    pb.matrix = arm.matrix_world.inverted() @ world


def swing_toward(arm, bone_name, end_name, target):
    pb = arm.pose.bones[bone_name]
    bpy.context.view_layer.update()
    head = arm.matrix_world @ pb.head
    end = world_tail(arm, end_name)
    current = end - head
    desired = target - head
    if current.length < 1e-4 or desired.length < 1e-4:
        return
    turn = current.normalized().rotation_difference(desired.normalized()).to_matrix().to_4x4()
    world = arm.matrix_world @ pb.matrix
    head_w = world.translation.copy()
    world = Matrix.Translation(head_w) @ turn @ Matrix.Translation(-head_w) @ world
    pb.matrix = arm.matrix_world.inverted() @ world


def reset_pose(arm, name):
    pb = arm.pose.bones[name]
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
    pb.location = (0.0, 0.0, 0.0)


def rotate_about_head(arm, name, turn):
    pb = arm.pose.bones[name]
    world = arm.matrix_world @ pb.matrix
    head = world.translation.copy()
    world = Matrix.Translation(head) @ turn.to_matrix().to_4x4() @ Matrix.Translation(-head) @ world
    pb.matrix = arm.matrix_world.inverted() @ world


def hand_cloud(side, mesh_name="m009_hipoly_81_bones_opacity", arm_name="Bip01"):
    """World-space center of the posed hand mesh. Bone tails sit inside the wrist."""
    mesh_obj = bpy.data.objects[mesh_name]
    group = mesh_obj.vertex_groups[f"Bip01 {side} Hand"]
    deps = bpy.context.evaluated_depsgraph_get()
    ev = mesh_obj.evaluated_get(deps)
    mesh = ev.to_mesh()
    gi = group.index
    total = Vector()
    count = 0
    for vert in mesh.vertices:
        for slot in vert.groups:
            if slot.group == gi and slot.weight > 0.5:
                total += ev.matrix_world @ vert.co
                count += 1
                break
    ev.to_mesh_clear()
    if count == 0:
        return world_tail(bpy.data.objects[arm_name], f"Bip01 {side} Hand")
    return total / count


def pose_mark_arms(arm, mesh_name="m009_hipoly_81_bones_opacity", target_y=None, palm_rolls=None, pitch=-0.55):
    """Plant each hand on its own side of the table. Elbows stay outside the chest.

    The seated rest pose hangs the hands wide and below the felt. A world-axis
    search climbs them onto the far edge. Rejected steps restore the basis
    quaternion copied after the depsgraph update; the matrix channel alone does
    not survive the next restore.
    """
    if arm.animation_data:
        arm.animation_data_clear()
    for side in ("L", "R"):
        for bone in ("UpperArm", "Forearm", "Hand"):
            reset_pose(arm, f"Bip01 {side} {bone}")
    bpy.context.view_layer.update()

    def try_turn(bone, turn, measure, accept):
        pb = arm.pose.bones[bone]
        bpy.context.view_layer.update()
        pb.rotation_mode = "QUATERNION"
        saved = pb.matrix_basis.to_quaternion().copy()
        before = measure()
        rotate_about_head(arm, bone, turn)
        bpy.context.view_layer.update()
        after = measure()
        if not accept(before, after):
            pb.rotation_quaternion = saved
            bpy.context.view_layer.update()
            return False
        return True

    for side in ("L", "R"):
        upper = f"Bip01 {side} UpperArm"
        fore = f"Bip01 {side} Forearm"
        shoulder = world_head(arm, upper)
        sign = 1.0 if shoulder.x >= 0.0 else -1.0
        # Cloud sits ~4cm above the palm. Aim it onto the felt, in from the far lip,
        # so the hand is on the table instead of hanging behind the edge.
        along = TABLE_FAR + 0.12 if target_y is None else target_y
        target = Vector((0.22 * sign, along, TABLE_TOP + 0.03))

        def measure(side=side, mesh_name=mesh_name, arm_name=arm.name):
            return hand_cloud(side, mesh_name, arm_name)

        def accept(before, after, sign=sign, target=target):
            if after.z < before.z - 0.01 and after.z < target.z:
                return False
            if after.x * sign < 0.04:
                return False
            return (after - target).length < (before - target).length - 0.003

        for _ in range(20):
            for bone in (fore, upper):
                for axis in ((1, 0, 0), (0, 1, 0), (0, 0, 1)):
                    for angle in (0.35, -0.35, 0.15, -0.15):
                        try_turn(bone, Quaternion(axis, angle), measure, accept)
        got = measure()
        elbow = world_head(arm, fore)
        print("HAND", side, tuple(round(c, 3) for c in got), "err", round((got - target).length, 3), "ELBOW", tuple(round(c, 3) for c in elbow))
    lay_palms(arm, palm_rolls, pitch)
    if mesh_name == "m009_hipoly_81_bones_opacity":
        smooth_mark()


def lay_palms(arm, rolls=None, pitch=-0.55):
    """Roll each hand onto its palm and pitch the fingers down onto the felt.

    The roll angles are the ones that made the hand mesh thinnest in Z without
    lifting the wrist off the tabletop.
    """
    if rolls is None:
        rolls = (("L", math.pi - 1.8), ("R", 1.8))
    chains = (
        "Finger1", "Finger11", "Finger12",
        "Finger2", "Finger21", "Finger22",
        "Finger3", "Finger31", "Finger32",
        "Finger4", "Finger41", "Finger42",
    )
    for side, angle in rolls:
        hand = arm.pose.bones[f"Bip01 {side} Hand"]
        hand.rotation_mode = "QUATERNION"
        hand.rotation_quaternion = hand.rotation_quaternion @ Quaternion((1.0, 0.0, 0.0), angle)
    bpy.context.view_layer.update()
    drop = Quaternion((1.0, 0.0, 0.0), pitch)
    for side in ("L", "R"):
        for bone in chains:
            name = f"Bip01 {side} {bone}"
            rotate_about_head(arm, name, drop)
            pb = arm.pose.bones[name]
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = pb.matrix_basis.to_quaternion()
    bpy.context.view_layer.update()


def material(name, color, rough=0.62, metal=0.0, emit=0.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if alpha < 1.0:
        mat.blend_method = "BLEND"
        bsdf.inputs["Alpha"].default_value = alpha
    if emit:
        bsdf.inputs["Emission"].default_value = (color[0], color[1], color[2], 1)
        bsdf.inputs["Emission Strength"].default_value = emit
    return mat


def assign(obj, mat):
    obj.data.materials.append(mat)


def box(name, location, scale, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    assign(obj, mat)
    return obj


def cylinder(name, location, radius, depth, mat):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.name = name
    assign(obj, mat)
    return obj


def import_mark():
    folder = "/tmp/ash-opening-gate1/rocketbox/male_adult_05"
    bpy.ops.import_scene.fbx(filepath=os.path.join(folder, "Male_Adult_05_facial.fbx"))
    images = {}
    for name in os.listdir(folder):
        low = name.lower()
        if low.endswith(".tga") and "color" in low:
            images[low] = bpy.data.images.load(os.path.join(folder, name))
    body = next(image for key, image in images.items() if "body" in key)
    head = next(image for key, image in images.items() if "head" in key)
    hair = next(image for key, image in images.items() if "opacity" in key)
    for mat in bpy.data.materials:
        if not mat.use_nodes or not mat.name.lower().startswith("m009"):
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


def smooth_mark():
    """Round the low-poly Rocketbox cage so the face matches Snow's soft shading.

    The mesh is already smooth-shaded. The facets are the 8k triangles, plus the
    custom normals the FBX imported to preserve that faceting.
    """
    mesh_obj = bpy.data.objects["m009_hipoly_81_bones_opacity"]
    # The viseme keys stay in the FBX for lip sync. Leaving all 176 on the
    # modifier makes every frame subdivide each key, which stalls the render.
    if mesh_obj.data.shape_keys:
        mesh_obj.shape_key_clear()
    bpy.context.view_layer.objects.active = mesh_obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.customdata_custom_splitnormals_clear()
    bpy.ops.object.mode_set(mode="OBJECT")
    for poly in mesh_obj.data.polygons:
        poly.use_smooth = True
    mod = mesh_obj.modifiers.new("RoundCage", "SUBSURF")
    mod.levels = 2
    mod.render_levels = 2
    mod.quality = 3
    armature = next(item for item in mesh_obj.modifiers if item.type == "ARMATURE")
    while mesh_obj.modifiers.find(mod.name) > mesh_obj.modifiers.find(armature.name):
        bpy.ops.object.modifier_move_up(modifier=mod.name)


def _card_image(rank, suit, path):
    from PIL import Image, ImageDraw, ImageFont

    width, height = 220, 308
    image = Image.new("RGBA", (width, height), (250, 246, 238, 255))
    draw = ImageDraw.Draw(image)
    color = (176, 28, 36, 255) if suit in ("♥", "♦") else (22, 22, 26, 255)
    draw.rounded_rectangle((6, 6, width - 7, height - 7), radius=16, outline=color, width=4)
    rank_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 48)
    suit_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 40)
    pip_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 108)
    draw.text((16, 8), rank, fill=color, font=rank_font)
    draw.text((18, 56), suit, fill=color, font=suit_font)
    draw.text((width / 2, height / 2 + 6), suit, fill=color, font=pip_font, anchor="mm")
    corner = Image.new("RGBA", (90, 110), (0, 0, 0, 0))
    corner_draw = ImageDraw.Draw(corner)
    corner_draw.text((4, 0), rank, fill=color, font=rank_font)
    corner_draw.text((6, 48), suit, fill=color, font=suit_font)
    flipped = corner.rotate(180, expand=True)
    image.paste(flipped, (width - flipped.width - 8, height - flipped.height - 6), flipped)
    image.convert("RGB").save(path)


def playing_cards():
    """Five face-up cards. The hand is a royal in mixed suits, readable as a win."""
    hand = [("A", "♠"), ("K", "♥"), ("Q", "♦"), ("J", "♣"), ("10", "♠")]
    folder = "/tmp/ash-opening-gate1/cards"
    os.makedirs(folder, exist_ok=True)
    for index, (rank, suit) in enumerate(hand):
        path = os.path.join(folder, f"card_{index}.png")
        _card_image(rank, suit, path)
        bpy.ops.mesh.primitive_plane_add(size=1, location=(-0.26 + index * 0.075, 0.20, TABLE_TOP + 0.004))
        obj = bpy.context.active_object
        obj.name = f"Card{index}"
        obj.scale = (0.057, 0.080, 1)
        obj.rotation_euler[2] = -0.42 + index * 0.18
        mat = bpy.data.materials.new(f"CardFace{index}")
        mat.use_nodes = True
        mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.42
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(path)
        mat.node_tree.links.new(tex.outputs["Color"], mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
        obj.data.materials.append(mat)


def drop_review_props():
    for name in ("ReviewTable", "ReviewSeat"):
        obj = bpy.data.objects.get(name)
        if obj is not None:
            bpy.data.objects.remove(obj, do_unlink=True)


def shift_wrists(arm, names, target):
    bpy.context.view_layer.update()
    points = [world_tail(arm, name) for name in names]
    mid = sum(points, Vector()) / len(points)
    arm.location = arm.location + (target - mid)
    bpy.context.view_layer.update()


def build_room():
    felt = material("Felt", (0.02, 0.045, 0.05), 0.78)
    wood = material("Wood", (0.08, 0.06, 0.045), 0.55)
    cyan = material("CyanEdge", (0.25, 0.83, 0.88), 0.35, emit=2.2)
    dark = material("Dark", (0.012, 0.016, 0.02), 0.7)
    wall = material("Wall", (0.03, 0.05, 0.06), 0.8)
    amber = material("Amber", (1.0, 0.62, 0.28), 0.4, emit=3.0)
    glass = material("Glass", (0.55, 0.75, 0.78), 0.08, alpha=0.35)
    metal = material("Metal", (0.35, 0.38, 0.4), 0.28, metal=0.6)

    box("Floor", (0, 0, -0.02), (6, 6, 0.04), dark)
    box("BackWall", (0, -3.2, 1.6), (6, 0.08, 3.2), wall)
    box("LeftWall", (-3.2, 0, 1.6), (0.08, 6, 3.2), wall)
    box("RightWall", (3.2, 0, 1.6), (0.08, 6, 3.2), wall)
    # The felt has to reach both sets of hands. Mark's palms land near y=-0.33
    # and Jason's near y=+0.36, so a 0.48-deep top left both of them off it.
    box("TableTop", (0, -0.065, TABLE_TOP - 0.02), (1.15, 0.97, 0.035), felt)
    box("TableBody", (0, -0.065, 0.48), (1.05, 0.88, 0.22), wood)
    box("CyanNear", (0, 0.42, TABLE_TOP), (1.16, 0.012, 0.008), cyan)
    box("CyanFar", (0, -0.55, TABLE_TOP), (1.16, 0.012, 0.008), cyan)
    box("Window", (-3.12, -0.4, 1.55), (0.02, 1.5, 0.9), material("Dock", (0.01, 0.03, 0.04), 0.4))
    for i, y in enumerate((-1.0, -0.55, -0.1)):
        box(f"DockStrip{i}", (-3.08, y, 1.95), (0.01, 0.7, 0.012), cyan)
    box("Pendant", (0, 0, 2.15), (0.28, 0.16, 0.03), amber)
    playing_cards()
    cylinder("Glass", (0.42, 0.18, TABLE_TOP + 0.045), 0.028, 0.08, glass)
    drink = material("Drink", (0.62, 0.32, 0.08), 0.18, emit=0.6)
    dark_glass = material("DarkGlass", (0.05, 0.08, 0.07), 0.15, alpha=0.85)
    bottle_amber = material("BottleAmber", (0.72, 0.38, 0.1), 0.2, emit=0.35)
    # Mark's side of the felt, clear of his left hand.
    cylinder("MarkGlass", (-0.40, -0.08, TABLE_TOP + 0.05), 0.038, 0.1, glass)
    cylinder("MarkDrink", (-0.40, -0.08, TABLE_TOP + 0.032), 0.03, 0.048, drink)
    shelf_wood = material("ShelfWood", (0.16, 0.11, 0.07), 0.5)
    box("BackShelf", (1.17, -2.98, 1.48), (1.45, 0.18, 0.035), shelf_wood)
    box("BackShelfEdge", (1.17, -2.88, 1.51), (1.46, 0.012, 0.012), cyan)
    bottles = (
        (0.52, 0.24, 0.032, bottle_amber),
        (0.74, 0.16, 0.026, glass),
        (0.96, 0.28, 0.03, dark_glass),
        (1.18, 0.19, 0.028, bottle_amber),
        (1.4, 0.25, 0.024, glass),
        (1.62, 0.15, 0.03, dark_glass),
        (1.82, 0.22, 0.027, bottle_amber),
    )
    for index, (x, height, radius, mat) in enumerate(bottles):
        cylinder(f"Bottle{index}", (x, -2.98, 1.52 + height * 0.5), radius, height, mat)
    device = box("Device", (0.18, -0.08, TABLE_TOP + 0.008), (0.09, 0.045, 0.008), metal)
    box("DeviceLamp", device.location + Vector((0.03, 0, 0.006)), (0.008, 0.008, 0.004), amber)

    for name, at in (("MarkChair", (-0.05, -0.95, 0.22)), ("JasonChair", (0.05, 0.95, 0.22))):
        seat = box(name, at, (0.28, 0.28, 0.04), dark)
        box(name + "Back", (at[0], at[1] + (0.16 if "Jason" in name else -0.16), 0.48), (0.28, 0.03, 0.28), dark)
        seat.location.z = 0.42


def add_light(name, color, energy, location, size):
    light = bpy.data.lights.new(name, "AREA")
    light.color = color
    light.energy = energy
    light.size = size
    obj = bpy.data.objects.new(name, light)
    obj.location = location
    bpy.context.scene.collection.objects.link(obj)


def build_lights_and_camera(mark, jason):
    world = bpy.data.worlds.new("BarWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.008, 0.012, 0.02, 1)
    bg.inputs[1].default_value = 0.15
    mark_head = world_head(mark, "Bip01 Head")
    jason_bone = "FK-Head" if "FK-Head" in jason.pose.bones else "Bip01 Head"
    jason_head = world_head(jason, jason_bone)
    add_light("AmberKey", (1.0, 0.52, 0.2), 90, mark_head + Vector((0.35, 0.7, 0.42)), 0.45)
    add_light("CyanRim", (0.2, 0.75, 0.88), 22, mark_head + Vector((-1.1, -0.5, 0.35)), 0.4)
    add_light("Fill", (0.55, 0.6, 0.62), 8, (0.2, 1.8, 1.7), 1.8)
    add_light("Practical", (1.0, 0.7, 0.4), 8, (0, 0, 2.05), 0.3)
    cam_data = bpy.data.cameras.new("BarCam")
    cam_data.sensor_fit = "VERTICAL"
    cam_data.angle = math.radians(42)
    cam_data.clip_start = 0.02
    cam_data.clip_end = 40
    cam = bpy.data.objects.new("BarCam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    # Over Jason's shoulder, past the cards, onto Mark.
    cam.location = jason_head + Vector((-0.95, 1.25, 0.28))
    direction = (mark_head + Vector((0.0, 0.12, -0.02))) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    print("MARK HEAD", tuple(round(c, 3) for c in mark_head))
    print("JASON HEAD", tuple(round(c, 3) for c in jason_head))
    print("CAM", tuple(round(c, 3) for c in cam.location))


def main():
    sheets.load_snow()
    sheets.hide_junk()
    sheets.sit_snow()
    jason = bpy.data.objects["RIG-Snow"]
    jason.pose.bones["FK-Head"].rotation_euler = (0.12, 0.0, 0.0)
    bpy.context.view_layer.update()
    drop_review_props()
    import_mark()
    mark = bpy.data.objects["Bip01"]
    if mark.animation_data:
        mark.animation_data_clear()
    print("MARK IMPORTED ROT", tuple(round(c, 3) for c in mark.rotation_euler))
    sheets.sit_rocket()
    drop_review_props()
    mark.scale = (0.01, 0.01, 0.01)
    mark.rotation_euler.z += math.pi
    bpy.context.view_layer.update()
    head = world_head(mark, "Bip01 Head")
    mark.location = mark.location + (Vector((0.0, -0.78, 1.16)) - head)
    bpy.context.view_layer.update()
    pose_mark_arms(mark)
    print("FEET", tuple(round(c, 3) for c in world_tail(mark, "Bip01 L Foot")))
    shift_wrists(jason, ["IK-MSTR-Wrist.L", "IK-MSTR-Wrist.R"], Vector((0.0, TABLE_NEAR, TABLE_TOP + 0.02)))
    sheets.hide_junk()
    build_room()
    build_lights_and_camera(mark, jason)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    scene.render.resolution_percentage = 100
    scene.eevee.taa_render_samples = 32
    scene.eevee.use_bloom = True
    scene.eevee.bloom_intensity = 0.035
    scene.eevee.bloom_threshold = 0.85
    scene.view_settings.view_transform = "Filmic"
    scene.view_settings.look = "Medium Contrast"
    path = os.path.join(OUT, "ash_meridian_opening_poker_still_v01.png")
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("WROTE", path)


if __name__ == "__main__":
    main()
