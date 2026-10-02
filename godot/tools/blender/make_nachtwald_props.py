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


make_all = [("tree_dead", tree_dead), ("tree_pine", tree_pine), ("bone_pillar", bone_pillar), ("bone_arch", bone_arch),
            ("skull_pile", skull_pile), ("mushroom_glow", mushroom_glow), ("rock_dark", rock_dark), ("brazier", brazier), ("lava_rock", lava_rock)]
for name, fn in make_all:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    make_materials()
    fn()
    export(name)
print("FERTIG")
