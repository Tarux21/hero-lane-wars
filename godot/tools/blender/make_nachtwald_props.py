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


make_all = [("tree_dead", tree_dead), ("tree_pine", tree_pine), ("bone_pillar", bone_pillar), ("bone_arch", bone_arch),
            ("skull_pile", skull_pile), ("mushroom_glow", mushroom_glow), ("rock_dark", rock_dark), ("brazier", brazier), ("lava_rock", lava_rock),
            ("skel_sit", skel_sit), ("skel_impaled", skel_impaled), ("skel_hang", skel_hang), ("cage_skel", cage_skel), ("wagon", wagon), ("barrels", barrels),
            ("tent", tent), ("campfire", campfire), ("banner", banner), ("sword_grave", sword_grave), ("totem", totem), ("stone_circle", stone_circle),
            ("torch", torch), ("eyes", eyes)]
for name, fn in make_all:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    make_materials()
    fn()
    export(name)
print("FERTIG")
