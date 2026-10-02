# Giftiger Nachtwald: erzeugt die Landschafts-Modelle (Low-Poly) und exportiert sie als GLB nach godot/assets/props/.
# Aufruf (vom Projektordner aus):
#   tools-extern/blender-4.2.9-windows-x64/blender.exe --background --python godot/tools/blender/make_nachtwald_props.py -- godot/assets/props
# Alles ist selbst gebaut (keine fremden Dateien, keine Lizenzrechte Dritter). Feste Zufallszahlen: gleiches Ergebnis bei jedem Lauf.
# Maße in Metern, Blender Z = oben (der GLB-Export dreht es für Godot nach Y = oben).

import bpy, math, random, sys, os
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "props"
os.makedirs(OUT, exist_ok=True)

BONE = (0.91, 0.88, 0.80)
BARK = (0.10, 0.07, 0.13)
STONE = (0.17, 0.15, 0.19)


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


M_BONE = mat("Knochen", BONE, rough=0.7)
M_BARK = mat("Rinde", BARK)
M_PINE = mat("Tanne", (0.05, 0.11, 0.10))
M_STONE = mat("Stein", STONE)
M_EYE = mat("Augen", (0.02, 0.02, 0.03))
M_STEM = mat("Stiel", (0.72, 0.80, 0.68))
M_CAP = mat("PilzGlut", (0.2, 0.6, 0.2), emit=(0.35, 1.0, 0.28), strength=3.0)
M_FIRE = mat("Flamme", (1.0, 0.45, 0.1), emit=(1.0, 0.45, 0.1), strength=4.0)
M_IRON = mat("Eisen", (0.12, 0.12, 0.14), rough=0.6)

parts = []


def finish(obj, material):
    obj.data.materials.append(material)
    parts.append(obj)
    return obj


def cone(r1, r2, depth, loc, rot=(0, 0, 0), material=None, verts=8):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    return finish(bpy.context.active_object, material)


def sphere(r, loc, scale=(1, 1, 1), material=None, seg=8, rings=6):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=r, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    return finish(o, material)


def box(size, loc, rot=(0, 0, 0), material=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = size
    return finish(o, material)


def limb(p0, p1, r0, r1, material, verts=6):
    """Zylinder von p0 nach p1 (verjüngt)"""
    a, b = Vector(p0), Vector(p1)
    d = b - a
    rot = d.to_track_quat("Z", "Y").to_euler()
    return cone(r0, r1, d.length, (a + b) / 2.0, rot, material, verts)


def bone(p0, p1, r=0.13, knob=0.2):
    """Knochen: Schaft mit zwei Gelenkköpfen"""
    limb(p0, p1, r, r, M_BONE, 6)
    for p in (p0, p1):
        sphere(knob, p, material=M_BONE, seg=6, rings=4)


def skull(loc, s=1.0):
    x, y, z = loc
    sphere(0.30 * s, (x, y, z), (1.0, 1.05, 0.92), M_BONE, 8, 6)
    box((0.30 * s, 0.22 * s, 0.14 * s), (x, y - 0.17 * s, z - 0.19 * s), material=M_BONE)           # Kiefer
    for sx in (-1, 1):
        sphere(0.075 * s, (x + sx * 0.12 * s, y - 0.25 * s, z + 0.02 * s), (1, 0.6, 1.2), M_EYE, 6, 4)
    box((0.06 * s, 0.05 * s, 0.1 * s), (x, y - 0.29 * s, z - 0.05 * s), material=M_EYE)             # Nase


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
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True)
    print("EXPORT", path, "Dreiecke:", len(obj.data.polygons))
    bpy.ops.object.delete()
    parts.clear()


# ---------------------------------------------------------------- Modelle
def tree_dead():
    rnd = random.Random(11)
    limb((0, 0, 0), (0.05, 0.03, 4.4), 0.42, 0.07, M_BARK, 7)
    for i in range(7):
        z = 1.2 + i * 0.42
        ang = rnd.uniform(0, math.tau)
        l = rnd.uniform(0.9, 1.7) * (1.1 - i * 0.08)
        p0 = (0.04 * math.cos(ang), 0.04 * math.sin(ang), z)
        p1 = (p0[0] + l * math.cos(ang), p0[1] + l * math.sin(ang), z + l * rnd.uniform(0.35, 0.8))
        limb(p0, p1, 0.12, 0.03, M_BARK, 5)
        ang2 = ang + rnd.uniform(-0.8, 0.8)
        p2 = (p1[0] + 0.6 * math.cos(ang2), p1[1] + 0.6 * math.sin(ang2), p1[2] + rnd.uniform(0.25, 0.6))
        limb(p1, p2, 0.05, 0.015, M_BARK, 4)
    for a in range(5):                                                                      # Wurzeln
        ang = a * math.tau / 5 + 0.3
        limb((0, 0, 0.35), (0.7 * math.cos(ang), 0.7 * math.sin(ang), -0.05), 0.2, 0.06, M_BARK, 5)


def tree_pine():
    limb((0, 0, 0), (0, 0, 1.3), 0.26, 0.2, M_BARK, 6)
    z = 1.0
    for i, (r, h) in enumerate([(1.55, 1.7), (1.25, 1.55), (0.95, 1.4), (0.62, 1.25)]):
        cone(r, 0.0, h, (0, 0, z + h / 2), (0, 0, i * 0.5), M_PINE, 8)
        z += h * 0.62


def bone_pillar():
    cone(0.62, 0.5, 0.2, (0, 0, 0.1), material=M_STONE, verts=8)
    z = 0.2
    for i in range(3):
        off = (0.04 * (i % 2 * 2 - 1), 0.03 * (1 - i % 2 * 2))
        bone((off[0], off[1], z), (off[0] * 1.5, off[1] * 1.5, z + 0.75), r=0.17 - i * 0.015, knob=0.25 - i * 0.025)
        z += 0.78
    skull((0.02, 0.0, z + 0.2), 0.95)


def bone_arch():
    n = 9
    r = 1.55
    pts = [(r * math.cos(math.pi * k / n), 0.0, 0.2 + r * math.sin(math.pi * k / n)) for k in range(n + 1)]
    for a, b in zip(pts, pts[1:]):
        bone(a, b, r=0.1, knob=0.14)
    for sx in (-1, 1):
        cone(0.5, 0.42, 0.2, (sx * r, 0, 0.1), material=M_STONE, verts=8)
    skull((0.0, 0.0, 0.2 + r + 0.25), 0.8)
    for k in range(1, n):                                                                   # Rippen darunter
        a = pts[k]
        limb((a[0], 0.0, a[2]), (a[0] * 0.9, 0.5, a[2] - 0.5), 0.05, 0.03, M_BONE, 4)


def skull_pile():
    rnd = random.Random(5)
    coords = [(0, 0, 0.3), (0.45, 0.1, 0.28), (-0.42, 0.05, 0.28), (0.1, 0.45, 0.28), (-0.1, -0.42, 0.28), (0.2, 0.05, 0.62), (-0.2, 0.1, 0.6), (0.0, -0.1, 0.9)]
    for c in coords:
        skull((c[0], c[1], c[2]), rnd.uniform(0.85, 1.05))
    bone((-0.9, 0.2, 0.15), (0.8, -0.3, 0.2), 0.08, 0.13)
    bone((-0.6, -0.7, 0.12), (0.7, 0.6, 0.18), 0.08, 0.13)


def mushroom_glow():
    rnd = random.Random(3)
    for (x, y, h, r) in [(0, 0, 0.9, 0.55), (0.55, 0.25, 0.6, 0.38), (-0.4, 0.4, 0.45, 0.3), (0.2, -0.5, 0.35, 0.25)]:
        limb((x, y, 0), (x + rnd.uniform(-0.05, 0.05), y, h), 0.09 * r / 0.4 + 0.03, 0.07, M_STEM, 6)
        sphere(r, (x, y, h), (1.0, 1.0, 0.55), M_CAP, 8, 5)
        for sp in range(3):
            a = rnd.uniform(0, math.tau)
            sphere(r * 0.12, (x + 0.55 * r * math.cos(a), y + 0.55 * r * math.sin(a), h + r * 0.3), material=M_STEM, seg=4, rings=3)


def rock_dark():
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.9, location=(0, 0, 0.45))
    o = bpy.context.active_object
    rnd = random.Random(8)
    for v in o.data.vertices:
        v.co += Vector((rnd.uniform(-0.18, 0.18), rnd.uniform(-0.18, 0.18), rnd.uniform(-0.1, 0.12)))
    o.scale = (1.15, 0.9, 0.7)
    finish(o, M_STONE)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.5, location=(0.9, 0.5, 0.22))
    o2 = bpy.context.active_object
    for v in o2.data.vertices:
        v.co += Vector((rnd.uniform(-0.1, 0.1), rnd.uniform(-0.1, 0.1), rnd.uniform(-0.06, 0.06)))
    finish(o2, M_STONE)


def brazier():
    for a in range(3):
        ang = a * math.tau / 3
        limb((0.38 * math.cos(ang), 0.38 * math.sin(ang), 0), (0.15 * math.cos(ang), 0.15 * math.sin(ang), 0.95), 0.07, 0.05, M_IRON, 5)
    cone(0.55, 0.38, 0.35, (0, 0, 1.05), material=M_IRON, verts=8)
    cone(0.3, 0.0, 0.7, (0, 0, 1.45), material=M_FIRE, verts=6)
    cone(0.16, 0.0, 0.5, (0.12, 0.05, 1.5), (0, 0.2, 0), M_FIRE, 5)


def lava_rock():
    """flache Kruste für das Ufer der Lava"""
    rnd = random.Random(21)
    for i in range(5):
        a = i * math.tau / 5
        box((0.9, 0.7, 0.35), (0.7 * math.cos(a), 0.7 * math.sin(a), 0.17), (0, 0, a + rnd.uniform(-0.3, 0.3)), M_STONE)
    box((0.5, 0.5, 0.12), (0, 0, 0.3), material=mat("Glut", (0.8, 0.2, 0.05), emit=(1.0, 0.35, 0.08), strength=3.5))


for name, fn in [("tree_dead", tree_dead), ("tree_pine", tree_pine), ("bone_pillar", bone_pillar), ("bone_arch", bone_arch),
                 ("skull_pile", skull_pile), ("mushroom_glow", mushroom_glow), ("rock_dark", rock_dark), ("brazier", brazier), ("lava_rock", lava_rock)]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for m in list(bpy.data.materials):
        pass
    M_BONE = mat("Knochen", BONE, rough=0.7)
    M_BARK = mat("Rinde", BARK)
    M_PINE = mat("Tanne", (0.05, 0.11, 0.10))
    M_STONE = mat("Stein", STONE)
    M_EYE = mat("Augen", (0.02, 0.02, 0.03))
    M_STEM = mat("Stiel", (0.72, 0.80, 0.68))
    M_CAP = mat("PilzGlut", (0.2, 0.6, 0.2), emit=(0.35, 1.0, 0.28), strength=3.0)
    M_FIRE = mat("Flamme", (1.0, 0.45, 0.1), emit=(1.0, 0.45, 0.1), strength=4.0)
    M_IRON = mat("Eisen", (0.12, 0.12, 0.14), rough=0.6)
    fn()
    export(name)
print("FERTIG")
