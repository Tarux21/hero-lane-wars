# Waffen der Helden (Blender 4.2 headless). Jede Waffe entsteht senkrecht am Ursprung: Griff bei (0,0,0), Spitze/Kopf nach +Z,
# Vorderseite nach -Y. make_heroes.py setzt sie in die Hand. Vorschau aller Vorschläge:
#   blender -b -P make_weapons.py -- sheet <bild.png>
import bpy, bmesh, sys, math, os
from mathutils import Vector


def mat(name, col, metal=0.0, rough=0.6, emit=None, strength=3.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*col, 1)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    if emit:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = strength
    return m


def M():
    return {
        "steel": mat("w_steel", (0.62, 0.64, 0.68), 0.9, 0.25),
        "dark": mat("w_dark", (0.16, 0.16, 0.19), 0.85, 0.35),
        "gold": mat("w_gold", (0.86, 0.62, 0.24), 0.95, 0.25),
        "leather": mat("w_leather", (0.26, 0.15, 0.08), 0.0, 0.7),
        "wood": mat("w_wood", (0.32, 0.2, 0.11), 0.0, 0.75),
        "darkwood": mat("w_darkwood", (0.14, 0.09, 0.06), 0.0, 0.8),
        "bone": mat("w_bone", (0.83, 0.79, 0.68), 0.0, 0.55),
        "team": mat("w_team", (0.08, 0.2, 0.52), 0.0, 0.7),
        "red": mat("w_red", (0.45, 0.04, 0.05), 0.3, 0.45),
        "poison": mat("w_poison", (0.3, 0.9, 0.25), 0.0, 0.3, emit=(0.3, 1.0, 0.25), strength=2.5),
        "arcane": mat("w_arcane", (0.6, 0.35, 1.0), 0.0, 0.2, emit=(0.6, 0.35, 1.0), strength=4.0),
        "frost": mat("w_frost", (0.5, 0.85, 1.0), 0.0, 0.15, emit=(0.4, 0.8, 1.0), strength=3.0),
        "leaf": mat("w_leaf", (0.22, 0.55, 0.15), 0.0, 0.6),
        "moss": mat("w_moss", (0.25, 0.42, 0.12), 0.0, 0.9),
        "glowleaf": mat("w_glowleaf", (0.4, 0.95, 0.35), 0.0, 0.4, emit=(0.35, 0.95, 0.3), strength=2.5),
        "soul": mat("w_soul", (0.4, 1.0, 0.45), 0.0, 0.3, emit=(0.4, 1.0, 0.45), strength=4.0),
        "string": mat("w_string", (0.85, 0.82, 0.7), 0.0, 0.5),
        "paper": mat("w_paper", (0.85, 0.78, 0.6), 0.0, 0.8),
    }


# ---------------------------------------------------------------- Grundbausteine
def prim(kind, m, **kw):
    getattr(bpy.ops.mesh, "primitive_" + kind + "_add")(**kw)
    o = bpy.context.object
    o.data.materials.append(m)
    return o


def cyl(m, r, a, b, r2=None, verts=8):
    a, b = Vector(a), Vector(b)
    d = b - a
    if r2 is None:
        o = prim("cylinder", m, vertices=verts, radius=r, depth=d.length, location=(a + b) / 2)
    else:
        o = prim("cone", m, vertices=verts, radius1=r, radius2=r2, depth=d.length, location=(a + b) / 2)
    o.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
    return o


def ball(m, r, loc, scale=(1, 1, 1), seg=8):
    o = prim("uv_sphere", m, radius=r, location=loc, segments=seg, ring_count=seg // 2)
    o.scale = scale
    return o


def cube(m, loc, size, rot=(0, 0, 0)):
    o = prim("cube", m, size=1, location=loc, rotation=rot)
    o.scale = size
    return o


def spike(m, base, tip, r=0.025):
    return cyl(m, r, base, tip, r2=0.0, verts=8)


def poly_plate(m, rim, outline, thick=0.03, inset=0.03, bulge=0.04, rim_m=None):
    """Flache Platte aus einem Umriss (Punkte in X/Z), Vorderseite -Y, leicht gewölbt, Rand in rim-Material."""
    bm = bmesh.new()
    vs = [bm.verts.new((x, 0, z)) for x, z in outline]
    f = bm.faces.new(vs)
    bmesh.ops.inset_region(bm, faces=[f], thickness=inset, depth=0.0)
    cx = sum(x for x, _ in outline) / len(outline)
    cz = sum(z for _, z in outline) / len(outline)
    span = max(max(abs(x - cx) for x, _ in outline), max(abs(z - cz) for _, z in outline))
    for v in bm.verts:
        d = math.hypot(v.co.x - cx, (v.co.z - cz) * 0.6) / span
        v.co.y = -bulge * (1 - min(1, d) ** 2)
    me = bpy.data.meshes.new("plate")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("plate", me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(m)
    me.materials.append(rim)
    for p in me.polygons:
        p.material_index = 0 if p.index == 0 else 1
    so = o.modifiers.new("s", "SOLIDIFY"); so.thickness = thick; so.use_rim = True; so.material_offset_rim = 1
    bv = o.modifiers.new("b", "BEVEL"); bv.width = 0.006; bv.segments = 2
    bpy.context.view_layer.objects.active = o
    for md in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    return o


def blade(m, length, width, base_z, thick=0.012, curve=0.0, wave=0.0, taper=0.25, fuller=None):
    """Klinge entlang +Z ab base_z: Spitze, dünne Schneiden, optional gekrümmt (curve) oder gewellt (wave), Hohlkehle (fuller-Material)."""
    o = cube(m, (0, 0, base_z + length / 2), (width, thick, length))
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.subdivide(number_cuts=12); bpy.ops.object.mode_set(mode='OBJECT')
    for v in o.data.vertices:
        t = (v.co.z - base_z) / length
        w = 1.0 - (1 - taper) * t
        if t > 0.82:
            w *= max(0.04, (1 - t) / 0.18)
        v.co.x *= w
        if abs(v.co.x) > width * 0.3 * w:
            v.co.y *= 0.3
        v.co.x += curve * t * t * length + wave * math.sin(t * math.pi * 5) * (1 - t)
    parts = [o]
    if fuller:
        f = cube(fuller, (0, 0, base_z + length * 0.4), (width * 0.18, thick * 1.15, length * 0.62))
        parts.append(f)
    return parts


def join(parts, name, smooth=False):
    for o in parts:
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    if smooth:
        for p in o.data.polygons:
            p.use_smooth = True
    return o


# ---------------------------------------------------------------- Tank: Turmschilde (Griff am Unterarm = Ursprung) und Schwerter
def tower_shield(k, v):
    m = M()
    if v == 1:                                                          # T1 Turmschild: hoch, oben gerundet, Buckel mit Stachel, 4 Randstacheln
        out = [(-0.3, -0.5), (0.3, -0.5)] + [(0.3 * math.cos(a), 0.45 + 0.12 * math.sin(a)) for a in [i / 10 * math.pi for i in range(11)]]
        p = [poly_plate(m["team"], m["dark"], out, 0.04, 0.04, 0.05)]
        p.append(ball(m["steel"], 0.09, (0, -0.06, 0.05), (1, 0.6, 1)))
        p.append(spike(m["steel"], (0, -0.1, 0.05), (0, -0.26, 0.05), 0.04))
        for x, z in ((-0.3, 0.3), (0.3, 0.3), (-0.3, -0.35), (0.3, -0.35)):
            p.append(spike(m["dark"], (x, -0.02, z), (x * 1.35, -0.06, z), 0.025))
        p.append(cube(m["gold"], (0, -0.055, 0.05), (0.05, 0.01, 0.9)))
        p.append(cube(m["gold"], (0, -0.055, 0.25), (0.5, 0.01, 0.05)))
    elif v == 2:                                                        # T2 Bollwerk: eckig, Stachelreihe oben, Mittelgrat, Nieten
        out = [(-0.32, -0.55), (0.32, -0.55), (0.34, 0.5), (0.0, 0.62), (-0.34, 0.5)]
        p = [poly_plate(m["dark"], m["steel"], out, 0.05, 0.05, 0.03)]
        p.append(cube(m["steel"], (0, -0.05, 0.0), (0.06, 0.02, 1.1)))
        for i in range(5):
            x = -0.26 + i * 0.13
            p.append(spike(m["steel"], (x, -0.02, 0.5 + 0.12 * (1 - abs(x) / 0.34)), (x, -0.02, 0.72 + 0.12 * (1 - abs(x) / 0.34)), 0.03))
        for x in (-0.25, 0.25):
            for z in (-0.4, 0.0, 0.35):
                p.append(ball(m["gold"], 0.022, (x, -0.04, z)))
        p.append(cube(m["team"], (0, -0.04, -0.1), (0.4, 0.012, 0.2)))
    else:                                                               # T3 Dornenwand: Kite-Turmschild, Wappen, Dornenkranz am Rand
        out = [(0.0, -0.7), (0.3, -0.25), (0.33, 0.45), (0.0, 0.55), (-0.33, 0.45), (-0.3, -0.25)]
        p = [poly_plate(m["team"], m["gold"], out, 0.04, 0.04, 0.06)]
        for i in range(len(out)):
            a, b = Vector((out[i][0], 0, out[i][1])), Vector((out[(i + 1) % len(out)][0], 0, out[(i + 1) % len(out)][1]))
            for t in (0.33, 0.66):
                q = a.lerp(b, t)
                n = Vector((q.x, 0, q.z - 0.0)).normalized()
                p.append(spike(m["dark"], (q.x, -0.02, q.z), (q.x + n.x * 0.12, -0.04, q.z + n.z * 0.12), 0.022))
        p.append(ball(m["gold"], 0.1, (0, -0.07, 0.05), (1, 0.5, 1.2)))
        p.append(spike(m["steel"], (0, -0.11, 0.05), (0, -0.3, 0.05), 0.045))
    return join(p, "tower_shield_%d" % v)


def tank_sword(k, v):
    m = M()
    if v == 1:                                                          # S1 Runenklinge: Hohlkehle mit leuchtenden Runen, gebogene Parierstange, Edelstein
        p = blade(m["steel"], 0.95, 0.07, 0.11, fuller=m["frost"])
        p.append(cyl(m["gold"], 0.025, (-0.17, 0, 0.08), (0.17, 0, 0.08), verts=10))
        for s in (-1, 1):
            p.append(cyl(m["gold"], 0.02, (s * 0.17, 0, 0.08), (s * 0.22, 0, 0.16), r2=0.0, verts=8))
        p.append(ball(m["frost"], 0.03, (0, -0.02, 0.09)))
        p.append(cyl(m["leather"], 0.02, (0, 0, -0.14), (0, 0, 0.06)))
        p.append(ball(m["gold"], 0.035, (0, 0, -0.17)))
    elif v == 2:                                                        # S2 Kriegsschwert: breite Klinge, kantige Parierstange mit Stacheln, Knaufstachel
        p = blade(m["steel"], 0.9, 0.11, 0.11, taper=0.55, fuller=m["dark"])
        p.append(cube(m["dark"], (0, 0, 0.08), (0.34, 0.05, 0.05)))
        for s in (-1, 1):
            p.append(spike(m["steel"], (s * 0.17, 0, 0.08), (s * 0.25, 0, 0.04), 0.022))
        p.append(cyl(m["leather"], 0.022, (0, 0, -0.16), (0, 0, 0.06)))
        p.append(spike(m["steel"], (0, 0, -0.16), (0, 0, -0.26), 0.03))
    else:                                                               # S3 Ritterstreitkolben: Flanschenkopf, langer Griff
        p = [cyl(m["dark"], 0.022, (0, 0, -0.15), (0, 0, 0.6))]
        for i in range(7):
            a = i / 7 * math.tau
            p.append(cube(m["steel"], (math.cos(a) * 0.06, math.sin(a) * 0.06, 0.62), (0.08, 0.015, 0.16), rot=(0, 0, a)))
        p.append(ball(m["gold"], 0.05, (0, 0, 0.62)))
        p.append(spike(m["steel"], (0, 0, 0.7), (0, 0, 0.82), 0.03))
        p.append(cyl(m["leather"], 0.026, (0, 0, -0.15), (0, 0, 0.05)))
    return join(p, "tank_sword_%d" % v)


# ---------------------------------------------------------------- Schurke: Dolche
def dagger(k, v):
    m = M()
    if v == 1:                                                          # D1 Giftzahn: gekrümmte Klinge, grün leuchtende Giftrinne
        p = blade(m["dark"], 0.36, 0.06, 0.07, curve=0.25, fuller=m["poison"])
        p.append(cube(m["red"], (0, 0, 0.05), (0.16, 0.035, 0.03)))
        p.append(cyl(m["leather"], 0.017, (0, 0, -0.1), (0, 0, 0.04)))
        p.append(ball(m["poison"], 0.022, (0, 0, -0.12)))
    elif v == 2:                                                        # D2 Schlangenklinge: gewellte Klinge (Kris), Schlangenkopf-Parierstange
        p = blade(m["steel"], 0.38, 0.05, 0.07, wave=0.015)
        p.append(cyl(m["gold"], 0.018, (-0.08, 0, 0.05), (0.08, 0, 0.05), verts=10))
        for s in (-1, 1):
            p.append(ball(m["gold"], 0.025, (s * 0.09, 0, 0.06), (1, 0.8, 1.3)))
        p.append(cyl(m["dark"], 0.017, (0, 0, -0.1), (0, 0, 0.04)))
        p.append(ball(m["red"], 0.02, (0, 0, -0.12)))
    else:                                                               # D3 Krallendolch: Karambit-Haken, Fingerring
        p = blade(m["dark"], 0.3, 0.06, 0.05, curve=0.7, taper=0.4)
        p.append(cyl(m["leather"], 0.018, (0, 0, -0.08), (0, 0, 0.05)))
        bpy.ops.mesh.primitive_torus_add(major_radius=0.035, minor_radius=0.009, location=(0, 0, -0.12), rotation=(math.pi / 2, 0, 0))
        tr = bpy.context.object; tr.data.materials.append(m["steel"]); p.append(tr)
    return join(p, "dagger_%d" % v)


# ---------------------------------------------------------------- Magier
def mage_weapon(k, v):
    m = M()
    if v == 1:                                                          # M1 Sphärenstab: Ring-Kopf mit schwebender Arkan-Kugel
        p = [cyl(m["darkwood"], 0.022, (0, 0, -0.5), (0, 0, 1.0))]
        bpy.ops.mesh.primitive_torus_add(major_radius=0.12, minor_radius=0.015, location=(0, 0, 1.13), rotation=(math.pi / 2, 0, 0))
        tr = bpy.context.object; tr.data.materials.append(m["gold"]); p.append(tr)
        p.append(ball(m["arcane"], 0.07, (0, 0, 1.13)))
        for a in (0.6, 2.5):
            p.append(spike(m["gold"], (0.1 * math.cos(a), 0, 1.0), (0.17 * math.cos(a), 0, 1.25), 0.012))
    elif v == 2:                                                        # M2 Zauberbuch + Zauberstab (Buch schwebt neben der linken Hand)
        p = [cube(m["red"], (0.0, 0, 0.35), (0.22, 0.06, 0.28))]
        p.append(cube(m["paper"], (0.008, 0, 0.35), (0.205, 0.05, 0.26)))
        p.append(cube(m["gold"], (0, -0.032, 0.35), (0.08, 0.01, 0.08)))
        p.append(ball(m["arcane"], 0.02, (0, -0.04, 0.35)))
        p.append(cyl(m["darkwood"], 0.012, (0.35, 0, -0.1), (0.35, 0, 0.32), r2=0.006))
        p.append(ball(m["arcane"], 0.025, (0.35, 0, 0.34)))
    else:                                                               # M3 Kristallzepter: kurzer Stab, Kristallsplitter im Kreis
        p = [cyl(m["gold"], 0.02, (0, 0, -0.15), (0, 0, 0.45))]
        p.append(ball(m["gold"], 0.04, (0, 0, 0.46)))
        k_ = prim("ico_sphere", m["frost"], radius=0.06, subdivisions=1, location=(0, 0, 0.6)); k_.scale = (0.7, 0.7, 1.6); p.append(k_)
        for i in range(5):
            a = i / 5 * math.tau
            s_ = prim("ico_sphere", m["frost"], radius=0.025, subdivisions=1, location=(0.12 * math.cos(a), 0.12 * math.sin(a), 0.6)); s_.scale = (0.6, 0.6, 1.8); p.append(s_)
    return join(p, "mage_%d" % v)


# ---------------------------------------------------------------- Waldläuferin
def ranger_weapon(k, v):
    m = M()
    def bowcurve(pts, mat_, r=0.016):
        cu = bpy.data.curves.new("bow", 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = r; cu.bevel_resolution = 3
        sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1)
        for i, q in enumerate(pts):
            sp.points[i].co = (*q, 1); sp.points[i].radius = 1.25 - abs(i / (len(pts) - 1) - 0.5) * 1.5
        o = bpy.data.objects.new("bow", cu); bpy.context.scene.collection.objects.link(o)
        cu.materials.append(mat_)
        bpy.context.view_layer.objects.active = o; o.select_set(True)
        bpy.ops.object.convert(target='MESH')
        return o
    if v == 1:                                                          # R1 Langbogen (Holz, Lederwicklung)
        pts = [(0, -0.15 * (1 - (2 * (i / 24 - 0.5)) ** 2), (i / 24 - 0.5) * 1.35) for i in range(25)]
        p = [bowcurve(pts, m["wood"]), cyl(m["string"], 0.003, (0, 0.0, -0.66), (0, 0.0, 0.66)), cyl(m["leather"], 0.022, (0, -0.15, -0.08), (0, -0.15, 0.08))]
    elif v == 2:                                                        # R2 Dornen-Recurvebogen: Enden nach vorn gebogen, Dornen, grüne Spitzen
        pts = []
        for i in range(25):
            t = i / 24 - 0.5
            y = -0.14 * (1 - (2 * t) ** 2) + 0.12 * max(0, abs(t) * 2 - 0.75) * 4
            pts.append((0, y, t * 1.2))
        p = [bowcurve(pts, m["darkwood"]), cyl(m["string"], 0.003, (0, 0.11, -0.6), (0, 0.11, 0.6))]
        for t in (-0.35, -0.2, 0.2, 0.35):
            p.append(spike(m["leaf"], (0, -0.12 * (1 - (2 * t) ** 2), t * 1.2), (0, -0.2, t * 1.2 + 0.03), 0.012))
        for s in (-1, 1):
            p.append(ball(m["glowleaf"], 0.02, (0, 0.12, s * 0.6)))
    else:                                                               # R3 Jagdarmbrust
        p = [cube(m["wood"], (0, 0, 0.2), (0.05, 0.06, 0.6))]
        pts = [((i / 16 - 0.5) * 0.6, -0.06 * (1 - (2 * (i / 16 - 0.5)) ** 2), 0.45) for i in range(17)]
        bw = bowcurve(pts, m["dark"], 0.012); p.append(bw)
        p.append(cyl(m["string"], 0.003, (-0.3, 0.02, 0.45), (0.3, 0.02, 0.45)))
        p.append(cyl(m["steel"], 0.006, (0, -0.04, 0.0), (0, -0.04, 0.48)))
        p.append(cube(m["leather"], (0, 0.03, -0.08), (0.04, 0.12, 0.12)))
    return join(p, "ranger_%d" % v)


# ---------------------------------------------------------------- Druidin
def druid_weapon(k, v):
    m = M()
    def leaf_at(loc, ang, size=0.07):
        bm = bmesh.new()
        pts = [(0, 0), (size * 0.35, size * 0.4), (0, size), (-size * 0.35, size * 0.4)]
        f = bm.faces.new([bm.verts.new((x, 0, z)) for x, z in pts])
        me = bpy.data.meshes.new("leaf"); bm.to_mesh(me); bm.free()
        o = bpy.data.objects.new("leaf", me); bpy.context.scene.collection.objects.link(o)
        me.materials.append(m["leaf"])
        so = o.modifiers.new("s", "SOLIDIFY"); so.thickness = 0.004
        bpy.context.view_layer.objects.active = o; bpy.ops.object.modifier_apply(modifier="s")
        o.location = loc; o.rotation_euler = ang
        return o
    if v == 1:                                                          # Dr1 Wurzelstab: knorrig, Moos, leuchtende Pilze, Blätter
        pts = [(0.02 * math.sin(i * 1.3), 0.02 * math.cos(i * 0.9), -0.5 + i * 0.1) for i in range(17)]
        p = [cyl(m["darkwood"], 0.024 - 0.0005 * i, pts[i], pts[i + 1]) for i in range(16)]
        for a in range(3):
            p.append(cyl(m["darkwood"], 0.014, pts[16], (0.1 * math.cos(a * 2.1), 0.1 * math.sin(a * 2.1), 1.2), r2=0.004))
        p.append(ball(m["glowleaf"], 0.05, (0, 0, 1.12)))
        for i, z in enumerate((0.75, 0.9, 1.0)):
            p.append(ball(m["moss"], 0.035, (0.02, 0, z), (1.2, 1.2, 0.6)))
            p.append(ball(m["poison"], 0.022, (0.04 * (-1) ** i, -0.02, z + 0.04), (1, 1, 0.5)))
        for a in range(6):
            p.append(leaf_at((0.03 * math.cos(a), 0.03 * math.sin(a), 1.05 + 0.02 * a), (0.4, 0, a * 1.05)))
    elif v == 2:                                                        # Dr2 Geweihstab: Hirschgeweih am Kopf, Federn
        p = [cyl(m["wood"], 0.022, (0, 0, -0.5), (0, 0, 1.05))]
        for s in (-1, 1):
            base = Vector((0, 0, 1.05))
            mid = Vector((s * 0.12, 0, 1.2)); top = Vector((s * 0.16, 0, 1.38))
            p += [cyl(m["bone"], 0.014, base, mid, r2=0.011), cyl(m["bone"], 0.011, mid, top, r2=0.004)]
            p.append(cyl(m["bone"], 0.009, mid, mid + Vector((s * 0.1, 0, 0.08)), r2=0.003))
        p.append(ball(m["glowleaf"], 0.04, (0, 0, 1.12)))
        for a in range(4):
            p.append(leaf_at((0.02, -0.02, 0.98 - a * 0.03), (0.2, 0, 3.3 + a * 0.3), 0.06))
    else:                                                               # Dr3 Sichel + Totem-Anhänger
        p = [cyl(m["wood"], 0.02, (0, 0, -0.15), (0, 0, 0.3))]
        for i in range(10):
            a0, a1 = i / 10 * 3.0, (i + 1) / 10 * 3.0
            q0 = Vector((0.18 * math.sin(a0) - 0.0, 0, 0.3 + 0.18 * (1 - math.cos(a0))))
            q1 = Vector((0.18 * math.sin(a1), 0, 0.3 + 0.18 * (1 - math.cos(a1))))
            p.append(cyl(m["steel"], 0.018 * (1 - i / 11), q0, q1, verts=6))
        p.append(ball(m["glowleaf"], 0.025, (0, 0, -0.18)))
        for a in range(3):
            p.append(leaf_at((0.0, 0, -0.2 - a * 0.05), (0, 0, a * 2.0), 0.05))
    return join(p, "druid_%d" % v)


# ---------------------------------------------------------------- Nekromant
def skull(m_bone, m_eye, loc, s=1.0):
    loc = Vector(loc)
    p = [ball(m_bone, 0.07 * s, loc, (1.0, 1.05, 0.95))]
    p.append(cube(m_bone, loc + Vector((0, -0.04 * s, -0.06 * s)), (0.08 * s, 0.06 * s, 0.04 * s)))
    for e in (-1, 1):
        p.append(ball(m_eye, 0.016 * s, loc + Vector((e * 0.026 * s, -0.062 * s, 0.0))))
    return p


def necro_weapon(k, v):
    m = M()
    if v == 1:                                                          # N1 Seelensense: lange Klinge, Schädel am Schaft
        p = [cyl(m["darkwood"], 0.022, (0, 0, -0.5), (0, 0, 1.15))]
        for i in range(12):
            a0, a1 = i / 12, (i + 1) / 12
            q0 = Vector((-0.6 * a0, 0, 1.15 - 0.18 * a0 * a0))
            q1 = Vector((-0.6 * a1, 0, 1.15 - 0.18 * a1 * a1))
            c_ = cube(m["dark"], (q0 + q1) / 2, (0.055, 0.008, 0.11 * (1 - a0 * 0.8)))
            c_.rotation_euler = (0, math.atan2(q1.z - q0.z, -(q1.x - q0.x)), 0)
            p.append(c_)
        p += skull(m["bone"], m["soul"], (0, -0.0, 1.0), 0.8)
    elif v == 2:                                                        # N2 Knochenstab: Wirbel-Schaft, Schädel mit Rippen-Krone, Seelenfeuer
        p = []
        for i in range(14):
            p.append(ball(m["bone"], 0.03, (0, 0, -0.4 + i * 0.1), (1, 1, 0.7)))
            p.append(cyl(m["bone"], 0.016, (0, 0, -0.4 + i * 0.1), (0, 0, -0.3 + i * 0.1)))
        p += skull(m["bone"], m["soul"], (0, 0, 1.08), 1.1)
        for a in range(5):
            ang = -0.9 + a * 0.45
            p.append(cyl(m["bone"], 0.01, (0, 0.02, 1.1), (0.16 * math.sin(ang), 0.04, 1.1 + 0.16 * math.cos(ang)), r2=0.004))
        p.append(ball(m["soul"], 0.05, (0, 0.03, 1.2)))
    else:                                                               # N3 Totenlaterne + Grimoire (Laterne an der Kette)
        p = [cyl(m["dark"], 0.01, (0, 0, -0.05), (0, 0, 0.25))]
        p.append(cube(m["dark"], (0, 0, -0.18), (0.13, 0.13, 0.03)))
        p.append(cube(m["dark"], (0, 0, -0.42), (0.13, 0.13, 0.03)))
        for x, y in ((-0.06, -0.06), (0.06, -0.06), (-0.06, 0.06), (0.06, 0.06)):
            p.append(cyl(m["dark"], 0.008, (x, y, -0.42), (x, y, -0.18)))
        p += skull(m["bone"], m["soul"], (0, 0, -0.3), 0.7)
        p.append(ball(m["soul"], 0.05, (0, 0, -0.3)))
        p.append(cube(m["dark"], (0.4, 0, 0.1), (0.2, 0.06, 0.26)))
        p += skull(m["bone"], m["soul"], (0.4, -0.04, 0.1), 0.45)
    return join(p, "necro_%d" % v)


ROWS = [("Tank: Schild", tower_shield), ("Tank: Waffe", tank_sword), ("Schurke: Dolch", dagger), ("Magier", mage_weapon),
        ("Waldläuferin", ranger_weapon), ("Druidin", druid_weapon), ("Nekromant", necro_weapon)]
NAMES = {
    "Tank: Schild": ["T1 Turmschild mit Buckelstachel", "T2 Bollwerk mit Stachelkrone", "T3 Dornenwand (Kite)"],
    "Tank: Waffe": ["S1 Runenklinge", "S2 Kriegsschwert mit Stacheln", "S3 Ritter-Streitkolben"],
    "Schurke: Dolch": ["D1 Giftzahn (gekrümmt, Giftrinne)", "D2 Schlangenklinge (gewellt)", "D3 Krallendolch (Karambit)"],
    "Magier": ["M1 Sphärenstab", "M2 Zauberbuch + Zauberstab", "M3 Kristallzepter"],
    "Waldläuferin": ["R1 Langbogen", "R2 Dornen-Recurvebogen", "R3 Jagdarmbrust"],
    "Druidin": ["Dr1 Wurzelstab mit Pilzen", "Dr2 Geweihstab", "Dr3 Sichel mit Totem"],
    "Nekromant": ["N1 Seelensense", "N2 Knochenstab mit Seelenfeuer", "N3 Totenlaterne + Grimoire"],
}


def label(text, loc, size=0.07):
    cu = bpy.data.curves.new("t", 'FONT'); cu.body = text; cu.size = size; cu.align_x = 'CENTER'
    o = bpy.data.objects.new("t", cu); bpy.context.scene.collection.objects.link(o)
    o.location = loc; o.rotation_euler = (math.pi / 2, 0, 0)
    cu.materials.append(mat("label", (0.9, 0.9, 0.9), 0.0, 0.5, emit=(0.9, 0.9, 0.9), strength=1.0))
    return o


def _tile(fn, v, text, path, size=(480, 560)):
    """Eine Waffe allein: schräg von vorn, bildfüllend, Beschriftung unten."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    o = fn(None, v)
    o.rotation_euler = (math.radians(-12), 0, math.radians(25))
    bpy.context.view_layer.update()
    ws = [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector([min(w[i] for w in ws) for i in range(3)])
    hi = Vector([max(w[i] for w in ws) for i in range(3)])
    ctr = (lo + hi) / 2
    ext = max(hi.x - lo.x, hi.z - lo.z * 1.0, (hi.z - lo.z)) * 1.18
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = ext * max(1.0, size[1] / size[0]) * 1.0
    cam.location = ctr + Vector((0, -6, 0.0))
    cam.rotation_euler = (math.pi / 2, 0, 0)
    lab = label(text, ctr + Vector((0, -1.0, -cam.data.ortho_scale * 0.5 + cam.data.ortho_scale * 0.04)), cam.data.ortho_scale * 0.045)
    def light(kind, energy, col, rot):
        l = bpy.data.objects.new(kind, bpy.data.lights.new(kind, kind)); sc.collection.objects.link(l)
        l.data.energy = energy; l.data.color = col; l.rotation_euler = rot
    light('SUN', 3.2, (1.0, 0.94, 0.86), (math.radians(55), 0, math.radians(-35)))
    light('SUN', 1.4, (0.55, 0.7, 1.0), (math.radians(-50), 0, math.radians(40)))
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.08, 0.08, 0.11, 1)
    sc.render.engine = 'BLENDER_EEVEE_NEXT'
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def sheet(out, rows=None):
    """Alle Vorschläge als Kacheln (je Waffe ein eigenes Bild), zu einem Gesamtbild zusammengesetzt."""
    import numpy as np
    rows = rows or ROWS
    tmp = os.path.join(os.path.dirname(out), "tiles")
    os.makedirs(tmp, exist_ok=True)
    grid = []
    for r, (title, fn) in enumerate(rows):
        row = []
        for v in (1, 2, 3):
            pth = os.path.join(tmp, "t_%d_%d.png" % (r, v))
            _tile(fn, v, "%s – %s" % (title, NAMES[title][v - 1]), pth)
            img = bpy.data.images.load(pth)
            a = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
            row.append(a)
        grid.append(np.concatenate(row, axis=1))
    full = np.concatenate(grid[::-1], axis=0)                           # Blender-Bilder liegen unten-links: Reihenfolge umdrehen
    h, w_ = full.shape[0], full.shape[1]
    im = bpy.data.images.new("sheet", w_, h, alpha=True)
    im.pixels = full.ravel()
    im.filepath_raw = out
    im.file_format = 'PNG'
    im.save()
    print("Saved:", out)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if argv and argv[0] == "sheet":
        sheet(argv[1])
