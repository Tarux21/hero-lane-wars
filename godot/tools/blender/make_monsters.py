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
    M["fur"] = mat("Fell", (0.30, 0.26, 0.24))
    M["fur2"] = mat("FellDunkel", (0.19, 0.16, 0.15))
    M["pink"] = mat("Hautrosa", (0.68, 0.46, 0.44))
    M["troll"] = mat("TrollHaut", (0.30, 0.38, 0.24))
    M["troll2"] = mat("TrollHautDunkel", (0.21, 0.28, 0.17))
    M["cloth"] = mat("Lumpen", (0.25, 0.18, 0.12))
    M["hydra"] = mat("HydraSchuppen", (0.34, 0.19, 0.33))
    M["hydra2"] = mat("HydraDunkel", (0.22, 0.11, 0.21))
    M["belly"] = mat("Bauchschuppen", (0.55, 0.50, 0.34))
    M["spider"] = mat("Spinne", (0.10, 0.10, 0.08))
    M["spider2"] = mat("SpinneHell", (0.20, 0.19, 0.13))
    M["tooth"] = mat("Zahn", (0.90, 0.87, 0.76))
    M["pustule"] = mat("Giftbeule", (0.5, 1.0, 0.3), emit=(0.5, 1.0, 0.25), strength=2.5)


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


def path(points, r0, r1, m, verts=7):
    n = len(points) - 1
    for i in range(n):
        limb(points[i], points[i + 1], r0 + (r1 - r0) * i / n, r0 + (r1 - r0) * (i + 1) / n, m, verts)
        if 0 < i:
            sphere(r0 + (r1 - r0) * i / n, points[i], m=m, seg=verts, rings=4)                         # Gelenk rund


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


def cyc(n, fn):
    """Laufzyklus: n+1 Schlüsselbilder über 24 Bilder (1 s), fn(i, s, c) liefert {Knochen: (rot, loc)}"""
    out = {}
    for i in range(n + 1):
        f = round(24 * i / n)
        a = i * math.tau / n
        for bn, (rot, loc) in fn(math.sin(a), math.cos(a)).items():
            out.setdefault(bn, []).append((f, rot, loc))
    return out


# ---------------------------------------------------------------- Borkengolem (Brocken)
def borkengolem():
    global cur_bone
    rnd = random.Random(21)
    cur_bone = "body"
    cone(0.55, 0.42, 0.95, (0, 0, 0.9), m="bark", verts=10)                                         # Stumpf-Körper
    cone(0.6, 0.55, 0.2, (0, 0, 0.45), m="bark2", verts=10)
    for k in range(7):                                                                              # Borkenrillen
        a = k * math.tau / 7 + 0.2
        limb((0.52 * math.cos(a), 0.52 * math.sin(a), 0.5), (0.44 * math.cos(a), 0.44 * math.sin(a), 1.32), 0.05, 0.04, "bark2", 4)
    for k in range(5):                                                                              # Moos und Pilze auf den Schultern
        a = rnd.uniform(0, math.tau)
        sphere(0.12, (0.45 * math.cos(a), 0.45 * math.sin(a), 0.7 + 0.12 * k), (1, 1, 0.5), "moss", 7, 4)
    for sx in (-1, 1):
        cone(0.04, 0.04, 0.16, (sx * 0.38, 0.05, 1.42), m="stem", verts=6)
        sphere(0.11, (sx * 0.38, 0.05, 1.52), (1, 1, 0.55), "cap", 9, 5)
    cur_bone = "head"
    cone(0.36, 0.3, 0.32, (0, 0, 1.5), m="bark", verts=9)                                           # Kopf: abgesägter Stumpf
    cone(0.3, 0.3, 0.03, (0, 0, 1.67), m="spot", verts=9)                                           # Jahresringe oben
    for sx in (-1, 1):
        sphere(0.07, (sx * 0.12, -0.3, 1.52), (1.1, 0.6, 0.8), "eye", 8, 5)
        limb((sx * 0.04, -0.33, 1.63), (sx * 0.22, -0.3, 1.58), 0.03, 0.025, "bark2", 4)
    sphere(0.09, (0, -0.31, 1.4), (1.6, 0.5, 0.5), "dark", 8, 4)
    for side, bn in ((1, "arm.L"), (-1, "arm.R")):                                                  # schwere Holzarme bis fast zum Boden
        cur_bone = bn
        limb((side * 0.55, 0, 1.2), (side * 0.72, -0.05, 0.75), 0.17, 0.15, "bark", 8)
        limb((side * 0.72, -0.05, 0.75), (side * 0.75, -0.12, 0.35), 0.15, 0.2, "bark2", 8)
        for c in (-1, 0, 1):
            limb((side * 0.75, -0.12, 0.3), (side * (0.75 + 0.08 * c), -0.22, 0.12), 0.06, 0.0, "bark2", 5)
    for side, bn in ((1, "leg.L"), (-1, "leg.R")):                                                  # Wurzelbeine
        cur_bone = bn
        limb((side * 0.26, 0, 0.5), (side * 0.3, 0, 0.08), 0.17, 0.15, "bark2", 8)
        for c in (-1, 0, 1):
            limb((side * 0.3, 0, 0.1), (side * (0.3 + 0.12 * c), -0.2 + 0.05 * abs(c), 0.0), 0.08, 0.03, "bark2", 5)
    bones = [("body", (0, 0, 0.45), (0, 0, 1.3), None), ("head", (0, 0, 1.3), (0, 0, 1.7), "body"),
             ("arm.L", (0.55, 0, 1.2), (0.75, -0.1, 0.3), "body"), ("arm.R", (-0.55, 0, 1.2), (-0.75, -0.1, 0.3), "body"),
             ("leg.L", (0.26, 0, 0.5), (0.3, 0, 0.05), "body"), ("leg.R", (-0.26, 0, 0.5), (-0.3, 0, 0.05), "body")]
    walk = cyc(4, lambda s, c: {"leg.L": ((22 * s, 0, 0), None), "leg.R": ((-22 * s, 0, 0), None),
                               "arm.L": ((-18 * s, 0, 0), None), "arm.R": ((18 * s, 0, 0), None),
                               "body": ((0, 5 * s, 0), (0, 0, 0.05 * abs(c))), "head": ((0, -4 * s, 0), None)})
    idle = {"body": [(0, (0, 0, 0), (0, 0, 0)), (24, (3, 0, 0), (0, 0, 0.02)), (48, (0, 0, 0), (0, 0, 0))],
            "head": [(0, (0, 0, -5), None), (24, (0, 0, 5), None), (48, (0, 0, -5), None)]}
    atk = {"body": [(0, (0, 0, 0), None), (7, (-10, 0, 0), None), (11, (22, 0, 0), None), (18, (0, 0, 0), None)],
           "arm.L": [(0, (0, 0, 0), None), (7, (-120, 0, 0), None), (11, (25, 0, 0), None), (18, (0, 0, 0), None)],
           "arm.R": [(0, (0, 0, 0), None), (7, (-120, 0, 0), None), (11, (25, 0, 0), None), (18, (0, 0, 0), None)]}
    export_rigged("Borkengolem", bones, {"Idle": idle, "Walk": walk, "Attack": atk})


# ---------------------------------------------------------------- Dornspinne (Schütze)
def dornspinne():
    global cur_bone
    rnd = random.Random(31)
    cur_bone = "body"
    sphere(0.42, (0, 0.38, 0.5), (1.0, 1.25, 0.85), "spider", 12, 8)                                # Hinterleib
    for k in range(8):                                                                              # leuchtende Giftbeulen und Dornen
        a = rnd.uniform(0, math.tau)
        z = rnd.uniform(0.62, 0.82)
        sphere(0.07, (0.3 * math.cos(a), 0.38 + 0.36 * math.sin(a), z), (1, 1, 0.7), "pustule", 7, 4)
    for k in range(6):
        a = rnd.uniform(0, math.tau)
        p = Vector((0.25 * math.cos(a), 0.38 + 0.3 * math.sin(a), 0.75))
        limb(tuple(p), tuple(p + Vector((0.1 * math.cos(a), 0.1 * math.sin(a), 0.22))), 0.04, 0.0, "spider2", 4)
    sphere(0.25, (0, -0.12, 0.42), (1.0, 1.1, 0.8), "spider2", 10, 7)                               # Vorderkörper
    for (x, y, z, r) in ((-0.07, -0.33, 0.5, 0.045), (0.07, -0.33, 0.5, 0.045), (-0.13, -0.29, 0.47, 0.03), (0.13, -0.29, 0.47, 0.03), (0, -0.34, 0.56, 0.03)):
        sphere(r, (x, y, z), m="eye", seg=7, rings=5)                                               # Augenkranz
    for sx in (-1, 1):                                                                              # Giftklauen
        limb((sx * 0.07, -0.33, 0.38), (sx * 0.05, -0.43, 0.25), 0.035, 0.0, "tooth", 5)
    legs = []
    for side in (1, -1):
        for k in range(4):
            bn = "leg%d.%s" % (k, "L" if side > 0 else "R")
            cur_bone = bn
            y0 = -0.22 + k * 0.13
            hip = (side * 0.2, y0, 0.45)
            ang = math.radians(-50 + k * 33)
            knee = (side * (0.2 + 0.4 * math.cos(ang)), y0 - 0.4 * math.sin(ang) * side * side, 0.75)
            foot = (side * (0.2 + 0.75 * math.cos(ang)), y0 - 0.75 * math.sin(ang), 0.0)
            limb(hip, knee, 0.05, 0.04, "spider", 6)
            limb(knee, foot, 0.04, 0.015, "spider2", 6)
            legs.append((bn, hip, foot))
    bones = [("body", (0, 0.4, 0.45), (0, -0.3, 0.45), None)] + [(bn, hip, foot, "body") for bn, hip, foot in legs]
    grpA = ["leg0.L", "leg1.R", "leg2.L", "leg3.R"]

    def wk(s, c):
        d = {"body": ((0, 0, 4 * s), (0, 0, 0.03 * abs(c)))}
        for bn, _, _ in legs:
            ph = s if bn in grpA else -s
            d[bn] = ((10 * max(0.0, ph), 0, 18 * ph), None)
        return d
    walk = cyc(4, wk)
    idle = {"body": [(0, (0, 0, 0), (0, 0, 0)), (24, (-3, 0, 0), (0, 0, 0.02)), (48, (0, 0, 0), (0, 0, 0))]}
    atk = {"body": [(0, (0, 0, 0), None), (6, (-22, 0, 0), (0, 0.05, 0.05)), (10, (10, 0, 0), (0, -0.08, 0)), (16, (0, 0, 0), None)],
           "leg0.L": [(0, (0, 0, 0), None), (6, (-35, 0, 0), None), (10, (0, 0, 0), None)],
           "leg0.R": [(0, (0, 0, 0), None), (6, (-35, 0, 0), None), (10, (0, 0, 0), None)]}
    export_rigged("Dornspinne", bones, {"Idle": idle, "Walk": walk, "Attack": atk})


# ---------------------------------------------------------------- Pestratte (Läufer)
def pestratte():
    global cur_bone
    rnd = random.Random(41)
    cur_bone = "body"
    sphere(0.3, (0, 0.05, 0.35), (0.85, 1.5, 0.8), "fur", 12, 8)
    for k in range(5):                                                                              # Pestbeulen auf dem Rücken
        sphere(0.06, (rnd.uniform(-0.12, 0.12), rnd.uniform(-0.25, 0.35), 0.58), (1, 1, 0.7), "pustule", 7, 4)
    for k in range(6):                                                                              # struppiges Fell
        limb((rnd.uniform(-0.15, 0.15), -0.2 + k * 0.1, 0.6), (rnd.uniform(-0.2, 0.2), -0.15 + k * 0.1, 0.7), 0.03, 0.0, "fur2", 4)
    cur_bone = "head"
    sphere(0.17, (0, -0.42, 0.42), (0.9, 1.1, 0.85), "fur", 10, 7)
    cone(0.12, 0.03, 0.28, (0, -0.62, 0.38), (math.radians(90), 0, 0), "fur2", 8)                   # Schnauze
    sphere(0.035, (0, -0.76, 0.38), m="pink", seg=6, rings=4)
    for sx in (-1, 1):
        sphere(0.04, (sx * 0.08, -0.53, 0.5), (1, 0.7, 1), "eye", 7, 5)
        sphere(0.07, (sx * 0.12, -0.38, 0.58), (1, 0.4, 1.1), "pink", 8, 5)                         # Ohren
        limb((sx * 0.02, -0.7, 0.33), (sx * 0.025, -0.72, 0.27), 0.02, 0.012, "tooth", 4)           # Nagezähne
    cur_bone = "tail"
    path([(0, 0.45, 0.32), (0, 0.75, 0.25), (0.08, 1.0, 0.15), (0.05, 1.25, 0.08)], 0.06, 0.015, "pink", 6)
    feet = {}
    for nm, (x, y) in {"legFL": (0.15, -0.25), "legFR": (-0.15, -0.25), "legBL": (0.17, 0.3), "legBR": (-0.17, 0.3)}.items():
        cur_bone = nm
        limb((x, y, 0.32), (x * 1.1, y - 0.04, 0.05), 0.06, 0.04, "fur2", 6)
        sphere(0.05, (x * 1.1, y - 0.08, 0.03), (1, 1.4, 0.5), "pink", 7, 4)
        feet[nm] = (x, y)
    bones = [("body", (0, 0.35, 0.36), (0, -0.3, 0.38), None), ("head", (0, -0.3, 0.4), (0, -0.75, 0.38), "body"),
             ("tail", (0, 0.42, 0.32), (0, 1.25, 0.08), "body")] + [(nm, (x, y, 0.32), (x * 1.1, y - 0.04, 0.03), "body") for nm, (x, y) in feet.items()]
    walk = cyc(4, lambda s, c: {"legFL": ((38 * s, 0, 0), None), "legFR": ((38 * s, 0, 0), None),
                               "legBL": ((-38 * s, 0, 0), None), "legBR": ((-38 * s, 0, 0), None),
                               "body": ((6 * s, 0, 0), (0, 0, 0.05 * abs(c))), "head": ((-6 * s, 0, 0), None), "tail": ((0, 0, 22 * s), None)})
    idle = {"head": [(0, (0, 0, -8), None), (12, (8, 0, 6), None), (24, (0, 0, 8), None), (36, (6, 0, -6), None), (48, (0, 0, -8), None)],
            "tail": [(0, (0, 0, -12), None), (24, (0, 0, 12), None), (48, (0, 0, -12), None)]}
    atk = {"head": [(0, (0, 0, 0), None), (4, (-25, 0, 0), None), (7, (30, 0, 0), None), (12, (0, 0, 0), None)],
           "body": [(0, (0, 0, 0), (0, 0, 0)), (4, (-6, 0, 0), (0, 0.06, 0)), (7, (8, 0, 0), (0, -0.12, 0)), (12, (0, 0, 0), (0, 0, 0))]}
    export_rigged("Pestratte", bones, {"Idle": idle, "Walk": walk, "Attack": atk})


# ---------------------------------------------------------------- Sumpftroll (Elite)
def sumpftroll():
    global cur_bone
    rnd = random.Random(51)
    cur_bone = "body"
    sphere(0.5, (0, 0.02, 0.95), (1.0, 0.85, 0.9), "troll", 12, 8)                                  # Bauch
    sphere(0.48, (0, 0.1, 1.42), (1.2, 0.85, 0.7), "troll", 12, 8)                                  # Brust, gebeugt
    for k in range(8):                                                                              # Moos und Giftblasen
        a = rnd.uniform(0, math.tau)
        z = rnd.uniform(0.8, 1.6)
        sphere(rnd.uniform(0.07, 0.12), (0.45 * math.cos(a), 0.4 * math.sin(a) + 0.05, z), (1, 1, 0.6), "moss" if k % 2 else "pustule", 7, 4)
    cone(0.42, 0.45, 0.25, (0, 0.02, 0.62), m="cloth", verts=10)                                    # Lendenschurz
    cur_bone = "head"
    sphere(0.24, (0, -0.32, 1.62), (1.0, 1.0, 0.9), "troll2", 10, 7)
    sphere(0.12, (0, -0.52, 1.6), (1.0, 1.2, 0.8), "troll2", 8, 5)                                  # Knollennase
    for sx in (-1, 1):
        sphere(0.045, (sx * 0.1, -0.5, 1.72), (1, 0.6, 1), "eye", 7, 5)
        limb((sx * 0.1, -0.48, 1.47), (sx * 0.13, -0.56, 1.62), 0.04, 0.0, "tooth", 5)              # Hauer
        limb((sx * 0.2, -0.3, 1.72), (sx * 0.36, -0.28, 1.8), 0.05, 0.0, "troll2", 5)                # Spitzohren
    for side, bn in ((1, "arm.L"), (-1, "arm.R")):                                                  # lange Arme, große Hände
        cur_bone = bn
        limb((side * 0.55, 0.05, 1.5), (side * 0.75, -0.05, 1.0), 0.13, 0.11, "troll", 8)
        limb((side * 0.75, -0.05, 1.0), (side * 0.78, -0.15, 0.5), 0.11, 0.1, "troll2", 8)
        sphere(0.15, (side * 0.78, -0.17, 0.42), (1, 1, 1), "troll2", 8, 6)
        if side < 0:                                                                                # Keule aus Wurzelholz
            limb((-0.78, -0.17, 0.42), (-0.82, -0.6, 0.1), 0.07, 0.17, "bark", 8)
            for k in range(4):
                a = k * math.tau / 4
                p = Vector((-0.82 + 0.15 * math.cos(a), -0.6, 0.1 + 0.15 * math.sin(a)))
                limb(tuple(p), tuple(p + Vector((0.12 * math.cos(a), -0.05, 0.12 * math.sin(a)))), 0.04, 0.0, "tooth", 4)
    for side, bn in ((1, "leg.L"), (-1, "leg.R")):
        cur_bone = bn
        limb((side * 0.25, 0, 0.65), (side * 0.3, 0.02, 0.1), 0.16, 0.12, "troll2", 8)
        sphere(0.14, (side * 0.3, -0.08, 0.06), (1, 1.5, 0.5), "troll2", 8, 5)
    bones = [("body", (0, 0, 0.65), (0, 0.05, 1.5), None), ("head", (0, -0.2, 1.5), (0, -0.4, 1.85), "body"),
             ("arm.L", (0.55, 0.05, 1.5), (0.78, -0.15, 0.45), "body"), ("arm.R", (-0.55, 0.05, 1.5), (-0.78, -0.15, 0.45), "body"),
             ("leg.L", (0.25, 0, 0.65), (0.3, 0, 0.06), "body"), ("leg.R", (-0.25, 0, 0.65), (-0.3, 0, 0.06), "body")]
    walk = cyc(4, lambda s, c: {"leg.L": ((26 * s, 0, 0), None), "leg.R": ((-26 * s, 0, 0), None),
                               "arm.L": ((-22 * s, 0, 0), None), "arm.R": ((22 * s, 0, 0), None),
                               "body": ((0, 7 * s, 0), (0, 0, 0.05 * abs(c))), "head": ((0, -5 * s, 0), None)})
    idle = {"body": [(0, (0, 0, 0), (0, 0, 0)), (24, (4, 0, 0), (0, 0, 0.03)), (48, (0, 0, 0), (0, 0, 0))],
            "arm.L": [(0, (0, 0, 0), None), (24, (-6, 0, 0), None), (48, (0, 0, 0), None)],
            "arm.R": [(0, (0, 0, 0), None), (24, (-6, 0, 0), None), (48, (0, 0, 0), None)]}
    atk = {"body": [(0, (0, 0, 0), None), (7, (-14, 0, 8), None), (11, (20, 0, -6), None), (18, (0, 0, 0), None)],
           "arm.R": [(0, (0, 0, 0), None), (7, (-140, 0, 0), None), (11, (30, 0, 0), None), (18, (0, 0, 0), None)],
           "arm.L": [(0, (0, 0, 0), None), (7, (20, 0, 0), None), (11, (-30, 0, 0), None), (18, (0, 0, 0), None)]}
    export_rigged("Sumpftroll", bones, {"Idle": idle, "Walk": walk, "Attack": atk})


# ---------------------------------------------------------------- Gifthydra (Boss)
def gifthydra():
    global cur_bone
    rnd = random.Random(61)
    cur_bone = "body"
    sphere(0.75, (0, 0.2, 0.75), (1.0, 1.3, 0.75), "hydra", 14, 9)                                  # massiger Leib
    sphere(0.6, (0, 0.25, 0.55), (0.9, 1.15, 0.5), "belly", 12, 6)
    for k in range(14):                                                                             # Rückenplatten und Giftbeulen
        y = -0.4 + k * 0.1
        limb((0, y, 1.25 - abs(y - 0.2) * 0.35), (0, y + 0.05, 1.5 - abs(y - 0.2) * 0.35), 0.08, 0.0, "hydra2", 4)
    for k in range(7):
        a = rnd.uniform(0, math.tau)
        sphere(0.09, (0.6 * math.cos(a), 0.2 + 0.7 * math.sin(a), 0.9), (1, 1, 0.6), "pustule", 7, 4)
    necks = [("neck.L", 0.42, -0.25), ("neck.M", 0.0, 0.0), ("neck.R", -0.42, 0.25)]
    bones = [("body", (0, 0.8, 0.75), (0, -0.4, 0.85), None)]
    for nm, x, tw in necks:
        cur_bone = nm
        base = (x * 0.8, -0.35, 1.0)
        mid = (x * 1.2, -0.7, 1.55)
        top = (x * 1.3, -0.85, 2.05 if x == 0 else 1.85)
        path([base, mid, top], 0.24, 0.14, "hydra", 9)
        for k in range(4):                                                                          # helle Bauchschuppen am Hals
            p = Vector(base).lerp(Vector(top), k / 4)
            sphere(0.12, (p.x, p.y - 0.12, p.z), (1, 0.5, 1), "belly", 7, 4)
        hn = "head" + nm[4:]
        cur_bone = hn
        hx, hy, hz = top
        sphere(0.22, (hx, hy - 0.12, hz + 0.05), (0.9, 1.3, 0.8), "hydra2", 10, 7)                  # Schlangenkopf
        cone(0.16, 0.08, 0.3, (hx, hy - 0.38, hz), (math.radians(90), 0, 0), "hydra2", 8)            # Maul
        cone(0.14, 0.06, 0.26, (hx, hy - 0.36, hz - 0.1), (math.radians(90), 0, 0), "dark", 8)      # offener Rachen
        for sx in (-1, 1):
            sphere(0.045, (hx + sx * 0.12, hy - 0.25, hz + 0.14), (1, 0.7, 1), "eye", 7, 5)
            limb((hx + sx * 0.07, hy - 0.47, hz - 0.02), (hx + sx * 0.07, hy - 0.47, hz - 0.14), 0.025, 0.0, "tooth", 4)   # Giftzähne
            limb((hx + sx * 0.1, hy, hz + 0.18), (hx + sx * 0.2, hy + 0.2, hz + 0.32), 0.05, 0.0, "hydra2", 5)            # Hörner
        bones.append((nm, base, top, "body"))
        bones.append((hn, top, (hx, hy - 0.5, hz), nm))
    cur_bone = "tail"
    path([(0, 1.05, 0.6), (0.15, 1.5, 0.4), (-0.1, 1.95, 0.25), (0.05, 2.3, 0.12)], 0.32, 0.05, "hydra", 9)
    bones.append(("tail", (0, 1.0, 0.6), (0.05, 2.3, 0.12), "body"))
    for nm, (x, y) in {"legFL": (0.55, -0.15), "legFR": (-0.55, -0.15), "legBL": (0.6, 0.6), "legBR": (-0.6, 0.6)}.items():
        cur_bone = nm
        limb((x, y, 0.55), (x * 1.15, y - 0.05, 0.08), 0.16, 0.13, "hydra2", 8)
        for c in (-1, 0, 1):
            limb((x * 1.15, y - 0.05, 0.08), (x * 1.15 + 0.08 * c, y - 0.25, 0.0), 0.05, 0.0, "tooth", 4)
        bones.append((nm, (x, y, 0.55), (x * 1.15, y - 0.05, 0.05), "body"))

    def wk(s, c):
        d = {"legFL": ((24 * s, 0, 0), None), "legBR": ((24 * s, 0, 0), None), "legFR": ((-24 * s, 0, 0), None), "legBL": ((-24 * s, 0, 0), None),
             "body": ((0, 4 * s, 0), (0, 0, 0.05 * abs(c))), "tail": ((0, 0, 20 * s), None)}
        for k, (nm, x, tw) in enumerate(necks):
            d[nm] = ((6 * math.sin(math.asin(max(-1, min(1, s))) + k), 0, 10 * s * (1 if k != 1 else -1)), None)
        return d
    walk = cyc(4, wk)
    idle = {"tail": [(0, (0, 0, -10), None), (24, (0, 0, 10), None), (48, (0, 0, -10), None)]}
    for k, (nm, x, tw) in enumerate(necks):
        o = k * 8
        idle[nm] = [(0, (0, 0, -8 + o), None), (24, (6, 0, 8 - o), None), (48, (0, 0, -8 + o), None)]
        idle["head" + nm[4:]] = [(0, (0, 0, 0), None), (24, (-10, 0, 0), None), (48, (0, 0, 0), None)]
    atk = {"body": [(0, (0, 0, 0), None), (6, (-6, 0, 0), None), (14, (5, 0, 0), None), (22, (0, 0, 0), None)]}
    for k, (nm, x, tw) in enumerate(necks):                                                        # die drei Köpfe schnappen nacheinander zu
        t0 = k * 3
        atk[nm] = [(0, (0, 0, 0), None), (t0 + 4, (-30, 0, 0), None), (t0 + 9, (35, 0, 0), None), (t0 + 15, (0, 0, 0), None)]
        atk["head" + nm[4:]] = [(0, (0, 0, 0), None), (t0 + 4, (-20, 0, 0), None), (t0 + 9, (25, 0, 0), None), (t0 + 15, (0, 0, 0), None)]
    export_rigged("Gifthydra", bones, {"Idle": idle, "Walk": walk, "Attack": atk})


ALL = [("Pilzling", pilzling), ("Borkengolem", borkengolem), ("Dornspinne", dornspinne), ("Pestratte", pestratte),
       ("Sumpftroll", sumpftroll), ("Gifthydra", gifthydra)]
for nm, fn in ALL:
    if ONLY and nm not in ONLY:
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    make_materials()
    fn()
print("FERTIG")
