# Giftiger Nachtwald: erzeugt die Landschafts-Modelle (Low-Poly, mit Details) und exportiert sie als GLB nach godot/assets/props/.
# Aufruf (vom Projektordner aus):
#   tools-extern/blender-4.2.9-windows-x64/blender.exe --background --python godot/tools/blender/make_nachtwald_props.py -- godot/assets/props
# Alles ist selbst gebaut (keine fremden Dateien, keine Lizenzrechte Dritter). Feste Zufallszahlen: gleiches Ergebnis bei jedem Lauf.
# Maße in Metern, Blender Z = oben (der GLB-Export dreht es für Godot nach Y = oben).
# Version 2: detailliertere Bäume (verzweigte Äste, Wurzeln, Dornen), Knochen mit Wirbeln und Zähnen, Pilze mit Lamellen und Punkten.

import bpy, math, random, sys, os
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "props"
os.makedirs(OUT, exist_ok=True)

BONE = (0.91, 0.88, 0.80)
BARK = (0.10, 0.07, 0.13)
STONE = (0.17, 0.15, 0.19)

M = {}
parts = []


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
    M["bone"] = mat("Knochen", BONE, rough=0.7)
    M["bonedark"] = mat("KnochenAlt", (0.62, 0.58, 0.50), rough=0.8)
    M["bark"] = mat("Rinde", BARK)
    M["bark2"] = mat("RindeHell", (0.17, 0.12, 0.20))
    M["pine"] = mat("Tanne", (0.05, 0.11, 0.10))
    M["pine2"] = mat("TanneHell", (0.08, 0.17, 0.14))
    M["stone"] = mat("Stein", STONE)
    M["stone2"] = mat("SteinHell", (0.26, 0.23, 0.30))
    M["eye"] = mat("Augen", (0.02, 0.02, 0.03))
    M["stem"] = mat("Stiel", (0.72, 0.80, 0.68))
    M["cap"] = mat("PilzGlut", (0.2, 0.6, 0.2), emit=(0.35, 1.0, 0.28), strength=3.0)
    M["spot"] = mat("PilzPunkt", (0.9, 1.0, 0.8), emit=(0.8, 1.0, 0.7), strength=2.0)
    M["gill"] = mat("Lamellen", (0.12, 0.25, 0.14))
    M["fire"] = mat("Flamme", (1.0, 0.45, 0.1), emit=(1.0, 0.45, 0.1), strength=4.0)
    M["ember"] = mat("Glut", (0.8, 0.2, 0.05), emit=(1.0, 0.35, 0.08), strength=3.5)
    M["iron"] = mat("Eisen", (0.12, 0.12, 0.14), rough=0.6)
    M["crack"] = mat("RissGlut", (0.5, 0.2, 0.8), emit=(0.7, 0.35, 1.0), strength=2.5)
    M["moss"] = mat("Moos", (0.1, 0.25, 0.12))
    M["wood"] = mat("Holz", (0.24, 0.15, 0.09))
    M["wood2"] = mat("HolzAlt", (0.16, 0.11, 0.08))
    M["cloth"] = mat("StoffRot", (0.34, 0.07, 0.08))
    M["cloth2"] = mat("StoffBraun", (0.28, 0.20, 0.12))
    M["rust"] = mat("Rost", (0.38, 0.22, 0.12), rough=0.7)
    M["eyeglow"] = mat("AugenGlut", (1.0, 0.8, 0.2), emit=(1.0, 0.75, 0.15), strength=5.0)
    M["skin"] = mat("GoblinHaut", (0.33, 0.55, 0.20))
    M["skin2"] = mat("GoblinHautDunkel", (0.22, 0.40, 0.14))
    M["robe"] = mat("Gewand", (0.30, 0.19, 0.10))
    M["hat"] = mat("Hut", (0.55, 0.12, 0.10))
    M["fur"] = mat("Fell", (0.20, 0.14, 0.12))
    M["fur2"] = mat("FellHell", (0.31, 0.23, 0.19))
    M["leather"] = mat("Leder", (0.33, 0.19, 0.10), rough=0.7)
    M["potion_g"] = mat("TrankGruen", (0.2, 0.7, 0.2), emit=(0.3, 1.0, 0.3), strength=2.5)
    M["potion_b"] = mat("TrankBlau", (0.2, 0.5, 0.8), emit=(0.3, 0.7, 1.0), strength=2.5)
    M["potion_p"] = mat("TrankLila", (0.5, 0.2, 0.7), emit=(0.7, 0.3, 1.0), strength=2.5)
    M["lantern"] = mat("Laterne", (1.0, 0.8, 0.4), emit=(1.0, 0.7, 0.25), strength=4.0)
    M["steel"] = mat("Stahl", (0.55, 0.60, 0.68), rough=0.4)
    M["steel2"] = mat("StahlDunkel", (0.30, 0.33, 0.40), rough=0.45)
    M["gold"] = mat("Gold", (0.95, 0.72, 0.15), emit=(1.0, 0.7, 0.1), strength=0.7, rough=0.3)
    M["statue"] = mat("StatueStein", (0.50, 0.50, 0.57), rough=0.9)
    M["statue2"] = mat("StatueDunkel", (0.34, 0.34, 0.41), rough=0.9)
    M["eyes_g"] = mat("WaechterAugen", (0.3, 1.0, 0.3), emit=(0.3, 1.0, 0.3), strength=7.0)
    M["eyes_dim"] = mat("WaechterAugenSchwach", (0.2, 0.5, 0.2), emit=(0.25, 0.8, 0.25), strength=1.6)
    M["crackd"] = mat("Riss", (0.04, 0.04, 0.05), rough=1.0)
    M["canopy"] = mat("Dach", (0.18, 0.45, 0.22))
    M["canopy2"] = mat("DachStreifen", (0.12, 0.30, 0.15))


def finish(obj, m):
    obj.data.materials.append(M[m])
    parts.append(obj)
    return obj


def cone(r1, r2, depth, loc, rot=(0, 0, 0), m="stone", verts=8):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    return finish(bpy.context.active_object, m)


def sphere(r, loc, scale=(1, 1, 1), m="bone", seg=8, rings=6):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=r, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    return finish(o, m)


def box(size, loc, rot=(0, 0, 0), m="bone"):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = size
    return finish(o, m)


def limb(p0, p1, r0, r1, m, verts=6):
    a, b = Vector(p0), Vector(p1)
    d = b - a
    rot = d.to_track_quat("Z", "Y").to_euler()
    return cone(r0, r1, d.length, (a + b) / 2.0, rot, m, verts)


def path(points, r0, r1, m, verts=6):
    n = len(points) - 1
    for i in range(n):
        ra = r0 + (r1 - r0) * i / n
        rb = r0 + (r1 - r0) * (i + 1) / n
        limb(points[i], points[i + 1], ra, rb, m, verts)


def bone(p0, p1, r=0.13, knob=0.2, m="bone"):
    limb(p0, p1, r, r * 0.8, m, 6)
    for p in (p0, p1):
        sphere(knob, p, m=m, seg=6, rings=4)


def skull(loc, s=1.0, horns=False):
    x, y, z = loc
    sphere(0.30 * s, (x, y, z), (1.0, 1.05, 0.92), "bone", 8, 6)
    sphere(0.2 * s, (x, y - 0.1 * s, z + 0.12 * s), (1.0, 1.0, 0.7), "bone", 6, 4)                   # Stirn
    box((0.30 * s, 0.22 * s, 0.14 * s), (x, y - 0.17 * s, z - 0.19 * s), m="bone")                    # Kiefer
    for k in range(5):                                                                              # Zähne
        box((0.035 * s, 0.03 * s, 0.07 * s), (x + (k - 2) * 0.062 * s, y - 0.29 * s, z - 0.12 * s), m="bone")
    for sx in (-1, 1):
        sphere(0.085 * s, (x + sx * 0.12 * s, y - 0.25 * s, z + 0.02 * s), (1, 0.6, 1.2), "eye", 6, 4)
        box((0.05 * s, 0.07 * s, 0.1 * s), (x + sx * 0.25 * s, y - 0.1 * s, z - 0.06 * s), m="bonedark")   # Wangenknochen
    box((0.06 * s, 0.05 * s, 0.1 * s), (x, y - 0.29 * s, z - 0.03 * s), m="eye")                        # Nase
    if horns:
        for sx in (-1, 1):
            path([(x + sx * 0.2 * s, y, z + 0.2 * s), (x + sx * 0.38 * s, y, z + 0.38 * s), (x + sx * 0.42 * s, y, z + 0.65 * s)], 0.07 * s, 0.015 * s, "bonedark", 5)


def export(name):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    path_out = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path_out, export_format="GLB", use_selection=True, export_apply=True)
    print("EXPORT", path_out, "Flaechen:", len(obj.data.polygons))
    bpy.ops.object.delete()
    parts.clear()


# ---------------------------------------------------------------- Modelle
def branch(rnd, p, d, length, r, depth):
    """Ast mit Knick; verzweigt sich bis depth, am Ende Dornen"""
    if depth < 0 or length < 0.2:
        return
    seg = 2
    cur = Vector(p)
    dirv = Vector(d).normalized()
    for i in range(seg):
        dirv = (dirv + Vector((rnd.uniform(-0.35, 0.35), rnd.uniform(-0.35, 0.35), rnd.uniform(-0.05, 0.3)))).normalized()
        nxt = cur + dirv * (length / seg)
        limb(cur, nxt, r * (1.0 - i * 0.25), r * (0.75 - i * 0.25), "bark", 5)
        cur = nxt
        if i == 0 and depth > 0:
            for _ in range(2):
                side = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(0.1, 0.8)))
                branch(rnd, cur, side, length * 0.55, r * 0.5, depth - 1)
    if depth == 0:
        limb(cur, cur + dirv * 0.35, r * 0.4, 0.0, "bark2", 4)                                       # Dorn


def tree_dead():
    rnd = random.Random(11)
    cone(0.78, 0.46, 0.5, (0, 0, 0.25), m="bark", verts=8)                                           # Stammfuß
    path([(0, 0, 0.4), (0.12, 0.05, 1.4), (-0.1, 0.1, 2.5), (0.1, -0.05, 3.5), (0.0, 0.0, 4.6)], 0.46, 0.1, "bark", 7)
    for i in range(8):
        z = 1.5 + i * 0.4
        ang = rnd.uniform(0, math.tau)
        d = (math.cos(ang), math.sin(ang), rnd.uniform(0.35, 0.9))
        branch(rnd, (0.05 * math.cos(ang), 0.05 * math.sin(ang), z), d, rnd.uniform(1.1, 1.8) * (1.15 - i * 0.07), 0.13, 1)
    for a in range(6):                                                                              # Wurzeln
        ang = a * math.tau / 6 + 0.3
        path([(0.2 * math.cos(ang), 0.2 * math.sin(ang), 0.5), (0.7 * math.cos(ang), 0.7 * math.sin(ang), 0.15), (1.2 * math.cos(ang + 0.2), 1.2 * math.sin(ang + 0.2), -0.05)], 0.22, 0.05, "bark", 5)
    for k in range(5):                                                                              # Moosflecken und Pilz am Stamm
        a = rnd.uniform(0, math.tau)
        sphere(0.14, (0.4 * math.cos(a), 0.4 * math.sin(a), 0.7 + k * 0.45), (1, 1, 0.6), "moss", 5, 4)


def tree_pine():
    rnd = random.Random(13)
    path([(0, 0, 0), (0.05, 0, 1.4), (0, 0.03, 2.8), (0, 0, 4.7)], 0.28, 0.05, "bark", 6)
    tiers = [(1.65, 1.1, 10), (1.5, 1.8, 10), (1.3, 2.5, 9), (1.1, 3.2, 8), (0.85, 3.8, 7), (0.55, 4.25, 6)]
    for t, (R, z, n) in enumerate(tiers):
        off = rnd.uniform(0, math.tau)
        for k in range(n):
            ang = off + k * math.tau / n + rnd.uniform(-0.12, 0.12)
            tip = (R * math.cos(ang), R * math.sin(ang), z - 0.55 * R * 0.7)
            mid = (R * 0.5 * math.cos(ang), R * 0.5 * math.sin(ang), z - 0.15)
            limb((0, 0, z), mid, 0.2, 0.17, "pine", 5)
            limb(mid, tip, 0.17, 0.0, "pine2" if (k + t) % 2 else "pine", 5)
    limb((0, 0, 4.4), (0, 0, 5.2), 0.12, 0.0, "pine", 5)
    for a in range(3):                                                                              # tote untere Äste
        ang = a * 2.1
        limb((0, 0, 0.9 + a * 0.2), (0.7 * math.cos(ang), 0.7 * math.sin(ang), 0.7 + a * 0.2), 0.07, 0.02, "bark2", 4)


def bone_pillar():
    rnd = random.Random(2)
    cone(0.7, 0.55, 0.25, (0, 0, 0.12), m="stone", verts=8)
    for k in range(3):                                                                              # Steinbrocken am Fuß
        a = k * 2.1 + 0.4
        box((0.3, 0.25, 0.22), (0.62 * math.cos(a), 0.62 * math.sin(a), 0.1), (0, 0, a), "stone2")
    z = 0.25
    for i in range(6):                                                                              # Wirbelsäule
        cone(0.34 - i * 0.015, 0.3 - i * 0.015, 0.24, (0.03 * (i % 2 * 2 - 1), 0, z + 0.12), m="bone", verts=8)
        limb((0.03 * (i % 2 * 2 - 1), 0.28, z + 0.12), (0.03 * (i % 2 * 2 - 1), 0.5, z + 0.25), 0.07, 0.01, "bonedark", 4)    # Dornfortsatz
        for sx in (-1, 1):
            limb((sx * 0.3, 0, z + 0.12), (sx * 0.52, 0.04, z + 0.2), 0.05, 0.03, "bone", 4)                                 # Querfortsatz
        z += 0.3
    for sx in (-1, 1):                                                                              # zwei Rippen
        path([(sx * 0.3, 0, 0.9), (sx * 0.62, 0.25, 1.15), (sx * 0.52, 0.5, 1.05), (sx * 0.25, 0.55, 0.85)], 0.07, 0.03, "bone", 5)
    skull((0.0, 0.0, z + 0.32), 1.0, horns=True)
    bone((-0.75, 0.3, 0.12), (-0.35, 0.5, 0.2), 0.07, 0.11, "bonedark")                               # liegende Knochen
    bone((0.7, -0.3, 0.1), (0.4, -0.55, 0.16), 0.07, 0.11, "bonedark")


def bone_arch():
    rnd = random.Random(4)
    r = 1.7
    for layer, off in enumerate((0.0, 0.32)):
        n = 10
        pts = [(r * math.cos(math.pi * k / n), off, 0.25 + r * math.sin(math.pi * k / n)) for k in range(n + 1)]
        for a, b in zip(pts, pts[1:]):
            bone(a, b, r=0.11 - layer * 0.02, knob=0.15 - layer * 0.02)
    for sx in (-1, 1):
        cone(0.55, 0.45, 0.25, (sx * r, 0.15, 0.12), m="stone", verts=8)
        for k in range(3):
            box((0.25, 0.22, 0.2), (sx * (r + 0.5 + 0.15 * k), 0.4 * (k - 1), 0.09), (0, 0, k), "stone2")
    skull((0.0, 0.1, 0.25 + r + 0.3), 0.9, horns=True)
    for k in range(1, 10):                                                                          # Rippen zwischen den Bögen
        a = k * math.pi / 10
        limb((r * math.cos(a), 0.0, 0.25 + r * math.sin(a)), (r * math.cos(a), 0.32, 0.25 + r * math.sin(a)), 0.04, 0.04, "bonedark", 4)
    for sx in (-1, 1):                                                                              # Klauen an den Pfosten
        for k in range(3):
            limb((sx * (r - 0.1), 0.15 + 0.12 * (k - 1), 0.5), (sx * (r - 0.55), 0.15 + 0.2 * (k - 1), 0.9), 0.06, 0.0, "bonedark", 4)


def skull_pile():
    rnd = random.Random(5)
    coords = [(0, 0, 0.3), (0.5, 0.1, 0.28), (-0.46, 0.05, 0.28), (0.12, 0.5, 0.28), (-0.1, -0.46, 0.28), (0.55, -0.4, 0.26), (-0.5, 0.5, 0.26),
              (0.22, 0.05, 0.62), (-0.22, 0.12, 0.6), (0.2, -0.3, 0.6), (0.0, -0.1, 0.92)]
    for c in coords:
        skull((c[0], c[1], c[2]), rnd.uniform(0.85, 1.05), horns=(c[2] > 0.9))
    bone((-1.0, 0.2, 0.15), (0.9, -0.3, 0.2), 0.08, 0.13, "bonedark")
    bone((-0.7, -0.8, 0.12), (0.8, 0.7, 0.18), 0.08, 0.13, "bonedark")
    for a in range(5):                                                                              # Dornenranken
        ang = a * 1.3
        path([(0.9 * math.cos(ang), 0.9 * math.sin(ang), 0.05), (1.2 * math.cos(ang + 0.3), 1.2 * math.sin(ang + 0.3), 0.4), (1.1 * math.cos(ang + 0.6), 1.1 * math.sin(ang + 0.6), 0.75)], 0.07, 0.02, "bark", 4)


def mushroom_glow():
    rnd = random.Random(3)
    specs = [(0, 0, 0.95, 0.58), (0.58, 0.28, 0.65, 0.4), (-0.46, 0.42, 0.5, 0.32), (0.22, -0.55, 0.38, 0.26), (-0.55, -0.4, 0.3, 0.2), (0.9, -0.2, 0.25, 0.17)]
    for (x, y, h, r) in specs:
        path([(x, y, 0), (x + 0.08, y - 0.03, h * 0.5), (x + rnd.uniform(-0.05, 0.05), y, h)], 0.1 + 0.1 * r, 0.07, "stem", 6)
        cone(r * 1.0, r * 0.25, 0.1, (x, y, h - 0.05), m="gill", verts=10)                          # Lamellen unter dem Hut
        sphere(r, (x, y, h + 0.02), (1.0, 1.0, 0.55), "cap", 10, 5)
        for sp in range(5):
            a = rnd.uniform(0, math.tau)
            d = rnd.uniform(0.25, 0.7) * r
            sphere(r * 0.11, (x + d * math.cos(a), y + d * math.sin(a), h + r * 0.45 * (1 - (d / r) ** 2) + 0.05), m="spot", seg=5, rings=3)
    for k in range(6):                                                                              # Wurzelfäden
        a = k * 1.1
        limb((0, 0, 0.05), (0.5 * math.cos(a), 0.5 * math.sin(a), 0.0), 0.05, 0.01, "stem", 4)


def rock_dark():
    rnd = random.Random(8)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.9, location=(0, 0, 0.4))
    o = bpy.context.active_object
    for v in o.data.vertices:
        v.co += Vector((rnd.uniform(-0.14, 0.14), rnd.uniform(-0.14, 0.14), rnd.uniform(-0.1, 0.1)))
        if v.co.z < -0.1:
            v.co.z = -0.1
    o.scale = (1.2, 0.95, 0.75)
    finish(o, "stone")
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.5, location=(0.95, 0.5, 0.2))
    o2 = bpy.context.active_object
    for v in o2.data.vertices:
        v.co += Vector((rnd.uniform(-0.1, 0.1), rnd.uniform(-0.1, 0.1), rnd.uniform(-0.06, 0.06)))
        if v.co.z < -0.05:
            v.co.z = -0.05
    finish(o2, "stone2")
    for k in range(3):                                                                              # glühende Risse
        a = k * 2.0 + 0.5
        limb((0.1 * math.cos(a), 0.1 * math.sin(a), 0.6), (0.65 * math.cos(a), 0.55 * math.sin(a), 0.45), 0.025, 0.012, "crack", 3)
    sphere(0.22, (-0.5, -0.2, 0.62), (1, 1, 0.5), "moss", 5, 4)


def brazier():
    for a in range(3):
        ang = a * math.tau / 3
        path([(0.42 * math.cos(ang), 0.42 * math.sin(ang), 0), (0.3 * math.cos(ang), 0.3 * math.sin(ang), 0.5), (0.18 * math.cos(ang), 0.18 * math.sin(ang), 1.0)], 0.08, 0.05, "iron", 5)
        limb((0.42 * math.cos(ang), 0.42 * math.sin(ang), 0.0), (0.55 * math.cos(ang), 0.55 * math.sin(ang), -0.0), 0.06, 0.06, "iron", 4)
    cone(0.62, 0.4, 0.38, (0, 0, 1.08), m="iron", verts=10)
    cone(0.58, 0.0, 0.02, (0, 0, 1.28), m="ember", verts=10)
    for k in range(8):                                                                              # Zacken am Rand
        a = k * math.tau / 8
        limb((0.6 * math.cos(a), 0.6 * math.sin(a), 1.2), (0.7 * math.cos(a), 0.7 * math.sin(a), 1.5), 0.05, 0.0, "iron", 4)
    skull((0.0, -0.68, 1.1), 0.5)
    cone(0.32, 0.0, 0.75, (0, 0, 1.68), m="fire", verts=6)
    cone(0.18, 0.0, 0.55, (0.15, 0.06, 1.62), (0, 0.25, 0), "fire", 5)
    cone(0.14, 0.0, 0.45, (-0.15, -0.05, 1.58), (0, -0.25, 0), "fire", 5)


def lava_rock():
    rnd = random.Random(21)
    for i in range(6):
        a = i * math.tau / 6
        box((0.95, 0.7, 0.3 + rnd.uniform(0, 0.2)), (0.75 * math.cos(a), 0.75 * math.sin(a), 0.17), (0, 0, a + rnd.uniform(-0.3, 0.3)), "stone")
        box((0.25, 0.55, 0.12), (0.45 * math.cos(a + 0.5), 0.45 * math.sin(a + 0.5), 0.12), (0, 0, a), "stone2")
    for k in range(4):
        a = k * 1.6
        box((0.7, 0.07, 0.07), (0.3 * math.cos(a), 0.3 * math.sin(a), 0.34), (0, 0, a), "ember")
    box((0.5, 0.5, 0.12), (0, 0, 0.3), m="ember")


# ---------------------------------------------------------------- Szenen am Wegrand (Vorderseite = Blender +Y)
def ribcage(cx, cy, z0, z1, width=0.3, pairs=5, tilt=0.0):
    """Wirbelsäule mit Rippenpaaren von z0 bis z1"""
    path([(cx, cy, z0), (cx, cy + tilt * 0.5, (z0 + z1) / 2), (cx, cy + tilt, z1)], 0.07, 0.06, "bone", 5)
    for k in range(pairs):
        t = (k + 0.5) / pairs
        z = z0 + (z1 - z0) * t
        w = width * (1.0 - abs(t - 0.45) * 0.9)
        for sx in (-1, 1):
            path([(cx, cy + tilt * t, z), (cx + sx * w, cy + tilt * t + 0.12, z - 0.03), (cx + sx * w * 0.8, cy + tilt * t + 0.26, z - 0.1)], 0.035, 0.02, "bone", 4)


def pelvis(cx, cy, z):
    box((0.34, 0.16, 0.16), (cx, cy, z), m="bone")
    for sx in (-1, 1):
        sphere(0.11, (cx + sx * 0.17, cy, z - 0.02), m="bone", seg=5, rings=4)


def skel_sit():
    rnd = random.Random(31)
    pelvis(0, 0, 0.2)
    ribcage(0, -0.08, 0.3, 0.95, 0.27, 5, -0.2)
    skull((0.02, -0.28, 1.12), 0.9)
    for sx in (-1, 1):
        bone((sx * 0.14, 0.05, 0.22), (sx * 0.17, 0.78, 0.26), 0.07, 0.1)          # Oberschenkel
        bone((sx * 0.17, 0.78, 0.26), (sx * 0.2, 0.86, -0.02 + 0.07), 0.055, 0.09)    # Schienbein
        box((0.1, 0.22, 0.05), (sx * 0.2, 0.96, 0.04), m="bone")                      # Fuß
        bone((sx * 0.22, -0.12, 0.82), (sx * 0.34, 0.25, 0.4), 0.05, 0.08)           # Oberarm
        bone((sx * 0.34, 0.25, 0.4), (sx * 0.3, 0.55, 0.12), 0.045, 0.07)            # Unterarm
    limb((0.62, 0.55, 0.0), (0.9, 0.9, 0.55), 0.05, 0.05, "rust", 4)                  # Schwert daneben
    box((0.28, 0.04, 0.04), (0.84, 0.82, 0.48), m="rust")
    box((0.5, 0.35, 0.05), (0.05, 0.1, 0.02), m="cloth2")                              # Stofffetzen


def skel_impaled():
    rnd = random.Random(32)
    limb((0, 0, 0), (0, 0, 3.0), 0.09, 0.07, "wood", 6)
    limb((0, 0, 3.0), (0, 0, 3.5), 0.07, 0.0, "wood", 6)
    ribcage(0, 0.1, 1.5, 2.3, 0.28, 5, 0.1)
    pelvis(0, 0.1, 1.38)
    skull((0, 0.1, 2.62), 0.9)
    for sx in (-1, 1):
        bone((sx * 0.12, 0.1, 1.35), (sx * 0.2, 0.18, 0.55), 0.06, 0.09)
        bone((sx * 0.2, 0.18, 0.55), (sx * 0.22, 0.2, 0.0), 0.05, 0.08)
        bone((sx * 0.24, 0.1, 2.25), (sx * 0.62, 0.15, 1.9), 0.045, 0.07)
        bone((sx * 0.62, 0.15, 1.9), (sx * 0.74, 0.2, 1.45), 0.04, 0.07)
    for k in range(5):
        a = k * 1.3
        sphere(0.2, (0.5 * math.cos(a), 0.5 * math.sin(a), 0.1), (1, 1, 0.5), "stone", 5, 4)      # Steine am Fuß


def skel_hang():
    for sx in (-1, 1):
        limb((sx * 1.0, 0, 0), (sx * 1.0, 0, 3.3), 0.11, 0.09, "wood", 6)
    limb((-1.15, 0, 3.25), (1.15, 0, 3.25), 0.09, 0.09, "wood", 6)
    limb((-0.9, 0, 3.1), (-0.5, 0, 3.25), 0.05, 0.05, "wood2", 4)                    # Strebe
    limb((0, 0, 3.25), (0, 0, 2.55), 0.025, 0.025, "cloth2", 4)                       # Strick
    ribcage(0, 0, 1.55, 2.3, 0.25, 5, 0.0)
    pelvis(0, 0, 1.45)
    skull((0, 0, 2.56), 0.85)
    for sx in (-1, 1):
        bone((sx * 0.11, 0, 1.4), (sx * 0.13, 0.05, 0.62), 0.06, 0.09)
        bone((sx * 0.13, 0.05, 0.62), (sx * 0.14, 0.08, 0.02), 0.05, 0.08)
        bone((sx * 0.24, 0, 2.2), (sx * 0.3, 0.05, 1.6), 0.045, 0.07)
        bone((sx * 0.3, 0.05, 1.6), (sx * 0.32, 0.08, 1.05), 0.04, 0.07)
    box((0.9, 0.5, 0.1), (0, 0, 0.04), m="stone")


def cage_skel():
    limb((0, -0.9, 0), (0, -0.9, 3.3), 0.1, 0.08, "wood", 6)
    limb((0, -0.9, 3.3), (0, -0.05, 3.3), 0.08, 0.08, "wood", 6)
    limb((0, 0, 3.3), (0, 0, 2.95), 0.025, 0.025, "iron", 4)
    for k in range(9):                                                                              # Gitterstäbe
        a = k * math.tau / 9
        limb((0.42 * math.cos(a), 0.42 * math.sin(a), 1.7), (0.42 * math.cos(a), 0.42 * math.sin(a), 2.95), 0.025, 0.025, "iron", 4)
    for z in (1.75, 2.35, 2.92):
        cone(0.44, 0.44, 0.05, (0, 0, z), m="iron", verts=12)
    sphere(0.22, (0, 0, 2.05), (1, 1, 0.5), "bonedark", 6, 4)
    ribcage(0, 0, 1.85, 2.25, 0.18, 3, 0.0)
    skull((0.02, -0.02, 2.5), 0.7)
    cone(0.44, 0.0, 0.2, (0, 0, 1.6), m="iron", verts=12)


def wagon():
    rnd = random.Random(41)
    box((2.3, 1.2, 0.18), (0, 0, 0.85), (0.0, 0.08, 0.05), "wood")                              # Ladefläche
    for sy in (-1, 1):
        box((2.3, 0.1, 0.5), (0, sy * 0.58, 1.12), (0.0, 0.08, 0.05), "wood2")                   # Seitenbretter
    box((0.1, 1.2, 0.5), (-1.12, 0, 1.12), m="wood2")
    for k in range(4):                                                                              # zerbrochene Latten
        limb((0.9 + 0.1 * k, -0.5 + 0.3 * k, 1.1), (1.15 + 0.1 * k, -0.4 + 0.3 * k, 1.55), 0.04, 0.03, "wood2", 4)
    for sy in (-1,):                                                                                # ein Rad steht, eines fehlt
        cone(0.62, 0.62, 0.12, (-0.5, sy * 0.75, 0.62), (math.pi / 2, 0, 0), "wood2", 12)
        cone(0.14, 0.14, 0.2, (-0.5, sy * 0.75, 0.62), (math.pi / 2, 0, 0), "iron", 8)
        for k in range(6):
            a = k * math.pi / 6
            limb((-0.5 + 0.55 * math.cos(a), sy * 0.8, 0.62 + 0.55 * math.sin(a)), (-0.5 - 0.55 * math.cos(a), sy * 0.8, 0.62 - 0.55 * math.sin(a)), 0.04, 0.04, "wood", 4)
    cone(0.62, 0.62, 0.12, (0.4, 1.1, 0.35), (0.3, 0.2, 0.5), "wood2", 12)                        # abgefallenes Rad
    for sy in (-1, 1):                                                                              # Deichsel
        limb((1.0, sy * 0.35, 0.6), (2.6, sy * 0.3, 0.05), 0.07, 0.06, "wood", 5)
    limb((0.9, 0.2, 0.9), (1.2, 0.2, 0.2), 0.05, 0.04, "wood2", 4)
    for k in range(3):
        sphere(0.3, (-0.4 + 0.4 * k, rnd.uniform(-0.2, 0.2), 1.1), (1, 1, 0.8), "cloth2", 6, 4)  # Säcke
    skull((0.6, 0.3, 1.1), 0.6)


def barrels():
    for (x, y, h, r) in [(0, 0, 0.9, 0.42), (0.85, 0.15, 0.9, 0.42), (0.35, 0.8, 0.8, 0.38)]:
        cone(r, r, h, (x, y, h / 2), m="wood", verts=10)
        for z in (0.15, 0.75 * h):
            cone(r + 0.02, r + 0.02, 0.07, (x, y, z), m="iron", verts=10)
        cone(r - 0.04, r - 0.04, 0.03, (x, y, h), m="wood2", verts=10)
    box((0.7, 0.7, 0.6), (-0.7, 0.55, 0.3), (0, 0, 0.5), "wood2")
    box((0.6, 0.6, 0.5), (-0.65, 0.5, 0.85), (0, 0, 0.1), "wood")
    sphere(0.32, (1.3, -0.5, 0.25), (1, 1, 0.8), "cloth2", 6, 4)
    limb((1.5, 0.5, 0.05), (1.9, 0.9, 0.5), 0.04, 0.04, "wood2", 4)


def tent():
    rnd = random.Random(51)
    for sx in (-1, 1):                                                                              # zusammengesunkenes Zelt
        box((2.0, 0.05, 1.5), (0, sx * 0.55, 0.65), (sx * -0.9, 0, 0), "cloth2")
    box((0.05, 1.2, 1.2), (-1.0, 0, 0.5), (0, 0, 0.1), "cloth")
    limb((-1.0, 0, 0.0), (-1.0, 0, 1.35), 0.05, 0.05, "wood", 4)
    limb((1.0, 0, 0.0), (0.9, 0.1, 1.0), 0.05, 0.04, "wood2", 4)
    limb((0.9, 0.1, 1.0), (1.3, 0.3, 1.3), 0.04, 0.03, "wood2", 4)
    box((1.2, 0.04, 0.05), (0.2, 0.0, 1.15), (0, 0, 0.1), "wood2")
    for k in range(4):                                                                              # Fetzen
        box((0.4, 0.3, 0.02), (0.9 + 0.3 * k, 0.9 - 0.4 * k, 0.03), (0, 0, k), "cloth")
    limb((-0.6, -1.0, 0.0), (-0.6, -1.0, 0.5), 0.04, 0.04, "wood", 4)


def campfire():
    rnd = random.Random(61)
    for k in range(9):
        a = k * math.tau / 9
        box((0.34, 0.26, 0.24), (0.85 * math.cos(a), 0.85 * math.sin(a), 0.12), (0, 0, a + 0.3), "stone")
    for k in range(4):
        a = k * 0.9 + 0.3
        limb((0.7 * math.cos(a), 0.7 * math.sin(a), 0.2), (-0.6 * math.cos(a), -0.6 * math.sin(a), 0.32), 0.1, 0.08, "bark", 5)
    cone(0.7, 0.0, 0.03, (0, 0, 0.2), m="ember", verts=10)
    for k in range(3):
        a = k * 2.1
        box((0.12, 0.12, 0.12), (0.3 * math.cos(a), 0.3 * math.sin(a), 0.3), (0.3, 0.3, a), "ember")
    limb((1.5, 0.3, 0.0), (1.2, 0.3, 1.0), 0.04, 0.04, "wood2", 4)                                  # Bratspieß
    limb((1.2, 0.3, 1.0), (-0.1, 0.3, 1.0), 0.03, 0.03, "wood2", 4)
    skull((-1.4, -0.8, 0.28), 0.6)


def banner():
    limb((0, 0, 0), (0, 0, 3.8), 0.08, 0.06, "wood", 6)
    limb((-0.7, 0, 3.4), (0.7, 0, 3.4), 0.05, 0.05, "wood", 5)
    box((1.15, 0.04, 1.6), (0, 0.02, 2.55), (0.04, 0, 0.0), "cloth")
    for k in range(4):                                                                              # zerfetzter Saum
        box((0.2, 0.04, 0.3 + 0.1 * (k % 2)), (-0.45 + 0.3 * k, 0.02, 1.62 - 0.05 * (k % 2)), (0, 0, 0.1 * (k - 2)), "cloth")
    skull((0, 0.08, 2.7), 0.8)
    limb((0, 0, 3.8), (0, 0, 4.2), 0.06, 0.0, "iron", 4)
    box((1.0, 0.6, 0.1), (0, 0, 0.04), m="stone")


def sword_grave():
    rnd = random.Random(71)
    for k, (x, y, tilt) in enumerate([(0, 0, 0.12), (0.55, 0.3, -0.2), (-0.5, 0.35, 0.3)]):
        box((0.1, 0.03, 1.4), (x, y, 0.75), (tilt, 0, 0.3 * k), "rust")
        box((0.5, 0.06, 0.07), (x - tilt * 0.4, y, 1.35), (tilt, 0, 0.3 * k), "iron")
        limb((x - tilt * 0.45, y, 1.38), (x - tilt * 0.55, y, 1.7), 0.035, 0.035, "wood", 4)
    sphere(0.28, (0.0, 0.7, 0.2), (1, 1, 0.9), "rust", 6, 4)                                       # Helm
    box((0.18, 0.04, 0.24), (0.0, 0.52, 0.22), m="eye")
    for k in range(8):
        a = k * math.tau / 8
        sphere(0.2, (0.8 * math.cos(a), 0.8 * math.sin(a), 0.1), (1, 1, 0.6), "stone", 5, 4)


def totem():
    limb((0, 0, 0), (0, 0, 3.4), 0.14, 0.12, "wood", 7)
    for z, s in ((0.9, 1.0), (1.8, 0.9), (2.7, 1.1)):
        skull((0, 0.12, z), s, horns=(z > 2.5))
        cone(0.2, 0.2, 0.06, (0, 0, z - 0.35), m="bonedark", verts=8)
    for sx in (-1, 1):
        for k in range(3):
            limb((sx * 0.14, 0, 3.1 - 0.12 * k), (sx * (0.5 + 0.05 * k), 0.05, 2.5 - 0.3 * k), 0.035, 0.0, "cloth" if k % 2 else "bonedark", 4)    # Federn und Bänder
    limb((0, 0, 3.4), (0, 0, 3.9), 0.1, 0.0, "bonedark", 5)
    for k in range(4):
        a = k * 1.6
        sphere(0.2, (0.5 * math.cos(a), 0.5 * math.sin(a), 0.1), (1, 1, 0.6), "stone", 5, 4)


def stone_circle():
    rnd = random.Random(81)
    for k in range(7):
        a = k * math.tau / 7
        h = rnd.uniform(1.4, 2.2)
        box((0.55, 0.35, h), (1.6 * math.cos(a), 1.6 * math.sin(a), h / 2), (rnd.uniform(-0.1, 0.1), rnd.uniform(-0.1, 0.1), a), "stone")
        box((0.2, 0.05, h * 0.5), (1.6 * math.cos(a) * 0.93, 1.6 * math.sin(a) * 0.93, h * 0.55), (0, 0, a), "crack")
    cone(0.9, 0.9, 0.12, (0, 0, 0.06), m="stone2", verts=10)
    for k in range(6):
        a = k * math.pi / 3
        box((0.7, 0.06, 0.04), (0.4 * math.cos(a), 0.4 * math.sin(a), 0.14), (0, 0, a), "crack")
    cone(0.18, 0.0, 0.5, (0, 0, 0.4), m="crack", verts=6)


def torch():
    limb((0, 0, 0), (0, 0, 2.2), 0.07, 0.06, "wood", 6)
    cone(0.2, 0.12, 0.3, (0, 0, 2.3), m="iron", verts=8)
    cone(0.16, 0.0, 0.55, (0, 0, 2.7), m="fire", verts=6)
    cone(0.1, 0.0, 0.4, (0.07, 0.03, 2.65), (0, 0.2, 0), "fire", 5)
    for k in range(3):
        a = k * 2.1
        limb((0, 0, 0.3), (0.35 * math.cos(a), 0.35 * math.sin(a), 0.0), 0.05, 0.03, "wood2", 4)


def eyes():
    for k, (x, z) in enumerate([(0, 0.5), (0.5, 0.65), (-0.45, 0.35)]):
        for sx in (-1, 1):
            sphere(0.045, (x + sx * 0.1, 0.0, z), (1, 0.6, 1.3), "eyeglow", 5, 3)


# ---------------------------------------------------------------- Goblin-Händler-Camp (Vorderseite = Blender +Y)
def goblin_merchant():
    """kleiner grüner Händler; rechte Hand am Mund ("Pst!")"""
    cone(0.46, 0.2, 1.0, (0, 0, 0.5), m="robe", verts=9)                                           # Gewand
    cone(0.5, 0.46, 0.08, (0, 0, 0.06), m="leather", verts=9)                                       # Saum
    box((0.5, 0.1, 0.12), (0, 0.05, 0.62), m="leather")                                             # Gürtel
    box((0.12, 0.08, 0.14), (0, 0.11, 0.62), m="lantern")                                           # Schnalle
    sphere(0.28, (0, 0.02, 1.32), (1.0, 0.95, 0.95), "skin", 10, 7)                                # Kopf
    for sx in (-1, 1):                                                                              # große spitze Ohren
        path([(sx * 0.24, 0.0, 1.36), (sx * 0.55, -0.06, 1.46), (sx * 0.78, -0.08, 1.58)], 0.1, 0.0, "skin", 5)
        sphere(0.07, (sx * 0.62, -0.06, 1.48), (1, 0.4, 1), "skin2", 5, 3)
    cone(0.07, 0.0, 0.22, (0, 0.3, 1.28), (math.pi / 2, 0, 0), "skin2", 6)                          # Nase
    for sx in (-1, 1):
        sphere(0.065, (sx * 0.12, 0.25, 1.4), (1, 0.6, 1.1), "eyeglow", 6, 4)
        box((0.14, 0.03, 0.04), (sx * 0.12, 0.26, 1.48), (0, 0, sx * 0.25), "skin2")                # Brauen
    box((0.2, 0.03, 0.04), (0, 0.27, 1.2), m="eye")                                                 # Mund
    for k in range(3):                                                                              # Zähnchen
        box((0.025, 0.02, 0.04), (-0.05 + k * 0.05, 0.27, 1.22), m="bone")
    cone(0.34, 0.0, 0.2, (0, 0, 1.54), (0, 0, 0), "hat", 9)                                         # Mütze mit Bommel
    path([(0, 0, 1.58), (0.1, -0.1, 1.82), (0.22, -0.2, 1.78)], 0.15, 0.05, "hat", 7)
    sphere(0.07, (0.24, -0.2, 1.76), m="lantern", seg=5, rings=4)
    path([(-0.22, 0, 1.15), (-0.5, 0.15, 0.8), (-0.55, 0.3, 0.55)], 0.07, 0.05, "robe", 5)         # linker Arm
    sphere(0.07, (-0.55, 0.32, 0.52), m="skin", seg=5, rings=4)
    path([(0.22, 0, 1.15), (0.42, 0.18, 1.2), (0.12, 0.3, 1.22)], 0.07, 0.05, "robe", 5)            # rechter Arm zum Mund
    sphere(0.07, (0.1, 0.3, 1.22), m="skin", seg=5, rings=4)
    box((0.02, 0.04, 0.1), (0.07, 0.31, 1.25), m="skin2")                                           # Zeigefinger
    box((0.12, 0.28, 0.1), (-0.05, -0.28, 0.72), m="leather")                                        # Rucksack
    sphere(0.14, (-0.05, -0.4, 0.95), (1, 0.8, 1), "leather", 6, 4)
    for sx in (-1, 1):
        box((0.1, 0.18, 0.08), (sx * 0.14, 0.12, 0.05), m="leather")                                # Stiefel


def market_wagon():
    box((2.8, 1.5, 0.2), (0, 0, 0.88), (0, 0, 0), "wood")                                          # Ladefläche
    box((2.8, 0.1, 0.5), (0, -0.7, 1.2), m="wood2")                                                 # Rückwand
    for sx in (-1, 1):
        box((0.1, 1.5, 0.5), (sx * 1.35, 0, 1.2), m="wood2")                                        # Seiten
        for sy in (-1, 1):
            cone(0.68, 0.68, 0.14, (sx * 0.9, sy * 0.88, 0.68), (math.pi / 2, 0, 0), "wood2", 14)  # Räder
            cone(0.15, 0.15, 0.22, (sx * 0.9, sy * 0.88, 0.68), (math.pi / 2, 0, 0), "iron", 8)
            for k in range(6):
                a = k * math.pi / 6
                limb((sx * 0.9 + 0.6 * math.cos(a), sy * 0.95, 0.68 + 0.6 * math.sin(a)), (sx * 0.9 - 0.6 * math.cos(a), sy * 0.95, 0.68 - 0.6 * math.sin(a)), 0.045, 0.045, "wood", 4)
    for sx in (-1, 1):                                                                              # Dachpfosten und Dach
        for sy in (-1, 1):
            limb((sx * 1.3, sy * 0.68, 0.95), (sx * 1.3, sy * 0.68, 2.6), 0.07, 0.07, "wood", 5)
    for k in range(7):                                                                              # gestreifte Plane (Satteldach)
        x = -1.5 + k * 0.5
        box((0.5, 1.8, 0.05), (x, 0, 2.62 + 0.0), (0.0, 0.0, 0.0), "canopy" if k % 2 == 0 else "canopy2")
    box((3.2, 0.06, 0.3), (0, 0.92, 2.45), m="canopy2")                                             # Vorderkante
    for k in range(8):
        box((0.3, 0.05, 0.22), (-1.4 + k * 0.4, 0.95, 2.28), (0, 0, 0.1 * ((-1) ** k)), "canopy" if k % 2 else "canopy2")
    box((2.4, 0.4, 0.06), (0, 0.45, 1.75), m="wood")                                                # Regalbrett
    for k, pm in enumerate(["potion_g", "potion_b", "potion_p", "potion_g", "potion_p", "potion_b"]):    # Tränke
        x = -1.0 + k * 0.4
        cone(0.1, 0.1, 0.22, (x, 0.45, 1.88), m=pm, verts=8)
        cone(0.04, 0.04, 0.1, (x, 0.45, 2.05), m="bone", verts=6)
    for k in range(3):                                                                              # Kisten und Säcke auf der Ladefläche
        box((0.5, 0.4, 0.4), (-1.0 + k * 0.5, -0.4, 1.2), (0, 0, 0.1 * k), "wood2")
    sphere(0.32, (0.9, -0.3, 1.2), (1, 1, 0.8), "cloth2", 6, 4)
    sphere(0.28, (1.1, 0.2, 1.15), (1, 1, 0.8), "cloth2", 6, 4)
    for k in range(3):                                                                              # Fässer neben dem Wagen
        a = (-1.55 + k * 0.6, 1.1 + (k % 2) * 0.25)
        cone(0.4, 0.4, 0.85, (a[0], a[1], 0.43), m="wood", verts=10)
        for z in (0.18, 0.68):
            cone(0.42, 0.42, 0.07, (a[0], a[1], z), m="iron", verts=10)
        cone(0.36, 0.36, 0.03, (a[0], a[1], 0.86), m="wood2", verts=10)
    for sx in (-1, 1):                                                                              # Deichsel
        limb((sx * 0.4, 0.75, 0.82), (sx * 0.5, 2.8, 0.1), 0.07, 0.06, "wood", 5)
    limb((0, 0.9, 2.45), (0, 0.9, 2.2), 0.02, 0.02, "iron", 4)                                       # Laterne
    box((0.2, 0.2, 0.28), (0, 0.9, 2.05), m="lantern")
    cone(0.16, 0.0, 0.14, (0, 0.9, 2.26), m="iron", verts=4)
    box((0.9, 0.05, 0.4), (0, 0.98, 1.35), m="wood")                                                # Schild "Händler"
    sphere(0.07, (-0.2, 1.0, 1.35), m="lantern", seg=5, rings=4)
    sphere(0.07, (0.0, 1.0, 1.35), m="lantern", seg=5, rings=4)
    sphere(0.07, (0.2, 1.0, 1.35), m="lantern", seg=5, rings=4)


def boar():
    """großes Wildschwein als Packtier mit Sattel, Satteltaschen und Zaumzeug"""
    sphere(0.8, (0, 0, 1.0), (0.78, 1.5, 0.78), "fur", 12, 8)                                       # Rumpf
    sphere(0.55, (0, 1.1, 1.1), (0.8, 0.9, 0.85), "fur", 10, 7)                                     # Schulter
    sphere(0.4, (0, 1.75, 0.95), (0.8, 1.1, 0.8), "fur2", 9, 6)                                     # Kopf
    cone(0.2, 0.14, 0.4, (0, 2.2, 0.82), (math.pi / 2, 0, 0), "fur2", 8)                            # Schnauze
    sphere(0.17, (0, 2.42, 0.8), (1, 0.6, 0.8), "eye", 6, 4)                                         # Nase
    for sx in (-1, 1):
        path([(sx * 0.18, 2.12, 0.78), (sx * 0.34, 2.15, 0.88), (sx * 0.3, 2.2, 1.05)], 0.06, 0.0, "bone", 5)   # Hauer
        cone(0.1, 0.0, 0.32, (sx * 0.28, 1.6, 1.3), (-0.4, sx * 0.3, 0), "fur", 5)                  # Ohren
        sphere(0.05, (sx * 0.2, 1.92, 1.1), (1, 0.5, 1), "eyeglow", 5, 3)                          # Augen
    for k in range(8):                                                                              # Borsten auf dem Rücken
        y = -0.8 + k * 0.28
        cone(0.06, 0.0, 0.3, (0, y, 1.55 - abs(y) * 0.1), (0, 0, 0), "fur2", 4)
    for sx in (-1, 1):                                                                              # Beine
        for y in (-0.85, 0.85):
            limb((sx * 0.3, y, 0.8), (sx * 0.3, y, 0.1), 0.15, 0.1, "fur", 6)
            cone(0.12, 0.1, 0.12, (sx * 0.3, y, 0.05), m="eye", verts=6)
    limb((0, -1.4, 1.1), (0.1, -1.7, 1.0), 0.07, 0.0, "fur", 5)                                     # Schwanz
    box((0.8, 0.9, 0.08), (0, 0.1, 1.74), m="cloth")                                                # Sattelunterlage
    box((0.55, 0.5, 0.14), (0, 0.1, 1.84), m="leather")                                             # Sattel
    box((0.5, 0.1, 0.22), (0, -0.2, 1.96), m="leather")                                             # Rückenlehne
    box((0.1, 0.2, 0.2), (0, 0.38, 1.96), m="leather")                                              # Sattelknauf
    for sx in (-1, 1):
        sphere(0.34, (sx * 0.6, -0.1, 1.2), (0.8, 1.0, 1.1), "cloth2", 8, 6)                       # Satteltaschen
        box((0.06, 0.3, 0.12), (sx * 0.44, -0.1, 1.5), m="leather")
        limb((sx * 0.2, 0.1, 1.8), (sx * 0.5, 0.1, 1.2), 0.03, 0.03, "leather", 4)                  # Gurt
        sphere(0.06, (sx * 0.62, -0.1, 0.9), m="iron", seg=5, rings=3)
        limb((sx * 0.16, 2.0, 1.15), (sx * 0.1, 1.0, 1.3), 0.025, 0.025, "leather", 4)               # Zügel
    cone(0.45, 0.45, 0.06, (0, 1.78, 0.98), (math.pi / 2, 0, 0), "leather", 8)                      # Kopfriemen
    sphere(0.3, (0.05, -0.2, 2.1), (0.9, 1.0, 0.7), "cloth2", 6, 4)                                # Bündel auf dem Sattel
    limb((0.05, -0.4, 2.2), (0.15, -0.7, 2.6), 0.04, 0.03, "wood2", 4)


def cauldron_fire():
    for k in range(9):
        a = k * math.tau / 9
        box((0.34, 0.26, 0.24), (0.95 * math.cos(a), 0.95 * math.sin(a), 0.12), (0, 0, a + 0.3), "stone")
    for k in range(4):
        a = k * 0.8 + 0.2
        limb((0.75 * math.cos(a), 0.75 * math.sin(a), 0.2), (-0.7 * math.cos(a), -0.7 * math.sin(a), 0.32), 0.1, 0.08, "bark", 5)
    cone(0.8, 0.0, 0.03, (0, 0, 0.2), m="ember", verts=10)
    cone(0.3, 0.0, 0.75, (0, 0, 0.62), m="fire", verts=6)
    cone(0.18, 0.0, 0.55, (0.18, 0.05, 0.55), (0, 0.25, 0), "fire", 5)
    for k in range(3):                                                                              # Dreibein
        a = k * math.tau / 3 + 0.5
        limb((1.0 * math.cos(a), 1.0 * math.sin(a), 0.0), (0.1 * math.cos(a), 0.1 * math.sin(a), 2.0), 0.06, 0.05, "wood", 5)
    sphere(0.62, (0, 0, 1.45), (1, 1, 0.8), "iron", 10, 6)                                           # Kessel
    cone(0.5, 0.5, 0.02, (0, 0, 1.82), m="potion_g", verts=10)                                       # grüne Brühe
    for k in range(8):
        a = k * math.tau / 8
        sphere(0.05, (0.25 * math.cos(a), 0.25 * math.sin(a), 1.84), m="potion_g", seg=4, rings=3)
    limb((0.05, 0, 1.9), (0.5, 0.2, 2.45), 0.035, 0.03, "wood2", 4)                                 # Kelle
    for sx in (-1, 1):
        sphere(0.16, (sx * 1.5, 0.7, 0.18), (1, 1, 0.8), "stone", 5, 4)


def loot_sack():
    sphere(0.55, (0, 0, 0.5), (1, 1, 1.0), "cloth2", 9, 7)                                           # Sack
    cone(0.2, 0.34, 0.4, (0, 0, 1.05), m="cloth2", verts=8)                                         # Hals
    cone(0.26, 0.26, 0.07, (0, 0, 0.9), m="leather", verts=8)                                       # Schnur
    skull((0.0, 0.0, 1.38), 0.8)
    skull((0.28, 0.1, 1.2), 0.55)
    bone((-0.3, 0.0, 1.15), (-0.55, 0.1, 1.7), 0.05, 0.08)
    bone((0.05, -0.1, 1.2), (0.3, -0.2, 1.75), 0.05, 0.08, "bonedark")
    sphere(0.12, (0.5, 0.45, 0.1), (1, 1, 0.5), "ember", 5, 4)                                       # Münzen am Boden
    sphere(0.1, (0.65, 0.3, 0.07), (1, 1, 0.5), "lantern", 5, 3)


def coin_stack(x, y, z, n, r=0.12):
    for k in range(n):
        cone(r, r, 0.035, (x + 0.004 * (k % 2), y, z + 0.0175 + 0.036 * k), m="gold", verts=10)


def counter():
    """Verkaufstresen mit Goldmünzen, Tränken, Waage und Rechnungsbuch (Vorderseite = +Y)"""
    box((2.7, 1.0, 0.12), (0, 0, 1.0), m="wood")                                                    # Platte
    box((2.76, 1.06, 0.04), (0, 0, 1.07), m="wood2")
    box((2.6, 0.1, 0.92), (0, 0.45, 0.5), m="wood2")                                                # Front
    for k in range(5):                                                                              # Frontbretter
        box((0.5, 0.02, 0.86), (-1.04 + k * 0.52, 0.51, 0.5), m="wood")
    box((2.62, 0.04, 0.1), (0, 0.52, 0.9), m="gold")                                                # Goldleiste
    box((2.62, 0.04, 0.1), (0, 0.52, 0.12), m="iron")
    for sx in (-1, 1):
        box((0.12, 0.9, 0.95), (sx * 1.27, 0, 0.5), m="wood2")                                      # Seiten
    box((1.1, 0.04, 0.6), (-0.1, 0.54, 0.52), m="cloth")                                            # Tuch mit Goldrand
    box((1.14, 0.045, 0.04), (-0.1, 0.55, 0.84), m="gold")
    sphere(0.12, (-0.1, 0.57, 0.52), (1, 0.4, 1), "gold", 6, 4)                                     # Münzzeichen
    coin_stack(-1.05, 0.15, 1.07, 9)                                                                # Münzstapel
    coin_stack(-0.8, 0.25, 1.07, 6, 0.12)
    coin_stack(-0.65, 0.05, 1.07, 12, 0.12)
    coin_stack(-0.4, 0.28, 1.07, 4, 0.12)
    for k in range(9):                                                                              # verstreute Münzen
        a = k * 2.3
        box((0.2, 0.2, 0.025), (-0.25 + 0.12 * math.cos(a) * (1 + k * 0.1), 0.12 + 0.15 * math.sin(a), 1.075), (0, 0, a), "gold")
    sphere(0.28, (0.15, 0.2, 1.22), (1, 1, 0.8), "leather", 8, 6)                                  # Münzbeutel
    cone(0.12, 0.2, 0.15, (0.15, 0.2, 1.42), m="leather", verts=8)
    for k in range(4):
        box((0.12, 0.12, 0.03), (0.3 + 0.07 * k, 0.12 - 0.04 * k, 1.075), (0, 0, k), "gold")
    for k, pm in enumerate(["potion_g", "potion_b", "potion_p", "potion_g", "potion_b"]):          # Tränke in einer Reihe
        x = 0.5 + k * 0.17
        cone(0.075, 0.075, 0.2, (x, -0.28, 1.17), m=pm, verts=8)
        cone(0.03, 0.03, 0.09, (x, -0.28, 1.31), m="bone", verts=6)
        cone(0.035, 0.035, 0.03, (x, -0.28, 1.375), m="wood2", verts=6)
    sphere(0.1, (1.05, -0.1, 1.2), m="potion_g", seg=8, rings=6)                                    # runde Flasche
    cone(0.03, 0.03, 0.1, (1.05, -0.1, 1.33), m="bone", verts=6)
    limb((0.92, -0.25, 1.06), (0.92, -0.25, 1.62), 0.025, 0.025, "iron", 4)                          # Waage
    limb((0.62, -0.25, 1.6), (1.22, -0.25, 1.6), 0.02, 0.02, "iron", 4)
    for sx in (-1, 1):
        limb((0.92 + sx * 0.3, -0.25, 1.6), (0.92 + sx * 0.3, -0.25, 1.38), 0.01, 0.01, "iron", 3)
        cone(0.12, 0.05, 0.03, (0.92 + sx * 0.3, -0.25, 1.36), m="gold", verts=10)
    sphere(0.1, (0.92, -0.25, 1.64), m="gold", seg=6, rings=4)
    box((0.42, 0.3, 0.07), (-0.95, -0.28, 1.1), (0, 0, 0.2), "leather")                             # Rechnungsbuch
    box((0.38, 0.26, 0.04), (-0.95, -0.28, 1.15), (0, 0, 0.2), "bone")
    limb((-0.8, -0.3, 1.2), (-0.62, -0.2, 1.5), 0.012, 0.0, "bonedark", 3)                           # Feder
    box((0.7, 0.04, 0.4), (0.0, -0.4, 1.34), (-0.5, 0, 0), "wood")                                   # Preisschild
    sphere(0.04, (-0.15, -0.38, 1.36), m="gold", seg=4, rings=3)
    sphere(0.04, (0.0, -0.38, 1.36), m="gold", seg=4, rings=3)
    sphere(0.04, (0.15, -0.38, 1.36), m="gold", seg=4, rings=3)


def armor_stand():
    """Rüstungsständer mit Brustpanzer, Schulterplatten, Helm mit Federbusch, Schild und Schwert"""
    for sx in (-1, 1):
        box((0.12, 0.9, 0.1), (sx * 0.0, 0.0, 0.05), (0, 0, 0.0), "wood")                          # Standfüße
    box((1.1, 0.12, 0.1), (0, 0, 0.05), m="wood")
    limb((0, 0, 0.1), (0, 0, 1.2), 0.07, 0.07, "wood", 6)                                           # Mittelstange
    limb((-0.7, 0, 1.55), (0.7, 0, 1.55), 0.05, 0.05, "wood", 5)                                    # Querholz
    box((0.46, 0.3, 0.3), (0, 0, 1.05), m="steel2")                                                 # Hüftschutz
    for k in range(4):                                                                              # Schurz-Platten
        box((0.12, 0.04, 0.34), (-0.18 + k * 0.12, 0.14, 0.78), (0.15, 0, 0), "steel")
    cone(0.3, 0.26, 0.55, (0, 0, 1.45), m="steel", verts=10)                                        # Brustpanzer
    box((0.5, 0.1, 0.5), (0, 0.18, 1.45), (0, 0, 0), "steel")
    box((0.04, 0.04, 0.5), (0, 0.24, 1.45), m="gold")
    for k in range(3):
        box((0.46, 0.02, 0.04), (0, 0.23, 1.25 + 0.12 * k), m="steel2")
    for sx in (-1, 1):
        sphere(0.2, (sx * 0.38, 0.0, 1.62), (1.0, 1.1, 0.7), "steel", 8, 5)                         # Schulterplatten
        sphere(0.16, (sx * 0.42, 0.0, 1.55), (1.0, 1.0, 0.6), "steel2", 8, 5)
        box((0.1, 0.1, 0.25), (sx * 0.62, 0.0, 1.2), m="steel")                                    # Armschienen
        sphere(0.07, (sx * 0.62, 0.0, 1.05), m="steel2", seg=5, rings=4)                            # Handschuh
    sphere(0.24, (0, 0, 1.92), (1.0, 1.05, 1.1), "steel", 10, 7)                                    # Helm
    box((0.34, 0.08, 0.05), (0, 0.2, 1.95), m="eye")                                                # Sehschlitz
    box((0.05, 0.1, 0.18), (0, 0.23, 1.9), m="steel2")                                              # Nasensteg
    path([(0, -0.05, 2.12), (0, -0.2, 2.35), (0, -0.4, 2.2)], 0.1, 0.03, "hat", 6)                 # Federbusch
    limb((0, 0, 2.1), (0, 0, 2.2), 0.06, 0.02, "gold", 5)
    # Schild an der Seite
    cone(0.45, 0.45, 0.06, (0.95, 0.08, 0.75), (math.pi / 2, 0, 0), "steel2", 14)
    cone(0.4, 0.4, 0.04, (0.95, 0.1, 0.75), (math.pi / 2, 0, 0), "cloth", 14)
    sphere(0.12, (0.95, 0.14, 0.75), (1, 0.6, 1), "gold", 8, 5)
    for k in range(8):
        a = k * math.tau / 8
        sphere(0.04, (0.95 + 0.36 * math.cos(a), 0.13, 0.75 + 0.36 * math.sin(a)), m="gold", seg=4, rings=3)
    # Schwert angelehnt
    box((0.1, 0.03, 1.2), (-0.8, 0.12, 0.75), (-0.1, 0, -0.2), "steel")
    box((0.4, 0.06, 0.06), (-0.7, 0.1, 1.28), (0, 0, -0.2), "gold")
    limb((-0.69, 0.1, 1.3), (-0.65, 0.1, 1.55), 0.035, 0.035, "leather", 4)
    sphere(0.05, (-0.65, 0.1, 1.58), m="gold", seg=5, rings=4)


def crate_stack():
    box((0.9, 0.9, 0.8), (0, 0, 0.4), (0, 0, 0.1), "wood")
    box((0.92, 0.92, 0.08), (0, 0, 0.82), (0, 0, 0.1), "wood2")
    box((0.7, 0.7, 0.6), (0.1, 0.0, 1.16), (0, 0, -0.2), "wood2")
    for k in range(3):
        limb((-0.05 + 0.1 * k, 0.0, 1.5), (-0.1 + 0.12 * k, 0.1, 1.95), 0.025, 0.025, "steel", 4)    # Schwertgriffe ragen heraus
        box((0.22, 0.03, 0.04), (-0.05 + 0.1 * k, 0.0, 1.78), (0, 0, 0.4 * k), "gold")
    box((0.8, 0.8, 0.7), (1.0, 0.1, 0.35), (0, 0, -0.1), "wood")                                    # zweite Kiste, offen
    box((0.78, 0.04, 0.5), (1.0, -0.3, 0.9), (-1.0, 0, -0.1), "wood2")                              # Deckel
    for k in range(3):
        sphere(0.17, (0.8 + 0.2 * k, 0.1, 0.78), (1, 1, 0.7), "cloth" if k % 2 else "cloth2", 6, 4)   # Stoffballen
    for k in range(3):
        cone(0.07, 0.07, 0.18, (1.0 + 0.1 * k, 0.3, 0.8), m=["potion_g", "potion_b", "potion_p"][k], verts=8)
    sphere(0.3, (-1.0, 0.2, 0.28), (1, 1, 0.8), "cloth2", 7, 5)                                      # Sack mit Getreide
    cone(0.16, 0.26, 0.2, (-1.0, 0.2, 0.55), m="cloth2", verts=8)
    box((0.5, 0.4, 0.4), (-0.1, 0.9, 0.2), (0, 0, 0.3), "wood2")


# ---------------------------------------------------------------- Wächterstatue (Basisobjekt) in 4 Zerfallsstufen, Heilbrunnen, Heilkreis
def rubble(rnd, n, rad, z0=0.0, size=0.35):
    for k in range(n):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.4, 1.0) * rad
        s = rnd.uniform(0.6, 1.4) * size
        box((s, s * rnd.uniform(0.7, 1.3), s * rnd.uniform(0.5, 1.0)), (r * math.cos(a), r * math.sin(a), z0 + s * 0.35), (rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), a), "statue" if k % 3 else "statue2")


def big_skull(x, y, z, s=2.0, eyes="eyes_g", horns=True, tilt=0.0):
    skull((x, y, z), s, horns=horns)
    for sx in (-1, 1):
        sphere(0.07 * s, (x + sx * 0.12 * s, y - 0.23 * s, z + 0.02 * s), (1, 0.5, 1.1), eyes, 5, 4)


def guardian(stage):
    rnd = random.Random(90 + stage)
    # Sockel (alle Stufen): drei Stufen, bei Stufe 3 gesprungen
    cone(1.75, 1.6, 0.3, (0, 0, 0.15), m="statue2", verts=10)
    cone(1.45, 1.3, 0.3, (0, 0, 0.45), m="statue", verts=10)
    cone(1.15, 1.0, 0.3, (0, 0, 0.75), m="statue2", verts=10)
    for k in range(4):                                                                              # Eck-Zacken am Sockel
        a = k * math.pi / 2 + 0.4
        box((0.3, 0.3, 0.5), (1.5 * math.cos(a), 1.5 * math.sin(a), 0.45), (0, 0, a), "statue")
    if stage >= 3:
        rubble(rnd, 14, 2.0, 0.0, 0.5)
        rubble(rnd, 8, 1.2, 0.9, 0.45)
        for k in range(3):
            limb((0.3 * k - 0.3, 0.2, 0.9), (0.2 * k - 0.2, 0.6, 1.4), 0.05, 0.02, "crackd", 3)
        big_skull(0.9, 0.9, 1.25, 1.6, "eyes_dim", False)
        box((0.22, 0.06, 2.4), (-0.6, 0.6, 1.2), (0.0, 1.2, 0.4), "statue2")                       # umgefallenes Schwert
        box((0.9, 0.12, 0.14), (-1.4, 0.2, 0.55), (0.0, 0.5, 0.4), "statue")
        for k in range(5):                                                                          # Glut zwischen den Trümmern
            a = k * 1.3
            sphere(0.14, (0.8 * math.cos(a), 0.8 * math.sin(a), 0.95), (1, 1, 0.5), "ember", 5, 3)
        pelvis(-0.2, 0.0, 1.1)
        ribcage(0.3, -0.3, 1.0, 1.7, 0.4, 3, 0.3)
        return
    # Beine
    z0 = 0.9
    for sx in (-1, 1):
        if stage == 2 and sx == 1:                                                                  # rechtes Bein abgebrochen
            box((0.4, 0.4, 0.5), (sx * 0.38, 0.0, z0 + 0.25), m="statue")
            rubble(rnd, 4, 0.9, z0, 0.3)
            continue
        box((0.4, 0.4, 0.6), (sx * 0.38, 0.1, z0 + 0.35), m="statue")                               # Fuß/Schienbein
        box((0.5, 0.7, 0.2), (sx * 0.38, 0.25, z0 + 0.1), m="statue2")                              # Stiefel
        box((0.38, 0.38, 0.9), (sx * 0.38, 0.05, z0 + 1.0), m="statue")                             # Oberschenkel
        sphere(0.26, (sx * 0.38, 0.05, z0 + 0.7), m="statue2", seg=6, rings=4)                      # Knie
    zb = z0 + 1.55
    box((1.05, 0.55, 0.38), (0, 0.0, zb), m="statue2")                                              # Becken/Gürtel
    box((0.3, 0.1, 0.3), (0, 0.3, zb), m="statue")
    sphere(0.12, (0, 0.36, zb), m="gold", seg=5, rings=4)
    zt = zb + 0.3
    path([(0, -0.1, zt), (0, -0.15, zt + 0.5), (0, -0.1, zt + 1.0)], 0.12, 0.1, "statue2", 6)       # Wirbelsäule
    ribs_n = 5 if stage < 2 else 4
    for k in range(ribs_n):
        t = (k + 0.5) / 5
        z = zt + 0.1 + t * 0.95
        w = 0.55 * (1.0 - abs(t - 0.4) * 0.8)
        for sx in (-1, 1):
            path([(0, -0.1, z), (sx * w, 0.1, z - 0.03), (sx * w * 0.8, 0.45, z - 0.12)], 0.09, 0.05, "statue", 5)
    box((0.14, 0.12, 0.8), (0, 0.4, zt + 0.5), m="statue")                                          # Brustbein
    for sx in (-1, 1):                                                                              # Schulterplatten
        if stage >= 1 and sx == -1:
            sphere(0.3, (sx * 0.75, 0, zt + 1.05), (1.0, 1.0, 0.65), "statue2", 8, 5)              # abgeplatzt
            rubble(rnd, 3, 0.5, zt + 0.6, 0.2)
        else:
            sphere(0.38, (sx * 0.75, 0, zt + 1.05), (1.0, 1.0, 0.65), "statue", 8, 5)
            for k in range(3):
                cone(0.06, 0.0, 0.18, (sx * (0.55 + 0.2 * k), 0.0, zt + 1.35 - 0.04 * k), m="statue2", verts=4)
    # Arme
    for sx in (-1, 1):
        p_sh = (sx * 0.8, 0.0, zt + 0.95)
        p_el = (sx * 0.95, 0.35, zt + 0.35)
        limb(p_sh, p_el, 0.17, 0.14, "statue", 6)
        sphere(0.17, p_el, m="statue2", seg=6, rings=4)
        if stage >= 1 and sx == -1:                                                                 # linker Unterarm weg
            limb(p_el, (sx * 0.95, 0.5, zt + 0.15), 0.12, 0.05, "statue2", 5)
            limb((-1.5, 1.1, 0.95), (-1.0, 1.4, 1.05), 0.12, 0.1, "statue", 5)
            sphere(0.14, (-1.0, 1.4, 1.05), m="statue2", seg=6, rings=4)
        elif stage == 2 and sx == 1:
            limb(p_el, (sx * 0.9, 0.4, zt - 0.4), 0.12, 0.1, "statue", 5)                           # Arm hängt
        else:
            limb(p_el, (0.0, 0.85, zt + 0.15), 0.13, 0.12, "statue", 6)                             # Unterarm zur Waffe
    # Schwert: nur bis Stufe 1 in der Hand
    if stage <= 1:
        box((0.24, 0.07, 2.3), (0, 0.85, 1.95), m="statue2")
        box((1.0, 0.16, 0.15), (0, 0.85, zt + 0.2), m="statue")
        sphere(0.14, (0, 0.85, zt + 0.46), m="gold", seg=6, rings=4)
        cone(0.14, 0.0, 0.35, (0, 0.85, 0.95), (math.pi, 0, 0), "statue2", 4)
    else:
        box((0.24, 0.07, 2.3), (-1.55, 0.9, 1.4), (0.0, 0.55, 0.3), "statue2")                     # Schwert lehnt am Sockel
        box((0.8, 0.14, 0.14), (-1.2, 0.9, 2.3), (0.0, 0.55, 0.3), "statue")
    # Kopf
    if stage <= 1:
        eyes_m = "eyes_g" if stage == 0 else "eyes_dim"
        zh = zt + 1.55
        path([(0, -0.1, zt + 1.0), (0, 0.0, zt + 1.2)], 0.14, 0.12, "statue2", 6)                   # Hals
        big_skull(0, 0.0, zh, 2.3, eyes_m, True)
    else:
        big_skull(1.25, 1.1, 1.1, 2.0, "eyes_dim", True)                                            # Kopf liegt auf dem Sockel
    # Risse
    if stage >= 1:
        rnd2 = random.Random(7)
        for k in range(7 if stage == 1 else 12):
            x = rnd2.uniform(-0.5, 0.5)
            z = zb + rnd2.uniform(-0.6, 1.4)
            limb((x, 0.4, z), (x + rnd2.uniform(-0.3, 0.3), 0.42, z + rnd2.uniform(0.3, 0.7)), 0.025, 0.012, "crackd", 3)
        rubble(rnd, 6 if stage == 1 else 12, 1.6, 0.0, 0.3)


def heal_fountain():
    """Heilbrunnen: Steinbecken mit leuchtendem Wasser, Knochensäule mit Schädel als Wasserspeier"""
    cone(1.3, 1.2, 0.5, (0, 0, 0.25), m="stone", verts=10)
    cone(1.15, 1.15, 0.05, (0, 0, 0.5), m="stone2", verts=10)
    cone(1.0, 1.0, 0.04, (0, 0, 0.5), m="potion_g", verts=10)                                       # Wasser
    for k in range(10):
        a = k * math.tau / 10
        box((0.55, 0.28, 0.3), (1.2 * math.cos(a), 1.2 * math.sin(a), 0.5), (0, 0, a), "stone2")   # Beckenrand
    limb((0, 0, 0.5), (0, 0, 2.3), 0.22, 0.16, "bonedark", 8)                                       # Säule aus Knochen
    for k in range(5):
        z = 0.8 + k * 0.3
        sphere(0.25, (0, 0, z), (1, 1, 0.6), "bone", 7, 4)
        for sx in (-1, 1):
            limb((sx * 0.2, 0, z), (sx * 0.6, 0.1, z - 0.15), 0.06, 0.03, "bone", 4)
    skull((0, 0.15, 2.55), 1.1, horns=True)
    for sx in (-1, 1):
        sphere(0.07, (sx * 0.13, -0.15, 2.57), (1, 0.5, 1.1), "eyes_g", 5, 3)
    for k in range(6):                                                                              # Wasserstrahlen (feste Formen)
        a = k * math.tau / 6
        path([(0, -0.1, 2.15), (0.5 * math.cos(a), 0.5 * math.sin(a), 1.8), (0.95 * math.cos(a), 0.95 * math.sin(a), 0.6)], 0.05, 0.03, "potion_g", 4)
    for k in range(4):
        a = k * math.tau / 4 + 0.8
        limb((1.4 * math.cos(a), 1.4 * math.sin(a), 0.5), (1.4 * math.cos(a), 1.4 * math.sin(a), 1.5), 0.06, 0.02, "bonedark", 4)      # Knochenzacken
        sphere(0.12, (1.4 * math.cos(a), 1.4 * math.sin(a), 1.55), m="potion_g", seg=6, rings=4)


def heal_circle():
    """flacher Runenkreis am Boden (Heilfeld)"""
    cone(4.3, 4.3, 0.05, (0, 0, 0.025), m="stone2", verts=24)
    cone(4.0, 4.0, 0.06, (0, 0, 0.05), m="potion_g", verts=24)
    cone(3.7, 3.7, 0.08, (0, 0, 0.055), m="stone", verts=24)
    for k in range(8):
        a = k * math.tau / 8
        box((0.8, 0.12, 0.05), (2.9 * math.cos(a), 2.9 * math.sin(a), 0.1), (0, 0, a + math.pi / 2), "potion_g")
        box((0.25, 0.25, 0.05), (3.6 * math.cos(a + 0.2), 3.6 * math.sin(a + 0.2), 0.1), (0, 0, a), "potion_g")
    for k in range(6):
        a = k * math.pi / 3
        box((3.0, 0.1, 0.04), (0, 0, 0.12), (0, 0, a), "potion_g")
    cone(1.5, 1.5, 0.08, (0, 0, 0.12), m="stone", verts=18)


make_all = [("tree_dead", tree_dead), ("tree_pine", tree_pine), ("bone_pillar", bone_pillar), ("bone_arch", bone_arch),
            ("skull_pile", skull_pile), ("mushroom_glow", mushroom_glow), ("rock_dark", rock_dark), ("brazier", brazier), ("lava_rock", lava_rock),
            ("skel_sit", skel_sit), ("skel_impaled", skel_impaled), ("skel_hang", skel_hang), ("cage_skel", cage_skel), ("wagon", wagon), ("barrels", barrels),
            ("tent", tent), ("campfire", campfire), ("banner", banner), ("sword_grave", sword_grave), ("totem", totem), ("stone_circle", stone_circle),
            ("torch", torch), ("eyes", eyes),
            ("goblin_merchant", goblin_merchant), ("market_wagon", market_wagon), ("boar", boar), ("cauldron_fire", cauldron_fire), ("loot_sack", loot_sack),
            ("counter", counter), ("armor_stand", armor_stand), ("crate_stack", crate_stack),
            ("guardian_0", lambda: guardian(0)), ("guardian_1", lambda: guardian(1)), ("guardian_2", lambda: guardian(2)), ("guardian_3", lambda: guardian(3)),
            ("heal_fountain", heal_fountain), ("heal_circle", heal_circle)]
for name, fn in make_all:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    make_materials()
    fn()
    export(name)
print("FERTIG")
