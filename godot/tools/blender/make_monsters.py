# Giftwald-Brut: erzeugt die Monster-Modelle mit Skelett und Animationen (Idle, Walk, Attack) als GLB nach godot/assets/monsters/.
# Aufruf (vom Projektordner aus):
#   tools-extern/blender-4.2.9-windows-x64/blender.exe --background --python godot/tools/blender/make_monsters.py -- godot/assets/monsters [Name ...]
# Aufbau: Körperteile aus einfachen Formen, jedes Teil hängt zu 100 % an einem Knochen (starre Glieder), alles zu einem Mesh mit Skin verbunden.
# Blickrichtung: Blender -Y (wird im Spiel +Z, wie bei den übrigen Monstermodellen). Maße in Metern, die Größe im Spiel setzt game.gd.

import bpy, math, random, sys, os
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "monsters"
ONLY = ARGS[1:]
os.makedirs(OUT, exist_ok=True)
FPS = 24

M = {}
parts = []          # (Objekt, Knochen)
cur_bone = "body"


def mat(name, color, emit=None, strength=0.0, rough=0.85):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = rough
    if emit is not None:
        b.inputs["Emission Color"].default_value = (*emit, 1.0)
        b.inputs["Emission Strength"].default_value = strength
    return m


def make_materials():
    M["bark"] = mat("Rinde", (0.30, 0.21, 0.14))
    M["bark2"] = mat("RindeDunkel", (0.18, 0.13, 0.09))
    M["cap"] = mat("PilzHut", (0.52, 0.11, 0.09), rough=0.6)
    M["spot"] = mat("PilzPunkt", (0.88, 0.84, 0.74))
    M["gill"] = mat("Lamellen", (0.35, 0.28, 0.22))
    M["stem"] = mat("Stiel", (0.78, 0.72, 0.60))
    M["moss"] = mat("Moos", (0.12, 0.28, 0.12))
    M["eye"] = mat("Giftauge", (0.5, 1.0, 0.3), emit=(0.55, 1.0, 0.2), strength=4.0)
    M["dark"] = mat("Mund", (0.03, 0.02, 0.02))


def finish(obj, m):
    obj.data.materials.append(M[m])
    parts.append((obj, cur_bone))
    return obj


def cone(r1, r2, depth, loc, rot=(0, 0, 0), m="bark", verts=8):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    return finish(bpy.context.active_object, m)


def sphere(r, loc, scale=(1, 1, 1), m="bark", seg=10, rings=7):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=r, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    return finish(o, m)


def limb(p0, p1, r0, r1, m, verts=7):
    a, b = Vector(p0), Vector(p1)
    d = b - a
    rot = d.to_track_quat("Z", "Y").to_euler()
    return cone(r0, r1, d.length, (a + b) / 2.0, rot, m, verts)


def export_rigged(name, bones, actions):
    """bones: [(Name, Kopf, Schwanz, Eltern)]; actions: {Name: {Knochen: [(Bild, (rx, ry, rz), (lx, ly, lz) oder None)]}}"""
    # 1) Teile mit Knochen-Gruppe versehen und zu einem Mesh verbinden
    for o, bn in parts:
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        vg = o.vertex_groups.new(name=bn)
        vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o, _ in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0][0]
    bpy.ops.object.join()
    body = bpy.context.active_object
    body.name = name + "_Mesh"
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    # 2) Skelett
    arm_data = bpy.data.armatures.new(name + "_Rig")
    rig = bpy.data.objects.new(name, arm_data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for bn, head, tail, parent in bones:
        eb = arm_data.edit_bones.new(bn)
        eb.head = head
        eb.tail = tail
        if parent:
            eb.parent = arm_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    body.parent = rig
    mod = body.modifiers.new("Rig", "ARMATURE")
    mod.object = rig
    # 3) Animationen (je eine Action, alle werden exportiert)
    rig.animation_data_create()
    for an, tracks in actions.items():
        act = bpy.data.actions.new(an)
        act.use_fake_user = True
        rig.animation_data.action = act
        for bn, keys in tracks.items():
            pb = rig.pose.bones[bn]
            pb.rotation_mode = "XYZ"
            for (frame, rot, loc) in keys:
                pb.rotation_euler = [math.radians(v) for v in rot]
                pb.keyframe_insert("rotation_euler", frame=frame)
                if loc is not None:
                    pb.location = loc
                    pb.keyframe_insert("location", frame=frame)
            pb.rotation_euler = (0, 0, 0)
            pb.location = (0, 0, 0)
        rig.animation_data.action = None
        track = rig.animation_data.nla_tracks.new()
        track.name = an
        track.strips.new(an, 0, act)
    for o in bpy.context.selected_objects:
        o.select_set(False)
    rig.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = rig
    path_out = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path_out, export_format="GLB", use_selection=True, export_animation_mode="NLA_TRACKS",
                              export_force_sampling=True, export_frame_range=False)
    print("EXPORT", path_out, "Flaechen:", len(body.data.polygons), "Animationen:", list(actions.keys()))
    parts.clear()


# ---------------------------------------------------------------- Pilzling (Grunt)
def pilzling():
    global cur_bone
    rnd = random.Random(5)
    cur_bone = "body"                                                                                # Rindenkörper
    cone(0.22, 0.17, 0.42, (0, 0, 0.5), m="bark", verts=9)
    sphere(0.2, (0, 0, 0.33), (1.1, 1.0, 0.7), "bark2", 9, 6)
    for k in range(4):                                                                              # Moosflecken
        a = rnd.uniform(0, math.tau)
        sphere(0.07, (0.2 * math.cos(a), 0.2 * math.sin(a), 0.42 + 0.06 * k), (1, 1, 0.5), "moss", 6, 4)
    cur_bone = "head"                                                                               # Stiel mit Gesicht, großer Hut
    cone(0.16, 0.14, 0.2, (0, 0, 0.8), m="stem", verts=10)
    for sx in (-1, 1):                                                                              # Giftaugen vorn am Hut (von oben sichtbar)
        sphere(0.065, (sx * 0.12, -0.37, 1.0), (1.1, 0.7, 1.0), "eye", 8, 6)
        limb((sx * 0.05, -0.42, 1.1), (sx * 0.2, -0.39, 1.06), 0.022, 0.018, "dark", 4)                  # böse Brauen
    sphere(0.05, (0, -0.15, 0.75), (1.4, 0.5, 0.5), "dark", 7, 4)
    cone(0.42, 0.18, 0.06, (0, 0, 0.93), m="gill", verts=16)
    sphere(0.43, (0, 0, 0.95), (1.0, 1.0, 0.55), "cap", 16, 8)
    for k in range(9):                                                                              # weiße Punkte auf dem Hut
        a = rnd.uniform(0, math.tau)
        d = rnd.uniform(0.12, 0.34)
        z = 0.95 + 0.23 * math.sqrt(max(0.0, 1 - (d / 0.43) ** 2))
        sphere(0.045, (d * math.cos(a), d * math.sin(a), z), (1, 1, 0.45), "spot", 6, 4)
    for side, bn in ((1, "arm.L"), (-1, "arm.R")):                                                  # Zweigarme mit Krallen
        cur_bone = bn
        limb((side * 0.18, 0, 0.62), (side * 0.3, -0.05, 0.42), 0.05, 0.035, "bark", 6)
        for c in (-1, 0, 1):
            limb((side * 0.3, -0.05, 0.42), (side * (0.33 + 0.03 * c), -0.1 + 0.03 * c, 0.33), 0.022, 0.0, "bark2", 4)
    for side, bn in ((1, "leg.L"), (-1, "leg.R")):                                                  # Wurzelbeine
        cur_bone = bn
        limb((side * 0.1, 0, 0.32), (side * 0.12, 0, 0.06), 0.065, 0.05, "bark2", 7)
        sphere(0.08, (side * 0.12, -0.03, 0.05), (1.0, 1.4, 0.55), "bark2", 8, 5)
    bones = [
        ("body", (0, 0, 0.3), (0, 0, 0.72), None),
        ("head", (0, 0, 0.72), (0, 0, 1.1), "body"),
        ("arm.L", (0.18, 0, 0.62), (0.3, -0.05, 0.42), "body"),
        ("arm.R", (-0.18, 0, 0.62), (-0.3, -0.05, 0.42), "body"),
        ("leg.L", (0.1, 0, 0.32), (0.12, 0, 0.05), "body"),
        ("leg.R", (-0.1, 0, 0.32), (-0.12, 0, 0.05), "body"),
    ]
    # Laufen (1 s): Beine und Arme schwingen gegengleich, Körper wippt, Hut wackelt
    walk = {"leg.L": [], "leg.R": [], "arm.L": [], "arm.R": [], "body": [], "head": []}
    for i, f in enumerate((0, 6, 12, 18, 24)):
        s = math.sin(i * math.pi / 2)
        walk["leg.L"].append((f, (32 * s, 0, 0), None))
        walk["leg.R"].append((f, (-32 * s, 0, 0), None))
        walk["arm.L"].append((f, (-28 * s, 0, 0), None))
        walk["arm.R"].append((f, (28 * s, 0, 0), None))
        walk["body"].append((f, (0, 6 * s, 0), (0, 0, 0.035 * abs(math.cos(i * math.pi / 2)))))
        walk["head"].append((f, (5 * abs(s), -6 * s, 0), None))
    # Ruhe (2 s): leichtes Atmen und Hutwackeln
    idle = {"body": [(0, (0, 0, 0), (0, 0, 0)), (24, (0, 0, 0), (0, 0, 0.02)), (48, (0, 0, 0), (0, 0, 0))],
            "head": [(0, (0, 0, -4), None), (24, (4, 0, 4), None), (48, (0, 0, -4), None)],
            "arm.L": [(0, (0, 0, 0), None), (24, (-8, 0, 0), None), (48, (0, 0, 0), None)],
            "arm.R": [(0, (0, 0, 0), None), (24, (-8, 0, 0), None), (48, (0, 0, 0), None)]}
    # Angriff (0,6 s): ausholen, mit beiden Armen und dem Hut nach vorn schlagen
    atk = {"body": [(0, (0, 0, 0), None), (5, (-12, 0, 0), None), (9, (24, 0, 0), None), (15, (0, 0, 0), None)],
           "head": [(0, (0, 0, 0), None), (5, (-10, 0, 0), None), (9, (18, 0, 0), None), (15, (0, 0, 0), None)],
           "arm.L": [(0, (0, 0, 0), None), (5, (-70, 0, 0), None), (9, (60, 0, 0), None), (15, (0, 0, 0), None)],
           "arm.R": [(0, (0, 0, 0), None), (5, (-70, 0, 0), None), (9, (60, 0, 0), None), (15, (0, 0, 0), None)]}
    export_rigged("Pilzling", bones, {"Idle": idle, "Walk": walk, "Attack": atk})


ALL = [("Pilzling", pilzling)]
for nm, fn in ALL:
    if ONLY and nm not in ONLY:
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    make_materials()
    fn()
print("FERTIG")
